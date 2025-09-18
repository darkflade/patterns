import 'package:flutter/material.dart';
import '../logic/1lab_tv.dart';

class Lab1Screen extends StatefulWidget {
  const Lab1Screen({super.key, required this.title});

  final String title;

  @override
  State<Lab1Screen> createState() => _Lab1ScreenState();
}

class _Lab1ScreenState extends State<Lab1Screen> {
  List<TVStore> stores = [];
  List<TextEditingController> purchaseControllers = [];
  final newShopNameController = TextEditingController();
  final newPriceController = TextEditingController();


  @override
  void initState() {
    super.initState();
    // Add a default store to start with
    _addShopWithName("Эльдорадо");
  }

  void _changeTVPrice() {
    final newPrice = double.tryParse(newPriceController.text);
    if (newPrice != null) {
      setState(() {
      TVStore.tvPrice = newPrice;


      });
    } else {
      setState(() {

      });
    }

    newPriceController.clear();
  }

  void _addShop() {
    final shopName = newShopNameController.text;
    if (shopName.isNotEmpty) {
      _addShopWithName(shopName);
      newShopNameController.clear();
    }
  }

  void _addShopWithName(String name) {
    setState(() {
      final store = TVStore(name);
      stores.add(store);
      final controller = TextEditingController(text: ""/*store.purchases.toString()*/);
      controller.addListener(() {
        final purchases = int.tryParse(controller.text);
        if (purchases != null && purchases >= 0) {
          setState(() {
            store.purchases = purchases;
          });
        } else if (controller.text.isNotEmpty) {
           setState(() {});
        }
      });
      purchaseControllers.add(controller);
    });
  }

  @override
  void dispose() {
    newShopNameController.dispose();
    for (var controller in purchaseControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Row with text field and button to add new shop
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: newShopNameController,
                    decoration: const InputDecoration(
                      labelText: "Название нового магазина",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _addShop,
                  child: const Text("Добавить"),
                ),
              ],
            ),
            // Row with new Price
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: newPriceController,
                    keyboardType: TextInputType.number,
                    decoration:  InputDecoration(
                      labelText: "Новая цена",
                      border: OutlineInputBorder(),
                      errorText: () {
                        final text = newPriceController.text;
                        final value = double.tryParse(text);

                        if (text.isEmpty) return null; // ничего не пишем, ошибки нет
                        if (value == null) return "Надо число";
                        if (value <= 0) return "Надо число больше нуля";

                        return null; // всё ок
                      } (),

                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _changeTVPrice,
                  child: const Text("Изменить"),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: stores.length,
                itemBuilder: (context, index) {
                  final store = stores[index];
                  final purchaseController = purchaseControllers[index];


                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(store.storeName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: purchaseController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Кол-во покупок",
                              border: const OutlineInputBorder(),
                              errorText: (int.tryParse(purchaseController.text) == null && purchaseController.text.isNotEmpty)
                                  ? "Неверное число"
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Выручка: ${store.totalRevenue().toStringAsFixed(2)} руб.",
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}