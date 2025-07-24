import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'app_performance_config.dart';

/// メモリキャッシュを管理するクラス
class MemoryCacheManager {
  static final MemoryCacheManager _instance = MemoryCacheManager._internal();
  factory MemoryCacheManager() => _instance;
  MemoryCacheManager._internal();

  final Map<String, _CacheEntry> _cache = {};
  final Queue<String> _accessOrder = Queue<String>();
  Timer? _cleanupTimer;

  /// キャッシュにデータを保存
  void set<T>(String key, T data, {Duration? expiration}) {
    final entry = _CacheEntry(
      data: data,
      timestamp: DateTime.now(),
      expiration: expiration ?? const Duration(minutes: 30),
    );

    _cache[key] = entry;
    _updateAccessOrder(key);
    _scheduleCleanup();
  }

  /// キャッシュからデータを取得
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    // 有効期限チェック
    if (entry.isExpired) {
      _cache.remove(key);
      _accessOrder.remove(key);
      return null;
    }

    _updateAccessOrder(key);
    return entry.data as T?;
  }

  /// キャッシュからデータを削除
  void remove(String key) {
    _cache.remove(key);
    _accessOrder.remove(key);
  }

  /// キャッシュをクリア
  void clear() {
    _cache.clear();
    _accessOrder.clear();
    _cleanupTimer?.cancel();
  }

  /// キャッシュサイズを取得
  int get size => _cache.length;

  /// キャッシュが空かどうか
  bool get isEmpty => _cache.isEmpty;

  /// アクセス順序を更新
  void _updateAccessOrder(String key) {
    _accessOrder.remove(key);
    _accessOrder.add(key);
  }

  /// クリーンアップをスケジュール
  void _scheduleCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer(const Duration(minutes: 5), _cleanup);
  }

  /// 期限切れのエントリを削除
  void _cleanup() {
    final expiredKeys = <String>[];
    final maxSize = AppPerformanceConfig.maxCacheSize;

    // 期限切れのエントリを特定
    for (final entry in _cache.entries) {
      if (entry.value.isExpired) {
        expiredKeys.add(entry.key);
      }
    }

    // 期限切れのエントリを削除
    for (final key in expiredKeys) {
      _cache.remove(key);
      _accessOrder.remove(key);
    }

    // サイズ制限を超えている場合、最も古いエントリを削除
    while (_cache.length > maxSize && _accessOrder.isNotEmpty) {
      final oldestKey = _accessOrder.removeFirst();
      _cache.remove(oldestKey);
    }

    if (kDebugMode) {
      print(
        'MemoryCache: Cleaned up ${expiredKeys.length} expired entries. Current size: ${_cache.length}',
      );
    }
  }

  /// キャッシュの統計情報を取得
  Map<String, dynamic> getStats() {
    int expiredCount = 0;
    int validCount = 0;

    for (final entry in _cache.values) {
      if (entry.isExpired) {
        expiredCount++;
      } else {
        validCount++;
      }
    }

    return {
      'total': _cache.length,
      'valid': validCount,
      'expired': expiredCount,
      'memoryUsage': _estimateMemoryUsage(),
    };
  }

  /// メモリ使用量を推定
  int _estimateMemoryUsage() {
    // 簡易的な推定（実際のメモリ使用量とは異なる場合があります）
    return _cache.length * 1024; // 1KB per entry as rough estimate
  }
}

/// キャッシュエントリクラス
class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  final Duration expiration;

  _CacheEntry({
    required this.data,
    required this.timestamp,
    required this.expiration,
  });

  bool get isExpired {
    return DateTime.now().difference(timestamp) > expiration;
  }
}
