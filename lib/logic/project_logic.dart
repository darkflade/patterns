import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:patterns/models/project_model.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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
          _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': true});
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
  final ChatClient _client;

  // Наше состояние - Map пользователей
  final Map<String, UserStatus> _users = {};
  List<UserStatus> get userList => _users.values.toList();

  UserManager(this._client) {
    // Подписываемся на сообщения, чтобы обновлять список
    _listenToMessages();

    // Сразу запрашиваем начальное состояние
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

        case 'user_joined':
          final payload = decoded['payload'];
          final username = payload['username'];
          _users[username] = UserStatus(
            username: username,
            role: payload['role'],
          );
          shouldUpdate = true;
          break;

        case 'user_left':
          final payload = decoded['payload'];
          _users.remove(payload['username']);
          shouldUpdate = true;
          break;
      }

      if (shouldUpdate) {
        // "Кричим" UI, что список пользователей изменился
        notifyListeners();
      }
    });
  }
}

/*
class WebRTCPeer {
  final ChatClient client;
  final RTCVideoRenderer remoteRenderer;
  late RTCPeerConnection _pc;
  bool polite = true;
  bool makingOffer = false;
  bool ignoreOffer = false;
  MediaStream? _localStream;
  final List<RTCIceCandidate> _iceBuffer = [];

  WebRTCPeer(this.client, this.remoteRenderer);

  Future<void> init() async {
    _pc = await createPeerConnection({
    });

    _pc.onIceCandidate = (RTCIceCandidate? candidate) {
      if (candidate == null) return;


        client.sendJson({
          'type': 'ice_candidate',
          'payload': candidate.toMap(),
        });

    };

    _pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
      }
    };

    // Подписка на сообщения
    client.rawMessages.listen((message) => _handleMessage(message));
  }

  Future<void> _handleMessage(dynamic message) async {
    final msg = jsonDecode(message as String);
    final type = msg['type'];
    final payload = msg['payload'];

    switch (type) {
      case 'join_call_success':
        print('joined');
        // теперь можно добавлять локальные треки и делать offer
        if (_localStream != null) {
          await _addLocalTracksAndOffer(_localStream!);
        }
        break;

      case 'sdp_offer':
        final offer = RTCSessionDescription(payload['sdp'], payload['type']);
        final isStable = _pc.signalingState == RTCSignalingState.RTCSignalingStateStable;
        final offerCollision = makingOffer || !isStable;
        ignoreOffer = !polite && offerCollision;
        if (ignoreOffer) return;

        await _pc.setRemoteDescription(offer);
        // после установки remoteDescription — отправляем все буферизированные ICE
        for (var cand in _iceBuffer) {
          client.sendJson({'type': 'ice_candidate', 'payload': cand.toMap()});
        }
        _iceBuffer.clear();

        final answer = await _pc.createAnswer();
        await _pc.setLocalDescription(answer);
        client.sendJson({'type': 'sdp_answer', 'payload': answer.toMap()});
        break;

      case 'sdp_answer':
        final answer = RTCSessionDescription(payload['sdp'], payload['type']);
        await _pc.setRemoteDescription(answer);

        // после remoteDescription — шлём буферизированные кандидаты
        for (var cand in _iceBuffer) {
          client.sendJson({'type': 'ice_candidate', 'payload': cand.toMap()});
        }
        _iceBuffer.clear();
        break;

      case 'ice_candidate':
        final c = payload;
        final candidate = RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']);
        await _pc.addCandidate(candidate);
        break;
    }
  }

  Future<void> startCall() async {
    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': true});
    // не добавляем треки пока не пришёл join_call_success
    client.sendJson({'type': 'join_call'});
  }

  Future<void> _addLocalTracksAndOffer(MediaStream stream) async {
    for (var track in stream.getTracks()) {
      await _pc.addTrack(track, stream);
    }

    makingOffer = true;
    final offer = await _pc.createOffer();
    await _pc.setLocalDescription(offer);
    client.sendJson({'type': 'sdp_offer', 'payload': offer.toMap()});
    makingOffer = false;
  }

  Future<void> dispose() async {
    _localStream?.getTracks().forEach((t) => t.stop());
    await _pc.close();
    remoteRenderer.srcObject = null;
  }
}
 */
