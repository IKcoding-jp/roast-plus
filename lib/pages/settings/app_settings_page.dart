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
      // アカウント・セキュリティセクション
      _buildSectionHeader(context, 'アカウント・セキュリティ'),
      _buildSettingsCard(
        context,
        icon: Icons.person_outline,
        title: 'アカウント情報',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccountInfoPage()),
          );
        },
      ),
      _buildSettingsCard(
        context,
        icon: Icons.lock_outline,
        title: 'パスコードロック設定',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PasscodeLockSettingsPage()),
          );
        },
      ),

      // カスタマイズセクション
      _buildSectionHeader(context, 'カスタマイズ'),
      _buildSettingsCard(
        context,
        icon: Icons.color_lens_outlined,
        title: 'テーマを変更する',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ThemeSettingsPage()),
          );
        },
      ),
      _buildSettingsCard(
        context,
        icon: Icons.text_fields,
        title: 'フォント設定',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FontSizeSettingsPage()),
          );
        },
      ),
      _buildSettingsCard(
        context,
        icon: Icons.volume_up,
        title: 'サウンド設定',
        subtitle: 'タイマー音・通知音の設定',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SoundSettingsPage()),
          );
        },
      ),
      _buildSettingsCard(
        context,
        icon: Icons.label,
        title: '豆のシール設定',
        subtitle: '豆の種類ごとの色シール設定',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BeanStickerSettingsPage()),
          );
        },
      ),
      const SizedBox(height: 24),

      // サポート・情報セクション
      _buildSectionHeader(context, 'サポート・情報'),
      _buildSettingsCard(
        context,
        icon: Icons.volunteer_activism,
        title: '寄付で応援する',
        subtitle: '300円から任意の金額で寄付できます。寄付者は広告非表示＆カスタマイズ解放',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DonationPage()),
          );
        },
      ),
      _buildSettingsCard(
        context,
        icon: Icons.feedback,
        title: 'フィードバック',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FeedbackPage()),
          );
        },
      ),
      _buildSettingsCard(
        context,
        icon: Icons.message,
        title: '制作者からのメッセージ',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreatorMessagePage()),
          );
        },
      ),
      _buildSettingsCard(
        context,
        icon: Icons.update,
        title: '今後アップデートで追加予定の機能',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UpcomingFeaturesPage()),
          );
        },
      ),
      const SizedBox(height: 24),

      // 法的情報セクション
      _buildSectionHeader(context, '法的情報'),
      _buildSettingsCard(
        context,
        icon: Icons.description,
        title: '利用規約',
        subtitle: 'アプリの利用に関する規約',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TermsOfServicePage()),
          );
        },
      ),
      _buildSettingsCard(
        context,
        icon: Icons.privacy_tip,
        title: 'プライバシーポリシー',
        subtitle: '個人情報の取り扱いについて',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
          );
        },
      ),
      const SizedBox(height: 32),
    ];
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16 * Provider.of<ThemeSettings>(context).fontSizeScale,
          fontWeight: FontWeight.bold,
          color: Provider.of<ThemeSettings>(context).fontColor1,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Provider.of<ThemeSettings>(context).cardBackgroundColor,
      child: ListTile(
        leading: Icon(
          icon,
          color: Provider.of<ThemeSettings>(context).settingsColor,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Provider.of<ThemeSettings>(context).fontColor1,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  color: Provider.of<ThemeSettings>(context).fontColor1,
                ),
              )
            : null,
        trailing: Icon(
          Icons.chevron_right,
          color: Provider.of<ThemeSettings>(context).iconColor,
        ),
        onTap: onTap,
      ),
    );
  }
}
