import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

import 'package:firebase_core/firebase_core.dart';
import '../utils/security_config.dart';

/// 暗号化されたFirebase設定を管理するサービス
/// 環境変数から設定を読み込み、セキュアにFirebaseを初期化する
class EncryptedFirebaseConfigService {
  static const String _logName = 'EncryptedFirebaseConfigService';
  static bool _isInitialized = false;

  /// Firebase設定を暗号化して環境変数に保存するためのヘルパー
  /// 開発時に一度だけ実行して、暗号化された値を生成
  static Map<String, String> generateEncryptedConfig() {
    final configs = {
      'web': {
        'apiKey': 'AIzaSyDfk6xs4N35cdVXWXE_UAIylcPgrX3w4WU',
        'appId': '1:781258244482:web:cbcaba8a1604caa0d58f9b',
        'messagingSenderId': '781258244482',
        'projectId': 'bysnlogapp',
        'authDomain': 'bysnlogapp.firebaseapp.com',
        'storageBucket': 'bysnlogapp.firebasestorage.app',
        'measurementId': 'G-XLEGLN9L2K',
      },
      'android': {
        'apiKey': 'AIzaSyDcKAdqrCS9p7l7sTVxKQUUsEUu97eE_1M',
        'appId': '1:781258244482:android:8fe7b807bea7dc33d58f9b',
        'messagingSenderId': '781258244482',
        'projectId': 'bysnlogapp',
        'storageBucket': 'bysnlogapp.firebasestorage.app',
      },
      'ios': {
        'apiKey': 'AIzaSyAo6DWzmD7nXY9Lb4mnS51cOxfDT-gC6rM',
        'appId': '1:781258244482:ios:c45b64301e3eb7fad58f9b',
        'messagingSenderId': '781258244482',
        'projectId': 'bysnlogapp',
        'storageBucket': 'bysnlogapp.firebasestorage.app',
        'androidClientId':
            '781258244482-84qipi741b1mjb42nl4uu9d9e799ol11.apps.googleusercontent.com',
        'iosClientId':
            '781258244482-65hi6fpa3h2jef9dl8k7eaoi2sprne9k.apps.googleusercontent.com',
        'iosBundleId': 'com.example.roastplus',
      },
      'macos': {
        'apiKey': 'AIzaSyAo6DWzmD7nXY9Lb4mnS51cOxfDT-gC6rM',
        'appId': '1:781258244482:ios:c45b64301e3eb7fad58f9b',
        'messagingSenderId': '781258244482',
        'projectId': 'bysnlogapp',
        'storageBucket': 'bysnlogapp.firebasestorage.app',
        'androidClientId':
            '781258244482-84qipi741b1mjb42nl4uu9d9e799ol11.apps.googleusercontent.com',
        'iosClientId':
            '781258244482-65hi6fpa3h2jef9dl8k7eaoi2sprne9k.apps.googleusercontent.com',
        'iosBundleId': 'com.example.roastplus',
      },
      'windows': {
        'apiKey': 'AIzaSyDfk6xs4N35cdVXWXE_UAIylcPgrX3w4WU',
        'appId': '1:781258244482:web:ebf7be16b0ea7e02d58f9b',
        'messagingSenderId': '781258244482',
        'projectId': 'bysnlogapp',
        'authDomain': 'bysnlogapp.firebaseapp.com',
        'storageBucket': 'bysnlogapp.firebasestorage.app',
        'measurementId': 'G-QJSVBBTXW1',
      },
    };

    final encryptedConfigs = <String, String>{};

    configs.forEach((platform, config) {
      config.forEach((key, value) {
        final encryptedKey = '${platform.toUpperCase()}_${key.toUpperCase()}';
        final encryptedValue = SecurityConfig.encryptToken(value);
        encryptedConfigs[encryptedKey] = encryptedValue;
      });
    });

    return encryptedConfigs;
  }

  /// SecurityConfigから暗号化されたFirebase設定を取得
  static Map<String, String> _getEncryptedConfigFromSecurityConfig() {
    final config = <String, String>{};

    // 基本設定
    config['apiKey'] = SecurityConfig.getEncryptedApiKey();
    config['appId'] = SecurityConfig.getEncryptedAppId();
    config['messagingSenderId'] = SecurityConfig.getEncryptedSenderId();
    config['projectId'] = SecurityConfig.getEncryptedProjectId();
    config['storageBucket'] = SecurityConfig.getEncryptedStorageBucket();

    // プラットフォーム固有の設定
    final authDomain = SecurityConfig.getEncryptedAuthDomain();
    if (authDomain.isNotEmpty) {
      config['authDomain'] = authDomain;
    }

    final measurementId = SecurityConfig.getEncryptedMeasurementId();
    if (measurementId.isNotEmpty) {
      config['measurementId'] = measurementId;
    }

    final androidClientId = SecurityConfig.getEncryptedAndroidClientId();
    if (androidClientId.isNotEmpty) {
      config['androidClientId'] = androidClientId;
    }

    final iosClientId = SecurityConfig.getEncryptedIosClientId();
    if (iosClientId.isNotEmpty) {
      config['iosClientId'] = iosClientId;
    }

    final iosBundleId = SecurityConfig.getEncryptedIosBundleId();
    if (iosBundleId.isNotEmpty) {
      config['iosBundleId'] = iosBundleId;
    }

    return config;
  }

  /// 暗号化された設定を復号化
  static Map<String, String> _decryptConfig(
    Map<String, String> encryptedConfig,
  ) {
    final decryptedConfig = <String, String>{};

    encryptedConfig.forEach((key, encryptedValue) {
      try {
        final decryptedValue = SecurityConfig.decryptToken(encryptedValue);
        decryptedConfig[key] = decryptedValue;
      } catch (e) {
        developer.log('設定の復号化に失敗: $key - $e', name: _logName);
        // 復号化に失敗した場合は、平文として扱う（開発環境用）
        decryptedConfig[key] = encryptedValue;
      }
    });

    return decryptedConfig;
  }

  /// Firebase設定を取得
  static FirebaseOptions getFirebaseOptions() {
    try {
      // SecurityConfigから暗号化された設定を取得
      final encryptedConfig = _getEncryptedConfigFromSecurityConfig();

      // 設定が空の場合は、デフォルトの暗号化された設定を使用
      if (encryptedConfig.isEmpty ||
          encryptedConfig.values.every((v) => v.isEmpty)) {
        developer.log('環境変数から設定を取得できません。デフォルト設定を使用します。', name: _logName);
        return _getDefaultFirebaseOptions();
      }

      // 暗号化された設定を復号化
      final decryptedConfig = _decryptConfig(encryptedConfig);

      // FirebaseOptionsオブジェクトを作成
      return FirebaseOptions(
        apiKey: decryptedConfig['apiKey'] ?? '',
        appId: decryptedConfig['appId'] ?? '',
        messagingSenderId: decryptedConfig['messagingSenderId'] ?? '',
        projectId: decryptedConfig['projectId'] ?? '',
        authDomain: decryptedConfig['authDomain'],
        storageBucket: decryptedConfig['storageBucket'] ?? '',
        measurementId: decryptedConfig['measurementId'],
        androidClientId: decryptedConfig['androidClientId'],
        iosClientId: decryptedConfig['iosClientId'],
        iosBundleId: decryptedConfig['iosBundleId'],
      );
    } catch (e) {
      developer.log('Firebase設定の取得に失敗: $e', name: _logName);
      // エラーが発生した場合は、デフォルト設定を使用
      return _getDefaultFirebaseOptions();
    }
  }

  /// デフォルトのFirebase設定（フォールバック用）
  static FirebaseOptions _getDefaultFirebaseOptions() {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: 'AIzaSyDfk6xs4N35cdVXWXE_UAIylcPgrX3w4WU',
        appId: '1:781258244482:web:cbcaba8a1604caa0d58f9b',
        messagingSenderId: '781258244482',
        projectId: 'bysnlogapp',
        authDomain: 'bysnlogapp.firebaseapp.com',
        storageBucket: 'bysnlogapp.firebasestorage.app',
        measurementId: 'G-XLEGLN9L2K',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const FirebaseOptions(
          apiKey: 'AIzaSyDcKAdqrCS9p7l7sTVxKQUUsEUu97eE_1M',
          appId: '1:781258244482:android:8fe7b807bea7dc33d58f9b',
          messagingSenderId: '781258244482',
          projectId: 'bysnlogapp',
          storageBucket: 'bysnlogapp.firebasestorage.app',
        );
      case TargetPlatform.iOS:
        return FirebaseOptions(
          apiKey: 'AIzaSyAo6DWzmD7nXY9Lb4mnS51cOxfDT-gC6rM',
          appId: '1:781258244482:ios:c45b64301e3eb7fad58f9b',
          messagingSenderId: '781258244482',
          projectId: 'bysnlogapp',
          storageBucket: 'bysnlogapp.firebasestorage.app',
          androidClientId:
              '781258244482-84qipi741b1mjb42nl4uu9d9e799ol11.apps.googleusercontent.com',
          iosClientId:
              '781258244482-65hi6fpa3h2jef9dl8k7eaoi2sprne9k.apps.googleusercontent.com',
          iosBundleId: null, // 動的に取得するためnullに設定
        );
      case TargetPlatform.macOS:
        return const FirebaseOptions(
          apiKey: 'AIzaSyAo6DWzmD7nXY9Lb4mnS51cOxfDT-gC6rM',
          appId: '1:781258244482:ios:c45b64301e3eb7fad58f9b',
          messagingSenderId: '781258244482',
          projectId: 'bysnlogapp',
          storageBucket: 'bysnlogapp.firebasestorage.app',
          androidClientId:
              '781258244482-84qipi741b1mjb42nl4uu9d9e799ol11.apps.googleusercontent.com',
          iosClientId:
              '781258244482-65hi6fpa3h2jef9dl8k7eaoi2sprne9k.apps.googleusercontent.com',
          iosBundleId: 'com.example.roastplus',
        );
      case TargetPlatform.windows:
        return const FirebaseOptions(
          apiKey: 'AIzaSyDfk6xs4N35cdVXWXE_UAIylcPgrX3w4WU',
          appId: '1:781258244482:web:ebf7be16b0ea7e02d58f9b',
          messagingSenderId: '781258244482',
          projectId: 'bysnlogapp',
          authDomain: 'bysnlogapp.firebaseapp.com',
          storageBucket: 'bysnlogapp.firebasestorage.app',
          measurementId: 'G-QJSVBBTXW1',
        );
      default:
        throw UnsupportedError(
          'Unsupported platform for Firebase configuration',
        );
    }
  }

  /// Firebaseを暗号化された設定で初期化
  static Future<void> initializeFirebase() async {
    if (_isInitialized) {
      developer.log('Firebaseは既に初期化されています', name: _logName);
      return;
    }

    try {
      developer.log('暗号化されたFirebase設定で初期化を開始', name: _logName);

      // Web版では既にindex.htmlで初期化されている可能性があるため、チェック
      if (kIsWeb) {
        try {
          // 既存のFirebaseアプリをチェック
          final apps = Firebase.apps;
          if (apps.isNotEmpty) {
            developer.log('Web版: 既存のFirebaseアプリを検出しました', name: _logName);
            _isInitialized = true;
            return;
          }
        } catch (e) {
          developer.log('Web版: Firebaseアプリチェック中にエラー: $e', name: _logName);
        }
      }

      // 暗号化された設定を取得
      final options = getFirebaseOptions();

      // Firebaseを初期化
      await Firebase.initializeApp(options: options);

      _isInitialized = true;
      developer.log('Firebaseの初期化が完了しました', name: _logName);
    } catch (e) {
      // 重複初期化エラーの場合は成功として扱う
      if (e.toString().contains('duplicate-app') ||
          e.toString().contains('already exists')) {
        developer.log('Firebaseは既に初期化されています（重複エラーを無視）', name: _logName);
        _isInitialized = true;
        return;
      }
      developer.log('Firebaseの初期化に失敗: $e', name: _logName);
      rethrow;
    }
  }

  /// 初期化状態を確認
  static bool get isInitialized => _isInitialized;

  /// 設定の検証
  static Future<bool> validateConfiguration() async {
    try {
      final config = _getEncryptedConfigFromSecurityConfig();
      if (config.isEmpty) return false;

      // 必須項目の存在確認
      final requiredKeys = [
        'apiKey',
        'appId',
        'messagingSenderId',
        'projectId',
      ];
      for (final key in requiredKeys) {
        if (!config.containsKey(key) || config[key]!.isEmpty) {
          developer.log('必須設定が不足: $key', name: _logName);
          return false;
        }
      }

      // 復号化テスト
      final decryptedConfig = _decryptConfig(config);
      if (decryptedConfig.isEmpty) {
        developer.log('設定の復号化に失敗', name: _logName);
        return false;
      }

      return true;
    } catch (e) {
      developer.log('設定の検証に失敗: $e', name: _logName);
      return false;
    }
  }
}
