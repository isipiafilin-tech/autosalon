import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/permissions.dart';
import '../state/auth_notifier.dart';
import 'adaptive.dart';

/// Раздел навигации: подпись, адрес, значок, право (null — доступен всем) и
/// признак «общего» раздела для нижней панели узкого окна.
class AppSection {
  final String label;
  final String path;
  final IconData icon;
  final Permission? permission;
  final bool inBottomBar;

  const AppSection(
    this.label,
    this.path,
    this.icon,
    this.permission, {
    this.inBottomBar = false,
  });
}

/// Разделы и право, нужное для каждого. Роль видит только свои.
const List<AppSection> appSections = [
  AppSection('Главная', '/', Icons.home_outlined, null, inBottomBar: true),
  AppSection(
    'Каталог',
    '/cars',
    Icons.directions_car_outlined,
    Permission.viewCatalog,
    inBottomBar: true,
  ),
  AppSection(
    'Мои заявки',
    '/my/deals',
    Icons.receipt_long_outlined,
    Permission.clientCabinet,
    inBottomBar: true,
  ),
  AppSection(
    'Мои тест-драйвы',
    '/my/test-drives',
    Icons.event_available_outlined,
    Permission.clientCabinet,
  ),
  AppSection(
    'Сделки',
    '/deals',
    Icons.handshake_outlined,
    Permission.manageDeals,
    inBottomBar: true,
  ),
  AppSection(
    'Договоры',
    '/contracts',
    Icons.description_outlined,
    Permission.manageContracts,
  ),
  AppSection(
    'Тест-драйвы',
    '/test-drives',
    Icons.event_outlined,
    Permission.manageTestDrives,
  ),
  AppSection(
    'Клиенты',
    '/customers',
    Icons.groups_outlined,
    Permission.manageCustomers,
  ),
  AppSection(
    'Модели',
    '/models',
    Icons.view_list_outlined,
    Permission.manageCars,
  ),
  AppSection(
    'Марки',
    '/brands',
    Icons.local_offer_outlined,
    Permission.manageDictionaries,
  ),
  AppSection(
    'Опции',
    '/options',
    Icons.tune_outlined,
    Permission.manageDictionaries,
  ),
  AppSection(
    'Услуги',
    '/services',
    Icons.build_outlined,
    Permission.manageDictionaries,
  ),
  AppSection(
    'Пользователи',
    '/admin/users',
    Icons.manage_accounts_outlined,
    Permission.manageUsers,
    inBottomBar: true,
  ),
  AppSection(
    'Корзина',
    '/admin/trash',
    Icons.delete_outline,
    Permission.viewTrash,
  ),
];

/// Каркас экранов: навигация по разделам текущей роли, имя пользователя,
/// выход. Узкое окно — панель снизу, среднее — полоса значков сбоку,
/// широкое — развёрнутая полоса с подписями.
class AppScaffold extends StatelessWidget {
  static const contentKey = Key('app-content');

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  static int _indexOf(List<AppSection> sections, String location) {
    var best = -1;
    var bestLength = -1;
    for (var i = 0; i < sections.length; i++) {
      final p = sections[i].path;
      final matches = p == '/'
          ? location == '/'
          : location == p || location.startsWith('$p/');
      if (matches && p.length > bestLength) {
        best = i;
        bestLength = p.length;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final location = GoRouterState.of(context).uri.path;
    final size = windowSizeOf(context);
    final sections = [
      for (final s in appSections)
        if (s.permission == null || auth.can(s.permission!)) s,
    ];
    final content = SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          key: contentKey,
          constraints: const BoxConstraints(maxWidth: contentMaxWidth),
          child: body,
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          ...?actions,
          ..._userActions(auth, compact: size == WindowSize.compact),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: floatingActionButton,
      body: size == WindowSize.compact
          ? content
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FocusTraversalGroup(
                  child: _rail(context, sections, location, size),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: FocusTraversalGroup(child: content)),
              ],
            ),
      bottomNavigationBar: size == WindowSize.compact
          ? _bottomBar(context, sections, location)
          : null,
    );
  }

  List<Widget> _userActions(AuthNotifier auth, {required bool compact}) {
    final user = auth.user;
    final name = user == null ? '' : '${user.name} · ${user.role.label}';
    if (compact) {
      return [
        PopupMenuButton<void>(
          tooltip: name.isEmpty ? 'Учётная запись' : name,
          icon: const Icon(Icons.account_circle_outlined),
          itemBuilder: (_) => [
            PopupMenuItem(enabled: false, child: Text(name)),
            PopupMenuItem(onTap: auth.logout, child: const Text('Выйти')),
          ],
        ),
      ];
    }
    return [
      if (user != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(name),
        ),
      IconButton(
        tooltip: 'Выйти',
        icon: const Icon(Icons.logout),
        onPressed: auth.logout,
      ),
    ];
  }

  Widget _rail(
    BuildContext context,
    List<AppSection> sections,
    String location,
    WindowSize size,
  ) {
    final extended = size == WindowSize.expanded;
    final selected = _indexOf(sections, location);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: NavigationRail(
              extended: extended,
              minExtendedWidth: 220,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              selectedIndex: selected == -1 ? null : selected,
              onDestinationSelected: (i) => context.go(sections[i].path),
              destinations: [
                for (final s in sections)
                  NavigationRailDestination(
                    icon: Icon(s.icon),
                    label: Text(s.label),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(
    BuildContext context,
    List<AppSection> sections,
    String location,
  ) {
    final primary = [
      for (final s in sections)
        if (s.inBottomBar) s,
    ].take(4).toList();
    final rest = [
      for (final s in sections)
        if (!primary.contains(s)) s,
    ];
    final selected = _indexOf(primary, location);
    return NavigationBar(
      height: 64,
      selectedIndex: selected == -1 ? primary.length : selected,
      onDestinationSelected: (i) => i < primary.length
          ? context.go(primary[i].path)
          : _showMore(context, rest),
      destinations: [
        for (final s in primary)
          NavigationDestination(icon: Icon(s.icon), label: s.label),
        const NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Ещё'),
      ],
    );
  }

  void _showMore(BuildContext context, List<AppSection> rest) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final s in rest)
              ListTile(
                leading: Icon(s.icon),
                title: Text(s.label),
                onTap: () {
                  Navigator.pop(sheet);
                  context.go(s.path);
                },
              ),
          ],
        ),
      ),
    );
  }
}
