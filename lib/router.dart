import 'package:go_router/go_router.dart';

import 'models/entities.dart';
import 'models/permissions.dart';
import 'screens/auth_screens.dart';
import 'screens/basic_screens.dart';
import 'screens/entity_config.dart';
import 'screens/entity_configs.dart';
import 'screens/entity_screens.dart';
import 'screens/forms.dart';
import 'state/auth_notifier.dart';

final myDealsConfig = dealsConfig.asClientView('/my/deals', 'Мои заявки');
final myDrivesConfig = testDrivesConfig.asClientView(
  '/my/test-drives',
  'Мои тест-драйвы',
);

/// Право, нужное для адреса; null — достаточно войти в систему.
/// Сервер проверяет права независимо от клиента.
Permission? requiredPermission(String path) {
  final isForm = path.endsWith('/new') || path.endsWith('/edit');
  if (path.startsWith('/my/')) return Permission.clientCabinet;
  if (path.startsWith('/admin/users')) return Permission.manageUsers;
  if (path.startsWith('/admin/trash')) return Permission.viewTrash;
  bool under(String p) => path == p || path.startsWith('$p/');
  if (under('/cars')) {
    return isForm ? Permission.manageCars : Permission.viewCatalog;
  }
  if (under('/models')) return Permission.manageCars;
  if (under('/brands') || under('/options') || under('/services')) {
    return Permission.manageDictionaries;
  }
  if (under('/customers')) return Permission.manageCustomers;
  if (under('/deals')) return Permission.manageDeals;
  if (under('/test-drives')) return Permission.manageTestDrives;
  if (under('/contracts')) return Permission.manageContracts;
  return null;
}

/// Маршруты типовой сущности: список, форма, карточка, изменение.
List<RouteBase> entityRoutes<T extends Entity>(
  EntityConfig<T> cfg, {
  bool newForm = true,
  bool editForm = true,
}) => [
  GoRoute(
    path: cfg.path,
    builder: (_, _) => EntityListScreen<T>(config: cfg),
  ),
  if (cfg.hasForm && newForm)
    GoRoute(
      path: '${cfg.path}/new',
      builder: (_, _) => EntityFormScreen<T>(config: cfg),
    ),
  if (cfg.hasDetail)
    GoRoute(
      path: '${cfg.path}/:id',
      builder: (_, s) =>
          EntityDetailScreen<T>(config: cfg, id: s.pathParameters['id']!),
    ),
  if (cfg.hasForm && cfg.canEdit && editForm)
    GoRoute(
      path: '${cfg.path}/:id/edit',
      builder: (_, s) =>
          EntityFormScreen<T>(config: cfg, id: s.pathParameters['id']),
    ),
];

GoRouter buildRouter(AuthNotifier auth) {
  return GoRouter(
    refreshListenable: auth,
    redirect: (context, state) {
      final loc = state.uri.path;
      final onAuthPage = loc == '/login' || loc == '/register';
      if (!auth.isSignedIn) {
        if (onAuthPage) return null;
        final from = state.uri.toString();
        return from == '/'
            ? '/login'
            : '/login?from=${Uri.encodeQueryComponent(from)}';
      }
      if (onAuthPage) return state.uri.queryParameters['from'] ?? '/';
      final need = requiredPermission(loc);
      if (need != null && !auth.can(need)) return '/forbidden';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/forbidden', builder: (_, _) => const ForbiddenScreen()),
      ...entityRoutes(brandsConfig),
      ...entityRoutes(modelsConfig),
      ...entityRoutes(carsConfig),
      ...entityRoutes(optionsConfig),
      ...entityRoutes(servicesConfig),
      ...entityRoutes(customersConfig),
      ...entityRoutes(usersConfig),

      // Сделки, тест-драйвы и договоры: формы со своей логикой.
      GoRoute(
        path: '/deals',
        builder: (_, _) => EntityListScreen<Deal>(config: dealsConfig),
      ),
      GoRoute(
        path: '/deals/new',
        builder: (_, s) => DealFormScreen(
          client: false,
          presetCar: s.uri.queryParameters['car'],
        ),
      ),
      GoRoute(
        path: '/deals/:id',
        builder: (_, s) => EntityDetailScreen<Deal>(
          config: dealsConfig,
          id: s.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/test-drives',
        builder: (_, _) =>
            EntityListScreen<TestDrive>(config: testDrivesConfig),
      ),
      GoRoute(
        path: '/test-drives/new',
        builder: (_, s) => TestDriveFormScreen(
          client: false,
          presetCar: s.uri.queryParameters['car'],
        ),
      ),
      GoRoute(
        path: '/test-drives/:id',
        builder: (_, s) => EntityDetailScreen<TestDrive>(
          config: testDrivesConfig,
          id: s.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/test-drives/:id/edit',
        builder: (_, s) =>
            TestDriveFormScreen(client: false, id: s.pathParameters['id']),
      ),
      GoRoute(
        path: '/contracts',
        builder: (_, _) => EntityListScreen<Contract>(config: contractsConfig),
      ),
      GoRoute(
        path: '/contracts/new',
        builder: (_, s) =>
            ContractFormScreen(presetDeal: s.uri.queryParameters['deal']),
      ),
      GoRoute(
        path: '/contracts/:id',
        builder: (_, s) => EntityDetailScreen<Contract>(
          config: contractsConfig,
          id: s.pathParameters['id']!,
        ),
      ),

      // Раздел клиента.
      GoRoute(
        path: '/my/deals',
        builder: (_, _) => EntityListScreen<Deal>(config: myDealsConfig),
      ),
      GoRoute(
        path: '/my/deals/new',
        builder: (_, s) => DealFormScreen(
          client: true,
          presetCar: s.uri.queryParameters['car'],
        ),
      ),
      GoRoute(
        path: '/my/deals/:id',
        builder: (_, s) => EntityDetailScreen<Deal>(
          config: myDealsConfig,
          id: s.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/my/test-drives',
        builder: (_, _) => EntityListScreen<TestDrive>(config: myDrivesConfig),
      ),
      GoRoute(
        path: '/my/test-drives/new',
        builder: (_, s) => TestDriveFormScreen(
          client: true,
          presetCar: s.uri.queryParameters['car'],
        ),
      ),
      GoRoute(
        path: '/my/test-drives/:id',
        builder: (_, s) => EntityDetailScreen<TestDrive>(
          config: myDrivesConfig,
          id: s.pathParameters['id']!,
        ),
      ),

      GoRoute(path: '/admin/trash', builder: (_, _) => const TrashScreen()),
    ],
    errorBuilder: (context, state) => const ForbiddenScreen(),
  );
}
