import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autosalon/core/api_exceptions.dart';
import 'package:autosalon/core/pb_api.dart';
import 'package:autosalon/models/deal_pricing.dart';
import 'package:autosalon/models/entities.dart';
import 'package:autosalon/models/enums.dart';
import 'package:autosalon/models/list_query.dart';
import 'package:autosalon/models/permissions.dart';
import 'package:autosalon/models/schedule.dart';
import 'package:autosalon/repositories/entity_repository.dart';
import 'package:autosalon/router.dart';
import 'package:autosalon/state/auth_notifier.dart';
import 'package:autosalon/validation/validators.dart';

import 'support/fake_server.dart';

void main() {
  group('Расчёт стоимости сделки', () {
    test('итог учитывает услуги, скидку и зачёт старого автомобиля', () {
      const p = DealPricing(
        carPrice: 2000000,
        servicesTotal: 100000,
        discountPercent: 5,
        tradeIn: 100000,
      );
      expect(p.subtotal, 2100000);
      expect(p.discountAmount, 105000);
      expect(p.total, 1895000);
      expect(p.validate(), isEmpty);
    });

    test('скидка ограничена способом оплаты', () {
      DealPricing p(PaymentType t, double d) =>
          DealPricing(carPrice: 1000000, payment: t, discountPercent: d);
      expect(p(PaymentType.cash, 5).validate(), isEmpty);
      expect(p(PaymentType.cash, 6).validate(), contains('discountPercent'));
      expect(p(PaymentType.credit, 4).validate(), contains('discountPercent'));
      expect(
        p(PaymentType.leasing, 2.5).validate(),
        contains('discountPercent'),
      );
    });

    test('зачёт не больше половины стоимости', () {
      const p = DealPricing(carPrice: 1000000, tradeIn: 600000);
      expect(p.validate(), contains('tradeInValue'));
    });

    test('кредит: взнос от 20 %, срок 6–84 месяца, платёж рассчитывается', () {
      DealPricing credit(double down, int term) => DealPricing(
        carPrice: 1000000,
        payment: PaymentType.credit,
        downPayment: down,
        termMonths: term,
      );
      expect(credit(100000, 24).validate(), contains('downPayment'));
      expect(credit(200000, 5).validate(), contains('termMonths'));
      expect(credit(200000, 85).validate(), contains('termMonths'));
      final ok = credit(200000, 24);
      expect(ok.validate(), isEmpty);
      // 800 000 ₽ под 16,5 % на 24 месяца
      expect(ok.monthlyPayment, closeTo(39500, 500));
      expect(const DealPricing(carPrice: 1000000).monthlyPayment, isNull);
    });
  });

  group('Условия отбора списка', () {
    test('записываются в адрес и читаются обратно', () {
      const q = ListQuery(
        page: 3,
        perPage: 20,
        search: 'камри',
        sort: '-price',
        filters: {'status': 'available', 'priceMin': '1000000'},
      );
      final params = q.toParams();
      expect(params['f_status'], 'available');
      expect(params['page'], '3');
      expect(ListQuery.fromParams(params), q);
    });

    test('значения по умолчанию в адрес не пишутся', () {
      expect(const ListQuery().toParams(), isEmpty);
      expect(
        ListQuery.fromParams({'page': 'x', 'size': '7'}),
        const ListQuery(),
      );
    });

    test('изменение фильтра возвращает на первую страницу', () {
      final q = const ListQuery(page: 4).withFilter('status', 'sold');
      expect(q.page, 1);
      expect(q.withFilter('status', '').filters, isEmpty);
    });

    test(
      'фильтр PocketBase: удалённые, поиск и условия, кавычки экранируются',
      () {
        final repo = PbRepository<Car>(
          PbApi(Dio()),
          collection: 'cars',
          fromJson: Car.fromJson,
          searchFields: const ['vin', 'model.name'],
          filters: [
            const FilterSpec.min('priceMin', 'Цена от', 'price'),
            FilterSpec.select(
              'status',
              'Статус',
              'status',
              optionsOf(CarStatus.values),
            ),
          ],
        );
        const q = ListQuery(
          search: 'a"b',
          filters: {'priceMin': '100', 'status': 'available'},
        );
        expect(
          repo.buildFilter(q),
          'deletedAt = "" && (vin ~ "a\\"b" || model.name ~ "a\\"b") '
          '&& price >= 100 && status = "available"',
        );
        expect(
          repo.buildFilter(const ListQuery(), deleted: true),
          'deletedAt != ""',
        );
        // нечисловое значение не попадает в выражение
        expect(
          repo.buildFilter(const ListQuery(filters: {'priceMin': 'abc'})),
          'deletedAt = ""',
        );
      },
    );
  });

  group('Ответы сервера', () {
    test('400 с описанием полей — ошибка проверки с русским текстом', () {
      final e = ApiException.fromResponse(400, {
        'message': 'Failed to create record.',
        'data': {
          'vin': {
            'code': 'validation_not_unique',
            'message': 'Value must be unique.',
          },
          'price': {
            'code': 'validation_min_number_constraint',
            'message': 'Must be >= 100000',
          },
        },
      });
      expect(e, isA<ValidationException>());
      final fields = (e as ValidationException).fields;
      expect(fields['vin'], 'Такое значение уже есть');
      expect(fields['price'], 'Значение меньше допустимого');
    });

    test('422 — ошибка полей, 409 — конфликт, 404 и 5xx — свои типы', () {
      final body = {
        'message': 'Время занято',
        'data': {
          'startsAt': {'code': 'time_conflict', 'message': 'Время занято'},
        },
      };
      expect(ApiException.fromResponse(422, body), isA<ValidationException>());
      final conflict =
          ApiException.fromResponse(409, body) as ConflictException;
      expect(conflict.fields['startsAt'], 'Время занято');
      expect(ApiException.fromResponse(404, {}), isA<NotFoundException>());
      expect(ApiException.fromResponse(503, {}), isA<ServerException>());
      expect(ApiException.fromResponse(401, {}), isA<UnauthorizedException>());
    });
  });

  group('Сетевой слой', () {
    Dio dio(
      FakeServer server, {
      Future<bool> Function()? refresh,
      void Function()? onFailed,
      void Function()? onOffline,
    }) => buildDio(
      baseUrl: 'http://test.local',
      token: () => 'tok',
      refreshToken: refresh,
      onAuthFailed: onFailed,
      onOffline: onOffline,
      retryDelays: const [Duration.zero, Duration.zero],
    )..httpClientAdapter = server;

    test('чтение повторяется при сбое сети', () async {
      var calls = 0;
      final server = FakeServer(
        (o) => ++calls < 3
            ? const FakeResponse(-1)
            : const FakeResponse(200, {'ok': true}),
      );
      final json = await PbApi(dio(server)).get('/api/x');
      expect(json['ok'], true);
      expect(server.requests.length, 3);
    });

    test(
      'сервер недоступен: NetworkException и сигнал об отключении',
      () async {
        var offline = 0;
        final server = FakeServer((o) => const FakeResponse(-1));
        final api = PbApi(dio(server, onOffline: () => offline++));
        await expectLater(api.get('/api/x'), throwsA(isA<NetworkException>()));
        expect(offline, 1);
        // 1 запрос и 2 повтора
        expect(server.requests.length, 3);
      },
    );

    test('запись не повторяется автоматически', () async {
      final server = FakeServer((o) => const FakeResponse(-1));
      final api = PbApi(dio(server));
      await expectLater(
        api.post('/api/x', {}),
        throwsA(isA<NetworkException>()),
      );
      expect(server.requests.length, 1);
    });

    test(
      'ответ 401: токен продлевается и запрос повторяется один раз',
      () async {
        var refreshed = 0;
        var calls = 0;
        final server = FakeServer(
          (o) => ++calls == 1
              ? const FakeResponse(401, {'message': 'expired'})
              : const FakeResponse(200, {'ok': true}),
        );
        final api = PbApi(
          dio(
            server,
            refresh: () async {
              refreshed++;
              return true;
            },
          ),
        );
        final json = await api.get('/api/x');
        expect(json['ok'], true);
        expect(refreshed, 1);
        expect(server.requests.length, 2);
      },
    );

    test('если продлить токен не удалось, сессия завершается', () async {
      var failed = 0;
      final server = FakeServer(
        (o) => const FakeResponse(401, {'message': 'x'}),
      );
      final api = PbApi(
        dio(server, refresh: () async => false, onFailed: () => failed++),
      );
      await expectLater(
        api.get('/api/x'),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(failed, 1);
    });
  });

  group('Модели и сессия', () {
    test('автомобиль читается вместе с развёрнутой моделью и маркой', () {
      final car = Car.fromJson(carJson(1));
      expect(car.modelTitle, 'Toyota Camry');
      expect(car.bodyType, BodyType.sedan);
      expect(car.status, CarStatus.available);
      expect(car.isNew, true);
      expect(car.toFormValues()['price'], 2100000);
    });

    test('срок действия токена читается из JWT', () {
      String part(Map<String, Object?> m) =>
          base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
      final token =
          '${part({'alg': 'HS256'})}.${part({'exp': 2000000000})}.sig';
      expect(
        tokenExpiry(token),
        DateTime.fromMillisecondsSinceEpoch(2000000000 * 1000),
      );
      expect(tokenExpiry('не токен'), isNull);
    });
  });

  group('Права и маршруты', () {
    test('у каждой роли есть раздел, недоступный остальным', () {
      for (final (role, only) in [
        (Role.client, Permission.clientCabinet),
        (Role.manager, Permission.manageContracts),
        (Role.admin, Permission.manageUsers),
      ]) {
        expect(roleCan(role, only), isTrue);
        for (final other in Role.values.where((r) => r != role)) {
          expect(
            roleCan(other, only),
            isFalse,
            reason: '$other не должен иметь $only',
          );
        }
      }
    });

    test('адрес определяет нужное право', () {
      expect(requiredPermission('/'), isNull);
      expect(requiredPermission('/cars'), Permission.viewCatalog);
      expect(requiredPermission('/cars/abc'), Permission.viewCatalog);
      expect(requiredPermission('/cars/new'), Permission.manageCars);
      expect(requiredPermission('/cars/abc/edit'), Permission.manageCars);
      expect(requiredPermission('/admin/users'), Permission.manageUsers);
      expect(requiredPermission('/admin/trash'), Permission.viewTrash);
      expect(requiredPermission('/my/deals'), Permission.clientCabinet);
      expect(requiredPermission('/contracts/new'), Permission.manageContracts);
    });
  });

  group('Проверка полей и расписание', () {
    test('VIN, телефон, диапазоны и пароль', () {
      expect(vin()('XTA210930Y1234567'), isNull);
      expect(vin()('XTA210930O1234567'), isNotNull); // буква O запрещена
      expect(phone()('+7 (900) 123-45-67'), isNull);
      expect(phone()('12345'), isNotNull);
      expect(intRange(1990, 2100)('1980'), 'Не меньше 1990');
      expect(intRange(1990, 2100)('abc'), 'Введите целое число');
      expect(strongPassword()('abc'), 'Не короче 8 символов');
      expect(strongPassword()('abcdefgh'), 'Есть цифра');
      expect(strongPassword()('abcdefg1'), isNull);
    });

    test('интервалы пересекаются, но стык не считается пересечением', () {
      final t = DateTime(2030, 1, 1, 10);
      DateTime at(int h) => t.add(Duration(hours: h - 10));
      expect(intervalsOverlap(at(10), at(11), at(11), at(12)), isFalse);
      expect(intervalsOverlap(at(10), at(12), at(11), at(13)), isTrue);
      expect(intervalsOverlap(at(10), at(14), at(11), at(12)), isTrue);
    });

    test(
      'конфликты ищутся только среди запланированных тест-драйвов той же машины',
      () {
        TestDrive drive(
          String id,
          String car,
          int from,
          int to,
          DriveStatus s,
        ) => TestDrive(
          id: id,
          carId: car,
          carTitle: '',
          customerId: 'c',
          customerName: '',
          startsAt: DateTime(2030, 1, 1, from),
          endsAt: DateTime(2030, 1, 1, to),
          status: s,
        );
        final drives = [
          drive('a', 'car1', 10, 12, DriveStatus.planned),
          drive('b', 'car1', 10, 12, DriveStatus.cancelled),
          drive('c', 'car2', 10, 12, DriveStatus.planned),
        ];
        final start = DateTime(2030, 1, 1, 11);
        final end = DateTime(2030, 1, 1, 13);
        expect(conflictsFor(drives, 'car1', start, end).map((d) => d.id), [
          'a',
        ]);
        expect(
          conflictsFor(drives, 'car1', start, end, exceptId: 'a'),
          isEmpty,
        );
      },
    );

    test('интервал тест-драйва: порядок, длительность, прошлое', () {
      final now = DateTime(2030, 1, 1, 9);
      DateTime h(int x) => DateTime(2030, 1, 1, x);
      expect(validateInterval(h(10), h(11), now: now), isNull);
      expect(validateInterval(h(11), h(10), now: now), contains('позже'));
      expect(validateInterval(h(10), h(14), now: now), contains('трёх часов'));
      expect(validateInterval(h(8), h(9), now: now), contains('прошло'));
    });
  });
}
