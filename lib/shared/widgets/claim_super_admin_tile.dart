import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_colors.dart';
import '../../core/theme_rebuild_scope.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/data/auth_repository.dart';
import 'app_loader.dart';
import 'design/app_confirm_dialog.dart';
import 'design/premium_card.dart';

/// Shown when the workspace has no active super admin.
class ClaimSuperAdminTile extends StatefulWidget {
  const ClaimSuperAdminTile({super.key, this.compact = false});

  final bool compact;

  @override
  State<ClaimSuperAdminTile> createState() => _ClaimSuperAdminTileState();
}

class _ClaimSuperAdminTileState extends State<ClaimSuperAdminTile> {
  bool? _available;
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    try {
      final has = await context.read<AuthRepository>().hasActiveSuperAdmin();
      if (!mounted) return;
      setState(() => _available = !has);
    } catch (e) {
      debugPrint('[ClaimSuperAdmin] check failed: $e');
      if (!mounted) return;
      // Prefer showing the option when the check itself fails and the
      // signed-in user is not already a super admin.
      final isSuper =
          context.read<AuthBloc>().state.profile?.isSuperAdmin == true;
      setState(() => _available = !isSuper);
    }
  }

  Future<void> _claim() async {
    if (_claiming) return;
    final ok = await showAppConfirmDialog(
      context,
      title: 'Become Super Admin?',
      message:
          'No Super Admin is active in this workspace. '
          'You will get full access to approve users and manage roles.',
      confirmLabel: 'Become',
      tone: AppConfirmTone.success,
      icon: Icons.admin_panel_settings_outlined,
    );
    if (!ok || !mounted) return;

    setState(() => _claiming = true);
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthBloc>();
    try {
      await context.read<AuthRepository>().claimSuperAdminIfNone();
      if (!mounted) return;
      auth.add(const AuthRefreshProfile());
      messenger.showSnackBar(
        const SnackBar(content: Text('You are now a Super Admin')),
      );
      setState(() {
        _available = false;
        _claiming = false;
      });
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not claim Super Admin: $e')),
      );
      setState(() => _claiming = false);
      await _check();
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    if (_available == null) {
      return widget.compact
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: AppLoader.inline(size: 20)),
            )
          : const SizedBox.shrink();
    }
    if (_available != true) return const SizedBox.shrink();

    if (widget.compact) {
      return FilledButton.icon(
        onPressed: _claiming ? null : _claim,
        icon: _claiming
            ? const AppLoader.inline(size: 16)
            : const Icon(Icons.admin_panel_settings_outlined),
        label: Text(_claiming ? 'Claiming…' : 'Become Super Admin'),
      );
    }

    return PremiumCard(
      onTap: _claiming ? null : _claim,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _claiming
                ? const Center(child: AppLoader.inline(size: 20))
                : Icon(
                    Icons.admin_panel_settings_outlined,
                    color: AppColors.accent,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Become Super Admin',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'No Super Admin is active — claim workspace control',
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
