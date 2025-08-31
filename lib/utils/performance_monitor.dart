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

    // 各処理の閾値設定
    final thresholds = {'Firebase初期化': 200, 'テーマ設定初期化': 1000, 'アプリ起動全体': 5000};

    results.forEach((name, duration) {
      final threshold = thresholds[name] ?? 100;
      if (duration.inMilliseconds > threshold) {
        suggestions.add('$name: ${duration.inMilliseconds}ms - 最適化を検討してください');
      }
    });

    // 総合的な最適化提案
    final totalTime = results.values.fold<Duration>(
      Duration.zero,
      (sum, duration) => sum + duration,
    );

    if (totalTime.inMilliseconds > 3000) {
      suggestions.add('総初期化時間: ${totalTime.inMilliseconds}ms - 並列処理の検討を推奨');
    }

    return suggestions;
  }

  /// 詳細なパフォーマンスレポートを生成
  static void generateDetailedReport() {
    if (!kDebugMode) return;

    final results = getResults();
    if (results.isEmpty) return;

    developer.log('📊 詳細パフォーマンスレポート:', name: 'Performance');
    developer.log('=' * 50, name: 'Performance');

    // 処理時間順にソート
    final sortedResults = results.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedResults) {
      final percentage =
          (entry.value.inMilliseconds /
                  results.values.fold<int>(
                    0,
                    (sum, duration) => sum + duration.inMilliseconds,
                  ) *
                  100)
              .toStringAsFixed(1);

      developer.log(
        '${entry.key}: ${entry.value.inMilliseconds}ms (${percentage}%)',
        name: 'Performance',
      );
    }

    developer.log('=' * 50, name: 'Performance');

    // 最適化提案を表示
    final suggestions = getOptimizationSuggestions();
    if (suggestions.isNotEmpty) {
      developer.log('🚀 最適化提案:', name: 'Performance');
      for (final suggestion in suggestions) {
        developer.log('  - $suggestion', name: 'Performance');
      }
    }
  }
}
