import 'package:flutter/material.dart';
import 'project_screen.dart';

class ProjectLoginScreen extends StatefulWidget {
  const ProjectLoginScreen({super.key, required this.title});
  final String title;
  @override
  State<ProjectLoginScreen> createState() => _ProjectLoginScreenState();
}

class _ProjectLoginScreenState extends State<ProjectLoginScreen> {
  final _nickController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ipController = TextEditingController(text: "192.168.1.4:8080");

  void _enterChat() {
    final nick = _nickController.text.trim();
    final password = _passwordController.text.trim();
    final ip = _ipController.text.trim();

    if (nick.isEmpty || ip.isEmpty || password.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectScreen(title: "Чат ($nick@$ip)", ip: ip, username: nick, password: password),
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
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: "Введите пароль",
                border: OutlineInputBorder(),
              ),
              obscureText: true,
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
