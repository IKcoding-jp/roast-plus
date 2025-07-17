import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class RoastTimerNotificationService {
  static Future<void> initialize() async {}
  static void _onNotificationTapped(NotificationResponse response) {}
  static Future<void> scheduleRoastTimerNotification({
    required int id,
    required Duration duration,
    required String title,
    required String body,
  }) async {}
  static Future<void> cancelRoastTimerNotification(int id) async {}
  static Future<void> cancelAllRoastTimerNotifications() async {}
  static Future<bool> requestPermissions() async => true;
  static Future<bool> areNotificationsEnabled() async => false;
}
