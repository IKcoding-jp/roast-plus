import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/theme_settings.dart';
import '../pages/settings/theme_settings_page.dart';
import '../pages/settings/bean_sticker_settings_page.dart';
import 'feedback_page.dart';
import 'font_size_settings_page.dart';
import 'sound_settings_page.dart';
import 'account_info_page.dart';
import 'passcode_lock_settings_page.dart';
import 'creator_message_page.dart';
import 'upcoming_features_page.dart';
import 'donation_page.dart';

class AppSettingsPage extends StatelessWidget {
  const AppSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('アプリ設定')),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '設定',
                style: TextStyle(
                  fontSize:
                      16 * Provider.of<ThemeSettings>(context).fontSizeScale,
                  fontWeight: FontWeight.bold,
                  color: Provider.of<ThemeSettings>(context).fontColor1,
                ),
              ),
            ),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Provider.of<ThemeSettings>(context).backgroundColor2,
              child: ListTile(
                leading: Icon(
                  Icons.person_outline,
                  color: Provider.of<ThemeSettings>(context).settingsColor,
                ),
                title: Text(
                  'アカウント情報',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AccountInfoPage()),
                  );
                },
              ),
            ),
            // ▼ここから追加：パスコードロック設定
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Provider.of<ThemeSettings>(context).backgroundColor2,
              child: ListTile(
                leading: Icon(
                  Icons.lock_outline,
                  color: Provider.of<ThemeSettings>(context).settingsColor,
                ),
                title: Text(
                  'パスコードロック設定',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PasscodeLockSettingsPage(),
                    ),
                  );
                },
              ),
            ),
            // ▲ここまで追加
            // ▼ここから追加：寄付セクション
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Provider.of<ThemeSettings>(context).backgroundColor2,
              child: ListTile(
                leading: Icon(
                  Icons.volunteer_activism,
                  color: Provider.of<ThemeSettings>(context).settingsColor,
                ),
                title: Text(
                  '寄付で応援する',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                  ),
                ),
                subtitle: Text(
                  '300円から任意の金額で寄付できます。寄付者は広告非表示＆カスタマイズ解放',
                  style: TextStyle(
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DonationPage()),
                  );
                },
              ),
            ),
            // ▲ここまで追加
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Provider.of<ThemeSettings>(context).backgroundColor2,
              child: ListTile(
                leading: Icon(
                  Icons.color_lens_outlined,
                  color: Provider.of<ThemeSettings>(context).settingsColor,
                ),
                title: Text(
                  'テーマを変更する',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ThemeSettingsPage(),
                    ),
                  );
                },
              ),
            ),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Provider.of<ThemeSettings>(context).backgroundColor2,
              child: ListTile(
                leading: Icon(
                  Icons.text_fields,
                  color: Provider.of<ThemeSettings>(context).settingsColor,
                ),
                title: Text(
                  'フォント設定',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FontSizeSettingsPage(),
                    ),
                  );
                },
              ),
            ),
            // 豆のシール設定
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Provider.of<ThemeSettings>(context).backgroundColor2,
              child: ListTile(
                leading: Icon(
                  Icons.label,
                  color: Provider.of<ThemeSettings>(context).settingsColor,
                ),
                title: Text(
                  '豆のシール設定',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                  ),
                ),
                subtitle: Text(
                  '豆の種類ごとの色シール設定',
                  style: TextStyle(
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BeanStickerSettingsPage(),
                    ),
                  );
                },
              ),
            ),
            // サウンド設定
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Provider.of<ThemeSettings>(context).backgroundColor2,
              child: ListTile(
                leading: Icon(
                  Icons.volume_up,
                  color: Provider.of<ThemeSettings>(context).settingsColor,
                ),
                title: Text(
                  'サウンド設定',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                  ),
                ),
                subtitle: Text(
                  'タイマー音・通知音の設定',
                  style: TextStyle(
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SoundSettingsPage(),
                    ),
                  );
                },
              ),
            ),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Provider.of<ThemeSettings>(context).backgroundColor2,
              child: ListTile(
                leading: Icon(
                  Icons.feedback,
                  color: Provider.of<ThemeSettings>(context).settingsColor,
                ),
                title: Text(
                  'フィードバック',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FeedbackPage()),
                  );
                },
              ),
            ),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Provider.of<ThemeSettings>(context).backgroundColor2,
              child: ListTile(
                leading: Icon(
                  Icons.message,
                  color: Provider.of<ThemeSettings>(context).settingsColor,
                ),
                title: Text(
                  '制作者からのメッセージ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreatorMessagePage(),
                    ),
                  );
                },
              ),
            ),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Provider.of<ThemeSettings>(context).backgroundColor2,
              child: ListTile(
                leading: Icon(
                  Icons.update,
                  color: Provider.of<ThemeSettings>(context).settingsColor,
                ),
                title: Text(
                  '今後アップデートで追加予定の機能',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UpcomingFeaturesPage(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
