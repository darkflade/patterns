abstract class Store {
  String get storeName;
  set purchases(int value);
  double totalRevenue();
}

class TVStore implements Store {
  static double _tvPrice = 500;

  static set tvPrice(double value) {
    if (value > 0) {
      _tvPrice = value;
    }
  }

  @override
  final String storeName;
  int _purchases = 0;

  TVStore(this.storeName);

  @override
  set purchases(int value) {
    if (value >= 0) _purchases = value;
  }

  @override
  double totalRevenue() {
    return _tvPrice * _purchases;
  }
}
