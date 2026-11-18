import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/wellin_logo.dart';
import '../bloc/auth_bloc.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<AuthBloc, AuthBlocState>(
          listener: (context, state) {
            if (state.status == AuthStatus.failure &&
                state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.errorMessage!)),
              );
            }
            if (state.status == AuthStatus.passwordRecovery &&
                state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.errorMessage!)),
              );
            }
            if (state.status == AuthStatus.authenticated) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password updated')),
              );
              context.go('/home');
            }
          },
          builder: (context, state) {
            final loading = state.status == AuthStatus.loading;
            final canReset = state.status == AuthStatus.passwordRecovery ||
                state.status == AuthStatus.loading ||
                state.user != null;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const WellinLogo(height: 96),
                        const SizedBox(height: 16),
                        Text(
                          'Set a new password',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          canReset
                              ? 'Choose a password for email sign-in.'
                              : 'Open the reset link from your email to continue.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 28),
                        if (canReset) ...[
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'New password',
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (v) => v != null && v.length >= 6
                                ? null
                                : 'Min 6 characters',
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirm,
                            obscureText: _obscure,
                            decoration: const InputDecoration(
                              labelText: 'Confirm password',
                            ),
                            validator: (v) =>
                                v == _password.text ? null : 'Passwords must match',
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: loading
                                ? null
                                : () {
                                    if (!_formKey.currentState!.validate()) {
                                      return;
                                    }
                                    context.read<AuthBloc>().add(
                                          AuthPasswordUpdateRequested(
                                            password: _password.text,
                                          ),
                                        );
                                  },
                            child: loading
                                ? AppLoader.inline(
                                    size: 22,
                                    color: AppColors.fabIcon,
                                  )
                                : const Text('Update password'),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Back to sign in'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
