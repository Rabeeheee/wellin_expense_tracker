import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';
import '../../../core/theme_cubit.dart';
import '../../../core/theme_reveal.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/claim_super_admin_tile.dart';
import '../../../shared/widgets/design/app_confirm_dialog.dart';
import '../../../shared/widgets/design/premium_card.dart';
import '../../../shared/widgets/profile_avatar.dart';
import '../../../shared/widgets/wellin_logo.dart';
import '../bloc/auth_bloc.dart';
import '../data/auth_repository.dart';

class MorePage extends StatefulWidget {
  const MorePage({super.key});

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  bool _uploading = false;

  Future<void> _pickAvatar() async {
    final profile = context.read<AuthBloc>().state.profile;
    if (profile == null || _uploading) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    setState(() => _uploading = true);
    final repo = context.read<AuthRepository>();
    final authBloc = context.read<AuthBloc>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await file.readAsBytes();
      final mime = file.mimeType ?? 'image/jpeg';
      await repo.uploadAvatar(
        userId: profile.id,
        bytes: bytes,
        contentType: mime,
      );
      if (!mounted) return;
      authBloc.add(const AuthRefreshProfile());
      messenger.showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update photo: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    context.watch<ThemeCubit>();
    final profile = context.watch<AuthBloc>().state.profile;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            const Center(child: WellinLogo(height: 56, showWordmark: false)),
            const SizedBox(height: 20),
            PremiumCard(
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      ProfileAvatar(
                        profile: profile,
                        size: 64,
                        onTap: _uploading ? null : _pickAvatar,
                      ),
                      if (_uploading)
                        const SizedBox(
                          width: 64,
                          height: 64,
                          child: Center(child: AppLoader.inline(size: 28)),
                        ),
                    ],
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.name ?? 'User',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          profile?.email ?? '',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          profile?.role.label ?? '',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextButton(
                          onPressed: _uploading ? null : _pickAvatar,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: AppColors.textSecondary,
                          ),
                          child: Text(
                            profile?.avatarUrl == null
                                ? 'Add profile photo'
                                : 'Change photo',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _MoreTile(
              icon: Icons.handshake_outlined,
              title: 'Clients',
              subtitle: 'Client Details And Contacts',
              onTap: () => context.push('/clients'),
            ),
            const SizedBox(height: 10),
            _MoreTile(
              icon: Icons.work_outline_rounded,
              title: 'Projects',
              subtitle: 'Active, Upcoming, And Payments',
              onTap: () => context.push('/projects'),
            ),
            const SizedBox(height: 10),
            _MoreTile(
              icon: Icons.badge_outlined,
              title: 'Employee Entries',
              subtitle: 'Transport, Petrol, And Reimbursements',
              onTap: () => context.push('/employee-expenses'),
            ),
            const SizedBox(height: 10),
            _MoreTile(
              icon: Icons.notifications_outlined,
              title: 'Reminders',
              subtitle: 'Bills And Due Dates',
              onTap: () => context.push('/reminders'),
            ),
            SizedBox(height: 10),
            _MoreTile(
              icon: Icons.lock_outline,
              title: 'Security',
              subtitle: 'Biometric And App PIN',
              onTap: () => context.push('/security'),
            ),
            SizedBox(height: 10),
            _AppearanceTile(
              isLight: AppColors.isLight,
              onToggle: (globalCenter) async {
                final reveal = ThemeRevealScope.of(context);
                final theme = context.read<ThemeCubit>();
                await reveal.revealFrom(
                  globalCenter: globalCenter,
                  switchTheme: theme.toggle,
                );
              },
            ),
            if (profile?.isSuperAdmin == true) ...[
              const SizedBox(height: 10),
              _MoreTile(
                icon: Icons.group_outlined,
                title: 'Manage Users',
                subtitle: 'Approve And Assign Roles',
                onTap: () => context.push('/users'),
              ),
            ] else ...[
              const SizedBox(height: 10),
              const ClaimSuperAdminTile(),
            ],
            const SizedBox(height: 24),
            PremiumCard(
              onTap: () async {
                final ok = await showAppConfirmDialog(
                  context,
                  title: 'Sign Out?',
                  message:
                      'You’ll need to sign in again to access this workspace.',
                  confirmLabel: 'Sign Out',
                  tone: AppConfirmTone.danger,
                  icon: Icons.logout_rounded,
                );
                if (!context.mounted || !ok) return;
                context.read<AuthBloc>().add(const AuthLogoutRequested());
              },
              child: Row(
                children: [
                  Icon(Icons.logout, color: AppColors.expense),
                  SizedBox(width: 12),
                  Text(
                    'Sign Out',
                    style: TextStyle(
                      color: AppColors.expense,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppearanceTile extends StatelessWidget {
  const _AppearanceTile({
    required this.isLight,
    required this.onToggle,
  });

  final bool isLight;
  final Future<void> Function(Offset globalCenter) onToggle;

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTapDown: (details) {
            // Fire reveal from the exact finger point.
            onToggle(details.globalPosition);
          },
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isLight
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appearance',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isLight ? 'Light Premium' : 'Dark Premium',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.contrast_rounded, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.textPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
