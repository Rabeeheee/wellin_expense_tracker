import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/transaction_item.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/amount_text.dart';
import '../../../shared/widgets/design/app_confirm_dialog.dart';
import '../../../shared/widgets/design/filter_chips_row.dart';
import '../../../shared/widgets/design/metric_tile.dart';
import '../../../shared/widgets/design/premium_card.dart';
import '../../../shared/widgets/design/txn_icon.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/month_year_filter.dart';
import '../../../shared/widgets/wellin_logo.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../transactions/bloc/transactions_cubit.dart';

enum _SettleFilter { all, pending, completed }

enum _ViewMode { category, spender }

enum _SettleCharge { company, personal }

class EmployeeExpensesPage extends StatefulWidget {
  const EmployeeExpensesPage({super.key});

  @override
  State<EmployeeExpensesPage> createState() => _EmployeeExpensesPageState();
}

class _EmployeeExpensesPageState extends State<EmployeeExpensesPage> {
  _SettleFilter _settleFilter = _SettleFilter.all;
  _ViewMode _viewMode = _ViewMode.category;
  String? _selectedSpenderId;
  String? _selectedSpenderName;

  bool get _drilling =>
      _viewMode == _ViewMode.spender && _selectedSpenderId != null;

  String _spenderKey(TransactionItem e) => e.spentBy ?? e.createdBy;

  List<TransactionItem> _employeeItems(List<TransactionItem> all) {
    var items = all.where((e) => e.isEmployeeExpense).toList();
    switch (_settleFilter) {
      case _SettleFilter.all:
        break;
      case _SettleFilter.pending:
        items = items.where((e) => !e.employeeExpenseSettled).toList();
      case _SettleFilter.completed:
        items = items.where((e) => e.employeeExpenseSettled).toList();
    }
    return items;
  }

  double _expenseTotal(List<TransactionItem> items) => items
      .where((e) => e.type == TxnType.expense)
      .fold(0.0, (s, e) => s + e.amount);

  double _incomeTotal(List<TransactionItem> items) => items
      .where((e) => e.type == TxnType.income)
      .fold(0.0, (s, e) => s + e.amount);

  List<_SpenderSummary> _spenderSummaries(List<TransactionItem> items) {
    final map = <String, _SpenderSummary>{};
    for (final item in items) {
      final id = _spenderKey(item);
      final existing = map[id];
      if (existing == null) {
        map[id] = _SpenderSummary(
          userId: id,
          name: item.spenderName,
          expenseTotal: item.type == TxnType.expense ? item.amount : 0,
          incomeTotal: item.type == TxnType.income ? item.amount : 0,
          expenseCount: item.type == TxnType.expense ? 1 : 0,
          incomeCount: item.type == TxnType.income ? 1 : 0,
        );
      } else {
        map[id] = existing.add(item);
      }
    }
    final list = map.values.toList()
      ..sort((a, b) {
        final byExpense = b.expenseTotal.compareTo(a.expenseTotal);
        if (byExpense != 0) return byExpense;
        final byIncome = b.incomeTotal.compareTo(a.incomeTotal);
        if (byIncome != 0) return byIncome;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return list;
  }

  void _openSpender(String userId, String name) {
    setState(() {
      _selectedSpenderId = userId;
      _selectedSpenderName = name;
    });
  }

  void _closeSpender() {
    setState(() {
      _selectedSpenderId = null;
      _selectedSpenderName = null;
    });
  }

  void _setViewMode(int i) {
    setState(() {
      _viewMode = _ViewMode.values[i];
      _selectedSpenderId = null;
      _selectedSpenderName = null;
    });
  }

  Future<_SettleCharge?> _pickSettleCharge(TransactionItem item) {
    final isExpense = item.type == TxnType.expense;
    return showModalBottomSheet<_SettleCharge>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'How was this settled?',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isExpense
                      ? 'Company deducts from company income. Personal '
                          'keeps company totals unchanged.'
                      : 'Company adds to company income. Personal keeps '
                          'company totals unchanged.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.account_balance_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    isExpense
                        ? 'Deduct from company'
                        : 'Credit to company',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    isExpense
                        ? 'Counts in company expenses / net'
                        : 'Counts in company income / net',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  onTap: () => Navigator.pop(ctx, _SettleCharge.company),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.accent,
                  ),
                  title: Text(
                    'Deduct from personal',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Settled without changing company books',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  onTap: () => Navigator.pop(ctx, _SettleCharge.personal),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleSettled(TransactionItem item) async {
    final markComplete = !item.employeeExpenseSettled;
    var chargeCompany = false;

    if (markComplete) {
      final charge = await _pickSettleCharge(item);
      if (charge == null || !mounted) return;
      chargeCompany = charge == _SettleCharge.company;
    } else {
      final ok = await showAppConfirmDialog(
        context,
        title: 'Undo Completion?',
        message:
            'Move this back to pending. It will leave company totals again '
            'if it was deducted from company.',
        confirmLabel: 'Undo',
        tone: AppConfirmTone.danger,
      );
      if (!ok || !mounted) return;
    }

    try {
      await context.read<TransactionsCubit>().setEmployeeExpenseSettled(
            id: item.id,
            settled: markComplete,
            chargeCompany: chargeCompany,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    context.read<TransactionsCubit>().load();
  }

  Future<void> _delete(TransactionItem item) async {
    try {
      await context.read<TransactionsCubit>().delete(item.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e')),
      );
    }
  }

  List<Widget> _entryTiles({
    required List<TransactionItem> items,
    required String? myId,
    required bool isSuperAdmin,
  }) {
    if (items.isEmpty) {
      return [
        const EmptyState(
          message:
              'No employee entries yet. Flag one when saving an expense or income.',
        ),
      ];
    }

    return [
      for (final item in items) ...[
        Builder(
          builder: (context) {
            final canManage = item.createdBy == myId || isSuperAdmin;
            final tile = _EmployeeExpenseTile(
              item: item,
              onTap: canManage
                  ? () => context.push(
                        '/transactions/${item.id}/edit',
                        extra: item,
                      )
                  : null,
              onToggleSettled: () => _toggleSettled(item),
            );
            if (!canManage) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: tile,
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Dismissible(
                key: ValueKey('emp-${item.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: AppColors.expenseSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.expense,
                  ),
                ),
                confirmDismiss: (_) => showAppConfirmDialog(
                  context,
                  title: 'Delete Entry?',
                  message:
                      'Remove "${item.category.label}" for ${item.spenderName}? This cannot be undone.',
                  confirmLabel: 'Delete',
                  tone: AppConfirmTone.danger,
                ),
                onDismissed: (_) => _delete(item),
                child: tile,
              ),
            );
          },
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    final profile = context.watch<AuthBloc>().state.profile;
    final myId = profile?.id;
    final isSuperAdmin = profile?.isSuperAdmin == true;

    return PopScope(
      canPop: !_drilling,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _drilling) _closeSpender();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _drilling
              ? IconButton(
                  tooltip: 'Back',
                  onPressed: _closeSpender,
                  icon: const Icon(Icons.arrow_back_rounded),
                )
              : null,
          title: WellinAppBarTitle(
            title: _drilling
                ? (_selectedSpenderName ?? 'Spender')
                : 'Employee Entries',
          ),
        ),
        body: BlocBuilder<TransactionsCubit, TransactionsState>(
          builder: (context, state) {
            if (state.loading && state.items.isEmpty) {
              return const AppLoader.page();
            }

            final allEmployee =
                state.items.where((e) => e.isEmployeeExpense).toList();
            final pending = allEmployee
                .where((e) => !e.employeeExpenseSettled)
                .toList();
            final settled = allEmployee
                .where((e) => e.employeeExpenseSettled)
                .toList();
            final filtered = _employeeItems(state.items);
            final visible = _drilling
                ? filtered
                    .where((e) => _spenderKey(e) == _selectedSpenderId)
                    .toList()
                : filtered;

            final pendingTotal = _expenseTotal(pending);
            final settledTotal = _expenseTotal(settled);
            final allTotal = _expenseTotal(allEmployee);

            final categoryMap = <TxnCategory, double>{};
            for (final item
                in filtered.where((e) => e.type == TxnType.expense)) {
              categoryMap[item.category] =
                  (categoryMap[item.category] ?? 0) + item.amount;
            }
            final chartTotal = filtered
                .where((e) => e.type == TxnType.expense)
                .fold(0.0, (s, e) => s + e.amount);

            final summaries = _viewMode == _ViewMode.spender && !_drilling
                ? _spenderSummaries(filtered)
                : const <_SpenderSummary>[];
            final maxSpendBar = summaries.isEmpty
                ? 0.0
                : summaries
                    .map((e) => e.expenseTotal + e.incomeTotal)
                    .fold<double>(0, (a, b) => a > b ? a : b);

            return RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: () => context.read<TransactionsCubit>().load(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                children: [
                  if (!_drilling) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Employee Entries',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        MonthYearFilter(
                          year: state.year,
                          month: state.month,
                          day: state.day,
                          scope: state.scope,
                          compact: true,
                          onChanged: (y, m, d) => context
                              .read<TransactionsCubit>()
                              .setDate(y, m, d),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    PeriodScopeChips(
                      scope: state.scope,
                      onChanged: (v) =>
                          context.read<TransactionsCubit>().setScope(v),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: MetricTile(
                            compact: true,
                            label: 'Pending',
                            value: formatMoney(pendingTotal),
                            icon: Icons.schedule_rounded,
                            accent: AppColors.expense,
                            accentSoft:
                                AppColors.expense.withValues(alpha: 0.12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MetricTile(
                            compact: true,
                            label: 'Settled',
                            value: formatMoney(settledTotal),
                            icon: Icons.check_circle_outline,
                            accent: AppColors.income,
                            accentSoft:
                                AppColors.income.withValues(alpha: 0.12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MetricTile(
                            compact: true,
                            label: 'All',
                            value: formatMoney(allTotal),
                            icon: Icons.payments_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilterChipsRow(
                      labels: const ['All', 'Pending', 'Completed'],
                      selectedIndex: _settleFilter.index,
                      onSelected: (i) => setState(
                        () => _settleFilter = _SettleFilter.values[i],
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilterChipsRow(
                      labels: const ['By Category', 'By Spender'],
                      selectedIndex: _viewMode.index,
                      onSelected: _setViewMode,
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Text(
                      '${visible.length} entr${visible.length == 1 ? 'y' : 'ies'}'
                      ' · Exp ${formatMoney(_expenseTotal(visible))}'
                      ' · Inc ${formatMoney(_incomeTotal(visible))}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_viewMode == _ViewMode.category && !_drilling) ...[
                    PremiumCard(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                      child: chartTotal <= 0
                          ? Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 28),
                              child: Text(
                                'No Employee Entries In This Period.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            )
                          : _CategoryDonut(
                              map: categoryMap,
                              total: chartTotal,
                            ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Items (${visible.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._entryTiles(
                      items: visible,
                      myId: myId,
                      isSuperAdmin: isSuperAdmin,
                    ),
                  ] else if (_viewMode == _ViewMode.spender && !_drilling) ...[
                    if (summaries.isEmpty)
                      const EmptyState(
                        message:
                            'No employee entries yet. Flag one when saving an expense or income.',
                      )
                    else ...[
                      PremiumCard(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        child: Column(
                          children: [
                            Text(
                              formatMoney(
                                summaries.fold<double>(
                                  0,
                                  (s, e) => s + e.expenseTotal,
                                ),
                              ),
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppColors.expense,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Expense by spender · Tap a person',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Income ${formatMoney(summaries.fold<double>(0, (s, e) => s + e.incomeTotal))}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.income,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < summaries.length; i++) ...[
                        _SpenderSummaryTile(
                          summary: summaries[i],
                          color: AppColors.chartColor(i),
                          maxBar: maxSpendBar,
                          onTap: () => _openSpender(
                            summaries[i].userId,
                            summaries[i].name,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ] else ...[
                    ..._entryTiles(
                      items: visible,
                      myId: myId,
                      isSuperAdmin: isSuperAdmin,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SpenderSummary {
  const _SpenderSummary({
    required this.userId,
    required this.name,
    required this.expenseTotal,
    required this.incomeTotal,
    required this.expenseCount,
    required this.incomeCount,
  });

  final String userId;
  final String name;
  final double expenseTotal;
  final double incomeTotal;
  final int expenseCount;
  final int incomeCount;

  int get count => expenseCount + incomeCount;

  _SpenderSummary add(TransactionItem item) {
    return _SpenderSummary(
      userId: userId,
      name: name,
      expenseTotal:
          expenseTotal + (item.type == TxnType.expense ? item.amount : 0),
      incomeTotal:
          incomeTotal + (item.type == TxnType.income ? item.amount : 0),
      expenseCount: expenseCount + (item.type == TxnType.expense ? 1 : 0),
      incomeCount: incomeCount + (item.type == TxnType.income ? 1 : 0),
    );
  }
}

class _SpenderSummaryTile extends StatelessWidget {
  const _SpenderSummaryTile({
    required this.summary,
    required this.color,
    required this.maxBar,
    required this.onTap,
  });

  final _SpenderSummary summary;
  final Color color;
  final double maxBar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    final barValue = summary.expenseTotal + summary.incomeTotal;
    final parts = <String>[
      if (summary.expenseCount > 0)
        '${summary.expenseCount} expense${summary.expenseCount == 1 ? '' : 's'}',
      if (summary.incomeCount > 0)
        '${summary.incomeCount} income${summary.incomeCount == 1 ? '' : 's'}',
    ];

    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.18),
                child: Text(
                  summary.name.isEmpty
                      ? '?'
                      : summary.name.characters.first.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      parts.isEmpty ? 'No entries' : parts.join(' · '),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (summary.expenseTotal > 0)
                    Text(
                      formatMoney(summary.expenseTotal),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.expense,
                      ),
                    ),
                  if (summary.incomeTotal > 0)
                    Text(
                      formatMoney(summary.incomeTotal),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.income,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: maxBar == 0 ? 0 : barValue / maxBar,
              minHeight: 7,
              backgroundColor: AppColors.primaryMuted,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeExpenseTile extends StatelessWidget {
  const _EmployeeExpenseTile({
    required this.item,
    required this.onTap,
    required this.onToggleSettled,
  });

  final TransactionItem item;
  final VoidCallback? onTap;
  final VoidCallback onToggleSettled;

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    final settled = item.employeeExpenseSettled;
    final statusLabel = !settled
        ? 'Pending'
        : item.employeeChargeCompany
            ? 'Company'
            : 'Personal';
    final statusColor = !settled
        ? AppColors.expense
        : item.employeeChargeCompany
            ? AppColors.primary
            : AppColors.accent;
    return PremiumCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TxnIconWell(category: item.category),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.category.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    AmountText(
                      amount: item.amount,
                      type: item.type,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.spenderName} · ${formatDate(item.txnDate)} · '
                  '${item.type.label}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (item.note != null && item.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.note!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: onToggleSettled,
                      child: Text(settled ? 'Undo' : 'Complete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryDonut extends StatelessWidget {
  const _CategoryDonut({required this.map, required this.total});

  final Map<TxnCategory, double> map;
  final double total;

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 48,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value,
                    color: categoryColor(entries[i].key),
                    radius: 28,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          formatMoney(total),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          'Expense Total',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 10,
          children: [
            for (final e in entries)
              SizedBox(
                width: (MediaQuery.sizeOf(context).width - 72) / 2,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: categoryColor(e.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.key.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      total == 0
                          ? '0%'
                          : '${((e.value / total) * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
