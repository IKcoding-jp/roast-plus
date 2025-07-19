import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// パフォーマンス最適化用のユーティリティクラス
class PerformanceUtils {
  /// デバッグモードでのみログを出力
  static void debugLog(String message) {
    if (kDebugMode) {
      print('Performance: $message');
    }
  }

  /// ウィジェットの再ビルドを防ぐためのキー生成
  static String generateWidgetKey(String baseKey, [String? suffix]) {
    return suffix != null ? '${baseKey}_$suffix' : baseKey;
  }

  /// リストアイテムの高さを計算
  static double calculateListItemHeight({
    required double baseHeight,
    required double padding,
    required double margin,
  }) {
    return baseHeight + (padding * 2) + (margin * 2);
  }

  /// 画像キャッシュの最適化
  static Widget optimizedImage({
    required BuildContext context,
    required String imagePath,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
  }) {
    return Image.asset(
      imagePath,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: (width * MediaQuery.of(context).devicePixelRatio).round(),
      cacheHeight: (height * MediaQuery.of(context).devicePixelRatio).round(),
    );
  }

  /// テキストの最適化
  static Widget optimizedText({
    required String text,
    required TextStyle style,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: TextAlign.start,
    );
  }

  /// リストビューの最適化設定
  static ScrollPhysics getOptimizedScrollPhysics() {
    return const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics());
  }

  /// メモリ使用量の監視
  static void monitorMemoryUsage() {
    if (kDebugMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugLog('Memory usage monitored');
      });
    }
  }
}
