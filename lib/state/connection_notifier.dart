import 'dart:async';

import 'package:flutter/foundation.dart';

/// Связь с сервером. После сетевого сбоя приложение само проверяет сервер
/// через равные промежутки и, как только он ответит, сообщает об этом:
/// экраны загружают данные заново без перезагрузки страницы.
class ConnectionNotifier extends ChangeNotifier {
  final Future<void> Function() _ping;
  final Duration interval;

  ConnectionNotifier(this._ping, {this.interval = const Duration(seconds: 5)});

  bool _online = true;
  Timer? _timer;

  bool get online => _online;

  void reportOffline() {
    if (!_online) return;
    _online = false;
    _timer = Timer.periodic(interval, (_) => _check());
    notifyListeners();
  }

  void reportOnline() {
    if (_online) return;
    _online = true;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  Future<void> _check() async {
    try {
      await _ping();
    } catch (_) {
      // Ответ сервера, в том числе с ошибкой, сообщит интерсептор Dio;
      // здесь остаётся только дождаться следующей проверки.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
