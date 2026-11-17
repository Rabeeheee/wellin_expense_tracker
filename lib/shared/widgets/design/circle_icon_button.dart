import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 42,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    return Material(
      color: AppColors.surface,
      shape: CircleBorder(
        side: BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        customBorder: CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
