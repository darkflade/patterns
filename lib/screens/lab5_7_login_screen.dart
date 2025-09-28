import 'package:flutter/material.dart';
import '5and7lab_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.title});
  final String title;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nickController = TextEditingController();
  final _ipController = TextEditingController(text: "192.168.137.1:8080");

  void _enterChat() {
    final nick = _nickController.text.trim();
    final ip = _ipController.text.trim();

    if (nick.isEmpty || ip.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Lab57Screen(title: "Чат ($nick@$ip)", ip: ip, nick: nick),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nickController,
              decoration: const InputDecoration(
                labelText: "Введите ник",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: "IP:порт сервера",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _enterChat,
              icon: const Icon(Icons.login),
              label: const Text("Войти"),
            )
          ],
        ),
      ),
    );
  }
}
