import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

// лАБА 5
abstract class MessagePrinter {
  String printMessage(String message);
}

class SimplePrinter implements MessagePrinter {
  @override
  String printMessage(String message) => message;
}

class LogPrinter implements MessagePrinter {
  final MessagePrinter _wrappee;
  final String type;

  LogPrinter(this._wrappee, {this.type = "INFO"});

  @override
  String printMessage(String message) {
    final now = DateTime.now().toIso8601String();
    return "[$now][$type] ${_wrappee.printMessage(message)}";
  }
}

class BorderPrinter implements MessagePrinter {
  final MessagePrinter _wrappee;

  BorderPrinter(this._wrappee);

  @override
  String printMessage(String message) {
    final base = _wrappee.printMessage(message);
    return "*** $base ***";
  }
}

class CountPrinter implements MessagePrinter {
  final MessagePrinter _wrappee;
  static int counter = 0;

  CountPrinter(this._wrappee);

  @override
  String printMessage(String message) {
    counter++;
    final base = _wrappee.printMessage(message);
    return "($counter) $base";
  }
}

// Лаба 7
class ChatClient {
  final WebSocketChannel channel;

  ChatClient(String url) : channel = WebSocketChannel.connect(Uri.parse(url));

  void sendMessage(String text) {
    channel.sink.add(jsonEncode({"msg": text}));
  }

  Stream<String> get messages => channel.stream.map((data) {
    try {
      final decoded = jsonDecode(data);
      return decoded["msg"] ?? data;
    } catch (_) {
      return data.toString();
    }
  });

  void dispose() {
    channel.sink.close();
  }
}
