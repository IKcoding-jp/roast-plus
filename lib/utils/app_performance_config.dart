/// アプリ全体のパフォーマンス設定を管理するクラス
class AppPerformanceConfig {
  // リストビューの設定
  static const int defaultListLimit = 50;
  static const int maxListItems = 1000;
  static const double defaultItemExtent = 80.0;

  // キャッシュ設定
  static const int imageCacheSize = 100;
  static const int textCacheSize = 200;

  // データベース設定
  static const int firestoreBatchSize = 25;
  static const int firestoreQueryLimit = 50;

  // UI設定
  static const double defaultAnimationDuration = 300.0;
  static const double fastAnimationDuration = 150.0;

  // メモリ設定
  static const int maxCachedImages = 50;
  static const int maxCachedTexts = 100;

  // パフォーマンス閾値
  static const int maxConcurrentOperations = 5;
  static const int maxRetryAttempts = 3;

  /// デバッグモードでのパフォーマンス設定
  static Map<String, dynamic> getDebugConfig() {
    return {
      'enablePerformanceLogging': true,
      'enableMemoryMonitoring': true,
      'enableWidgetRebuildLogging': true,
      'enableNetworkLogging': true,
    };
  }

  /// リリースモードでのパフォーマンス設定
  static Map<String, dynamic> getReleaseConfig() {
    return {
      'enablePerformanceLogging': false,
      'enableMemoryMonitoring': false,
      'enableWidgetRebuildLogging': false,
      'enableNetworkLogging': false,
    };
  }
}
