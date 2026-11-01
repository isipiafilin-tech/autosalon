/// Адрес сервера PocketBase задаётся при сборке:
/// flutter build web --dart-define=API_BASE_URL=http://127.0.0.1:8090
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8090',
);

/// Выход из системы по неактивности (секунды) и предупреждение перед ним.
const inactivitySeconds = int.fromEnvironment(
  'INACTIVITY_SECONDS',
  defaultValue: 900,
);
const inactivityTimeout = Duration(seconds: inactivitySeconds);
const inactivityWarning = Duration(seconds: 30);

/// Размеры страницы в списках.
const pageSizes = [10, 20, 50];
const defaultPageSize = 10;
