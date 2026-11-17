import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';
import '../../../core/secure_lock_service.dart';
import '../../../shared/widgets/design/app_confirm_dialog.dart';
import '../../../shared/widgets/wellin_logo.dart';
import '../bloc/auth_bloc.dart';

class UnlockPage extends StatefulWidget {
  const UnlockPage({super.key});

  @override
  State<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends State<UnlockPage> {
  final _pin = TextEditingController();
  final _pinFocus = FocusNode();
  bool _usePin = false;
  bool _pinEnabled = false;
  bool _biometricEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _pin.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final lock = context.read<SecureLockService>();
    final pin = await lock.isPinEnabled;
    final bio = await lock.isBiometricEnabled;
    if (!mounted) return;
    setState(() {
      _pinEnabled = pin;
      _biometricEnabled = bio;
      _usePin = !bio && pin;
    });
    // Cold start already prompted in AuthBloc; only auto-prompt when
    // returning from background (user landed here after lock).
    if (bio) {
      await _tryBiometric();
    } else if (pin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pinFocus.requestFocus();
      });
    }
  }

  Future<void> _tryBiometric() async {
    final lock = context.read<SecureLockService>();
    if (!await lock.isBiometricEnabled) {
      if (_pinEnabled) {
        setState(() => _usePin = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _pinFocus.requestFocus();
        });
      }
      return;
    }
    final error = await lock.authenticateBiometric();
    if (!mounted) return;
    if (error == null) {
      context.read<AuthBloc>().add(const AuthUnlocked());
      return;
    }
    setState(() {
      _error = error;
      if (_pinEnabled) _usePin = true;
    });
    if (_pinEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pinFocus.requestFocus();
      });
    }
  }

  Future<void> _submitPin() async {
    if (_pin.text.length < 4) return;
    final lock = context.read<SecureLockService>();
    final ok = await lock.verifyPin(_pin.text);
    if (!mounted) return;
    if (ok) {
      context.read<AuthBloc>().add(const AuthUnlocked());
      return;
    }
    final fails = await lock.failCount();
    if (!mounted) return;
    if (fails >= SecureLockService.maxPinAttempts) {
      context.read<AuthBloc>().add(const AuthLogoutRequested(clearLock: true));
      return;
    }
    setState(() {
      _error =
          'Incorrect PIN · ${SecureLockService.maxPinAttempts - fails} left';
      _pin.clear();
    });
    _pinFocus.requestFocus();
  }

  void _onPinChanged(String value) {
    setState(() => _error = null);
    if (value.length == 6) {
      _submitPin();
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: keyboardOpen
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () async {
                          final ok = await showAppConfirmDialog(
                            context,
                            title: 'Sign Out?',
                            message:
                                'You’ll need to sign in again on this device.',
                            confirmLabel: 'Sign Out',
                            tone: AppConfirmTone.danger,
                            icon: Icons.logout_rounded,
                          );
                          if (!context.mounted || !ok) return;
                          context
                              .read<AuthBloc>()
                              .add(const AuthLogoutRequested());
                        },
                        child: Text('Sign Out'),
                      ),
                    ),
                    SizedBox(height: keyboardOpen ? 4 : 12),
                      Center(
                        child: WellinLogo(height: 56, showWordmark: false),
                      ),
                    SizedBox(height: keyboardOpen ? 14 : 28),
                    Center(
                      child: Container(
                        width: keyboardOpen ? 52 : 68,
                        height: keyboardOpen ? 52 : 68,
                        decoration: BoxDecoration(
                          color: AppColors.primaryMuted,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          _usePin
                              ? Icons.lock_rounded
                              : Icons.fingerprint_rounded,
                          size: keyboardOpen ? 26 : 34,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    SizedBox(height: keyboardOpen ? 12 : 20),
                    Text(
                      _usePin ? 'Enter PIN' : 'Unlock',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: keyboardOpen ? 20 : 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      _usePin
                          ? 'Enter your 4–6 digit app PIN'
                          : 'Confirm it’s you to continue',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: keyboardOpen ? 18 : 28),
                    if (!_usePin)
                      FilledButton.icon(
                        onPressed: _tryBiometric,
                        icon: Icon(Icons.fingerprint_rounded, size: 22),
                        label: Text('Unlock With Biometrics'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.fabIcon,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      )
                    else ...[
                      GestureDetector(
                        onTap: () => _pinFocus.requestFocus(),
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          children: [
                            _PinSlots(
                              length: _pin.text.length,
                              maxLength: 6,
                              hasError: _error != null,
                            ),
                            SizedBox(
                              width: 1,
                              height: 1,
                              child: Opacity(
                                opacity: 0,
                                child: TextField(
                                  controller: _pin,
                                  focusNode: _pinFocus,
                                  autofocus: true,
                                  obscureText: true,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    counterText: '',
                                    border: InputBorder.none,
                                  ),
                                  onChanged: _onPinChanged,
                                  onSubmitted: (_) => _submitPin(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_error != null) ...[
                        SizedBox(height: 10),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.expense,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      SizedBox(height: 18),
                      FilledButton(
                        onPressed:
                            _pin.text.length >= 4 ? _submitPin : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.fabIcon,
                          disabledBackgroundColor: AppColors.border,
                          disabledForegroundColor: AppColors.textTertiary,
                          minimumSize: Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text('Unlock'),
                      ),
                    ],
                    if (_error != null && !_usePin) ...[
                      SizedBox(height: 10),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.expense,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (_biometricEnabled && _pinEnabled)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _usePin = !_usePin;
                            _error = null;
                            _pin.clear();
                          });
                          if (_usePin) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) _pinFocus.requestFocus();
                            });
                          } else {
                            _tryBiometric();
                          }
                        },
                        child: Text(
                          _usePin
                              ? 'Use Biometrics Instead'
                              : 'Use PIN Instead',
                        ),
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

class _PinSlots extends StatelessWidget {
  const _PinSlots({
    required this.length,
    required this.maxLength,
    required this.hasError,
  });

  final int length;
  final int maxLength;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(maxLength, (i) {
        final filled = i < length;
        final active = i == length;
        final borderColor = hasError
            ? AppColors.expense
            : filled || active
                ? AppColors.primary
                : AppColors.border;
        return AnimatedContainer(
          duration: Duration(milliseconds: 140),
          margin: EdgeInsets.symmetric(horizontal: 5),
          width: 40,
          height: 48,
          decoration: BoxDecoration(
            color: filled ? AppColors.primaryMuted : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: active || hasError ? 2 : 1.5,
            ),
          ),
          child: Center(
            child: filled
                ? Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasError ? AppColors.expense : AppColors.primary,
                    ),
                  )
                : null,
          ),
        );
      }),
    );
  }
}
