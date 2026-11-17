import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/models/enums.dart';
import '../../../shared/models/period_scope.dart';
import '../../../shared/models/transaction_item.dart';
import '../../../shared/utils/formatters.dart';
import '../data/transaction_repository.dart';

class TransactionsState extends Equatable {
  const TransactionsState({
    required this.year,
    required this.month,
    required this.day,
    this.scope = PeriodScope.month,
    this.items = const [],
    this.loading = false,
    this.typeFilter,
    this.userFilter,
    this.projectFilter,
    this.searchQuery = '',
    this.error,
  });

  final int year;
  final int month;
  final int day;
  final PeriodScope scope;
  final List<TransactionItem> items;
  final bool loading;
  final TxnType? typeFilter;
  final String? userFilter;

  /// `null` = all · `''` = no project · otherwise project id.
  final String? projectFilter;
  final String searchQuery;
  final String? error;

  DateTime get selectedDate {
    final maxDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day.clamp(1, maxDay));
  }

  String get periodLabel => switch (scope) {
        PeriodScope.day => formatDate(selectedDate),
        PeriodScope.month => formatMonthYear(DateTime(year, month)),
        PeriodScope.year => formatYear(year),
      };

  /// Full period data for Home. List/Analytics filters never shrink `items`.
  List<TransactionItem> get filteredItems {
    final q = searchQuery.trim().toLowerCase();
    return items.where((e) {
      if (typeFilter != null && e.type != typeFilter) return false;
      if (userFilter != null && e.createdBy != userFilter) return false;
      if (projectFilter != null) {
        if (projectFilter!.isEmpty) {
          if (e.projectId != null) return false;
        } else if (e.projectId != projectFilter) {
          return false;
        }
      }
      if (q.isNotEmpty) {
        final haystack = [
          e.category.label,
          e.type.label,
          e.creatorName,
          e.note ?? '',
          e.amount.toStringAsFixed(2),
          e.amount.toStringAsFixed(0),
        ].join(' ').toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  double get incomeTotal => items
      .where((e) => e.type == TxnType.income)
      .fold(0.0, (sum, e) => sum + e.amount);

  double get expenseTotal => items
      .where((e) => e.type == TxnType.expense)
      .fold(0.0, (sum, e) => sum + e.amount);

  double get net => incomeTotal - expenseTotal;

  Map<TxnCategory, double> get byCategory {
    final map = <TxnCategory, double>{};
    for (final item in items) {
      map[item.category] = (map[item.category] ?? 0) + item.amount;
    }
    return map;
  }

  Map<String, double> expenseByUser() {
    final map = <String, double>{};
    for (final item in items.where((e) => e.type == TxnType.expense)) {
      final key = item.creatorName;
      map[key] = (map[key] ?? 0) + item.amount;
    }
    return map;
  }

  Map<String, double> incomeByUser() {
    final map = <String, double>{};
    for (final item in items.where((e) => e.type == TxnType.income)) {
      final key = item.creatorName;
      map[key] = (map[key] ?? 0) + item.amount;
    }
    return map;
  }

  TransactionsState copyWith({
    int? year,
    int? month,
    int? day,
    PeriodScope? scope,
    List<TransactionItem>? items,
    bool? loading,
    TxnType? typeFilter,
    String? userFilter,
    String? projectFilter,
    String? searchQuery,
    String? error,
    bool clearTypeFilter = false,
    bool clearUserFilter = false,
    bool clearProjectFilter = false,
  }) {
    return TransactionsState(
      year: year ?? this.year,
      month: month ?? this.month,
      day: day ?? this.day,
      scope: scope ?? this.scope,
      items: items ?? this.items,
      loading: loading ?? this.loading,
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      userFilter: clearUserFilter ? null : (userFilter ?? this.userFilter),
      projectFilter:
          clearProjectFilter ? null : (projectFilter ?? this.projectFilter),
      searchQuery: searchQuery ?? this.searchQuery,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        year,
        month,
        day,
        scope,
        items,
        loading,
        typeFilter,
        userFilter,
        projectFilter,
        searchQuery,
        error,
      ];
}

class TransactionsCubit extends Cubit<TransactionsState> {
  TransactionsCubit(this._repository)
      : super(TransactionsState(
          year: DateTime.now().year,
          month: DateTime.now().month,
          day: DateTime.now().day,
        ));

  final TransactionRepository _repository;

  /// Full-year cache so Day/Month/Year switches update totals instantly.
  List<TransactionItem> _yearItems = const [];
  int? _yearItemsYear;

  TransactionRepository get repository => _repository;

  bool _hasYearCache(int year) => _yearItemsYear == year;

  List<TransactionItem> _filterByPeriod(
    List<TransactionItem> source, {
    required PeriodScope scope,
    required int year,
    required int month,
    required int day,
  }) {
    return switch (scope) {
      PeriodScope.year =>
        source.where((e) => e.txnDate.year == year).toList(),
      PeriodScope.month => source
          .where((e) => e.txnDate.year == year && e.txnDate.month == month)
          .toList(),
      PeriodScope.day => source.where((e) {
          final d = e.txnDate;
          return d.year == year && d.month == month && d.day == day;
        }).toList(),
    };
  }

  void _emitScopedFromCache({
    PeriodScope? scope,
    int? year,
    int? month,
    int? day,
  }) {
    final nextScope = scope ?? state.scope;
    final nextYear = year ?? state.year;
    final nextMonth = month ?? state.month;
    final nextDay = day ?? state.day;
    emit(
      state.copyWith(
        scope: nextScope,
        year: nextYear,
        month: nextMonth,
        day: nextDay,
        items: _filterByPeriod(
          _yearItems,
          scope: nextScope,
          year: nextYear,
          month: nextMonth,
          day: nextDay,
        ),
        loading: false,
        error: null,
      ),
    );
  }

  Future<void> load() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      // Always fetch the year so scope/date switches can filter locally.
      final yearItems = await _repository.fetchYear(year: state.year);
      _yearItems = yearItems;
      _yearItemsYear = state.year;
      emit(
        state.copyWith(
          items: _filterByPeriod(
            yearItems,
            scope: state.scope,
            year: state.year,
            month: state.month,
            day: state.day,
          ),
          loading: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> setDate(int year, int month, int day) async {
    final maxDay = DateTime(year, month + 1, 0).day;
    final clampedDay = day.clamp(1, maxDay);
    if (_hasYearCache(year)) {
      _emitScopedFromCache(year: year, month: month, day: clampedDay);
      return;
    }
    emit(state.copyWith(year: year, month: month, day: clampedDay));
    await load();
  }

  Future<void> setScope(PeriodScope scope) async {
    if (_hasYearCache(state.year)) {
      _emitScopedFromCache(scope: scope);
      return;
    }
    emit(state.copyWith(scope: scope));
    await load();
  }

  void setTypeFilter(TxnType? type) {
    emit(state.copyWith(typeFilter: type, clearTypeFilter: type == null));
  }

  void setUserFilter(String? userId) {
    emit(state.copyWith(userFilter: userId, clearUserFilter: userId == null));
  }

  void setProjectFilter(String? projectId) {
    emit(
      state.copyWith(
        projectFilter: projectId,
        clearProjectFilter: projectId == null,
      ),
    );
  }

  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  Future<void> add({
    required TxnType type,
    required TxnCategory category,
    required double amount,
    required DateTime txnDate,
    required String createdBy,
    String? note,
    String? receiptUrl,
    String? projectId,
    bool isEmployeeExpense = false,
    bool employeeExpenseSettled = false,
    String? spentBy,
  }) async {
    await _repository.create(
      type: type,
      category: category,
      amount: amount,
      txnDate: txnDate,
      createdBy: createdBy,
      note: note,
      receiptUrl: receiptUrl,
      projectId: projectId,
      isEmployeeExpense: isEmployeeExpense,
      employeeExpenseSettled: employeeExpenseSettled,
      spentBy: spentBy,
    );
    await load();
  }

  Future<void> updateItem({
    required String id,
    required TxnType type,
    required TxnCategory category,
    required double amount,
    required DateTime txnDate,
    String? note,
    String? receiptUrl,
    bool clearReceipt = false,
    String? projectId,
    bool clearProject = false,
    bool isEmployeeExpense = false,
    bool employeeExpenseSettled = false,
    String? spentBy,
  }) async {
    await _repository.update(
      id: id,
      type: type,
      category: category,
      amount: amount,
      txnDate: txnDate,
      note: note,
      receiptUrl: receiptUrl,
      clearReceipt: clearReceipt,
      projectId: projectId,
      clearProject: clearProject,
      isEmployeeExpense: isEmployeeExpense,
      employeeExpenseSettled: employeeExpenseSettled,
      spentBy: spentBy,
    );
    await load();
  }

  Future<void> setEmployeeExpenseSettled({
    required String id,
    required bool settled,
  }) async {
    final previous = state.items;
    final previousYear = _yearItems;
    _yearItems = _yearItems
        .map(
          (e) => e.id == id ? e.copyWith(employeeExpenseSettled: settled) : e,
        )
        .toList();
    emit(
      state.copyWith(
        items: previous
            .map(
              (e) => e.id == id
                  ? e.copyWith(employeeExpenseSettled: settled)
                  : e,
            )
            .toList(),
      ),
    );
    try {
      await _repository.setEmployeeExpenseSettled(id: id, settled: settled);
    } catch (_) {
      _yearItems = previousYear;
      emit(state.copyWith(items: previous));
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    // Remove from UI immediately so Dismissible leaves the tree.
    final previous = state.items;
    final previousYear = _yearItems;
    _yearItems = _yearItems.where((e) => e.id != id).toList();
    emit(
      state.copyWith(
        items: previous.where((e) => e.id != id).toList(),
      ),
    );
    try {
      await _repository.delete(id);
    } catch (_) {
      _yearItems = previousYear;
      emit(state.copyWith(items: previous));
      rethrow;
    }
  }
}
