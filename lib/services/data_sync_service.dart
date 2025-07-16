import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/theme_settings.dart';
import 'theme_cloud_service.dart';
import 'app_settings_firestore_service.dart';

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
    final prefs = await SharedPreferences.getInstance();

    try {
      // 1. テーマ設定をアップロード
      final themeSettings = await ThemeSettings.load();
      final themeData = {
        'appBarColor': themeSettings.appBarColor,
        'backgroundColor': themeSettings.backgroundColor,
        'buttonColor': themeSettings.buttonColor,
        'backgroundColor2': themeSettings.backgroundColor2,
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
      final settingsData = {
        'preheatMinutes': prefs.getInt('preheatMinutes'),
        'passcode_lock_enabled': prefs.getBool('passcode_lock_enabled'),
        'passcode': prefs.getString('passcode'),
        'developerMode': prefs.getBool('developerMode'),
        'lastSync': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('app_settings')
          .set(settingsData, SetOptions(merge: true));

      // 4. スケジュール設定をアップロード
      final scheduleData = prefs.getString('schedule_data');
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
    final prefs = await SharedPreferences.getInstance();

    try {
      // 1. テーマ設定をダウンロード
      final cloudTheme = await ThemeCloudService.getThemeFromCloud();
      if (cloudTheme != null) {
        // テーマ設定をローカルに保存
        await prefs.setInt(
          'theme_appBarColor',
          cloudTheme['appBarColor']!.value,
        );
        await prefs.setInt(
          'theme_backgroundColor',
          cloudTheme['backgroundColor']!.value,
        );
        await prefs.setInt(
          'theme_buttonColor',
          cloudTheme['buttonColor']!.value,
        );
        await prefs.setInt(
          'theme_backgroundColor2',
          cloudTheme['backgroundColor2']!.value,
        );
        await prefs.setInt('theme_fontColor1', cloudTheme['fontColor1']!.value);
        await prefs.setInt('theme_fontColor2', cloudTheme['fontColor2']!.value);
        await prefs.setInt('theme_iconColor', cloudTheme['iconColor']!.value);
        await prefs.setInt(
          'theme_timerCircleColor',
          cloudTheme['timerCircleColor']!.value,
        );
        await prefs.setInt(
          'theme_bottomNavigationColor',
          cloudTheme['bottomNavigationColor']!.value,
        );
        await prefs.setInt(
          'theme_inputBackgroundColor',
          cloudTheme['inputBackgroundColor']!.value,
        );
        await prefs.setInt(
          'theme_memberBackgroundColor',
          cloudTheme['memberBackgroundColor']!.value,
        );
        await prefs.setInt(
          'theme_appBarTextColor',
          cloudTheme['appBarTextColor']!.value,
        );
        await prefs.setInt(
          'theme_bottomNavigationTextColor',
          cloudTheme['bottomNavigationTextColor']!.value,
        );
      }

      // 2. カスタムテーマをダウンロード
      final cloudCustomThemes =
          await ThemeCloudService.getCustomThemesFromCloud();
      if (cloudCustomThemes.isNotEmpty) {
        final themeDataMap = cloudCustomThemes.map(
          (key, value) =>
              MapEntry(key, value.map((k, v) => MapEntry(k, v.value))),
        );
        await prefs.setString('custom_themes', json.encode(themeDataMap));
      }

      // 追加: サウンド設定をダウンロード
      final soundSettings =
          await AppSettingsFirestoreService.getSoundSettings();
      if (soundSettings != null) {
        await prefs.setString(
          'sound_alarmSound',
          soundSettings['alarmSound'] ?? '',
        );
        await prefs.setString(
          'sound_notificationSound',
          soundSettings['notificationSound'] ?? '',
        );
        await prefs.setBool(
          'sound_alarmEnabled',
          soundSettings['alarmEnabled'] ?? true,
        );
        await prefs.setBool(
          'sound_notificationEnabled',
          soundSettings['notificationEnabled'] ?? true,
        );
        await prefs.setDouble(
          'sound_alarmVolume',
          (soundSettings['alarmVolume'] ?? 1.0).toDouble(),
        );
        await prefs.setDouble(
          'sound_notificationVolume',
          (soundSettings['notificationVolume'] ?? 1.0).toDouble(),
        );
      }

      // 追加: フォントサイズ設定をダウンロード
      final fontSettings =
          await AppSettingsFirestoreService.getFontSizeSettings();
      if (fontSettings != null) {
        await prefs.setDouble(
          'fontSize',
          (fontSettings['fontSize'] ?? 1.0).toDouble(),
        );
        await prefs.setBool(
          'useCustomFontSize',
          fontSettings['useCustomFontSize'] ?? false,
        );
        if (fontSettings['fontFamily'] != null) {
          await prefs.setString('fontFamily', fontSettings['fontFamily']);
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
          await prefs.setString(
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

        if (data['preheatMinutes'] != null) {
          await prefs.setInt('preheatMinutes', data['preheatMinutes']);
        }
        if (data['passcode_lock_enabled'] != null) {
          await prefs.setBool(
            'passcode_lock_enabled',
            data['passcode_lock_enabled'],
          );
        }
        if (data['passcode'] != null) {
          await prefs.setString('passcode', data['passcode']);
        }
        if (data['developerMode'] != null) {
          await prefs.setBool('developerMode', data['developerMode']);
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
          await prefs.setString('schedule_data', data['scheduleData']);
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
    final prefs = await SharedPreferences.getInstance();

    return {
      'theme_settings': {
        'appBarColor': prefs.getInt('theme_appBarColor'),
        'backgroundColor': prefs.getInt('theme_backgroundColor'),
        'buttonColor': prefs.getInt('theme_buttonColor'),
        'backgroundColor2': prefs.getInt('theme_backgroundColor2'),
        'fontColor1': prefs.getInt('theme_fontColor1'),
        'fontColor2': prefs.getInt('theme_fontColor2'),
        'iconColor': prefs.getInt('theme_iconColor'),
        'timerCircleColor': prefs.getInt('theme_timerCircleColor'),
        'bottomNavigationColor': prefs.getInt('theme_bottomNavigationColor'),
        'inputBackgroundColor': prefs.getInt('theme_inputBackgroundColor'),
        'memberBackgroundColor': prefs.getInt('theme_memberBackgroundColor'),
        'appBarTextColor': prefs.getInt('theme_appBarTextColor'),
        'bottomNavigationTextColor': prefs.getInt(
          'theme_bottomNavigationTextColor',
        ),
      },
      'app_settings': {
        'preheatMinutes': prefs.getInt('preheatMinutes'),
        'passcode_lock_enabled': prefs.getBool('passcode_lock_enabled'),
        'passcode': prefs.getString('passcode'),
        'developerMode': prefs.getBool('developerMode'),
      },
      'custom_themes': prefs.getString('custom_themes'),
      'schedule_data': prefs.getString('schedule_data'),
    };
  }
}
