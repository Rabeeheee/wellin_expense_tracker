import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';

class FilterChipsRow extends StatelessWidget {
  const FilterChipsRow({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _Chip(
              label: labels[i],
              selected: i == selectedIndex,
              onTap: () => onSelected(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.borderStrong,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: StadiumBorder(),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: selected ? AppColors.fabIcon : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
