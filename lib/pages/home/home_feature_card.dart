import 'package:flutter/material.dart';
import '../../models/theme_settings.dart';

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

    return Container(
      height: 120, // 統一された高さ
      child: Card(
        elevation: isImportant ? 4 : 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: themeSettings.backgroundColor2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor,
                width: isImportant ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    Container(
                      width: isImportant ? 56 : 48,
                      height: isImportant ? 56 : 48,
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: iconColor,
                        size: isImportant ? 28 : 24,
                      ),
                    ),
                    if (badge != null)
                      Positioned(right: -2, top: -2, child: badge!),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize:
                        (isImportant ? 14 : 13) * themeSettings.fontSizeScale,
                    fontWeight: isImportant ? FontWeight.bold : FontWeight.w600,
                    color: themeSettings.fontColor1,
                    fontFamily: themeSettings.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// カードの背景色を取得
  Color _getCardColor() {
    if (customColor != null) {
      return customColor!.withOpacity(0.15);
    }

    // 重要機能は濃いブラウン
    if (isImportant) {
      return Color(0xFF8B4513).withOpacity(0.15); // 濃いブラウン
    }

    // デフォルトはアイコン色
    return themeSettings.iconColor.withOpacity(0.1);
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
      return customColor!.withOpacity(0.3);
    }

    // 重要機能は濃いブラウン
    if (isImportant) {
      return Color(0xFF8B4513).withOpacity(0.4); // 濃いブラウン
    }

    // デフォルトはアイコン色
    return themeSettings.iconColor.withOpacity(0.15);
  }
}
