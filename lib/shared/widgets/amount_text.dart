import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/theme_rebuild_scope.dart';
import '../models/enums.dart';
import '../utils/formatters.dart';

class AmountText extends StatelessWidget {
  const AmountText({
    super.key,
    required this.amount,
    required this.type,
    this.style,
  });

  final double amount;
  final TxnType type;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    final color =
        type == TxnType.income ? AppColors.income : AppColors.expense;
    final prefix = type == TxnType.income ? '+' : '−';
    return Text(
      '$prefix${formatMoney(amount)}',
      style: (style ?? const TextStyle(fontWeight: FontWeight.w600))
          .copyWith(color: color),
    );
  }
}
