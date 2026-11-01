/// Проверки полей ввода. Каждая возвращает текст ошибки или null.
typedef Validator = String? Function(String?);

Validator notEmpty() =>
    (v) => v == null || v.trim().isEmpty ? 'Заполните поле' : null;

Validator minLength(int n) =>
    (v) => v != null && v.trim().isNotEmpty && v.trim().length < n
    ? 'Не короче $n символов'
    : null;

Validator maxLength(int n) =>
    (v) => v != null && v.trim().length > n ? 'Не длиннее $n символов' : null;

Validator pattern(RegExp re, String message) =>
    (v) => v != null && v.trim().isNotEmpty && !re.hasMatch(v.trim())
    ? message
    : null;

/// Целое число в диапазоне; пустое значение допустимо (обязательность — отдельно).
Validator intRange(int min, int max) => (v) {
  if (v == null || v.trim().isEmpty) return null;
  final n = int.tryParse(v.trim());
  if (n == null) return 'Введите целое число';
  if (n < min) return 'Не меньше $min';
  if (n > max) return 'Не больше $max';
  return null;
};

Validator numRange(num min, num max) => (v) {
  if (v == null || v.trim().isEmpty) return null;
  final n = num.tryParse(v.trim().replaceAll(',', '.'));
  if (n == null) return 'Введите число';
  if (n < min) return 'Не меньше $min';
  if (n > max) return 'Не больше $max';
  return null;
};

final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');
final phonePattern = RegExp(r'^\+?[0-9\s\-()]{10,20}$');
final vinPattern = RegExp(r'^[A-HJ-NPR-Z0-9]{17}$');

Validator email() => pattern(emailPattern, 'Введите адрес электронной почты');
Validator phone() =>
    pattern(phonePattern, 'Телефон в формате +7 (900) 123-45-67');
Validator vin() => pattern(
  vinPattern,
  '17 символов: латинские заглавные буквы (кроме I, O, Q) и цифры',
);

/// Правила пароля; тот же список показывается пользователю при регистрации.
const passwordRules = <(String, bool Function(String))>[
  ('Не короче 8 символов', _hasLength),
  ('Есть цифра', _hasDigit),
  ('Есть буква', _hasLetter),
];

bool _hasLength(String s) => s.length >= 8;
bool _hasDigit(String s) => RegExp(r'\d').hasMatch(s);
bool _hasLetter(String s) => RegExp(r'[A-Za-zА-Яа-яЁё]').hasMatch(s);

Validator strongPassword() => (v) {
  final value = v ?? '';
  if (value.isEmpty) return 'Заполните поле';
  for (final (label, ok) in passwordRules) {
    if (!ok(value)) return label;
  }
  return null;
};

/// Первая ошибка из списка проверок.
String? firstError(String? value, Iterable<Validator> validators) {
  for (final v in validators) {
    final error = v(value);
    if (error != null) return error;
  }
  return null;
}
