class LocalAuthSession {
  final String uid;
  final String? email;

  const LocalAuthSession({required this.uid, this.email});
}

class AuthTokenNetworkException implements Exception {
  const AuthTokenNetworkException();

  @override
  String toString() => 'Firebase token refresh failed due to connectivity';
}

abstract interface class AuthTokenProvider {
  LocalAuthSession? get currentSession;

  Future<String?> getIdToken({bool forceRefresh = false});
}
