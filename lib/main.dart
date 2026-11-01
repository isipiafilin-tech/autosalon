import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'repositories/repos.dart';
import 'router.dart';
import 'state/auth_notifier.dart';
import 'state/connection_notifier.dart';
import 'state/lookup_notifier.dart';
import 'widgets/connection_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Адреса без #: прямые ссылки на экраны работают и после обновления страницы.
  usePathUrlStrategy();
  final prefs = await SharedPreferences.getInstance();
  runApp(AutosalonApp(prefs: prefs));
}

class AutosalonApp extends StatefulWidget {
  final SharedPreferences prefs;

  /// Подмена слоя доступа к серверу в тестах.
  final Repos? repos;

  const AutosalonApp({super.key, required this.prefs, this.repos});

  @override
  State<AutosalonApp> createState() => _AutosalonAppState();
}

class _AutosalonAppState extends State<AutosalonApp> {
  late final AuthNotifier _auth;
  late final ConnectionNotifier _connection;
  late final Repos _repos;
  late final LookupNotifier _lookup;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _connection = ConnectionNotifier(() async {
      await _auth.api.get('/api/health');
    });
    _auth = AuthNotifier(widget.prefs, _connection);
    _repos = widget.repos ?? Repos(_auth.api);
    _lookup = LookupNotifier(_auth.api);
    _router = buildRouter(_auth);
    // Роль из localStorage могла быть подменена: сверяем её с сервером.
    _auth.verifySession();
  }

  @override
  void dispose() {
    _router.dispose();
    _connection.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _connection),
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider.value(value: _lookup),
        Provider.value(value: _repos),
      ],
      child: MaterialApp.router(
        title: 'Автосалон',
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF1E4E8C),
          useMaterial3: true,
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        builder: (context, child) =>
            ConnectionBanner(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
