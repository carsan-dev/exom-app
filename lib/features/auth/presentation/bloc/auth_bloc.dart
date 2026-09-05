import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/auth/firebase_auth_service.dart';
import 'package:exom_app/features/auth/domain/entities/user_entity.dart';
import 'package:exom_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/get_me_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/social_login_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/logout_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/delete_account_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase _loginUseCase;
  final SocialLoginUseCase _socialLoginUseCase;
  final LogoutUseCase _logoutUseCase;
  final GetMeUseCase _getMeUseCase;
  final DeleteAccountUseCase _deleteAccountUseCase;
  final FirebaseAuthService _firebaseAuthService;
  AuthCredential? _pendingLinkCredential;
  String? _pendingLinkEmail;
  String? _pendingLinkProvider;
  int _sessionValidationGeneration = 0;

  AuthBloc({
    required LoginUseCase loginUseCase,
    required SocialLoginUseCase socialLoginUseCase,
    required LogoutUseCase logoutUseCase,
    required GetMeUseCase getMeUseCase,
    required DeleteAccountUseCase deleteAccountUseCase,
    required FirebaseAuthService firebaseAuthService,
  }) : _loginUseCase = loginUseCase,
       _socialLoginUseCase = socialLoginUseCase,
       _logoutUseCase = logoutUseCase,
       _getMeUseCase = getMeUseCase,
       _deleteAccountUseCase = deleteAccountUseCase,
       _firebaseAuthService = firebaseAuthService,
       super(const AuthInitial()) {
    on<AuthCheckStatusRequested>(_onCheckStatus);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthGoogleLoginRequested>(_onGoogleLoginRequested);
    on<AuthAppleLoginRequested>(_onAppleLoginRequested);
    on<AuthLinkPasswordSubmitted>(_onLinkPasswordSubmitted);
    on<AuthLinkCancelled>(_onLinkCancelled);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthAccountDeletionRequested>(_onAccountDeletionRequested);
  }

  void _clearPendingLink() {
    _pendingLinkCredential = null;
    _pendingLinkEmail = null;
    _pendingLinkProvider = null;
  }

  String _providerLabel(String provider) {
    switch (provider) {
      case 'google':
        return 'Google';
      case 'apple':
        return 'Apple';
      default:
        return provider;
    }
  }

  String _firebaseAuthMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'credential-already-in-use':
        return 'Este acceso social ya está vinculado a otra cuenta. Inicia sesión con tu método original o revisa la configuración de Firebase antes de volver a intentarlo.';
      case 'no-current-user':
        return 'No hemos podido mantener tu sesión para completar la vinculación. Vuelve a intentarlo.';
      case 'invalid-credential':
        return 'La credencial social ha caducado. Repite el proceso de vinculación.';
      default:
        return error.message ?? error.code;
    }
  }

  Future<UserEntity> _completeSocialLogin(String provider) async {
    final token =
        await _firebaseAuthService.getIdToken(forceRefresh: true) ?? '';
    return _socialLoginUseCase(token, provider);
  }

  Future<OAuthCredential> _createSocialCredential(String provider) {
    switch (provider) {
      case 'google':
        return _firebaseAuthService.createGoogleCredential();
      case 'apple':
        return _firebaseAuthService.createAppleCredential();
      default:
        throw UnsupportedError('Unsupported social provider: $provider');
    }
  }

  Future<void> _preparePasswordLinkFlow({
    required AuthCredential credential,
    required String provider,
    required String? email,
    required Emitter<AuthState> emit,
  }) async {
    try {
      await _firebaseAuthService.signOut();
    } catch (_) {}

    final normalizedEmail = email?.trim().toLowerCase();
    if (normalizedEmail == null || normalizedEmail.isEmpty) {
      _clearPendingLink();
      emit(
        AuthError(
          'No hemos podido identificar el correo de esta cuenta ${_providerLabel(provider)}. Inicia sesión con tu método actual y vuelve a intentarlo.',
        ),
      );
      return;
    }

    _pendingLinkCredential = credential;
    _pendingLinkEmail = normalizedEmail;
    _pendingLinkProvider = provider;
    emit(
      AuthLinkPasswordRequired(
        email: normalizedEmail,
        provider: _providerLabel(provider),
      ),
    );
  }

  Future<void> _startSocialLogin(
    String provider,
    Emitter<AuthState> emit,
  ) async {
    _sessionValidationGeneration++;
    emit(const AuthLoading());

    final credential = await _createSocialCredential(provider);
    String? socialEmail;
    try {
      final socialSession = await _firebaseAuthService.signInWithCredential(
        credential,
      );
      socialEmail = socialSession.user?.email;
      final user = await _completeSocialLogin(provider);
      _clearPendingLink();
      emit(AuthAuthenticated(user));
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        await _preparePasswordLinkFlow(
          credential: credential,
          provider: provider,
          email: e.email,
          emit: emit,
        );
        return;
      }

      emit(AuthError(_firebaseAuthMessage(e)));
    } on ApiException catch (e) {
      if (e.isLocked) {
        emit(const AuthAccountLocked());
        return;
      }

      if (e.statusCode == 409) {
        await _preparePasswordLinkFlow(
          credential: credential,
          provider: provider,
          email: socialEmail,
          emit: emit,
        );
        return;
      }

      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onCheckStatus(
    AuthCheckStatusRequested event,
    Emitter<AuthState> emit,
  ) async {
    final validationGeneration = ++_sessionValidationGeneration;
    final firebaseSession = _firebaseAuthService.currentSession;
    if (firebaseSession == null) {
      emit(const AuthUnauthenticated());
      return;
    }

    bool isCurrentValidation() =>
        validationGeneration == _sessionValidationGeneration &&
        _firebaseAuthService.currentSession?.uid == firebaseSession.uid;

    try {
      final user = await _getMeUseCase();
      if (!isCurrentValidation()) return;
      emit(AuthAuthenticated(user));
    } on ApiException catch (e) {
      if (!isCurrentValidation()) return;
      if (e.isLocked) {
        emit(const AuthAccountLocked());
      } else if (e.isNetworkError) {
        final entity = UserEntity(
          id: firebaseSession.uid,
          email: firebaseSession.email ?? '',
          role: 'CLIENT',
        );
        emit(AuthAuthenticated(entity));
      } else if (e.statusCode == 401 || e.statusCode == 403) {
        try {
          await _firebaseAuthService.signOut();
        } catch (_) {}
        emit(const AuthUnauthenticated());
      } else {
        emit(AuthError(e.message));
      }
    } catch (e) {
      if (!isCurrentValidation()) return;
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    _sessionValidationGeneration++;
    _clearPendingLink();
    emit(const AuthLoading());
    try {
      final user = await _loginUseCase(event.email, event.password);
      emit(AuthAuthenticated(user));
    } on ApiException catch (e) {
      if (e.isLocked) {
        emit(const AuthAccountLocked());
      } else {
        emit(AuthError(e.message));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onGoogleLoginRequested(
    AuthGoogleLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _startSocialLogin('google', emit);
  }

  Future<void> _onAppleLoginRequested(
    AuthAppleLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _startSocialLogin('apple', emit);
  }

  Future<void> _onLinkPasswordSubmitted(
    AuthLinkPasswordSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    _sessionValidationGeneration++;
    final pendingCredential = _pendingLinkCredential;
    final pendingEmail = _pendingLinkEmail;
    final pendingProvider = _pendingLinkProvider;
    if (pendingCredential == null ||
        pendingEmail == null ||
        pendingProvider == null) {
      emit(
        const AuthError(
          'La solicitud de vinculación ha caducado. Vuelve a intentarlo.',
        ),
      );
      return;
    }

    emit(const AuthLoading());
    try {
      final user = await _loginUseCase(pendingEmail, event.password);

      try {
        await _firebaseAuthService.linkCurrentUserWithCredential(
          pendingCredential,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code != 'provider-already-linked') {
          rethrow;
        }
      }

      _clearPendingLink();
      emit(AuthAuthenticated(user));
    } on ApiException catch (e) {
      if (e.isLocked) {
        emit(const AuthAccountLocked());
      } else {
        emit(AuthError(e.message));
      }
    } on FirebaseAuthException catch (e) {
      try {
        await _logoutUseCase();
      } catch (_) {}
      emit(AuthError(_firebaseAuthMessage(e)));
    } catch (e) {
      try {
        await _logoutUseCase();
      } catch (_) {}
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onLinkCancelled(
    AuthLinkCancelled event,
    Emitter<AuthState> emit,
  ) async {
    _sessionValidationGeneration++;
    _clearPendingLink();
    emit(const AuthInitial());
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    _sessionValidationGeneration++;
    _clearPendingLink();
    emit(const AuthLoading());
    try {
      await _logoutUseCase();
    } catch (_) {
      // Best effort logout
    }
    emit(const AuthUnauthenticated());
  }

  Future<void> _onAccountDeletionRequested(
    AuthAccountDeletionRequested event,
    Emitter<AuthState> emit,
  ) async {
    _sessionValidationGeneration++;
    _clearPendingLink();
    emit(const AuthLoading());
    try {
      await _deleteAccountUseCase();
      emit(const AuthAccountDeleted());
      emit(const AuthUnauthenticated());
    } on ApiException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}
