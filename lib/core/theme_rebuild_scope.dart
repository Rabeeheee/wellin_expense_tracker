import 'package:flutter/material.dart';

/// Inherited scope so any `AppColors` consumer can depend on theme and rebuild.
class ThemeRebuildScope extends InheritedWidget {
  const ThemeRebuildScope({
    super.key,
    required this.mode,
    required this.isLight,
    required super.child,
  });

  final ThemeMode mode;
  final bool isLight;

  static ThemeRebuildScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ThemeRebuildScope>();
    assert(scope != null, 'ThemeRebuildScope missing');
    return scope!;
  }

  /// Call at the top of build() when reading [AppColors] static getters.
  static void depend(BuildContext context) {
    of(context);
  }

  @override
  bool updateShouldNotify(ThemeRebuildScope oldWidget) {
    return mode != oldWidget.mode || isLight != oldWidget.isLight;
  }
}
