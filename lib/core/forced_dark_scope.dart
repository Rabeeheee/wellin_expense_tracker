import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_theme.dart';
import 'theme_rebuild_scope.dart';

/// Forces [AppColors] + [Theme] into dark for this subtree, then restores.
class ForcedDarkScope extends StatefulWidget {
  const ForcedDarkScope({super.key, required this.child});

  final Widget child;

  @override
  State<ForcedDarkScope> createState() => _ForcedDarkScopeState();
}

class _ForcedDarkScopeState extends State<ForcedDarkScope> {
  late final bool _restoreLight;

  @override
  void initState() {
    super.initState();
    _restoreLight = AppColors.isLight;
    AppColors.setLight(false);
  }

  @override
  void dispose() {
    AppColors.setLight(_restoreLight);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.setLight(false);
    final theme = AppTheme.dark;
    return ThemeRebuildScope(
      mode: ThemeMode.dark,
      isLight: false,
      child: Theme(
        data: theme,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: AppColors.background,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
