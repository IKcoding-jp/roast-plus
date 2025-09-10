import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Added for kDebugMode
import '../config/app_config.dart';

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

  // 新しい最適化設定
  static const bool enableListViewOptimization = true;
  static const bool enableProviderOptimization = true;
  static const bool enableImageOptimization = true;
  static const bool enableTextOptimization = true;
  static const bool enableMemoryOptimization = true;

  // キャッシュ設定
  static const Duration cacheExpirationDuration = Duration(minutes: 30);
  static const int maxCacheSize = 1000;
  static const bool enableCacheCompression = true;

  // アニメーション設定
  static const bool enableReducedMotion = false;
  static const double animationScale = 1.0;

  // ネットワーク設定
  static const Duration networkTimeout = Duration(seconds: 10);
  static const int maxConcurrentNetworkRequests = 3;

  /// デバッグモードでのパフォーマンス設定
  static Map<String, dynamic> getDebugConfig() {
    return {
      'enablePerformanceLogging': true,
      'enableMemoryMonitoring': true,
      'enableWidgetRebuildLogging': true,
      'enableNetworkLogging': true,
      'enableListViewOptimization': enableListViewOptimization,
      'enableProviderOptimization': enableProviderOptimization,
      'enableImageOptimization': enableImageOptimization,
      'enableTextOptimization': enableTextOptimization,
      'enableMemoryOptimization': enableMemoryOptimization,
      'cacheExpirationDuration': cacheExpirationDuration,
      'maxCacheSize': maxCacheSize,
      'enableCacheCompression': enableCacheCompression,
      'enableReducedMotion': enableReducedMotion,
      'animationScale': animationScale,
      'networkTimeout': networkTimeout,
      'maxConcurrentNetworkRequests': maxConcurrentNetworkRequests,
    };
  }

  /// リリースモードでのパフォーマンス設定
  static Map<String, dynamic> getReleaseConfig() {
    return {
      'enablePerformanceLogging': false,
      'enableMemoryMonitoring': false,
      'enableWidgetRebuildLogging': false,
      'enableNetworkLogging': false,
      'enableListViewOptimization': enableListViewOptimization,
      'enableProviderOptimization': enableProviderOptimization,
      'enableImageOptimization': enableImageOptimization,
      'enableTextOptimization': enableTextOptimization,
      'enableMemoryOptimization': enableMemoryOptimization,
      'cacheExpirationDuration': cacheExpirationDuration,
      'maxCacheSize': maxCacheSize,
      'enableCacheCompression': enableCacheCompression,
      'enableReducedMotion': enableReducedMotion,
      'animationScale': animationScale,
      'networkTimeout': networkTimeout,
      'maxConcurrentNetworkRequests': maxConcurrentNetworkRequests,
    };
  }

  /// 現在の設定を取得
  static Map<String, dynamic> getCurrentConfig() {
    return kDebugMode ? getDebugConfig() : getReleaseConfig();
  }

  /// 設定値の取得
  static T getSetting<T>(String key, T defaultValue) {
    final config = getCurrentConfig();
    return config[key] as T? ?? defaultValue;
  }
}

Future<bool> isDonorUser() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  // 寄付者として登録されたメールアドレス（環境変数から取得）
  final donorEmails = await AppConfig.donorEmails;

  if (donorEmails.contains(user.email)) return true;

  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('settings')
      .doc('donation')
      .get();
  if (doc.exists && doc.data() != null) {
    return doc.data()!['isDonor'] == true;
  }
  return false;
}
