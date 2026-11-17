import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';
import '../../../shared/widgets/design/app_confirm_dialog.dart';
import '../../../shared/widgets/wellin_logo.dart';
import '../bloc/auth_bloc.dart';

class PendingPage extends StatelessWidget {
  const PendingPage({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    final profile = context.watch<AuthBloc>().state.profile;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Spacer(),
              WellinLogo(height: 72, showWordmark: false),
              SizedBox(height: 24),
              Icon(Icons.hourglass_top, size: 56, color: AppColors.warning),
              SizedBox(height: 16),
              Text(
                profile?.status.name == 'disabled'
                    ? 'Account disabled'
                    : 'Waiting for approval',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                profile?.status.name == 'disabled'
                    ? 'Contact a Super Admin to reactivate your account.'
                    : 'Your Super Admin request is pending. A Super Admin will approve it.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () =>
                    context.read<AuthBloc>().add(const AuthRefreshProfile()),
                child: const Text('Refresh status'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  final ok = await showAppConfirmDialog(
                    context,
                    title: 'Sign Out?',
                    message:
                        'You’ll need to sign in again to check your approval status.',
                    confirmLabel: 'Sign Out',
                    tone: AppConfirmTone.danger,
                    icon: Icons.logout_rounded,
                  );
                  if (!context.mounted || !ok) return;
                  context
                      .read<AuthBloc>()
                      .add(const AuthLogoutRequested());
                },
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
