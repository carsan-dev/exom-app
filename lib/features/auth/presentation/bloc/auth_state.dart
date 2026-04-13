import 'package:equatable/equatable.dart';
import 'package:exom_app/features/auth/domain/entities/user_entity.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final UserEntity user;

  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

class AuthLinkPasswordRequired extends AuthState {
  final String email;
  final String provider;

  const AuthLinkPasswordRequired({required this.email, required this.provider});

  @override
  List<Object?> get props => [email, provider];
}

class AuthAccountLocked extends AuthState {
  const AuthAccountLocked();
}
