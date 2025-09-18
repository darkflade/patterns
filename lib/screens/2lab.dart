import 'package:flutter/material.dart';
import '../logic/2lab.dart';

class Lab2Screen extends StatefulWidget {
  const Lab2Screen({super.key, required this.title});
  final String title;

  @override
  State<Lab2Screen> createState() => _Lab2ScreenState();
}

class _Lab2ScreenState extends State<Lab2Screen> {
  String result = "";
  String selectedBrand = "Эконом";

  void _createCarKit() {
    CarFactory factory;

    switch (selectedBrand) {
      case "Эконом":
        factory = EconomyCarFactory();
        break;
      case "Премиум":
        factory = PremiumCarFactory();
        break;
      case "Спорт":
        factory = SportCarFactory();
        break;
      default:
        factory = EconomyCarFactory();
    }

    final kit = CarKit(factory);

    setState(() {
      result = "Комплект ${selectedBrand}-класса:\n${kit.info()}";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Text("Выберите бренд автомобиля:"),
            const SizedBox(height: 10),
            DropdownButton<String>(
              value: selectedBrand,
              items: ["Эконом", "Премиум", "Спорт"]
                  .map((brand) => DropdownMenuItem(
                value: brand,
                child: Text(brand),
              ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedBrand = value!;
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _createCarKit,
              child: const Text("Создать комплект запчастей"),
            ),
            const SizedBox(height: 20),
            Text(
              result,
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
