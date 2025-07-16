import 'package:shared_preferences/shared_preferences.dart';

class SoundUtils {
  /// サウンド設定から選択されたタイマー音を取得
  static Future<String> getSelectedTimerSound() async {
    final prefs = await SharedPreferences.getInstance();
    final sound = prefs.getString('selected_timer_sound') ??
        'sounds/alarm/alarm01.mp3';
    
    // 古いパス形式の場合は新しい形式に変換
    if (sound.startsWith('alarm/')) {
      return 'sounds/$sound';
    }
    
    return sound;
  }

  /// サウンド設定から選択された通知音を取得
  static Future<String> getSelectedNotificationSound() async {
    final prefs = await SharedPreferences.getInstance();
    final sound = prefs.getString('selected_notification_sound') ??
        'sounds/notification/notification01.mp3';
    
    // 古いパス形式の場合は新しい形式に変換
    if (sound.startsWith('notification/')) {
      return 'sounds/$sound';
    }
    
    return sound;
  }

  /// タイマー音が有効かどうかを取得
  static Future<bool> isTimerSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('timer_sound_enabled') ?? true;
  }

  /// 通知音が有効かどうかを取得
  static Future<bool> isNotificationSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notification_sound_enabled') ?? true;
  }

  /// タイマー音量を取得
  static Future<double> getTimerVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('timer_volume') ?? 0.5;
  }

  /// 通知音量を取得
  static Future<double> getNotificationVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('notification_volume') ?? 0.5;
  }
}
