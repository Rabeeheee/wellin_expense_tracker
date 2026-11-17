import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/models/client_item.dart';
import '../data/client_repository.dart';

class ClientsState extends Equatable {
  const ClientsState({
    this.items = const [],
    this.loading = false,
    this.error,
  });

  final List<ClientItem> items;
  final bool loading;
  final String? error;

  ClientsState copyWith({
    List<ClientItem>? items,
    bool? loading,
    String? error,
  }) {
    return ClientsState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [items, loading, error];
}

class ClientsCubit extends Cubit<ClientsState> {
  ClientsCubit(this._repository) : super(const ClientsState());

  final ClientRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final items = await _repository.fetchAll();
      emit(state.copyWith(items: items, loading: false));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> create({
    required String name,
    required String createdBy,
    String? company,
    String? email,
    String? phone,
    String? notes,
  }) async {
    await _repository.create(
      name: name,
      createdBy: createdBy,
      company: company,
      email: email,
      phone: phone,
      notes: notes,
    );
    await load();
  }

  Future<void> update(ClientItem item) async {
    await _repository.update(item);
    await load();
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    await load();
  }
}
