/// アプリケーション設定管理クラス
/// 個人情報や機密情報を安全に管理する
class AppConfig {
  // 開発者・管理者のメールアドレス
  // 環境変数から取得、デフォルト値は空文字列
  static const String developerEmail = String.fromEnvironment(
    'DEVELOPER_EMAIL',
    defaultValue: '',
  );

  static const String feedbackEmail = String.fromEnvironment(
    'FEEDBACK_EMAIL',
    defaultValue: '',
  );

  // 寄付者メールアドレス（カンマ区切り）
  static const String donorEmailsEnv = String.fromEnvironment(
    'DONOR_EMAILS',
    defaultValue: '',
  );

  /// 寄付者メールアドレスのリストを取得
  static List<String> get donorEmails {
    if (donorEmailsEnv.isEmpty) {
      return [];
    }
    return donorEmailsEnv
        .split(',')
        .map((email) => email.trim())
        .where((email) => email.isNotEmpty)
        .toList();
  }

  /// 開発者メールアドレスかどうかを判定
  static bool isDeveloperEmail(String email) {
    if (developerEmail.isEmpty) return false;
    return email == developerEmail;
  }

  /// フィードバック送信先メールアドレスを取得
  static String get feedbackRecipientEmail {
    return feedbackEmail.isNotEmpty ? feedbackEmail : developerEmail;
  }

  /// 設定が正しく読み込まれているかチェック
  static bool get isConfigValid {
    return developerEmail.isNotEmpty && feedbackEmail.isNotEmpty;
  }

  /// デバッグ用の設定情報（個人情報は含まない）
  static Map<String, dynamic> get debugInfo {
    return {
      'hasDeveloperEmail': developerEmail.isNotEmpty,
      'hasFeedbackEmail': feedbackEmail.isNotEmpty,
      'donorEmailsCount': donorEmails.length,
      'isConfigValid': isConfigValid,
    };
  }
}
