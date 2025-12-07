import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:patterns/models/project_model.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class Me {
  final String username;
  String role;

  Me({required this.username, required this.role});

  bool get isAdmin => role == 'admin';
  bool get isModerator => role == 'moderator';
}

class ChatClient {
  final WebSocketChannel _channel;
  late final Stream<dynamic> _broadcastStream;

  ChatClient(String url, String username)
      : _channel = WebSocketChannel.connect(Uri.parse(url + "?username=$username")) {
    _broadcastStream = _channel.stream.asBroadcastStream();
  }


  void sendMessage(String text) {
    _channel.sink.add(jsonEncode({
      "type": "chat_message",
      "payload": {
        "text": text
      }
    }));
  }

  void sendJson(Map<String, dynamic> data) {
    _channel.sink.add(jsonEncode(data));
  }
  Stream<ChatMessage> get messages => _broadcastStream
      .map((data) => jsonDecode(data))
      .where((decoded) => decoded['type'] == 'chat_message')
      .map((decoded) => ChatMessage.fromJson(decoded['payload']));

  Stream<dynamic> get rawMessages => _broadcastStream;


  void dispose() {
    _channel.sink.close();
  }

}

class WebRTCManager {
  final ChatClient _client;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  WebRTCManager(this._client) {
    remoteRenderer.initialize();
    _listenToSignaling();
  }

  void dispose() {
    remoteRenderer.dispose();
    _localStream?.getTracks().forEach((track) => track.stop());
    _peerConnection?.close();
  }

  void _listenToSignaling() {
    _client.rawMessages.listen((data) async {
      if (_peerConnection == null) return;


      final decoded = jsonDecode(data);
      final type = decoded['type'];
      final payload = decoded['payload'];


      switch (type) {
        case 'sdp_answer':
          final answer = RTCSessionDescription(payload['sdp'], payload['type']);
          print("🧩----------- Текущий signalingState: ${_peerConnection
              ?.signalingState}");
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
            final offer = RTCSessionDescription(
                payload['sdp'], payload['type']);

            if (_peerConnection!.signalingState ==
                RTCSignalingState.RTCSignalingStateStable) {
              await _peerConnection?.setRemoteDescription(offer);
              final answer = await _peerConnection!.createAnswer();
              print(
                  "🧩 Текущий signalingState: ${_peerConnection
                      ?.signalingState}");
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
            _localStream = await navigator.mediaDevices.getUserMedia({'audio':
            {
              'channelCount': 2,
              'sampleRate': 48000,
              'echoCancellation': false,
              'googEchoCancellation': false,
              'googEchoCancellation2': false,
              'googDAEchoCancellation': false,
              'noiseSuppression': false,
              'googNoiseSuppression': false,
              'autoGainControl': false,
              'googAutoGainControl': false,
            }, 'video': false}); // Bug Without True in video on mobile devices with infinite send offers. Doesn't know in this config it works well
          _localStream!.getTracks().forEach((track) {
            _peerConnection?.addTrack(track, _localStream!);
          });
          break;
        default:
          print('Unknown message type was received $type');
          break;
      }
    });
  }

  void joinCall() async {
    if (_peerConnection != null) {
      print("⚠️ Попытка вызвать _joinCall, когда _peerConnection уже существует.");
      return;
    }
    print("--- 🎬 НАЧИНАЕМ _joinCall ---");

    print("🔊 Устанавливаем аудио-конфигурацию ДО создания PeerConnection...");
    AndroidNativeAudioManagement.setAndroidAudioConfiguration(
        AndroidAudioConfiguration(
          androidAudioMode: AndroidAudioMode.normal,
          androidAudioStreamType: AndroidAudioStreamType.music,
          androidAudioAttributesUsageType: AndroidAudioAttributesUsageType.media,
          androidAudioAttributesContentType: AndroidAudioAttributesContentType.music,
          forceHandleAudioRouting: true,
        )
    );
    print("🔊 Аудио-конфигурация установлена в 'normal'/'music'.");


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
          print("➡️ Устанавливаю удаленный поток в рендерер...");
          remoteRenderer.srcObject = event.streams[0];
      }
    };



    _peerConnection!.onRenegotiationNeeded = () async {
      print("🔄 OnNegotiationNeeded сработал");
      await _performNegotiation();
    };

    print("📲 Отправляем 'join_call' на сервер...");
    _client.sendJson({ "type": "join_call" });
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
}

class UserManager with ChangeNotifier {
  final Me _me;
  final ChatClient _client;

  final Map<String, UserStatus> _users = {};
  List<UserStatus> get userList => _users.values.toList();

  UserManager(this._me,this._client) {
    _listenToMessages();

    _client.sendJson({"type": "active_clients_ws"});
    _client.sendJson({"type": "active_clients_sfu"});
  }

  void _listenToMessages() {
    _client.rawMessages.listen((data) {
      print("📥 UserManager RECEIVED: $data");
      final decoded = jsonDecode(data);
      final type = decoded['type'];

      bool shouldUpdate = false;

      switch (type) {
        case 'active_clients_ws_response':
          final List<dynamic> userList = decoded['payload'];
          for (var userData in userList) {
            final username = userData['username'];
            if (!_users.containsKey(username)) {
              _users[username] = UserStatus(
                username: username,
                role: userData['role'],
              );
            }
          }

          if (_users.containsKey(_me.username)) {
            _me.role = _users[_me.username]!.role;
          }

          shouldUpdate = true;
          break;

        case 'active_clients_sfu_response':
          final List<dynamic> userList = decoded['payload'];
          _users.forEach((_, user) => user.isInCall = false);
          for (var userData in userList) {
            final username = userData['username'];
            if (_users.containsKey(username)) {
              _users[username]!.isInCall = true;
            }
          }
          shouldUpdate = true;
          break;

        case 'user_joined_ws':
          final payload = decoded['payload'];
          final username = payload['username'];
          _users[username] = UserStatus(
            username: username,
            role: payload['role'],
          );
          shouldUpdate = true;
          break;

        case 'user_left_ws':
          final payload = decoded['payload'];
          _users.remove(payload['username']);
          shouldUpdate = true;
          break;

        case 'user_joined_sfu':
          final payload = decoded['payload'];
          final username = payload['username'];
          if (_users.containsKey(username)) {
            _users[username]!.isInCall = true;
            shouldUpdate = true;
          }
          break;

        case 'user_left_sfu':
          final payload = decoded['payload'];
          final username = payload['username'];
          if (_users.containsKey(username)) {
            _users[username]!.isInCall = false;
            shouldUpdate = true;
          }
          break;


        case 'promote_user_response':
          final payload = decoded['payload'];
          final username = payload['username'];
          final newRole = payload['new_role'];
          if (_users.containsKey(username)) {
            _users[username]!.role = newRole;
            shouldUpdate = true;
          }

          if (username == _me.username) {
            _me.role = newRole;
          }
          break;
        default:
          print('Unknown message type was received $type');
          break;
      }

      if (shouldUpdate) {
        notifyListeners();
      }
    });
  }
  void promoteUser(String username, String newRole) {
    print("👑 Отправляем команду на повышение $username до $newRole");
    _client.sendJson({
      "type": "promote_user",
      "payload": {
        "username": username,
        "new_role": newRole,
      }
    });
  }
}

