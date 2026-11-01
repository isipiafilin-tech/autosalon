/// Перечисления предметной области. `value` — строка в PocketBase,
/// `label` — подпись в интерфейсе.
abstract interface class Labeled {
  String get value;
  String get label;
}

T parseEnum<T extends Labeled>(List<T> values, String value, T fallback) {
  for (final v in values) {
    if (v.value == value) return v;
  }
  return fallback;
}

List<(String, String)> optionsOf(List<Labeled> values) => [
  for (final v in values) (v.value, v.label),
];

enum Role implements Labeled {
  client('client', 'Клиент'),
  manager('manager', 'Менеджер'),
  admin('admin', 'Администратор');

  const Role(this.value, this.label);
  @override
  final String value;
  @override
  final String label;
}

enum BodyType implements Labeled {
  sedan('sedan', 'Седан'),
  hatchback('hatchback', 'Хэтчбек'),
  wagon('wagon', 'Универсал'),
  suv('suv', 'Внедорожник'),
  coupe('coupe', 'Купе'),
  minivan('minivan', 'Минивэн'),
  pickup('pickup', 'Пикап');

  const BodyType(this.value, this.label);
  @override
  final String value;
  @override
  final String label;
}

enum Engine implements Labeled {
  petrol('petrol', 'Бензин'),
  diesel('diesel', 'Дизель'),
  hybrid('hybrid', 'Гибрид'),
  electric('electric', 'Электро');

  const Engine(this.value, this.label);
  @override
  final String value;
  @override
  final String label;
}

enum Transmission implements Labeled {
  manual('manual', 'Механика'),
  automatic('automatic', 'Автомат'),
  robot('robot', 'Робот'),
  cvt('cvt', 'Вариатор');

  const Transmission(this.value, this.label);
  @override
  final String value;
  @override
  final String label;
}

enum CarStatus implements Labeled {
  available('available', 'В наличии'),
  reserved('reserved', 'Зарезервирован'),
  sold('sold', 'Продан');

  const CarStatus(this.value, this.label);
  @override
  final String value;
  @override
  final String label;
}

enum OptionCategory implements Labeled {
  comfort('comfort', 'Комфорт'),
  safety('safety', 'Безопасность'),
  multimedia('multimedia', 'Мультимедиа'),
  exterior('exterior', 'Внешний вид');

  const OptionCategory(this.value, this.label);
  @override
  final String value;
  @override
  final String label;
}

enum DealStatus implements Labeled {
  newDeal('new', 'Новая'),
  approved('approved', 'Одобрена'),
  signed('signed', 'Договор подписан'),
  cancelled('cancelled', 'Отменена');

  const DealStatus(this.value, this.label);
  @override
  final String value;
  @override
  final String label;
}

enum PaymentType implements Labeled {
  cash('cash', 'Наличные'),
  credit('credit', 'Кредит'),
  leasing('leasing', 'Лизинг');

  const PaymentType(this.value, this.label);
  @override
  final String value;
  @override
  final String label;
}

enum DriveStatus implements Labeled {
  planned('planned', 'Запланирован'),
  done('done', 'Проведён'),
  cancelled('cancelled', 'Отменён');

  const DriveStatus(this.value, this.label);
  @override
  final String value;
  @override
  final String label;
}
