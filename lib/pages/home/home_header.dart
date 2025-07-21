import 'package:flutter/material.dart';
import '../../models/theme_settings.dart';

/// ホーム画面のヘッダー部分
class HomeHeader extends StatelessWidget {
  final ThemeSettings themeSettings;

  const HomeHeader({super.key, required this.themeSettings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: themeSettings.iconColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.coffee, color: themeSettings.iconColor, size: 30),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'おはようございます！',
                  style: TextStyle(
                    fontSize: 24 * themeSettings.fontSizeScale,
                    fontWeight: FontWeight.bold,
                    color: themeSettings.fontColor1,
                    fontFamily: themeSettings.fontFamily,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '今日も素晴らしい焙煎を',
                  style: TextStyle(
                    fontSize: 16 * themeSettings.fontSizeScale,
                    color: themeSettings.fontColor1.withOpacity(0.7),
                    fontFamily: themeSettings.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
