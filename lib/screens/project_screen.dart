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
  final _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  late ChatClient _client;
  late UserManager _userManager;

  // WebRTC
  late WebRTCManager _webRTCManager;
  /*RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final _remoteRenderer = RTCVideoRenderer();*/

  @override
  void initState() {
    super.initState();
    //_remoteRenderer.initialize();
    _client = ChatClient("ws://${widget.ip}/ws", widget.username);

    _webRTCManager = WebRTCManager(_client);
    _userManager = UserManager(_client);
    _userManager.addListener(_onUsersChanged);

    _client.messages.listen((msg) {
        setState(() {
          _messages.add(msg);
        });
    });

    //_client.rawMessages.listen(_handleSignalingMessage);
  }

  void _onUsersChanged() {
    // Просто перерисовываем экран
    setState(() {});
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _client.sendMessage(text);

    _controller.clear();
  }

 /* void _handleSignalingMessage(dynamic data) async {
    if (_peerConnection == null) return;
    final decoded = jsonDecode(data);
    final type = decoded['type'];
    final payload = decoded['payload'];

    switch(type) {

      case 'sdp_answer':
        final answer = RTCSessionDescription(payload['sdp'], payload['type']);
        print("🧩----------- Текущий signalingState: ${_peerConnection?.signalingState}");
        await _peerConnection?.setRemoteDescription(answer);
        break;

      case 'ice_candidate':
        final candidate = RTCIceCandidate(
          payload['candidate'],
          payload['sdpMid'],
          payload['sdpMLineIndex'],
        );
        await _peerConnection?.addCandidate(candidate);
        break;

      case 'sdp_offer':
        print("ПОЛУЧЕН встречный Offer от сервера");
        try {
          final offer = RTCSessionDescription(payload['sdp'], payload['type']);

          if (_peerConnection!.signalingState == RTCSignalingState.RTCSignalingStateStable) {
            await _peerConnection?.setRemoteDescription(offer);
            final answer = await _peerConnection!.createAnswer();
            print(
                "🧩 Текущий signalingState: ${_peerConnection?.signalingState}");
            await _peerConnection!.setLocalDescription(answer);

            _client.sendJson({
              "type": "sdp_answer",
              "payload": answer.toMap(),
            });
            print("✅ Ответили на server offer");
          }
        } catch (e) {
          print("❌ Ошибка при обработке server offer: $e");
        }
        break;
      case 'join_call_success':
        print("Сервер подтвердил вход в звонок. Начинаем настройку медиа.");
        _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': true});
        _localStream!.getTracks().forEach((track) {
          _peerConnection?.addTrack(track, _localStream!);
        });
        break;
      default:
        print('Unknown message type was received $type');
        break;
    }
  }

  Future<void> _performNegotiation() async {

    try {
      print("📤 Создаем offer на клиенте");
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      _client.sendJson({
        "type": "sdp_offer",
        "payload": offer.toMap(),
      });

      print("✅ Offer отправлен на сервер");
    } catch (e) {
      print("❌ Ошибка в _performNegotiation: $e");
    }
  }


  void _joinCall() async {
    if (_peerConnection != null) {
      print("⚠️ Попытка вызвать _joinCall, когда _peerConnection уже существует.");
      return;
    }
    print("--- 🎬 НАЧИНАЕМ _joinCall ---");


    _peerConnection = await createPeerConnection({});

    _peerConnection!.onSignalingState = (state) {
      print("🚦 SignalingState изменился: $state");
    };
    _peerConnection!.onIceGatheringState = (state) {
      print("🧊 IceGatheringState изменился: $state");
    };
    _peerConnection!.onIceConnectionState = (state) {
      print("🔌 IceConnectionState изменился: $state");
    };
    _peerConnection!.onConnectionState = (state) {
      print("🔗 ConnectionState изменился: $state");
    };

    _peerConnection!.onIceCandidate = (candidate) {

      print("🔍 Найден локальный ICE кандидат, отправляем на сервер.");
      _client.sendJson({
        "type": "ice_candidate",
        "payload": candidate.toMap(),
      });

    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      print('New track from remote: ${event.track.kind}');
      if (event.track.kind == 'audio') {
        setState(() {
          print("➡️ Устанавливаю удаленный поток в рендерер...");
          _remoteStream = event.streams[0];
          _remoteRenderer.srcObject = _remoteStream;
        });
      }
    };



    _peerConnection!.onRenegotiationNeeded = () async {
      print("🔄 OnNegotiationNeeded сработал");
      await _performNegotiation();
    };

    print("📲 Отправляем 'join_call' на сервер...");
    _client.sendJson({ "type": "join_call" });
  }*/

  @override
  void dispose() {
    /*
    _remoteRenderer.dispose();
    _localStream?.getTracks().forEach((track) => track.stop());
    _peerConnection?.close();
     */
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
                // Здесь можно показать Drawer или новый экран со списком `userList`
                showModalBottomSheet(
                  context: context,
                  builder: (context) => ListView.builder(
                    itemCount: userList.length,
                    itemBuilder: (context, index) {
                      final user = userList[index];
                      return ListTile(
                        title: Text(user.username),
                        subtitle: Text(user.role),
                        trailing: Icon(
                          Icons.circle,
                          color: user.isInCall ? Colors.green : Colors.grey,
                        ),
                      );
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

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.deepPurple[100] : Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${msg.sender} (${msg.role})",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isMe ? Colors.deepPurple : Colors.green[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(msg.text),
                      ]
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
}
