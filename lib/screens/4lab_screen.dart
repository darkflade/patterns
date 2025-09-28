// 4lab_screen.dart
import 'package:flutter/material.dart';
import 'package:patterns/logic/4lab_logic.dart';

class Lab4Screen extends StatefulWidget {
  const Lab4Screen({super.key, required this.title});
  final String title;
  @override
  State<Lab4Screen> createState() => _Lab4ScreenState();
}

class _Lab4ScreenState extends State<Lab4Screen> {
  final _controller = TextEditingController();
  String _status = "Ожидание оплаты...";
  late PaymentAdapter _adapter;

  @override
  void initState() {
    super.initState();
    _adapter = PaymentAdapter(NewPaymentAPI(), currency: "USD");
  }

  void _processPayment() {
    final text = _controller.text;
    final amount = double.tryParse(text);
    if (amount == null) {
      setState(() {
        _status = "Некорректная сумма!";
      });
      return;
    }

    setState(() {
      _status = "Инициализация...";
    });

    _adapter.connect();
    _adapter.pay(amount);
    _adapter.disconnect();

    setState(() {
      _status = "Оплата $amount USD прошла успешно ✅";
    });
  }

  void _runTest() {
    final newApi = NewPaymentAPI();
    final testAdapter = PaymentAdapter(newApi, currency: "EUR");

    testAdapter.connect();
    testAdapter.pay(50.0);
    testAdapter.disconnect();

    setState(() {
      _status = "Тест прошёл: адаптер работает (EUR, 50.0)";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.credit_card, size: 80, color: Colors.teal),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Введите сумму",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _processPayment,
              icon: const Icon(Icons.payment),
              label: const Text("Оплатить"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _runTest,
              icon: const Icon(Icons.bug_report),
              label: const Text("Прогнать тест адаптера"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.teal),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _status,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
