import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/auth/firebase_auth_service.dart';
import 'package:exom_app/core/services/feature_gate_service.dart';
import 'package:exom_app/features/auth/domain/entities/user_entity.dart';
import 'package:exom_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/get_me_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/social_login_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/logout_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/register_trial_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase _loginUseCase;
  final SocialLoginUseCase _socialLoginUseCase;
  final LogoutUseCase _logoutUseCase;
  final RegisterTrialUseCase _registerTrialUseCase;
  final GetMeUseCase _getMeUseCase;
  final FirebaseAuthService _firebaseAuthService;

  AuthBloc({
    required LoginUseCase loginUseCase,
    required SocialLoginUseCase socialLoginUseCase,
    required LogoutUseCase logoutUseCase,
    required RegisterTrialUseCase registerTrialUseCase,
    required GetMeUseCase getMeUseCase,
    required FirebaseAuthService firebaseAuthService,
  }) : _loginUseCase = loginUseCase,
       _socialLoginUseCase = socialLoginUseCase,
       _logoutUseCase = logoutUseCase,
       _registerTrialUseCase = registerTrialUseCase,
       _getMeUseCase = getMeUseCase,
       _firebaseAuthService = firebaseAuthService,
       super(const AuthInitial()) {
    on<AuthCheckStatusRequested>(_onCheckStatus);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthGoogleLoginRequested>(_onGoogleLoginRequested);
    on<AuthAppleLoginRequested>(_onAppleLoginRequested);
    on<AuthTrialRegisterRequested>(_onTrialRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onCheckStatus(
    AuthCheckStatusRequested event,
    Emitter<AuthState> emit,
  ) async {
    final firebaseUser = _firebaseAuthService.currentUser;
    if (firebaseUser == null) {
      _resetFeatureGate();
      emit(const AuthUnauthenticated());
      return;
    }

    // Fetch real user data (tier, trial_expires_at) from the backend
    try {
      final user = await _getMeUseCase();
      _syncFeatureGate(user);
      emit(AuthAuthenticated(user));
    } on ApiException catch (e) {
      if (e.isTrialExpired) {
        _markTrialExpired();
        emit(AuthTrialExpired(e.message));
      } else if (e.isLocked) {
        emit(const AuthAccountLocked());
      } else {
        // Backend unreachable or other error — fall back to Firebase data
        final entity = UserEntity(
          id: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          role: 'CLIENT',
          tier: 'LOW_TICKET',
        );
        _syncFeatureGate(entity);
        emit(AuthAuthenticated(entity));
      }
    } catch (_) {
      // Network error — fall back to Firebase-only data
      final entity = UserEntity(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        role: 'CLIENT',
        tier: 'LOW_TICKET',
      );
      _syncFeatureGate(entity);
      emit(AuthAuthenticated(entity));
    }
  }

  void _syncFeatureGate(UserEntity user) {
    GetIt.instance<FeatureGateService>().updateUser(user);
  }

  void _markTrialExpired() {
    GetIt.instance<FeatureGateService>().markTrialExpired();
  }

  void _resetFeatureGate() {
    GetIt.instance<FeatureGateService>().reset();
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _loginUseCase(event.email, event.password);
      _syncFeatureGate(user);
      emit(AuthAuthenticated(user));
    } on ApiException catch (e) {
      if (e.isTrialExpired) {
        _markTrialExpired();
        emit(AuthTrialExpired(e.message));
      } else if (e.isLocked) {
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
    emit(const AuthLoading());
    try {
      final credential = await _firebaseAuthService.signInWithGoogle();
      final token = await credential.user?.getIdToken() ?? '';
      final user = await _socialLoginUseCase(token, 'google');
      _syncFeatureGate(user);
      emit(AuthAuthenticated(user));
    } on ApiException catch (e) {
      if (e.isTrialExpired) {
        _markTrialExpired();
        emit(AuthTrialExpired(e.message));
      } else if (e.isLocked) {
        emit(const AuthAccountLocked());
      } else {
        emit(AuthError(e.message));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onAppleLoginRequested(
    AuthAppleLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final credential = await _firebaseAuthService.signInWithApple();
      final token = await credential.user?.getIdToken() ?? '';
      final user = await _socialLoginUseCase(token, 'apple');
      _syncFeatureGate(user);
      emit(AuthAuthenticated(user));
    } on ApiException catch (e) {
      if (e.isTrialExpired) {
        _markTrialExpired();
        emit(AuthTrialExpired(e.message));
      } else if (e.isLocked) {
        emit(const AuthAccountLocked());
      } else {
        emit(AuthError(e.message));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onTrialRegisterRequested(
    AuthTrialRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _registerTrialUseCase(
        email: event.email,
        password: event.password,
        firstName: event.firstName,
        lastName: event.lastName,
      );
      _syncFeatureGate(user);
      emit(AuthAuthenticated(user));
    } on ApiException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _logoutUseCase();
    } catch (_) {
      // Best effort logout
    }
    _resetFeatureGate();
    emit(const AuthUnauthenticated());
  }
}
