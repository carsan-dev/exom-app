import 'dart:io';

import 'package:dio/dio.dart';

bool isOfflineError(Object error) {
  if (error is! DioException) {
    return false;
  }

  if (error.response != null) {
    return false;
  }

  return error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      (error.type == DioExceptionType.unknown &&
          (error.error is SocketException || error.error is HttpException));
}
