import 'package:flutter/material.dart';
import '../../models/theme_settings.dart';
import 'home_feature_card.dart';

/// 機能セクションのヘッダー
class HomeFeatureSection extends StatelessWidget {
  final ThemeSettings themeSettings;
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<HomeFeatureCard> children;
  final bool isExpanded;
  final VoidCallback? onToggle;

  const HomeFeatureSection({
    super.key,
    required this.themeSettings,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.children,
    this.isExpanded = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // セクションヘッダー（折りたたみ可能）
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 22),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18 * themeSettings.fontSizeScale,
                      fontWeight: FontWeight.bold,
                      color: themeSettings.fontColor1,
                      fontFamily: themeSettings.fontFamily,
                    ),
                  ),
                ),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: accentColor,
                  size: 24,
                ),
              ],
            ),
          ),
        ),

        // 折りたたみ可能なコンテンツ
        AnimatedCrossFade(
          firstChild: Container(),
          secondChild: Container(
            margin: EdgeInsets.only(top: 16),
            child: GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: children,
            ),
          ),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: Duration(milliseconds: 300),
        ),
      ],
    );
  }
}
