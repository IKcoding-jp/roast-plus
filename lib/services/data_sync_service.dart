import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../models/theme_settings.dart';
import 'theme_cloud_service.dart';
import 'app_settings_firestore_service.dart';
import 'user_settings_firestore_service.dart';

class DataSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ユーザーがログインしているかチェック
  static bool get isLoggedIn => _auth.currentUser != null;

  // 現在のユーザーIDを取得
  static String? get currentUserId => _auth.currentUser?.uid;

  // 全データをクラウドにアップロード
  static Future<void> uploadAllData() async {
    if (!isLoggedIn) {
      throw Exception('ユーザーがログインしていません');
    }

    final userId = currentUserId!;

    try {
      // 1. テーマ設定をアップロード
      final themeSettings = await ThemeSettings.load();
      final themeData = {
        'appBarColor': themeSettings.appBarColor,
        'backgroundColor': themeSettings.backgroundColor,
        'buttonColor': themeSettings.buttonColor,
        'backgroundColor2': themeSettings.cardBackgroundColor,
        'fontColor1': themeSettings.fontColor1,
        'fontColor2': themeSettings.fontColor2,
        'iconColor': themeSettings.iconColor,
        'timerCircleColor': themeSettings.timerCircleColor,
        'bottomNavigationColor': themeSettings.bottomNavigationColor,
        'inputBackgroundColor': themeSettings.inputBackgroundColor,
        'memberBackgroundColor': themeSettings.memberBackgroundColor,
        'appBarTextColor': themeSettings.appBarTextColor,
        'bottomNavigationTextColor': themeSettings.bottomNavigationTextColor,
      };
      await ThemeCloudService.saveThemeToCloud(themeData);

      // 2. カスタムテーマをアップロード
      final customThemes = await ThemeSettings.getCustomThemes();
      await ThemeCloudService.saveCustomThemesToCloud(customThemes);

      // 3. その他の設定データをアップロード
      final settings = await UserSettingsFirestoreService.getMultipleSettings([
        'preheatMinutes',
        'passcode_lock_enabled',
        'passcode',
        'developerMode',
      ]);

      final settingsData = {
        'preheatMinutes': settings['preheatMinutes'],
        'passcode_lock_enabled': settings['passcode_lock_enabled'],
        'passcode': settings['passcode'],
        'developerMode': settings['developerMode'],
        'lastSync': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('app_settings')
          .set(settingsData, SetOptions(merge: true));

      // 4. スケジュール設定をアップロード
      final scheduleData = await UserSettingsFirestoreService.getSetting(
        'schedule_data',
      );
      if (scheduleData != null) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('settings')
            .doc('schedule_settings')
            .set({
              'scheduleData': scheduleData,
              'lastSync': FieldValue.serverTimestamp(),
            });
      }
    } catch (e) {
      throw Exception('データのアップロードに失敗しました: $e');
    }
  }

  // 全データをクラウドからダウンロード
  static Future<void> downloadAllData() async {
    if (!isLoggedIn) {
      throw Exception('ユーザーがログインしていません');
    }

    final userId = currentUserId!;

    try {
      // 1. テーマ設定をダウンロード
      final cloudTheme = await ThemeCloudService.getThemeFromCloud();
      if (cloudTheme != null) {
        // テーマ設定をローカルに保存
        await UserSettingsFirestoreService.saveMultipleSettings({
          'theme_appBarColor': cloudTheme['appBarColor']!.toARGB32(),
          'theme_backgroundColor': cloudTheme['backgroundColor']!.toARGB32(),
          'theme_buttonColor': cloudTheme['buttonColor']!.toARGB32(),
          'theme_backgroundColor2': cloudTheme['backgroundColor2']!.toARGB32(),
          'theme_fontColor1': cloudTheme['fontColor1']!.toARGB32(),
          'theme_fontColor2': cloudTheme['fontColor2']!.toARGB32(),
          'theme_iconColor': cloudTheme['iconColor']!.toARGB32(),
          'theme_timerCircleColor': cloudTheme['timerCircleColor']!.toARGB32(),
          'theme_bottomNavigationColor': cloudTheme['bottomNavigationColor']!
              .toARGB32(),
          'theme_inputBackgroundColor': cloudTheme['inputBackgroundColor']!
              .toARGB32(),
          'theme_memberBackgroundColor': cloudTheme['memberBackgroundColor']!
              .toARGB32(),
          'theme_appBarTextColor': cloudTheme['appBarTextColor']!.toARGB32(),
          'theme_bottomNavigationTextColor':
              cloudTheme['bottomNavigationTextColor']!.toARGB32(),
        });
      }

      // 2. カスタムテーマをダウンロード
      final cloudCustomThemes =
          await ThemeCloudService.getCustomThemesFromCloud();
      if (cloudCustomThemes.isNotEmpty) {
        final themeDataMap = cloudCustomThemes.map(
          (key, value) =>
              MapEntry(key, value.map((k, v) => MapEntry(k, v.toARGB32()))),
        );
        await UserSettingsFirestoreService.saveSetting(
          'custom_themes',
          json.encode(themeDataMap),
        );
      }

      // 追加: サウンド設定をダウンロード
      final soundSettings =
          await AppSettingsFirestoreService.getSoundSettings();
      if (soundSettings != null) {
        await UserSettingsFirestoreService.saveMultipleSettings({
          'sound_alarmSound': soundSettings['alarmSound'] ?? '',
          'sound_notificationSound': soundSettings['notificationSound'] ?? '',
          'sound_alarmEnabled': soundSettings['alarmEnabled'] ?? true,
          'sound_notificationEnabled':
              soundSettings['notificationEnabled'] ?? true,
          'sound_alarmVolume': (soundSettings['alarmVolume'] ?? 1.0).toDouble(),
          'sound_notificationVolume':
              (soundSettings['notificationVolume'] ?? 1.0).toDouble(),
        });
      }

      // 追加: フォントサイズ設定をダウンロード
      final fontSettings =
          await AppSettingsFirestoreService.getFontSizeSettings();
      if (fontSettings != null) {
        await UserSettingsFirestoreService.saveMultipleSettings({
          'fontSize': (fontSettings['fontSize'] ?? 1.0).toDouble(),
          'useCustomFontSize': fontSettings['useCustomFontSize'] ?? false,
        });
        if (fontSettings['fontFamily'] != null) {
          await UserSettingsFirestoreService.saveSetting(
            'fontFamily',
            fontSettings['fontFamily'],
          );
        }
      }

      // 追加: 豆のシール設定をダウンロード
      final beanStickersDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('bean_stickers')
          .get();
      if (beanStickersDoc.exists) {
        final data = beanStickersDoc.data() as Map<String, dynamic>;
        if (data['beanStickers'] != null) {
          await UserSettingsFirestoreService.saveSetting(
            'bean_stickers',
            json.encode(data['beanStickers']),
          );
        }
      }

      // 3. その他の設定データをダウンロード
      final settingsDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('app_settings')
          .get();

      if (settingsDoc.exists) {
        final data = settingsDoc.data() as Map<String, dynamic>;
        final settingsToSave = <String, dynamic>{};

        if (data['preheatMinutes'] != null) {
          settingsToSave['preheatMinutes'] = data['preheatMinutes'];
        }
        if (data['passcode_lock_enabled'] != null) {
          settingsToSave['passcode_lock_enabled'] =
              data['passcode_lock_enabled'];
        }
        if (data['passcode'] != null) {
          settingsToSave['passcode'] = data['passcode'];
        }
        if (data['developerMode'] != null) {
          settingsToSave['developerMode'] = data['developerMode'];
        }

        if (settingsToSave.isNotEmpty) {
          await UserSettingsFirestoreService.saveMultipleSettings(
            settingsToSave,
          );
        }
      }

      // 4. スケジュール設定をダウンロード
      final scheduleDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('schedule_settings')
          .get();

      if (scheduleDoc.exists) {
        final data = scheduleDoc.data() as Map<String, dynamic>;
        if (data['scheduleData'] != null) {
          await UserSettingsFirestoreService.saveSetting(
            'schedule_data',
            data['scheduleData'],
          );
        }
      }
    } catch (e) {
      throw Exception('データのダウンロードに失敗しました: $e');
    }
  }

  // 同期状態をチェック
  static Future<Map<String, dynamic>> getSyncStatus() async {
    if (!isLoggedIn) {
      return {'isLoggedIn': false, 'lastSync': null, 'hasCloudData': false};
    }

    final userId = currentUserId!;

    try {
      // 最後の同期時刻を取得
      final settingsDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('app_settings')
          .get();

      final lastSync = settingsDoc.exists
          ? (settingsDoc.data() as Map<String, dynamic>)['lastSync']
                as Timestamp?
          : null;

      // クラウドにデータが存在するかチェック
      final hasThemeData = await ThemeCloudService.hasCloudTheme();
      final hasCustomThemes = await ThemeCloudService.hasCloudCustomThemes();

      return {
        'isLoggedIn': true,
        'lastSync': lastSync,
        'hasCloudData': hasThemeData || hasCustomThemes || settingsDoc.exists,
      };
    } catch (e) {
      return {
        'isLoggedIn': true,
        'lastSync': null,
        'hasCloudData': false,
        'error': e.toString(),
      };
    }
  }

  // データの競合を解決（クラウドのデータを優先）
  static Future<void> resolveConflicts() async {
    if (!isLoggedIn) {
      throw Exception('ユーザーがログインしていません');
    }

    try {
      // クラウドのデータをダウンロードしてローカルを上書き
      await downloadAllData();
    } catch (e) {
      throw Exception('競合の解決に失敗しました: $e');
    }
  }

  // データのバックアップを作成
  static Future<void> createBackup() async {
    if (!isLoggedIn) {
      throw Exception('ユーザーがログインしていません');
    }

    final userId = currentUserId!;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      // 現在のデータをバックアップとして保存
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('backups')
          .doc('backup_$timestamp')
          .set({
            'timestamp': FieldValue.serverTimestamp(),
            'description': '手動バックアップ',
            'data': await _getAllLocalData(),
          });
    } catch (e) {
      throw Exception('バックアップの作成に失敗しました: $e');
    }
  }

  /// アカウントに保存された全データをFirestoreから削除（グループデータは除外）
  static Future<void> deleteAllUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('未ログイン');
    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final collections = [
      'assignmentMembers',
      'assignmentHistory',
      'todaySchedule',
      'todoList',
      'labels',
      'roastRecords',
      'roastBreakTimes',
      'roastTimerSettings',
      'tastingRecords',
      'workProgress',
      'memo',
      // 必要に応じて追加
    ];
    for (final col in collections) {
      final colRef = userDoc.collection(col);
      final snapshots = await colRef.get();
      for (final doc in snapshots.docs) {
        await doc.reference.delete();
      }
    }
    // ユーザードキュメント自体の個人情報も削除（グループ情報は除外）
    await userDoc.delete();
  }

  // ローカルの全データを取得
  static Future<Map<String, dynamic>> _getAllLocalData() async {
    return {
      'theme_settings': {
        'appBarColor': await UserSettingsFirestoreService.getSetting(
          'theme_appBarColor',
        ),
        'backgroundColor': await UserSettingsFirestoreService.getSetting(
          'theme_backgroundColor',
        ),
        'buttonColor': await UserSettingsFirestoreService.getSetting(
          'theme_buttonColor',
        ),
        'backgroundColor2': await UserSettingsFirestoreService.getSetting(
          'theme_backgroundColor2',
        ),
        'fontColor1': await UserSettingsFirestoreService.getSetting(
          'theme_fontColor1',
        ),
        'fontColor2': await UserSettingsFirestoreService.getSetting(
          'theme_fontColor2',
        ),
        'iconColor': await UserSettingsFirestoreService.getSetting(
          'theme_iconColor',
        ),
        'timerCircleColor': await UserSettingsFirestoreService.getSetting(
          'theme_timerCircleColor',
        ),
        'bottomNavigationColor': await UserSettingsFirestoreService.getSetting(
          'theme_bottomNavigationColor',
        ),
        'inputBackgroundColor': await UserSettingsFirestoreService.getSetting(
          'theme_inputBackgroundColor',
        ),
        'memberBackgroundColor': await UserSettingsFirestoreService.getSetting(
          'theme_memberBackgroundColor',
        ),
        'appBarTextColor': await UserSettingsFirestoreService.getSetting(
          'theme_appBarTextColor',
        ),
        'bottomNavigationTextColor':
            await UserSettingsFirestoreService.getSetting(
              'theme_bottomNavigationTextColor',
            ),
      },
      'app_settings': {
        'preheatMinutes': await UserSettingsFirestoreService.getSetting(
          'preheatMinutes',
        ),
        'passcode_lock_enabled': await UserSettingsFirestoreService.getSetting(
          'passcode_lock_enabled',
        ),
        'passcode': await UserSettingsFirestoreService.getSetting('passcode'),
        'developerMode': await UserSettingsFirestoreService.getSetting(
          'developerMode',
        ),
      },
      'custom_themes': await UserSettingsFirestoreService.getSetting(
        'custom_themes',
      ),
      'schedule_data': await UserSettingsFirestoreService.getSetting(
        'schedule_data',
      ),
    };
  }
}
