import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:developer' as developer;

/// ユーザー設定をFirestoreに保存・取得するサービス
class UserSettingsFirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static const String _logName = 'UserSettingsFirestoreService';
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

  static String? get _uid => _auth.currentUser?.uid;

  /// ユーザー設定コレクションの参照を取得
  static CollectionReference<Map<String, dynamic>> get _userSettingsCollection {
    if (_uid == null) throw Exception('未ログイン');
    return _firestore.collection('users').doc(_uid).collection('settings');
  }

  /// 設定を保存
  static Future<void> saveSetting(String key, dynamic value) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      await _userSettingsCollection.doc(key).set({
        'value': value,
        'type': _getValueType(value),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _logInfo('設定を保存しました: $key = $value');
    } catch (e, st) {
      _logError('設定保存エラー', e, st);
      rethrow;
    }
  }

  /// 設定を取得
  static Future<dynamic> getSetting(String key, {dynamic defaultValue}) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final doc = await _userSettingsCollection.doc(key).get();
      if (!doc.exists) return defaultValue;

      final data = doc.data()!;
      return _convertValue(data['value'], data['type']);
    } catch (e, st) {
      _logError('設定取得エラー', e, st);
      return defaultValue;
    }
  }

  /// 複数の設定を一括保存
  static Future<void> saveMultipleSettings(
    Map<String, dynamic> settings,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final batch = _firestore.batch();

      for (final entry in settings.entries) {
        final docRef = _userSettingsCollection.doc(entry.key);
        batch.set(docRef, {
          'value': entry.value,
          'type': _getValueType(entry.value),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      _logInfo('複数設定を保存しました: ${settings.keys.join(', ')}');
    } catch (e, st) {
      _logError('複数設定保存エラー', e, st);
      rethrow;
    }
  }

  /// 複数の設定を一括取得
  static Future<Map<String, dynamic>> getMultipleSettings(
    List<String> keys,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final Map<String, dynamic> result = {};

      for (final key in keys) {
        final doc = await _userSettingsCollection.doc(key).get();
        if (doc.exists) {
          final data = doc.data()!;
          result[key] = _convertValue(data['value'], data['type']);
        }
      }

      return result;
    } catch (e, st) {
      _logError('複数設定取得エラー', e, st);
      return {};
    }
  }

  /// 設定を削除
  static Future<void> deleteSetting(String key) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      await _userSettingsCollection.doc(key).delete();
      _logInfo('設定を削除しました: $key');
    } catch (e, st) {
      _logError('設定削除エラー', e, st);
      rethrow;
    }
  }

  /// すべての設定を取得
  static Future<Map<String, dynamic>> getAllSettings() async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final snapshot = await _userSettingsCollection.get();
      final Map<String, dynamic> result = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        result[doc.id] = _convertValue(data['value'], data['type']);
      }

      return result;
    } catch (e, st) {
      _logError('全設定取得エラー', e, st);
      return {};
    }
  }

  /// 値の型を取得
  static String _getValueType(dynamic value) {
    if (value is String) return 'string';
    if (value is int) return 'int';
    if (value is double) return 'double';
    if (value is bool) return 'bool';
    if (value is List) return 'list';
    if (value is Map) return 'map';
    return 'string';
  }

  /// 値を適切な型に変換
  static dynamic _convertValue(dynamic value, String type) {
    switch (type) {
      case 'string':
        return value.toString();
      case 'int':
        return int.tryParse(value.toString()) ?? 0;
      case 'double':
        return double.tryParse(value.toString()) ?? 0.0;
      case 'bool':
        return value == true || value == 'true';
      case 'list':
        if (value is List) return value;
        if (value is String) {
          try {
            return json.decode(value) as List;
          } catch (e) {
            return [];
          }
        }
        return [];
      case 'map':
        if (value is Map) return value;
        if (value is String) {
          try {
            return json.decode(value) as Map<String, dynamic>;
          } catch (e) {
            return {};
          }
        }
        return {};
      default:
        return value.toString();
    }
  }

  /// 設定の変更を監視
  static Stream<Map<String, dynamic>> watchSettings(List<String> keys) {
    if (_uid == null) {
      return Stream.value({});
    }

    return _userSettingsCollection.snapshots().map((snapshot) {
      final Map<String, dynamic> result = {};

      for (final doc in snapshot.docs) {
        if (keys.contains(doc.id)) {
          final data = doc.data();
          result[doc.id] = _convertValue(data['value'], data['type']);
        }
      }

      return result;
    });
  }

  /// 特定の設定の変更を監視
  static Stream<dynamic> watchSetting(String key, {dynamic defaultValue}) {
    if (_uid == null) {
      return Stream.value(defaultValue);
    }

    return _userSettingsCollection.doc(key).snapshots().map((doc) {
      if (!doc.exists) return defaultValue;

      final data = doc.data()!;
      return _convertValue(data['value'], data['type']);
    });
  }

  /// テーマ設定を一括保存（最適化版）
  static Future<void> saveThemeSettingsOptimized(
    Map<String, dynamic> themeSettings,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      // テーマ設定を1つのドキュメントにまとめて保存
      await _userSettingsCollection.doc('theme_settings').set({
        'themeData': themeSettings,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _logInfo('テーマ設定を最適化保存: ${themeSettings.keys.length}個の設定');
    } catch (e, st) {
      _logError('テーマ設定最適化保存エラー', e, st);
      rethrow;
    }
  }
}
