import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../utils/web_ui_utils.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      backgroundColor: themeSettings.backgroundColor,
      appBar: AppBar(
        title: Text(
          'プライバシーポリシー',
          style: TextStyle(
            color: themeSettings.appBarTextColor,
            fontSize: 18 * themeSettings.fontSizeScale,
          ),
        ),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
      ),
      body: SafeArea(
        child: WebUIUtils.isWeb
            ? _buildWebLayout(context)
            : _buildMobileLayout(context),
      ),
    );
  }

  Widget _buildWebLayout(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Container(
          color: themeSettings.backgroundColor,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Container(
      color: themeSettings.backgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ヘッダーカード
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: themeSettings.cardBackgroundColor,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.privacy_tip,
                      color: themeSettings.settingsColor,
                      size: 28 * themeSettings.fontSizeScale,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'プライバシーポリシー',
                        style: TextStyle(
                          fontSize: 24 * themeSettings.fontSizeScale,
                          fontWeight: FontWeight.bold,
                          color: themeSettings.fontColor1,
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '最終更新日: 2024年12月',
                  style: TextStyle(
                    fontSize: 14 * themeSettings.fontSizeScale,
                    color: themeSettings.fontColor2,
                    fontFamily: themeSettings.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 各セクションをカードで囲む
        _buildSectionCard(
          context,
          '1. 個人情報の収集について',
          'Roast Plus（以下「本アプリ」）では、以下の個人情報を収集いたします：\n\n'
              '• Googleアカウント情報（メールアドレス、表示名、プロフィール画像）\n'
              '• アプリ内で作成されたデータ（焙煎記録、グループ情報、設定情報等）\n'
              '• デバイス情報（デバイスID、OS情報等）\n'
              '• 利用統計情報（アプリの使用状況、エラーログ等）',
          Icons.data_usage,
        ),
        _buildSectionCard(
          context,
          '2. 個人情報の利用目的',
          '収集した個人情報は、以下の目的で利用いたします：\n\n'
              '• 本アプリの提供・運営\n'
              '• ユーザー認証・アカウント管理\n'
              '• サービス改善・新機能開発\n'
              '• お客様サポート\n'
              '• セキュリティ確保\n'
              '• 法令遵守',
          Icons.info,
        ),
        _buildSectionCard(
          context,
          '3. 個人情報の管理',
          '当社は、お客様の個人情報を正確かつ最新の状態に保ち、個人情報への不正アクセス、紛失、漏洩、改ざんおよび破壊などを防止するため、セキュリティシステムの維持・管理体制の整備・社員教育の徹底等の必要な措置を講じ、安全対策を実施し個人情報の厳重な管理を行ないます。',
          Icons.admin_panel_settings,
        ),
        _buildSectionCard(
          context,
          '4. 個人情報の第三者への開示・提供の禁止',
          '当社は、お客様よりお預かりした個人情報を適切に管理し、以下のいずれかに該当する場合を除き、個人情報を第三者に開示いたしません：\n\n'
              '• お客様の同意がある場合\n'
              '• お客様が希望されるサービスを行なうために当社が業務を委託する業者に対して開示する場合\n'
              '• 法令に基づき開示することが必要である場合',
          Icons.block,
        ),
        _buildSectionCard(
          context,
          '5. 個人情報の安全対策',
          '当社は、個人情報の正確性及び安全性確保のために、セキュリティに万全の対策を講じています。\n\n'
              '• データの暗号化\n'
              '• セキュアな通信（HTTPS）\n'
              '• アクセス制御\n'
              '• 定期的なセキュリティ監査',
          Icons.security,
        ),
        _buildSectionCard(
          context,
          '6. ご本人の照会',
          'お客様がご本人の個人情報の照会・修正・削除などをご希望される場合には、ご本人であることを確認の上、対応させていただきます。',
          Icons.person_search,
        ),
        _buildSectionCard(
          context,
          '7. 法令、規範の遵守と見直し',
          '当社は、保有する個人情報に関して適用される日本の法令、その他規範を遵守するとともに、本ポリシーの内容を適宜見直し、その改善に努めます。',
          Icons.rule,
        ),
        _buildSectionCard(
          context,
          '8. お問い合わせ',
          '本ポリシーに関するお問い合わせは、下記までご連絡ください。\n\n'
              '• アプリ内の「フィードバック」機能をご利用ください\n'
              '• または、開発者まで直接ご連絡ください',
          Icons.contact_support,
        ),
        _buildSectionCard(
          context,
          '9. データの保存期間',
          '当社は、以下の期間にわたって個人情報を保存いたします：\n\n'
              '• アカウント情報：アカウント削除まで\n'
              '• アプリ内データ：アカウント削除まで\n'
              '• 利用統計情報：最大2年間\n'
              '• セキュリティログ：最大1年間',
          Icons.schedule,
        ),
        _buildSectionCard(
          context,
          '10. 国際的なデータ転送',
          '本アプリは、Google Firebaseサービスを利用しており、データは日本国外のサーバーに保存される場合があります。当社は、適切なデータ保護措置を講じて、お客様の個人情報を保護いたします。',
          Icons.public,
        ),

        // フッターカード
        const SizedBox(height: 16),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: themeSettings.cardBackgroundColor,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: themeSettings.settingsColor,
                  size: 24 * themeSettings.fontSizeScale,
                ),
                const SizedBox(width: 12),
                Text(
                  '以上',
                  style: TextStyle(
                    fontSize: 18 * themeSettings.fontSizeScale,
                    fontWeight: FontWeight.bold,
                    color: themeSettings.fontColor1,
                    fontFamily: themeSettings.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionCard(
    BuildContext context,
    String title,
    String content,
    IconData icon,
  ) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: themeSettings.cardBackgroundColor,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: themeSettings.settingsColor,
                  size: 24 * themeSettings.fontSizeScale,
                ),
                const SizedBox(width: 12),
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
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: themeSettings.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: themeSettings.borderColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                content,
                style: TextStyle(
                  fontSize: 16 * themeSettings.fontSizeScale,
                  color: themeSettings.fontColor1,
                  fontFamily: themeSettings.fontFamily,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
