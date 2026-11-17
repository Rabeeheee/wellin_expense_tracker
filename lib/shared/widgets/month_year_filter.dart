import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/theme_rebuild_scope.dart';
import '../models/period_scope.dart';
import '../utils/formatters.dart';
import 'design/circle_icon_button.dart';

class MonthYearFilter extends StatelessWidget {
  const MonthYearFilter({
    super.key,
    required this.year,
    required this.month,
    required this.day,
    required this.scope,
    required this.onChanged,
    this.onScopeChanged,
    this.compact = false,
  });

  final int year;
  final int month;
  final int day;
  final PeriodScope scope;
  final void Function(int year, int month, int day) onChanged;
  final ValueChanged<PeriodScope>? onScopeChanged;
  final bool compact;

  DateTime get _date {
    final maxDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day.clamp(1, maxDay));
  }

  String get _label => switch (scope) {
        PeriodScope.day => formatDate(_date),
        PeriodScope.month => formatMonthYear(DateTime(year, month)),
        PeriodScope.year => formatYear(year),
      };

  Widget _periodPill(BuildContext context) {
    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 8 : 12,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(compact ? 20 : 14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 13 : 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _scopeChips({bool expanded = false}) {
    if (onScopeChanged == null) return const SizedBox.shrink();
    return PeriodScopeChips(
      scope: scope,
      onChanged: onScopeChanged!,
      expanded: expanded,
    );
  }

  void _step(int delta) {
    switch (scope) {
      case PeriodScope.day:
        final next = _date.add(Duration(days: delta));
        onChanged(next.year, next.month, next.day);
      case PeriodScope.month:
        final next = DateTime(year, month + delta);
        final maxDay = DateTime(next.year, next.month + 1, 0).day;
        onChanged(next.year, next.month, day.clamp(1, maxDay));
      case PeriodScope.year:
        onChanged(year + delta, month, day);
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    if (compact) {
      return _periodPill(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onScopeChanged != null) ...[
          _scopeChips(expanded: true),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            CircleIconButton(
              icon: Icons.chevron_left,
              onPressed: () => _step(-1),
            ),
            const SizedBox(width: 10),
            Expanded(child: _periodPill(context)),
            const SizedBox(width: 10),
            CircleIconButton(
              icon: Icons.chevron_right,
              onPressed: () => _step(1),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    switch (scope) {
      case PeriodScope.day:
        final picked = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          helpText: 'Select Day',
        );
        if (picked != null) {
          onChanged(picked.year, picked.month, picked.day);
        }
      case PeriodScope.month:
        final picked = await showDialog<(int, int)>(
          context: context,
          builder: (ctx) => _MonthPickerDialog(year: year, month: month),
        );
        if (picked != null) {
          final maxDay = DateTime(picked.$1, picked.$2 + 1, 0).day;
          onChanged(picked.$1, picked.$2, day.clamp(1, maxDay));
        }
      case PeriodScope.year:
        final picked = await showDialog<int>(
          context: context,
          builder: (ctx) {
            final now = DateTime.now().year;
            final years = [for (var y = now; y >= 2020; y--) y];
            return Dialog(
              backgroundColor: AppColors.surfaceElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: AppColors.borderStrong),
              ),
              child: SizedBox(
                width: 280,
                height: 320,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Select Year',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: years.length,
                        itemBuilder: (context, i) {
                          final y = years[i];
                          final selected = y == year;
                          return ListTile(
                            title: Text(
                              '$y',
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? AppColors.accent
                                    : AppColors.textPrimary,
                              ),
                            ),
                            onTap: () => Navigator.pop(ctx, y),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
        if (picked != null) onChanged(picked, month, day);
    }
  }
}

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({required this.year, required this.month});

  final int year;
  final int month;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year;

  static const _months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _year = widget.year;
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.borderStrong),
      ),
      child: SizedBox(
        width: 320,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous Year',
                    onPressed: _year <= 2020
                        ? null
                        : () => setState(() => _year -= 1),
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '$_year',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next Year',
                    onPressed: _year >= DateTime.now().year + 1
                        ? null
                        : () => setState(() => _year += 1),
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 12,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.2,
                ),
                itemBuilder: (context, index) {
                  final m = index + 1;
                  final selected = m == widget.month && _year == widget.year;
                  return Material(
                    color: selected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(context, (_year, m)),
                      child: Center(
                        child: Text(
                          _months[index].substring(0, 3),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: selected
                                ? AppColors.fabIcon
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Day / Month / Year scope chips for use on their own layout row.
class PeriodScopeChips extends StatelessWidget {
  const PeriodScopeChips({
    super.key,
    required this.scope,
    required this.onChanged,
    this.expanded = true,
  });

  final PeriodScope scope;
  final ValueChanged<PeriodScope> onChanged;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    return Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (var i = 0; i < PeriodScope.values.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Flexible(
            fit: expanded ? FlexFit.tight : FlexFit.loose,
            child: _ScopeChip(
              label: PeriodScope.values[i].label,
              selected: scope == PeriodScope.values[i],
              onTap: () => onChanged(PeriodScope.values[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.borderStrong,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected ? AppColors.fabIcon : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
