import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';

class PremiumSelectOption<T> {
  const PremiumSelectOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Dark-premium select that opens a bottom sheet instead of a Material menu.
class PremiumSelectField<T> extends StatelessWidget {
  const PremiumSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final T value;
  final List<PremiumSelectOption<T>> options;
  final ValueChanged<T> onChanged;
  final bool enabled;

  String get _currentLabel {
    for (final o in options) {
      if (o.value == value) return o.label;
    }
    return '';
  }

  Future<void> _open(BuildContext context) async {
    if (!enabled) return;
    final selected = await showModalBottomSheet<T>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, 12, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderStrong,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: AppColors.border,
                    ),
                    itemBuilder: (context, index) {
                      final option = options[index];
                      final selected = option.value == value;
                      return ListTile(
                        title: Text(
                          option.label,
                          style: TextStyle(
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        trailing: selected
                            ? Icon(
                                Icons.check_rounded,
                                color: AppColors.primary,
                              )
                            : null,
                        onTap: () => Navigator.pop(context, option.value),
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
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 8),
        Material(
          color: enabled ? AppColors.surface : AppColors.primaryMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            onTap: enabled ? () => _open(context) : null,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _currentLabel,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: enabled
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: enabled
                        ? AppColors.textSecondary
                        : AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
