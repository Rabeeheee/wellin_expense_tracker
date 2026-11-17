import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/core/app_colors.dart';

void main() {
  test('AppColors primary is teal', () {
    expect(AppColors.primary, const Color(0xFF0F6E56));
  });
}
