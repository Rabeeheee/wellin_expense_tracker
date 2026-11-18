import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';
import '../../../core/secure_lock_service.dart';
import '../../../shared/widgets/wellin_logo.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  bool _pinEnabled = false;
  bool _biometricEnabled = false;
  bool _canBiometric = false;
  final _pin = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lock = context.read<SecureLockService>();
    final pin = await lock.isPinEnabled;
    final bio = await lock.isBiometricEnabled;
    final can = await lock.canCheckBiometrics();
    if (!mounted) return;
    setState(() {
      _pinEnabled = pin;
      _biometricEnabled = bio;
      _canBiometric = can;
    });
  }

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _savePin() async {
    if (_pin.text.length < 4 || _pin.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN must be 4–6 digits and match')),
      );
      return;
    }
    await context.read<SecureLockService>().setPin(_pin.text);
    _pin.clear();
    _confirm.clear();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('App PIN enabled')),
    );
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    final lock = context.read<SecureLockService>();

    return Scaffold(
      appBar: AppBar(title: WellinAppBarTitle(title: 'Security')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Text(
            'Protect the app on this device after you sign in.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          SizedBox(height: 16),
          Card(
            elevation: 0,
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.border),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              secondary: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.fingerprint_rounded,
                  color: AppColors.primary,
                ),
              ),
              title: const Text('Biometric Unlock'),
              subtitle: Text(
                _canBiometric
                    ? 'Fingerprint or Face ID'
                    : 'Not available here (use PIN on web)',
              ),
              value: _biometricEnabled,
              onChanged: !_canBiometric
                  ? null
                  : (v) async {
                      final messenger = ScaffoldMessenger.of(context);
                      if (v) {
                        final error = await lock.authenticateBiometric(
                          reason: 'Enable biometric unlock',
                        );
                        if (!mounted) return;
                        if (error != null) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(error)),
                          );
                          return;
                        }
                      }
                      await lock.setBiometricEnabled(v);
                      await _load();
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            v
                                ? 'Biometric unlock enabled'
                                : 'Biometric unlock turned off',
                          ),
                        ),
                      );
                    },
            ),
          ),
          SizedBox(height: 12),
          Card(
            elevation: 0,
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.border),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  secondary: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryMuted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  title: const Text('App PIN'),
                  subtitle: const Text('4–6 digit PIN for this device'),
                  value: _pinEnabled,
                  onChanged: (v) async {
                    if (!v) {
                      await lock.clearPin();
                      await _load();
                    } else {
                      setState(() => _pinEnabled = true);
                    }
                  },
                ),
                if (_pinEnabled) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _pin,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'New PIN',
                            prefixIcon: Icon(Icons.lock_outline),
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirm,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: 'Confirm PIN',
                            prefixIcon: Icon(Icons.lock_outline),
                            counterText: '',
                          ),
                        ),
                        SizedBox(height: 12),
                        FilledButton(
                          onPressed: _savePin,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.fabIcon,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Save PIN'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
