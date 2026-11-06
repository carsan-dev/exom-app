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

/// Stable message values carried by [AuthError] for known Firebase codes.
/// The login UI maps them to localized text; they are not shown directly.
class AuthErrorMessages {
  const AuthErrorMessages._();

  static const userDisabled =
      'Tu cuenta ha sido dada de baja por un administrador. Contacta con tu entrenador.';
  static const credentialAlreadyInUse =
      'Este acceso social ya está vinculado a otra cuenta. Inicia sesión con tu método original o revisa la configuración de Firebase antes de volver a intentarlo.';
  static const noCurrentUser =
      'No hemos podido mantener tu sesión para completar la vinculación. Vuelve a intentarlo.';
  static const invalidCredential =
      'La credencial social ha caducado. Repite el proceso de vinculación.';
  static const unknown = 'auth_operation_failed';
  static const linkRequestExpired =
      'La solicitud de vinculación ha caducado. Vuelve a intentarlo.';
  static const _missingEmailPrefix =
      'No hemos podido identificar el correo de esta cuenta ';
  static const _missingEmailSuffix =
      '. Inicia sesión con tu método actual y vuelve a intentarlo.';

  /// Message for a social account without email; embeds the provider label.
  static String missingEmail(String providerLabel) =>
      '$_missingEmailPrefix$providerLabel$_missingEmailSuffix';

  /// Returns the provider label when [message] is a [missingEmail] message.
  static String? missingEmailProvider(String message) {
    if (message.startsWith(_missingEmailPrefix) &&
        message.endsWith(_missingEmailSuffix) &&
        message.length >
            _missingEmailPrefix.length + _missingEmailSuffix.length) {
      return message.substring(
        _missingEmailPrefix.length,
        message.length - _missingEmailSuffix.length,
      );
    }
    return null;
  }
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

class AuthAccountDeleted extends AuthState {
  const AuthAccountDeleted();
}
