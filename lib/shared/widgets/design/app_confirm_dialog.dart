import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';

enum AppConfirmTone { neutral, danger, success }

/// Single confirm dialog style used across the app.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  AppConfirmTone tone = AppConfirmTone.neutral,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (ctx) => AppConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      tone: tone,
      icon: icon,
    ),
  );
  return result == true;
}

class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.tone = AppConfirmTone.neutral,
    this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final AppConfirmTone tone;
  final IconData? icon;

  Color get _accent => switch (tone) {
        AppConfirmTone.danger => AppColors.expense,
        AppConfirmTone.success => AppColors.income,
        AppConfirmTone.neutral => AppColors.accent,
      };

  Color get _accentSoft => switch (tone) {
        AppConfirmTone.danger => AppColors.expenseSoft,
        AppConfirmTone.success => AppColors.incomeSoft,
        AppConfirmTone.neutral => AppColors.accentSoft,
      };

  IconData get _defaultIcon => switch (tone) {
        AppConfirmTone.danger => Icons.delete_outline_rounded,
        AppConfirmTone.success => Icons.check_circle_outline_rounded,
        AppConfirmTone.neutral => Icons.help_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 22, 20, 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _accentSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon ?? _defaultIcon, color: _accent, size: 26),
            ),
            SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: AppColors.borderStrong),
                      minimumSize: Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(cancelLabel),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: tone == AppConfirmTone.neutral
                          ? AppColors.textPrimary
                          : AppColors.fabIcon,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      confirmLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
