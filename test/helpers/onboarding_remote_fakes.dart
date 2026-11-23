import 'dart:async';

import 'package:dio/dio.dart';
import 'package:exom_app/features/onboarding/data/onboarding_remote_datasource.dart';

class RecordedOnboardingCall {
  RecordedOnboardingCall(this.expectedOwner, this.outcome);

  final String expectedOwner;
  final String? outcome;
}

/// Scripted `POST /profile/me/onboarding`. Each call consumes the next
/// response; with no script left it answers 200.
class FakeOnboardingRemote implements OnboardingRemoteDataSource {
  final calls = <RecordedOnboardingCall>[];
  final responses = <FutureOr<void> Function()>[];
  void Function(RecordedOnboardingCall call)? onCall;

  @override
  Future<void> markOnboarding({
    required String expectedOwner,
    String? outcome,
  }) async {
    final call = RecordedOnboardingCall(expectedOwner, outcome);
    calls.add(call);
    onCall?.call(call);
    if (responses.isEmpty) return;
    await responses.removeAt(0)();
  }
}

DioException httpError(int statusCode) {
  final options = RequestOptions(path: '/profile/me/onboarding');
  return DioException(
    requestOptions: options,
    response: Response<void>(requestOptions: options, statusCode: statusCode),
    type: DioExceptionType.badResponse,
  );
}

DioException networkError() => DioException.connectionError(
  requestOptions: RequestOptions(path: '/profile/me/onboarding'),
  reason: 'offline',
);
