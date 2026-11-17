import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/theme_rebuild_scope.dart';
import '../models/profile.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    this.profile,
    this.name,
    this.avatarUrl,
    this.size = 48,
    this.onTap,
  });

  final Profile? profile;
  final String? name;
  final String? avatarUrl;
  final double size;
  final VoidCallback? onTap;

  String get _label => (profile?.name ?? name ?? '?').trim();

  String? get _url => profile?.avatarUrl ?? avatarUrl;

  String get _initials {
    final parts = _label.split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    if (parts.isEmpty) return '?';
    final list = parts.toList();
    if (list.length == 1) return list.first.substring(0, 1).toUpperCase();
    return (list[0].substring(0, 1) + list[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    final url = _url;
    final child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryMuted,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 1.5),
        image: url != null && url.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(url),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: url == null || url.isEmpty
          ? Text(
              _initials,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.34,
              ),
            )
          : null,
    );

    if (onTap == null) return child;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: size * 0.36,
              height: size * 0.36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 2),
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                size: size * 0.2,
                color: AppColors.fabIcon,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
