import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/gamification_models.dart';
import 'user_settings_firestore_service.dart';
import 'gamification_firestore_service.dart';

/// ゲーミフィケーションデータの永続化クラス（Firestore + ローカル対応）
class GamificationStorage {
  static const String _keyUserProfile = 'gamification_user_profile';
  static const String _keyLastResetDate = 'gamification_last_reset_date';
  static const String _keyDailyActivities = 'gamification_daily_activities';
  static const String _keyMigrationCompleted =
      'gamification_migration_completed';

  /// ユーザープロフィールを保存（Firebase + Firestore）
  static Future<void> saveUserProfile(UserProfile profile) async {
    try {
      // Firebaseに保存
      final jsonString = jsonEncode(profile.toJson());
      await UserSettingsFirestoreService.saveSetting(
        _keyUserProfile,
        jsonString,
      );

      // Firestoreに保存（ログインしている場合）
      if (FirebaseAuth.instance.currentUser != null) {
        try {
          await GamificationFirestoreService.saveUserProfile(profile);
        } catch (e) {
          print('Firestoreへの保存に失敗しましたが、Firebase保存は成功しました: $e');
        }
      }
    } catch (e) {
      print('ユーザープロフィール保存エラー: $e');
    }
  }

  /// ユーザープロフィールを読み込み（Firestore優先、ローカルフォールバック）
  static Future<UserProfile> loadUserProfile() async {
    UserProfile? firestoreProfile;
    UserProfile? localProfile;

    // Firestoreから取得を試行（ログインしている場合）
    if (FirebaseAuth.instance.currentUser != null) {
      try {
        firestoreProfile = await GamificationFirestoreService.loadUserProfile();
      } catch (e) {
        print('Firestoreからの読み込みに失敗しました: $e');
      }
    }

    // Firebaseから取得を試行
    try {
      final jsonString = await UserSettingsFirestoreService.getSetting(
        _keyUserProfile,
      );

      if (jsonString != null && jsonString.isNotEmpty) {
        final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
        localProfile = UserProfile.fromJson(jsonMap);
      }
    } catch (e) {
      print('Firebaseデータの読み込みエラー: $e');
    }

    // Firestoreのデータがある場合はそれを優先
    if (firestoreProfile != null) {
      // ローカルデータより新しい場合は、ローカルにも保存
      if (localProfile == null ||
          _isFirestoreDataNewer(firestoreProfile, localProfile)) {
        await _saveLocalProfile(firestoreProfile);
      }
      return firestoreProfile;
    }

    // ローカルデータがある場合はそれを使用し、Firestoreにも同期
    if (localProfile != null) {
      if (FirebaseAuth.instance.currentUser != null) {
        try {
          await GamificationFirestoreService.saveUserProfile(localProfile);
        } catch (e) {
          print('ローカルデータのFirestore同期に失敗しました: $e');
        }
      }
      return localProfile;
    }

    // どちらにもデータがない場合は初期データを返す
    return UserProfile.initial();
  }

  /// Firebaseプロフィールのみを保存（Firestore同期なし）
  static Future<void> _saveLocalProfile(UserProfile profile) async {
    try {
      final jsonString = jsonEncode(profile.toJson());
      await UserSettingsFirestoreService.saveSetting(
        _keyUserProfile,
        jsonString,
      );
    } catch (e) {
      print('Firebaseプロフィール保存エラー: $e');
    }
  }

  /// Firestoreデータの方が新しいかチェック
  static bool _isFirestoreDataNewer(
    UserProfile firestoreProfile,
    UserProfile localProfile,
  ) {
    // 経験値やレベルが高い方を新しいと判断
    if (firestoreProfile.experiencePoints > localProfile.experiencePoints) {
      return true;
    }
    if (firestoreProfile.level > localProfile.level) {
      return true;
    }
    if (firestoreProfile.badges.length > localProfile.badges.length) {
      return true;
    }
    return false;
  }

  /// プロフィールをリセット（開発・テスト用）
  static Future<void> resetUserProfile() async {
    try {
      await UserSettingsFirestoreService.deleteSetting(_keyUserProfile);
      await UserSettingsFirestoreService.deleteSetting(_keyLastResetDate);
      await UserSettingsFirestoreService.deleteSetting(_keyDailyActivities);
      await UserSettingsFirestoreService.deleteSetting(_keyMigrationCompleted);
    } catch (e) {
      print('プロフィールリセットエラー: $e');
    }
  }

  /// 今日の活動記録を保存（重複防止用、Firebase + Firestore）
  static Future<void> saveDailyActivity(ActivityType type, String key) async {
    final today = DateTime.now();

    try {
      // Firebaseに保存
      final todayStr = today.toIso8601String().split('T')[0]; // YYYY-MM-DD
      final activityKey = '${type.toString()}_${key}_$todayStr';

      final activities =
          await UserSettingsFirestoreService.getSetting(_keyDailyActivities) ??
          [];
      if (!activities.contains(activityKey)) {
        activities.add(activityKey);
        await UserSettingsFirestoreService.saveSetting(
          _keyDailyActivities,
          activities,
        );
      }
    } catch (e) {
      print('Firebase活動記録保存エラー: $e');
    }

    // Firestoreに保存（ログインしている場合）
    if (FirebaseAuth.instance.currentUser != null) {
      try {
        await GamificationFirestoreService.saveDailyActivity(type, key, today);
      } catch (e) {
        print('日次活動記録のFirestore保存に失敗しました: $e');
      }
    }
  }

  /// 今日既に記録済みかチェック（Firestore優先、ローカルフォールバック）
  static Future<bool> isDailyActivityRecorded(
    ActivityType type,
    String key,
  ) async {
    final today = DateTime.now();

    // Firestoreから確認（ログインしている場合）
    if (FirebaseAuth.instance.currentUser != null) {
      try {
        final isRecorded =
            await GamificationFirestoreService.isDailyActivityRecorded(
              type,
              key,
              today,
            );
        return isRecorded;
      } catch (e) {
        print('Firestoreでの活動記録確認に失敗しました: $e');
      }
    }

    // Firebaseから確認
    try {
      final todayStr = today.toIso8601String().split('T')[0]; // YYYY-MM-DD
      final activityKey = '${type.toString()}_${key}_$todayStr';

      final activities =
          await UserSettingsFirestoreService.getSetting(_keyDailyActivities) ??
          [];
      return activities.contains(activityKey);
    } catch (e) {
      print('Firebase活動記録確認エラー: $e');
      return false;
    }
  }

  /// 古い活動記録をクリーンアップ（1週間以上前のデータを削除）
  static Future<void> cleanupOldActivities() async {
    try {
      // Firebaseクリーンアップ
      final activities =
          await UserSettingsFirestoreService.getSetting(_keyDailyActivities) ??
          [];

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

      await UserSettingsFirestoreService.saveSetting(
        _keyDailyActivities,
        validActivities,
      );
    } catch (e) {
      print('Firebase古い活動記録クリーンアップエラー: $e');
    }

    // Firestoreクリーンアップ（ログインしている場合）
    if (FirebaseAuth.instance.currentUser != null) {
      try {
        await GamificationFirestoreService.cleanupOldActivities();
      } catch (e) {
        print('Firestoreでの古い活動記録クリーンアップに失敗しました: $e');
      }
    }
  }

  /// データの移行（アップデート時などに使用）
  static Future<void> migrateDataIfNeeded() async {
    final migrationCompleted =
        await UserSettingsFirestoreService.getSetting(_keyMigrationCompleted) ??
        false;

    // 既に移行済みの場合はスキップ
    if (migrationCompleted) {
      return;
    }

    print('ゲーミフィケーションデータの移行を開始します...');

    try {
      // ローカルの既存データを確認
      final existingLocalData = await UserSettingsFirestoreService.getSetting(
        _keyUserProfile,
      );
      UserProfile? localProfile;

      if (existingLocalData != null) {
        try {
          localProfile = UserProfile.fromJson(existingLocalData);
          print(
            'ローカルデータが見つかりました: レベル${localProfile.level}, 経験値${localProfile.experiencePoints}',
          );
        } catch (e) {
          print('ローカルデータの解析に失敗しました: $e');
        }
      }

      // Firestoreからデータを確認（ログインしている場合）
      UserProfile? firestoreProfile;
      if (FirebaseAuth.instance.currentUser != null) {
        try {
          firestoreProfile =
              await GamificationFirestoreService.loadUserProfile();
          if (firestoreProfile != null) {
            print(
              'Firestoreデータが見つかりました: レベル${firestoreProfile.level}, 経験値${firestoreProfile.experiencePoints}',
            );
          }
        } catch (e) {
          print('Firestoreデータの取得に失敗しました: $e');
        }
      }

      // データの統合処理
      UserProfile finalProfile;

      if (localProfile != null && firestoreProfile != null) {
        // 両方のデータがある場合は、より進んでいる方を採用
        if (_isFirestoreDataNewer(firestoreProfile, localProfile)) {
          finalProfile = firestoreProfile;
          print('Firestoreデータを採用しました');
        } else {
          finalProfile = localProfile;
          print('ローカルデータを採用しました');
        }
      } else if (localProfile != null) {
        finalProfile = localProfile;
        print('ローカルデータのみを使用します');
      } else if (firestoreProfile != null) {
        finalProfile = firestoreProfile;
        print('Firestoreデータのみを使用します');
      } else {
        finalProfile = UserProfile.initial();
        print('データが見つからないため、初期データを作成します');
      }

      // 統合されたデータを両方の場所に保存
      await _saveLocalProfile(finalProfile);

      if (FirebaseAuth.instance.currentUser != null) {
        try {
          await GamificationFirestoreService.saveUserProfile(finalProfile);
        } catch (e) {
          print('移行データのFirestore保存に失敗しました: $e');
        }
      }

      // ローカル活動記録の移行
      await _migrateDailyActivities();

      // 移行完了フラグを設定
      await UserSettingsFirestoreService.saveSetting(
        _keyMigrationCompleted,
        true,
      );

      print('ゲーミフィケーションデータ移行完了');
    } catch (e) {
      print('データ移行エラー: $e');
      // エラーの場合は初期データで上書き
      try {
        await saveUserProfile(UserProfile.initial());
        await UserSettingsFirestoreService.saveSetting(
          _keyMigrationCompleted,
          true,
        );
      } catch (saveError) {
        print('初期データ保存エラー: $saveError');
      }
    }
  }

  /// ローカル活動記録をFirestoreに移行
  static Future<void> _migrateDailyActivities() async {
    if (FirebaseAuth.instance.currentUser == null) return;

    try {
      final activities =
          await UserSettingsFirestoreService.getSetting(_keyDailyActivities) ??
          [];

      for (final activity in activities) {
        final parts = activity.split('_');
        if (parts.length >= 3) {
          final typeStr = parts[0];
          final key = parts[1];
          final dateStr = parts[2];

          try {
            final type = ActivityType.values.firstWhere(
              (e) => e.toString() == typeStr,
              orElse: () => ActivityType.attendance,
            );
            final date = DateTime.parse('${dateStr}T00:00:00');

            await GamificationFirestoreService.saveDailyActivity(
              type,
              key,
              date,
            );
          } catch (e) {
            print('活動記録の移行に失敗しました: $activity, エラー: $e');
          }
        }
      }

      print('活動記録の移行が完了しました: ${activities.length}件');
    } catch (e) {
      print('活動記録移行エラー: $e');
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
