import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'env_loader.dart';
import 'common_utils.dart';
import 'app_logger.dart';

/// セキュリティ設定を管理するクラス
class SecurityConfig {
  // 暗号化キー（環境変数から取得、デフォルト値なし）
  // NOTE: このキーは実行環境で設定すること。ソースに直接配置しないこと。
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
  static Future<Map<String, String>> getFirebaseConfig() async {
    if (kDebugMode) {
      // デバッグモードでは平文で返す（開発用）
      return {
        'apiKey': _decryptApiKey(await getEncryptedApiKey()),
        'appId': _decryptAppId(await getEncryptedAppId()),
        'projectId': _decryptProjectId(await getEncryptedProjectId()),
        'messagingSenderId': _decryptSenderId(await getEncryptedSenderId()),
      };
    } else {
      // リリースモードでは暗号化された値を返す
      return {
        'apiKey': _decryptApiKey(await getEncryptedApiKey()),
        'appId': _decryptAppId(await getEncryptedAppId()),
        'projectId': _decryptProjectId(await getEncryptedProjectId()),
        'messagingSenderId': _decryptSenderId(await getEncryptedSenderId()),
      };
    }
  }

  /// APIキーを取得して必要なら Base64 デコードする
  ///
  /// 注意: Base64 は暗号化ではなくエンコードであるため、秘匿性はありません。
  /// 本番では CI/CD の Secrets や KMS を使用してください。
  static String _decryptApiKey(String encryptedApiKey) {
    try {
      final decoded = CommonUtils.decodeBase64IfPossible(encryptedApiKey);
      if (decoded != encryptedApiKey) {
        AppLogger.warn('APIキーが Base64 からデコードされました', name: 'SecurityConfig');
      }
      return decoded;
    } catch (e, st) {
      AppLogger.error(
        'APIキーの復号化に失敗しました',
        name: 'SecurityConfig',
        error: e,
        stackTrace: st,
      );
      throw Exception('APIキーの復号化に失敗しました');
    }
  }

  /// アプリIDを復号化
  /// App ID を取得して必要なら Base64 デコードする
  static String _decryptAppId(String encryptedAppId) {
    try {
      final decoded = CommonUtils.decodeBase64IfPossible(encryptedAppId);
      return decoded;
    } catch (e, st) {
      AppLogger.error(
        'アプリIDの復号化に失敗しました',
        name: 'SecurityConfig',
        error: e,
        stackTrace: st,
      );
      throw Exception('アプリIDの復号化に失敗しました');
    }
  }

  /// プロジェクトIDを復号化
  /// Project ID を取得して必要なら Base64 デコードする
  static String _decryptProjectId(String encryptedProjectId) {
    try {
      final decoded = CommonUtils.decodeBase64IfPossible(encryptedProjectId);
      return decoded;
    } catch (e, st) {
      AppLogger.error(
        'プロジェクトIDの復号化に失敗しました',
        name: 'SecurityConfig',
        error: e,
        stackTrace: st,
      );
      throw Exception('プロジェクトIDの復号化に失敗しました');
    }
  }

  /// 送信者IDを復号化
  /// Messaging Sender ID を取得して必要なら Base64 デコードする
  static String _decryptSenderId(String encryptedSenderId) {
    try {
      final decoded = CommonUtils.decodeBase64IfPossible(encryptedSenderId);
      return decoded;
    } catch (e, st) {
      AppLogger.error(
        '送信者IDの復号化に失敗しました',
        name: 'SecurityConfig',
        error: e,
        stackTrace: st,
      );
      throw Exception('送信者IDの復号化に失敗しました');
    }
  }

  // 暗号化された設定値（環境変数から取得）
  static Future<String> getEncryptedApiKey() async {
    if (kIsWeb) {
      return await EnvLoader.getEnvVar('FIREBASE_WEB_API_KEY_ENCRYPTED');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return await EnvLoader.getEnvVar('FIREBASE_ANDROID_API_KEY_ENCRYPTED');
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return await EnvLoader.getEnvVar('FIREBASE_IOS_API_KEY_ENCRYPTED');
      case TargetPlatform.windows:
        return await EnvLoader.getEnvVar('FIREBASE_WEB_API_KEY_ENCRYPTED');
      default:
        return await EnvLoader.getEnvVar('FIREBASE_WEB_API_KEY_ENCRYPTED');
    }
  }

  /// 実行時環境変数から暗号化されたAPIキーを取得
  static Future<String> getEncryptedApiKeyRuntime() async {
    if (kIsWeb) {
      return await EnvLoader.getEnvVar('FIREBASE_WEB_API_KEY_ENCRYPTED');
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return await EnvLoader.getEnvVar('FIREBASE_ANDROID_API_KEY_ENCRYPTED');
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return await EnvLoader.getEnvVar('FIREBASE_IOS_API_KEY_ENCRYPTED');
      case TargetPlatform.windows:
        return await EnvLoader.getEnvVar('FIREBASE_WEB_API_KEY_ENCRYPTED');
      default:
        return await EnvLoader.getEnvVar('FIREBASE_WEB_API_KEY_ENCRYPTED');
    }
  }

  static Future<String> getEncryptedAppId() async {
    if (kIsWeb) {
      return await EnvLoader.getEnvVar('FIREBASE_WEB_APP_ID_ENCRYPTED');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return await EnvLoader.getEnvVar('FIREBASE_ANDROID_APP_ID_ENCRYPTED');
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return await EnvLoader.getEnvVar('FIREBASE_IOS_APP_ID_ENCRYPTED');
      case TargetPlatform.windows:
        return await EnvLoader.getEnvVar('FIREBASE_WINDOWS_APP_ID_ENCRYPTED');
      default:
        return await EnvLoader.getEnvVar('FIREBASE_WEB_APP_ID_ENCRYPTED');
    }
  }

  static Future<String> getEncryptedProjectId() async {
    return await EnvLoader.getEnvVar('FIREBASE_PROJECT_ID_ENCRYPTED');
  }

  static Future<String> getEncryptedSenderId() async {
    return await EnvLoader.getEnvVar('FIREBASE_MESSAGING_SENDER_ID_ENCRYPTED');
  }

  static Future<String> getEncryptedAuthDomain() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      return await EnvLoader.getEnvVar('FIREBASE_AUTH_DOMAIN_ENCRYPTED');
    }
    return '';
  }

  static Future<String> getEncryptedStorageBucket() async {
    return await EnvLoader.getEnvVar('FIREBASE_STORAGE_BUCKET_ENCRYPTED');
  }

  static Future<String> getEncryptedMeasurementId() async {
    if (kIsWeb) {
      return await EnvLoader.getEnvVar('FIREBASE_MEASUREMENT_ID_ENCRYPTED');
    }
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return await EnvLoader.getEnvVar(
        'FIREBASE_WINDOWS_MEASUREMENT_ID_ENCRYPTED',
      );
    }
    return '';
  }

  static Future<String> getEncryptedAndroidClientId() async {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return await EnvLoader.getEnvVar('FIREBASE_ANDROID_CLIENT_ID_ENCRYPTED');
    }
    return '';
  }

  static Future<String> getEncryptedIosClientId() async {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return await EnvLoader.getEnvVar('FIREBASE_IOS_CLIENT_ID_ENCRYPTED');
    }
    return '';
  }

  static Future<String> getEncryptedIosBundleId() async {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return await EnvLoader.getEnvVar('FIREBASE_IOS_BUNDLE_ID_ENCRYPTED');
    }
    return '';
  }

  /// トークンを（簡易的に）エンコードして返す
  ///
  /// 現状は Base64 エンコードを返す実装で、SHA256 の結果は利用していません。
  /// この実装は互換性維持のため残していますが、本番では
  /// シークレット管理 / KMS を使った暗号化を推奨します。
  static String encryptToken(String token) {
    // 警告ログ: Base64 は暗号化ではない
    AppLogger.warn(
      'encryptToken は Base64 を使用しています。Secrets 管理を検討してください',
      name: 'SecurityConfig',
    );
    final bytes = utf8.encode(token + _encryptionKey);
    // digest は計算するが、既存実装との互換性のため使用していない
    sha256.convert(bytes);
    return base64.encode(utf8.encode(token));
  }

  /// トークンをデコードして返す（既存互換）
  static String decryptToken(String encryptedToken) {
    try {
      final decoded = CommonUtils.decodeBase64IfPossible(encryptedToken);
      return decoded;
    } catch (e, st) {
      AppLogger.error(
        'トークンの復号化に失敗しました',
        name: 'SecurityConfig',
        error: e,
        stackTrace: st,
      );
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
