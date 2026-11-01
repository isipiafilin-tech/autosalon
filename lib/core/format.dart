// Форматирование значений для показа пользователю.

/// Сумма в рублях с неразрывными пробелами: 3 400 000 ₽.
String money(num value) {
  final s = value.round().abs().toString();
  final b = StringBuffer(value < 0 ? '−' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return '$b ₽';
}

String _two(int n) => n.toString().padLeft(2, '0');

String formatDate(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';

String formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

String formatDateTime(DateTime d) => '${formatDate(d)} ${formatTime(d)}';

/// Дата в виде `2026-11-01` для условий отбора и адресной строки.
String isoDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// Пробег: 12 500 км.
String kilometers(int km) => '${money(km).replaceAll(' ₽', '')} км';
