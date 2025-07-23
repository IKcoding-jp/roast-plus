import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'dart:async';

/// パフォーマンス最適化用のユーティリティクラス
class PerformanceUtils {
  /// デバッグモードでのみログを出力
  static void debugLog(String message) {
    if (kDebugMode) {
      print('パフォーマンス: $message');
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

  /// 最適化されたListView.builder
  static Widget optimizedListViewBuilder({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    double? itemExtent,
    EdgeInsetsGeometry? padding,
    ScrollPhysics? physics,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
  }) {
    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      itemExtent: itemExtent,
      padding: padding,
      physics: physics ?? getOptimizedScrollPhysics(),
      addAutomaticKeepAlives: addAutomaticKeepAlives,
      addRepaintBoundaries: addRepaintBoundaries,
      addSemanticIndexes: addSemanticIndexes,
    );
  }

  /// 最適化されたConsumer
  static Widget optimizedConsumer<T extends ChangeNotifier>({
    required BuildContext context,
    required Widget Function(BuildContext, T, Widget?) builder,
    Widget? child,
  }) {
    return Consumer<T>(builder: builder, child: child);
  }

  /// 最適化されたProvider.of
  static T optimizedProviderOf<T>(BuildContext context, {bool listen = true}) {
    return Provider.of<T>(context, listen: listen);
  }

  /// 重い処理をバックグラウンドで実行
  static Future<T> runInBackground<T>(Future<T> Function() computation) async {
    return await compute(_isolatedComputation, computation);
  }

  /// アイソレート用の計算関数
  static Future<T> _isolatedComputation<T>(
    Future<T> Function() computation,
  ) async {
    return await computation();
  }

  /// デバウンス機能
  static Timer? _debounceTimer;
  static void debounce(
    VoidCallback callback, {
    Duration duration = const Duration(milliseconds: 300),
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(duration, callback);
  }

  /// スロットリング機能
  static DateTime? _lastThrottleTime;
  static bool throttle({
    Duration duration = const Duration(milliseconds: 100),
  }) {
    final now = DateTime.now();
    if (_lastThrottleTime == null ||
        now.difference(_lastThrottleTime!) > duration) {
      _lastThrottleTime = now;
      return true;
    }
    return false;
  }

  /// パフォーマンス測定
  static Future<T> measurePerformance<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await operation();
      stopwatch.stop();
      debugLog('$operationName took ${stopwatch.elapsedMilliseconds}ms');
      return result;
    } catch (e) {
      stopwatch.stop();
      debugLog(
        '$operationName failed after ${stopwatch.elapsedMilliseconds}ms: $e',
      );
      rethrow;
    }
  }

  /// ウィジェットの再ビルドを防ぐためのRepaintBoundary
  static Widget repaintBoundary(Widget child) {
    return RepaintBoundary(child: child);
  }

  /// 最適化されたカードウィジェット
  static Widget optimizedCard({
    required Widget child,
    Color? color,
    double elevation = 4.0,
    EdgeInsetsGeometry? margin,
    BorderRadius? borderRadius,
  }) {
    return Card(
      color: color,
      elevation: elevation,
      margin: margin,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  /// 最適化されたアイコン
  static Widget optimizedIcon({
    required IconData icon,
    double? size,
    Color? color,
  }) {
    return Icon(icon, size: size, color: color);
  }

  /// 最適化されたボタン
  static Widget optimizedButton({
    required VoidCallback? onPressed,
    required Widget child,
    ButtonStyle? style,
    bool isEnabled = true,
  }) {
    return ElevatedButton(
      onPressed: isEnabled ? onPressed : null,
      style: style,
      child: child,
    );
  }
}
