import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gamification_models.dart';

/// ゲーミフィケーションデータの永続化クラス
class GamificationStorage {
  static const String _keyUserProfile = 'gamification_user_profile';
  static const String _keyLastResetDate = 'gamification_last_reset_date';
  static const String _keyDailyActivities = 'gamification_daily_activities';

  /// ユーザープロフィールを保存
  static Future<void> saveUserProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(profile.toJson());
    await prefs.setString(_keyUserProfile, jsonString);
  }

  /// ユーザープロフィールを読み込み
  static Future<UserProfile> loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyUserProfile);

    if (jsonString == null || jsonString.isEmpty) {
      return UserProfile.initial();
    }

    try {
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return UserProfile.fromJson(jsonMap);
    } catch (e) {
      print('ゲーミフィケーションデータの読み込みエラー: $e');
      return UserProfile.initial();
    }
  }

  /// プロフィールをリセット（開発・テスト用）
  static Future<void> resetUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserProfile);
    await prefs.remove(_keyLastResetDate);
    await prefs.remove(_keyDailyActivities);
  }

  /// 今日の活動記録を保存（重複防止用）
  static Future<void> saveDailyActivity(ActivityType type, String key) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD
    final activityKey = '${type.toString()}_${key}_$today';

    final activities = prefs.getStringList(_keyDailyActivities) ?? [];
    if (!activities.contains(activityKey)) {
      activities.add(activityKey);
      await prefs.setStringList(_keyDailyActivities, activities);
    }
  }

  /// 今日既に記録済みかチェック
  static Future<bool> isDailyActivityRecorded(
    ActivityType type,
    String key,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD
    final activityKey = '${type.toString()}_${key}_$today';

    final activities = prefs.getStringList(_keyDailyActivities) ?? [];
    return activities.contains(activityKey);
  }

  /// 古い活動記録をクリーンアップ（1週間以上前のデータを削除）
  static Future<void> cleanupOldActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final activities = prefs.getStringList(_keyDailyActivities) ?? [];

    final oneWeekAgo = DateTime.now().subtract(Duration(days: 7));
    final cutoffDate = oneWeekAgo.toIso8601String().split('T')[0];

    final validActivities = activities.where((activity) {
      final parts = activity.split('_');
      if (parts.length >= 3) {
        final dateStr = parts.last;
        return dateStr.compareTo(cutoffDate) >= 0;
      }
      return false;
    }).toList();

    await prefs.setStringList(_keyDailyActivities, validActivities);
  }

  /// データの移行（アップデート時などに使用）
  static Future<void> migrateDataIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();

    // 既存データがあるかチェック
    final existingData = prefs.getString(_keyUserProfile);
    if (existingData != null) {
      try {
        final profile = await loadUserProfile();

        // データ形式が古い場合の移行処理をここに追加
        // 現在は特に移行処理なし

        await saveUserProfile(profile);
        print('ゲーミフィケーションデータ移行完了');
      } catch (e) {
        print('データ移行エラー: $e');
        // エラーの場合は初期データで上書き
        await saveUserProfile(UserProfile.initial());
      }
    }
  }

  /// バックアップとリストア機能
  static Future<String> exportUserData() async {
    final profile = await loadUserProfile();
    return jsonEncode(profile.toJson());
  }

  static Future<bool> importUserData(String jsonData) async {
    try {
      final jsonMap = jsonDecode(jsonData) as Map<String, dynamic>;
      final profile = UserProfile.fromJson(jsonMap);
      await saveUserProfile(profile);
      return true;
    } catch (e) {
      print('データインポートエラー: $e');
      return false;
    }
  }

  /// デバッグ用：現在のプロフィール情報を表示
  static Future<void> debugPrintProfile() async {
    final profile = await loadUserProfile();
    print('=== ゲーミフィケーションプロフィール ===');
    print('レベル: ${profile.level}');
    print('経験値: ${profile.experiencePoints}');
    print('出勤日数: ${profile.stats.attendanceDays}');
    print('焙煎時間: ${profile.stats.totalRoastTimeHours.toStringAsFixed(1)}時間');
    print('ドリップパック: ${profile.stats.dripPackCount}個');
    print('バッジ数: ${profile.badges.length}');
    if (profile.badges.isNotEmpty) {
      print('獲得バッジ:');
      for (final badge in profile.badges) {
        print('  - ${badge.name}: ${badge.description}');
      }
    }
    print('===============================');
  }
}
