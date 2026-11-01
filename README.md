Автосалон. Клиент на Flutter Web, сервер на PocketBase 0.40.6 (папка pocketbase).

Учётные записи:
администратор admin@autosalon.ru / admin12345
менеджер manager@autosalon.ru / manager12345
клиент client@autosalon.ru / client12345

Запуск сервера (положить pocketbase.exe в папку pocketbase):
cd pocketbase
./pocketbase superuser upsert admin@autosalon.local Admin12345
./pocketbase serve
node seed.mjs

Запуск клиента:
flutter pub get
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 5000

Адрес сервера по умолчанию http://127.0.0.1:8090, меняется параметром --dart-define=API_BASE_URL=...

Схема базы данных: pocketbase/schema.sql и pocketbase/pb_schema.json
Диаграммы: папка docs
Проверки: dart format --set-exit-if-changed lib test, flutter analyze, flutter test
Публикация на GitHub Pages: .github/workflows/deploy.yml
