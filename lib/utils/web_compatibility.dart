import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Web版用のPaint代替クラス
class WebPaint {
  final Color? color;
  final Shader? shader;

  WebPaint({this.color, this.shader});

  /// Web版ではshaderを直接使用できないため、色を返す
  Color? get effectiveColor {
    if (color != null) return color;
    if (shader != null && shader is LinearGradient) {
      final gradient = shader as LinearGradient;
      return gradient.colors.isNotEmpty ? gradient.colors.first : null;
    }
    return null;
  }
}

/// Webプラットフォームでのdart:ui互換性を提供するユーティリティクラス
class WebCompatibility {
  /// Web版かどうかを判定
  static bool get isWeb => kIsWeb;

  /// Web版用のPaint作成
  static WebPaint createPaint({Color? color, Shader? shader}) {
    return WebPaint(color: color, shader: shader);
  }

  /// Web版用のRect作成
  static Rect createRect(double left, double top, double width, double height) {
    return Rect.fromLTWH(left, top, width, height);
  }

  /// Web版用の色の透明度変更（withValuesの代替）
  static Color withAlpha(Color color, double alpha) {
    return Color.fromARGB(
      (alpha * 255).round(),
      (color.r * 255.0).round() & 0xff,
      (color.g * 255.0).round() & 0xff,
      (color.b * 255.0).round() & 0xff,
    );
  }

  /// Web版用のLinearGradient作成
  static LinearGradient createLinearGradient({
    required List<Color> colors,
    AlignmentGeometry? begin,
    AlignmentGeometry? end,
  }) {
    return LinearGradient(
      colors: colors,
      begin: begin ?? Alignment.topCenter,
      end: end ?? Alignment.bottomCenter,
    );
  }

  /// Web版用のテキストスタイル作成
  static TextStyle createTextStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    WebPaint? foreground,
    double? letterSpacing,
    String? fontFamily,
    List<Shadow>? shadows,
  }) {
    // Web版ではforegroundのshaderを無視し、色のみを使用
    Color? effectiveColor = color;
    if (foreground != null) {
      effectiveColor = foreground.effectiveColor ?? color;
    }

    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: effectiveColor,
      letterSpacing: letterSpacing,
      fontFamily: fontFamily,
      shadows: shadows,
    );
  }

  /// Web版用のBoxShadow作成
  static BoxShadow createBoxShadow({
    Color? color,
    double? blurRadius,
    Offset? offset,
  }) {
    return BoxShadow(
      color: color ?? Color.fromARGB(25, 0, 0, 0), // alpha: 0.1 = 25/255
      blurRadius: blurRadius ?? 4.0,
      offset: offset ?? const Offset(0, 2),
    );
  }

  /// Web版用のShadow作成
  static Shadow createShadow({
    Color? color,
    double? blurRadius,
    Offset? offset,
  }) {
    return Shadow(
      color: color ?? Color.fromARGB(25, 0, 0, 0), // alpha: 0.1 = 25/255
      blurRadius: blurRadius ?? 4.0,
      offset: offset ?? const Offset(0, 2),
    );
  }

  /// Web版用の色の透明度変更（withValuesの代替）
  static Color withValues(Color color, {double? alpha}) {
    if (alpha != null) {
      return Color.fromARGB(
        (alpha * 255).round(),
        (color.r * 255.0).round() & 0xff,
        (color.g * 255.0).round() & 0xff,
        (color.b * 255.0).round() & 0xff,
      );
    }
    return color;
  }

  /// Web版用の色の透明度変更（withValuesの代替、静的メソッド）
  static Color colorWithValues(Color color, {double? alpha}) {
    if (alpha != null) {
      return Color.fromARGB(
        (alpha * 255).round(),
        (color.r * 255.0).round() & 0xff,
        (color.g * 255.0).round() & 0xff,
        (color.b * 255.0).round() & 0xff,
      );
    }
    return color;
  }
}

/// Web版互換性のためのColor拡張
extension WebColorExtension on Color {
  /// Web版用のwithValues代替メソッド
  Color withValues({double? alpha}) {
    if (alpha != null) {
      return Color.fromARGB(
        (alpha * 255).round(),
        (r * 255.0).round() & 0xff,
        (g * 255.0).round() & 0xff,
        (b * 255.0).round() & 0xff,
      );
    }
    return this;
  }
}
