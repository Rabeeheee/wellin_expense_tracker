import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';
import '../counting_money_text.dart';
import 'premium_card.dart';

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    this.value,
    this.amount,
    this.icon,
    this.compact = false,
    this.accent,
    this.accentSoft,
  }) : assert(value != null || amount != null);

  final String label;
  final String? value;
  final double? amount;
  final IconData? icon;
  final bool compact;
  final Color? accent;
  final Color? accentSoft;

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    final color = accent ?? AppColors.textPrimary;
    final soft = accentSoft ?? AppColors.primaryMuted;
    final style = TextStyle(
      fontSize: compact ? 16 : 18,
      fontWeight: FontWeight.w700,
      color: color,
    );

    return PremiumCard(
      padding: EdgeInsets.all(compact ? 14 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: soft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            SizedBox(height: 12),
          ],
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          if (amount != null)
            CountingMoneyText(value: amount!, style: style)
          else
            Text(value!, style: style),
        ],
      ),
    );
  }
}
