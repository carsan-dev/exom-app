import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckStatusRequested extends AuthEvent {
  const AuthCheckStatusRequested();
}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class AuthGoogleLoginRequested extends AuthEvent {
  const AuthGoogleLoginRequested();
}

class AuthAppleLoginRequested extends AuthEvent {
  const AuthAppleLoginRequested();
}

class AuthLinkPasswordSubmitted extends AuthEvent {
  final String password;

  const AuthLinkPasswordSubmitted({required this.password});

  @override
  List<Object?> get props => [password];
}

class AuthLinkCancelled extends AuthEvent {
  const AuthLinkCancelled();
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}
