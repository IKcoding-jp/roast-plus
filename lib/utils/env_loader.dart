import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';

/// 環境変数ファイルを読み込むユーティリティ
class EnvLoader {
  static const String _logName = 'EnvLoader';
  static Map<String, String>? _cachedEnvVars;

  /// app_config.envファイルから環境変数を読み込み
  static Future<Map<String, String>> loadEnvFile() async {
    if (_cachedEnvVars != null) {
      return _cachedEnvVars!;
    }

    try {
      String content;

      // まずアセットから読み込みを試行
      try {
        content = await rootBundle.loadString('app_config.env');
        developer.log('app_config.envファイルをアセットから読み込みました', name: _logName);
      } catch (e) {
        developer.log('アセットからapp_config.envファイルの読み込みに失敗: $e', name: _logName);

        // アセットから読み込めない場合は、ファイルシステムから読み込みを試行
        final currentDir = Directory.current.path;
        developer.log('現在の作業ディレクトリ: $currentDir', name: _logName);

        // 複数のパスを試行
        final possiblePaths = [
          'app_config.env',
          '../app_config.env',
          '../../app_config.env',
          '../../../app_config.env',
          'assets/app_config.env',
          '$currentDir/app_config.env',
          '$currentDir/../app_config.env',
          '$currentDir/../../app_config.env',
        ];

        File? envFile;
        for (final path in possiblePaths) {
          final file = File(path);
          if (await file.exists()) {
            envFile = file;
            developer.log('app_config.envファイルを発見: $path', name: _logName);
            break;
          }
        }

        if (envFile == null) {
          developer.log(
            'app_config.envファイルが見つかりません。試行したパス: $possiblePaths',
            name: _logName,
          );
          return {};
        }

        content = await envFile.readAsString();
      }
      final envVars = <String, String>{};

      for (final line in content.split('\n')) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty || trimmedLine.startsWith('#')) {
          continue;
        }

        final equalIndex = trimmedLine.indexOf('=');
        if (equalIndex > 0) {
          final key = trimmedLine.substring(0, equalIndex).trim();
          final value = trimmedLine.substring(equalIndex + 1).trim();
          envVars[key] = value;
        }
      }

      _cachedEnvVars = envVars;
      developer.log(
        'app_config.envから${envVars.length}個の環境変数を読み込みました',
        name: _logName,
      );
      return envVars;
    } catch (e) {
      developer.log('app_config.envファイルの読み込みに失敗: $e', name: _logName);
      return {};
    }
  }

  /// 指定されたキーの環境変数を取得
  static Future<String> getEnvVar(
    String key, {
    String defaultValue = '',
  }) async {
    final envVars = await loadEnvFile();
    return envVars[key] ?? defaultValue;
  }

  /// 環境変数をクリア（テスト用）
  static void clearCache() {
    _cachedEnvVars = null;
  }
}
