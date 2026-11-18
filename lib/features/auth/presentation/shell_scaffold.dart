import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';
import '../../../core/theme_cubit.dart';

class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(BuildContext context, int index, {Offset? revealOrigin}) {
    if (index == 2) {
      context.push(
        '/transactions/new',
        extra: revealOrigin,
      );
      return;
    }
    final branch = index > 2 ? index - 1 : index;
    navigationShell.goBranch(
      branch,
      initialLocation: branch == navigationShell.currentIndex,
    );
  }

  int get _selectedVisualIndex {
    final i = navigationShell.currentIndex;
    if (i >= 2) return i + 1;
    return i;
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    context.watch<ThemeCubit>();
    final selected = _selectedVisualIndex;

    return Scaffold(
      body: navigationShell,
      extendBody: true,
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          height: 72,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.navBar,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _NavItem(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home_rounded,
                      label: 'Home',
                      selected: selected == 0,
                      onTap: () => _onTap(context, 0),
                    ),
                    _NavItem(
                      icon: Icons.pie_chart_outline_rounded,
                      selectedIcon: Icons.pie_chart_rounded,
                      label: 'Analytics',
                      selected: selected == 1,
                      onTap: () => _onTap(context, 1),
                    ),
                    const SizedBox(width: 64),
                    _NavItem(
                      icon: Icons.receipt_long_outlined,
                      selectedIcon: Icons.receipt_long,
                      label: 'Entries',
                      selected: selected == 3,
                      onTap: () => _onTap(context, 3),
                    ),
                    _NavItem(
                      icon: Icons.more_horiz,
                      selectedIcon: Icons.more_horiz,
                      label: 'More',
                      selected: selected == 4,
                      onTap: () => _onTap(context, 4),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -8,
                child: _AddExpenseFab(
                  onTap: (origin) =>
                      _onTap(context, 2, revealOrigin: origin),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddExpenseFab extends StatefulWidget {
  const _AddExpenseFab({required this.onTap});

  final ValueChanged<Offset> onTap;

  @override
  State<_AddExpenseFab> createState() => _AddExpenseFabState();
}

class _AddExpenseFabState extends State<_AddExpenseFab> {
  bool _pressed = false;

  Offset _center() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      final size = MediaQuery.sizeOf(context);
      return Offset(size.width / 2, size.height - 48);
    }
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    return Semantics(
      button: true,
      label: 'Add Entry',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: () => widget.onTap(_center()),
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.fab,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              Icons.add_rounded,
              color: AppColors.fabIcon,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    final color =
        selected ? AppColors.textPrimary : AppColors.textTertiary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? selectedIcon : icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
