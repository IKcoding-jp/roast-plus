import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../utils/web_ui_utils.dart';
import 'theme_settings_page.dart';
import 'bean_sticker_settings_page.dart';
import 'feedback_page.dart';
import 'font_size_settings_page.dart';
import 'sound_settings_page.dart';
import 'account_info_page.dart';
import 'passcode_lock_settings_page.dart';
import 'biometric_settings_page.dart';
// セキュリティ設定は一般ユーザーには不要なため削除
// import 'encrypted_storage_settings_page.dart';
// import 'network_security_settings_page.dart';
// import 'firebase_security_settings_page.dart';
import 'creator_message_page.dart';
import 'upcoming_features_page.dart';
import 'donation_page.dart';
import 'terms_of_service_page.dart';
import 'privacy_policy_page.dart';

class AppSettingsPage extends StatelessWidget {
  const AppSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('アプリ設定')),
      body: SafeArea(
        child: WebUIUtils.isWeb
            ? _buildWebLayout(context)
            : _buildMobileLayout(context),
      ),
    );
  }

  Widget _buildWebLayout(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 600),
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: ListView(
            padding: EdgeInsets.all(16),
            children: _buildSettingsItems(context),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView(
        padding: EdgeInsets.all(16),
        children: _buildSettingsItems(context),
      ),
    );
  }

  List<Widget> _buildSettingsItems(BuildContext context) {
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          '設定',
          style: TextStyle(
            fontSize: 16 * Provider.of<ThemeSettings>(context).fontSizeScale,
            fontWeight: FontWeight.bold,
            color: Provider.of<ThemeSettings>(context).fontColor1,
          ),
        ),
      ),
      Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Provider.of<ThemeSettings>(context).cardBackgroundColor,
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
      // パスコードロック設定
      Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Provider.of<ThemeSettings>(context).cardBackgroundColor,
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
      // 生体認証設定
      Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Provider.of<ThemeSettings>(context).cardBackgroundColor,
        child: ListTile(
          leading: Icon(
            Icons.fingerprint,
            color: Provider.of<ThemeSettings>(context).settingsColor,
          ),
          title: Text(
            '生体認証設定',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Provider.of<ThemeSettings>(context).fontColor1,
            ),
          ),
          subtitle: Text(
            '指紋・顔認証でアプリにアクセス',
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
              MaterialPageRoute(builder: (_) => const BiometricSettingsPage()),
            );
          },
        ),
      ),
      // 暗号化ストレージ設定は一般ユーザーには不要なため削除
      // ネットワークセキュリティ設定は一般ユーザーには不要なため削除
      // Firebaseセキュリティ設定は一般ユーザーには不要なため削除
      // 寄付セクション
      Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Provider.of<ThemeSettings>(context).cardBackgroundColor,
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
      Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Provider.of<ThemeSettings>(context).cardBackgroundColor,
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
              MaterialPageRoute(builder: (_) => const ThemeSettingsPage()),
            );
          },
        ),
      ),
      Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Provider.of<ThemeSettings>(context).cardBackgroundColor,
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
              MaterialPageRoute(builder: (_) => const FontSizeSettingsPage()),
            );
          },
        ),
      ),
      // 豆のシール設定
      Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Provider.of<ThemeSettings>(context).cardBackgroundColor,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Provider.of<ThemeSettings>(context).cardBackgroundColor,
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
              MaterialPageRoute(builder: (_) => const SoundSettingsPage()),
            );
          },
        ),
      ),
      Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Provider.of<ThemeSettings>(context).cardBackgroundColor,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Provider.of<ThemeSettings>(context).cardBackgroundColor,
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
              MaterialPageRoute(builder: (_) => const CreatorMessagePage()),
            );
          },
        ),
      ),
      Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Provider.of<ThemeSettings>(context).cardBackgroundColor,
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
              MaterialPageRoute(builder: (_) => const UpcomingFeaturesPage()),
            );
          },
        ),
      ),
      const SizedBox(height: 16),
      // 法的情報セクション
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          '法的情報',
          style: TextStyle(
            fontSize: 16 * Provider.of<ThemeSettings>(context).fontSizeScale,
            fontWeight: FontWeight.bold,
            color: Provider.of<ThemeSettings>(context).fontColor1,
          ),
        ),
      ),
      Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Provider.of<ThemeSettings>(context).cardBackgroundColor,
        child: ListTile(
          leading: Icon(
            Icons.description,
            color: Provider.of<ThemeSettings>(context).settingsColor,
          ),
          title: Text(
            '利用規約',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Provider.of<ThemeSettings>(context).fontColor1,
            ),
          ),
          subtitle: Text(
            'アプリの利用に関する規約',
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
              MaterialPageRoute(builder: (_) => const TermsOfServicePage()),
            );
          },
        ),
      ),
      Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Provider.of<ThemeSettings>(context).cardBackgroundColor,
        child: ListTile(
          leading: Icon(
            Icons.privacy_tip,
            color: Provider.of<ThemeSettings>(context).settingsColor,
          ),
          title: Text(
            'プライバシーポリシー',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Provider.of<ThemeSettings>(context).fontColor1,
            ),
          ),
          subtitle: Text(
            '個人情報の取り扱いについて',
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
              MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
            );
          },
        ),
      ),
      const SizedBox(height: 32),
    ];
  }
}
