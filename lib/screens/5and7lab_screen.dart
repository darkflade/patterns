import 'package:flutter/material.dart';
import 'package:patterns/logic/5and7lab_logic.dart';

class Lab57Screen extends StatefulWidget {
  const Lab57Screen({super.key, required this.title, required this.ip, required this.nick});
  final String title;
  final String ip;
  final String nick;

  @override
  State<Lab57Screen> createState() => _Lab57ScreenState();
}

class _Lab57ScreenState extends State<Lab57Screen> {
  final _controller = TextEditingController();
  final List<String> _messages = [];
  late ChatClient _client;
  late MessagePrinter _printer;

  @override
  void initState() {
    super.initState();
    _client = ChatClient("ws://${widget.ip}/ws");
    _printer = CountPrinter(BorderPrinter(LogPrinter(SimplePrinter())));

    _client.messages.listen((msg) {
      setState(() {
        _messages.add("СЕРВЕР: $msg");
      });
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final decorated = _printer.printMessage("${widget.nick}: $text");
    _client.sendMessage(decorated);

    setState(() {
      _messages.add("КЛИЕНТ: $decorated");
      _controller.clear();
    });
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isClient = msg.startsWith("КЛИЕНТ");
                return Align(
                  alignment: isClient ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isClient ? Colors.deepPurple[100] : Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(msg),
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
