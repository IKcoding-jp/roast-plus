import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import '../utils/security_config.dart';

/// 暗号化されたローカルストレージサービス
/// SharedPreferencesの代わりに使用し、すべてのデータを暗号化して保存
class EncryptedLocalStorageService {
  static const String _logName = 'EncryptedLocalStorageService';
  static SharedPreferences? _prefs;

  /// 初期化
  static Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      developer.log('暗号化ローカルストレージサービスを初期化しました', name: _logName);
    } catch (e) {
      developer.log('暗号化ローカルストレージサービスの初期化に失敗しました: $e', name: _logName);
      rethrow;
    }
  }

  /// 文字列を暗号化して保存
  static Future<bool> setString(String key, String value) async {
    try {
      if (_prefs == null) await initialize();

      final encryptedValue = SecurityConfig.encryptToken(value);
      final result = await _prefs!.setString(key, encryptedValue);

      developer.log('文字列を暗号化して保存しました: $key', name: _logName);
      return result;
    } catch (e) {
      developer.log('文字列の暗号化保存に失敗しました: $key, $e', name: _logName);
      return false;
    }
  }

  /// 暗号化された文字列を取得・復号化
  static Future<String?> getString(String key) async {
    try {
      if (_prefs == null) await initialize();

      final encryptedValue = _prefs!.getString(key);
      if (encryptedValue == null) return null;

      final decryptedValue = SecurityConfig.decryptToken(encryptedValue);
      developer.log('暗号化された文字列を復号化しました: $key', name: _logName);
      return decryptedValue;
    } catch (e) {
      developer.log('暗号化された文字列の取得に失敗しました: $key, $e', name: _logName);
      return null;
    }
  }

  /// 整数を暗号化して保存
  static Future<bool> setInt(String key, int value) async {
    try {
      if (_prefs == null) await initialize();

      final encryptedValue = SecurityConfig.encryptToken(value.toString());
      final result = await _prefs!.setString(key, encryptedValue);

      developer.log('整数を暗号化して保存しました: $key', name: _logName);
      return result;
    } catch (e) {
      developer.log('整数の暗号化保存に失敗しました: $key, $e', name: _logName);
      return false;
    }
  }

  /// 暗号化された整数を取得・復号化
  static Future<int?> getInt(String key) async {
    try {
      if (_prefs == null) await initialize();

      final encryptedValue = _prefs!.getString(key);
      if (encryptedValue == null) return null;

      final decryptedValue = SecurityConfig.decryptToken(encryptedValue);
      final intValue = int.tryParse(decryptedValue);

      developer.log('暗号化された整数を復号化しました: $key', name: _logName);
      return intValue;
    } catch (e) {
      developer.log('暗号化された整数の取得に失敗しました: $key, $e', name: _logName);
      return null;
    }
  }

  /// 倍精度浮動小数点数を暗号化して保存
  static Future<bool> setDouble(String key, double value) async {
    try {
      if (_prefs == null) await initialize();

      final encryptedValue = SecurityConfig.encryptToken(value.toString());
      final result = await _prefs!.setString(key, encryptedValue);

      developer.log('倍精度浮動小数点数を暗号化して保存しました: $key', name: _logName);
      return result;
    } catch (e) {
      developer.log('倍精度浮動小数点数の暗号化保存に失敗しました: $key, $e', name: _logName);
      return false;
    }
  }

  /// 暗号化された倍精度浮動小数点数を取得・復号化
  static Future<double?> getDouble(String key) async {
    try {
      if (_prefs == null) await initialize();

      final encryptedValue = _prefs!.getString(key);
      if (encryptedValue == null) return null;

      final decryptedValue = SecurityConfig.decryptToken(encryptedValue);
      final doubleValue = double.tryParse(decryptedValue);

      developer.log('暗号化された倍精度浮動小数点数を復号化しました: $key', name: _logName);
      return doubleValue;
    } catch (e) {
      developer.log('暗号化された倍精度浮動小数点数の取得に失敗しました: $key, $e', name: _logName);
      return null;
    }
  }

  /// 真偽値を暗号化して保存
  static Future<bool> setBool(String key, bool value) async {
    try {
      if (_prefs == null) await initialize();

      final encryptedValue = SecurityConfig.encryptToken(value.toString());
      final result = await _prefs!.setString(key, encryptedValue);

      developer.log('真偽値を暗号化して保存しました: $key', name: _logName);
      return result;
    } catch (e) {
      developer.log('真偽値の暗号化保存に失敗しました: $key, $e', name: _logName);
      return false;
    }
  }

  /// 暗号化された真偽値を取得・復号化
  static Future<bool?> getBool(String key) async {
    try {
      if (_prefs == null) await initialize();

      final encryptedValue = _prefs!.getString(key);
      if (encryptedValue == null) return null;

      final decryptedValue = SecurityConfig.decryptToken(encryptedValue);
      final boolValue = decryptedValue == 'true';

      developer.log('暗号化された真偽値を復号化しました: $key', name: _logName);
      return boolValue;
    } catch (e) {
      developer.log('暗号化された真偽値の取得に失敗しました: $key, $e', name: _logName);
      return null;
    }
  }

  /// 文字列リストを暗号化して保存
  static Future<bool> setStringList(String key, List<String> value) async {
    try {
      if (_prefs == null) await initialize();

      final jsonString = jsonEncode(value);
      final encryptedValue = SecurityConfig.encryptToken(jsonString);
      final result = await _prefs!.setString(key, encryptedValue);

      developer.log('文字列リストを暗号化して保存しました: $key', name: _logName);
      return result;
    } catch (e) {
      developer.log('文字列リストの暗号化保存に失敗しました: $key, $e', name: _logName);
      return false;
    }
  }

  /// 暗号化された文字列リストを取得・復号化
  static Future<List<String>?> getStringList(String key) async {
    try {
      if (_prefs == null) await initialize();

      final encryptedValue = _prefs!.getString(key);
      if (encryptedValue == null) return null;

      final decryptedValue = SecurityConfig.decryptToken(encryptedValue);
      final List<dynamic> jsonList = jsonDecode(decryptedValue);
      final stringList = jsonList.cast<String>().toList();

      developer.log('暗号化された文字列リストを復号化しました: $key', name: _logName);
      return stringList;
    } catch (e) {
      developer.log('暗号化された文字列リストの取得に失敗しました: $key, $e', name: _logName);
      return null;
    }
  }

  /// マップを暗号化して保存
  static Future<bool> setMap(String key, Map<String, dynamic> value) async {
    try {
      if (_prefs == null) await initialize();

      final jsonString = jsonEncode(value);
      final encryptedValue = SecurityConfig.encryptToken(jsonString);
      final result = await _prefs!.setString(key, encryptedValue);

      developer.log('マップを暗号化して保存しました: $key', name: _logName);
      return result;
    } catch (e) {
      developer.log('マップの暗号化保存に失敗しました: $key, $e', name: _logName);
      return false;
    }
  }

  /// 暗号化されたマップを取得・復号化
  static Future<Map<String, dynamic>?> getMap(String key) async {
    try {
      if (_prefs == null) await initialize();

      final encryptedValue = _prefs!.getString(key);
      if (encryptedValue == null) return null;

      final decryptedValue = SecurityConfig.decryptToken(encryptedValue);
      final Map<String, dynamic> map = jsonDecode(decryptedValue);

      developer.log('暗号化されたマップを復号化しました: $key', name: _logName);
      return map;
    } catch (e) {
      developer.log('暗号化されたマップの取得に失敗しました: $key, $e', name: _logName);
      return null;
    }
  }

  /// キーが存在するかチェック
  static Future<bool> containsKey(String key) async {
    try {
      if (_prefs == null) await initialize();
      return _prefs!.containsKey(key);
    } catch (e) {
      developer.log('キー存在チェックに失敗しました: $key, $e', name: _logName);
      return false;
    }
  }

  /// 指定されたキーのデータを削除
  static Future<bool> remove(String key) async {
    try {
      if (_prefs == null) await initialize();
      final result = await _prefs!.remove(key);
      developer.log('暗号化データを削除しました: $key', name: _logName);
      return result;
    } catch (e) {
      developer.log('暗号化データの削除に失敗しました: $key, $e', name: _logName);
      return false;
    }
  }

  /// すべての暗号化データを削除
  static Future<bool> clear() async {
    try {
      if (_prefs == null) await initialize();
      final result = await _prefs!.clear();
      developer.log('すべての暗号化データを削除しました', name: _logName);
      return result;
    } catch (e) {
      developer.log('すべての暗号化データの削除に失敗しました: $e', name: _logName);
      return false;
    }
  }

  /// すべてのキーを取得
  static Future<Set<String>> getKeys() async {
    try {
      if (_prefs == null) await initialize();
      return _prefs!.getKeys();
    } catch (e) {
      developer.log('キー一覧の取得に失敗しました: $e', name: _logName);
      return <String>{};
    }
  }

  /// データの整合性をチェック
  static Future<bool> validateDataIntegrity() async {
    try {
      if (_prefs == null) await initialize();

      final keys = _prefs!.getKeys();
      int validCount = 0;
      int totalCount = keys.length;

      for (final key in keys) {
        try {
          final value = _prefs!.getString(key);
          if (value != null) {
            // 復号化テスト
            SecurityConfig.decryptToken(value);
            validCount++;
          }
        } catch (e) {
          developer.log('データ整合性チェックでエラー: $key, $e', name: _logName);
        }
      }

      final integrity = validCount == totalCount;
      developer.log('データ整合性チェック完了: $validCount/$totalCount 有効', name: _logName);
      return integrity;
    } catch (e) {
      developer.log('データ整合性チェックに失敗しました: $e', name: _logName);
      return false;
    }
  }

  /// 暗号化統計を取得
  static Future<Map<String, dynamic>> getEncryptionStats() async {
    try {
      if (_prefs == null) await initialize();

      final keys = _prefs!.getKeys();
      int encryptedCount = 0;
      int totalCount = keys.length;

      for (final key in keys) {
        try {
          final value = _prefs!.getString(key);
          if (value != null) {
            // 暗号化されているかチェック（復号化可能かテスト）
            SecurityConfig.decryptToken(value);
            encryptedCount++;
          }
        } catch (e) {
          // 復号化できない場合は暗号化されていないとみなす
        }
      }

      return {
        'totalKeys': totalCount,
        'encryptedKeys': encryptedCount,
        'encryptionRate': totalCount > 0
            ? (encryptedCount / totalCount * 100).toStringAsFixed(1)
            : '0.0',
        'lastChecked': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      developer.log('暗号化統計の取得に失敗しました: $e', name: _logName);
      return {
        'totalKeys': 0,
        'encryptedKeys': 0,
        'encryptionRate': '0.0',
        'lastChecked': DateTime.now().toIso8601String(),
        'error': e.toString(),
      };
    }
  }
}
