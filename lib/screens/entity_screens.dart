import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../models/entities.dart';
import '../models/list_query.dart';
import '../repositories/repos.dart';
import '../state/auth_notifier.dart';
import '../state/lookup_notifier.dart';
import '../widgets/adaptive.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/connection_widgets.dart';
import '../widgets/entity_list_view.dart';
import '../widgets/form_fields.dart';
import '../widgets/form_page.dart';
import 'entity_config.dart';

/// Условия отбора из адресной строки с проверкой сортировки.
ListQuery queryFromUri(Uri uri, EntityConfig config) {
  final q = ListQuery.fromParams(uri.queryParameters);
  final valid = config.sorts.any((s) => s.$1 == q.sort);
  return valid ? q : q.copyWith(sort: '');
}

/// Список сущности. Условия отбора живут в адресе: ссылку можно передать.
class EntityListScreen<T extends Entity> extends StatelessWidget {
  final EntityConfig<T> config;

  const EntityListScreen({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final uri = GoRouterState.of(context).uri;
    final canAdd =
        config.manage != null && auth.can(config.manage!) && config.hasForm;
    final compact = windowSizeOf(context) == WindowSize.compact;
    return AppScaffold(
      title: config.title,
      actions: [
        if (canAdd)
          compact
              ? IconButton(
                  tooltip: 'Добавить',
                  icon: const Icon(Icons.add),
                  onPressed: () => context.push(config.newPath),
                )
              : FilledButton.icon(
                  onPressed: () => context.push(config.newPath),
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить'),
                ),
      ],
      body: EntityListView<T>(
        config: config,
        query: queryFromUri(uri, config),
        onQuery: (q) => context.go(
          Uri(
            path: uri.path,
            queryParameters: q.toParams().isEmpty ? null : q.toParams(),
          ).toString(),
        ),
      ),
    );
  }
}

/// Карточка записи: все поля и действия, зависящие от роли.
class EntityDetailScreen<T extends Entity> extends StatefulWidget {
  final EntityConfig<T> config;
  final String id;

  const EntityDetailScreen({super.key, required this.config, required this.id});

  @override
  State<EntityDetailScreen<T>> createState() => _EntityDetailScreenState<T>();
}

class _EntityDetailScreenState<T extends Entity>
    extends State<EntityDetailScreen<T>> {
  late Future<T> _future = _load();

  Future<T> _load() => widget.config.repo(context.read<Repos>()).get(widget.id);

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    final auth = context.watch<AuthNotifier>();
    final canManage = cfg.manage != null && auth.can(cfg.manage!);
    return AppScaffold(
      title: cfg.singular,
      actions: [
        FutureBuilder<T>(
          future: _future,
          builder: (context, snap) {
            final e = snap.data;
            if (e == null || !canManage || !cfg.hasForm || !cfg.canEdit) {
              return const SizedBox.shrink();
            }
            return IconButton(
              tooltip: 'Изменить',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await context.push(cfg.editPath(e));
                if (mounted) _retry();
              },
            );
          },
        ),
      ],
      body: ReconnectListener(
        onReconnect: _retry,
        child: FutureBuilder<T>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              final err = snap.error;
              return RetryMessage(
                text: err is ApiException
                    ? err.message
                    : 'Не удалось загрузить запись.',
                onRetry: _retry,
              );
            }
            final e = snap.data as T;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: formMaxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cfg.cardTitle(e),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        for (final (label, value) in cfg.details)
                          _DetailRow(label, value(e)),
                        if (cfg.detailExtra != null)
                          cfg.detailExtra!(context, e, _retry),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: theme.textTheme.labelLarge),
          ),
          Expanded(child: Text(value.isEmpty ? '—' : value)),
        ],
      ),
    );
  }
}

/// Форма создания и изменения записи типовой сущности.
class EntityFormScreen<T extends Entity> extends StatefulWidget {
  final EntityConfig<T> config;
  final String? id;

  const EntityFormScreen({super.key, required this.config, this.id});

  @override
  State<EntityFormScreen<T>> createState() => _EntityFormScreenState<T>();
}

class _EntityFormScreenState<T extends Entity>
    extends State<EntityFormScreen<T>> {
  FormController? _form;
  late Future<void> _loading = _init();

  bool get _isNew => widget.id == null;
  List<FieldSpec> get _fields => [
    for (final f in widget.config.fields)
      if (!(f.createOnly && !_isNew) && !(f.editOnly && _isNew)) f,
  ];

  Future<void> _init() async {
    if (_isNew) {
      _form = FormController();
      return;
    }
    final e = await widget.config.repo(context.read<Repos>()).get(widget.id!);
    _form = FormController(e.toFormValues());
  }

  void _retry() => setState(() => _loading = _init());

  Future<void> _save(Map<String, dynamic> json) async {
    final cfg = widget.config;
    final repo = cfg.repo(context.read<Repos>());
    final data = cfg.prepare != null ? cfg.prepare!(json, _isNew) : json;
    if (_isNew) {
      await repo.create(data);
    } else {
      await repo.update(widget.id!, data);
    }
    if (mounted) context.read<LookupNotifier>().invalidate();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    return AppScaffold(
      title: _isNew
          ? 'Новая запись: ${cfg.singular.toLowerCase()}'
          : 'Изменение: ${cfg.singular.toLowerCase()}',
      body: FutureBuilder<void>(
        future: _loading,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final err = snap.error;
            return RetryMessage(
              text: err is ApiException
                  ? err.message
                  : 'Не удалось загрузить запись.',
              onRetry: _retry,
            );
          }
          return FormPage(
            controller: _form!,
            fields: _fields,
            onSave: _save,
            saveLabel: _isNew ? 'Создать' : 'Сохранить',
            savedMessage: _isNew ? 'Запись добавлена' : 'Изменения сохранены',
          );
        },
      ),
    );
  }
}
