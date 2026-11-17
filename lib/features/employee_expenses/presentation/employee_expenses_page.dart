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

enum _ChartMode { category, spender }

class EmployeeExpensesPage extends StatefulWidget {
  const EmployeeExpensesPage({super.key});

  @override
  State<EmployeeExpensesPage> createState() => _EmployeeExpensesPageState();
}

class _EmployeeExpensesPageState extends State<EmployeeExpensesPage> {
  _SettleFilter _settleFilter = _SettleFilter.all;
  _ChartMode _chartMode = _ChartMode.category;

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

  Future<void> _toggleSettled(TransactionItem item) async {
    final markComplete = !item.employeeExpenseSettled;
    final ok = await showAppConfirmDialog(
      context,
      title: markComplete ? 'Mark Completed?' : 'Undo Completion?',
      message: markComplete
          ? 'Mark this as reimbursed to ${item.spenderName}.'
          : 'Move this back to pending.',
      confirmLabel: markComplete ? 'Complete' : 'Undo',
      tone: markComplete ? AppConfirmTone.success : AppConfirmTone.danger,
    );
    if (!ok || !mounted) return;
    try {
      await context.read<TransactionsCubit>().setEmployeeExpenseSettled(
            id: item.id,
            settled: markComplete,
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

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    final profile = context.watch<AuthBloc>().state.profile;
    final myId = profile?.id;
    final isSuperAdmin = profile?.isSuperAdmin == true;

    return Scaffold(
      appBar: AppBar(
        title: const WellinAppBarTitle(title: 'Employee Expenses'),
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

          final pendingTotal = _expenseTotal(pending);
          final settledTotal = _expenseTotal(settled);
          final allTotal = _expenseTotal(allEmployee);

          final categoryMap = <TxnCategory, double>{};
          final spenderMap = <String, double>{};
          for (final item in filtered.where((e) => e.type == TxnType.expense)) {
            categoryMap[item.category] =
                (categoryMap[item.category] ?? 0) + item.amount;
            spenderMap[item.spenderName] =
                (spenderMap[item.spenderName] ?? 0) + item.amount;
          }
          final chartTotal = filtered
              .where((e) => e.type == TxnType.expense)
              .fold(0.0, (s, e) => s + e.amount);

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: () => context.read<TransactionsCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Reimbursements',
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
                        accentSoft: AppColors.expense.withValues(alpha: 0.12),
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
                        accentSoft: AppColors.income.withValues(alpha: 0.12),
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
                  selectedIndex: _chartMode.index,
                  onSelected: (i) => setState(
                    () => _chartMode = _ChartMode.values[i],
                  ),
                ),
                const SizedBox(height: 16),
                PremiumCard(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: chartTotal <= 0
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Text(
                            'No Employee Expenses In This Period.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : _chartMode == _ChartMode.category
                          ? _CategoryDonut(
                              map: categoryMap,
                              total: chartTotal,
                            )
                          : _SpenderBars(map: spenderMap),
                ),
                const SizedBox(height: 20),
                Text(
                  'Items (${filtered.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  const EmptyState(
                    message:
                        'No employee expenses yet. Flag one when saving an expense or income.',
                  )
                else
                  ...filtered.map((item) {
                    final canManage =
                        item.createdBy == myId || isSuperAdmin;
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
                          title: 'Delete Expense?',
                          message:
                              'Remove "${item.category.label}" for ${item.spenderName}? This cannot be undone.',
                          confirmLabel: 'Delete',
                          tone: AppConfirmTone.danger,
                        ),
                        onDismissed: (_) => _delete(item),
                        child: tile,
                      ),
                    );
                  }),
              ],
            ),
          );
        },
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
                  '${item.spenderName} · ${formatDate(item.txnDate)}',
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
                        color: settled
                            ? AppColors.income.withValues(alpha: 0.12)
                            : AppColors.expense.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        settled ? 'Completed' : 'Pending',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: settled ? AppColors.income : AppColors.expense,
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

class _SpenderBars extends StatelessWidget {
  const _SpenderBars({required this.map});

  final Map<String, double> map;

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    if (map.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Text(
          'No Spenders Yet.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.first.value;

    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entries[i].key,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      formatMoney(entries[i].value),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.chartColor(i),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : entries[i].value / max,
                    minHeight: 8,
                    backgroundColor: AppColors.primaryMuted,
                    color: AppColors.chartColor(i),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
