class NewPaymentAPI {
  void startConnection() {
    print("NewPaymentAPI: соединение установлено");
  }

  void processPayment(double amount, String currency) {
    print("NewPaymentAPI: обработка платежа $amount $currency");
  }

  void endConnection() {
    print("NewPaymentAPI: соединение завершено");
  }
}

// Старый интерфейс, который ждет приложение
abstract class OldPaymentAPI {
  void connect();
  void pay(double amount);
  void disconnect();
}

// Адаптер, который притворяется старым, но под капотом юзает новый
class PaymentAdapter implements OldPaymentAPI {
  final NewPaymentAPI _newApi;
  final String currency;

  PaymentAdapter(this._newApi, {this.currency = "USD"});

  @override
  void connect() {
    _newApi.startConnection();
  }

  @override
  void pay(double amount) {
    _newApi.processPayment(amount, currency);
  }

  @override
  void disconnect() {
    _newApi.endConnection();
  }
}

// Для теста
void testPaymentAdapter() {
  final newApi = NewPaymentAPI();
  final adapter = PaymentAdapter(newApi, currency: "EUR");

  adapter.connect();
  adapter.pay(99.99);
  adapter.disconnect();
}
