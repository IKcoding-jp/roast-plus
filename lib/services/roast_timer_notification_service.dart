import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class RoastTimerNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  /// 通知サービスを初期化
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // タイムゾーンデータを初期化
    tz.initializeTimeZones();

    // Android設定
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS設定
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    // 初期化設定
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    // 通知を初期化
    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
  }

  /// 通知がタップされた時の処理
  static void _onNotificationTapped(NotificationResponse response) {
    // アプリを起動する処理は、main.dartでハンドリングされます
    print('焙煎タイマー通知がタップされました: ${response.payload}');
  }

  /// 焙煎タイマー通知をスケジュール
  static Future<void> scheduleRoastTimerNotification({
    required int id,
    required Duration duration,
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // 通知時刻を計算（現在時刻 + 指定された時間）
    final scheduledDate = tz.TZDateTime.now(tz.local).add(duration);

    // Android通知詳細
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'roast_timer_channel',
          '焙煎タイマー',
          channelDescription: '焙煎タイマーの通知',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('notification01'),
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true, // アプリを起動するために必要
          autoCancel: false,
        );

    // iOS通知詳細
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'notification01.aiff',
          categoryIdentifier: 'roast_timer',
        );

    // 通知詳細
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // 通知をスケジュール
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'roast_timer_$id',
    );

    print('焙煎タイマー通知をスケジュールしました: $id, $scheduledDate');
  }

  /// 焙煎タイマー通知をキャンセル
  static Future<void> cancelRoastTimerNotification(int id) async {
    await _notifications.cancel(id);
    print('焙煎タイマー通知をキャンセルしました: $id');
  }

  /// すべての焙煎タイマー通知をキャンセル
  static Future<void> cancelAllRoastTimerNotifications() async {
    await _notifications.cancelAll();
    print('すべての焙煎タイマー通知をキャンセルしました');
  }

  /// 通知権限をリクエスト
  static Future<bool> requestPermissions() async {
    if (!_isInitialized) {
      await initialize();
    }

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    bool? androidGranted;
    if (androidImplementation != null) {
      androidGranted = await androidImplementation
          .requestNotificationsPermission();
    }

    // iOSはDarwinInitializationSettingsで初期化時に権限リクエスト済み
    return (androidGranted ?? true);
  }

  /// 通知が許可されているかチェック（Androidのみ）
  static Future<bool> areNotificationsEnabled() async {
    if (!_isInitialized) {
      await initialize();
    }

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    bool? androidEnabled;
    if (androidImplementation != null) {
      androidEnabled = await androidImplementation.areNotificationsEnabled();
    }

    return (androidEnabled ?? false);
  }
}
