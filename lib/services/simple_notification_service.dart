import 'package:flutter/material.dart';

class SimpleNotificationService {
  static final SimpleNotificationService _instance = SimpleNotificationService._internal();
  factory SimpleNotificationService() => _instance;

  SimpleNotificationService._internal();

  final List<NotificationItem> _notifications = [];
  final List<NotificationCallback> _listeners = [];

  void addListener(NotificationCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(NotificationCallback listener) {
    _listeners.remove(listener);
  }

  List<NotificationItem> getNotifications() {
    return List.from(_notifications);
  }

  void clearNotifications() {
    _notifications.clear();
    _notifyListeners();
  }

  void showHealthAlert({
    required String title,
    required String body,
    String? payload,
    bool critical = false,
  }) {
    final notification = NotificationItem(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: body,
      timestamp: DateTime.now(),
      type: critical ? NotificationType.critical : NotificationType.info,
      payload: payload,
    );

    _notifications.insert(0, notification);
    _notifyListeners();

    // Show in-app notification
    _showInAppNotification(notification);
  }

  void showAnalysisComplete({
    required String diagnosis,
    required double confidence,
    String? recommendations,
  }) {
    final title = 'Analysis Complete';
    final body = 'Diagnosis: $diagnosis (${(confidence * 100).toStringAsFixed(1)}% confidence)';

    showHealthAlert(
      title: title,
      body: body,
      payload: 'analysis_complete',
    );
  }

  void showAbnormalResult({
    required String diagnosis,
    required double confidence,
    required String severity,
  }) {
    final title = '⚠️ Abnormal Result Detected';
    final body = '$diagnosis detected with ${(confidence * 100).toStringAsFixed(1)}% confidence. $severity';

    showHealthAlert(
      title: title,
      body: body,
      critical: true,
    );
  }

  void showImprovementNotification({
    required String message,
    required double improvement,
  }) {
    final title = '🎉 Health Improvement';
    final body = '$message (+${(improvement * 100).toStringAsFixed(1)}% improvement)';

    showHealthAlert(
      title: title,
      body: body,
    );
  }

  void showWeeklySummary({
    required int totalAnalyses,
    required double averageConfidence,
    required String trend,
  }) {
    final title = '📊 Weekly Health Summary';
    final body = '$totalAnalyses analyses completed. Average confidence: ${(averageConfidence * 100).toStringAsFixed(1)}%. Trend: $trend';

    showHealthAlert(
      title: title,
      body: body,
    );
  }

  void _showInAppNotification(NotificationItem notification) {
    // This would typically show a snackbar or overlay
    // For now, we'll just print to console
    print('🔔 Notification: ${notification.title} - ${notification.body}');
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener(_notifications);
    }
  }

  void markAsRead(int id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _notifyListeners();
    }
  }

  void removeNotification(int id) {
    _notifications.removeWhere((n) => n.id == id);
    _notifyListeners();
  }

  int getUnreadCount() {
    return _notifications.where((n) => !n.isRead).length;
  }
}

typedef NotificationCallback = void Function(List<NotificationItem> notifications);

enum NotificationType {
  info,
  warning,
  critical,
  success,
}

class NotificationItem {
  final int id;
  final String title;
  final String body;
  final DateTime timestamp;
  final NotificationType type;
  final String? payload;
  final bool isRead;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.type,
    this.payload,
    this.isRead = false,
  });

  NotificationItem copyWith({
    int? id,
    String? title,
    String? body,
    DateTime? timestamp,
    NotificationType? type,
    String? payload,
    bool? isRead,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      isRead: isRead ?? this.isRead,
    );
  }

  Color getColor() {
    switch (type) {
      case NotificationType.critical:
        return Colors.red;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.success:
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  IconData getIcon() {
    switch (type) {
      case NotificationType.critical:
        return Icons.error;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.success:
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }
}
