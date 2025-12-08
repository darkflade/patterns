import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:patterns/logic/project_logic.dart';
import 'package:patterns/models/project_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProjectScreen extends StatefulWidget {
  final String title;
  final String ip;
  final String username;
  final String password;

  const ProjectScreen({
    super.key,
    required this.title,
    required this.ip,
    required this.username,
    required this.password,
  });

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

  // Stickers
  final List<String> _stickers = [];

  @override
  void initState() {
    super.initState();
    _client = ChatClient(widget.ip, widget.username, widget.password);
    _me = Me(username: widget.username, role: 'peasant');

    _webRTCManager = WebRTCManager(_client);
    _userManager = UserManager(_me, _client);
    _userManager.addListener(_onUsersChanged);
    
    _loadStickers();

    _client.messages.listen((msg) {
      if (mounted) {
        setState(() {
          _messages.add(msg);
        });
      }
    });

    _client.historyMessages.listen((msgs) {
      if (mounted) {
        setState(() {
          // Add history at the beginning
          _messages.insertAll(0, msgs);
        });
      }
    });
    
    // Request history on load
    _client.requestHistory();
  }
  
  Future<void> _loadStickers() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _stickers.clear();
      _stickers.addAll(prefs.getStringList('stickers') ?? []);
    });
  }

  Future<void> _saveSticker(String contentPath) async {
    if (_stickers.contains(contentPath)) return;
    setState(() {
      _stickers.add(contentPath);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('stickers', _stickers);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Стикер сохранен!")),
      );
    }
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

  Future<void> _pickAndUploadImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif'],
        withData: true, // ВАЖНО ДЛЯ WEB
      );

      if (result == null) return;

      final picked = result.files.single;

      if (kIsWeb) {
        // тут bytes есть
        final bytes = picked.bytes;
        if (bytes == null) {
          print("No bytes on web file");
          return;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Загрузка файла...")),
          );
        }

        final url = await _client.uploadFile(picked); // передаем сам PlatformFile

        if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (url != null) {
          _client.sendImageMessage(url);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Ошибка загрузки файла на сервер")),
            );
          }
        }

      } else {
        // Мобильная/десктопная логика
        if (picked.path == null) {
          print("File has no path on non-web");
          return;
        }

        final file = File(picked.path!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Загрузка файла...")),
          );
        }

        final url = await _client.uploadFile(file);

        if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (url != null) {
          _client.sendImageMessage(url);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Ошибка загрузки файла на сервер")),
            );
          }
        }
      }
    } catch (e) {
      print("File picking error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка выбора файла: $e")),
        );
      }
    }
  }
  
  void _sendSticker(String contentPath) {
    _client.sendImageMessage(contentPath);
    Navigator.pop(context); // Close sticker picker
  }

  void _showStickerPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        if (_stickers.isEmpty) {
          return const Center(child: Text("Нет сохраненных стикеров"));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _stickers.length,
          itemBuilder: (context, index) {
            final content = _stickers[index];
            final url = _getFullUrl(content);
            return GestureDetector(
              onTap: () => _sendSticker(content),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _userManager.removeListener(_onUsersChanged);
    _webRTCManager.dispose();
    _client.dispose();
    _controller.dispose();
    super.dispose();
  }
  
  String _getFullUrl(String content) {
    if (content.startsWith("http://") || content.startsWith("https://")) {
        return content;
    }
    if (content.startsWith("/")) {
      return "http://${widget.ip}$content";
    }
    return "http://${widget.ip}/$content";
  }

  @override
  Widget build(BuildContext context) {
    final userList = _userManager.userList;
    final activeCallUsers = userList.where((u) => u.isInCall).map((u) => u.username).join(", ");

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _webRTCManager.leaveCall();
        Navigator.pop(context);
      },
      child: Scaffold(
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
            ValueListenableBuilder<bool>(
              valueListenable: _webRTCManager.inCall,
              builder: (context, inCall, child) {
                if (!inCall) return const SizedBox.shrink();
                return Container(
                  height: 300,
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                         BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                         )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        RTCVideoView(_webRTCManager.remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                        
                        // User info overlay
                        Positioned(
                            top: 16,
                            left: 16,
                            right: 16,
                            child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                    activeCallUsers.isNotEmpty ? "В звонке: $activeCallUsers" : "Ожидание участников...",
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                ),
                            ),
                        ),
                        
                        // Controls overlay
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: FloatingActionButton(
                              backgroundColor: Colors.redAccent,
                              onPressed: () {
                                _webRTCManager.leaveCall();
                              },
                              child: const Icon(Icons.call_end, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
  
                  Widget contentWidget;
                  if (msg.type == 'picture') {
                    final fullUrl = _getFullUrl(msg.content);
                    contentWidget = GestureDetector(
                      onLongPress: () {
                        // Context menu
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.star),
                                title: const Text("Сохранить как стикер"),
                                onTap: () {
                                  Navigator.pop(context);
                                  _saveSticker(msg.content);
                                },
                              )
                            ],
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          fullUrl,
                          width: 250,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                             if (loadingProgress == null) return child;
                             return Container(
                               width: 200, height: 200,
                               color: Colors.grey.withOpacity(0.2),
                               child: const Center(child: CircularProgressIndicator()),
                             );
                          },
                          errorBuilder: (context, error, stackTrace) {
                             return Container(
                                width: 200, height: 100,
                                color: Colors.grey.withOpacity(0.2),
                                child: const Center(child: Text("❌ Ошибка загрузки", style: TextStyle(fontSize: 12))),
                             );
                          },
                        ),
                      ),
                    );
                  } else {
                    contentWidget = Text(msg.content);
                  }
  
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
                              fontSize: 12
                            ),
                          ),
                          const SizedBox(height: 4),
                          contentWidget,
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
                  IconButton(
                    icon: const Icon(Icons.image),
                    onPressed: _pickAndUploadImage,
                    tooltip: "Отправить картинку",
                  ),
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions),
                    onPressed: _showStickerPicker,
                    tooltip: "Стикеры",
                  ),
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
