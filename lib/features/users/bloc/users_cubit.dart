import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/models/enums.dart';
import '../../../shared/models/profile.dart';
import '../data/users_repository.dart';

class UsersState extends Equatable {
  const UsersState({
    this.users = const [],
    this.loading = false,
    this.error,
  });

  final List<Profile> users;
  final bool loading;
  final String? error;

  UsersState copyWith({
    List<Profile>? users,
    bool? loading,
    String? error,
  }) {
    return UsersState(
      users: users ?? this.users,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [users, loading, error];
}

class UsersCubit extends Cubit<UsersState> {
  UsersCubit(this._repository) : super(const UsersState());

  final UsersRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final users = await _repository.fetchAll();
      emit(state.copyWith(users: users, loading: false));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> approve(String id) async {
    await _repository.approve(id);
    await load();
  }

  Future<void> disable(String id) async {
    await _repository.setStatus(id, UserStatus.disabled);
    await load();
  }

  Future<void> setRole(String id, UserRole role) async {
    await _repository.setRole(id, role);
    await load();
  }
}
