import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:patterns/logic/project_logic.dart';
import 'package:patterns/models/project_model.dart';

class ProjectScreen extends StatefulWidget {
  final String title;
  final String ip;
  final String username;

  const ProjectScreen({super.key, required this.title, required this.ip, required this.username});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  late final Me _me;
  final _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  late ChatClient _client;
  late UserManager _userManager;

  // WebRTC
  late WebRTCManager _webRTCManager;

  @override
  void initState() {
    super.initState();
    _client = ChatClient("ws://${widget.ip}/ws", widget.username);
    _me = Me(username: widget.username, role: 'peasant');

    _webRTCManager = WebRTCManager(_client);
    _userManager = UserManager(_me, _client);
    _userManager.addListener(_onUsersChanged);

    _client.messages.listen((msg) {
      setState(() {
          _messages.add(msg);
        });
    });

  }

  void _onUsersChanged() {
    setState(() {});
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _client.sendMessage(text);

    _controller.clear();
  }

  @override
  void dispose() {
    _userManager.removeListener(_onUsersChanged);
    _webRTCManager.dispose();
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userList = _userManager.userList;

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.people),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => ListView.builder(
                    itemCount: userList.length,
                    itemBuilder: (context, index) {
                      final user = userList[index];
                      Widget tile = ListTile(
                        leading: Icon(
                          Icons.circle,
                          color: user.isInCall ? Colors.green : Colors.grey,
                          size: 14,
                        ),
                        title: Text(user.username),
                        subtitle: Text(user.role),
                        trailing: (_me.isAdmin && user.username != _me.username)
                            ? IconButton(
                          icon: const Icon(Icons.upgrade),
                          tooltip: 'Изменить роль',
                          onPressed: () {
                            _showPromoteDialog(context, user);
                          },
                        )
                            : null,
                      );
                      if (user.role == 'admin') {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.amber.shade700, width: 2),
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: [Colors.amber.shade100, Colors.white],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                          child: tile,
                        );
                      }

                      if (user.role == 'moderator') {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue.shade700, width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: tile,
                        );
                      }

                      return tile;
                    },
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.call),
              onPressed: _webRTCManager.joinCall,
            ),
          ],
      ),
      body: Column(
        children: [
          SizedBox(
            width: 0,
            height: 0,
            child: RTCVideoView(_webRTCManager.remoteRenderer),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg.sender == widget.username;

                Color getRoleColor(String role) {
                  switch (role.toLowerCase()) {
                    case 'admin':
                      return Colors.redAccent.shade100;
                    case 'moderator':
                      return Colors.blueAccent.shade100;
                    case 'peasant':
                      return Colors.greenAccent.shade100;
                    default:
                      return Colors.deepPurple.shade50;
                  }
                }

                Color bgColor = isMe ? Colors.deepPurple[100]! : getRoleColor(msg.role);
                Color textColor = isMe ? Colors.deepPurple : Colors.black87;

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${msg.sender} (${msg.role})",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(msg.text),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: "Введите сообщение",
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                  label: const Text("Отправить"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPromoteDialog(BuildContext context, UserStatus userToPromote) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Повысить ${userToPromote.username}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                title: const Text('Сделать крестьянином'),
                onTap: () {
                  _userManager.promoteUser(userToPromote.username, 'peasant');
                  Navigator.of(dialogContext).pop();
                },
              ),
              ListTile(
                title: const Text('Сделать модератором'),
                onTap: () {
                  _userManager.promoteUser(userToPromote.username, 'moderator');
                  Navigator.of(dialogContext).pop();
                },
              ),
              ListTile(
                title: const Text('Сделать админом'),
                onTap: () {
                  _userManager.promoteUser(userToPromote.username, 'admin');
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Отмена'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
