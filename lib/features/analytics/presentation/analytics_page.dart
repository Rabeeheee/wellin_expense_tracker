import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/period_scope.dart';
import '../../../shared/models/transaction_item.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/counting_money_text.dart';
import '../../../shared/widgets/design/circle_icon_button.dart';
import '../../../shared/widgets/design/filter_chips_row.dart';
import '../../../shared/widgets/design/premium_card.dart';
import '../../../shared/widgets/design/premium_select_field.dart';
import '../../../shared/widgets/design/section_header.dart';
import '../../../shared/widgets/design/txn_icon.dart';
import '../../../shared/widgets/month_year_filter.dart';
import '../../projects/bloc/projects_cubit.dart';
import '../../transactions/bloc/transactions_cubit.dart';
import '../../transactions/data/transaction_repository.dart';

enum _AnalyticsMode { all, income, expense, byUser }

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  static const _allProjects = '__all__';
  static const _noProject = '';

  _AnalyticsMode _mode = _AnalyticsMode.all;
  List<TransactionItem> _trendItems = const [];
  double? _prevExpense;
  bool _trendLoading = false;

  @override
  void initState() {
    super.initState();
    context.read<TransactionsCubit>().load();
    context.read<ProjectsCubit>().load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExtras());
  }

  Future<void> _loadExtras() async {
    final state = context.read<TransactionsCubit>().state;
    final repo = context.read<TransactionRepository>();
    setState(() => _trendLoading = true);
    try {
      final end = monthEnd(state.year, state.month);
      final startMonth = DateTime(state.year, state.month - 5);
      final start = monthStart(startMonth.year, startMonth.month);
      final prev = DateTime(state.year, state.month - 1);

      final results = await Future.wait([
        repo.fetchRange(start: start, end: end),
        repo.fetchMonth(year: prev.year, month: prev.month),
      ]);

      final trend = results[0];
      final prevItems = results[1];
      final prevExpense = prevItems
          .where((e) => e.type == TxnType.expense)
          .fold<double>(0, (s, e) => s + e.amount);

      if (!mounted) return;
      setState(() {
        _trendItems = trend;
        _prevExpense = prevExpense;
        _trendLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _trendLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocConsumer<TransactionsCubit, TransactionsState>(
          listenWhen: (p, c) =>
              p.year != c.year ||
              p.month != c.month ||
              p.day != c.day ||
              p.scope != c.scope ||
              p.items != c.items,
          listener: (context, state) => _loadExtras(),
          builder: (context, state) {
            if (state.loading && state.items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final filtered = _filterItems(state.items, state.projectFilter);
            final categoryMap = <TxnCategory, double>{};
            final userMap = <String, double>{};
            for (final item in filtered) {
              categoryMap[item.category] =
                  (categoryMap[item.category] ?? 0) + item.amount;
              userMap[item.creatorName] =
                  (userMap[item.creatorName] ?? 0) + item.amount;
            }

            final total = filtered.fold<double>(0, (s, e) => s + e.amount);
            final expenseTotal = filtered
                .where((e) => e.type == TxnType.expense)
                .fold<double>(0, (s, e) => s + e.amount);
            final insight = _insightText(expenseTotal);

            final trendBars = _buildTrendBars(state.year, state.month);

            return RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: () async {
                await context.read<TransactionsCubit>().load();
                await _loadExtras();
              },
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 120),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Analytics',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      CircleIconButton(
                        icon: Icons.calendar_today_outlined,
                        onPressed: () async {
                          final cubit = context.read<TransactionsCubit>();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: cubit.state.selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null && context.mounted) {
                            await cubit.setScope(PeriodScope.day);
                            await cubit.setDate(
                              picked.year,
                              picked.month,
                              picked.day,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilterChipsRow(
                    labels: ['All', 'Income', 'Expense', 'By User'],
                    selectedIndex: _mode.index,
                    onSelected: (i) =>
                        setState(() => _mode = _AnalyticsMode.values[i]),
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final projects =
                          context.watch<ProjectsCubit>().state.items;
                      final selected = state.projectFilter == null
                          ? _allProjects
                          : state.projectFilter!;
                      return PremiumSelectField<String>(
                        label: 'Project',
                        value: selected,
                        options: [
                          const PremiumSelectOption(
                            value: _allProjects,
                            label: 'All Projects',
                          ),
                          const PremiumSelectOption(
                            value: _noProject,
                            label: 'No Project',
                          ),
                          ...projects.map(
                            (p) => PremiumSelectOption(
                              value: p.id,
                              label: '${p.title} · ${p.clientName}',
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          context.read<TransactionsCubit>().setProjectFilter(
                                v == _allProjects ? null : v,
                              );
                        },
                      );
                    },
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Your Spending',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                  PremiumCard(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: Column(
                      children: [
                        CountingMoneyText(
                          value: total,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: switch (_mode) {
                              _AnalyticsMode.income => AppColors.income,
                              _AnalyticsMode.expense => AppColors.expense,
                              _ => AppColors.textPrimary,
                            },
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _mode == _AnalyticsMode.byUser
                              ? 'By Contributor'
                              : _mode == _AnalyticsMode.income
                                  ? 'Total Income'
                                  : _mode == _AnalyticsMode.expense
                                      ? 'Total Spent'
                                      : 'Total Activity',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 20),
                        if (_mode == _AnalyticsMode.byUser)
                          _UserBars(map: userMap)
                        else if (categoryMap.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Text(
                              'No Data For This Filter.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        else
                          _DonutWithLegend(
                            map: categoryMap,
                            total: total,
                          ),
                      ],
                    ),
                  ),
                  if (insight != null) ...[
                    SizedBox(height: 12),
                  PremiumCard(
                    color: AppColors.accentSoft,
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.insights_outlined,
                            color: AppColors.accent,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            insight,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ],
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Spending Trend'),
                  const SizedBox(height: 12),
                  PremiumCard(
                    padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                    child: SizedBox(
                      height: 180,
                      child: _trendLoading &&
                              trendBars.every((e) => e.$2 == 0)
                          ? const Center(child: CircularProgressIndicator())
                          : _TrendBars(bars: trendBars),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<TransactionItem> _filterItems(
    List<TransactionItem> items,
    String? projectFilter,
  ) {
    Iterable<TransactionItem> scoped = items;
    if (projectFilter != null) {
      scoped = scoped.where((e) {
        if (projectFilter.isEmpty) return e.projectId == null;
        return e.projectId == projectFilter;
      });
    }
    return switch (_mode) {
      _AnalyticsMode.all => scoped.toList(),
      _AnalyticsMode.income =>
        scoped.where((e) => e.type == TxnType.income).toList(),
      _AnalyticsMode.expense =>
        scoped.where((e) => e.type == TxnType.expense).toList(),
      _AnalyticsMode.byUser =>
        scoped.where((e) => e.type == TxnType.expense).toList(),
    };
  }

  String? _insightText(double expenseTotal) {
    final prev = _prevExpense;
    if (prev == null) return null;
    if (prev == 0 && expenseTotal == 0) {
      return 'No spending recorded for this or last month.';
    }
    if (prev == 0) {
      return 'First spending month on record — keep tracking.';
    }
    final delta = ((expenseTotal - prev) / prev) * 100;
    final abs = delta.abs().toStringAsFixed(0);
    if (delta <= 0) {
      return 'You spent $abs% less than last month.';
    }
    return 'Expense was up $abs% vs last month.';
  }

  List<(String, double)> _buildTrendBars(int year, int month) {
    final projectFilter =
        context.read<TransactionsCubit>().state.projectFilter;
    final bars = <(String, double)>[];
    for (var i = 5; i >= 0; i--) {
      final d = DateTime(year, month - i);
      final label = _shortMonth(d.month);
      final sum = _trendItems
          .where((e) {
            if (e.type != TxnType.expense) return false;
            if (e.txnDate.year != d.year || e.txnDate.month != d.month) {
              return false;
            }
            if (projectFilter == null) return true;
            if (projectFilter.isEmpty) return e.projectId == null;
            return e.projectId == projectFilter;
          })
          .fold<double>(0, (s, e) => s + e.amount);
      bars.add((label, sum));
    }
    return bars;
  }

  String _shortMonth(int m) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[m - 1];
  }
}

class _DonutWithLegend extends StatelessWidget {
  const _DonutWithLegend({required this.map, required this.total});

  final Map<TxnCategory, double> map;
  final double total;

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    // Stable category order so slice values lerp instead of reshuffling.
    final entries = TxnCategory.values
        .map((c) => MapEntry(c, map[c] ?? 0.0))
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => a.key.index.compareTo(b.key.index));

    final legend = [...entries]
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 54,
              sections: [
                for (final entry in entries)
                  PieChartSectionData(
                    value: entry.value,
                    color: categoryColor(entry.key),
                    title: '',
                    radius: 42,
                  ),
              ],
            ),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOutCubic,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 10,
          children: [
            for (final entry in legend)
              SizedBox(
                width: (MediaQuery.sizeOf(context).width - 72) / 2,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: categoryColor(entry.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.key.label,
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
                          : '${((entry.value / total) * 100).round()}%',
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

class _UserBars extends StatelessWidget {
  const _UserBars({required this.map});

  final Map<String, double> map;

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    if (map.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Text(
          'No Expenses By User.',
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
            padding: EdgeInsets.only(bottom: 12),
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
                    CountingMoneyText(
                      value: entries[i].value,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.chartColor(i),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0,
                    end: max == 0 ? 0 : entries[i].value / max,
                  ),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
                        backgroundColor: AppColors.primaryMuted,
                        color: AppColors.chartColor(i),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TrendBars extends StatelessWidget {
  const _TrendBars({required this.bars});

  final List<(String, double)> bars;

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    final maxY = bars.fold<double>(0, (s, e) => e.$2 > s ? e.$2 : s);
    final chartMax = maxY <= 0 ? 1.0 : maxY * 1.25;

    return BarChart(
      BarChartData(
        maxY: chartMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.border.withValues(alpha: 0.8),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchExtraThreshold: EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 24,
          ),
          touchTooltipData: BarTouchTooltipData(
            tooltipBorderRadius: BorderRadius.circular(14),
            tooltipPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            tooltipMargin: 10,
            maxContentWidth: 160,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            direction: TooltipDirection.top,
            tooltipBorder: BorderSide(color: AppColors.borderStrong),
            getTooltipColor: (_) => AppColors.surfaceElevated,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (groupIndex < 0 || groupIndex >= bars.length) return null;
              final month = bars[groupIndex].$1;
              final amount = bars[groupIndex].$2;
              final isCurrent = groupIndex == bars.length - 1;
              final accent =
                  isCurrent ? AppColors.expense : AppColors.accent;

              return BarTooltipItem(
                month,
                TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  height: 1.2,
                ),
                children: [
                  TextSpan(
                    text: '\n${formatMoney(amount)}',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  TextSpan(
                    text: '\nSpent',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= bars.length) return const SizedBox.shrink();
                final isLast = i == bars.length - 1;
                return Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    bars[i].$1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
                      color: isLast
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < bars.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: bars[i].$2 <= 0 ? 0.01 : bars[i].$2,
                  width: 18,
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: i == bars.length - 1
                        ? [
                            AppColors.expense.withValues(alpha: 0.55),
                            AppColors.expense,
                          ]
                        : [
                            AppColors.accent.withValues(alpha: 0.35),
                            AppColors.accent.withValues(alpha: 0.85),
                          ],
                  ),
                ),
              ],
            ),
        ],
      ),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
    );
  }
}
