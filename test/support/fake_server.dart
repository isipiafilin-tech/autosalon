import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Ответ поддельного сервера.
class FakeResponse {
  final int status;
  final Object? body;
  final Duration delay;

  const FakeResponse(this.status, [this.body, this.delay = Duration.zero]);
}

/// Подменяет сеть: запросы Dio обрабатываются функцией [handler].
/// Так проверяется весь путь запроса — репозиторий, Dio, разбор ответа.
class FakeServer implements HttpClientAdapter {
  FutureOr<FakeResponse> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  FakeServer(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final r = await handler(options);
    if (r.delay > Duration.zero) await Future<void>.delayed(r.delay);
    if (r.status == -1) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'нет соединения',
      );
    }
    return ResponseBody.fromString(
      jsonEncode(r.body ?? {}),
      r.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Ответ списка записей PocketBase.
Map<String, dynamic> pbPage(
  List<Map<String, dynamic>> items, {
  int page = 1,
  int perPage = 10,
  int? total,
}) {
  final count = total ?? items.length;
  return {
    'page': page,
    'perPage': perPage,
    'totalItems': count,
    'totalPages': count == 0 ? 1 : (count / perPage).ceil(),
    'items': items,
  };
}

Map<String, dynamic> carJson(int n, {String status = 'available'}) => {
  'id': 'car$n',
  'model': 'm1',
  'vin': 'XTA21093OY12345$n'.padRight(17, '0').substring(0, 17),
  'year': 2024,
  'color': 'Белый',
  'mileage': 0,
  'price': 2000000 + n * 100000,
  'engine': 'petrol',
  'transmission': 'automatic',
  'horsepower': 150,
  'status': status,
  'options': <String>[],
  'deletedAt': '',
  'expand': {
    'model': {
      'id': 'm1',
      'name': 'Camry',
      'bodyType': 'sedan',
      'expand': {
        'brand': {'id': 'b1', 'name': 'Toyota'},
      },
    },
  },
};
