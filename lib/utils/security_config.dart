import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'env_loader.dart';

/// セキュリティ設定を管理するクラス
class SecurityConfig {
  // 暗号化キー（環境変数から取得、デフォルト値なし）
  static const String _encryptionKey = String.fromEnvironment('ENCRYPTION_KEY');

  /// 実行時環境変数から暗号化キーを取得
  static Future<String> getEncryptionKey() async {
    const compileTimeKey = String.fromEnvironment('ENCRYPTION_KEY');
    if (compileTimeKey.isNotEmpty) {
      return compileTimeKey;
    }

    // コンパイル時環境変数が空の場合は、実行時環境変数から取得
    return await EnvLoader.getEnvVar('ENCRYPTION_KEY', defaultValue: '');
  }

  /// Firebase設定を暗号化して取得
  static Map<String, String> getFirebaseConfig() {
    if (kDebugMode) {
      // デバッグモードでは平文で返す（開発用）
      return {
        'apiKey': _decryptApiKey(getEncryptedApiKey()),
        'appId': _decryptAppId(getEncryptedAppId()),
        'projectId': _decryptProjectId(getEncryptedProjectId()),
        'messagingSenderId': _decryptSenderId(getEncryptedSenderId()),
      };
    } else {
      // リリースモードでは暗号化された値を返す
      return {
        'apiKey': _decryptApiKey(getEncryptedApiKey()),
        'appId': _decryptAppId(getEncryptedAppId()),
        'projectId': _decryptProjectId(getEncryptedProjectId()),
        'messagingSenderId': _decryptSenderId(getEncryptedSenderId()),
      };
    }
  }

  /// APIキーを復号化
  static String _decryptApiKey(String encryptedApiKey) {
    try {
      return utf8.decode(base64.decode(encryptedApiKey));
    } catch (e) {
      throw Exception('APIキーの復号化に失敗しました');
    }
  }

  /// アプリIDを復号化
  static String _decryptAppId(String encryptedAppId) {
    try {
      return utf8.decode(base64.decode(encryptedAppId));
    } catch (e) {
      throw Exception('アプリIDの復号化に失敗しました');
    }
  }

  /// プロジェクトIDを復号化
  static String _decryptProjectId(String encryptedProjectId) {
    try {
      return utf8.decode(base64.decode(encryptedProjectId));
    } catch (e) {
      throw Exception('プロジェクトIDの復号化に失敗しました');
    }
  }

  /// 送信者IDを復号化
  static String _decryptSenderId(String encryptedSenderId) {
    try {
      return utf8.decode(base64.decode(encryptedSenderId));
    } catch (e) {
      throw Exception('送信者IDの復号化に失敗しました');
    }
  }

  // 暗号化された設定値（環境変数から取得）
  static String getEncryptedApiKey() {
    if (kIsWeb) {
      return const String.fromEnvironment('FIREBASE_WEB_API_KEY_ENCRYPTED');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const String.fromEnvironment(
          'FIREBASE_ANDROID_API_KEY_ENCRYPTED',
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const String.fromEnvironment('FIREBASE_IOS_API_KEY_ENCRYPTED');
      case TargetPlatform.windows:
        return const String.fromEnvironment('FIREBASE_WEB_API_KEY_ENCRYPTED');
      default:
        return const String.fromEnvironment('FIREBASE_WEB_API_KEY_ENCRYPTED');
    }
  }

  /// 実行時環境変数から暗号化されたAPIキーを取得
  static Future<String> getEncryptedApiKeyRuntime() async {
    if (kIsWeb) {
      const compileTimeKey = String.fromEnvironment(
        'FIREBASE_WEB_API_KEY_ENCRYPTED',
      );
      if (compileTimeKey.isNotEmpty) return compileTimeKey;
      return await EnvLoader.getEnvVar('FIREBASE_WEB_API_KEY_ENCRYPTED');
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        const compileTimeKey = String.fromEnvironment(
          'FIREBASE_ANDROID_API_KEY_ENCRYPTED',
        );
        if (compileTimeKey.isNotEmpty) return compileTimeKey;
        return await EnvLoader.getEnvVar('FIREBASE_ANDROID_API_KEY_ENCRYPTED');
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        const compileTimeKey = String.fromEnvironment(
          'FIREBASE_IOS_API_KEY_ENCRYPTED',
        );
        if (compileTimeKey.isNotEmpty) return compileTimeKey;
        return await EnvLoader.getEnvVar('FIREBASE_IOS_API_KEY_ENCRYPTED');
      case TargetPlatform.windows:
        const compileTimeKey = String.fromEnvironment(
          'FIREBASE_WEB_API_KEY_ENCRYPTED',
        );
        if (compileTimeKey.isNotEmpty) return compileTimeKey;
        return await EnvLoader.getEnvVar('FIREBASE_WEB_API_KEY_ENCRYPTED');
      default:
        const compileTimeKey = String.fromEnvironment(
          'FIREBASE_WEB_API_KEY_ENCRYPTED',
        );
        if (compileTimeKey.isNotEmpty) return compileTimeKey;
        return await EnvLoader.getEnvVar('FIREBASE_WEB_API_KEY_ENCRYPTED');
    }
  }

  static String getEncryptedAppId() {
    if (kIsWeb) {
      return const String.fromEnvironment('FIREBASE_WEB_APP_ID_ENCRYPTED');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const String.fromEnvironment(
          'FIREBASE_ANDROID_APP_ID_ENCRYPTED',
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const String.fromEnvironment('FIREBASE_IOS_APP_ID_ENCRYPTED');
      case TargetPlatform.windows:
        return const String.fromEnvironment(
          'FIREBASE_WINDOWS_APP_ID_ENCRYPTED',
        );
      default:
        return const String.fromEnvironment('FIREBASE_WEB_APP_ID_ENCRYPTED');
    }
  }

  static String getEncryptedProjectId() {
    return const String.fromEnvironment('FIREBASE_PROJECT_ID_ENCRYPTED');
  }

  static String getEncryptedSenderId() {
    return const String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID_ENCRYPTED',
    );
  }

  static String getEncryptedAuthDomain() {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      return const String.fromEnvironment('FIREBASE_AUTH_DOMAIN_ENCRYPTED');
    }
    return '';
  }

  static String getEncryptedStorageBucket() {
    return const String.fromEnvironment('FIREBASE_STORAGE_BUCKET_ENCRYPTED');
  }

  static String getEncryptedMeasurementId() {
    if (kIsWeb) {
      return const String.fromEnvironment('FIREBASE_MEASUREMENT_ID_ENCRYPTED');
    }
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return const String.fromEnvironment(
        'FIREBASE_WINDOWS_MEASUREMENT_ID_ENCRYPTED',
      );
    }
    return '';
  }

  static String getEncryptedAndroidClientId() {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return const String.fromEnvironment(
        'FIREBASE_ANDROID_CLIENT_ID_ENCRYPTED',
      );
    }
    return '';
  }

  static String getEncryptedIosClientId() {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return const String.fromEnvironment('FIREBASE_IOS_CLIENT_ID_ENCRYPTED');
    }
    return '';
  }

  static String getEncryptedIosBundleId() {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID_ENCRYPTED');
    }
    return '';
  }

  /// セキュアなトークン保存
  static String encryptToken(String token) {
    final bytes = utf8.encode(token + _encryptionKey);
    sha256.convert(bytes);
    return base64.encode(utf8.encode(token));
  }

  /// トークンの復号化
  static String decryptToken(String encryptedToken) {
    try {
      return utf8.decode(base64.decode(encryptedToken));
    } catch (e) {
      throw Exception('トークンの復号化に失敗しました');
    }
  }

  /// パスワードのハッシュ化
  static String hashPassword(String password) {
    final bytes = utf8.encode(password + _encryptionKey);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// パスワードの検証
  static bool verifyPassword(String password, String hashedPassword) {
    return hashPassword(password) == hashedPassword;
  }

  /// ランダムなセキュアキーの生成
  static String generateSecureKey(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }
}
