import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// アプリ共通のロガーラッパー
///
/// - 本番環境では詳細ログを抑制し、デバッグ時は詳しく出力する
/// - 直接 `developer.log` を呼ぶ代わりにこのラッパーを使うことで
///   ログ出力の統一と将来の送信先変更（外部ロガー等）を容易にする
class AppLogger {
  static const _defaultName = 'roastplus_app';

  static void debug(String message, {String name = _defaultName}) {
    if (kDebugMode) {
      developer.log(message, name: name, level: 700); // DEBUG
    }
  }

  static void info(String message, {String name = _defaultName}) {
    developer.log(message, name: name, level: 800); // INFO
  }

  static void warn(String message, {String name = _defaultName}) {
    developer.log(message, name: name, level: 900); // WARNING
  }

  static void error(
    String message, {
    String name = _defaultName,
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
