import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';

abstract class OnboardingRemoteDataSource {
  /// `POST /profile/me/onboarding`. Completes only on 2xx; any HTTP error or
  /// transport failure is thrown to the caller.
  ///
  /// [expectedOwner] is the Firebase uid that owns the pending entry: the
  /// auth interceptor rejects the request if the current session belongs to
  /// someone else. A `null` [outcome] omits the field (self-repair, OP-D13).
  Future<void> markOnboarding({required String expectedOwner, String? outcome});
}

class OnboardingRemoteDataSourceImpl implements OnboardingRemoteDataSource {
  OnboardingRemoteDataSourceImpl(this._apiClient);

  static const path = '/profile/me/onboarding';

  final ApiClient _apiClient;

  @override
  Future<void> markOnboarding({
    required String expectedOwner,
    String? outcome,
  }) async {
    await _apiClient.dio.post<dynamic>(
      path,
      data: <String, Object?>{'outcome': ?outcome},
      options: Options(extra: {'exom.auth.expectedOwner': expectedOwner}),
    );
  }
}
