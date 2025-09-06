import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auto_sync_service.dart';
import 'dart:developer' as developer;

class AppSettingsFirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  /// 音声設定を保存
  static Future<void> saveSoundSettings({
    required String alarmSound,
    required String notificationSound,
    required bool alarmEnabled,
    required bool notificationEnabled,
    required double alarmVolume,
    required double notificationVolume,
  }) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('sound')
          .set({
            'alarmSound': alarmSound,
            'notificationSound': notificationSound,
            'alarmEnabled': alarmEnabled,
            'notificationEnabled': notificationEnabled,
            'alarmVolume': alarmVolume,
            'notificationVolume': notificationVolume,
            'savedAt': FieldValue.serverTimestamp(),
          });

      // 自動同期を実行
      await AutoSyncService.triggerAutoSyncForDataType('sound_settings');
    } catch (e) {
      developer.log('音声設定保存エラー: $e', name: 'AppSettingsFirestoreService');
      rethrow;
    }
  }

  /// 音声設定を取得
  static Future<Map<String, dynamic>?> getSoundSettings() async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('sound')
          .get();

      return doc.exists ? doc.data() : null;
    } catch (e) {
      developer.log('音声設定取得エラー: $e', name: 'AppSettingsFirestoreService');
      return null;
    }
  }

  /// フォントサイズ設定を保存
  static Future<void> saveFontSizeSettings({
    required double fontSize,
    required bool useCustomFontSize,
    required String fontFamily,
  }) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('font_size')
          .set({
            'fontSize': fontSize,
            'useCustomFontSize': useCustomFontSize,
            'fontFamily': fontFamily,
            'savedAt': FieldValue.serverTimestamp(),
          });

      // 自動同期を実行
      await AutoSyncService.triggerAutoSyncForDataType('font_size_settings');
    } catch (e) {
      developer.log('フォントサイズ設定保存エラー: $e', name: 'AppSettingsFirestoreService');
      rethrow;
    }
  }

  /// フォントサイズ設定を取得
  static Future<Map<String, dynamic>?> getFontSizeSettings() async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('font_size')
          .get();

      return doc.exists ? doc.data() : null;
    } catch (e) {
      developer.log('フォントサイズ設定取得エラー: $e', name: 'AppSettingsFirestoreService');
      return null;
    }
  }

  /// パスコードロック設定を保存
  static Future<void> savePasscodeSettings({
    required bool passcodeEnabled,
    required String? passcode,
  }) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('passcode')
          .set({
            'passcodeEnabled': passcodeEnabled,
            'passcode': passcode,
            'savedAt': FieldValue.serverTimestamp(),
          });

      // 自動同期を実行
      await AutoSyncService.triggerAutoSyncForDataType('passcode_settings');
    } catch (e) {
      developer.log('パスコード設定保存エラー: $e', name: 'AppSettingsFirestoreService');
      rethrow;
    }
  }

  /// パスコードロック設定を取得
  static Future<Map<String, dynamic>?> getPasscodeSettings() async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('passcode')
          .get();

      return doc.exists ? doc.data() : null;
    } catch (e) {
      developer.log('パスコード設定取得エラー: $e', name: 'AppSettingsFirestoreService');
      return null;
    }
  }

  static Future<void> saveTodoNotificationSettings({
    required bool todoNotificationsEnabled,
    required int notificationTime, // 分単位
    required List<String> notificationDays, // ['monday', 'tuesday', ...]
  }) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('todo_notifications')
          .set({
            'todoNotificationsEnabled': todoNotificationsEnabled,
            'notificationTime': notificationTime,
            'notificationDays': notificationDays,
            'savedAt': FieldValue.serverTimestamp(),
          });

      // 自動同期を実行
      await AutoSyncService.triggerAutoSyncForDataType(
        'todo_notification_settings',
      );
    } catch (e) {
      developer.log('TODO通知設定保存エラー: $e', name: 'AppSettingsFirestoreService');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getTodoNotificationSettings() async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('todo_notifications')
          .get();

      return doc.exists ? doc.data() : null;
    } catch (e) {
      developer.log('TODO通知設定取得エラー: $e', name: 'AppSettingsFirestoreService');
      return null;
    }
  }

  /// 豆のシール設定を保存
  static Future<void> saveBeanStickers(List beanStickers) async {
    if (_uid == null) throw Exception('未ログイン');
    try {
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('bean_stickers')
          .set({
            'beanStickers': beanStickers.map((e) => e.toMap()).toList(),
            'savedAt': FieldValue.serverTimestamp(),
          });
      // 自動同期を実行
      await AutoSyncService.triggerAutoSyncForDataType('bean_stickers');
    } catch (e) {
      developer.log('豆のシール設定保存エラー: $e', name: 'AppSettingsFirestoreService');
      rethrow;
    }
  }

  /// 豆のシール設定を取得
  static Future<List?> getBeanStickers() async {
    if (_uid == null) throw Exception('未ログイン');
    try {
      developer.log('豆のシール設定を取得中...', name: 'AppSettingsFirestoreService');
      final doc = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('bean_stickers')
          .get();
      developer.log(
        'ドキュメント存在確認: ${doc.exists}',
        name: 'AppSettingsFirestoreService',
      );
      if (!doc.exists) {
        developer.log(
          '豆のシール設定ドキュメントが存在しません',
          name: 'AppSettingsFirestoreService',
        );
        return null;
      }
      final data = doc.data();
      developer.log('ドキュメントデータ: $data', name: 'AppSettingsFirestoreService');
      if (data == null || data['beanStickers'] == null) {
        developer.log(
          'beanStickersフィールドが存在しません',
          name: 'AppSettingsFirestoreService',
        );
        return null;
      }
      developer.log(
        '豆のシール設定取得成功: ${data['beanStickers']}',
        name: 'AppSettingsFirestoreService',
      );
      return data['beanStickers'];
    } catch (e) {
      developer.log('豆のシール設定取得エラー: $e', name: 'AppSettingsFirestoreService');
      return null;
    }
  }

  /// グループの豆のシール設定を保存
  static Future<void> saveGroupBeanStickers(
    String groupId,
    List beanStickers,
  ) async {
    if (_uid == null) throw Exception('未ログイン');
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('settings')
          .doc('bean_stickers')
          .set({
            'beanStickers': beanStickers.map((e) => e.toMap()).toList(),
            'savedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      developer.log(
        'グループ豆のシール設定保存エラー: $e',
        name: 'AppSettingsFirestoreService',
      );
      rethrow;
    }
  }

  /// グループの豆のシール設定を取得
  static Future<List?> getGroupBeanStickers(String groupId) async {
    if (_uid == null) throw Exception('未ログイン');
    try {
      final doc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('settings')
          .doc('bean_stickers')
          .get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null || data['beanStickers'] == null) return null;
      return data['beanStickers'];
    } catch (e) {
      developer.log(
        'グループ豆のシール設定取得エラー: $e',
        name: 'AppSettingsFirestoreService',
      );
      return null;
    }
  }

  /// 全アプリ設定を保存
  static Future<void> saveAllAppSettings({
    required Map<String, dynamic> soundSettings,
    required Map<String, dynamic> fontSizeSettings,
    required Map<String, dynamic> passcodeSettings,
    required Map<String, dynamic> todoNotificationSettings,
  }) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final batch = _firestore.batch();

      // 音声設定
      batch.set(
        _firestore
            .collection('users')
            .doc(_uid)
            .collection('settings')
            .doc('sound'),
        {...soundSettings, 'savedAt': FieldValue.serverTimestamp()},
      );

      // フォントサイズ設定
      batch.set(
        _firestore
            .collection('users')
            .doc(_uid)
            .collection('settings')
            .doc('font_size'),
        {...fontSizeSettings, 'savedAt': FieldValue.serverTimestamp()},
      );

      // パスコード設定
      batch.set(
        _firestore
            .collection('users')
            .doc(_uid)
            .collection('settings')
            .doc('passcode'),
        {...passcodeSettings, 'savedAt': FieldValue.serverTimestamp()},
      );

      batch.set(
        _firestore
            .collection('users')
            .doc(_uid)
            .collection('settings')
            .doc('todo_notifications'),
        {...todoNotificationSettings, 'savedAt': FieldValue.serverTimestamp()},
      );

      await batch.commit();

      // 自動同期を実行
      await AutoSyncService.triggerAutoSyncForDataType('app_settings');
    } catch (e) {
      developer.log('全アプリ設定保存エラー: $e', name: 'AppSettingsFirestoreService');
      rethrow;
    }
  }

  /// 全アプリ設定を取得
  static Future<Map<String, dynamic>> getAllAppSettings() async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final futures = await Future.wait([
        getSoundSettings(),
        getFontSizeSettings(),
        getPasscodeSettings(),
        getTodoNotificationSettings(),
      ]);

      return {
        'sound': futures[0],
        'font_size': futures[1],
        'passcode': futures[2],
        'todo_notifications': futures[3],
      };
    } catch (e) {
      developer.log('全アプリ設定取得エラー: $e', name: 'AppSettingsFirestoreService');
      return {};
    }
  }

  /// 開発者モード設定を保存
  static Future<void> saveDeveloperMode({required bool enabled}) async {
    if (_uid == null) throw Exception('未ログイン');
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('settings')
        .doc('developerMode')
        .set({'enabled': enabled, 'savedAt': FieldValue.serverTimestamp()});
  }

  /// 開発者モード設定を取得
  static Future<bool> getDeveloperMode() async {
    if (_uid == null) throw Exception('未ログイン');
    final doc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('settings')
        .doc('developerMode')
        .get();
    if (!doc.exists) return false;
    final data = doc.data();
    return data?['enabled'] ?? false;
  }
}
