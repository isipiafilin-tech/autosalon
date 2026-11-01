import '../core/api_exceptions.dart';
import '../core/pb_api.dart';
import '../models/entities.dart';
import '../models/json_read.dart';
import '../models/list_query.dart';

/// Доступ к записям одной сущности. Экраны и состояние знают только этот
/// интерфейс; смена сервера потребует заменить лишь его реализацию.
abstract class EntityRepository<T extends Entity> {
  /// Условия отбора, которые умеет применять этот репозиторий.
  List<FilterSpec> get filters;

  /// Есть ли у записей логическое удаление (иначе удаление сразу физическое).
  bool get softDeletable;

  Future<PageResult<T>> list(
    ListQuery query, {
    bool deleted = false,
    String? extraFilter,
  });
  Future<T> get(String id);
  Future<T> create(Map<String, dynamic> data);
  Future<T> update(String id, Map<String, dynamic> data);

  /// Логическое удаление: запись остаётся в базе с отметкой времени.
  Future<void> softDelete(String id);
  Future<void> restore(String id);

  /// Физическое удаление без возможности восстановления.
  Future<void> hardDelete(String id);
}

/// Реализация поверх REST API PocketBase.
class PbRepository<T extends Entity> implements EntityRepository<T> {
  final PbApi api;
  final String collection;
  final T Function(Json) fromJson;
  final List<String> searchFields;
  final String expand;
  final String defaultSort;
  @override
  final bool softDeletable;
  @override
  final List<FilterSpec> filters;

  const PbRepository(
    this.api, {
    required this.collection,
    required this.fromJson,
    this.searchFields = const [],
    this.expand = '',
    this.defaultSort = '-created',
    this.softDeletable = true,
    this.filters = const [],
  });

  /// Выражение фильтра PocketBase для условий отбора.
  String buildFilter(ListQuery q, {bool deleted = false, String? extra}) {
    final parts = <String>[];
    if (softDeletable) {
      parts.add(deleted ? 'deletedAt != ""' : 'deletedAt = ""');
    }
    if (q.search.isNotEmpty && searchFields.isNotEmpty) {
      final like = pbQuote(q.search);
      parts.add('(${searchFields.map((f) => '$f ~ $like').join(' || ')})');
    }
    for (final spec in filters) {
      final value = q.filters[spec.key];
      if (value == null) continue;
      final expr = spec.expression(value);
      if (expr != null) parts.add(expr);
    }
    if (extra != null && extra.isNotEmpty) parts.add('($extra)');
    return parts.join(' && ');
  }

  @override
  Future<PageResult<T>> list(
    ListQuery query, {
    bool deleted = false,
    String? extraFilter,
  }) async {
    final json = await api.get(
      PbApi.records(collection),
      query: {
        'page': query.page,
        'perPage': query.perPage,
        'sort': query.sort.isEmpty ? defaultSort : query.sort,
        'filter': buildFilter(query, deleted: deleted, extra: extraFilter),
        if (expand.isNotEmpty) 'expand': expand,
      },
    );
    final items = json['items'];
    return PageResult(
      items: [
        if (items is List)
          for (final e in items) fromJson(Map<String, dynamic>.from(e as Map)),
      ],
      page: integer(json, 'page'),
      size: integer(json, 'perPage'),
      total: integer(json, 'totalItems'),
      totalPages: integer(json, 'totalPages') == 0
          ? 1
          : integer(json, 'totalPages'),
    );
  }

  @override
  Future<T> get(String id) async => fromJson(
    await api.get(
      PbApi.records(collection, id),
      query: {if (expand.isNotEmpty) 'expand': expand},
    ),
  );

  @override
  Future<T> create(Map<String, dynamic> data) async =>
      fromJson(await api.post(PbApi.records(collection), _withExpand(data)));

  @override
  Future<T> update(String id, Map<String, dynamic> data) async => fromJson(
    await api.patch(PbApi.records(collection, id), _withExpand(data)),
  );

  // PocketBase принимает expand и в теле запроса, поэтому ответ приходит
  // с развёрнутыми связями, как и у списка.
  Map<String, dynamic> _withExpand(Map<String, dynamic> data) => data;

  @override
  Future<void> softDelete(String id) async {
    if (!softDeletable) return hardDelete(id);
    await api.patch(PbApi.records(collection, id), {
      'deletedAt': pbDate(DateTime.now()),
    });
  }

  @override
  Future<void> restore(String id) async {
    await api.patch(PbApi.records(collection, id), {'deletedAt': ''});
  }

  @override
  Future<void> hardDelete(String id) async {
    try {
      await api.delete(PbApi.records(collection, id));
    } on ApiException catch (e) {
      // PocketBase не удаляет запись, на которую ссылаются другие записи.
      if (e.status == 400) {
        throw const ConflictException(
          'Запись используется в других данных, удалить её нельзя.',
          {},
        );
      }
      rethrow;
    }
  }
}
