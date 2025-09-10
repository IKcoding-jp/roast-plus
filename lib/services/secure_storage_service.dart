import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import '../utils/security_config.dart';

/// セキュアストレージサービス
/// 機密情報を安全に保存・取得するためのサービス
class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  static const String _logName = 'SecureStorageService';

  /// Web版ではSharedPreferencesを使用、ネイティブ版ではFlutterSecureStorageを使用
  static Future<void> _write(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  static Future<String?> _read(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } else {
      return await _storage.read(key: key);
    }
  }

  static Future<void> _delete(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } else {
      await _storage.delete(key: key);
    }
  }

  static Future<void> _deleteAll() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } else {
      await _storage.deleteAll();
    }
  }

  // キー定数
  static const String _keyAccessToken = 'access_token';
  static const String _keyIdToken = 'id_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyPasscode = 'app_passcode';
  static const String _keyEncryptionKey = 'encryption_key';
  static const String _keyUserCredentials = 'user_credentials';

  /// アクセストークンを安全に保存
  static Future<void> saveAccessToken(String token) async {
    try {
      final encryptedToken = SecurityConfig.encryptToken(token);
      await _write(_keyAccessToken, encryptedToken);
      developer.log('アクセストークンを安全に保存しました', name: _logName);
    } catch (e) {
      developer.log('アクセストークンの保存に失敗しました: $e', name: _logName);
      rethrow;
    }
  }

  /// アクセストークンを安全に取得
  static Future<String?> getAccessToken() async {
    try {
      final encryptedToken = await _read(_keyAccessToken);
      if (encryptedToken == null) return null;

      return SecurityConfig.decryptToken(encryptedToken);
    } catch (e) {
      developer.log('アクセストークンの取得に失敗しました: $e', name: _logName);
      return null;
    }
  }

  /// IDトークンを安全に保存
  static Future<void> saveIdToken(String token) async {
    try {
      final encryptedToken = SecurityConfig.encryptToken(token);
      await _write(_keyIdToken, encryptedToken);
      developer.log('IDトークンを安全に保存しました', name: _logName);
    } catch (e) {
      developer.log('IDトークンの保存に失敗しました: $e', name: _logName);
      rethrow;
    }
  }

  /// IDトークンを安全に取得
  static Future<String?> getIdToken() async {
    try {
      final encryptedToken = await _read(_keyIdToken);
      if (encryptedToken == null) return null;

      return SecurityConfig.decryptToken(encryptedToken);
    } catch (e) {
      developer.log('IDトークンの取得に失敗しました: $e', name: _logName);
      return null;
    }
  }

  /// リフレッシュトークンを安全に保存
  static Future<void> saveRefreshToken(String token) async {
    try {
      final encryptedToken = SecurityConfig.encryptToken(token);
      await _write(_keyRefreshToken, encryptedToken);
      developer.log('リフレッシュトークンを安全に保存しました', name: _logName);
    } catch (e) {
      developer.log('リフレッシュトークンの保存に失敗しました: $e', name: _logName);
      rethrow;
    }
  }

  /// リフレッシュトークンを安全に取得
  static Future<String?> getRefreshToken() async {
    try {
      final encryptedToken = await _read(_keyRefreshToken);
      if (encryptedToken == null) return null;

      return SecurityConfig.decryptToken(encryptedToken);
    } catch (e) {
      developer.log('リフレッシュトークンの取得に失敗しました: $e', name: _logName);
      return null;
    }
  }

  /// パスコードを安全に保存
  static Future<void> savePasscode(String passcode) async {
    try {
      final hashedPasscode = SecurityConfig.hashPassword(passcode);
      await _write(_keyPasscode, hashedPasscode);
      developer.log('パスコードを安全に保存しました', name: _logName);
    } catch (e) {
      developer.log('パスコードの保存に失敗しました: $e', name: _logName);
      rethrow;
    }
  }

  /// パスコードを検証
  static Future<bool> verifyPasscode(String passcode) async {
    try {
      final storedHash = await _read(_keyPasscode);
      if (storedHash == null) return false;

      return SecurityConfig.verifyPassword(passcode, storedHash);
    } catch (e) {
      developer.log('パスコードの検証に失敗しました: $e', name: _logName);
      return false;
    }
  }

  /// 暗号化キーを安全に保存
  static Future<void> saveEncryptionKey(String key) async {
    try {
      await _write(_keyEncryptionKey, key);
      developer.log('暗号化キーを安全に保存しました', name: _logName);
    } catch (e) {
      developer.log('暗号化キーの保存に失敗しました: $e', name: _logName);
      rethrow;
    }
  }

  /// 暗号化キーを安全に取得
  static Future<String?> getEncryptionKey() async {
    try {
      return await _read(_keyEncryptionKey);
    } catch (e) {
      developer.log('暗号化キーの取得に失敗しました: $e', name: _logName);
      return null;
    }
  }

  /// ユーザー認証情報を安全に保存
  static Future<void> saveUserCredentials({
    required String email,
    required String password,
  }) async {
    try {
      final hashedPassword = SecurityConfig.hashPassword(password);
      final credentials = {
        'email': email,
        'password': hashedPassword,
        'savedAt': DateTime.now().toIso8601String(),
      };

      await _write(_keyUserCredentials, credentials.toString());
      developer.log('ユーザー認証情報を安全に保存しました', name: _logName);
    } catch (e) {
      developer.log('ユーザー認証情報の保存に失敗しました: $e', name: _logName);
      rethrow;
    }
  }

  /// ユーザー認証情報を安全に取得
  static Future<Map<String, dynamic>?> getUserCredentials() async {
    try {
      final credentials = await _read(_keyUserCredentials);
      if (credentials == null) return null;

      // 文字列からMapに変換（実際の実装ではJSONを使用）
      return {'credentials': credentials};
    } catch (e) {
      developer.log('ユーザー認証情報の取得に失敗しました: $e', name: _logName);
      return null;
    }
  }

  /// すべての機密情報を削除
  static Future<void> clearAllSecureData() async {
    try {
      await _deleteAll();
      developer.log('すべての機密情報を削除しました', name: _logName);
    } catch (e) {
      developer.log('機密情報の削除に失敗しました: $e', name: _logName);
      rethrow;
    }
  }

  /// 特定のキーの機密情報を削除
  static Future<void> deleteSecureData(String key) async {
    try {
      await _delete(key);
      developer.log('機密情報を削除しました: $key', name: _logName);
    } catch (e) {
      developer.log('機密情報の削除に失敗しました: $e', name: _logName);
      rethrow;
    }
  }

  /// セキュアストレージが利用可能かチェック
  static Future<bool> isSecureStorageAvailable() async {
    try {
      const testKey = 'test_availability';
      const testValue = 'test_value';

      await _write(testKey, testValue);
      final readValue = await _read(testKey);
      await _delete(testKey);

      return readValue == testValue;
    } catch (e) {
      developer.log('セキュアストレージが利用できません: $e', name: _logName);
      return false;
    }
  }

  /// パスコードが設定されているかチェック
  static Future<bool> hasPasscode() async {
    try {
      final passcode = await _read(_keyPasscode);
      return passcode != null;
    } catch (e) {
      developer.log('パスコード存在確認に失敗しました: $e', name: _logName);
      return false;
    }
  }
}
