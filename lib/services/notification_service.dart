import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart' show TimeOfDay;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  late FlutterLocalNotificationsPlugin _notifications;

  NotificationService._internal() {
    _notifications = FlutterLocalNotificationsPlugin();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
        print('Notification tapped: ${details.payload}');
      },
    );

    // Initialize timezone
    tz.initializeTimeZones();
  }

  Future<void> requestPermissions() async {
    // Android: Permissions are usually granted at install time. For Android 13+, consider using the permission_handler package if you need to request notification permission.

    // iOS: Explicitly request permissions.
    await _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // macOS: If you support macOS, request permissions similarly.
    await _notifications
        .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  Future<void> showHealthAlert({
    required String title,
    required String body,
    String? payload,
    bool critical = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'health_alerts',
      'Health Alerts',
      channelDescription: 'Notifications for health analysis results',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      // Remove largeIcon or use BitmapFilePathAndroidBitmap if you have a file path
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> showAnalysisComplete({
    required String diagnosis,
    required double confidence,
    String? recommendations,
  }) async {
    final title = 'Analysis Complete';
    final body = 'Diagnosis: $diagnosis (${(confidence * 100).toStringAsFixed(1)}% confidence)';

    await showHealthAlert(
      title: title,
      body: body,
      payload: 'analysis_complete',
    );
  }

  Future<void> showAbnormalResult({
    required String diagnosis,
    required double confidence,
    required String severity,
  }) async {
    final title = '⚠️ Abnormal Result Detected';
    final body = '$diagnosis detected with ${(confidence * 100).toStringAsFixed(1)}% confidence. $severity';

    await showHealthAlert(
      title: title,
      body: body,
      critical: true,
    );
  }

  Future<void> showImprovementNotification({
    required String message,
    required double improvement,
  }) async {
    final title = '🎉 Health Improvement';
    final body = '$message (+${(improvement * 100).toStringAsFixed(1)}% improvement)';

    await showHealthAlert(
      title: title,
      body: body,
    );
  }

  Future<void> showWeeklySummary({
    required int totalAnalyses,
    required double averageConfidence,
    required String trend,
  }) async {
    final title = '📊 Weekly Health Summary';
    final body = '$totalAnalyses analyses completed. Average confidence: ${(averageConfidence * 100).toStringAsFixed(1)}%. Trend: $trend';

    await showHealthAlert(
      title: title,
      body: body,
    );
  }

  Future<void> scheduleReminder({
    required String title,
    required String body,
    required DateTime scheduledTime,
    int id = 0,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'reminders',
      'Health Reminders',
      channelDescription: 'Scheduled health check reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> scheduleDailyReminder({
    TimeOfDay time = const TimeOfDay(hour: 9, minute: 0),
  }) async {
    final now = DateTime.now();
    var scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If the time has passed today, schedule for tomorrow
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    await scheduleReminder(
      id: 100,
      title: '🫁 Daily Health Check',
      body: 'Time for your daily breath analysis. Monitor your respiratory health!',
      scheduledTime: scheduledTime,
    );
  }

  Future<void> scheduleWeeklyReport({
    TimeOfDay time = const TimeOfDay(hour: 8, minute: 0),
    int dayOfWeek = DateTime.sunday,
  }) async {
    final now = DateTime.now();
    var scheduledTime = DateTime(
      now.year,
      now.month,
      now.day + (dayOfWeek - now.weekday),
      time.hour,
      time.minute,
    );

    // If the day has passed this week, schedule for next week
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 7));
    }

    await scheduleReminder(
      id: 200,
      title: '📈 Weekly Health Report',
      body: 'Your weekly respiratory health summary is ready. Check your progress!',
      scheduledTime: scheduledTime,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
}
