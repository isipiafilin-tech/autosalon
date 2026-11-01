import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/format.dart';
import '../models/entities.dart';
import '../models/list_query.dart';
import '../repositories/repos.dart';
import '../screens/entity_config.dart';
import '../state/auth_notifier.dart';
import '../state/list_notifier.dart';
import '../state/lookup_notifier.dart';
import 'adaptive.dart';
import 'connection_widgets.dart';
import 'debounced_text_field.dart';
import 'dialogs.dart';
import 'pagination_bar.dart';

/// Типовой список: поиск, фильтры, сортировка, таблица или карточки,
/// постраничный вывод, выбор нескольких записей и их удаление.
/// Все условия отбора берутся из [query] и сообщаются через [onQuery]
/// (экран записывает их в адресную строку); отбор выполняет сервер.
class EntityListView<T extends Entity> extends StatefulWidget {
  final EntityConfig<T> config;
  final ListQuery query;
  final ValueChanged<ListQuery> onQuery;
  final bool trash;
  final String? extraFilter;

  /// Скрыть кнопки изменения (список «только для просмотра»).
  final bool readOnly;

  const EntityListView({
    super.key,
    required this.config,
    required this.query,
    required this.onQuery,
    this.trash = false,
    this.extraFilter,
    this.readOnly = false,
  });

  @override
  State<EntityListView<T>> createState() => _EntityListViewState<T>();
}

class _EntityListViewState<T extends Entity> extends State<EntityListView<T>> {
  late final ListNotifier<T> _notifier;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    final repo = widget.config.repo(context.read<Repos>());
    _notifier = ListNotifier<T>(
      repo,
      deleted: widget.trash,
      extraFilter: widget.extraFilter,
    )..load(widget.query);
  }

  @override
  void didUpdateWidget(covariant EntityListView<T> old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) {
      _selected.clear();
      _notifier.load(widget.query);
    }
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  EntityConfig<T> get cfg => widget.config;

  bool _can(AuthNotifier auth) =>
      !widget.readOnly && cfg.manage != null && auth.can(cfg.manage!);
  bool _canPurge(AuthNotifier auth) =>
      cfg.purge != null && auth.can(cfg.purge!);

  void _changed() {
    context.read<LookupNotifier>().invalidate();
    _selected.clear();
    _notifier.reload();
  }

  Future<void> _run(
    Future<void> Function(T) action,
    List<T> items, {
    required String done,
  }) async {
    var failed = 0;
    String? firstError;
    await Future.wait([
      for (final e in items)
        action(e).catchError((Object error) {
          failed++;
          firstError ??= error is ApiException ? error.message : '$error';
        }),
    ]);
    if (!mounted) return;
    final ok = items.length - failed;
    if (failed == 0) {
      showMessage(context, ok == 1 ? done : '$done: $ok');
    } else {
      showMessage(
        context,
        'Выполнено: $ok, не удалось: $failed. $firstError',
        error: true,
      );
    }
    _changed();
  }

  Future<void> _softDelete(List<T> items) async {
    final repo = cfg.repo(context.read<Repos>());
    final where = repo.softDeletable
        ? 'перенесена в корзину'
        : 'удалена навсегда';
    final text = items.length == 1
        ? 'Запись «${items.first.title}» будет $where.'
        : 'Выбранные записи (${items.length}) будут $where.';
    if (!await confirm(context, title: 'Удалить?', text: text)) return;
    await _run((e) => repo.softDelete(e.id), items, done: 'Запись удалена');
  }

  Future<void> _restore(List<T> items) async {
    final repo = cfg.repo(context.read<Repos>());
    await _run((e) => repo.restore(e.id), items, done: 'Запись восстановлена');
  }

  Future<void> _purge(List<T> items) async {
    final text = items.length == 1
        ? 'Запись «${items.first.title}» будет удалена навсегда. Восстановить её будет нельзя.'
        : 'Выбранные записи (${items.length}) будут удалены навсегда.';
    if (!await confirm(
      context,
      title: 'Удалить навсегда?',
      text: text,
      action: 'Удалить навсегда',
    )) {
      return;
    }
    if (!mounted) return;
    final repo = cfg.repo(context.read<Repos>());
    await _run(
      (e) => repo.hardDelete(e.id),
      items,
      done: 'Запись удалена навсегда',
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final repo = cfg.repo(context.read<Repos>());
    return ReconnectListener(
      onReconnect: _notifier.reload,
      child: ListenableBuilder(
        listenable: _notifier,
        builder: (context, _) {
          final page = _notifier.page;
          return Column(
            children: [
              _FilterPanel<T>(
                config: cfg,
                filters: repo.filters,
                query: widget.query,
                onQuery: widget.onQuery,
              ),
              if (_selected.isNotEmpty) _selectionBar(auth),
              Expanded(child: _content(auth)),
              if (page != null && _notifier.status == ListStatus.data)
                PaginationBar(
                  page: page,
                  onPage: (p) => widget.onQuery(widget.query.copyWith(page: p)),
                  onSize: (s) => widget.onQuery(
                    widget.query.copyWith(perPage: s, page: 1),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _selectionBar(AuthNotifier auth) {
    final items = [
      for (final e in _notifier.page?.items ?? <T>[])
        if (_selected.contains(e.id)) e,
    ];
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            Text('Выбрано: ${items.length}'),
            if (widget.trash) ...[
              if (_canPurge(auth))
                OutlinedButton.icon(
                  onPressed: () => _restore(items),
                  icon: const Icon(Icons.restore),
                  label: const Text('Восстановить'),
                ),
              if (_canPurge(auth))
                OutlinedButton.icon(
                  onPressed: () => _purge(items),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Удалить навсегда'),
                ),
            ] else if (_can(auth))
              OutlinedButton.icon(
                onPressed: () => _softDelete(items),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Удалить выбранные'),
              ),
            TextButton(
              onPressed: () => setState(_selected.clear),
              child: const Text('Снять выделение'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(AuthNotifier auth) {
    switch (_notifier.status) {
      case ListStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case ListStatus.error:
        return RetryMessage(
          text: _notifier.error?.message ?? 'Не удалось загрузить данные.',
          onRetry: _notifier.reload,
        );
      case ListStatus.empty:
        return _empty(auth);
      case ListStatus.data:
        final items = _notifier.page!.items;
        final size = windowSizeOf(context);
        return size == WindowSize.expanded
            ? _table(items, auth)
            : _cards(items, auth);
    }
  }

  Widget _empty(AuthNotifier auth) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              widget.trash ? 'Корзина пуста' : 'Ничего не найдено',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (widget.query.hasConditions) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    widget.onQuery(ListQuery(perPage: widget.query.perPage)),
                child: const Text('Сбросить условия'),
              ),
            ] else if (!widget.trash && _can(auth) && cfg.hasForm) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.push(cfg.newPath),
                icon: const Icon(Icons.add),
                label: const Text('Добавить'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(T e, AuthNotifier auth) {
    if (widget.trash) {
      if (!_canPurge(auth)) return const [];
      return [
        IconButton(
          tooltip: 'Восстановить',
          icon: const Icon(Icons.restore),
          onPressed: () => _restore([e]),
        ),
        IconButton(
          tooltip: 'Удалить навсегда',
          icon: const Icon(Icons.delete_forever_outlined),
          onPressed: () => _purge([e]),
        ),
      ];
    }
    return [
      if (cfg.hasDetail)
        IconButton(
          tooltip: 'Открыть',
          icon: const Icon(Icons.visibility_outlined),
          onPressed: () => context.push(cfg.detailPath(e)),
        ),
      if (_can(auth) && cfg.hasForm && cfg.canEdit)
        IconButton(
          tooltip: 'Изменить',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => context.push(cfg.editPath(e)),
        ),
      if (_can(auth))
        IconButton(
          tooltip: 'Удалить',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _softDelete([e]),
        ),
    ];
  }

  bool _selectable(AuthNotifier auth) =>
      widget.trash ? _canPurge(auth) : _can(auth);

  Widget _table(List<T> items, AuthNotifier auth) {
    final selectable = _selectable(auth);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              columnSpacing: 20,
              horizontalMargin: 12,
              showCheckboxColumn: selectable,
              onSelectAll: selectable
                  ? (on) => setState(() {
                      _selected.clear();
                      if (on == true) _selected.addAll(items.map((e) => e.id));
                    })
                  : null,
              columns: [
                for (final c in cfg.columns)
                  DataColumn(label: Text(c.label), numeric: c.numeric),
                const DataColumn(label: Text('')),
              ],
              rows: [
                for (final e in items)
                  DataRow(
                    selected: _selected.contains(e.id),
                    onSelectChanged: selectable
                        ? (on) => setState(() {
                            on == true
                                ? _selected.add(e.id)
                                : _selected.remove(e.id);
                          })
                        : null,
                    cells: [
                      for (final c in cfg.columns)
                        DataCell(
                          c.cell != null
                              ? c.cell!(context, e)
                              : ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 280,
                                  ),
                                  child: Text(
                                    c.value(e),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                        ),
                      DataCell(Row(children: _actions(e, auth))),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cards(List<T> items, AuthNotifier auth) {
    final selectable = _selectable(auth);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ResponsiveGrid(
          children: [
            for (final e in items)
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: cfg.hasDetail && !widget.trash
                      ? () => context.push(cfg.detailPath(e))
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (selectable)
                              Checkbox(
                                value: _selected.contains(e.id),
                                semanticLabel: 'Выбрать: ${cfg.cardTitle(e)}',
                                onChanged: (on) => setState(() {
                                  on == true
                                      ? _selected.add(e.id)
                                      : _selected.remove(e.id);
                                }),
                              ),
                            Expanded(
                              child: Text(
                                cfg.cardTitle(e),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: EdgeInsets.only(left: selectable ? 12 : 0),
                          child: Text(
                            cfg.cardSubtitle(e),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final c
                            in cfg.columns.where((c) => c.inCard).take(4))
                          Padding(
                            padding: EdgeInsets.only(
                              left: selectable ? 12 : 0,
                              bottom: 2,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${c.label}: ',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Expanded(
                                  child: Text(
                                    c.value(e),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(children: _actions(e, auth)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Панель поиска, сортировки и фильтров.
class _FilterPanel<T extends Entity> extends StatelessWidget {
  final EntityConfig<T> config;
  final List<FilterSpec> filters;
  final ListQuery query;
  final ValueChanged<ListQuery> onQuery;

  const _FilterPanel({
    required this.config,
    required this.filters,
    required this.query,
    required this.onQuery,
  });

  @override
  Widget build(BuildContext context) {
    final compact = windowSizeOf(context) == WindowSize.compact;
    final sortValue = config.sorts.any((s) => s.$1 == query.sort)
        ? query.sort
        : config.sorts.first.$1;
    final controls = [
      for (final f in filters)
        SizedBox(
          width: compact ? double.infinity : 210,
          child: _filterField(context, f),
        ),
    ];
    final head = Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: compact ? double.infinity : 280,
          child: DebouncedTextField(
            label: 'Поиск',
            icon: Icons.search,
            value: query.search,
            onChanged: (v) => onQuery(query.copyWith(search: v, page: 1)),
          ),
        ),
        SizedBox(
          width: compact ? double.infinity : 230,
          child: DropdownButtonFormField<String>(
            value: sortValue,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Сортировка'),
            items: [
              for (final (value, label) in config.sorts)
                DropdownMenuItem(value: value, child: Text(label)),
            ],
            onChanged: (v) {
              if (v != null) onQuery(query.copyWith(sort: v, page: 1));
            },
          ),
        ),
        if (query.hasConditions)
          TextButton.icon(
            onPressed: () => onQuery(ListQuery(perPage: query.perPage)),
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Сбросить'),
          ),
      ],
    );
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        head,
        if (controls.isNotEmpty && !compact) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: controls),
        ],
      ],
    );
    if (compact && controls.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(
          children: [
            head,
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                query.filters.isEmpty
                    ? 'Фильтры'
                    : 'Фильтры (${query.filters.length})',
              ),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [Wrap(spacing: 12, runSpacing: 12, children: controls)],
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: body,
    );
  }

  Widget _filterField(BuildContext context, FilterSpec f) {
    final value = query.filters[f.key] ?? '';
    switch (f.kind) {
      case FilterKind.select:
        return _dropdown(f.label, value, [
          for (final (v, l) in f.options) LookupItem(v, l),
        ], (v) => onQuery(query.withFilter(f.key, v)));
      case FilterKind.relation:
        return FutureBuilder<List<LookupItem>>(
          future: context.read<LookupNotifier>().items(f.lookup!),
          builder: (context, snap) => _dropdown(
            f.label,
            value,
            snap.data ?? const [],
            (v) => onQuery(query.withFilter(f.key, v)),
          ),
        );
      case FilterKind.dateFrom:
      case FilterKind.dateTo:
        return _DateFilter(
          label: f.label,
          value: value,
          onChanged: (v) => onQuery(query.withFilter(f.key, v)),
        );
      default:
        return DebouncedTextField(
          label: f.label,
          value: value,
          digitsOnly: f.isNumeric,
          onChanged: (v) => onQuery(query.withFilter(f.key, v.trim())),
        );
    }
  }

  Widget _dropdown(
    String label,
    String value,
    List<LookupItem> items,
    ValueChanged<String?> onChanged,
  ) {
    final known = value.isEmpty || items.any((i) => i.id == value);
    return DropdownButtonFormField<String>(
      value: known ? value : '',
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: '', child: Text('Все')),
        for (final i in items)
          DropdownMenuItem(
            value: i.id,
            child: Text(i.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) => onChanged(v),
    );
  }
}

class _DateFilter extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String?> onChanged;

  const _DateFilter({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(value);
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: parsed ?? now,
          firstDate: DateTime(1930),
          lastDate: DateTime(now.year + 5),
        );
        if (picked != null) onChanged(isoDate(picked));
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: parsed == null
              ? const Icon(Icons.calendar_today_outlined, size: 18)
              : IconButton(
                  tooltip: 'Очистить',
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                ),
        ),
        child: Text(parsed == null ? '' : formatDate(parsed)),
      ),
    );
  }
}
