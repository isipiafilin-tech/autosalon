import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autosalon/core/format.dart';
import 'package:autosalon/models/enums.dart';

import 'support/fake_server.dart';
import 'support/harness.dart';

/// Сервер по умолчанию: два автомобиля, остальные коллекции пусты.
FakeServer server({
  FutureOr<FakeResponse?> Function(RequestOptions o)? first,
}) => FakeServer((o) async {
  final special = await first?.call(o);
  if (special != null) return special;
  final p = o.path;
  if (o.method == 'GET') {
    if (p.endsWith('/records/car1')) return FakeResponse(200, carJson(1));
    if (p.endsWith('/collections/cars/records')) {
      return FakeResponse(200, pbPage([carJson(1), carJson(2)]));
    }
    return FakeResponse(200, pbPage([]));
  }
  return const FakeResponse(200, {});
});

bool isCarsList(RequestOptions o) =>
    o.method == 'GET' &&
    o.path.endsWith('/collections/cars/records') &&
    o.queryParameters.containsKey('filter') &&
    '${o.queryParameters['filter']}'.contains('deletedAt');

void main() {
  group('Состояния списка', () {
    testWidgets('пока идёт запрос — индикатор, затем данные', (tester) async {
      final pending = Completer<FakeResponse>();
      await pumpApp(
        tester,
        server(first: (o) => isCarsList(o) ? pending.future : null),
        role: Role.manager,
        location: '/cars',
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Ничего не найдено'), findsNothing);

      pending.complete(FakeResponse(200, pbPage([carJson(1), carJson(2)])));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Toyota Camry'), findsWidgets);
    });

    testWidgets('пустой результат — сообщение, а не индикатор или ошибка', (
      tester,
    ) async {
      await pumpApp(
        tester,
        server(
          first: (o) => isCarsList(o) ? FakeResponse(200, pbPage([])) : null,
        ),
        role: Role.manager,
        location: '/cars',
      );
      await tester.pumpAndSettle();
      expect(find.text('Ничего не найдено'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Повторить'), findsNothing);
    });

    testWidgets('ошибка сети — сообщение и повтор загружает данные', (
      tester,
    ) async {
      var down = true;
      await pumpApp(
        tester,
        server(
          first: (o) => isCarsList(o) && down ? const FakeResponse(-1) : null,
        ),
        role: Role.manager,
        location: '/cars',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Нет соединения'), findsWidgets);
      expect(find.text('Повторить'), findsOneWidget);

      down = false;
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.text('Повторить'), findsNothing);
      expect(find.text('Toyota Camry'), findsWidgets);
    });
  });

  group('Формы и ошибки сервера', () {
    testWidgets('пустая форма не отправляется: ошибки у полей', (tester) async {
      final s = server();
      await pumpApp(tester, s, role: Role.admin, location: '/brands/new');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Создать'));
      await tester.pumpAndSettle();
      expect(find.text('Заполните поле'), findsNWidgets(2));
      expect(s.requests.where((r) => r.method == 'POST'), isEmpty);
    });

    testWidgets('ошибка проверки с сервера показывается у поля', (
      tester,
    ) async {
      await pumpApp(
        tester,
        server(
          first: (o) => o.method == 'POST'
              ? const FakeResponse(400, {
                  'message': 'Failed to create record.',
                  'data': {
                    'name': {'code': 'validation_not_unique', 'message': 'x'},
                  },
                })
              : null,
        ),
        role: Role.admin,
        location: '/brands/new',
      );
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Toyota');
      await tester.enterText(fields.at(1), 'Япония');
      await tester.tap(find.text('Создать'));
      await tester.pumpAndSettle();
      expect(find.text('Такое значение уже есть'), findsOneWidget);
    });

    testWidgets('конфликт 409 показывается у поля времени', (tester) async {
      await pumpApp(
        tester,
        server(
          first: (o) => o.method == 'POST'
              ? const FakeResponse(409, {
                  'message': 'Автомобиль в это время занят.',
                  'data': {
                    'startsAt': {
                      'code': 'time_conflict',
                      'message': 'Время занято другим тест-драйвом',
                    },
                  },
                })
              : null,
        ),
        role: Role.client,
        location: '/my/test-drives/new?car=car1',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Записаться'));
      await tester.pumpAndSettle();
      expect(find.text('Время занято другим тест-драйвом'), findsOneWidget);
    });

    testWidgets(
      'форма сделки считает стоимость и подставляет данные автомобиля',
      (tester) async {
        await pumpApp(
          tester,
          server(),
          role: Role.manager,
          location: '/deals/new?car=car1',
        );
        await tester.pumpAndSettle();
        expect(find.text('Расчёт стоимости'), findsOneWidget);
        expect(find.text(money(2100000)), findsWidgets);
      },
    );
  });

  group('Роли и маршруты', () {
    testWidgets('клиент не видит служебные действия и разделы', (tester) async {
      final h = await pumpApp(
        tester,
        server(),
        role: Role.client,
        location: '/cars',
      );
      await tester.pumpAndSettle();
      expect(h.auth.isSignedIn, isTrue);
      expect(find.text('Добавить'), findsNothing);
      expect(find.byTooltip('Удалить'), findsNothing);
      expect(find.text('Пользователи'), findsNothing);
      expect(find.text('Мои заявки'), findsOneWidget);
    });

    testWidgets(
      'менеджер видит добавление, администратор — пользователей и корзину',
      (tester) async {
        await pumpApp(tester, server(), role: Role.manager, location: '/cars');
        await tester.pumpAndSettle();
        expect(find.text('Добавить'), findsOneWidget);
        expect(find.text('Договоры'), findsOneWidget);
        expect(find.text('Пользователи'), findsNothing);

        await pumpApp(tester, server(), role: Role.admin, location: '/cars');
        await tester.pumpAndSettle();
        expect(find.text('Пользователи'), findsOneWidget);
        expect(find.text('Корзина'), findsOneWidget);
        expect(find.text('Договоры'), findsNothing);
      },
    );

    testWidgets('недоступный адрес, набранный вручную, ведёт на экран отказа', (
      tester,
    ) async {
      await pumpApp(
        tester,
        server(),
        role: Role.client,
        location: '/admin/users',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Этот раздел недоступен для вашей роли'),
        findsOneWidget,
      );
    });

    testWidgets('без входа открывается форма входа', (tester) async {
      await pumpApp(tester, server(), location: '/cars');
      await tester.pumpAndSettle();
      expect(find.text('Войти'), findsOneWidget);
      expect(find.text('Регистрация'), findsOneWidget);
    });
  });

  group('Адаптивная вёрстка', () {
    testWidgets('узкое окно — карточки и нижняя навигация', (tester) async {
      await pumpApp(
        tester,
        server(),
        role: Role.manager,
        location: '/cars',
        size: const Size(360, 780),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsNothing);
      expect(find.byType(Card), findsWidgets);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('широкое окно — таблица и боковая навигация', (tester) async {
      await pumpApp(tester, server(), role: Role.manager, location: '/cars');
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    for (final width in [360.0, 768.0, 1280.0, 1920.0]) {
      testWidgets(
        'длинные названия не ломают раскладку при ширине ${width.toInt()}',
        (tester) async {
          final long = carJson(1)
            ..['color'] = 'Очень длинное описание цвета ' * 8;
          await pumpApp(
            tester,
            server(
              first: (o) => isCarsList(o)
                  ? FakeResponse(200, pbPage([long, carJson(2)]))
                  : null,
            ),
            role: Role.manager,
            location: '/cars',
            size: Size(width, 900),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
