import 'package:dio/dio.dart';

import 'api_exceptions.dart';
import 'config.dart';

const _retryKey = 'retry';
const _authRetryKey = 'authRetried';

/// Клиент HTTP с общей обработкой: токен в заголовке, таймауты, повтор
/// чтения при сбое сети, обновление токена при ответе 401, перевод
/// ответов сервера в [ApiException].
Dio buildDio({
  String baseUrl = apiBaseUrl,
  String? Function()? token,
  Future<bool> Function()? refreshToken,
  void Function()? onAuthFailed,
  void Function()? onOnline,
  void Function()? onOffline,
  List<Duration> retryDelays = const [
    Duration(milliseconds: 300),
    Duration(milliseconds: 900),
  ],
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final t = token?.call();
        if (t != null && t.isNotEmpty) options.headers['Authorization'] = t;
        handler.next(options);
      },
      onResponse: (response, handler) {
        onOnline?.call();
        handler.next(response);
      },
      onError: (e, handler) async {
        final error = ApiException.fromDio(e);
        final options = e.requestOptions;
        final isRead = options.method.toUpperCase() == 'GET';

        // Сбой сети или таймаут: чтение повторяем с нарастающей паузой.
        if ((error is NetworkException || error is TimeoutApiException) &&
            isRead) {
          final attempt = (options.extra[_retryKey] as int?) ?? 0;
          if (attempt < retryDelays.length) {
            await Future<void>.delayed(retryDelays[attempt]);
            options.extra[_retryKey] = attempt + 1;
            try {
              return handler.resolve(await dio.fetch<dynamic>(options));
            } on DioException catch (again) {
              return handler.reject(again);
            }
          }
        }
        if (error is NetworkException) onOffline?.call();
        final isAuthCall = options.path.contains('/auth-');
        if (error is UnauthorizedException && !isAuthCall) {
          if (options.extra[_authRetryKey] != true && refreshToken != null) {
            options.extra[_authRetryKey] = true;
            if (await refreshToken()) {
              final t = token?.call();
              if (t != null) options.headers['Authorization'] = t;
              try {
                return handler.resolve(await dio.fetch<dynamic>(options));
              } on DioException catch (again) {
                return handler.reject(again);
              }
            }
          }
          onAuthFailed?.call();
        }
        handler.reject(
          DioException(
            requestOptions: options,
            response: e.response,
            type: e.type,
            error: error,
          ),
        );
      },
    ),
  );
  return dio;
}

/// Тонкая обёртка над [Dio]: возвращает разобранный JSON и бросает
/// только [ApiException].
class PbApi {
  final Dio dio;

  PbApi(this.dio);

  static String records(String collection, [String? id]) =>
      '/api/collections/$collection/records${id == null ? '' : '/$id'}';

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) => _call(() => dio.get<dynamic>(path, queryParameters: query));

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      _call(() => dio.post<dynamic>(path, data: body));

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      _call(() => dio.patch<dynamic>(path, data: body));

  Future<void> delete(String path) async {
    await _call(() => dio.delete<dynamic>(path));
  }

  Future<Map<String, dynamic>> _call(
    Future<Response<dynamic>> Function() send,
  ) async {
    try {
      final response = await send();
      final data = response.data;
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
