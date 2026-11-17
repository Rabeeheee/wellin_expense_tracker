import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';
import '../../models/enums.dart';

IconData categoryIcon(TxnCategory category) {
  return switch (category) {
    TxnCategory.projectIncome => Icons.work_outline,
    TxnCategory.dayToDay => Icons.payments_outlined,
    TxnCategory.otherIncome => Icons.trending_up,
    TxnCategory.projectExpenses => Icons.construction_outlined,
    TxnCategory.officeExpenses => Icons.apartment_outlined,
    TxnCategory.roomRent => Icons.home_outlined,
    TxnCategory.electricity => Icons.bolt_outlined,
    TxnCategory.otherExpense => Icons.receipt_long_outlined,
  };
}

Color categoryColor(TxnCategory category) {
  return switch (category) {
    TxnCategory.projectIncome => AppColors.income,
    TxnCategory.dayToDay => AppColors.teal,
    TxnCategory.otherIncome => AppColors.accent,
    TxnCategory.projectExpenses => AppColors.chartPalette[5],
    TxnCategory.officeExpenses => AppColors.accent,
    TxnCategory.roomRent => AppColors.chartPalette[6],
    TxnCategory.electricity => AppColors.warning,
    TxnCategory.otherExpense => AppColors.expense,
  };
}

class TxnIconWell extends StatelessWidget {
  const TxnIconWell({super.key, required this.category, this.size = 44});

  final TxnCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    final color = categoryColor(category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        categoryIcon(category),
        size: size * 0.45,
        color: color,
      ),
    );
  }
}
