import '../services/user_settings_firestore_service.dart';

class SoundUtils {
  /// サウンド設定から選択されたタイマー音を取得
  static Future<String> getSelectedTimerSound() async {
    final sound = await UserSettingsFirestoreService.getSetting(
      'selected_timer_sound',
      defaultValue: 'sounds/alarm/alarm01.mp3',
    );

    // 古いパス形式の場合は新しい形式に変換
    if (sound.startsWith('alarm/')) {
      return 'sounds/$sound';
    }

    return sound;
  }

  /// サウンド設定から選択された通知音を取得
  static Future<String> getSelectedNotificationSound() async {
    final sound = await UserSettingsFirestoreService.getSetting(
      'selected_notification_sound',
      defaultValue: 'sounds/notification/notification01.mp3',
    );

    // 古いパス形式の場合は新しい形式に変換
    if (sound.startsWith('notification/')) {
      return 'sounds/$sound';
    }

    return sound;
  }

  /// タイマー音が有効かどうかを取得
  static Future<bool> isTimerSoundEnabled() async {
    return await UserSettingsFirestoreService.getSetting(
      'timer_sound_enabled',
      defaultValue: true,
    );
  }

  /// 通知音が有効かどうかを取得
  static Future<bool> isNotificationSoundEnabled() async {
    return await UserSettingsFirestoreService.getSetting(
      'notification_sound_enabled',
      defaultValue: true,
    );
  }

  /// タイマー音量を取得
  static Future<double> getTimerVolume() async {
    return await UserSettingsFirestoreService.getSetting(
      'timer_volume',
      defaultValue: 0.5,
    );
  }

  /// 通知音量を取得
  static Future<double> getNotificationVolume() async {
    return await UserSettingsFirestoreService.getSetting(
      'notification_volume',
      defaultValue: 0.5,
    );
  }
}
