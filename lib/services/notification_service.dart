import 'dart:ui' show Color;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/task.dart';
import 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';

/// Local notifications: instant "task added" alert + scheduled reminders.
/// Notification id scheme per task:  base = taskId*100
///   base+0 (or +weekday) = at due time, base+50(+weekday) = "before" reminder, base+99 = "task added".
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const Map<String, String> soundOptions = {
    'default': 'Default',
    'alarm': 'Alarm',
    'ringtone': 'Ringtone',
  };

  static AndroidNotificationSound? _sound(String key) {
    switch (key) {
      case 'alarm':
        return const UriAndroidNotificationSound('content://settings/system/alarm_alert');
      case 'ringtone':
        return const UriAndroidNotificationSound('content://settings/system/ringtone');
      default:
        return null; // system default notification sound
    }
  }

  static Future<void> init() async {
    if (kIsWeb) return; // browsers: in-app alerts are used instead
    tzdata.initializeTimeZones();
    _setLocalZone();
    const android = AndroidInitializationSettings('@drawable/ic_stat');
    await _plugin.initialize(const InitializationSettings(android: android));
  }

  /// Picks the timezone matching the phone's current UTC offset (Pakistan => Asia/Karachi).
  static void _setLocalZone() {
    final offMs = DateTime.now().timeZoneOffset.inMilliseconds;
    String? name;
    for (final e in tz.timeZoneDatabase.locations.entries) {
      if (e.value.currentTimeZone.offset == offMs) {
        name ??= e.key;
        if (e.key == 'Asia/Karachi') {
          name = e.key;
          break;
        }
      }
    }
    tz.setLocalLocation(tz.getLocation(name ?? 'Asia/Karachi'));
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> requestPermissions() async {
    if (kIsWeb) {
      requestWebNotifyPermission();
      return;
    }
    await _android?.requestNotificationsPermission();
    try {
      await _android?.requestExactAlarmsPermission();
    } catch (_) {}
  }

  // A channel's sound can't change after creation, so one channel per sound option.
  static NotificationDetails _details(String sound) => NotificationDetails(
        android: AndroidNotificationDetails(
          'masha_tasks_$sound',
          'Task reminders (${soundOptions[sound] ?? 'Default'})',
          channelDescription: 'Reminders for your tasks',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: _sound(sound),
          enableVibration: true,
          icon: 'ic_stat',
          color: const Color(0xFFC2397F),
        ),
      );

  static Future<void> showNow(int id, String title, String body, String sound) async {
    if (kIsWeb) {
      webNotify(title, body);
      playWebSound(sound);
      return;
    }
    await _plugin.show(id, title, body, _details(sound));
  }

  static Future<void> showAdded(Task t, String sound) =>
      showNow(t.id! * 100 + 99, '🍯 Task added!', '${t.title} — ${t.whenLabel}', sound);

  static Future<void> _zs(int id, String title, String body, tz.TZDateTime when, String sound,
      {DateTimeComponents? match}) async {
    Future<void> go(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id, title, body, when, _details(sound),
          androidScheduleMode: mode,
          matchDateTimeComponents: match,
        );
    try {
      await go(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (_) {
      await go(AndroidScheduleMode.inexactAllowWhileIdle); // exact alarm permission not granted
    }
  }

  static tz.TZDateTime _next(DateTime due, int? weekday, tz.TZDateTime now) {
    var c = tz.TZDateTime(tz.local, now.year, now.month, now.day, due.hour, due.minute);
    final start = tz.TZDateTime(tz.local, due.year, due.month, due.day, due.hour, due.minute);
    if (c.isBefore(start)) c = start;
    while (!c.isAfter(now) || (weekday != null && c.weekday != weekday)) {
      c = c.add(const Duration(days: 1));
    }
    return c;
  }

  static Future<void> schedule(Task t, String sound) async {
    if (kIsWeb || t.id == null) return;
    await cancelTask(t);
    if (!t.isRepeating && t.completed) return;
    final base = t.id! * 100;
    final now = tz.TZDateTime.now(tz.local);

    if (!t.isRepeating) {
      final at = tz.TZDateTime.from(t.dueDate, tz.local);
      if (at.isAfter(now)) await _zs(base, '⏰ Task time!', t.title, at, sound);
      if (t.reminderBefore > 0) {
        final b = at.subtract(Duration(minutes: t.reminderBefore));
        if (b.isAfter(now)) {
          await _zs(base + 50, '🔔 Reminder: ${t.reminderBefore} min left', t.title, b, sound);
        }
      }
      return;
    }

    final daily = t.repeatType == 'daily';
    final List<int?> days = daily ? [null] : t.repeatDays;
    for (final wd in days) {
      final slot = wd ?? 0;
      final match = daily ? DateTimeComponents.time : DateTimeComponents.dayOfWeekAndTime;
      final occ = _next(t.dueDate, wd, now);
      await _zs(base + slot, '⏰ Task time!', '${t.title} (${t.repeatLabel})', occ, sound, match: match);
      if (t.reminderBefore > 0) {
        var b = occ.subtract(Duration(minutes: t.reminderBefore));
        if (!b.isAfter(now)) b = b.add(Duration(days: daily ? 1 : 7));
        await _zs(base + 50 + slot, '🔔 Reminder: ${t.reminderBefore} min left', t.title, b, sound,
            match: match);
      }
    }
  }

  static Future<void> cancelTask(Task t) async {
    if (kIsWeb || t.id == null) return;
    final base = t.id! * 100;
    for (var i = 0; i <= 7; i++) {
      await _plugin.cancel(base + i);
      await _plugin.cancel(base + 50 + i);
    }
  }
}
