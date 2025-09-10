import 'package:flutter/material.dart';
import '../../models/theme_settings.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// 機能カード（新しいデザイン）
class HomeFeatureCard extends StatelessWidget {
  final ThemeSettings themeSettings;
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isImportant;
  final Color? customColor;
  final Widget? badge;

  const HomeFeatureCard({
    super.key,
    required this.themeSettings,
    required this.title,
    required this.icon,
    required this.onTap,
    this.isImportant = false,
    this.customColor,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    // カテゴリ別の色を自動割り当て
    final cardColor = _getCardColor();
    final iconColor = _getIconColor();
    final borderColor = _getBorderColor();

    // WEB版とモバイル版で異なるスタイルを適用
    final isWeb = kIsWeb;

    return Card(
      elevation: isImportant ? 6 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isWeb ? 20 : 16),
      ),
      color: themeSettings.cardBackgroundColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isWeb ? 20 : 16),
        child: Container(
          padding: EdgeInsets.all(isWeb ? 16 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isWeb ? 20 : 16),
            border: Border.all(color: borderColor, width: isImportant ? 2 : 1),
            gradient: isWeb
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cardColor.withValues(alpha: 0.1),
                      cardColor.withValues(alpha: 0.05),
                    ],
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Container(
                    width: isWeb
                        ? (isImportant ? 56 : 48)
                        : (isImportant ? 48 : 40),
                    height: isWeb
                        ? (isImportant ? 56 : 48)
                        : (isImportant ? 48 : 40),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(isWeb ? 14 : 10),
                      boxShadow: isWeb
                          ? [
                              BoxShadow(
                                color: cardColor.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: isWeb
                          ? (isImportant ? 28 : 24)
                          : (isImportant ? 24 : 20),
                    ),
                  ),
                  if (badge != null)
                    Positioned(right: -2, top: -2, child: badge!),
                ],
              ),
              SizedBox(height: isWeb ? 12 : 8),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isWeb
                        ? (isImportant ? 14 : 13) * themeSettings.fontSizeScale
                        : (isImportant ? 12 : 11) * themeSettings.fontSizeScale,
                    fontWeight: isImportant ? FontWeight.bold : FontWeight.w600,
                    color: themeSettings.fontColor1,
                    fontFamily: themeSettings.fontFamily,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// カードの背景色を取得
  Color _getCardColor() {
    if (customColor != null) {
      return customColor!.withValues(alpha: 0.15);
    }

    // 重要機能は濃いブラウン
    if (isImportant) {
      return Color(0xFF8B4513).withValues(alpha: 0.15); // 濃いブラウン
    }

    // デフォルトはアイコン色
    return themeSettings.iconColor.withValues(alpha: 0.1);
  }

  /// アイコンの色を取得
  Color _getIconColor() {
    if (customColor != null) {
      return customColor!;
    }

    // 重要機能は濃いブラウン
    if (isImportant) {
      return Color(0xFF8B4513); // 濃いブラウン
    }

    // デフォルトはアイコン色
    return themeSettings.iconColor;
  }

  /// ボーダーの色を取得
  Color _getBorderColor() {
    if (customColor != null) {
      return customColor!.withValues(alpha: 0.3);
    }

    // 重要機能は濃いブラウン
    if (isImportant) {
      return Color(0xFF8B4513).withValues(alpha: 0.4); // 濃いブラウン
    }

    // デフォルトはアイコン色
    return themeSettings.iconColor.withValues(alpha: 0.15);
  }
}
