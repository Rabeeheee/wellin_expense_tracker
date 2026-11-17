import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/notification_service.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/reminder_item.dart';
import '../data/reminder_repository.dart';

class RemindersState extends Equatable {
  const RemindersState({
    this.items = const [],
    this.loading = false,
    this.error,
  });

  final List<ReminderItem> items;
  final bool loading;
  final String? error;

  List<ReminderItem> get due => items
      .where((e) => !e.isDone && !e.dueDate.isAfter(DateTime.now()))
      .toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  List<ReminderItem> get pending => items
      .where((e) => !e.isDone && e.dueDate.isAfter(DateTime.now()))
      .toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  List<ReminderItem> get completed => items
      .where((e) => e.isDone)
      .toList()
    ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

  RemindersState copyWith({
    List<ReminderItem>? items,
    bool? loading,
    String? error,
  }) {
    return RemindersState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [items, loading, error];
}

class RemindersCubit extends Cubit<RemindersState> {
  RemindersCubit(this._repository, {NotificationService? notifications})
      : _notifications = notifications,
        super(const RemindersState());

  final ReminderRepository _repository;
  final NotificationService? _notifications;

  Future<void> load() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final items = await _repository.fetchAll(includeDone: true);
      emit(state.copyWith(items: items, loading: false));
      await _syncSchedules(items);
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> _syncSchedules(List<ReminderItem> items) async {
    final service = _notifications;
    if (service == null) return;

    for (final item in items) {
      if (item.isDone) {
        await service.cancelReminder(item.id);
      } else {
        await service.scheduleReminder(
          reminderId: item.id,
          title: item.title,
          dueLocal: item.dueDate,
        );
      }
    }
  }

  Future<void> add({
    required String title,
    required ReminderPreset preset,
    required DateTime dueDate,
    required String createdBy,
    double? amount,
    bool recurring = false,
  }) async {
    final created = await _repository.create(
      title: title,
      preset: preset,
      dueDate: dueDate,
      createdBy: createdBy,
      amount: amount,
      isRecurringMonthly: recurring,
    );
    await _notifications?.scheduleReminder(
      reminderId: created.id,
      title: created.title,
      dueLocal: created.dueDate,
    );
    await load();
  }

  Future<void> markDone(ReminderItem item) async {
    final previous = state.items;
    // Optimistically move to completed so swipe Dismissible leaves the tree.
    emit(
      state.copyWith(
        items: previous
            .map(
              (e) => e.id == item.id
                  ? ReminderItem(
                      id: e.id,
                      title: e.title,
                      preset: e.preset,
                      dueDate: e.dueDate,
                      isRecurringMonthly: e.isRecurringMonthly,
                      isDone: true,
                      createdBy: e.createdBy,
                      createdAt: e.createdAt,
                      amount: e.amount,
                      creator: e.creator,
                    )
                  : e,
            )
            .toList(),
      ),
    );
    try {
      await _notifications?.cancelReminder(item.id);
      await _repository.markDone(item);
    } catch (_) {
      emit(state.copyWith(items: previous));
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    final previous = state.items;
    emit(
      state.copyWith(
        items: previous.where((e) => e.id != id).toList(),
      ),
    );
    try {
      await _notifications?.cancelReminder(id);
      await _repository.delete(id);
    } catch (_) {
      emit(state.copyWith(items: previous));
      rethrow;
    }
  }
}
