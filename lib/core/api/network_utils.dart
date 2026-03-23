import 'package:dio/dio.dart';

bool isOfflineError(Object error) {
  if (error is! DioException) {
    return false;
  }

  return error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      (error.response == null && error.type == DioExceptionType.unknown);
}
