import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SecureLockService {
  SecureLockService({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _localAuth = localAuth ?? LocalAuthentication();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  static const _pinKey = 'app_pin_hash';
  static const _biometricKey = 'biometric_enabled';
  static const _pinEnabledKey = 'pin_enabled';
  static const _failCountKey = 'pin_fail_count';
  static const maxPinAttempts = 5;

  Future<bool> get isPinEnabled async =>
      (await _storage.read(key: _pinEnabledKey)) == 'true';

  Future<bool> get isBiometricEnabled async =>
      (await _storage.read(key: _biometricKey)) == 'true';

  Future<bool> get isLockEnabled async =>
      await isPinEnabled || await isBiometricEnabled;

  Future<bool> canCheckBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) return false;
      final can = await _localAuth.canCheckBiometrics;
      final enrolled = await _localAuth.getAvailableBiometrics();
      // Some OEMs report empty enrolled lists even with a working fingerprint.
      return can || enrolled.isNotEmpty;
    } catch (e) {
      debugPrint('[SecureLock] canCheckBiometrics: $e');
      return false;
    }
  }

  Future<void> setPin(String pin) async {
    final hash = _hash(pin);
    await _storage.write(key: _pinKey, value: hash);
    await _storage.write(key: _pinEnabledKey, value: 'true');
    await _storage.write(key: _failCountKey, value: '0');
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _pinKey);
    await _storage.write(key: _pinEnabledKey, value: 'false');
    await _storage.write(key: _failCountKey, value: '0');
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricKey, value: enabled ? 'true' : 'false');
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _pinKey);
    if (stored == null) return false;
    final ok = stored == _hash(pin);
    if (ok) {
      await _storage.write(key: _failCountKey, value: '0');
      return true;
    }
    final fails =
        int.tryParse(await _storage.read(key: _failCountKey) ?? '0') ?? 0;
    await _storage.write(key: _failCountKey, value: '${fails + 1}');
    return false;
  }

  Future<int> failCount() async =>
      int.tryParse(await _storage.read(key: _failCountKey) ?? '0') ?? 0;

  /// Returns null on success, or an error message on failure / cancel.
  Future<String?> authenticateBiometric({
    String reason = 'Unlock Expense Tracker',
  }) async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return ok ? null : 'Biometric unlock was cancelled';
    } catch (e) {
      debugPrint('[SecureLock] authenticateBiometric: $e');
      final msg = e.toString();
      if (msg.contains('NotAvailable') || msg.contains('not_available')) {
        return 'Biometrics are not available on this device';
      }
      if (msg.contains('NotEnrolled') || msg.contains('not_enrolled')) {
        return 'No fingerprint or Face ID enrolled. Add one in system settings.';
      }
      if (msg.contains('FragmentActivity') || msg.contains('notFragmentActivity')) {
        return 'App update required for biometric unlock. Please reinstall.';
      }
      if (msg.contains('LockedOut') || msg.contains('PermanentlyLockedOut')) {
        return 'Biometrics locked. Unlock your phone with PIN/pattern first.';
      }
      return 'Biometric unlock failed. Try again.';
    }
  }

  Future<void> clearAllLockSettings() async {
    await _storage.delete(key: _pinKey);
    await _storage.delete(key: _biometricKey);
    await _storage.delete(key: _pinEnabledKey);
    await _storage.delete(key: _failCountKey);
  }

  String _hash(String pin) => sha256.convert(utf8.encode(pin)).toString();
}
