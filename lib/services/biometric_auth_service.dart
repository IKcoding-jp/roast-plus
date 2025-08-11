import 'dart:developer' as developer;
import 'package:local_auth/local_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'secure_storage_service.dart';
import 'secure_auth_service.dart';

class BiometricAuthService {
  static const String _logName = 'BiometricAuthService';
  static final LocalAuthentication _localAuth = LocalAuthentication();
  static bool _isInitialized = false;

  /// 生体認証サービスの初期化
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      developer.log('生体認証サービス初期化開始', name: _logName);

      // 利用可能な生体認証の確認
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      developer.log(
        '生体認証利用可能: $isAvailable, デバイス対応: $isDeviceSupported',
        name: _logName,
      );

      _isInitialized = true;
      developer.log('生体認証サービス初期化完了', name: _logName);
    } catch (e) {
      developer.log('生体認証サービス初期化エラー: $e', name: _logName);
      rethrow;
    }
  }

  /// 利用可能な生体認証タイプを取得
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      await initialize();
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      developer.log('利用可能な生体認証: $availableBiometrics', name: _logName);
      return availableBiometrics;
    } catch (e) {
      developer.log('生体認証タイプ取得エラー: $e', name: _logName);
      return [];
    }
  }

  /// 生体認証が有効かどうかを確認
  static Future<bool> isBiometricEnabled() async {
    try {
      final enabled = await SecureStorageService.getBiometricEnabled();
      return enabled ?? false;
    } catch (e) {
      developer.log('生体認証有効状態確認エラー: $e', name: _logName);
      return false;
    }
  }

  /// 生体認証を有効化
  static Future<bool> enableBiometric() async {
    try {
      developer.log('生体認証有効化開始', name: _logName);

      // 現在のユーザーが認証されているか確認
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        developer.log('ユーザーが認証されていません', name: _logName);
        return false;
      }

      // 生体認証の利用可能性を確認
      final availableBiometrics = await getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        developer.log('利用可能な生体認証がありません', name: _logName);
        return false;
      }

      // 生体認証をテスト
      final authenticated = await authenticateWithBiometrics(
        reason: '生体認証を有効にするために認証してください',
        fallbackTitle: 'パスコードを使用',
      );

      if (authenticated) {
        // 生体認証を有効化
        await SecureStorageService.saveBiometricEnabled(true);

        // セキュリティイベントを記録
        await SecureAuthService.logSecurityEvent(
          'biometric_enabled',
          details: {
            'biometric_types': availableBiometrics
                .map((e) => e.toString())
                .toList(),
            'user_id': user.uid,
          },
        );

        developer.log('生体認証が有効化されました', name: _logName);
        return true;
      } else {
        developer.log('生体認証テストに失敗しました', name: _logName);
        return false;
      }
    } catch (e) {
      developer.log('生体認証有効化エラー: $e', name: _logName);
      return false;
    }
  }

  /// 生体認証を無効化
  static Future<bool> disableBiometric() async {
    try {
      developer.log('生体認証無効化開始', name: _logName);

      // 現在のユーザーが認証されているか確認
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        developer.log('ユーザーが認証されていません', name: _logName);
        return false;
      }

      // パスコードまたは生体認証で認証
      final authenticated = await authenticateUser(
        reason: '生体認証を無効にするために認証してください',
      );

      if (authenticated) {
        // 生体認証を無効化
        await SecureStorageService.saveBiometricEnabled(false);

        // セキュリティイベントを記録
        await SecureAuthService.logSecurityEvent(
          'biometric_disabled',
          details: {'user_id': user.uid},
        );

        developer.log('生体認証が無効化されました', name: _logName);
        return true;
      } else {
        developer.log('認証に失敗しました', name: _logName);
        return false;
      }
    } catch (e) {
      developer.log('生体認証無効化エラー: $e', name: _logName);
      return false;
    }
  }

  /// 生体認証でユーザーを認証
  static Future<bool> authenticateWithBiometrics({
    required String reason,
    String? fallbackTitle,
  }) async {
    try {
      await initialize();

      developer.log('生体認証開始: $reason', name: _logName);

      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        developer.log('生体認証成功', name: _logName);

        // セキュリティイベントを記録
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await SecureAuthService.logSecurityEvent(
            'biometric_auth_success',
            details: {'user_id': user.uid, 'reason': reason},
          );
        }

        return true;
      } else {
        developer.log('生体認証失敗', name: _logName);
        return false;
      }
    } catch (e) {
      developer.log('生体認証エラー: $e', name: _logName);
      return false;
    }
  }

  /// パスコードでユーザーを認証
  static Future<bool> authenticateWithPasscode({required String reason}) async {
    try {
      await initialize();

      developer.log('パスコード認証開始: $reason', name: _logName);

      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (authenticated) {
        developer.log('パスコード認証成功', name: _logName);

        // セキュリティイベントを記録
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await SecureAuthService.logSecurityEvent(
            'passcode_auth_success',
            details: {'user_id': user.uid, 'reason': reason},
          );
        }

        return true;
      } else {
        developer.log('パスコード認証失敗', name: _logName);
        return false;
      }
    } catch (e) {
      developer.log('パスコード認証エラー: $e', name: _logName);
      return false;
    }
  }

  /// ユーザーを認証（生体認証またはパスコード）
  static Future<bool> authenticateUser({required String reason}) async {
    try {
      developer.log('ユーザー認証開始: $reason', name: _logName);

      // 生体認証が有効かどうかを確認
      final biometricEnabled = await isBiometricEnabled();

      if (biometricEnabled) {
        // 生体認証を試行
        final biometricResult = await authenticateWithBiometrics(
          reason: reason,
          fallbackTitle: 'パスコードを使用',
        );

        if (biometricResult) {
          return true;
        }

        // 生体認証が失敗した場合、パスコードを試行
        developer.log('生体認証失敗、パスコード認証を試行', name: _logName);
        return await authenticateWithPasscode(reason: reason);
      } else {
        // 生体認証が無効な場合、パスコードのみ
        return await authenticateWithPasscode(reason: reason);
      }
    } catch (e) {
      developer.log('ユーザー認証エラー: $e', name: _logName);
      return false;
    }
  }

  /// アプリ起動時の認証チェック
  static Future<bool> checkAppLaunchAuth() async {
    try {
      developer.log('アプリ起動時認証チェック開始', name: _logName);

      // 生体認証またはパスコードが設定されているか確認
      final biometricEnabled = await isBiometricEnabled();
      final hasPasscode = await SecureStorageService.hasPasscode();

      if (!biometricEnabled && !hasPasscode) {
        developer.log('認証設定がありません', name: _logName);
        return true; // 認証設定がない場合は許可
      }

      // 認証を要求
      final authenticated = await authenticateUser(
        reason: 'アプリにアクセスするために認証してください',
      );

      if (authenticated) {
        developer.log('アプリ起動時認証成功', name: _logName);

        // セキュリティイベントを記録
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await SecureAuthService.logSecurityEvent(
            'app_launch_auth_success',
            details: {
              'user_id': user.uid,
              'biometric_enabled': biometricEnabled,
              'has_passcode': hasPasscode,
            },
          );
        }

        return true;
      } else {
        developer.log('アプリ起動時認証失敗', name: _logName);
        return false;
      }
    } catch (e) {
      developer.log('アプリ起動時認証チェックエラー: $e', name: _logName);
      return false;
    }
  }

  /// 機密操作前の認証チェック
  static Future<bool> checkSensitiveOperationAuth({
    required String operation,
  }) async {
    try {
      developer.log('機密操作認証チェック開始: $operation', name: _logName);

      // 生体認証またはパスコードが設定されているか確認
      final biometricEnabled = await isBiometricEnabled();
      final hasPasscode = await SecureStorageService.hasPasscode();

      if (!biometricEnabled && !hasPasscode) {
        developer.log('認証設定がありません', name: _logName);
        return true; // 認証設定がない場合は許可
      }

      // 認証を要求
      final authenticated = await authenticateUser(
        reason: '$operationを実行するために認証してください',
      );

      if (authenticated) {
        developer.log('機密操作認証成功: $operation', name: _logName);

        // セキュリティイベントを記録
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await SecureAuthService.logSecurityEvent(
            'sensitive_operation_auth_success',
            details: {
              'user_id': user.uid,
              'operation': operation,
              'biometric_enabled': biometricEnabled,
              'has_passcode': hasPasscode,
            },
          );
        }

        return true;
      } else {
        developer.log('機密操作認証失敗: $operation', name: _logName);
        return false;
      }
    } catch (e) {
      developer.log('機密操作認証チェックエラー: $e', name: _logName);
      return false;
    }
  }

  /// 生体認証設定の状態を取得
  static Future<Map<String, dynamic>> getBiometricStatus() async {
    try {
      final biometricEnabled = await isBiometricEnabled();
      final availableBiometrics = await getAvailableBiometrics();
      final hasPasscode = await SecureStorageService.hasPasscode();

      return {
        'biometric_enabled': biometricEnabled,
        'available_biometrics': availableBiometrics
            .map((e) => e.toString())
            .toList(),
        'has_passcode': hasPasscode,
        'is_device_supported': await _localAuth.isDeviceSupported(),
        'can_check_biometrics': await _localAuth.canCheckBiometrics,
      };
    } catch (e) {
      developer.log('生体認証状態取得エラー: $e', name: _logName);
      return {
        'biometric_enabled': false,
        'available_biometrics': [],
        'has_passcode': false,
        'is_device_supported': false,
        'can_check_biometrics': false,
        'error': e.toString(),
      };
    }
  }
}
