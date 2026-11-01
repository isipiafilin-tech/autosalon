import '../core/pb_api.dart';
import '../models/entities.dart';
import '../models/enums.dart';
import '../models/list_query.dart';
import 'entity_repository.dart';

/// Все репозитории приложения. Создаётся один раз и передаётся через Provider.
class Repos {
  final PbApi api;

  final EntityRepository<Brand> brands;
  final EntityRepository<CarModel> models;
  final EntityRepository<Car> cars;
  final EntityRepository<CarOption> options;
  final EntityRepository<ExtraService> services;
  final EntityRepository<Customer> customers;
  final EntityRepository<TestDrive> testDrives;
  final EntityRepository<Deal> deals;
  final EntityRepository<Contract> contracts;
  final EntityRepository<AppUser> users;

  Repos(this.api)
    : brands = PbRepository<Brand>(
        api,
        collection: 'brands',
        fromJson: Brand.fromJson,
        searchFields: const ['name', 'country'],
        defaultSort: 'name',
        filters: const [
          FilterSpec.contains('country', 'Страна', 'country'),
          FilterSpec.min('yearMin', 'Основана не раньше', 'foundedYear'),
          FilterSpec.max('yearMax', 'Основана не позже', 'foundedYear'),
        ],
      ),
      models = PbRepository<CarModel>(
        api,
        collection: 'car_models',
        fromJson: CarModel.fromJson,
        searchFields: const ['name', 'brand.name'],
        expand: 'brand',
        defaultSort: 'name',
        filters: [
          const FilterSpec.relation('brand', 'Марка', 'brand', 'brands'),
          FilterSpec.select(
            'body',
            'Кузов',
            'bodyType',
            optionsOf(BodyType.values),
          ),
          const FilterSpec.min('seats', 'Мест не меньше', 'seats'),
        ],
      ),
      cars = PbRepository<Car>(
        api,
        collection: 'cars',
        fromJson: Car.fromJson,
        searchFields: const ['vin', 'color', 'model.name', 'model.brand.name'],
        expand: 'model.brand,options',
        filters: [
          const FilterSpec.relation('brand', 'Марка', 'model.brand', 'brands'),
          FilterSpec.select(
            'body',
            'Кузов',
            'model.bodyType',
            optionsOf(BodyType.values),
          ),
          FilterSpec.select(
            'engine',
            'Двигатель',
            'engine',
            optionsOf(Engine.values),
          ),
          FilterSpec.select(
            'gear',
            'Коробка',
            'transmission',
            optionsOf(Transmission.values),
          ),
          FilterSpec.select(
            'status',
            'Статус',
            'status',
            optionsOf(CarStatus.values),
          ),
          const FilterSpec.min('priceMin', 'Цена от', 'price'),
          const FilterSpec.max('priceMax', 'Цена до', 'price'),
          const FilterSpec.min('yearMin', 'Год от', 'year'),
          const FilterSpec.max('yearMax', 'Год до', 'year'),
        ],
      ),
      options = PbRepository<CarOption>(
        api,
        collection: 'options',
        fromJson: CarOption.fromJson,
        searchFields: const ['name'],
        defaultSort: 'name',
        filters: [
          FilterSpec.select(
            'category',
            'Категория',
            'category',
            optionsOf(OptionCategory.values),
          ),
          const FilterSpec.min('priceMin', 'Цена от', 'price'),
          const FilterSpec.max('priceMax', 'Цена до', 'price'),
        ],
      ),
      services = PbRepository<ExtraService>(
        api,
        collection: 'services',
        fromJson: ExtraService.fromJson,
        searchFields: const ['name', 'description'],
        defaultSort: 'name',
        filters: const [
          FilterSpec.min('priceMin', 'Цена от', 'price'),
          FilterSpec.max('priceMax', 'Цена до', 'price'),
        ],
      ),
      customers = PbRepository<Customer>(
        api,
        collection: 'customers',
        fromJson: Customer.fromJson,
        searchFields: const ['fullName', 'phone', 'email', 'city'],
        defaultSort: 'fullName',
        filters: const [
          FilterSpec.contains('city', 'Город', 'city'),
          FilterSpec.dateFrom('bornFrom', 'Родился с', 'birthDate'),
          FilterSpec.dateTo('bornTo', 'Родился по', 'birthDate'),
        ],
      ),
      testDrives = PbRepository<TestDrive>(
        api,
        collection: 'test_drives',
        fromJson: TestDrive.fromJson,
        searchFields: const ['car.vin', 'car.model.name', 'customer.fullName'],
        expand: 'car.model.brand,customer',
        defaultSort: '-startsAt',
        filters: [
          FilterSpec.select(
            'status',
            'Статус',
            'status',
            optionsOf(DriveStatus.values),
          ),
          const FilterSpec.relation('car', 'Автомобиль', 'car', 'cars'),
          const FilterSpec.relation(
            'customer',
            'Клиент',
            'customer',
            'customers',
          ),
          const FilterSpec.dateFrom('from', 'С даты', 'startsAt'),
          const FilterSpec.dateTo('to', 'По дату', 'startsAt'),
        ],
      ),
      deals = PbRepository<Deal>(
        api,
        collection: 'deals',
        fromJson: Deal.fromJson,
        searchFields: const [
          'customer.fullName',
          'car.vin',
          'car.model.name',
          'note',
        ],
        expand: 'customer,car.model.brand,manager,services',
        filters: [
          FilterSpec.select(
            'status',
            'Статус',
            'status',
            optionsOf(DealStatus.values),
          ),
          FilterSpec.select(
            'payment',
            'Оплата',
            'paymentType',
            optionsOf(PaymentType.values),
          ),
          const FilterSpec.relation(
            'manager',
            'Менеджер',
            'manager',
            'managers',
          ),
          const FilterSpec.relation(
            'customer',
            'Клиент',
            'customer',
            'customers',
          ),
          const FilterSpec.min('priceMin', 'Сумма от', 'totalPrice'),
          const FilterSpec.max('priceMax', 'Сумма до', 'totalPrice'),
        ],
      ),
      contracts = PbRepository<Contract>(
        api,
        collection: 'contracts',
        fromJson: Contract.fromJson,
        searchFields: const ['number', 'deal.customer.fullName'],
        expand: 'deal.customer,deal.car.model.brand',
        defaultSort: '-signedAt',
        filters: const [
          FilterSpec.dateFrom('from', 'Подписан с', 'signedAt'),
          FilterSpec.dateTo('to', 'Подписан по', 'signedAt'),
          FilterSpec.min('amountMin', 'Сумма от', 'amount'),
          FilterSpec.max('amountMax', 'Сумма до', 'amount'),
        ],
      ),
      users = PbRepository<AppUser>(
        api,
        collection: 'users',
        fromJson: AppUser.fromJson,
        searchFields: const ['name', 'email'],
        softDeletable: false,
        filters: [
          FilterSpec.select('role', 'Роль', 'role', optionsOf(Role.values)),
        ],
      );
}
