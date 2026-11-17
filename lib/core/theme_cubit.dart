import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_colors.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit({FlutterSecureStorage? storage})
      : _storage = storage ?? FlutterSecureStorage(),
        super(ThemeMode.light) {
    AppColors.setLight(true);
    _load();
  }

  final FlutterSecureStorage _storage;
  static const _key = 'theme_mode';

  Future<void> _load() async {
    final raw = await _storage.read(key: _key);
    if (raw == 'dark') {
      await setDark();
    } else {
      await setLight();
    }
  }

  Future<void> setLight() async {
    AppColors.setLight(true);
    await _storage.write(key: _key, value: 'light');
    emit(ThemeMode.light);
  }

  Future<void> setDark() async {
    AppColors.setLight(false);
    await _storage.write(key: _key, value: 'dark');
    emit(ThemeMode.dark);
  }

  Future<void> toggle() async {
    if (state == ThemeMode.light) {
      await setDark();
    } else {
      await setLight();
    }
  }

  bool get isLight => state == ThemeMode.light;
}
