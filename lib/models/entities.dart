import 'enums.dart';
import 'json_read.dart';

/// Запись коллекции PocketBase. Логически удалённая запись имеет [deletedAt].
abstract class Entity {
  String get id;
  DateTime? get deletedAt;
  bool get isDeleted => deletedAt != null;

  /// Краткое название для заголовков и подтверждений.
  String get title;

  /// Значения полей для формы редактирования (ключи — имена полей в базе).
  Map<String, dynamic> toFormValues();
}

String _brandModel(Json car) {
  final model = expandOne(car, 'model');
  final brand = expandOne(model, 'brand');
  return '${str(brand, 'name')} ${str(model, 'name')}'.trim();
}

class AppUser implements Entity {
  @override
  final String id;
  final String email;
  final String name;
  final String phone;
  final Role role;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.role,
  });

  factory AppUser.fromJson(Json j) => AppUser(
    id: str(j, 'id'),
    email: str(j, 'email'),
    name: str(j, 'name'),
    phone: str(j, 'phone'),
    role: parseEnum(Role.values, str(j, 'role'), Role.client),
  );

  Json toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'phone': phone,
    'role': role.value,
  };

  @override
  DateTime? get deletedAt => null;
  @override
  bool get isDeleted => false;
  @override
  String get title => name.isEmpty ? email : name;
  @override
  Map<String, dynamic> toFormValues() => {
    'name': name,
    'email': email,
    'phone': phone,
    'role': role.value,
  };
}

class Brand implements Entity {
  @override
  final String id;
  final String name;
  final String country;
  final int? foundedYear;
  final String description;
  @override
  final DateTime? deletedAt;

  const Brand({
    required this.id,
    required this.name,
    required this.country,
    this.foundedYear,
    this.description = '',
    this.deletedAt,
  });

  factory Brand.fromJson(Json j) => Brand(
    id: str(j, 'id'),
    name: str(j, 'name'),
    country: str(j, 'country'),
    foundedYear: integerOrNull(j, 'foundedYear'),
    description: str(j, 'description'),
    deletedAt: dateOf(j, 'deletedAt'),
  );

  @override
  bool get isDeleted => deletedAt != null;
  @override
  String get title => name;
  @override
  Map<String, dynamic> toFormValues() => {
    'name': name,
    'country': country,
    'foundedYear': foundedYear,
    'description': description,
  };
}

class CarModel implements Entity {
  @override
  final String id;
  final String brandId;
  final String brandName;
  final String name;
  final BodyType bodyType;
  final int? seats;
  @override
  final DateTime? deletedAt;

  const CarModel({
    required this.id,
    required this.brandId,
    required this.brandName,
    required this.name,
    required this.bodyType,
    this.seats,
    this.deletedAt,
  });

  factory CarModel.fromJson(Json j) => CarModel(
    id: str(j, 'id'),
    brandId: str(j, 'brand'),
    brandName: str(expandOne(j, 'brand'), 'name'),
    name: str(j, 'name'),
    bodyType: parseEnum(BodyType.values, str(j, 'bodyType'), BodyType.sedan),
    seats: integerOrNull(j, 'seats'),
    deletedAt: dateOf(j, 'deletedAt'),
  );

  @override
  bool get isDeleted => deletedAt != null;
  @override
  String get title => '$brandName $name'.trim();
  @override
  Map<String, dynamic> toFormValues() => {
    'brand': brandId,
    'name': name,
    'bodyType': bodyType.value,
    'seats': seats,
  };
}

class Car implements Entity {
  @override
  final String id;
  final String modelId;
  final String modelTitle;
  final BodyType bodyType;
  final String vin;
  final int year;
  final String color;
  final int mileage;
  final double price;
  final Engine engine;
  final Transmission transmission;
  final int? horsepower;
  final CarStatus status;
  final List<String> optionIds;
  final List<String> optionNames;
  @override
  final DateTime? deletedAt;

  const Car({
    required this.id,
    required this.modelId,
    required this.modelTitle,
    required this.bodyType,
    required this.vin,
    required this.year,
    required this.color,
    required this.mileage,
    required this.price,
    required this.engine,
    required this.transmission,
    this.horsepower,
    required this.status,
    this.optionIds = const [],
    this.optionNames = const [],
    this.deletedAt,
  });

  factory Car.fromJson(Json j) => Car(
    id: str(j, 'id'),
    modelId: str(j, 'model'),
    modelTitle: _brandModel(j),
    bodyType: parseEnum(
      BodyType.values,
      str(expandOne(j, 'model'), 'bodyType'),
      BodyType.sedan,
    ),
    vin: str(j, 'vin'),
    year: integer(j, 'year'),
    color: str(j, 'color'),
    mileage: integer(j, 'mileage'),
    price: dbl(j, 'price'),
    engine: parseEnum(Engine.values, str(j, 'engine'), Engine.petrol),
    transmission: parseEnum(
      Transmission.values,
      str(j, 'transmission'),
      Transmission.automatic,
    ),
    horsepower: integerOrNull(j, 'horsepower'),
    status: parseEnum(CarStatus.values, str(j, 'status'), CarStatus.available),
    optionIds: strList(j, 'options'),
    optionNames: [for (final o in expandMany(j, 'options')) str(o, 'name')],
    deletedAt: dateOf(j, 'deletedAt'),
  );

  @override
  bool get isDeleted => deletedAt != null;
  @override
  String get title => '$modelTitle, $year';
  bool get isNew => mileage == 0;
  @override
  Map<String, dynamic> toFormValues() => {
    'model': modelId,
    'vin': vin,
    'year': year,
    'color': color,
    'mileage': mileage,
    'price': price.round(),
    'engine': engine.value,
    'transmission': transmission.value,
    'horsepower': horsepower,
    'status': status.value,
    'options': optionIds,
  };
}

class CarOption implements Entity {
  @override
  final String id;
  final String name;
  final OptionCategory category;
  final double price;
  @override
  final DateTime? deletedAt;

  const CarOption({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.deletedAt,
  });

  factory CarOption.fromJson(Json j) => CarOption(
    id: str(j, 'id'),
    name: str(j, 'name'),
    category: parseEnum(
      OptionCategory.values,
      str(j, 'category'),
      OptionCategory.comfort,
    ),
    price: dbl(j, 'price'),
    deletedAt: dateOf(j, 'deletedAt'),
  );

  @override
  bool get isDeleted => deletedAt != null;
  @override
  String get title => name;
  @override
  Map<String, dynamic> toFormValues() => {
    'name': name,
    'category': category.value,
    'price': price.round(),
  };
}

class ExtraService implements Entity {
  @override
  final String id;
  final String name;
  final String description;
  final double price;
  @override
  final DateTime? deletedAt;

  const ExtraService({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.deletedAt,
  });

  factory ExtraService.fromJson(Json j) => ExtraService(
    id: str(j, 'id'),
    name: str(j, 'name'),
    description: str(j, 'description'),
    price: dbl(j, 'price'),
    deletedAt: dateOf(j, 'deletedAt'),
  );

  @override
  bool get isDeleted => deletedAt != null;
  @override
  String get title => name;
  @override
  Map<String, dynamic> toFormValues() => {
    'name': name,
    'description': description,
    'price': price.round(),
  };
}

class Customer implements Entity {
  @override
  final String id;
  final String userId;
  final String fullName;
  final String phone;
  final String email;
  final String city;
  final DateTime? birthDate;
  @override
  final DateTime? deletedAt;

  const Customer({
    required this.id,
    this.userId = '',
    required this.fullName,
    this.phone = '',
    this.email = '',
    this.city = '',
    this.birthDate,
    this.deletedAt,
  });

  factory Customer.fromJson(Json j) => Customer(
    id: str(j, 'id'),
    userId: str(j, 'user'),
    fullName: str(j, 'fullName'),
    phone: str(j, 'phone'),
    email: str(j, 'email'),
    city: str(j, 'city'),
    birthDate: dateOf(j, 'birthDate'),
    deletedAt: dateOf(j, 'deletedAt'),
  );

  @override
  bool get isDeleted => deletedAt != null;
  @override
  String get title => fullName;
  @override
  Map<String, dynamic> toFormValues() => {
    'fullName': fullName,
    'phone': phone,
    'email': email,
    'city': city,
    'birthDate': birthDate,
  };
}

class TestDrive implements Entity {
  @override
  final String id;
  final String carId;
  final String carTitle;
  final String customerId;
  final String customerName;
  final DateTime startsAt;
  final DateTime endsAt;
  final DriveStatus status;
  final String comment;
  @override
  final DateTime? deletedAt;

  const TestDrive({
    required this.id,
    required this.carId,
    required this.carTitle,
    required this.customerId,
    required this.customerName,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.comment = '',
    this.deletedAt,
  });

  factory TestDrive.fromJson(Json j) {
    final car = expandOne(j, 'car');
    return TestDrive(
      id: str(j, 'id'),
      carId: str(j, 'car'),
      carTitle: _brandModel(car),
      customerId: str(j, 'customer'),
      customerName: str(expandOne(j, 'customer'), 'fullName'),
      startsAt: dateOf(j, 'startsAt') ?? DateTime.fromMillisecondsSinceEpoch(0),
      endsAt: dateOf(j, 'endsAt') ?? DateTime.fromMillisecondsSinceEpoch(0),
      status: parseEnum(
        DriveStatus.values,
        str(j, 'status'),
        DriveStatus.planned,
      ),
      comment: str(j, 'comment'),
      deletedAt: dateOf(j, 'deletedAt'),
    );
  }

  @override
  bool get isDeleted => deletedAt != null;
  @override
  String get title => '$carTitle — $customerName';
  @override
  Map<String, dynamic> toFormValues() => {
    'car': carId,
    'customer': customerId,
    'startsAt': startsAt,
    'endsAt': endsAt,
    'status': status.value,
    'comment': comment,
  };
}

class Deal implements Entity {
  @override
  final String id;
  final String customerId;
  final String customerName;
  final String carId;
  final String carTitle;
  final double carPrice;
  final String managerId;
  final String managerName;
  final List<String> serviceIds;
  final List<String> serviceNames;
  final DealStatus status;
  final PaymentType paymentType;
  final double discountPercent;
  final double tradeInValue;
  final double downPayment;
  final int termMonths;
  final double totalPrice;
  final String note;
  final DateTime? created;
  @override
  final DateTime? deletedAt;

  const Deal({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.carId,
    required this.carTitle,
    required this.carPrice,
    this.managerId = '',
    this.managerName = '',
    this.serviceIds = const [],
    this.serviceNames = const [],
    required this.status,
    required this.paymentType,
    this.discountPercent = 0,
    this.tradeInValue = 0,
    this.downPayment = 0,
    this.termMonths = 0,
    required this.totalPrice,
    this.note = '',
    this.created,
    this.deletedAt,
  });

  factory Deal.fromJson(Json j) {
    final car = expandOne(j, 'car');
    return Deal(
      id: str(j, 'id'),
      customerId: str(j, 'customer'),
      customerName: str(expandOne(j, 'customer'), 'fullName'),
      carId: str(j, 'car'),
      carTitle: _brandModel(car),
      carPrice: dbl(car, 'price'),
      managerId: str(j, 'manager'),
      managerName: str(expandOne(j, 'manager'), 'name'),
      serviceIds: strList(j, 'services'),
      serviceNames: [for (final s in expandMany(j, 'services')) str(s, 'name')],
      status: parseEnum(
        DealStatus.values,
        str(j, 'status'),
        DealStatus.newDeal,
      ),
      paymentType: parseEnum(
        PaymentType.values,
        str(j, 'paymentType'),
        PaymentType.cash,
      ),
      discountPercent: dbl(j, 'discountPercent'),
      tradeInValue: dbl(j, 'tradeInValue'),
      downPayment: dbl(j, 'downPayment'),
      termMonths: integer(j, 'termMonths'),
      totalPrice: dbl(j, 'totalPrice'),
      note: str(j, 'note'),
      created: dateOf(j, 'created'),
      deletedAt: dateOf(j, 'deletedAt'),
    );
  }

  @override
  bool get isDeleted => deletedAt != null;
  @override
  String get title => '$customerName — $carTitle';
  @override
  Map<String, dynamic> toFormValues() => {
    'customer': customerId,
    'car': carId,
    'services': serviceIds,
    'paymentType': paymentType.value,
    'discountPercent': discountPercent,
    'tradeInValue': tradeInValue.round(),
    'downPayment': downPayment.round(),
    'termMonths': termMonths,
    'note': note,
  };
}

class Contract implements Entity {
  @override
  final String id;
  final String dealId;
  final String dealTitle;
  final String number;
  final DateTime signedAt;
  final double amount;
  final int warrantyMonths;
  @override
  final DateTime? deletedAt;

  const Contract({
    required this.id,
    required this.dealId,
    required this.dealTitle,
    required this.number,
    required this.signedAt,
    required this.amount,
    this.warrantyMonths = 0,
    this.deletedAt,
  });

  factory Contract.fromJson(Json j) {
    final deal = expandOne(j, 'deal');
    final customer = str(expandOne(deal, 'customer'), 'fullName');
    final car = _brandModel(expandOne(deal, 'car'));
    return Contract(
      id: str(j, 'id'),
      dealId: str(j, 'deal'),
      dealTitle: '$customer — $car',
      number: str(j, 'number'),
      signedAt: dateOf(j, 'signedAt') ?? DateTime.fromMillisecondsSinceEpoch(0),
      amount: dbl(j, 'amount'),
      warrantyMonths: integer(j, 'warrantyMonths'),
      deletedAt: dateOf(j, 'deletedAt'),
    );
  }

  @override
  bool get isDeleted => deletedAt != null;
  @override
  String get title => number.isEmpty ? 'Договор' : 'Договор $number';
  @override
  Map<String, dynamic> toFormValues() => {
    'deal': dealId,
    'number': number,
    'signedAt': signedAt,
    'amount': amount.round(),
    'warrantyMonths': warrantyMonths,
  };
}
