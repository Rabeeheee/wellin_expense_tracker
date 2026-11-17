import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';
import '../../../core/secure_lock_service.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/wellin_logo.dart';
import '../bloc/auth_bloc.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _biometricReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBiometric());
  }

  Future<void> _loadBiometric() async {
    final lock = context.read<SecureLockService>();
    final enabled = await lock.isBiometricEnabled;
    final can = await lock.canCheckBiometrics();
    if (!mounted) return;
    setState(() => _biometricReady = enabled && can);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
                SnackBar(
                  content: Text(state.errorMessage!),
                  duration: const Duration(seconds: 6),
                ),
              );
            }
          },
          builder: (context, state) {
            final loading = state.status == AuthStatus.loading;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        WellinLogo(height: 112),
                        SizedBox(height: 12),
                        Text(
                          'Track shared workspace income and expenses.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        SizedBox(height: 32),
                        if (_biometricReady) ...[
                          FilledButton.icon(
                            onPressed: loading
                                ? null
                                : () => context.read<AuthBloc>().add(
                                      AuthBiometricLoginRequested(),
                                    ),
                            icon: Icon(Icons.fingerprint_rounded),
                            label: Text('Unlock With Biometrics'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: AppColors.textPrimary,
                              minimumSize: Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'Or Sign In',
                                  style: TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration:
                              const InputDecoration(labelText: 'Email'),
                          validator: (v) => v != null && v.contains('@')
                              ? null
                              : 'Enter a valid email',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Password',
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
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: loading
                              ? null
                              : () {
                                  if (!_formKey.currentState!.validate()) {
                                    return;
                                  }
                                  context.read<AuthBloc>().add(
                                        AuthLoginRequested(
                                          email: _email.text.trim(),
                                          password: _password.text,
                                        ),
                                      );
                                },
                          child: loading
                              ? AppLoader.inline(
                                  size: 22,
                                  color: AppColors.fabIcon,
                                )
                              : const Text('Sign in'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: loading
                              ? null
                              : () => context
                                  .read<AuthBloc>()
                                  .add(const AuthGoogleRequested()),
                          icon: const Icon(Icons.g_mobiledata, size: 28),
                          label: const Text('Continue With Google'),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => context.go('/register'),
                          child: const Text('Create An Account'),
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
