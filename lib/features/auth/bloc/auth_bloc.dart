import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/secure_lock_service.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/profile.dart';
import '../data/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthBlocState> {
  AuthBloc({
    required AuthRepository authRepository,
    required SecureLockService lockService,
  })  : _authRepository = authRepository,
        _lockService = lockService,
        super(const AuthBlocState.unknown()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLogin);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthGoogleRequested>(_onGoogle);
    on<AuthCompleteProfileRequested>(_onCompleteProfile);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthUnlocked>(_onUnlocked);
    on<AuthBiometricLoginRequested>(_onBiometricLogin);
    on<AuthLockRequested>(_onLock);
    on<AuthRefreshProfile>(_onRefreshProfile);
    on<AuthSessionChanged>(_onSessionChanged);
  }

  final AuthRepository _authRepository;
  final SecureLockService _lockService;
  StreamSubscription<dynamic>? _sub;

  /// Once unlocked, stay unlocked until app backgrounds or logout.
  bool _unlockedForSession = false;

  Future<void> _onStarted(
    AuthStarted event,
    Emitter<AuthBlocState> emit,
  ) async {
    await _sub?.cancel();
    _sub = _authRepository.authStateChanges.listen((data) {
      add(AuthSessionChanged(data.session));
    });
    add(AuthSessionChanged(_authRepository.currentSession));
  }

  Future<void> _onSessionChanged(
    AuthSessionChanged event,
    Emitter<AuthBlocState> emit,
  ) async {
    final session = event.session;
    if (session == null) {
      _unlockedForSession = false;
      emit(const AuthBlocState.unauthenticated());
      return;
    }

    try {
      final profile = await _authRepository.fetchMyProfile();
      if (profile == null) {
        emit(AuthBlocState.needsProfile(session.user));
        return;
      }
      if (profile.status == UserStatus.pending ||
          profile.status == UserStatus.disabled) {
        emit(AuthBlocState.pending(profile));
        return;
      }

      final lockEnabled = await _lockService.isLockEnabled;

      // Just signed in with Google/email — go straight home (no second gate).
      final justSignedIn = state.status == AuthStatus.loading;

      // No PIN/biometric: never restore a saved session into the app.
      // Force email (or Google) login on cold start.
      if (!lockEnabled) {
        if (justSignedIn || _unlockedForSession) {
          _unlockedForSession = true;
          emit(AuthBlocState.authenticated(profile, unlocked: true));
          return;
        }
        await _authRepository.signOut();
        _unlockedForSession = false;
        emit(const AuthBlocState.unauthenticated());
        return;
      }

      if (_unlockedForSession || justSignedIn) {
        _unlockedForSession = true;
        emit(AuthBlocState.authenticated(profile, unlocked: true));
        return;
      }

      // Saved session on launch / after background → unlock screen
      // (auto biometric prompt, like Google Pay).
      emit(AuthBlocState.locked(profile));
    } catch (e) {
      emit(AuthBlocState.failure(e.toString()));
    }
  }

  Future<void> _onLogin(
    AuthLoginRequested event,
    Emitter<AuthBlocState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));
    try {
      await _authRepository.signInWithEmail(
        email: event.email,
        password: event.password,
      );
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRegister(
    AuthRegisterRequested event,
    Emitter<AuthBlocState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));
    try {
      await _authRepository.signUpWithEmail(
        name: event.name,
        email: event.email,
        password: event.password,
        role: event.role,
      );
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onGoogle(
    AuthGoogleRequested event,
    Emitter<AuthBlocState> emit,
  ) async {
    // ignore: avoid_print
    print('[AuthBloc] Google sign-in requested');
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));
    try {
      await _authRepository.signInWithGoogle();
      // ignore: avoid_print
      print('[AuthBloc] Google sign-in completed without throw');
    } catch (e, st) {
      // ignore: avoid_print
      print('[AuthBloc] Google sign-in error: $e');
      // ignore: avoid_print
      print('[AuthBloc] Stack: $st');
      final raw = e.toString();
      final message = raw.startsWith('Exception: ')
          ? raw.substring('Exception: '.length)
          : raw;
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMessage: message,
      ));
    }
  }

  Future<void> _onCompleteProfile(
    AuthCompleteProfileRequested event,
    Emitter<AuthBlocState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));
    try {
      await _authRepository.completeProfile(name: event.name, role: event.role);
      add(AuthSessionChanged(_authRepository.currentSession));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthBlocState> emit,
  ) async {
    _unlockedForSession = false;
    if (event.clearLock) {
      await _lockService.clearAllLockSettings();
    }
    await _authRepository.signOut();
    emit(const AuthBlocState.unauthenticated());
  }

  Future<void> _onUnlocked(
    AuthUnlocked event,
    Emitter<AuthBlocState> emit,
  ) async {
    if (state.profile != null) {
      _unlockedForSession = true;
      emit(AuthBlocState.authenticated(state.profile!, unlocked: true));
    }
  }

  Future<void> _onBiometricLogin(
    AuthBiometricLoginRequested event,
    Emitter<AuthBlocState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));
    try {
      if (!await _lockService.isBiometricEnabled) {
        emit(state.copyWith(
          status: AuthStatus.failure,
          errorMessage:
              'Enable biometric unlock in More → Security after signing in.',
        ));
        return;
      }

      final error = await _lockService.authenticateBiometric(
        reason: 'Sign in to Expense Tracker',
      );
      if (error != null) {
        emit(state.copyWith(
          status: AuthStatus.failure,
          errorMessage: error,
        ));
        return;
      }

      final session = _authRepository.currentSession;
      if (session == null) {
        emit(state.copyWith(
          status: AuthStatus.failure,
          errorMessage:
              'No saved session. Sign in with email or Google once, then use biometrics next time.',
        ));
        return;
      }

      final profile = await _authRepository.fetchMyProfile();
      if (profile == null) {
        emit(AuthBlocState.needsProfile(session.user));
        return;
      }
      if (profile.status == UserStatus.pending ||
          profile.status == UserStatus.disabled) {
        emit(AuthBlocState.pending(profile));
        return;
      }

      _unlockedForSession = true;
      emit(AuthBlocState.authenticated(profile, unlocked: true));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLock(
    AuthLockRequested event,
    Emitter<AuthBlocState> emit,
  ) async {
    // Only lock an active session. Skip if already locked (biometric sheet
    // pauses the app and would otherwise re-trigger forever).
    if (state.status != AuthStatus.authenticated) return;
    if (state.profile == null) return;
    if (!await _lockService.isLockEnabled) return;
    _unlockedForSession = false;
    emit(AuthBlocState.locked(state.profile!));
  }

  Future<void> _onRefreshProfile(
    AuthRefreshProfile event,
    Emitter<AuthBlocState> emit,
  ) async {
    try {
      final profile = await _authRepository.fetchMyProfile();
      if (profile == null) return;

      if (profile.status == UserStatus.pending ||
          profile.status == UserStatus.disabled) {
        emit(AuthBlocState.pending(profile));
        return;
      }

      // Keep an existing in-app session (including pending → claimed super admin).
      if (state.status == AuthStatus.pending ||
          state.status == AuthStatus.authenticated ||
          state.status == AuthStatus.locked) {
        _unlockedForSession = true;
        emit(AuthBlocState.authenticated(profile, unlocked: true));
      }
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
