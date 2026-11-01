/// Чтение полей из JSON-ответа PocketBase: пропущенное поле не ломает разбор.
typedef Json = Map<String, dynamic>;

String str(Json m, String k) => m[k]?.toString() ?? '';

double dbl(Json m, String k) {
  final v = m[k];
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0;
}

int integer(Json m, String k) => dbl(m, k).round();

int? integerOrNull(Json m, String k) {
  final v = m[k];
  if (v == null || v == '') return null;
  return dbl(m, k).round();
}

/// PocketBase хранит даты как `2026-11-01 10:00:00.000Z`.
DateTime? dateOf(Json m, String k) {
  final s = str(m, k);
  if (s.isEmpty) return null;
  return DateTime.tryParse(s.replaceFirst(' ', 'T'))?.toLocal();
}

String pbDate(DateTime d) => d.toUtc().toIso8601String().replaceFirst('T', ' ');

List<String> strList(Json m, String k) {
  final v = m[k];
  if (v is List) return [for (final e in v) '$e'];
  if (v is String && v.isNotEmpty) return [v];
  return const [];
}

/// Связанная запись из `expand`.
Json expandOne(Json m, String k) {
  final e = m['expand'];
  if (e is Map && e[k] is Map) return Map<String, dynamic>.from(e[k] as Map);
  return const {};
}

List<Json> expandMany(Json m, String k) {
  final e = m['expand'];
  if (e is Map && e[k] is List) {
    return [for (final x in e[k] as List) Map<String, dynamic>.from(x as Map)];
  }
  if (e is Map && e[k] is Map) {
    return [Map<String, dynamic>.from(e[k] as Map)];
  }
  return const [];
}
