import 'dart:developer' as developer;
import '../utils/env_loader.dart';

/// アプリケーション設定管理クラス
/// 個人情報や機密情報を安全に管理する
class AppConfig {
  static const String _logName = 'AppConfig';

  // キャッシュされた環境変数
  static Map<String, String>? _cachedEnvVars;

  /// 環境変数を読み込み（キャッシュ機能付き）
  static Future<Map<String, String>> _loadEnvVars() async {
    if (_cachedEnvVars != null) {
      developer.log('AppConfig: キャッシュされた環境変数を使用', name: _logName);
      return _cachedEnvVars!;
    }

    try {
      _cachedEnvVars = await EnvLoader.loadEnvFile();
      developer.log(
        'AppConfig: 環境変数を読み込みました - 件数: ${_cachedEnvVars!.length}',
        name: _logName,
      );
      developer.log(
        'AppConfig: 読み込まれた環境変数: ${_cachedEnvVars!.keys.toList()}',
        name: _logName,
      );
      return _cachedEnvVars!;
    } catch (e) {
      developer.log('AppConfig: 環境変数読み込みエラー: $e', name: _logName);
      _cachedEnvVars = {};
      return _cachedEnvVars!;
    }
  }

  /// 開発者・管理者のメールアドレスを取得
  static Future<String> get developerEmail async {
    final envVars = await _loadEnvVars();
    return envVars['DEVELOPER_EMAIL'] ?? '';
  }

  /// フィードバック送信先メールアドレスを取得
  static Future<String> get feedbackEmail async {
    final envVars = await _loadEnvVars();
    return envVars['FEEDBACK_EMAIL'] ?? '';
  }

  /// 寄付者メールアドレス（カンマ区切り）を取得
  static Future<String> get donorEmailsEnv async {
    final envVars = await _loadEnvVars();
    return envVars['DONOR_EMAILS'] ?? '';
  }

  /// 寄付者メールアドレスのリストを取得
  static Future<List<String>> get donorEmails async {
    final donorEmailsStr = await donorEmailsEnv;
    if (donorEmailsStr.isEmpty) {
      return [];
    }
    return donorEmailsStr
        .split(',')
        .map((email) => email.trim())
        .where((email) => email.isNotEmpty)
        .toList();
  }

  /// 開発者メールアドレスかどうかを判定
  static Future<bool> isDeveloperEmail(String email) async {
    final devEmail = await developerEmail;
    developer.log(
      'AppConfig: 開発者メール判定 - 入力: $email, 設定値: $devEmail',
      name: _logName,
    );
    if (devEmail.isEmpty) {
      developer.log('AppConfig: 開発者メールが設定されていません', name: _logName);
      return false;
    }
    final isDeveloper = email == devEmail;
    developer.log('AppConfig: 開発者メール判定結果: $isDeveloper', name: _logName);
    return isDeveloper;
  }

  /// 寄付者メールアドレスかどうかを判定
  static Future<bool> isDonorEmail(String email) async {
    final donorEmailsList = await donorEmails;
    developer.log(
      'AppConfig: 寄付者メール判定 - 入力: $email, 設定値: $donorEmailsList',
      name: _logName,
    );
    final isDonor = donorEmailsList.contains(email);
    developer.log('AppConfig: 寄付者メール判定結果: $isDonor', name: _logName);
    return isDonor;
  }

  /// フィードバック送信先メールアドレスを取得
  static Future<String> get feedbackRecipientEmail async {
    final feedbackEmail = await AppConfig.feedbackEmail;
    if (feedbackEmail.isNotEmpty) {
      return feedbackEmail;
    }
    return await developerEmail;
  }

  /// 設定が正しく読み込まれているかチェック
  static Future<bool> get isConfigValid async {
    final devEmail = await developerEmail;
    final feedbackEmail = await AppConfig.feedbackEmail;
    return devEmail.isNotEmpty && feedbackEmail.isNotEmpty;
  }

  /// デバッグ用の設定情報（個人情報は含まない）
  static Future<Map<String, dynamic>> get debugInfo async {
    final devEmail = await developerEmail;
    final feedbackEmail = await AppConfig.feedbackEmail;
    final donorEmailsList = await donorEmails;

    return {
      'hasDeveloperEmail': devEmail.isNotEmpty,
      'hasFeedbackEmail': feedbackEmail.isNotEmpty,
      'donorEmailsCount': donorEmailsList.length,
      'isConfigValid': await isConfigValid,
    };
  }

  /// キャッシュをクリア（テスト用）
  static void clearCache() {
    _cachedEnvVars = null;
    EnvLoader.clearCache();
  }
}
