import 'entities.dart';
import 'enums.dart';

/// Пересекаются ли два интервала времени. Границы не пересекаются:
/// тест-драйв, который заканчивается в 12:00, не мешает начаться другому в 12:00.
bool intervalsOverlap(
  DateTime aStart,
  DateTime aEnd,
  DateTime bStart,
  DateTime bEnd,
) => aStart.isBefore(bEnd) && aEnd.isAfter(bStart);

/// Тест-драйвы автомобиля, мешающие выбранному времени.
List<TestDrive> conflictsFor(
  Iterable<TestDrive> drives,
  String carId,
  DateTime start,
  DateTime end, {
  String? exceptId,
}) => [
  for (final d in drives)
    if (d.carId == carId &&
        d.id != exceptId &&
        d.status == DriveStatus.planned &&
        intervalsOverlap(start, end, d.startsAt, d.endsAt))
      d,
];

/// Наибольшая длительность тест-драйва.
const maxDriveDuration = Duration(hours: 3);

/// Ошибка выбранного интервала по тем же правилам, что и на сервере; null — всё в порядке.
String? validateInterval(DateTime start, DateTime end, {DateTime? now}) {
  if (!end.isAfter(start)) return 'Окончание должно быть позже начала';
  if (end.difference(start) > maxDriveDuration) {
    return 'Тест-драйв не длиннее трёх часов';
  }
  if (start.isBefore(now ?? DateTime.now())) return 'Время начала уже прошло';
  return null;
}
