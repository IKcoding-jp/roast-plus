import 'package:flutter/material.dart';
import '../../models/theme_settings.dart';

/// ホーム画面のヘッダー部分
class HomeHeader extends StatefulWidget {
  final ThemeSettings themeSettings;

  const HomeHeader({super.key, required this.themeSettings});

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 11) {
      return 'おはようございます！';
    } else if (hour >= 11 && hour < 18) {
      return 'こんにちは！';
    } else {
      return 'こんばんは！';
    }
  }

  String _getSecondMessage() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 7) {
      return '新しい一日の始まりです。';
    } else if (hour >= 7 && hour < 10) {
      return '今日も一緒にお仕事頑張りましょう！';
    } else if (hour >= 10 && hour < 12) {
      return '今日もお仕事、応援しています！';
    } else if (hour >= 12 && hour < 14) {
      return 'お昼休憩の時間ですね。美味しいご飯とコーヒーでリフレッシュしましょう🍽️☕️';
    } else if (hour >= 14 && hour < 17) {
      return 'もうひと踏ん張り！がんばりましょう！';
    } else if (hour >= 17 && hour < 19) {
      return '本日もお疲れ様でした。ゆっくり休憩しましょう。';
    } else if (hour >= 19 || hour < 0) {
      return '一日お疲れ様でした。ゆっくりお休みくださいね。';
    } else {
      return '夜遅くまでお疲れ様です。無理せず休んでくださいね。';
    }
  }

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
              color: widget.themeSettings.iconColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.coffee,
              color: widget.themeSettings.iconColor,
              size: 30,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreetingMessage(),
                  style: TextStyle(
                    fontSize: 24 * widget.themeSettings.fontSizeScale,
                    fontWeight: FontWeight.bold,
                    color: widget.themeSettings.fontColor1,
                    fontFamily: widget.themeSettings.fontFamily,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _getSecondMessage(),
                  style: TextStyle(
                    fontSize: 16 * widget.themeSettings.fontSizeScale,
                    color: widget.themeSettings.fontColor1.withValues(
                      alpha: 0.7,
                    ),
                    fontFamily: widget.themeSettings.fontFamily,
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
