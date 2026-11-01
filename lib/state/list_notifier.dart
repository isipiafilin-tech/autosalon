import 'package:flutter/foundation.dart';

import '../core/api_exceptions.dart';
import '../models/entities.dart';
import '../models/list_query.dart';
import '../repositories/entity_repository.dart';

/// Четыре состояния экрана со списком.
enum ListStatus { loading, data, empty, error }

/// Состояние списка записей одной сущности. Пустой результат — отдельное
/// состояние: он не ошибка и не загрузка.
class ListNotifier<T extends Entity> extends ChangeNotifier {
  final EntityRepository<T> repo;
  final bool deleted;
  final String? extraFilter;

  ListNotifier(this.repo, {this.deleted = false, this.extraFilter});

  ListStatus _status = ListStatus.loading;
  PageResult<T>? _page;
  ApiException? _error;
  ListQuery _query = const ListQuery();
  int _generation = 0;

  ListStatus get status => _status;
  PageResult<T>? get page => _page;
  ApiException? get error => _error;
  ListQuery get query => _query;

  Future<void> load(ListQuery query) {
    _query = query;
    return reload();
  }

  Future<void> reload() async {
    final generation = ++_generation;
    // Прежние данные остаются на экране, пока идёт обновление той же страницы.
    if (_page == null || _status == ListStatus.error) {
      _status = ListStatus.loading;
      notifyListeners();
    }
    try {
      var result = await repo.list(
        _query,
        deleted: deleted,
        extraFilter: extraFilter,
      );
      // Страница за пределами списка (запись удалили): показываем последнюю.
      if (result.items.isEmpty && result.total > 0 && _query.page > 1) {
        _query = _query.copyWith(page: result.totalPages);
        result = await repo.list(
          _query,
          deleted: deleted,
          extraFilter: extraFilter,
        );
      }
      if (generation != _generation) return;
      _page = result;
      _error = null;
      _status = result.total == 0 ? ListStatus.empty : ListStatus.data;
    } on ApiException catch (e) {
      if (generation != _generation) return;
      _error = e;
      _status = ListStatus.error;
    }
    notifyListeners();
  }
}
