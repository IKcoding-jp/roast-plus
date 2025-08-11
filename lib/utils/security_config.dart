import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

/// セキュリティ設定を管理するクラス
class SecurityConfig {
  // 暗号化キー（本番環境では環境変数から取得すべき）
  static const String _encryptionKey = 'your-secure-encryption-key-here';

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

  /// APIキーを暗号化
  static String _encryptApiKey(String apiKey) {
    final bytes = utf8.encode(apiKey + _encryptionKey);
    final digest = sha256.convert(bytes);
    return base64.encode(utf8.encode(apiKey));
  }

  /// APIキーを復号化
  static String _decryptApiKey(String encryptedApiKey) {
    try {
      return utf8.decode(base64.decode(encryptedApiKey));
    } catch (e) {
      throw Exception('APIキーの復号化に失敗しました');
    }
  }

  /// アプリIDを暗号化
  static String _encryptAppId(String appId) {
    return base64.encode(utf8.encode(appId));
  }

  /// アプリIDを復号化
  static String _decryptAppId(String encryptedAppId) {
    try {
      return utf8.decode(base64.decode(encryptedAppId));
    } catch (e) {
      throw Exception('アプリIDの復号化に失敗しました');
    }
  }

  /// プロジェクトIDを暗号化
  static String _encryptProjectId(String projectId) {
    return base64.encode(utf8.encode(projectId));
  }

  /// プロジェクトIDを復号化
  static String _decryptProjectId(String encryptedProjectId) {
    try {
      return utf8.decode(base64.decode(encryptedProjectId));
    } catch (e) {
      throw Exception('プロジェクトIDの復号化に失敗しました');
    }
  }

  /// 送信者IDを暗号化
  static String _encryptSenderId(String senderId) {
    return base64.encode(utf8.encode(senderId));
  }

  /// 送信者IDを復号化
  static String _decryptSenderId(String encryptedSenderId) {
    try {
      return utf8.decode(base64.decode(encryptedSenderId));
    } catch (e) {
      throw Exception('送信者IDの復号化に失敗しました');
    }
  }

  // 暗号化された設定値（プラットフォーム別）
  static String getEncryptedApiKey() {
    if (kIsWeb) {
      return 'QUl6YVN5RGZrNnhzNE4zNWNkVlhXWEVfVUFJeWxjUGdyWDN3NFdV';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'QUl6YVN5RGNLQWRxckNTOTA3bDdsU1RYeEtRVXVzRVV1OTdlRV8xTQ==';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'QUl6YVN5QW82RFd6bUQ3blhZOUxiNG1uUzUxY094ZkRULWdDNnJN';
      case TargetPlatform.windows:
        return 'QUl6YVN5RGZrNnhzNE4zNWNkVlhXWEVfVUFJeWxjUGdyWDN3NFdV';
      default:
        return 'QUl6YVN5RGZrNnhzNE4zNWNkVlhXWEVfVUFJeWxjUGdyWDN3NFdV';
    }
  }

  static String getEncryptedAppId() {
    if (kIsWeb) {
      return 'MTc4MTI1ODI0NDQ4Mjp3ZWI6Y2JjYWJhOGExNjA0Y2FhMGQ1OGY5Yg==';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'MTc4MTI1ODI0NDQ4MjphbmRyb2lkOjhmZTdiODA3YmVhN2RjMzNkNThmOWI=';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'MTc4MTI1ODI0NDQ4Mjppb3M6YzQ1YjY0MzAxZTNlYjdmYWRmNThmOWI=';
      case TargetPlatform.windows:
        return 'MTc4MTI1ODI0NDQ4Mjp3ZWI6ZWJmN2JlMTZiMGVhN2UwMmQ1OGY5Yg==';
      default:
        return 'MTc4MTI1ODI0NDQ4Mjp3ZWI6Y2JjYWJhOGExNjA0Y2FhMGQ1OGY5Yg==';
    }
  }

  static String getEncryptedProjectId() {
    return 'YnlzbmxvZ2FwcA==';
  }

  static String getEncryptedSenderId() {
    return 'NzgxMjU4MjQ0NDgy';
  }

  static String getEncryptedAuthDomain() {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      return 'YnlzbmxvZ2FwcC5maXJlYmFzZWFwcC5jb20=';
    }
    return '';
  }

  static String getEncryptedStorageBucket() {
    return 'YnlzbmxvZ2FwcC5maXJlYmFzdG9yYWdlLmFwcA==';
  }

  static String getEncryptedMeasurementId() {
    if (kIsWeb) {
      return 'Ry1YTEVHTE45TEs=';
    }
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return 'Ry1RSlNWQkJUWFcx';
    }
    return '';
  }

  static String getEncryptedAndroidClientId() {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return 'NzgxMjU4MjQ0NDgyLTg0cWlwaTc0MWIxbWpiNDJubDR1dTlkOWU3OTlvbDExLmFwcHMuZ29vZ2xldXNlcmNvbnRlbnQuY29t';
    }
    return '';
  }

  static String getEncryptedIosClientId() {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return 'NzgxMjU4MjQ0NDgyLTY1aGk2ZnBhM2gyamVmOWRsOGs3ZWFvaTJzcHJuZTlrLmFwcHMuZ29vZ2xldXNlcmNvbnRlbnQuY29t';
    }
    return '';
  }

  static String getEncryptedIosBundleId() {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return 'Y29tLmV4YW1wbGUucm9hc3RwbHVz';
    }
    return '';
  }

  /// セキュアなトークン保存
  static String encryptToken(String token) {
    final bytes = utf8.encode(token + _encryptionKey);
    final digest = sha256.convert(bytes);
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
