import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// パフォーマンス監視クラス
class PerformanceMonitor {
  static final Map<String, DateTime> _startTimes = {};
  static final Map<String, Duration> _durations = {};

  /// パフォーマンス計測開始
  static void startTimer(String name) {
    if (kDebugMode) {
      _startTimes[name] = DateTime.now();
      developer.log('⏱️ 開始: $name', name: 'Performance');
    }
  }

  /// パフォーマンス計測終了
  static void endTimer(String name) {
    if (kDebugMode) {
      final startTime = _startTimes[name];
      if (startTime != null) {
        final duration = DateTime.now().difference(startTime);
        _durations[name] = duration;
        developer.log(
          '⏱️ 終了: $name - ${duration.inMilliseconds}ms',
          name: 'Performance',
        );
        _startTimes.remove(name);
      }
    }
  }

  /// パフォーマンス計測（即座に実行）
  static T measure<T>(String name, T Function() operation) {
    startTimer(name);
    try {
      final result = operation();
      endTimer(name);
      return result;
    } catch (e) {
      endTimer(name);
      rethrow;
    }
  }

  /// 非同期パフォーマンス計測
  static Future<T> measureAsync<T>(
    String name,
    Future<T> Function() operation,
  ) async {
    startTimer(name);
    try {
      final result = await operation();
      endTimer(name);
      return result;
    } catch (e) {
      endTimer(name);
      rethrow;
    }
  }

  /// 全計測結果を取得
  static Map<String, Duration> getResults() {
    return Map.from(_durations);
  }

  /// 計測結果をクリア
  static void clearResults() {
    _durations.clear();
    _startTimes.clear();
  }

  /// 起動時間の最適化提案を取得
  static List<String> getOptimizationSuggestions() {
    final suggestions = <String>[];
    final results = getResults();

    // 100ms以上かかる処理を警告
    results.forEach((name, duration) {
      if (duration.inMilliseconds > 100) {
        suggestions.add('$name: ${duration.inMilliseconds}ms - 最適化を検討してください');
      }
    });

    return suggestions;
  }
}
