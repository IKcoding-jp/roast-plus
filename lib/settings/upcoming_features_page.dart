import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/theme_settings.dart';

class UpcomingFeaturesPage extends StatelessWidget {
  const UpcomingFeaturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('今後アップデートで追加予定の機能'),
        backgroundColor: Provider.of<ThemeSettings>(context).appBarColor,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color:
                    Provider.of<ThemeSettings>(context).backgroundColor2 ??
                    Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.update,
                              color: Colors.blue,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            '開発予定の機能',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).fontColor1,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      _buildFeatureItem(
                        context,
                        '⏱️ ハンドピックタイマー機能',
                        'ハンドピックをタイマーで管理してくれる機能',
                      ),
                      _buildFeatureItem(
                        context,
                        '📚 欠点豆データベース',
                        '豆の説明や、味にどう影響するかいつでも見れる',
                      ),
                      _buildFeatureItem(
                        context,
                        '💡 豆の端数提案機能',
                        '豆の端数をどう振り分けたらいいか提案してくれる機能',
                      ),
                      _buildFeatureItem(
                        context,
                        '📄 データエクスポート機能',
                        'CSV・PDF形式でデータを出力できる機能',
                      ),
                      _buildFeatureItem(
                        context,
                        '🎮 ゲーム要素の追加',
                        'アプリ内で楽しめるゲーム的な要素を導入',
                      ),
                      _buildFeatureItem(
                        context,
                        '👥 グループレベル機能',
                        'グループごとにレベルや成長要素を追加',
                      ),
                      _buildFeatureItem(
                        context,
                        '🎨 カラーテーマのプリセット追加',
                        '選べるカラーテーマのバリエーションを増やす',
                      ),
                      _buildFeatureItem(
                        context,
                        '💖 寄付システム',
                        'アプリ開発支援のための寄付機能',
                      ),
                      SizedBox(height: 24),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lightbulb, color: Colors.blue, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'ご要望があれば、フィードバックからお聞かせください！',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    String title,
    String description,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                    height: 1.4,
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
