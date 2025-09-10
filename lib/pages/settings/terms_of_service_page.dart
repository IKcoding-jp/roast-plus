import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../utils/web_ui_utils.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      backgroundColor: themeSettings.backgroundColor,
      appBar: AppBar(
        title: Text(
          '利用規約',
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
                      Icons.description,
                      color: themeSettings.settingsColor,
                      size: 28 * themeSettings.fontSizeScale,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '利用規約',
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
          '第1条（適用）',
          '本規約は、Roast Plus（以下「本アプリ」）の利用に関して適用されます。',
          Icons.gavel,
        ),
        _buildSectionCard(
          context,
          '第2条（利用登録）',
          '1. 本アプリの利用者は、Googleアカウントによる認証が必要です。\n'
              '2. 利用者は、真実かつ正確な情報を提供するものとします。\n'
              '3. 利用者は、自己の責任においてアカウント情報を管理するものとします。',
          Icons.person_add,
        ),
        _buildSectionCard(
          context,
          '第3条（禁止事項）',
          '利用者は、本アプリの利用にあたり、以下の行為をしてはなりません：\n'
              '1. 法令または公序良俗に違反する行為\n'
              '2. 犯罪行為に関連する行為\n'
              '3. 本アプリのサーバーまたはネットワークの機能を破壊する行為\n'
              '4. 他の利用者に迷惑をかける行為\n'
              '5. 本アプリに関連して、反社会的勢力に対して直接または間接に利益を供与する行為',
          Icons.block,
        ),
        _buildSectionCard(
          context,
          '第4条（本アプリの提供の停止等）',
          '1. 当社は、以下のいずれかの事由があると判断した場合、利用者に事前に通知することなく本アプリの全部または一部の提供を停止または中断することができるものとします：\n'
              '・本アプリにかかるコンピュータシステムの保守点検または更新を行う場合\n'
              '・地震、落雷、火災、停電または天災などの不可抗力により、本アプリの提供が困難となった場合\n'
              '・その他、当社が本アプリの提供が困難と判断した場合\n'
              '2. 当社は、本アプリの提供の停止または中断により利用者または第三者に生じた損害について、一切の責任を負いません。',
          Icons.pause_circle,
        ),
        _buildSectionCard(
          context,
          '第5条（利用制限および登録抹消）',
          '1. 当社は、利用者が以下のいずれかに該当する場合には、事前の通知なく、利用者に対して、本アプリの全部もしくは一部の利用を制限し、または利用者としての登録を抹消することができるものとします：\n'
              '・本規約のいずれかの条項に違反した場合\n'
              '・登録事項に虚偽の事実があることが判明した場合\n'
              '・その他、当社が本アプリの利用を適当でないと判断した場合\n'
              '2. 当社は、本条に基づき当社が行った行為により利用者に生じた損害について、一切の責任を負いません。',
          Icons.remove_circle,
        ),
        _buildSectionCard(
          context,
          '第6条（免責事項）',
          '1. 当社は、本アプリに関して、利用者と他の利用者または第三者との間において生じた取引、連絡または紛争等について一切責任を負いません。\n'
              '2. 当社は、本アプリの利用により生じた利用者の損害について、一切の責任を負いません。',
          Icons.security,
        ),
        _buildSectionCard(
          context,
          '第7条（サービス内容の変更等）',
          '当社は、利用者に通知することなく、本アプリの内容を変更しまたは本アプリの提供を中止することができるものとし、これによって利用者に生じた損害について一切の責任を負いません。',
          Icons.settings,
        ),
        _buildSectionCard(
          context,
          '第8条（利用規約の変更）',
          '当社は、必要と判断した場合には、利用者に通知することなくいつでも本規約を変更することができるものとします。なお、本規約変更後、本アプリの利用を継続した場合には、変更後の規約に同意したものとみなします。',
          Icons.edit,
        ),
        _buildSectionCard(
          context,
          '第9条（通知または連絡）',
          '利用者と当社との間の通知または連絡は、当社の定める方法によって行うものとします。当社は、利用者から、当社が定める方法に従った通知がない限り、利用者がいかなる通知または連絡を受領したものとみなしません。',
          Icons.notifications,
        ),
        _buildSectionCard(
          context,
          '第10条（権利義務の譲渡の禁止）',
          '利用者は、当社の書面による事前の承諾なく、利用契約上の地位または本規約に基づく権利もしくは義務を第三者に譲渡し、または担保に供することはできません。',
          Icons.transfer_within_a_station,
        ),
        _buildSectionCard(
          context,
          '第11条（準拠法・裁判管轄）',
          '1. 本規約の解釈にあたっては、日本法を準拠法とします。\n'
              '2. 本アプリに関して紛争が生じた場合には、東京地方裁判所を第一審の専属的合意管轄裁判所とします。',
          Icons.balance,
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
