import '../core/config.dart';

/// Одна страница результата списка.
class PageResult<T> {
  final List<T> items;
  final int page;
  final int size;
  final int total;
  final int totalPages;

  const PageResult({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
    required this.totalPages,
  });

  bool get hasPrevious => page > 1;
  bool get hasNext => page < totalPages;
}

/// Условия отбора списка: поиск, фильтры, сортировка, страница.
/// Целиком записываются в адрес страницы (см. [toParams]) и читаются из него,
/// поэтому ссылку на отфильтрованный список можно передать другому.
class ListQuery {
  final int page;
  final int perPage;
  final String search;
  final String sort;
  final Map<String, String> filters;

  const ListQuery({
    this.page = 1,
    this.perPage = defaultPageSize,
    this.search = '',
    this.sort = '',
    this.filters = const {},
  });

  static const filterPrefix = 'f_';

  ListQuery copyWith({
    int? page,
    int? perPage,
    String? search,
    String? sort,
    Map<String, String>? filters,
  }) => ListQuery(
    page: page ?? this.page,
    perPage: perPage ?? this.perPage,
    search: search ?? this.search,
    sort: sort ?? this.sort,
    filters: filters ?? this.filters,
  );

  /// Новое значение фильтра; пустое значение убирает фильтр. Страница сбрасывается.
  ListQuery withFilter(String key, String? value) {
    final next = Map<String, String>.of(filters);
    if (value == null || value.isEmpty) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    return copyWith(filters: next, page: 1);
  }

  bool get hasConditions => search.isNotEmpty || filters.isNotEmpty;

  /// Параметры адресной строки; значения по умолчанию не пишутся.
  Map<String, String> toParams() => {
    if (search.isNotEmpty) 'q': search,
    if (sort.isNotEmpty) 'sort': sort,
    if (page > 1) 'page': '$page',
    if (perPage != defaultPageSize) 'size': '$perPage',
    for (final e in filters.entries) '$filterPrefix${e.key}': e.value,
  };

  factory ListQuery.fromParams(Map<String, String> p) {
    final size = int.tryParse(p['size'] ?? '') ?? defaultPageSize;
    return ListQuery(
      page: (int.tryParse(p['page'] ?? '') ?? 1).clamp(1, 100000),
      perPage: pageSizes.contains(size) ? size : defaultPageSize,
      search: p['q'] ?? '',
      sort: p['sort'] ?? '',
      filters: {
        for (final e in p.entries)
          if (e.key.startsWith(filterPrefix) && e.value.isNotEmpty)
            e.key.substring(filterPrefix.length): e.value,
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ListQuery &&
      other.page == page &&
      other.perPage == perPage &&
      other.search == search &&
      other.sort == sort &&
      other.filters.length == filters.length &&
      filters.entries.every((e) => other.filters[e.key] == e.value);

  @override
  int get hashCode => Object.hash(page, perPage, search, sort, filters.length);
}

/// Строковый литерал языка фильтров PocketBase.
String pbQuote(String value) =>
    '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

enum FilterKind { select, relation, min, max, dateFrom, dateTo, contains }

/// Описание одного условия отбора: что показать пользователю и как
/// превратить введённое значение в выражение фильтра PocketBase.
class FilterSpec {
  final String key;
  final String label;
  final String field;
  final FilterKind kind;
  final List<(String, String)> options;
  final String? lookup;

  const FilterSpec.select(this.key, this.label, this.field, this.options)
    : kind = FilterKind.select,
      lookup = null;

  const FilterSpec.relation(
    this.key,
    this.label,
    this.field,
    String this.lookup,
  ) : kind = FilterKind.relation,
      options = const [];

  const FilterSpec.contains(this.key, this.label, this.field)
    : kind = FilterKind.contains,
      options = const [],
      lookup = null;

  const FilterSpec.min(this.key, this.label, this.field)
    : kind = FilterKind.min,
      options = const [],
      lookup = null;

  const FilterSpec.max(this.key, this.label, this.field)
    : kind = FilterKind.max,
      options = const [],
      lookup = null;

  const FilterSpec.dateFrom(this.key, this.label, this.field)
    : kind = FilterKind.dateFrom,
      options = const [],
      lookup = null;

  const FilterSpec.dateTo(this.key, this.label, this.field)
    : kind = FilterKind.dateTo,
      options = const [],
      lookup = null;

  bool get isNumeric => kind == FilterKind.min || kind == FilterKind.max;
  bool get isDate => kind == FilterKind.dateFrom || kind == FilterKind.dateTo;

  /// Выражение фильтра или `null`, если значение не подходит.
  String? expression(String value) {
    if (value.isEmpty) return null;
    switch (kind) {
      case FilterKind.select:
      case FilterKind.relation:
        return '$field = ${pbQuote(value)}';
      case FilterKind.contains:
        return '$field ~ ${pbQuote(value)}';
      case FilterKind.min:
        final n = num.tryParse(value);
        return n == null ? null : '$field >= $n';
      case FilterKind.max:
        final n = num.tryParse(value);
        return n == null ? null : '$field <= $n';
      case FilterKind.dateFrom:
        return DateTime.tryParse(value) == null
            ? null
            : '$field >= ${pbQuote('$value 00:00:00.000Z')}';
      case FilterKind.dateTo:
        return DateTime.tryParse(value) == null
            ? null
            : '$field <= ${pbQuote('$value 23:59:59.999Z')}';
    }
  }
}
