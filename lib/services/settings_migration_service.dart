import 'user_settings_firestore_service.dart';
import 'dart:developer' as developer;

/// SharedPreferencesからFirebaseへの設定移行サービス
class SettingsMigrationService {
  static const String _logName = 'SettingsMigrationService';
  static void _logInfo(String message) =>
      developer.log(message, name: _logName);
  static void _logError(
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) => developer.log(
    message,
    name: _logName,
    error: error,
    stackTrace: stackTrace,
  );

  /// 移行が必要な設定キーの定義
  static const Map<String, String> _settingKeys = {
    // サウンド設定
    'timer_sound_enabled': 'timer_sound_enabled',
    'notification_sound_enabled': 'notification_sound_enabled',
    'timer_volume': 'timer_volume',
    'notification_volume': 'notification_volume',
    'selected_timer_sound': 'selected_timer_sound',
    'selected_notification_sound': 'selected_notification_sound',

    // パスコード設定
    'passcode': 'passcode',
    'isLockEnabled': 'isLockEnabled',

    // テーマ設定
    'theme_appBarColor': 'theme_appBarColor',
    'theme_backgroundColor': 'theme_backgroundColor',
    'theme_buttonColor': 'theme_buttonColor',
    'theme_backgroundColor2': 'theme_backgroundColor2',
    'theme_fontColor1': 'theme_fontColor1',
    'theme_fontColor2': 'theme_fontColor2',
    'theme_iconColor': 'theme_iconColor',
    'theme_timerCircleColor': 'theme_timerCircleColor',
    'theme_bottomNavigationColor': 'theme_bottomNavigationColor',
    'theme_inputBackgroundColor': 'theme_inputBackgroundColor',
    'theme_appBarTextColor': 'theme_appBarTextColor',
    'theme_dialogBackgroundColor': 'theme_dialogBackgroundColor',
    'theme_dialogTextColor': 'theme_dialogTextColor',
    'theme_inputTextColor': 'theme_inputTextColor',
    'theme_fontSizeScale': 'theme_fontSizeScale',
    'theme_fontFamily': 'theme_fontFamily',
    'custom_themes': 'custom_themes',

    // 焙煎タイマー設定
    'preheatMinutes': 'preheatMinutes',
    'usePreheat': 'usePreheat',
    'roast_timer_remaining_seconds': 'roast_timer_remaining_seconds',
    'roast_timer_total_seconds': 'roast_timer_total_seconds',
    'roast_timer_mode': 'roast_timer_mode',
    'roast_timer_is_paused': 'roast_timer_is_paused',
    'roast_timer_completed': 'roast_timer_completed',
    'roast_timer_completed_mode': 'roast_timer_completed_mode',
    'roast_timer_completed_at': 'roast_timer_completed_at',

    // スケジュール設定
    'schedule_data': 'schedule_data',
    'todaySchedule_labels': 'todaySchedule_labels',
    'todaySchedule_data': 'todaySchedule_data',

    // ドリップパック設定
    'dripPackRecords': 'dripPackRecords',

    // アサインメント設定
    'teams': 'teams',
    'a班': 'assignment_team_a',
    'b班': 'assignment_team_b',
    'leftLabels': 'assignment_left_labels',
    'rightLabels': 'assignment_right_labels',
    'assignedDate': 'assignment_date',

    'todo_list': 'todo_list',
    'todo_notification_enabled': 'todo_notification_enabled',
    'todo_notification_time': 'todo_notification_time',
    'todo_notification_sent': 'todo_notification_sent',

    // ゲーミフィケーション設定
    'user_profile': 'gamification_user_profile',
    'daily_activities': 'gamification_daily_activities',
    'migration_completed': 'gamification_migration_completed',
    'last_activity_date': 'gamification_last_activity_date',

    // 作業進捗設定
    'work_progress_records': 'work_progress_records',

    // テイスティング設定
    'tasting_records': 'tasting_records',

    // ダッシュボード統計設定
    'cached_total_roasting_time': 'dashboard_cached_total_roasting_time',
    'cached_roasting_time_timestamp':
        'dashboard_cached_roasting_time_timestamp',
    'cached_attendance_days': 'dashboard_cached_attendance_days',
    'cached_attendance_timestamp': 'dashboard_cached_attendance_timestamp',
    'cached_drip_pack_count': 'dashboard_cached_drip_pack_count',
    'cached_drip_pack_timestamp': 'dashboard_cached_drip_pack_timestamp',

    // データ同期設定
    'last_sync_timestamp': 'sync_last_timestamp',
    'sync_status': 'sync_status',
    'cloud_theme_data': 'sync_cloud_theme_data',
    'cloud_sound_settings': 'sync_cloud_sound_settings',
    'cloud_font_settings': 'sync_cloud_font_settings',
    'cloud_roast_timer_settings': 'sync_cloud_roast_timer_settings',
    'cloud_schedule_data': 'sync_cloud_schedule_data',
    'cloud_drip_pack_data': 'sync_cloud_drip_pack_data',
    'cloud_assignment_data': 'sync_cloud_assignment_data',
    'cloud_todo_data': 'sync_cloud_todo_data',
    'cloud_work_progress_data': 'sync_cloud_work_progress_data',
    'cloud_tasting_data': 'sync_cloud_tasting_data',

    // ゴミ箱設定
    'trash_roast_records': 'trash_roast_records',

    // 焙煎時間アドバイザー設定
    'roast_time_advisor_settings': 'roast_time_advisor_settings',

    // その他の設定
    'developerMode': 'developerMode',
    'isFirstInstall': 'isFirstInstall',
  };

  /// 移行が必要かチェック
  static Future<bool> needsMigration() async {
    try {
      final migrationCompleted =
          await UserSettingsFirestoreService.getSetting(
            'settings_migration_completed',
          ) ??
          false;

      if (migrationCompleted) return false;

      // 移行対象の設定が存在するかチェック
      for (final key in _settingKeys.keys) {
        final value = await UserSettingsFirestoreService.getSetting(key);
        if (value != null) {
          return true;
        }
      }

      return false;
    } catch (e, st) {
      _logError('移行必要性チェックエラー', e, st);
      return false;
    }
  }

  /// 設定を移行
  static Future<bool> migrateSettings() async {
    try {
      _logInfo('設定移行を開始します...');

      final Map<String, dynamic> settingsToMigrate = {};

      // SharedPreferencesから設定を読み込み
      for (final entry in _settingKeys.entries) {
        final oldKey = entry.key;
        final newKey = entry.value;

        final value = await UserSettingsFirestoreService.getSetting(oldKey);
        if (value != null) {
          settingsToMigrate[newKey] = value;
          _logInfo('移行対象: $oldKey -> $newKey = $value');
        }
      }

      if (settingsToMigrate.isEmpty) {
        _logInfo('移行対象の設定が見つかりませんでした');
        await _markMigrationCompleted();
        return true;
      }

      // Firebaseに保存
      await UserSettingsFirestoreService.saveMultipleSettings(
        settingsToMigrate,
      );

      // 移行完了をマーク
      await _markMigrationCompleted();

      _logInfo('設定移行が完了しました: ${settingsToMigrate.length}件');
      return true;
    } catch (e, st) {
      _logError('設定移行エラー', e, st);
      return false;
    }
  }

  /// 移行完了をマーク
  static Future<void> _markMigrationCompleted() async {
    await UserSettingsFirestoreService.saveMultipleSettings({
      'settings_migration_completed': true,
      'settings_migration_timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 移行状態をリセット（デバッグ用）
  static Future<void> resetMigrationStatus() async {
    try {
      await UserSettingsFirestoreService.deleteSetting(
        'settings_migration_completed',
      );
      await UserSettingsFirestoreService.deleteSetting(
        'settings_migration_timestamp',
      );
      _logInfo('移行状態をリセットしました');
    } catch (e, st) {
      _logError('移行状態リセットエラー', e, st);
    }
  }

  /// 移行された設定を削除（移行後のクリーンアップ用）
  static Future<void> cleanupOldSettings() async {
    try {
      for (final key in _settingKeys.keys) {
        await UserSettingsFirestoreService.deleteSetting(key);
        _logInfo('古い設定を削除: $key');
      }

      _logInfo('古い設定のクリーンアップが完了しました');
    } catch (e, st) {
      _logError('クリーンアップエラー', e, st);
    }
  }

  /// 移行状態を確認
  static Future<Map<String, dynamic>> getMigrationStatus() async {
    try {
      final migrationCompleted =
          await UserSettingsFirestoreService.getSetting(
            'settings_migration_completed',
          ) ??
          false;
      final migrationTimestamp = await UserSettingsFirestoreService.getSetting(
        'settings_migration_timestamp',
      );

      final Map<String, dynamic> status = {
        'migrationCompleted': migrationCompleted,
        'migrationTimestamp': migrationTimestamp,
        'migrationDate': migrationTimestamp != null
            ? DateTime.fromMillisecondsSinceEpoch(migrationTimestamp).toString()
            : null,
      };

      // 移行対象の設定の存在確認
      final existingSettings = <String>[];
      for (final key in _settingKeys.keys) {
        final value = await UserSettingsFirestoreService.getSetting(key);
        if (value != null) {
          existingSettings.add(key);
        }
      }
      status['existingSettings'] = existingSettings;
      status['existingSettingsCount'] = existingSettings.length;

      return status;
    } catch (e, st) {
      _logError('移行状態確認エラー', e, st);
      return {
        'migrationCompleted': false,
        'migrationTimestamp': null,
        'migrationDate': null,
        'existingSettings': [],
        'existingSettingsCount': 0,
      };
    }
  }
}
