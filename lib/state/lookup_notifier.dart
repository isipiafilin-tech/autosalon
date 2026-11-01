import 'package:flutter/foundation.dart';

import '../core/pb_api.dart';
import '../models/enums.dart';
import '../models/json_read.dart';

/// Элемент выпадающего списка связи.
class LookupItem {
  final String id;
  final String label;

  const LookupItem(this.id, this.label);
}

class _Source {
  final String collection;
  final String expand;
  final String sort;
  final String filter;
  final String Function(Json) label;

  const _Source(
    this.collection,
    this.label, {
    this.expand = '',
    this.sort = '',
    this.filter = 'deletedAt = ""',
  });
}

String _money(double v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

String _carLabel(Json j) {
  final model = expandOne(j, 'model');
  final brand = str(expandOne(model, 'brand'), 'name');
  final vin = str(j, 'vin');
  final tail = vin.length > 6 ? vin.substring(vin.length - 6) : vin;
  return '$brand ${str(model, 'name')}, ${str(j, 'year')} · $tail';
}

/// Справочники для выпадающих списков и фильтров. Каждый загружается один
/// раз; после изменения данных кэш сбрасывается через [invalidate].
class LookupNotifier extends ChangeNotifier {
  final PbApi api;

  LookupNotifier(this.api);

  final Map<String, Future<List<LookupItem>>> _cache = {};

  static final Map<String, _Source> _sources = {
    'brands': _Source('brands', (j) => str(j, 'name'), sort: 'name'),
    'models': _Source(
      'car_models',
      (j) => '${str(expandOne(j, 'brand'), 'name')} ${str(j, 'name')}',
      expand: 'brand',
      sort: 'name',
    ),
    'options': _Source(
      'options',
      (j) => '${str(j, 'name')} — ${_money(dbl(j, 'price'))} ₽',
      sort: 'name',
    ),
    'services': _Source(
      'services',
      (j) => '${str(j, 'name')} — ${_money(dbl(j, 'price'))} ₽',
      sort: 'name',
    ),
    'customers': _Source(
      'customers',
      (j) => str(j, 'fullName'),
      sort: 'fullName',
    ),
    'cars': _Source('cars', _carLabel, expand: 'model.brand', sort: '-created'),
    'carsFree': _Source(
      'cars',
      _carLabel,
      expand: 'model.brand',
      sort: '-created',
      filter: 'deletedAt = "" && status = "available"',
    ),
    'managers': _Source(
      'users',
      (j) => str(j, 'name'),
      sort: 'name',
      filter: 'role = "${Role.manager.value}"',
    ),
    'dealsApproved': _Source(
      'deals',
      (j) =>
          '${str(expandOne(j, 'customer'), 'fullName')} — '
          '${_carLabel(expandOne(j, 'car'))} (${_money(dbl(j, 'totalPrice'))} ₽)',
      expand: 'customer,car.model.brand',
      sort: '-created',
      filter: 'deletedAt = "" && status = "approved"',
    ),
  };

  Future<List<LookupItem>> items(String key) =>
      _cache.putIfAbsent(key, () => _load(key));

  Future<List<LookupItem>> _load(String key) async {
    final source = _sources[key];
    if (source == null) return const [];
    try {
      final json = await api.get(
        PbApi.records(source.collection),
        query: {
          'perPage': 500,
          if (source.sort.isNotEmpty) 'sort': source.sort,
          if (source.filter.isNotEmpty) 'filter': source.filter,
          if (source.expand.isNotEmpty) 'expand': source.expand,
          'skipTotal': true,
        },
      );
      final list = json['items'];
      return [
        if (list is List)
          for (final e in list)
            LookupItem(
              str(Map<String, dynamic>.from(e as Map), 'id'),
              source.label(Map<String, dynamic>.from(e)),
            ),
      ];
    } catch (_) {
      _cache.remove(key);
      rethrow;
    }
  }

  /// Сбрасывает кэш (все справочники или один).
  void invalidate([String? key]) {
    if (key == null) {
      _cache.clear();
    } else {
      _cache.remove(key);
    }
    notifyListeners();
  }
}
