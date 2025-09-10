import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import 'group_create_page.dart';
import 'group_invitations_page.dart';

class GroupDeleteCompletePage extends StatelessWidget {
  const GroupDeleteCompletePage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      backgroundColor: themeSettings.backgroundColor,
      appBar: AppBar(
        title: Text('グループ削除完了'),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
        automaticallyImplyLeading: false, // 戻るボタンを無効化
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // アイコン
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(Icons.group_remove, size: 60, color: Colors.red),
              ),

              const SizedBox(height: 32),

              // タイトル
              Text(
                'グループを削除しました',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: themeSettings.fontColor1,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // 説明文
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: themeSettings.cardBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: themeSettings.iconColor.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 32,
                      color: themeSettings.iconColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ローストプラスを利用するには、\nグループの参加が必須です',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: themeSettings.fontColor1,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'グループ機能により、メンバー間でデータを共有し、\n協力してコーヒー業務を進めることができます。',
                      style: TextStyle(
                        fontSize: 14,
                        color: themeSettings.fontColor1.withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // アクションボタン
              Column(
                children: [
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
                      icon: Icon(Icons.add_circle_outline),
                      label: Text(
                        '新しいグループを作成',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeSettings.buttonColor,
                        foregroundColor: themeSettings.fontColor2,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

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
                      icon: Icon(Icons.mail_outline),
                      label: Text(
                        '招待を受ける',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: themeSettings.iconColor,
                        side: BorderSide(
                          color: themeSettings.iconColor.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // 補足情報
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: themeSettings.memberBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: themeSettings.iconColor.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 20,
                          color: themeSettings.iconColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'グループ機能について',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: themeSettings.fontColor1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• 焙煎記録の共有\n• スケジュールの同期\n• メンバー間の協力\n• ゲーミフィケーション',
                      style: TextStyle(
                        fontSize: 12,
                        color: themeSettings.fontColor1.withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
