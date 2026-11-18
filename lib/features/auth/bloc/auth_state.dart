part of 'auth_bloc.dart';

enum AuthStatus {
  unknown,
  loading,
  unauthenticated,
  needsProfile,
  pending,
  locked,
  authenticated,
  passwordRecovery,
  failure,
}

class AuthBlocState extends Equatable {
  const AuthBlocState({
    required this.status,
    this.profile,
    this.user,
    this.unlocked = false,
    this.errorMessage,
    this.infoMessage,
  });

  const AuthBlocState.unknown() : this(status: AuthStatus.unknown);

  const AuthBlocState.unauthenticated()
      : this(status: AuthStatus.unauthenticated);

  const AuthBlocState.needsProfile(User user)
      : this(status: AuthStatus.needsProfile, user: user);

  const AuthBlocState.pending(Profile profile)
      : this(status: AuthStatus.pending, profile: profile);

  const AuthBlocState.locked(Profile profile)
      : this(status: AuthStatus.locked, profile: profile, unlocked: false);

  const AuthBlocState.authenticated(Profile profile, {bool unlocked = true})
      : this(
          status: AuthStatus.authenticated,
          profile: profile,
          unlocked: unlocked,
        );

  const AuthBlocState.passwordRecovery(User user)
      : this(status: AuthStatus.passwordRecovery, user: user);

  const AuthBlocState.failure(String message)
      : this(status: AuthStatus.failure, errorMessage: message);

  final AuthStatus status;
  final Profile? profile;
  final User? user;
  final bool unlocked;
  final String? errorMessage;
  final String? infoMessage;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && unlocked && profile != null;

  AuthBlocState copyWith({
    AuthStatus? status,
    Profile? profile,
    User? user,
    bool? unlocked,
    String? errorMessage,
    String? infoMessage,
  }) {
    return AuthBlocState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      user: user ?? this.user,
      unlocked: unlocked ?? this.unlocked,
      errorMessage: errorMessage,
      infoMessage: infoMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, profile, user, unlocked, errorMessage, infoMessage];
}
