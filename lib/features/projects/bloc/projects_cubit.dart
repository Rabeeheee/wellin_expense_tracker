import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/models/enums.dart';
import '../../../shared/models/project_item.dart';
import '../../../shared/models/transaction_item.dart';
import '../data/project_repository.dart';

class ProjectsState extends Equatable {
  const ProjectsState({
    this.items = const [],
    this.statusFilter = ProjectStatus.active,
    this.loading = false,
    this.error,
  });

  final List<ProjectItem> items;
  final ProjectStatus statusFilter;
  final bool loading;
  final String? error;

  List<ProjectItem> get filteredItems =>
      items.where((e) => e.status == statusFilter).toList();

  ProjectsState copyWith({
    List<ProjectItem>? items,
    ProjectStatus? statusFilter,
    bool? loading,
    String? error,
  }) {
    return ProjectsState(
      items: items ?? this.items,
      statusFilter: statusFilter ?? this.statusFilter,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [items, statusFilter, loading, error];
}

class ProjectsCubit extends Cubit<ProjectsState> {
  ProjectsCubit(this._repository) : super(const ProjectsState());

  final ProjectRepository _repository;

  ProjectRepository get repository => _repository;

  Future<void> load() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final items = await _repository.fetchAll();
      emit(state.copyWith(items: items, loading: false));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  void setStatusFilter(ProjectStatus status) {
    emit(state.copyWith(statusFilter: status));
  }

  Future<ProjectItem?> fetchById(String id) => _repository.fetchById(id);

  Future<List<TransactionItem>> fetchTransactions(String projectId) =>
      _repository.fetchTransactions(projectId);

  Future<void> create({
    required String clientId,
    required String title,
    required ProjectStatus status,
    required double contractValue,
    required String createdBy,
    String? description,
    DateTime? startDate,
    DateTime? dueDate,
  }) async {
    await _repository.create(
      clientId: clientId,
      title: title,
      status: status,
      contractValue: contractValue,
      createdBy: createdBy,
      description: description,
      startDate: startDate,
      dueDate: dueDate,
    );
    await load();
  }

  Future<void> update(ProjectItem item) async {
    await _repository.update(item);
    await load();
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    await load();
  }
}
