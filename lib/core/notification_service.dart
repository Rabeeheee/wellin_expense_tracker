import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  static const _advanceChannelId = 'reminders_advance_v1';
  static const _dueChannelId = 'reminders_due_v3';
  static const _overdueChannelId = 'reminders_overdue_v3';

  /// How far ahead to pre-schedule 2-hour overdue nudges (refilled on app sync).
  static const _overdueHorizon = Duration(days: 2);
  static const _overdueGap = Duration(hours: 2);
  static const _advanceGap = Duration(hours: 1);

  Future<void> init() async {
    if (kIsWeb) {
      debugPrint('[Notifications] skipped on web');
      return;
    }

    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('[Notifications] timezone fallback: $e');
      tz.setLocalLocation(tz.UTC);
    }

    // Status-bar icons must be white-on-transparent silhouettes.
    const android =
        AndroidInitializationSettings('@drawable/ic_stat_notification');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );

    await _requestPermissions();
    await _ensureAndroidChannels();
    _ready = true;
  }

  Future<void> _requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  Future<void> _ensureAndroidChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _advanceChannelId,
        'Upcoming reminders',
        description: 'Alert 1 hour before a reminder is due',
        importance: Importance.defaultImportance,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('reminder_alert'),
        enableVibration: true,
      ),
    );

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _dueChannelId,
        'Reminder due',
        description: 'Fires at the reminder due time',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('reminder_alert'),
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _overdueChannelId,
        'Overdue reminders',
        description: 'Every 2 hours while a reminder stays unchecked',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('reminder_alert'),
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
  }

  int advanceNotificationId(String reminderId) =>
      (reminderId.hashCode ^ 0x0a11ace) & 0x7fffffff;

  int dueNotificationId(String reminderId) =>
      reminderId.hashCode & 0x7fffffff;

  int overdueNotificationId(String reminderId, int slot) =>
      (reminderId.hashCode ^ (0x5f3759df + slot + 1)) & 0x7fffffff;

  int get _maxOverdueSlots =>
      (_overdueHorizon.inMinutes / _overdueGap.inMinutes).ceil();

  NotificationDetails _advanceDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _advanceChannelId,
        'Upcoming reminders',
        channelDescription: 'Alert 1 hour before a reminder is due',
        icon: '@drawable/ic_stat_notification',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        category: AndroidNotificationCategory.reminder,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('reminder_alert'),
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'reminder_alert.caf',
        interruptionLevel: InterruptionLevel.active,
      ),
    );
  }

  NotificationDetails _dueDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _dueChannelId,
        'Reminder due',
        channelDescription: 'Fires at the reminder due time',
        icon: '@drawable/ic_stat_notification',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('reminder_alert'),
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'reminder_alert.caf',
        interruptionLevel: InterruptionLevel.active,
      ),
    );
  }

  NotificationDetails _overdueDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _overdueChannelId,
        'Overdue reminders',
        channelDescription: 'Every 2 hours while a reminder stays unchecked',
        icon: '@drawable/ic_stat_notification',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('reminder_alert'),
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'reminder_alert.caf',
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  /// Schedules:
  /// 1) 1 hour before due
  /// 2) at due time
  /// 3) every 2 hours after due while still open (horizon refilled on sync)
  ///
  /// Only future times — never fires a burst on app open.
  Future<void> scheduleReminder({
    required String reminderId,
    required String title,
    required DateTime dueLocal,
  }) async {
    if (!_ready) return;
    await cancelReminder(reminderId);

    final now = DateTime.now();
    final advanceAt = dueLocal.subtract(_advanceGap);

    if (advanceAt.isAfter(now)) {
      await _zonedSchedule(
        id: advanceNotificationId(reminderId),
        when: advanceAt,
        title: 'Upcoming in 1 hour',
        body: title,
        details: _advanceDetails(),
      );
    }

    if (dueLocal.isAfter(now)) {
      await _zonedSchedule(
        id: dueNotificationId(reminderId),
        when: dueLocal,
        title: 'Reminder due',
        body: title,
        details: _dueDetails(),
      );
    }

    // Overdue nudges on a 2-hour grid after due (due+2h, +4h, …).
    // Jump to the next future slot so long-overdue items still nudge.
    var overdueAt = dueLocal.add(_overdueGap);
    while (!overdueAt.isAfter(now)) {
      overdueAt = overdueAt.add(_overdueGap);
    }
    final horizonEnd = now.add(_overdueHorizon);
    for (var slot = 0;
        slot < _maxOverdueSlots && overdueAt.isBefore(horizonEnd);
        slot++) {
      await _zonedSchedule(
        id: overdueNotificationId(reminderId, slot),
        when: overdueAt,
        title: 'Still pending',
        body: '$title is overdue — please complete it',
        details: _overdueDetails(),
      );
      overdueAt = overdueAt.add(_overdueGap);
    }
  }

  Future<void> _zonedSchedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    required NotificationDetails details,
  }) async {
    final scheduled = tz.TZDateTime.from(when, tz.local);
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: scheduled,
      notificationDetails: details,
      title: title,
      body: body,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelReminder(String reminderId) async {
    if (!_ready) return;
    await _plugin.cancel(id: advanceNotificationId(reminderId));
    await _plugin.cancel(id: dueNotificationId(reminderId));
    // Legacy single overdue id from older builds.
    await _plugin.cancel(
      id: (reminderId.hashCode ^ 0x5f3759df) & 0x7fffffff,
    );
    for (var slot = 0; slot < _maxOverdueSlots; slot++) {
      await _plugin.cancel(id: overdueNotificationId(reminderId, slot));
    }
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }
}
