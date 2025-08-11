import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../utils/web_ui_utils.dart';

/// WEB版専用のレスポンシブウィジェット
class WebResponsiveWidget extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final Widget? fallback;

  const WebResponsiveWidget({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return mobile;
    }

    if (WebUIUtils.isDesktop(context)) {
      return desktop ?? tablet ?? mobile;
    } else if (WebUIUtils.isTablet(context)) {
      return tablet ?? mobile;
    } else {
      return mobile;
    }
  }
}

/// WEB版専用のレスポンシブレイアウトビルダー
class WebResponsiveBuilder extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  )
  builder;

  const WebResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return builder(context, true, false, false);
    }

    final isMobile = WebUIUtils.isMobile(context);
    final isTablet = WebUIUtils.isTablet(context);
    final isDesktop = WebUIUtils.isDesktop(context);

    return builder(context, isMobile, isTablet, isDesktop);
  }
}

/// WEB版専用のアダプティブカード
class WebAdaptiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double? elevation;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const WebAdaptiveCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.elevation,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Card(
        margin: margin,
        elevation: elevation,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius ?? BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? BorderRadius.circular(12),
          child: Padding(padding: padding ?? EdgeInsets.all(16), child: child),
        ),
      );
    }

    // WEB版ではより大きなカードとパディング
    final isDesktop = WebUIUtils.isDesktop(context);

    return Card(
      margin: margin ?? EdgeInsets.all(isDesktop ? 16 : 8),
      elevation: elevation ?? (isDesktop ? 4 : 2),
      shape: RoundedRectangleBorder(
        borderRadius:
            borderRadius ?? BorderRadius.circular(isDesktop ? 16 : 12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            borderRadius ?? BorderRadius.circular(isDesktop ? 16 : 12),
        child: Padding(
          padding: padding ?? EdgeInsets.all(isDesktop ? 24 : 16),
          child: child,
        ),
      ),
    );
  }
}

/// WEB版専用のアダプティブボタン
class WebAdaptiveButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;

  const WebAdaptiveButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.fontSize,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon) : SizedBox.shrink(),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          textStyle: TextStyle(fontSize: fontSize),
          padding: padding,
        ),
      );
    }

    // WEB版ではより大きなボタン
    final isDesktop = WebUIUtils.isDesktop(context);

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon != null
          ? Icon(icon, size: isDesktop ? 24 : 20)
          : SizedBox.shrink(),
      label: Text(
        text,
        style: TextStyle(
          fontSize: fontSize ?? (isDesktop ? 18 : 16),
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding:
            padding ??
            EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 24,
              vertical: isDesktop ? 16 : 12,
            ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isDesktop ? 12 : 8),
        ),
      ),
    );
  }
}

/// WEB版専用のアダプティブテキスト
class WebAdaptiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const WebAdaptiveText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    // WEB版ではフォントサイズを調整
    final fontSizeScale = WebUIUtils.getFontSizeScale(context);
    final scaledStyle = style?.copyWith(
      fontSize: (style?.fontSize ?? 14) * fontSizeScale,
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
