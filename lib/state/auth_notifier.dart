import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_exceptions.dart';
import '../core/config.dart';
import '../core/pb_api.dart';
import '../models/entities.dart';
import '../models/enums.dart';
import '../models/permissions.dart';
import 'connection_notifier.dart';

const _tokenKey = 'auth_token';
const _userKey = 'auth_user';

/// Разбор срока действия токена JWT (поле `exp`, секунды); null, если не удалось.
DateTime? tokenExpiry(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final exp = (jsonDecode(payload) as Map)['exp'];
    if (exp is num) {
      return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    }
  } catch (_) {}
  return null;
}

/// Вход, регистрация и сессия. Токен и пользователь сохраняются в
/// localStorage, поэтому вход переживает перезагрузку страницы.
///
/// PocketBase не выдаёт отдельный токен обновления: действующий токен
/// продлевается запросом `auth-refresh`. Продление выполняется заранее —
/// пока срок не истёк, а при ответе 401 запрос повторяется после продления.
class AuthNotifier extends ChangeNotifier {
  final SharedPreferences _prefs;
  late final PbApi api;
  Timer? _timer;

  /// Периодически продлевать токен (в тестах отключается).
  final bool autoRefresh;

  String? _token;
  AppUser? _user;
  String? sessionMessage;

  AuthNotifier(
    this._prefs,
    ConnectionNotifier connection, {
    PbApi? apiOverride,
    String baseUrl = apiBaseUrl,
    this.autoRefresh = true,
  }) {
    api =
        apiOverride ??
        PbApi(
          buildDio(
            baseUrl: baseUrl,
            token: () => _token,
            refreshToken: refresh,
            onAuthFailed: () =>
                logout(message: 'Сессия истекла. Войдите снова.'),
            onOnline: connection.reportOnline,
            onOffline: connection.reportOffline,
          ),
        );
    _restore();
  }

  AppUser? get user => _user;
  String? get token => _token;
  bool get isSignedIn => _user != null && _token != null;
  Role? get role => _user?.role;

  bool can(Permission permission) {
    final r = role;
    return r != null && roleCan(r, permission);
  }

  void _restore() {
    final token = _prefs.getString(_tokenKey);
    final raw = _prefs.getString(_userKey);
    if (token == null || raw == null) return;
    try {
      final exp = tokenExpiry(token);
      if (exp != null && exp.isBefore(DateTime.now())) {
        _clear();
        return;
      }
      _token = token;
      _user = AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _startTimer();
    } catch (_) {
      _clear();
    }
  }

  /// Сверяет сохранённого пользователя с сервером: роль в localStorage
  /// может быть подменена, источник истины — токен на сервере.
  Future<void> verifySession() async {
    if (!isSignedIn) return;
    try {
      await refresh();
    } catch (_) {}
  }

  Future<void> login(String email, String password) async {
    final json = await api.post('/api/collections/users/auth-with-password', {
      'identity': email.trim(),
      'password': password,
    });
    await _accept(json);
  }

  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    await api.post('/api/collections/users/records', {
      'email': email.trim(),
      'password': password,
      'passwordConfirm': password,
      'name': name.trim(),
      'phone': phone.trim(),
      'role': Role.client.value,
    });
    await login(email, password);
  }

  /// Продлевает действующий токен. Возвращает false, если сервер его не принял.
  Future<bool> refresh() async {
    if (_token == null) return false;
    try {
      final json = await api.post('/api/collections/users/auth-refresh', {});
      await _accept(json);
      return true;
    } on UnauthorizedException {
      return false;
    } on ApiException {
      return false;
    }
  }

  Future<void> _accept(Map<String, dynamic> json) async {
    final token = json['token'] as String?;
    final record = json['record'];
    if (token == null || record is! Map) {
      throw const ApiException('Сервер вернул неожиданный ответ.');
    }
    _token = token;
    _user = AppUser.fromJson(Map<String, dynamic>.from(record));
    sessionMessage = null;
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_userKey, jsonEncode(_user!.toJson()));
    _startTimer();
    notifyListeners();
  }

  void logout({String? message}) {
    if (!isSignedIn && message == null) return;
    _clear();
    sessionMessage = message;
    notifyListeners();
  }

  void _clear() {
    _timer?.cancel();
    _timer = null;
    _token = null;
    _user = null;
    _prefs.remove(_tokenKey);
    _prefs.remove(_userKey);
  }

  /// Раз в минуту проверяет срок токена и продлевает его заранее.
  void _startTimer() {
    if (!autoRefresh) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
  }

  Future<void> _tick() async {
    final t = _token;
    if (t == null) return;
    final exp = tokenExpiry(t);
    if (exp == null) return;
    final left = exp.difference(DateTime.now());
    if (left.isNegative) {
      logout(message: 'Сессия истекла. Войдите снова.');
    } else if (left < const Duration(hours: 24)) {
      await refresh();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
