import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/period_scope.dart';
import '../../../shared/models/transaction_item.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/amount_text.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/counting_money_text.dart';
import '../../../shared/widgets/design/metric_tile.dart';
import '../../../shared/widgets/design/premium_card.dart';
import '../../../shared/widgets/design/section_header.dart';
import '../../../shared/widgets/design/txn_icon.dart';
import '../../../shared/widgets/month_year_filter.dart';
import '../../../shared/widgets/wellin_logo.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../transactions/bloc/transactions_cubit.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    context.read<TransactionsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    final profile = context.watch<AuthBloc>().state.profile;
    final name = profile?.name ?? 'there';
    final first = name.split(' ').first;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<TransactionsCubit, TransactionsState>(
          builder: (context, state) {
            if (state.loading && state.items.isEmpty) {
              return const AppLoader.page();
            }

            final recent = state.items.take(5).toList();
            final expenseItems = state.items
                .where(
                  (e) => e.type == TxnType.expense && e.countsInCompanyBooks,
                )
                .toList();

            return RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: () => context.read<TransactionsCubit>().load(),
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 120),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      WellinLogo(height: 28, showWordmark: false),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hi, $first',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Workspace Overview',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
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
                  const SizedBox(height: 20),
                  PremiumCard(
                    padding: EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Balance',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 8),
                        CountingMoneyText(
                          value: state.net,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: state.net >= 0
                                ? AppColors.income
                                : AppColors.expense,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          state.periodLabel,
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: MetricTile(
                          label: 'Income',
                          amount: state.incomeTotal,
                          icon: Icons.south_west_rounded,
                          compact: true,
                          accent: AppColors.income,
                          accentSoft: AppColors.incomeSoft,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: MetricTile(
                          label: 'Expenses',
                          amount: state.expenseTotal,
                          icon: Icons.north_east_rounded,
                          compact: true,
                          accent: AppColors.expense,
                          accentSoft: AppColors.expenseSoft,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  PremiumCard(
                    onTap: () => context.go('/analytics'),
                    padding: EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Analytics',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'View Spending Insights',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 44,
                                child: _Sparkline(
                                  items: expenseItems,
                                  year: state.year,
                                  month: state.month,
                                  scope: state.scope,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primaryMuted,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  SectionHeader(
                    title: 'Recent Expenses',
                    actionLabel: 'See all',
                    onAction: () => context.go('/transactions'),
                  ),
                  SizedBox(height: 12),
                  if (recent.isEmpty)
                    PremiumCard(
                      child: Text(
                        switch (state.scope) {
                          PeriodScope.day => 'No Expenses This Day.',
                          PeriodScope.month => 'No Expenses This Month.',
                          PeriodScope.year => 'No Expenses This Year.',
                        },
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    ...recent.map((item) {
                      final canManage = item.createdBy == profile?.id ||
                          profile?.isSuperAdmin == true;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: PremiumCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          onTap: canManage
                              ? () => context.push(
                                    '/transactions/${item.id}/edit',
                                    extra: item,
                                  )
                              : () => context.go('/transactions'),
                          child: Row(
                            children: [
                              TxnIconWell(category: item.category),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.category.label,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      '${formatDate(item.txnDate)} · ${item.creatorName}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AmountText(
                                amount: item.amount,
                                type: item.type,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Sparkline extends StatefulWidget {
  const _Sparkline({
    required this.items,
    required this.year,
    required this.month,
    this.scope = PeriodScope.month,
  });

  final List<TransactionItem> items;
  final int year;
  final int month;
  final PeriodScope scope;

  static const _pointCount = 24;

  @override
  State<_Sparkline> createState() => _SparklineState();
}

class _SparklineState extends State<_Sparkline>
    with TickerProviderStateMixin {
  late final AnimationController _breath;
  late final AnimationController _morph;
  late List<FlSpot> _from;
  late List<FlSpot> _to;
  String _dataKey = '';

  @override
  void initState() {
    super.initState();
    _to = _normalize(_rawSpots());
    _from = _to;
    _dataKey = _keyFor(widget);
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _morph = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..value = 1;
  }

  @override
  void didUpdateWidget(covariant _Sparkline oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextKey = _keyFor(widget);
    if (nextKey != _dataKey) {
      final t = Curves.easeInOutCubic.transform(_morph.value);
      _from = _lerpSpots(_from, _to, t);
      _to = _normalize(_rawSpots());
      _dataKey = nextKey;
      _morph.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _morph.dispose();
    super.dispose();
  }

  String _keyFor(_Sparkline w) =>
      '${w.scope.name}-${w.year}-${w.month}-${w.items.length}-'
      '${w.items.fold<double>(0, (s, e) => s + e.amount)}';

  List<FlSpot> _rawSpots() {
    final items = widget.items;
    final today = DateTime.now();
    var running = 0.0;
    final spots = <FlSpot>[];

    if (widget.scope == PeriodScope.year) {
      final byMonth = <int, double>{};
      for (final item in items) {
        final m = item.txnDate.month;
        byMonth[m] = (byMonth[m] ?? 0) + item.amount;
      }
      final lastMonth =
          widget.year == today.year ? today.month.clamp(1, 12) : 12;
      for (var m = 1; m <= lastMonth; m++) {
        running += byMonth[m] ?? 0;
        spots.add(FlSpot(m.toDouble(), running));
      }
    } else if (widget.scope == PeriodScope.day) {
      running = items.fold(0.0, (sum, e) => sum + e.amount);
      spots
        ..add(const FlSpot(0, 0))
        ..add(FlSpot(1, running));
    } else {
      final byDay = <int, double>{};
      for (final item in items) {
        final day = item.txnDate.day;
        byDay[day] = (byDay[day] ?? 0) + item.amount;
      }
      final daysInMonth = DateTime(widget.year, widget.month + 1, 0).day;
      final lastDay =
          (widget.year == today.year && widget.month == today.month)
              ? today.day.clamp(1, daysInMonth)
              : daysInMonth;
      for (var day = 1; day <= lastDay; day++) {
        running += byDay[day] ?? 0;
        spots.add(FlSpot(day.toDouble(), running));
      }
    }
    return spots;
  }

  List<FlSpot> _normalize(List<FlSpot> raw) {
    const n = _Sparkline._pointCount;
    if (raw.isEmpty) {
      return [for (var i = 0; i < n; i++) FlSpot(i.toDouble(), 0)];
    }
    if (raw.length == 1) {
      final y = raw.first.y;
      return [for (var i = 0; i < n; i++) FlSpot(i.toDouble(), y)];
    }

    final minX = raw.first.x;
    final maxX = raw.last.x;
    final span = (maxX - minX).abs() < 1e-6 ? 1.0 : maxX - minX;

    double yAt(double x) {
      if (x <= raw.first.x) return raw.first.y;
      if (x >= raw.last.x) return raw.last.y;
      for (var i = 1; i < raw.length; i++) {
        final a = raw[i - 1];
        final b = raw[i];
        if (x <= b.x) {
          final t = (x - a.x) / (b.x - a.x);
          return a.y + (b.y - a.y) * t;
        }
      }
      return raw.last.y;
    }

    return [
      for (var i = 0; i < n; i++)
        FlSpot(i.toDouble(), yAt(minX + (i / (n - 1)) * span)),
    ];
  }

  List<FlSpot> _lerpSpots(List<FlSpot> a, List<FlSpot> b, double t) {
    final n = math.min(a.length, b.length);
    return [
      for (var i = 0; i < n; i++)
        FlSpot(a[i].x, a[i].y + (b[i].y - a[i].y) * t),
    ];
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    if (widget.items.isEmpty) {
      return CustomPaint(
        painter: _EmptySparkPainter(AppColors.borderStrong),
        child: const SizedBox.expand(),
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_breath, _morph]),
      builder: (context, _) {
        final morphT = Curves.easeInOutCubic.transform(_morph.value);
        final base = _lerpSpots(_from, _to, morphT);
        final peak = base.fold<double>(0, (s, e) => e.y > s ? e.y : s);
        final chartMax = peak <= 0 ? 1.0 : peak * 1.18;
        final breathT = Curves.easeInOut.transform(_breath.value);
        final amp = chartMax * 0.03;
        final spots = [
          for (var i = 0; i < base.length; i++)
            FlSpot(
              base[i].x,
              math.max(
                0,
                base[i].y +
                    math.sin((breathT * 2 * math.pi) + i * 0.42) * amp,
              ),
            ),
        ];

        return LineChart(
          LineChartData(
            minX: 0,
            maxX: (_Sparkline._pointCount - 1).toDouble(),
            minY: 0,
            maxY: chartMax,
            gridData: FlGridData(show: false),
            titlesData: FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(enabled: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.28,
                color: AppColors.accent,
                barWidth: 2.2,
                isStrokeCapRound: true,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.accent.withValues(alpha: 0.14),
                ),
              ),
            ],
          ),
          duration: Duration.zero,
        );
      },
    );
  }
}

class _EmptySparkPainter extends CustomPainter {
  _EmptySparkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(0, size.height * 0.6)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.2,
        size.width * 0.55,
        size.height * 0.55,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.85,
        size.width,
        size.height * 0.4,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _EmptySparkPainter oldDelegate) =>
      oldDelegate.color != color;
}
