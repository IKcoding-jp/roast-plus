import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:firebase_core/firebase_core.dart';
import '../utils/security_config.dart';
import '../utils/env_loader.dart';

/// 暗号化されたFirebase設定を管理するサービス
/// 環境変数から設定を読み込み、セキュアにFirebaseを初期化する
class EncryptedFirebaseConfigService {
  static const String _logName = 'EncryptedFirebaseConfigService';
  static bool _isInitialized = false;

  /// 暗号化されたFirebase設定を生成するメソッド
  /// 環境変数から設定を取得し、暗号化して返す
  static Map<String, String> generateEncryptedConfig() {
    // 環境変数から設定を取得（フォールバック用のデフォルト値）
    final configs = {
      'web': {
        'apiKey': const String.fromEnvironment('FIREBASE_WEB_API_KEY'),
        'appId': const String.fromEnvironment('FIREBASE_WEB_APP_ID'),
        'messagingSenderId': const String.fromEnvironment(
          'FIREBASE_PROJECT_NUMBER',
        ),
        'projectId': const String.fromEnvironment('FIREBASE_PROJECT_ID'),
        'authDomain':
            '${const String.fromEnvironment('FIREBASE_PROJECT_ID')}.firebaseapp.com',
        'storageBucket':
            '${const String.fromEnvironment('FIREBASE_PROJECT_ID')}.firebasestorage.app',
        'measurementId': 'G-XXXXXXXXXX',
      },
      'android': {
        'apiKey': const String.fromEnvironment('FIREBASE_WEB_API_KEY'),
        'appId': const String.fromEnvironment('FIREBASE_ANDROID_APP_ID'),
        'messagingSenderId': const String.fromEnvironment(
          'FIREBASE_PROJECT_NUMBER',
        ),
        'projectId': const String.fromEnvironment('FIREBASE_PROJECT_ID'),
        'storageBucket':
            '${const String.fromEnvironment('FIREBASE_PROJECT_ID')}.firebasestorage.app',
      },
      'ios': {
        'apiKey': const String.fromEnvironment('FIREBASE_WEB_API_KEY'),
        'appId': const String.fromEnvironment('FIREBASE_ANDROID_APP_ID'),
        'messagingSenderId': const String.fromEnvironment(
          'FIREBASE_PROJECT_NUMBER',
        ),
        'projectId': const String.fromEnvironment('FIREBASE_PROJECT_ID'),
        'storageBucket': const String.fromEnvironment(
          'FIREBASE_STORAGE_BUCKET',
        ),
        'androidClientId': const String.fromEnvironment(
          'FIREBASE_ANDROID_CLIENT_ID',
        ),
        'iosClientId': const String.fromEnvironment('FIREBASE_IOS_CLIENT_ID'),
        'iosBundleId': const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
      },
      'macos': {
        'apiKey': const String.fromEnvironment('FIREBASE_IOS_API_KEY'),
        'appId': const String.fromEnvironment('FIREBASE_IOS_APP_ID'),
        'messagingSenderId': const String.fromEnvironment(
          'FIREBASE_MESSAGING_SENDER_ID',
        ),
        'projectId': const String.fromEnvironment('FIREBASE_PROJECT_ID'),
        'storageBucket': const String.fromEnvironment(
          'FIREBASE_STORAGE_BUCKET',
        ),
        'androidClientId': const String.fromEnvironment(
          'FIREBASE_ANDROID_CLIENT_ID',
        ),
        'iosClientId': const String.fromEnvironment('FIREBASE_IOS_CLIENT_ID'),
        'iosBundleId': const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
      },
      'windows': {
        'apiKey': const String.fromEnvironment('FIREBASE_WEB_API_KEY'),
        'appId': const String.fromEnvironment('FIREBASE_WINDOWS_APP_ID'),
        'messagingSenderId': const String.fromEnvironment(
          'FIREBASE_MESSAGING_SENDER_ID',
        ),
        'projectId': const String.fromEnvironment('FIREBASE_PROJECT_ID'),
        'authDomain': const String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
        'storageBucket': const String.fromEnvironment(
          'FIREBASE_STORAGE_BUCKET',
        ),
        'measurementId': const String.fromEnvironment(
          'FIREBASE_WINDOWS_MEASUREMENT_ID',
        ),
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

  /// Firebase設定を環境変数から取得するヘルパー
  /// 平文の設定を直接使用（暗号化なし）
  static Map<String, String> generatePlainConfig() {
    // 環境変数から設定を取得（フォールバック用のデフォルト値）
    final configs = {
      'web': {
        'apiKey': const String.fromEnvironment('FIREBASE_WEB_API_KEY'),
        'appId': const String.fromEnvironment('FIREBASE_WEB_APP_ID'),
        'messagingSenderId': const String.fromEnvironment(
          'FIREBASE_PROJECT_NUMBER',
        ),
        'projectId': const String.fromEnvironment('FIREBASE_PROJECT_ID'),
        'authDomain':
            '${const String.fromEnvironment('FIREBASE_PROJECT_ID')}.firebaseapp.com',
        'storageBucket':
            '${const String.fromEnvironment('FIREBASE_PROJECT_ID')}.firebasestorage.app',
        'measurementId': 'G-XXXXXXXXXX',
      },
      'android': {
        'apiKey': const String.fromEnvironment('FIREBASE_WEB_API_KEY'),
        'appId': const String.fromEnvironment('FIREBASE_ANDROID_APP_ID'),
        'messagingSenderId': const String.fromEnvironment(
          'FIREBASE_PROJECT_NUMBER',
        ),
        'projectId': const String.fromEnvironment('FIREBASE_PROJECT_ID'),
        'storageBucket':
            '${const String.fromEnvironment('FIREBASE_PROJECT_ID')}.firebasestorage.app',
      },
      'ios': {
        'apiKey': const String.fromEnvironment('FIREBASE_WEB_API_KEY'),
        'appId': const String.fromEnvironment('FIREBASE_ANDROID_APP_ID'),
        'messagingSenderId': const String.fromEnvironment(
          'FIREBASE_PROJECT_NUMBER',
        ),
        'projectId': const String.fromEnvironment('FIREBASE_PROJECT_ID'),
        'storageBucket': const String.fromEnvironment(
          'FIREBASE_STORAGE_BUCKET',
        ),
        'androidClientId': const String.fromEnvironment(
          'FIREBASE_ANDROID_CLIENT_ID',
        ),
        'iosClientId': const String.fromEnvironment('FIREBASE_IOS_CLIENT_ID'),
        'iosBundleId': const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
      },
      'macos': {
        'apiKey': const String.fromEnvironment('FIREBASE_IOS_API_KEY'),
        'appId': const String.fromEnvironment('FIREBASE_IOS_APP_ID'),
        'messagingSenderId': const String.fromEnvironment(
          'FIREBASE_MESSAGING_SENDER_ID',
        ),
        'projectId': const String.fromEnvironment('FIREBASE_PROJECT_ID'),
        'storageBucket': const String.fromEnvironment(
          'FIREBASE_STORAGE_BUCKET',
        ),
        'androidClientId': const String.fromEnvironment(
          'FIREBASE_ANDROID_CLIENT_ID',
        ),
        'iosClientId': const String.fromEnvironment('FIREBASE_IOS_CLIENT_ID'),
        'iosBundleId': const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
      },
      'windows': {
        'apiKey': const String.fromEnvironment('FIREBASE_WEB_API_KEY'),
        'appId': const String.fromEnvironment('FIREBASE_WINDOWS_APP_ID'),
        'messagingSenderId': const String.fromEnvironment(
          'FIREBASE_MESSAGING_SENDER_ID',
        ),
        'projectId': const String.fromEnvironment('FIREBASE_PROJECT_ID'),
        'authDomain': const String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
        'storageBucket': const String.fromEnvironment(
          'FIREBASE_STORAGE_BUCKET',
        ),
        'measurementId': const String.fromEnvironment(
          'FIREBASE_WINDOWS_MEASUREMENT_ID',
        ),
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

  /// Firebase設定を取得（平文設定を使用）
  static Future<FirebaseOptions> getFirebaseOptions() async {
    try {
      // 環境変数から平文の設定を直接取得
      final config = await _getPlainConfigFromEnvironment();

      // 設定が空の場合は、詳細なエラー情報を提供
      if (config.isEmpty || config.values.every((v) => v.isEmpty)) {
        developer.log('❌ 環境変数から設定を取得できません', name: _logName);
        _logMissingEnvironmentVariables();
        return _getDefaultFirebaseOptions();
      }

      // 必須項目の検証
      _validateRequiredConfig(config);

      // FirebaseOptionsオブジェクトを作成
      return FirebaseOptions(
        apiKey: config['apiKey'] ?? '',
        appId: config['appId'] ?? '',
        messagingSenderId: config['messagingSenderId'] ?? '',
        projectId: config['projectId'] ?? '',
        authDomain: config['authDomain'],
        storageBucket: config['storageBucket'] ?? '',
        measurementId: config['measurementId'],
        androidClientId: config['androidClientId'],
        iosClientId: config['iosClientId'],
        iosBundleId: config['iosBundleId'],
      );
    } catch (e) {
      developer.log('Firebase設定の取得に失敗: $e', name: _logName);
      // エラーが発生した場合は、詳細なエラー情報を提供
      return _getDefaultFirebaseOptions();
    }
  }

  /// MethodChannelからFirebase設定を取得
  static Future<Map<String, String>> _getConfigFromNative() async {
    try {
      if (kIsWeb) return {};

      const platform = MethodChannel('com.ikcoding.roastplus/firebase_config');
      final Map<Object?, Object?>? config = await platform.invokeMethod(
        'getFirebaseConfig',
      );

      if (config != null) {
        developer.log('✅ MethodChannelからFirebase設定を取得しました', name: _logName);
        return config.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
      }
    } catch (e) {
      developer.log('❌ MethodChannelからの設定取得に失敗: $e', name: _logName);
    }
    return {};
  }

  /// 環境変数から平文の設定を取得
  static Future<Map<String, String>> _getPlainConfigFromEnvironment() async {
    // まずMethodChannelから設定を取得
    final nativeConfig = await _getConfigFromNative();
    if (nativeConfig.isNotEmpty) {
      developer.log('MethodChannelから設定を使用', name: _logName);
      return nativeConfig;
    }

    developer.log('MethodChannelから設定が取得できなかったため、環境変数を使用', name: _logName);

    if (kIsWeb) {
      return {
        'apiKey': await EnvLoader.getEnvVar('FIREBASE_WEB_API_KEY'),
        'appId': await EnvLoader.getEnvVar('FIREBASE_WEB_APP_ID'),
        'messagingSenderId': await EnvLoader.getEnvVar(
          'FIREBASE_MESSAGING_SENDER_ID',
        ),
        'projectId': await EnvLoader.getEnvVar('FIREBASE_PROJECT_ID'),
        'authDomain':
            '${await EnvLoader.getEnvVar('FIREBASE_PROJECT_ID')}.firebaseapp.com',
        'storageBucket':
            '${await EnvLoader.getEnvVar('FIREBASE_PROJECT_ID')}.firebasestorage.app',
        'measurementId': 'G-XXXXXXXXXX',
      };
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // AndroidではMethodChannelから設定を取得
        final nativeConfig = await _getConfigFromNative();
        if (nativeConfig.isNotEmpty) {
          return nativeConfig;
        }
        // フォールバックとして環境変数を使用
        return {
          'apiKey': await EnvLoader.getEnvVar('FIREBASE_WEB_API_KEY'),
          'appId': await EnvLoader.getEnvVar('FIREBASE_ANDROID_APP_ID'),
          'messagingSenderId': await EnvLoader.getEnvVar(
            'FIREBASE_MESSAGING_SENDER_ID',
          ),
          'projectId': await EnvLoader.getEnvVar('FIREBASE_PROJECT_ID'),
          'storageBucket':
              '${await EnvLoader.getEnvVar('FIREBASE_PROJECT_ID')}.firebasestorage.app',
        };
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return {
          'apiKey': await EnvLoader.getEnvVar('FIREBASE_WEB_API_KEY'),
          'appId': await EnvLoader.getEnvVar('FIREBASE_ANDROID_APP_ID'),
          'messagingSenderId': await EnvLoader.getEnvVar(
            'FIREBASE_MESSAGING_SENDER_ID',
          ),
          'projectId': await EnvLoader.getEnvVar('FIREBASE_PROJECT_ID'),
          'storageBucket':
              '${await EnvLoader.getEnvVar('FIREBASE_PROJECT_ID')}.firebasestorage.app',
          'androidClientId': await EnvLoader.getEnvVar(
            'GOOGLE_SIGN_IN_CLIENT_ID',
          ),
          'iosClientId': await EnvLoader.getEnvVar('GOOGLE_SIGN_IN_CLIENT_ID'),
          'iosBundleId': await EnvLoader.getEnvVar(
            'FIREBASE_ANDROID_PACKAGE_NAME',
          ),
        };
      case TargetPlatform.windows:
        return {
          'apiKey': await EnvLoader.getEnvVar('FIREBASE_WEB_API_KEY'),
          'appId': await EnvLoader.getEnvVar('FIREBASE_WEB_APP_ID'),
          'messagingSenderId': await EnvLoader.getEnvVar(
            'FIREBASE_MESSAGING_SENDER_ID',
          ),
          'projectId': await EnvLoader.getEnvVar('FIREBASE_PROJECT_ID'),
          'authDomain':
              '${await EnvLoader.getEnvVar('FIREBASE_PROJECT_ID')}.firebaseapp.com',
          'storageBucket':
              '${await EnvLoader.getEnvVar('FIREBASE_PROJECT_ID')}.firebasestorage.app',
          'measurementId': 'G-XXXXXXXXXX',
        };
      default:
        return {
          'apiKey': await EnvLoader.getEnvVar('FIREBASE_WEB_API_KEY'),
          'appId': await EnvLoader.getEnvVar('FIREBASE_WEB_APP_ID'),
          'messagingSenderId': await EnvLoader.getEnvVar(
            'FIREBASE_MESSAGING_SENDER_ID',
          ),
          'projectId': await EnvLoader.getEnvVar('FIREBASE_PROJECT_ID'),
          'authDomain':
              '${await EnvLoader.getEnvVar('FIREBASE_PROJECT_ID')}.firebaseapp.com',
          'storageBucket':
              '${await EnvLoader.getEnvVar('FIREBASE_PROJECT_ID')}.firebasestorage.app',
          'measurementId': 'G-XXXXXXXXXX',
        };
    }
  }

  /// デフォルトのFirebase設定（フォールバック用）
  /// ⚠️ セキュリティ警告: このメソッドは使用禁止です
  /// 環境変数から設定を取得できない場合は例外を投げます
  static FirebaseOptions _getDefaultFirebaseOptions() {
    developer.log('❌ セキュリティエラー: 環境変数からFirebase設定を取得できませんでした。', name: _logName);
    developer.log('📋 必要な環境変数:', name: _logName);
    developer.log('  - FIREBASE_WEB_API_KEY_ENCRYPTED (Web用)', name: _logName);
    developer.log(
      '  - FIREBASE_ANDROID_API_KEY_ENCRYPTED (Android用)',
      name: _logName,
    );
    developer.log(
      '  - FIREBASE_IOS_API_KEY_ENCRYPTED (iOS/macOS用)',
      name: _logName,
    );
    developer.log('  - その他の暗号化されたFirebase設定項目', name: _logName);
    developer.log(
      '🔧 解決方法: app_config.envファイルに暗号化された値を設定してください',
      name: _logName,
    );

    // セキュリティ強化: ハードコードされたAPIキーは一切使用しない
    throw Exception(
      'Firebase設定が環境変数から取得できません。'
      'app_config.envファイルに適切なFirebase設定を追加してください。'
      'ハードコードされたAPIキーはセキュリティ上の理由により使用禁止です。',
    );
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
      final options = await getFirebaseOptions();

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

  /// 不足している環境変数をログ出力
  static void _logMissingEnvironmentVariables() {
    developer.log('📋 必要な環境変数一覧:', name: _logName);
    developer.log('  🔑 暗号化されたAPIキー（本番用）:', name: _logName);
    developer.log('    - FIREBASE_WEB_API_KEY_ENCRYPTED', name: _logName);
    developer.log('    - FIREBASE_ANDROID_API_KEY_ENCRYPTED', name: _logName);
    developer.log('    - FIREBASE_IOS_API_KEY_ENCRYPTED', name: _logName);
    developer.log('  📱 暗号化されたアプリID:', name: _logName);
    developer.log('    - FIREBASE_WEB_APP_ID_ENCRYPTED', name: _logName);
    developer.log('    - FIREBASE_ANDROID_APP_ID_ENCRYPTED', name: _logName);
    developer.log('    - FIREBASE_IOS_APP_ID_ENCRYPTED', name: _logName);
    developer.log('    - FIREBASE_WINDOWS_APP_ID_ENCRYPTED', name: _logName);
    developer.log('  🏗️ 暗号化されたプロジェクト設定:', name: _logName);
    developer.log('    - FIREBASE_PROJECT_ID_ENCRYPTED', name: _logName);
    developer.log(
      '    - FIREBASE_MESSAGING_SENDER_ID_ENCRYPTED',
      name: _logName,
    );
    developer.log('    - FIREBASE_STORAGE_BUCKET_ENCRYPTED', name: _logName);
    developer.log('    - FIREBASE_AUTH_DOMAIN_ENCRYPTED', name: _logName);
    developer.log('    - FIREBASE_MEASUREMENT_ID_ENCRYPTED', name: _logName);
    developer.log(
      '    - FIREBASE_WINDOWS_MEASUREMENT_ID_ENCRYPTED',
      name: _logName,
    );
    developer.log('    - FIREBASE_ANDROID_CLIENT_ID_ENCRYPTED', name: _logName);
    developer.log('    - FIREBASE_IOS_CLIENT_ID_ENCRYPTED', name: _logName);
    developer.log('    - FIREBASE_IOS_BUNDLE_ID_ENCRYPTED', name: _logName);
    developer.log('  🔐 セキュリティ:', name: _logName);
    developer.log('    - ENCRYPTION_KEY', name: _logName);
    developer.log('', name: _logName);
    developer.log('🔧 設定方法:', name: _logName);
    developer.log('  1. app_config.envファイルを開く', name: _logName);
    developer.log('  2. 平文のAPIキーをBase64エンコードする', name: _logName);
    developer.log('  3. 暗号化された値を*_ENCRYPTED変数に設定', name: _logName);
    developer.log('  4. アプリを再起動', name: _logName);
    developer.log('', name: _logName);
    developer.log('⚠️ セキュリティ警告:', name: _logName);
    developer.log('  - ハードコーディングされたAPIキーは完全に削除されました', name: _logName);
    developer.log('  - 環境変数が設定されていない場合はアプリが起動しません', name: _logName);
    developer.log('  - 本番環境では必ず暗号化されたAPIキーを使用してください', name: _logName);
  }

  /// 必須設定項目の検証
  static void _validateRequiredConfig(Map<String, String> config) {
    final requiredKeys = ['apiKey', 'appId', 'messagingSenderId', 'projectId'];

    final missingKeys = <String>[];
    for (final key in requiredKeys) {
      if (!config.containsKey(key) || config[key]!.isEmpty) {
        missingKeys.add(key);
      }
    }

    if (missingKeys.isNotEmpty) {
      developer.log(
        '❌ 必須設定項目が不足しています: ${missingKeys.join(', ')}',
        name: _logName,
      );
      throw Exception('必須のFirebase設定項目が不足しています: ${missingKeys.join(', ')}');
    }

    developer.log('✅ Firebase設定の検証が完了しました', name: _logName);
  }

  /// 設定の検証
  static Future<bool> validateConfiguration() async {
    try {
      developer.log('🔍 Firebase設定の検証を開始...', name: _logName);

      final config = _getEncryptedConfigFromSecurityConfig();
      if (config.isEmpty) {
        developer.log('❌ 暗号化された設定が空です', name: _logName);
        _logMissingEnvironmentVariables();
        return false;
      }

      // 必須項目の存在確認
      final requiredKeys = [
        'apiKey',
        'appId',
        'messagingSenderId',
        'projectId',
      ];

      final missingKeys = <String>[];
      for (final key in requiredKeys) {
        if (!config.containsKey(key) || config[key]!.isEmpty) {
          missingKeys.add(key);
        }
      }

      if (missingKeys.isNotEmpty) {
        developer.log(
          '❌ 必須設定が不足しています: ${missingKeys.join(', ')}',
          name: _logName,
        );
        _logMissingEnvironmentVariables();
        return false;
      }

      // 復号化テスト
      final decryptedConfig = _decryptConfig(config);
      if (decryptedConfig.isEmpty) {
        developer.log('❌ 設定の復号化に失敗しました', name: _logName);
        return false;
      }

      // 復号化された設定の検証
      _validateRequiredConfig(decryptedConfig);

      developer.log('✅ Firebase設定の検証が完了しました', name: _logName);
      return true;
    } catch (e) {
      developer.log('❌ 設定の検証に失敗: $e', name: _logName);
      _logMissingEnvironmentVariables();
      return false;
    }
  }
}
