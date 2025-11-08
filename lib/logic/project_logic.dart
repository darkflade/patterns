import 'dart:convert';
import 'dart:async';
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