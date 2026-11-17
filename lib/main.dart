import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/app_config.dart';
import 'core/notification_service.dart';
import 'core/secure_lock_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConfig.isConfigured) {
    debugPrint(
      'Supabase is not configured. Pass SUPABASE_URL and SUPABASE_ANON_KEY '
      'via --dart-define. See README.md.',
    );
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  final notifications = NotificationService();
  try {
    await notifications.init();
  } catch (e, stack) {
    // Never block app launch on notification setup (release resource shrink, etc).
    debugPrint('[Notifications] init failed: $e\n$stack');
  }

  final lockService = SecureLockService();

  runApp(ExpenseTrackerApp(
    lockService: lockService,
    notificationService: notifications,
  ));
}
