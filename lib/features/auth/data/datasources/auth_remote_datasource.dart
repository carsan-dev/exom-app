import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import '../models/auth_response_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResponseModel> login(String email, String password);
  Future<AuthResponseModel> socialLogin(String token, String provider);
  Future<void> logout();
  Future<void> forgotPassword(String email);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _apiClient;

  AuthRemoteDataSourceImpl(this._apiClient);

  @override
  Future<AuthResponseModel> login(String email, String password) async {
    try {
      return await _apiClient.post<AuthResponseModel>(
        '/auth/login',
        data: {'email': email, 'password': password},
        fromJson: AuthResponseModel.fromJson,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<AuthResponseModel> socialLogin(String token, String provider) async {
    try {
      return await _apiClient.post<AuthResponseModel>(
        '/auth/social',
        data: {'token': token, 'provider': provider},
        fromJson: AuthResponseModel.fromJson,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _apiClient.post<void>('/auth/logout');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<void> forgotPassword(String email) async {
    try {
      await _apiClient.post<void>(
        '/auth/forgot-password',
        data: {'email': email},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
