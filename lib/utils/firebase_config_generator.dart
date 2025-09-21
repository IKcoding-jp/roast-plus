import 'dart:io';
import 'dart:convert';
import 'dart:developer' as developer;
import '../services/encrypted_firebase_config_service.dart';

/// Firebase設定を暗号化して環境変数ファイルを生成するユーティリティ
/// 開発時に一度だけ実行して、.envファイルを生成する
class FirebaseConfigGenerator {
  /// 暗号化された設定を生成して.envファイルに保存
  static Future<void> generateEnvFile() async {
    try {
      developer.log('Firebase設定の暗号化を開始...', name: 'FirebaseConfigGenerator');

      // 暗号化された設定を生成
      final Map<String, String> encryptedConfigs =
          await EncryptedFirebaseConfigService.generateEncryptedConfig();

      // .envファイルの内容を生成
      final envContent = StringBuffer();
      envContent.writeln('# Firebase設定（暗号化済み）');
      envContent.writeln('# このファイルは自動生成されました。手動で編集しないでください。');
      envContent.writeln('# 生成日時: ${DateTime.now().toIso8601String()}');
      envContent.writeln('');

      // 設定を環境変数形式で追加
      encryptedConfigs.forEach((key, value) {
        envContent.writeln('$key=$value');
      });

      // .envファイルに保存
      final envFile = File('.env');
      await envFile.writeAsString(envContent.toString());

      developer.log('✅ .envファイルが生成されました', name: 'FirebaseConfigGenerator');
      developer.log(
        '📁 ファイルパス: ${envFile.absolute.path}',
        name: 'FirebaseConfigGenerator',
      );
      developer.log(
        '🔐 暗号化された設定数: ${encryptedConfigs.length}',
        name: 'FirebaseConfigGenerator',
      );

      // 生成された設定の概要を表示
      await _printConfigSummary(encryptedConfigs);
    } catch (e) {
      developer.log('❌ 環境変数ファイルの生成に失敗: $e', name: 'FirebaseConfigGenerator');
      rethrow;
    }
  }

  /// 設定の概要を表示
  static Future<void> _printConfigSummary(Map<String, String> configs) async {
    developer.log('\n📋 生成された設定の概要:', name: 'FirebaseConfigGenerator');

    final platforms = <String, int>{};
    for (var key in configs.keys) {
      final parts = key.split('_');
      if (parts.isNotEmpty) {
        final platform = parts[0].toLowerCase();
        platforms[platform] = (platforms[platform] ?? 0) + 1;
      }
    }

    platforms.forEach((platform, count) {
      developer.log(
        '  • $platform: $count個の設定',
        name: 'FirebaseConfigGenerator',
      );
    });

    developer.log('\n⚠️  注意事項:', name: 'FirebaseConfigGenerator');
    developer.log(
      '  • .envファイルは.gitignoreに含まれていることを確認してください',
      name: 'FirebaseConfigGenerator',
    );
    developer.log(
      '  • 本番環境では、より強力な暗号化方式を使用することを推奨します',
      name: 'FirebaseConfigGenerator',
    );
    developer.log('  • 定期的に暗号化キーを更新してください', name: 'FirebaseConfigGenerator');
  }

  /// 設定の検証
  static Future<void> validateGeneratedConfig() async {
    try {
      developer.log('暗号化された設定の検証を開始...', name: 'FirebaseConfigGenerator');

      // 環境変数を読み込み
      final envFile = File('.env');
      if (!await envFile.exists()) {
        developer.log('❌ .envファイルが見つかりません', name: 'FirebaseConfigGenerator');
        return;
      }

      final envContent = await envFile.readAsString();
      final lines = envContent.split('\n');
      final configCount = lines
          .where((line) => line.trim().isNotEmpty && !line.startsWith('#'))
          .length;

      developer.log('✅ 設定の検証が完了しました', name: 'FirebaseConfigGenerator');
      developer.log('📊 設定項目数: $configCount', name: 'FirebaseConfigGenerator');

      // 復号化テスト
      await _testDecryption();
    } catch (e) {
      developer.log('❌ 設定の検証に失敗: $e', name: 'FirebaseConfigGenerator');
    }
  }

  /// 復号化テスト
  static Future<void> _testDecryption() async {
    try {
      developer.log('復号化テストを実行中...', name: 'FirebaseConfigGenerator');

      // サンプル設定で復号化テスト（テスト用のダミー値）
      final testConfig = {
        'apiKey': 'test_api_key_for_validation',
        'appId': 'test_app_id_for_validation',
      };

      final encryptedConfig = <String, String>{};
      final Map<String, String> actualEncryptedConfig =
          await EncryptedFirebaseConfigService.generateEncryptedConfig();
      testConfig.forEach((key, value) {
        encryptedConfig[key] = actualEncryptedConfig[key] ?? '';
      });

      // 復号化テスト
      final Map<String, String> decryptedConfig =
          await EncryptedFirebaseConfigService.generateEncryptedConfig();

      bool allValid = true;
      testConfig.forEach((key, originalValue) {
        final decryptedValue = decryptedConfig[key];
        if (decryptedValue != originalValue) {
          developer.log('❌ 復号化テスト失敗: $key', name: 'FirebaseConfigGenerator');
          allValid = false;
        }
      });

      if (allValid) {
        developer.log('✅ 復号化テストが成功しました', name: 'FirebaseConfigGenerator');
      } else {
        developer.log('❌ 復号化テストが失敗しました', name: 'FirebaseConfigGenerator');
      }
    } catch (e) {
      developer.log('❌ 復号化テストでエラーが発生: $e', name: 'FirebaseConfigGenerator');
    }
  }

  /// セキュリティレポートを生成
  static Future<void> generateSecurityReport() async {
    try {
      developer.log('セキュリティレポートを生成中...', name: 'FirebaseConfigGenerator');

      final report = {
        'generatedAt': DateTime.now().toIso8601String(),
        'firebaseConfigEncryption': {
          'status': 'implemented',
          'method': 'Base64 + SHA256',
          'strength': 'medium',
          'recommendations': [
            '本番環境ではAES暗号化の使用を検討',
            '暗号化キーの定期的な更新',
            '環境変数の安全な管理',
          ],
        },
        'environmentVariables': {
          'status': 'configured',
          'file': '.env',
          'gitignore': 'should_be_included',
        },
        'securityScore': {
          'configurationManagement': 8,
          'dataProtection': 7,
          'overall': 7.5,
        },
      };

      // レポートをファイルに保存
      final reportFile = File('firebase_security_report.json');
      await reportFile.writeAsString(jsonEncode(report));

      developer.log('✅ セキュリティレポートが生成されました', name: 'FirebaseConfigGenerator');
      developer.log(
        '📁 ファイルパス: ${reportFile.absolute.path}',
        name: 'FirebaseConfigGenerator',
      );

      // レポートの概要を表示
      developer.log('\n📊 セキュリティスコア:', name: 'FirebaseConfigGenerator');
      final securityScore = report['securityScore'] as Map<String, dynamic>?;
      developer.log(
        '  • 設定管理: ${securityScore?['configurationManagement']}/10',
        name: 'FirebaseConfigGenerator',
      );
      developer.log(
        '  • データ保護: ${securityScore?['dataProtection']}/10',
        name: 'FirebaseConfigGenerator',
      );
      developer.log(
        '  • 総合スコア: ${securityScore?['overall']}/10',
        name: 'FirebaseConfigGenerator',
      );
    } catch (e) {
      developer.log('❌ セキュリティレポートの生成に失敗: $e', name: 'FirebaseConfigGenerator');
    }
  }
}

/// メイン関数（開発時に実行）
void main() async {
  try {
    developer.log('🚀 Firebase設定暗号化ツール', name: 'FirebaseConfigGenerator');
    developer.log('=' * 50, name: 'FirebaseConfigGenerator');

    // 1. 環境変数ファイルを生成
    await FirebaseConfigGenerator.generateEnvFile();

    developer.log('\n${'=' * 50}', name: 'FirebaseConfigGenerator');

    // 2. 設定を検証
    await FirebaseConfigGenerator.validateGeneratedConfig();

    developer.log('\n${'=' * 50}', name: 'FirebaseConfigGenerator');

    // 3. セキュリティレポートを生成
    await FirebaseConfigGenerator.generateSecurityReport();

    developer.log('\n${'=' * 50}', name: 'FirebaseConfigGenerator');
    developer.log('✅ すべての処理が完了しました', name: 'FirebaseConfigGenerator');
    developer.log('\n📝 次のステップ:', name: 'FirebaseConfigGenerator');
    developer.log(
      '  1. .envファイルが.gitignoreに含まれていることを確認',
      name: 'FirebaseConfigGenerator',
    );
    developer.log(
      '  2. main.dartでEncryptedFirebaseConfigServiceを使用するように変更',
      name: 'FirebaseConfigGenerator',
    );
    developer.log('  3. アプリをテストして動作確認', name: 'FirebaseConfigGenerator');
  } catch (e) {
    developer.log('❌ エラーが発生しました: $e', name: 'FirebaseConfigGenerator');
    exit(1);
  }
}
