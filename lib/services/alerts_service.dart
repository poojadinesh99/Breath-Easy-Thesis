import 'package:supabase_flutter/supabase_flutter.dart';

class Alert {
  final String id;
  final String? userId;
  final String alertType;
  final String title;
  final String message;
  final int severity;
  final bool isRead;
  final bool isResolved;
  final String? analysisId;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  Alert({
    required this.id,
    this.userId,
    required this.alertType,
    required this.title,
    required this.message,
    required this.severity,
    required this.isRead,
    required this.isResolved,
    this.analysisId,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      alertType: json['alert_type'] as String,
      title: json['title'] as String? ?? 'Alert',
      message: json['message'] as String? ?? '',
      severity: json['severity'] as int? ?? 1,
      isRead: json['is_read'] as bool? ?? false,
      isResolved: json['is_resolved'] as bool? ?? false,
      analysisId: json['analysis_id'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String? ?? json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'alert_type': alertType,
      'title': title,
      'message': message,
      'severity': severity,
      'is_read': isRead,
      'is_resolved': isResolved,
      'analysis_id': analysisId,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class AlertsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch all alerts for the current user
  Future<List<Alert>> getAlerts({bool? resolved}) async {
    try {
      final user = _supabase.auth.currentUser;
      
      // Build the query step by step
      var queryBuilder = _supabase
          .from('ai_alerts')
          .select('*');

      // Add user filter - if no user is authenticated, get test alerts (null user_id)
      if (user != null) {
        queryBuilder = queryBuilder.eq('user_id', user.id);
      } else {
        // For test alerts with null user_id, use isFilter
        queryBuilder = queryBuilder.isFilter('user_id', null);
      }

      // Add resolved filter if specified
      if (resolved != null) {
        queryBuilder = queryBuilder.eq('is_resolved', resolved);
      }

      // Apply ordering and execute
      final response = await queryBuilder.order('created_at', ascending: false);
      
      return response.map<Alert>((json) => Alert.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch alerts: $e');
    }
  }

  /// Get unresolved alerts count
  Future<int> getUnresolvedAlertsCount() async {
    try {
      final user = _supabase.auth.currentUser;
      
      var queryBuilder = _supabase
          .from('ai_alerts')
          .select('*');

      // Add user filter
      if (user != null) {
        queryBuilder = queryBuilder.eq('user_id', user.id);
      } else {
        queryBuilder = queryBuilder.isFilter('user_id', null);
      }

      // Add resolved filter and execute
      final response = await queryBuilder.eq('is_resolved', false);
      
      return response.length;
    } catch (e) {
      return 0;
    }
  }

  /// Mark an alert as resolved
  Future<void> markAsResolved(String alertId) async {
    try {
      await _supabase
          .from('ai_alerts')
          .update({'is_resolved': true})
          .eq('id', alertId);
    } catch (e) {
      throw Exception('Failed to mark alert as resolved: $e');
    }
  }

  /// Mark an alert as read
  Future<void> markAsRead(String alertId) async {
    try {
      await _supabase
          .from('ai_alerts')
          .update({'is_read': true})
          .eq('id', alertId);
    } catch (e) {
      throw Exception('Failed to mark alert as read: $e');
    }
  }

  /// Create a new alert (typically called by backend or analysis service)
  Future<Alert> createAlert({
    required String alertType,
    required String title,
    required String message,
    int severity = 1,
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      final finalUserId = userId ?? user?.id;

      final response = await _supabase
          .from('ai_alerts')
          .insert({
            'user_id': finalUserId,
            'alert_type': alertType,
            'title': title,
            'message': message,
            'severity': severity,
            'is_read': false,
            'is_resolved': false,
            'metadata': metadata ?? {},
          })
          .select()
          .single();

      return Alert.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create alert: $e');
    }
  }

  /// Delete an alert
  Future<void> deleteAlert(String alertId) async {
    try {
      await _supabase
          .from('ai_alerts')
          .delete()
          .eq('id', alertId);
    } catch (e) {
      throw Exception('Failed to delete alert: $e');
    }
  }

  /// Get alert icon based on type
  static String getAlertIcon(String alertType) {
    switch (alertType.toLowerCase()) {
      case 'critical':
      case 'emergency':
        return '🚨';
      case 'warning':
      case 'abnormal':
        return '⚠️';
      case 'info':
      case 'recommendation':
        return 'ℹ️';
      case 'respiratory':
      case 'breathing':
        return '🫁';
      case 'speech':
        return '🗣️';
      default:
        return '📋';
    }
  }

  /// Get alert color based on type
  static String getAlertSeverity(String alertType) {
    switch (alertType.toLowerCase()) {
      case 'critical':
      case 'emergency':
        return 'critical';
      case 'warning':
      case 'abnormal':
        return 'warning';
      case 'info':
      case 'recommendation':
        return 'info';
      default:
        return 'info';
    }
  }
}
