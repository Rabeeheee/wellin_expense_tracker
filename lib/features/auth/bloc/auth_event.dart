part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

final class AuthSessionChanged extends AuthEvent {
  const AuthSessionChanged(this.session);
  final Session? session;

  @override
  List<Object?> get props => [session?.accessToken];
}

final class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({required this.email, required this.password});
  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

final class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
  });

  final String name;
  final String email;
  final String password;
  final UserRole role;

  @override
  List<Object?> get props => [name, email, password, role];
}

final class AuthGoogleRequested extends AuthEvent {
  const AuthGoogleRequested();
}

final class AuthCompleteProfileRequested extends AuthEvent {
  const AuthCompleteProfileRequested({required this.name, required this.role});
  final String name;
  final UserRole role;

  @override
  List<Object?> get props => [name, role];
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested({this.clearLock = false});
  final bool clearLock;

  @override
  List<Object?> get props => [clearLock];
}

final class AuthUnlocked extends AuthEvent {
  const AuthUnlocked();
}

final class AuthBiometricLoginRequested extends AuthEvent {
  const AuthBiometricLoginRequested();
}

final class AuthLockRequested extends AuthEvent {
  const AuthLockRequested();
}

final class AuthRefreshProfile extends AuthEvent {
  const AuthRefreshProfile();
}
