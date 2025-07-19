import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import 'group_create_page.dart';
import 'group_invitations_page.dart';

class GroupRequiredPage extends StatelessWidget {
  const GroupRequiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      backgroundColor: themeSettings.backgroundColor,
      appBar: AppBar(
        title: Text('グループ参加が必要です'),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
        automaticallyImplyLeading: false, // 戻るボタンを無効化
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // アイコン
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: themeSettings.iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: themeSettings.iconColor.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.group_work,
                  size: 35,
                  color: themeSettings.iconColor,
                ),
              ),

              const SizedBox(height: 16),

              // タイトル
              Text(
                'グループ参加が必要です',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: themeSettings.fontColor1,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // 説明文
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: themeSettings.backgroundColor2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: themeSettings.iconColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 24,
                      color: themeSettings.iconColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ローストプラスを利用するには、\nグループの参加が必須です',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: themeSettings.fontColor1,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // アクションボタン
              // 新しいグループを作成
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GroupCreatePage(),
                      ),
                    );
                  },
                  icon: Icon(Icons.add_circle_outline, size: 22),
                  label: Text(
                    '新しいグループを作成',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeSettings.buttonColor,
                    foregroundColor: themeSettings.fontColor2,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 招待を受ける
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GroupInvitationsPage(),
                      ),
                    );
                  },
                  icon: Icon(Icons.mail_outline, size: 22),
                  label: Text(
                    '招待を受ける',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: themeSettings.iconColor,
                    side: BorderSide(
                      color: themeSettings.iconColor.withOpacity(0.5),
                      width: 2,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // グループ機能の簡潔な説明
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: themeSettings.memberBackgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: themeSettings.iconColor.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 18,
                          color: themeSettings.iconColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'グループ機能',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: themeSettings.fontColor1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildCompactFeatureItem('焙煎記録の共有', themeSettings),
                    _buildCompactFeatureItem('スケジュールの同期', themeSettings),
                    _buildCompactFeatureItem('メンバー間の協力', themeSettings),
                    _buildCompactFeatureItem('ゲーミフィケーション', themeSettings),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 補足情報
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tips_and_updates, size: 16, color: Colors.blue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'グループに参加すると、ローストプラスの全機能を利用できます',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactFeatureItem(String title, ThemeSettings themeSettings) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: themeSettings.iconColor,
              shape: BoxShape.circle,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: themeSettings.fontColor1.withOpacity(0.8),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    String title,
    String description,
    ThemeSettings themeSettings,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: 8),
            decoration: BoxDecoration(
              color: themeSettings.iconColor,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: themeSettings.fontColor1,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: themeSettings.fontColor1.withOpacity(0.7),
                    height: 1.3,
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
