import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:autosalon/core/pb_api.dart';
import 'package:autosalon/models/enums.dart';
import 'package:autosalon/repositories/repos.dart';
import 'package:autosalon/router.dart';
import 'package:autosalon/state/auth_notifier.dart';
import 'package:autosalon/state/connection_notifier.dart';
import 'package:autosalon/state/lookup_notifier.dart';
import 'package:autosalon/widgets/connection_widgets.dart';

import 'fake_server.dart';

class Harness {
  final FakeServer server;
  final AuthNotifier auth;
  final ConnectionNotifier connection;
  final GoRouter router;

  Harness(this.server, this.auth, this.connection, this.router);
}

/// Запускает приложение с поддельным сервером под указанной ролью
/// (null — без входа) и открывает [location].
Future<Harness> pumpApp(
  WidgetTester tester,
  FakeServer server, {
  Role? role,
  String location = '/',
  Size size = const Size(1280, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({
    if (role != null) ...{
      'auth_token': 'test-token',
      'auth_user':
          '{"id":"u1","email":"u@test.ru","name":"Тестовый Пользователь","phone":"","role":"${role.value}"}',
    },
  });
  final prefs = await SharedPreferences.getInstance();
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
    ..httpClientAdapter = server;
  final api = PbApi(dio);
  final connection = ConnectionNotifier(() async {});
  final auth = AuthNotifier(
    prefs,
    connection,
    apiOverride: api,
    autoRefresh: false,
  );
  final repos = Repos(api);
  final router = buildRouter(auth)..go(location);
  addTearDown(connection.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: connection),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => LookupNotifier(api)),
        Provider.value(value: repos),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) =>
            ConnectionBanner(child: child ?? const SizedBox.shrink()),
      ),
    ),
  );
  return Harness(server, auth, connection, router);
}
