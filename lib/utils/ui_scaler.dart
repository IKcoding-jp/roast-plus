import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/theme_settings.dart';

class UIScaler {
  static double getFontSize(BuildContext context, double baseSize) {
    final themeSettings = Provider.of<ThemeSettings>(context, listen: false);
    return baseSize * themeSettings.fontSizeScale;
  }

  static TextStyle getTextStyle(BuildContext context, TextStyle baseStyle) {
    final themeSettings = Provider.of<ThemeSettings>(context, listen: false);
    return baseStyle.copyWith(
      fontSize: (baseStyle.fontSize ?? 14) * themeSettings.fontSizeScale,
    );
  }
}

// スケール可能なテキストウィジェット
class ScalableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const ScalableText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);
    final scaledStyle = style?.copyWith(
      fontSize: (style?.fontSize ?? 14) * themeSettings.fontSizeScale,
    );

    return Text(
      text,
      style: scaledStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
