import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/wellin_logo.dart';
import '../bloc/auth_bloc.dart';
import 'google_gis_button.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.admin;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    return Scaffold(
      appBar: AppBar(title: const WellinAppBarTitle(title: 'Create account')),
      body: SafeArea(
        child: BlocConsumer<AuthBloc, AuthBlocState>(
          listener: (context, state) {
            if (state.status == AuthStatus.failure &&
                state.errorMessage != null) {
              debugPrint('[RegisterPage] error: ${state.errorMessage}');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  duration: const Duration(seconds: 8),
                ),
              );
            }
          },
          builder: (context, state) {
            final loading = state.status == AuthStatus.loading;
            return SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: WellinLogo(height: 72, showWordmark: false),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Register with email or Google, then choose your role.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (v) =>
                          v != null && v.trim().length >= 2 ? null : 'Enter your name',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) =>
                          v != null && v.contains('@') ? null : 'Enter a valid email',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          v != null && v.length >= 6 ? null : 'Min 6 characters',
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Role',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<UserRole>(
                      segments: const [
                        ButtonSegment(
                          value: UserRole.admin,
                          label: Text('Admin'),
                          icon: Icon(Icons.person_outline),
                        ),
                        ButtonSegment(
                          value: UserRole.superAdmin,
                          label: Text('Super Admin'),
                          icon: Icon(Icons.shield_outlined),
                        ),
                      ],
                      selected: {_role},
                      onSelectionChanged: (s) => setState(() => _role = s.first),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _role == UserRole.superAdmin
                          ? 'If a Super Admin already exists, your account will wait for approval.'
                          : 'Admin accounts are active immediately.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: loading
                          ? null
                          : () {
                              if (!_formKey.currentState!.validate()) return;
                              context.read<AuthBloc>().add(
                                    AuthRegisterRequested(
                                      name: _name.text.trim(),
                                      email: _email.text.trim(),
                                      password: _password.text,
                                      role: _role,
                                    ),
                                  );
                            },
                      child: loading
                          ? AppLoader.inline(
                              size: 22,
                              color: AppColors.fabIcon,
                            )
                          : const Text('Create account'),
                    ),
                    const SizedBox(height: 12),
                    if (kIsWeb)
                      IgnorePointer(
                        ignoring: loading,
                        child: Opacity(
                          opacity: loading ? 0.5 : 1,
                          child: googleGisSignInButton(),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: loading
                            ? null
                            : () => context
                                .read<AuthBloc>()
                                .add(const AuthGoogleRequested()),
                        icon: const Icon(Icons.g_mobiledata, size: 28),
                        label: const Text('Continue With Google'),
                      ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Already have an account? Sign in'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
