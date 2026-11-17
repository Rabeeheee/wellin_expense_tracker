import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/theme_rebuild_scope.dart';

/// Brand mark — white on dark by default for the premium theme.
class WellinLogo extends StatelessWidget {
  const WellinLogo({
    super.key,
    this.height = 96,
    this.width,
    this.showWordmark = true,
    this.compact = false,
    this.onDark = true,
  });

  final double height;
  final double? width;
  final bool showWordmark;
  final bool compact;
  final bool onDark;

  static const assetBlack = 'assets/images/wellin_logo_black.png';
  static const assetWhite = 'assets/images/wellin_logo_white.png';
  static const assetPath = assetWhite;

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    // Prefer explicit onDark; otherwise follow active theme.
    final useDarkMark = onDark && !AppColors.isLight;
    final mark = Image.asset(
      useDarkMark ? assetWhite : assetBlack,
      height: height,
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    if (!showWordmark) return mark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(height: compact ? 6 : 10),
        Text(
          'Expense Tracker',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 18 : 26,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class WellinAppBarTitle extends StatelessWidget {
  const WellinAppBarTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    return Row(
      children: [
        Image.asset(
          AppColors.isLight ? WellinLogo.assetBlack : WellinLogo.assetWhite,
          height: 26,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        SizedBox(width: 12),
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
