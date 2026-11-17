import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/wellin_logo.dart';
import '../bloc/auth_bloc.dart';

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _name = TextEditingController();
  UserRole _role = UserRole.admin;
  var _prefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    final user = context.read<AuthBloc>().state.user;
    final metaName = user?.userMetadata?['full_name'] as String? ??
        user?.userMetadata?['name'] as String?;
    final fallback = user?.email?.split('@').first;
    final seed = (metaName?.trim().isNotEmpty == true) ? metaName!.trim() : fallback;
    if (seed != null && seed.isNotEmpty && _name.text.isEmpty) {
      _name.text = seed;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    return Scaffold(
      appBar: AppBar(title: WellinAppBarTitle(title: 'Complete profile')),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: WellinLogo(height: 72, showWordmark: false)),
            SizedBox(height: 16),
            Text(
              'Choose your display name and role to finish setup.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 16),
            SegmentedButton<UserRole>(
              segments: const [
                ButtonSegment(value: UserRole.admin, label: Text('Admin')),
                ButtonSegment(
                  value: UserRole.superAdmin,
                  label: Text('Super Admin'),
                ),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                if (_name.text.trim().length < 2) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter your name')),
                  );
                  return;
                }
                context.read<AuthBloc>().add(
                      AuthCompleteProfileRequested(
                        name: _name.text.trim(),
                        role: _role,
                      ),
                    );
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
