import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/entities.dart';
import '../models/enums.dart';
import '../models/permissions.dart';
import '../validation/validators.dart';
import '../widgets/dialogs.dart';
import '../widgets/form_fields.dart';
import 'detail_actions.dart';
import 'entity_config.dart';

Color _green() => Colors.green.shade700;

Color carStatusColor(CarStatus s) => switch (s) {
  CarStatus.available => _green(),
  CarStatus.reserved => Colors.orange.shade800,
  CarStatus.sold => Colors.blueGrey,
};

Color dealStatusColor(DealStatus s) => switch (s) {
  DealStatus.newDeal => Colors.blue.shade700,
  DealStatus.approved => Colors.teal.shade700,
  DealStatus.signed => _green(),
  DealStatus.cancelled => Colors.red.shade700,
};

Color driveStatusColor(DriveStatus s) => switch (s) {
  DriveStatus.planned => Colors.blue.shade700,
  DriveStatus.done => _green(),
  DriveStatus.cancelled => Colors.blueGrey,
};

Widget _chip(String label, Color color) => StatusChip(label, color: color);

final brandsConfig = EntityConfig<Brand>(
  key: 'brands',
  path: '/brands',
  title: 'Марки',
  singular: 'Марка',
  repo: (r) => r.brands,
  manage: Permission.manageDictionaries,
  sorts: const [
    ('name', 'Название: А–Я'),
    ('-name', 'Название: Я–А'),
    ('foundedYear', 'Год основания'),
  ],
  columns: [
    ColumnSpec('Название', (e) => e.name),
    ColumnSpec('Страна', (e) => e.country),
    ColumnSpec(
      'Основана',
      (e) => e.foundedYear?.toString() ?? '—',
      numeric: true,
    ),
  ],
  cardTitle: (e) => e.name,
  cardSubtitle: (e) => e.country,
  details: [
    ('Название', (e) => e.name),
    ('Страна', (e) => e.country),
    ('Год основания', (e) => e.foundedYear?.toString() ?? ''),
    ('Описание', (e) => e.description),
  ],
  fields: [
    FieldSpec(
      'name',
      'Название',
      FieldKind.text,
      required: true,
      validators: [minLength(2), maxLength(60)],
    ),
    FieldSpec(
      'country',
      'Страна',
      FieldKind.text,
      required: true,
      validators: [minLength(2), maxLength(60)],
    ),
    FieldSpec(
      'foundedYear',
      'Год основания',
      FieldKind.integer,
      validators: [intRange(1850, 2100)],
    ),
    FieldSpec(
      'description',
      'Описание',
      FieldKind.multiline,
      validators: [maxLength(500)],
    ),
  ],
  lookups: const ['brands', 'models'],
);

final modelsConfig = EntityConfig<CarModel>(
  key: 'models',
  path: '/models',
  title: 'Модели',
  singular: 'Модель',
  repo: (r) => r.models,
  manage: Permission.manageCars,
  sorts: const [
    ('name', 'Название: А–Я'),
    ('-name', 'Название: Я–А'),
    ('-created', 'Сначала новые'),
  ],
  columns: [
    ColumnSpec('Марка', (e) => e.brandName),
    ColumnSpec('Модель', (e) => e.name),
    ColumnSpec('Кузов', (e) => e.bodyType.label),
    ColumnSpec('Мест', (e) => e.seats?.toString() ?? '—', numeric: true),
  ],
  cardTitle: (e) => e.title,
  cardSubtitle: (e) => e.bodyType.label,
  details: [
    ('Марка', (e) => e.brandName),
    ('Модель', (e) => e.name),
    ('Кузов', (e) => e.bodyType.label),
    ('Мест', (e) => e.seats?.toString() ?? ''),
  ],
  fields: [
    FieldSpec(
      'brand',
      'Марка',
      FieldKind.relation,
      required: true,
      lookup: 'brands',
    ),
    FieldSpec(
      'name',
      'Название модели',
      FieldKind.text,
      required: true,
      validators: [maxLength(60)],
    ),
    FieldSpec(
      'bodyType',
      'Тип кузова',
      FieldKind.select,
      required: true,
      options: optionsOf(BodyType.values),
    ),
    FieldSpec(
      'seats',
      'Число мест',
      FieldKind.integer,
      validators: [intRange(2, 9)],
    ),
  ],
  lookups: const ['models'],
);

final carsConfig = EntityConfig<Car>(
  key: 'cars',
  path: '/cars',
  title: 'Каталог автомобилей',
  singular: 'Автомобиль',
  repo: (r) => r.cars,
  manage: Permission.manageCars,
  sorts: const [
    ('-created', 'Сначала новые записи'),
    ('price', 'Цена: по возрастанию'),
    ('-price', 'Цена: по убыванию'),
    ('-year', 'Год: новее'),
    ('mileage', 'Пробег: меньше'),
  ],
  columns: [
    ColumnSpec('Автомобиль', (e) => e.modelTitle),
    ColumnSpec('Год', (e) => '${e.year}', numeric: true, inCard: false),
    ColumnSpec(
      'Пробег',
      (e) => e.isNew ? 'новый' : kilometers(e.mileage),
      numeric: true,
    ),
    ColumnSpec('Цена', (e) => money(e.price), numeric: true),
    ColumnSpec('Двигатель', (e) => e.engine.label, inCard: false),
    ColumnSpec('Коробка', (e) => e.transmission.label, inCard: false),
    ColumnSpec(
      'Статус',
      (e) => e.status.label,
      cell: (context, e) => _chip(e.status.label, carStatusColor(e.status)),
    ),
  ],
  cardTitle: (e) => e.modelTitle,
  cardSubtitle: (e) =>
      '${e.year} · ${e.color.isEmpty ? 'цвет не указан' : e.color} · ${e.engine.label}, ${e.transmission.label}',
  details: [
    ('Автомобиль', (e) => e.modelTitle),
    ('Кузов', (e) => e.bodyType.label),
    ('VIN', (e) => e.vin),
    ('Год выпуска', (e) => '${e.year}'),
    ('Цвет', (e) => e.color),
    ('Пробег', (e) => e.isNew ? 'новый' : kilometers(e.mileage)),
    ('Двигатель', (e) => e.engine.label),
    ('Коробка', (e) => e.transmission.label),
    ('Мощность', (e) => e.horsepower == null ? '' : '${e.horsepower} л. с.'),
    ('Статус', (e) => e.status.label),
    ('Цена', (e) => money(e.price)),
    ('Опции', (e) => e.optionNames.join(', ')),
  ],
  detailExtra: (context, e, reload) => CarActions(car: e, reload: reload),
  fields: [
    FieldSpec(
      'model',
      'Модель',
      FieldKind.relation,
      required: true,
      lookup: 'models',
    ),
    FieldSpec(
      'vin',
      'VIN',
      FieldKind.text,
      required: true,
      validators: [vin()],
      hint: 'Например, XTA210930Y1234567',
    ),
    FieldSpec(
      'year',
      'Год выпуска',
      FieldKind.integer,
      required: true,
      validators: [intRange(1990, 2100)],
    ),
    FieldSpec('color', 'Цвет', FieldKind.text, validators: [maxLength(40)]),
    FieldSpec(
      'mileage',
      'Пробег, км',
      FieldKind.integer,
      validators: [intRange(0, 2000000)],
    ),
    FieldSpec(
      'price',
      'Цена, ₽',
      FieldKind.integer,
      required: true,
      validators: [intRange(100000, 100000000)],
    ),
    FieldSpec(
      'engine',
      'Двигатель',
      FieldKind.select,
      required: true,
      options: optionsOf(Engine.values),
    ),
    FieldSpec(
      'transmission',
      'Коробка передач',
      FieldKind.select,
      required: true,
      options: optionsOf(Transmission.values),
    ),
    FieldSpec(
      'horsepower',
      'Мощность, л. с.',
      FieldKind.integer,
      validators: [intRange(30, 2000)],
    ),
    FieldSpec(
      'status',
      'Статус',
      FieldKind.select,
      required: true,
      options: optionsOf(CarStatus.values),
    ),
    FieldSpec('options', 'Опции', FieldKind.relationMulti, lookup: 'options'),
  ],
  prepare: (json, isNew) => {...json, 'vin': '${json['vin']}'.toUpperCase()},
  lookups: const ['cars', 'carsFree'],
);

final optionsConfig = EntityConfig<CarOption>(
  key: 'options',
  path: '/options',
  title: 'Опции комплектации',
  singular: 'Опция',
  repo: (r) => r.options,
  manage: Permission.manageDictionaries,
  sorts: const [
    ('name', 'Название: А–Я'),
    ('price', 'Цена: по возрастанию'),
    ('-price', 'Цена: по убыванию'),
  ],
  columns: [
    ColumnSpec('Название', (e) => e.name),
    ColumnSpec('Категория', (e) => e.category.label),
    ColumnSpec('Цена', (e) => money(e.price), numeric: true),
  ],
  cardTitle: (e) => e.name,
  cardSubtitle: (e) => e.category.label,
  details: [
    ('Название', (e) => e.name),
    ('Категория', (e) => e.category.label),
    ('Цена', (e) => money(e.price)),
  ],
  fields: [
    FieldSpec(
      'name',
      'Название',
      FieldKind.text,
      required: true,
      validators: [minLength(2), maxLength(80)],
    ),
    FieldSpec(
      'category',
      'Категория',
      FieldKind.select,
      required: true,
      options: optionsOf(OptionCategory.values),
    ),
    FieldSpec(
      'price',
      'Цена, ₽',
      FieldKind.integer,
      required: true,
      validators: [intRange(0, 5000000)],
    ),
  ],
  lookups: const ['options'],
);

final servicesConfig = EntityConfig<ExtraService>(
  key: 'services',
  path: '/services',
  title: 'Дополнительные услуги',
  singular: 'Услуга',
  repo: (r) => r.services,
  manage: Permission.manageDictionaries,
  sorts: const [
    ('name', 'Название: А–Я'),
    ('price', 'Цена: по возрастанию'),
    ('-price', 'Цена: по убыванию'),
  ],
  columns: [
    ColumnSpec('Название', (e) => e.name),
    ColumnSpec('Описание', (e) => e.description, inCard: false),
    ColumnSpec('Цена', (e) => money(e.price), numeric: true),
  ],
  cardTitle: (e) => e.name,
  cardSubtitle: (e) => e.description,
  details: [
    ('Название', (e) => e.name),
    ('Описание', (e) => e.description),
    ('Цена', (e) => money(e.price)),
  ],
  fields: [
    FieldSpec(
      'name',
      'Название',
      FieldKind.text,
      required: true,
      validators: [minLength(2), maxLength(80)],
    ),
    FieldSpec(
      'description',
      'Описание',
      FieldKind.multiline,
      validators: [maxLength(300)],
    ),
    FieldSpec(
      'price',
      'Цена, ₽',
      FieldKind.integer,
      required: true,
      validators: [intRange(0, 1000000)],
    ),
  ],
  lookups: const ['services'],
);

final customersConfig = EntityConfig<Customer>(
  key: 'customers',
  path: '/customers',
  title: 'Клиенты',
  singular: 'Клиент',
  repo: (r) => r.customers,
  manage: Permission.manageCustomers,
  sorts: const [
    ('fullName', 'ФИО: А–Я'),
    ('-fullName', 'ФИО: Я–А'),
    ('-created', 'Сначала новые'),
  ],
  columns: [
    ColumnSpec('ФИО', (e) => e.fullName),
    ColumnSpec('Телефон', (e) => e.phone.isEmpty ? '—' : e.phone),
    ColumnSpec('Почта', (e) => e.email.isEmpty ? '—' : e.email, inCard: false),
    ColumnSpec('Город', (e) => e.city.isEmpty ? '—' : e.city),
    ColumnSpec(
      'Учётная запись',
      (e) => e.userId.isEmpty ? 'нет' : 'есть',
      inCard: false,
    ),
  ],
  cardTitle: (e) => e.fullName,
  cardSubtitle: (e) => e.email,
  details: [
    ('ФИО', (e) => e.fullName),
    ('Телефон', (e) => e.phone),
    ('Почта', (e) => e.email),
    ('Город', (e) => e.city),
    (
      'Дата рождения',
      (e) => e.birthDate == null ? '' : formatDate(e.birthDate!),
    ),
    ('Учётная запись', (e) => e.userId.isEmpty ? 'нет' : 'есть'),
  ],
  fields: [
    FieldSpec(
      'fullName',
      'ФИО',
      FieldKind.text,
      required: true,
      validators: [minLength(5), maxLength(120)],
    ),
    FieldSpec(
      'phone',
      'Телефон',
      FieldKind.text,
      validators: [phone()],
      hint: '+7 (900) 123-45-67',
    ),
    FieldSpec('email', 'Почта', FieldKind.text, validators: [email()]),
    FieldSpec('city', 'Город', FieldKind.text, validators: [maxLength(60)]),
    FieldSpec('birthDate', 'Дата рождения', FieldKind.date),
  ],
  lookups: const ['customers'],
);

final testDrivesConfig = EntityConfig<TestDrive>(
  key: 'test-drives',
  path: '/test-drives',
  title: 'Тест-драйвы',
  singular: 'Тест-драйв',
  repo: (r) => r.testDrives,
  manage: Permission.manageTestDrives,
  sorts: const [
    ('-startsAt', 'Позже сначала'),
    ('startsAt', 'Раньше сначала'),
    ('-created', 'Недавно созданные'),
  ],
  columns: [
    ColumnSpec('Автомобиль', (e) => e.carTitle),
    ColumnSpec('Клиент', (e) => e.customerName),
    ColumnSpec('Начало', (e) => formatDateTime(e.startsAt)),
    ColumnSpec('Окончание', (e) => formatTime(e.endsAt), inCard: false),
    ColumnSpec(
      'Статус',
      (e) => e.status.label,
      cell: (context, e) => _chip(e.status.label, driveStatusColor(e.status)),
    ),
  ],
  cardTitle: (e) => e.carTitle,
  cardSubtitle: (e) => e.customerName,
  details: [
    ('Автомобиль', (e) => e.carTitle),
    ('Клиент', (e) => e.customerName),
    ('Начало', (e) => formatDateTime(e.startsAt)),
    ('Окончание', (e) => formatDateTime(e.endsAt)),
    ('Статус', (e) => e.status.label),
    ('Комментарий', (e) => e.comment),
  ],
  detailExtra: (context, e, reload) => DriveActions(drive: e, reload: reload),
  lookups: const [],
);

final dealsConfig = EntityConfig<Deal>(
  key: 'deals',
  path: '/deals',
  title: 'Сделки',
  singular: 'Сделка',
  repo: (r) => r.deals,
  manage: Permission.manageDeals,
  canEdit: false,
  sorts: const [
    ('-created', 'Сначала новые'),
    ('-totalPrice', 'Сумма: по убыванию'),
    ('totalPrice', 'Сумма: по возрастанию'),
  ],
  columns: [
    ColumnSpec('Клиент', (e) => e.customerName),
    ColumnSpec('Автомобиль', (e) => e.carTitle),
    ColumnSpec('Сумма', (e) => money(e.totalPrice), numeric: true),
    ColumnSpec('Оплата', (e) => e.paymentType.label, inCard: false),
    ColumnSpec(
      'Менеджер',
      (e) => e.managerName.isEmpty ? '—' : e.managerName,
      inCard: false,
    ),
    ColumnSpec(
      'Статус',
      (e) => e.status.label,
      cell: (context, e) => _chip(e.status.label, dealStatusColor(e.status)),
    ),
  ],
  cardTitle: (e) => e.carTitle,
  cardSubtitle: (e) => e.customerName,
  details: dealDetails,
  detailExtra: (context, e, reload) => DealActions(deal: e, reload: reload),
  lookups: const ['cars', 'carsFree', 'dealsApproved'],
);

final List<(String, String Function(Deal))> dealDetails = [
  ('Клиент', (e) => e.customerName),
  ('Автомобиль', (e) => e.carTitle),
  ('Цена автомобиля', (e) => money(e.carPrice)),
  ('Услуги', (e) => e.serviceNames.join(', ')),
  ('Оплата', (e) => e.paymentType.label),
  ('Скидка', (e) => e.discountPercent == 0 ? '' : '${e.discountPercent} %'),
  (
    'Зачёт старого авто',
    (e) => e.tradeInValue == 0 ? '' : money(e.tradeInValue),
  ),
  (
    'Первоначальный взнос',
    (e) => e.downPayment == 0 ? '' : money(e.downPayment),
  ),
  ('Срок кредита', (e) => e.termMonths == 0 ? '' : '${e.termMonths} мес.'),
  ('Итоговая сумма', (e) => money(e.totalPrice)),
  ('Менеджер', (e) => e.managerName),
  ('Статус', (e) => e.status.label),
  ('Примечание', (e) => e.note),
];

final contractsConfig = EntityConfig<Contract>(
  key: 'contracts',
  path: '/contracts',
  title: 'Договоры',
  singular: 'Договор',
  repo: (r) => r.contracts,
  manage: Permission.manageContracts,
  canEdit: false,
  sorts: const [
    ('-signedAt', 'Позже сначала'),
    ('signedAt', 'Раньше сначала'),
    ('-amount', 'Сумма: по убыванию'),
  ],
  columns: [
    ColumnSpec('Номер', (e) => e.number),
    ColumnSpec('Сделка', (e) => e.dealTitle),
    ColumnSpec('Дата', (e) => formatDate(e.signedAt)),
    ColumnSpec('Сумма', (e) => money(e.amount), numeric: true),
    ColumnSpec(
      'Гарантия',
      (e) => '${e.warrantyMonths} мес.',
      numeric: true,
      inCard: false,
    ),
  ],
  cardTitle: (e) => e.title,
  cardSubtitle: (e) => e.dealTitle,
  details: [
    ('Номер', (e) => e.number),
    ('Сделка', (e) => e.dealTitle),
    ('Дата подписания', (e) => formatDate(e.signedAt)),
    ('Сумма', (e) => money(e.amount)),
    ('Гарантия', (e) => '${e.warrantyMonths} мес.'),
  ],
  lookups: const ['dealsApproved'],
);

final usersConfig = EntityConfig<AppUser>(
  key: 'users',
  path: '/admin/users',
  title: 'Пользователи',
  singular: 'Пользователь',
  repo: (r) => r.users,
  manage: Permission.manageUsers,
  purge: null,
  hasDetail: false,
  sorts: const [
    ('-created', 'Сначала новые'),
    ('name', 'Имя: А–Я'),
    ('role', 'По роли'),
  ],
  columns: [
    ColumnSpec('Имя', (e) => e.name),
    ColumnSpec('Почта', (e) => e.email),
    ColumnSpec(
      'Телефон',
      (e) => e.phone.isEmpty ? '—' : e.phone,
      inCard: false,
    ),
    ColumnSpec(
      'Роль',
      (e) => e.role.label,
      cell: (context, e) => _chip(e.role.label, switch (e.role) {
        Role.admin => Colors.deepPurple,
        Role.manager => Colors.teal.shade700,
        Role.client => Colors.blue.shade700,
      }),
    ),
  ],
  cardTitle: (e) => e.name.isEmpty ? e.email : e.name,
  cardSubtitle: (e) => e.email,
  fields: [
    FieldSpec(
      'name',
      'ФИО',
      FieldKind.text,
      required: true,
      validators: [minLength(5), maxLength(120)],
    ),
    FieldSpec(
      'email',
      'Почта',
      FieldKind.text,
      required: true,
      validators: [email()],
    ),
    FieldSpec('phone', 'Телефон', FieldKind.text, validators: [phone()]),
    FieldSpec(
      'role',
      'Роль',
      FieldKind.select,
      required: true,
      options: optionsOf(Role.values),
    ),
    FieldSpec(
      'password',
      'Пароль',
      FieldKind.password,
      required: true,
      createOnly: true,
      validators: [strongPassword()],
    ),
  ],
  prepare: (json, isNew) => isNew
      ? {...json, 'passwordConfirm': json['password'], 'emailVisibility': true}
      : json,
  lookups: const ['managers'],
);

/// Сущности, у которых есть корзина: нужны разделу «Корзина».
final List<EntityConfig<dynamic>> trashConfigs = [
  carsConfig,
  modelsConfig,
  brandsConfig,
  optionsConfig,
  servicesConfig,
  customersConfig,
  dealsConfig,
  testDrivesConfig,
  contractsConfig,
];
