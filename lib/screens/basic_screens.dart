import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/list_query.dart';
import '../state/auth_notifier.dart';
import '../widgets/adaptive.dart';
import '../widgets/app_scaffold.dart';
import 'entity_configs.dart';

/// Главная: приветствие и разделы текущей роли.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final user = auth.user;
    final sections = [
      for (final s in appSections)
        if (s.path != '/' && s.permission != null && auth.can(s.permission!)) s,
    ];
    return AppScaffold(
      title: 'Главная',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Здравствуйте, ${user?.name ?? ''}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text('Роль: ${user?.role.label ?? ''}. Доступные разделы:'),
          const SizedBox(height: 16),
          ResponsiveGrid(
            children: [
              for (final s in sections)
                Card(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    onTap: () => context.go(s.path),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(s.icon, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              s.label,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Экран отказа: показывается при попытке открыть недоступный адрес вручную.
class ForbiddenScreen extends StatelessWidget {
  const ForbiddenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Доступ запрещён',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 56,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                'Этот раздел недоступен для вашей роли',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('На главную'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Корзина: удалённые записи по сущностям; восстановление и физическое удаление.
class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final key = uri.queryParameters['e'] ?? trashConfigs.first.key;
    final config = trashConfigs.firstWhere(
      (c) => c.key == key,
      orElse: () => trashConfigs.first,
    );
    void go(ListQuery q, String entity) => context.go(
      Uri(
        path: uri.path,
        queryParameters: {...q.toParams(), 'e': entity},
      ).toString(),
    );
    return AppScaffold(
      title: 'Корзина',
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final c in trashConfigs)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c.title),
                      selected: c.key == config.key,
                      onSelected: (_) => go(const ListQuery(), c.key),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: config.trashView(
              query: ListQuery.fromParams(uri.queryParameters),
              onQuery: (q) => go(q, config.key),
            ),
          ),
        ],
      ),
    );
  }
}
