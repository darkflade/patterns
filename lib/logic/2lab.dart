// Абстрактные продукты
abstract class Engine {
  String description();
}

abstract class Chassis {
  String description();
}

abstract class Gearbox {
  String description();
}

// Конкретные продукты для эконом-класса
class EconomyEngine implements Engine {
  @override
  String description() => "Двигатель эконом-класса";
}

class EconomyChassis implements Chassis {
  @override
  String description() => "Шасси эконом-класса";
}

class EconomyGearbox implements Gearbox {
  @override
  String description() => "Коробка передач эконом-класса";
}

// Конкретные продукты для премиум-класса
class PremiumEngine implements Engine {
  @override
  String description() => "Двигатель премиум-класса";
}

class PremiumChassis implements Chassis {
  @override
  String description() => "Шасси премиум-класса";
}

class PremiumGearbox implements Gearbox {
  @override
  String description() => "Коробка передач премиум-класса";
}

// Конкретные продукты для спорт-класса
class SportEngine implements Engine {
  @override
  String description() => "Двигатель спорт-класса";
}

class SportChassis implements Chassis {
  @override
  String description() => "Шасси спорт-класса";
}

class SportGearbox implements Gearbox {
  @override
  String description() => "Коробка передач спорт-класса";
}

// Абстрактная фабрика
abstract class CarFactory {
  Engine createEngine();
  Chassis createChassis();
  Gearbox createGearbox();
}

// Конкретные фабрики
class EconomyCarFactory implements CarFactory {
  @override
  Engine createEngine() => EconomyEngine();
  @override
  Chassis createChassis() => EconomyChassis();
  @override
  Gearbox createGearbox() => EconomyGearbox();
}

class PremiumCarFactory implements CarFactory {
  @override
  Engine createEngine() => PremiumEngine();
  @override
  Chassis createChassis() => PremiumChassis();
  @override
  Gearbox createGearbox() => PremiumGearbox();
}

class SportCarFactory implements CarFactory {
  @override
  Engine createEngine() => SportEngine();
  @override
  Chassis createChassis() => SportChassis();
  @override
  Gearbox createGearbox() => SportGearbox();
}

// Клиент
class CarKit {
  final Engine engine;
  final Chassis chassis;
  final Gearbox gearbox;

  CarKit(CarFactory factory)
      : engine = factory.createEngine(),
        chassis = factory.createChassis(),
        gearbox = factory.createGearbox();

  String info() {
    return "\n${engine.description()}\n${chassis.description()}\n${gearbox.description()}\n";
  }
}
