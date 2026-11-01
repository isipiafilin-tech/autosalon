import 'package:dio/dio.dart';

/// Ошибка обращения к серверу. Каждый вид ошибки — отдельный класс:
/// экраны по типу решают, что показать (поле формы, сообщение, повтор).
class ApiException implements Exception {
  final String message;
  final int? status;

  const ApiException(this.message, {this.status});

  @override
  String toString() => message;

  /// Разбор ответа PocketBase:
  /// `{"status":400,"message":"...","data":{"поле":{"code":"...","message":"..."}}}`.
  static ApiException fromDio(DioException e) {
    final inner = e.error;
    if (inner is ApiException) return inner;
    switch (e.type) {
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutApiException();
      default:
        break;
    }
    final response = e.response;
    if (response == null) return const NetworkException();
    return fromResponse(response.statusCode ?? 0, response.data);
  }

  static ApiException fromResponse(int status, Object? body) {
    final map = body is Map ? body : const {};
    final serverMessage = map['message'] is String
        ? map['message'] as String
        : '';
    final fields = fieldErrorsOf(map['data']);
    switch (status) {
      case 400:
        if (fields.isNotEmpty) {
          return ValidationException(
            'Проверьте выделенные поля.',
            fields,
            status: status,
          );
        }
        return ApiException(
          serverMessage.isEmpty
              ? 'Сервер отклонил запрос.'
              : 'Сервер отклонил запрос: $serverMessage',
          status: status,
        );
      case 401:
        return UnauthorizedException(
          serverMessage.isEmpty ? 'Нужно войти в систему.' : serverMessage,
        );
      case 403:
        return const ForbiddenException();
      case 404:
        return const NotFoundException();
      case 409:
        return ConflictException(
          serverMessage.isEmpty ? 'Конфликт данных.' : serverMessage,
          fields,
        );
      case 422:
        return ValidationException(
          serverMessage.isEmpty ? 'Проверьте выделенные поля.' : serverMessage,
          fields,
          status: status,
        );
      case 429:
        return const ApiException(
          'Слишком много запросов. Подождите немного.',
          status: 429,
        );
    }
    if (status >= 500) return ServerException(status);
    return ApiException('Ошибка сервера ($status).', status: status);
  }

  /// Ошибки полей из `data`; тексты кодов PocketBase переведены на русский.
  static Map<String, String> fieldErrorsOf(Object? data) {
    final out = <String, String>{};
    if (data is! Map) return out;
    data.forEach((key, value) {
      if (value is Map) {
        final code = value['code']?.toString() ?? '';
        final text = value['message']?.toString() ?? '';
        out['$key'] = _translate(code, text);
      }
    });
    return out;
  }

  static String _translate(String code, String text) {
    switch (code) {
      case 'validation_required':
        return 'Заполните поле';
      case 'validation_not_unique':
        return 'Такое значение уже есть';
      case 'validation_invalid_email':
        return 'Введите адрес электронной почты';
      case 'validation_min_text_constraint':
      case 'validation_min_text_length':
        return 'Слишком короткое значение';
      case 'validation_max_text_constraint':
      case 'validation_max_text_length':
        return 'Слишком длинное значение';
      case 'validation_min_number_constraint':
      case 'validation_min_number':
        return 'Значение меньше допустимого';
      case 'validation_max_number_constraint':
      case 'validation_max_number':
        return 'Значение больше допустимого';
      case 'validation_invalid_format':
      case 'validation_match_invalid':
        return 'Неверный формат';
      case 'validation_values_mismatch':
        return 'Значения не совпадают';
      case 'validation_missing_rel_records':
        return 'Выбранная запись не найдена';
    }
    return text.isEmpty ? 'Недопустимое значение' : text;
  }
}

/// Сервер недоступен: нет сети, адрес не отвечает.
class NetworkException extends ApiException {
  const NetworkException()
    : super('Нет соединения с сервером. Проверьте, что сервер запущен.');
}

/// Сервер не ответил за отведённое время.
class TimeoutApiException extends ApiException {
  const TimeoutApiException()
    : super('Сервер не ответил вовремя. Повторите попытку.');
}

/// Ошибка проверки данных (коды 400 с описанием полей и 422).
class ValidationException extends ApiException {
  final Map<String, String> fields;

  const ValidationException(super.message, this.fields, {super.status});
}

/// Конфликт состояний (код 409): занято время, автомобиль зарезервирован.
class ConflictException extends ApiException {
  final Map<String, String> fields;

  const ConflictException(super.message, this.fields) : super(status: 409);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException(super.message) : super(status: 401);
}

class ForbiddenException extends ApiException {
  const ForbiddenException()
    : super('Операция недоступна для вашей роли.', status: 403);
}

class NotFoundException extends ApiException {
  const NotFoundException()
    : super('Запись не найдена или недоступна.', status: 404);
}

class ServerException extends ApiException {
  const ServerException(int status)
    : super('Ошибка на сервере ($status). Повторите позже.', status: status);
}
