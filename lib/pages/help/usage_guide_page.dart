import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../utils/web_ui_utils.dart';

class UsageGuidePage extends StatefulWidget {
  const UsageGuidePage({super.key});

  @override
  State<UsageGuidePage> createState() => _UsageGuidePageState();
}

class _DetailPage extends StatelessWidget {
  final String title;
  final List<String> content;
  final ThemeSettings themeSettings;

  const _DetailPage({
    required this.title,
    required this.content,
    required this.themeSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
      ),
      body: Container(
        color: themeSettings.backgroundColor,
        child: WebUIUtils.isWeb
            ? Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 800),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(24),
                    child: Card(
                      elevation: 4,
                      color: themeSettings.cardBackgroundColor,
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: content.map((item) {
                            if (item.isEmpty) {
                              return SizedBox(height: 16);
                            } else if (item.startsWith('【') &&
                                item.endsWith('】')) {
                              return Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Text(
                                  item,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              );
                            } else {
                              return Padding(
                                padding: EdgeInsets.only(bottom: 6),
                                child: Text(
                                  item,
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.black87,
                                  ),
                                ),
                              );
                            }
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Card(
                  elevation: 4,
                  color: themeSettings.cardBackgroundColor,
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: content.map((item) {
                        if (item.isEmpty) {
                          return SizedBox(height: 16);
                        } else if (item.startsWith('【') && item.endsWith('】')) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              item,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          );
                        } else {
                          return Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Text(
                              item,
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.black87,
                              ),
                            ),
                          );
                        }
                      }).toList(),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _UsageGuidePageState extends State<UsageGuidePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('使い方ガイド'),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
        bottom: WebUIUtils.isWeb
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: themeSettings.buttonColor,
                labelColor: themeSettings.appBarTextColor,
                unselectedLabelColor: themeSettings.appBarTextColor.withValues(
                  alpha: 0.7,
                ),
                tabs: [
                  Tab(text: '基本'),
                  Tab(text: '焙煎'),
                  Tab(text: '管理'),
                  Tab(text: 'グループ'),
                  Tab(text: 'ゲーム'),
                  Tab(text: '設定'),
                ],
              ),
      ),
      body: WebUIUtils.isWeb
          ? _buildWebLayout(themeSettings)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBasicTab(themeSettings),
                _buildRoastingTab(themeSettings),
                _buildManagementTab(themeSettings),
                _buildGroupTab(themeSettings),
                _buildGamificationTab(themeSettings),
                _buildSettingsTab(themeSettings),
              ],
            ),
    );
  }

  Widget _buildWebLayout(ThemeSettings themeSettings) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 1400),
        child: Container(
          color: themeSettings.backgroundColor,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左側のカテゴリナビゲーション
              Container(
                width: 250,
                decoration: BoxDecoration(
                  color: themeSettings.cardBackgroundColor,
                  border: Border(
                    right: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    // カテゴリヘッダー
                    Container(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'カテゴリ',
                        style: TextStyle(
                          fontSize: 18 * themeSettings.fontSizeScale,
                          fontWeight: FontWeight.bold,
                          color: themeSettings.fontColor1,
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                    ),
                    // カテゴリリスト
                    Expanded(
                      child: ListView(
                        children: [
                          _buildWebCategoryItem(
                            themeSettings,
                            '基本',
                            Icons.play_arrow,
                            0,
                          ),
                          _buildWebCategoryItem(
                            themeSettings,
                            '焙煎',
                            Icons.timer,
                            1,
                          ),
                          _buildWebCategoryItem(
                            themeSettings,
                            '管理',
                            Icons.schedule,
                            2,
                          ),
                          _buildWebCategoryItem(
                            themeSettings,
                            'グループ',
                            Icons.group,
                            3,
                          ),
                          _buildWebCategoryItem(
                            themeSettings,
                            'ゲーム',
                            Icons.emoji_events,
                            4,
                          ),
                          _buildWebCategoryItem(
                            themeSettings,
                            '設定',
                            Icons.settings,
                            5,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 右側のコンテンツエリア
              Expanded(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 120,
                  child: IndexedStack(
                    index: _tabController.index,
                    children: [
                      _buildBasicTab(themeSettings),
                      _buildRoastingTab(themeSettings),
                      _buildManagementTab(themeSettings),
                      _buildGroupTab(themeSettings),
                      _buildGamificationTab(themeSettings),
                      _buildSettingsTab(themeSettings),
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

  Widget _buildWebCategoryItem(
    ThemeSettings themeSettings,
    String title,
    IconData icon,
    int index,
  ) {
    final isSelected = _tabController.index == index;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Card(
        elevation: isSelected ? 4 : 1,
        color: isSelected
            ? themeSettings.buttonColor
            : themeSettings.cardBackgroundColor,
        child: ListTile(
          leading: Icon(
            icon,
            color: isSelected
                ? themeSettings.fontColor2
                : themeSettings.iconColor,
            size: 24,
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16 * themeSettings.fontSizeScale,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? themeSettings.fontColor2
                  : themeSettings.fontColor1,
              fontFamily: themeSettings.fontFamily,
            ),
          ),
          onTap: () {
            setState(() {
              _tabController.animateTo(index);
            });
          },
        ),
      ),
    );
  }

  Widget _buildBasicTab(ThemeSettings themeSettings) {
    return Container(
      color: themeSettings.backgroundColor,
      child: WebUIUtils.isWeb
          ? _buildWebTabContent(
              themeSettings,
              [
                _buildListItem(
                  themeSettings,
                  'アプリの起動と基本操作',
                  'アプリの基本的な使い方を説明',
                  Icons.play_arrow,
                  () => _showBasicOperationDetail(context, themeSettings),
                ),
                _buildListItem(
                  themeSettings,
                  'ドロワーメニューの使い方',
                  'メニューの開き方と項目の説明',
                  Icons.menu,
                  () => _showDrawerMenuDetail(context, themeSettings),
                ),
                _buildListItem(
                  themeSettings,
                  'データの保存と同期',
                  'データの自動保存とクラウド同期',
                  Icons.sync,
                  () => _showDataSyncDetail(context, themeSettings),
                ),
              ],
              '基本',
              'アプリの基本的な使い方について説明します',
            )
          : ListView(
              padding: EdgeInsets.all(16),
              children: [
                _buildListItem(
                  themeSettings,
                  'アプリの起動と基本操作',
                  'アプリの基本的な使い方を説明',
                  Icons.play_arrow,
                  () => _showBasicOperationDetail(context, themeSettings),
                ),
                SizedBox(height: 12),
                _buildListItem(
                  themeSettings,
                  'ドロワーメニューの使い方',
                  'メニューの開き方と項目の説明',
                  Icons.menu,
                  () => _showDrawerMenuDetail(context, themeSettings),
                ),
                SizedBox(height: 12),
                _buildListItem(
                  themeSettings,
                  'データの保存と同期',
                  'データの自動保存とクラウド同期',
                  Icons.sync,
                  () => _showDataSyncDetail(context, themeSettings),
                ),
              ],
            ),
    );
  }

  Widget _buildWebTabContent(
    ThemeSettings themeSettings,
    List<Widget> items, [
    String title = '基本',
    String description = 'アプリの基本的な使い方について説明します',
  ]) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タブタイトル
          Text(
            title,
            style: TextStyle(
              fontSize: 24 * themeSettings.fontSizeScale,
              fontWeight: FontWeight.bold,
              color: themeSettings.fontColor1,
              fontFamily: themeSettings.fontFamily,
            ),
          ),
          SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 16 * themeSettings.fontSizeScale,
              color: themeSettings.fontColor2,
              fontFamily: themeSettings.fontFamily,
            ),
          ),
          SizedBox(height: 24),
          // アイテムグリッド
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: items
                .map((item) => SizedBox(width: 350, child: item))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRoastingTab(ThemeSettings themeSettings) {
    return Container(
      color: themeSettings.backgroundColor,
      child: WebUIUtils.isWeb
          ? _buildWebTabContent(
              themeSettings,
              [
                _buildListItem(
                  themeSettings,
                  '焙煎タイマーって何？',
                  '焙煎作業の時間管理をサポート',
                  Icons.timer,
                  () => _showRoastingTimerDetail(context, themeSettings),
                ),
                _buildListItem(
                  themeSettings,
                  '焙煎記録の作成',
                  '焙煎作業の詳細を記録',
                  Icons.note_add,
                  () => _showRoastingRecordDetail(context, themeSettings),
                ),
              ],
              '焙煎',
              '焙煎作業に関する機能の使い方を説明します',
            )
          : ListView(
              padding: EdgeInsets.all(16),
              children: [
                _buildListItem(
                  themeSettings,
                  '焙煎タイマーって何？',
                  '焙煎作業の時間管理をサポート',
                  Icons.timer,
                  () => _showRoastingTimerDetail(context, themeSettings),
                ),
                SizedBox(height: 12),
                _buildListItem(
                  themeSettings,
                  '焙煎記録の作成',
                  '焙煎作業の詳細を記録',
                  Icons.note_add,
                  () => _showRoastingRecordDetail(context, themeSettings),
                ),
              ],
            ),
    );
  }

  Widget _buildManagementTab(ThemeSettings themeSettings) {
    return Container(
      color: themeSettings.backgroundColor,
      child: WebUIUtils.isWeb
          ? _buildWebTabContent(
              themeSettings,
              [
                _buildListItem(
                  themeSettings,
                  'スケジュールの作成',
                  '作業スケジュールの管理と自動作成',
                  Icons.schedule,
                  () => _showScheduleDetail(context, themeSettings),
                ),
                _buildListItem(
                  themeSettings,
                  'TODOリストの使い方',
                  'タスク管理と通知機能',
                  Icons.checklist,
                  () => _showTodoDetail(context, themeSettings),
                ),
                _buildListItem(
                  themeSettings,
                  'ドリップカウンターの使い方',
                  'ドリップパックのカウントと記録',
                  Icons.filter_list,
                  () => _showDripCounterDetail(context, themeSettings),
                ),
                _buildListItem(
                  themeSettings,
                  'テイスティング記録の作成',
                  'コーヒーの試飲評価と記録',
                  Icons.local_cafe,
                  () => _showTastingDetail(context, themeSettings),
                ),
                _buildListItem(
                  themeSettings,
                  '作業状況記録の使い方',
                  '作業の進捗管理と記録',
                  Icons.work,
                  () => _showWorkProgressDetail(context, themeSettings),
                ),
                _buildListItem(
                  themeSettings,
                  'カレンダー機能の使い方',
                  '日付別のデータ表示と管理',
                  Icons.calendar_today,
                  () => _showCalendarDetail(context, themeSettings),
                ),
              ],
              '管理',
              'スケジュール、TODO、記録などの管理機能について説明します',
            )
          : ListView(
              padding: EdgeInsets.all(16),
              children: [
                _buildListItem(
                  themeSettings,
                  'スケジュールの作成',
                  '作業スケジュールの管理と自動作成',
                  Icons.schedule,
                  () => _showScheduleDetail(context, themeSettings),
                ),
                SizedBox(height: 12),
                _buildListItem(
                  themeSettings,
                  'TODOリストの使い方',
                  'タスク管理と通知機能',
                  Icons.checklist,
                  () => _showTodoDetail(context, themeSettings),
                ),
                SizedBox(height: 12),
                _buildListItem(
                  themeSettings,
                  'ドリップカウンターの使い方',
                  'ドリップパックのカウントと記録',
                  Icons.filter_list,
                  () => _showDripCounterDetail(context, themeSettings),
                ),
                SizedBox(height: 12),
                _buildListItem(
                  themeSettings,
                  'テイスティング記録の作成',
                  'コーヒーの試飲評価と記録',
                  Icons.local_cafe,
                  () => _showTastingDetail(context, themeSettings),
                ),
                SizedBox(height: 12),
                _buildListItem(
                  themeSettings,
                  '作業状況記録の使い方',
                  '作業の進捗管理と記録',
                  Icons.work,
                  () => _showWorkProgressDetail(context, themeSettings),
                ),
                SizedBox(height: 12),
                _buildListItem(
                  themeSettings,
                  'カレンダー機能の使い方',
                  '日付別のデータ表示と管理',
                  Icons.calendar_today,
                  () => _showCalendarDetail(context, themeSettings),
                ),
              ],
            ),
    );
  }

  Widget _buildGroupTab(ThemeSettings themeSettings) {
    return Container(
      color: themeSettings.backgroundColor,
      child: WebUIUtils.isWeb
          ? _buildWebTabContent(
              themeSettings,
              [
                _buildListItem(
                  themeSettings,
                  'グループの作成',
                  '新しいグループを作成する方法',
                  Icons.group_add,
                  () => _showGroupCreateDetail(context, themeSettings),
                ),
                _buildListItem(
                  themeSettings,
                  'メンバーの招待',
                  'グループにメンバーを招待する方法',
                  Icons.person_add,
                  () => _showMemberInviteDetail(context, themeSettings),
                ),
                _buildListItem(
                  themeSettings,
                  'グループ内での共有',
                  'データをグループ内で共有する方法',
                  Icons.share,
                  () => _showGroupShareDetail(context, themeSettings),
                ),
                _buildListItem(
                  themeSettings,
                  '出勤退勤機能の使い方',
                  'メンバーの出勤退勤状態を管理',
                  Icons.access_time,
                  () => _showAttendanceDetail(context, themeSettings),
                ),
                _buildListItem(
                  themeSettings,
                  '担当表の使い方',
                  'チームの担当を自動で決める機能',
                  Icons.assignment,
                  () => _showAssignmentDetail(context, themeSettings),
                ),
              ],
              'グループ',
              'チームでの協力作業とデータ共有について説明します',
            )
          : ListView(
              padding: EdgeInsets.all(16),
              children: [
                _buildListItem(
                  themeSettings,
                  'グループの作成',
                  '新しいグループを作成する方法',
                  Icons.group_add,
                  () => _showGroupCreateDetail(context, themeSettings),
                ),
                SizedBox(height: 12),
                _buildListItem(
                  themeSettings,
                  'メンバーの招待',
                  'グループにメンバーを招待する方法',
                  Icons.person_add,
                  () => _showMemberInviteDetail(context, themeSettings),
                ),
                SizedBox(height: 12),
                _buildListItem(
                  themeSettings,
                  'グループ内での共有',
                  'データをグループ内で共有する方法',
                  Icons.share,
                  () => _showGroupShareDetail(context, themeSettings),
                ),
                SizedBox(height: 12),
                _buildListItem(
                  themeSettings,
                  '出勤退勤機能の使い方',
                  'メンバーの出勤退勤状態を管理',
                  Icons.access_time,
                  () => _showAttendanceDetail(context, themeSettings),
                ),
                SizedBox(height: 12),
                _buildListItem(
                  themeSettings,
                  '担当表の使い方',
                  'チームの担当を自動で決める機能',
                  Icons.assignment,
                  () => _showAssignmentDetail(context, themeSettings),
                ),
              ],
            ),
    );
  }

  Widget _buildGamificationTab(ThemeSettings themeSettings) {
    return Container(
      color: themeSettings.backgroundColor,
      child: WebUIUtils.isWeb
          ? _buildWebTabContent(
              themeSettings,
              [
                _buildListItem(
                  themeSettings,
                  'バッジシステムとは',
                  'バッジの獲得条件と種類について',
                  Icons.emoji_events,
                  () => _showBadgeSystemDetail(context, themeSettings),
                ),
                _buildListItem(
                  themeSettings,
                  'レベルアップシステム',
                  '経験値とレベルアップの仕組み',
                  Icons.trending_up,
                  () => _showLevelSystemDetail(context, themeSettings),
                ),
              ],
              'ゲーミフィケーション',
              'バッジシステムとレベルアップ機能について説明します',
            )
          : ListView(
              padding: EdgeInsets.all(16),
              children: [
                _buildListItem(
                  themeSettings,
                  'バッジシステムとは',
                  'バッジの獲得条件と種類について',
                  Icons.emoji_events,
                  () => _showBadgeSystemDetail(context, themeSettings),
                ),
                SizedBox(height: 12),
                _buildListItem(
                  themeSettings,
                  'レベルアップシステム',
                  '経験値とレベルアップの仕組み',
                  Icons.trending_up,
                  () => _showLevelSystemDetail(context, themeSettings),
                ),
              ],
            ),
    );
  }

  Widget _buildSettingsTab(ThemeSettings themeSettings) {
    return Container(
      color: themeSettings.backgroundColor,
      child: WebUIUtils.isWeb
          ? _buildWebTabContent(
              themeSettings,
              [
                _buildListItem(
                  themeSettings,
                  'テーマ設定の変更',
                  'アプリの見た目をカスタマイズ',
                  Icons.palette,
                  () => _showThemeSettingsDetail(context, themeSettings),
                ),
                _buildListItem(
                  themeSettings,
                  '音声通知の設定',
                  'アラーム音と音量の調整',
                  Icons.volume_up,
                  () => _showSoundSettingsDetail(context, themeSettings),
                ),
                _buildListItem(
                  themeSettings,
                  '通知設定の調整',
                  'アラームと通知の設定',
                  Icons.notifications,
                  () => _showNotificationSettingsDetail(context, themeSettings),
                ),
                _buildListItem(
                  themeSettings,
                  'セキュリティ設定',
                  'パスコードロックと生体認証',
                  Icons.security,
                  () => _showSecuritySettingsDetail(context, themeSettings),
                ),
                _buildListItem(
                  themeSettings,
                  'データ管理とバックアップ',
                  'データのエクスポート・インポート',
                  Icons.storage,
                  () => _showDataManagementDetail(context, themeSettings),
                ),
                _buildListItem(
                  themeSettings,
                  'フィードバック送信',
                  '要望やバグ報告を送信',
                  Icons.feedback,
                  () => _showFeedbackDetail(context, themeSettings),
                ),
                _buildListItem(
                  themeSettings,
                  '便利な使い方のコツ',
                  'アプリを効率的に使うためのヒント',
                  Icons.lightbulb,
                  () => _showUsageTipsDetail(context, themeSettings),
                ),
              ],
              '設定',
              'アプリの設定とカスタマイズについて説明します',
            )
          : ListView(
              padding: EdgeInsets.all(16),
              children: [
                _buildListItem(
                  themeSettings,
                  'テーマ設定の変更',
                  'アプリの見た目をカスタマイズ',
                  Icons.palette,
                  () => _showThemeSettingsDetail(context, themeSettings),
                ),
                SizedBox(height: 12),
                _buildListItem(
                  themeSettings,
                  '音声通知の設定',
                  'アラーム音と音量の調整',
                  Icons.volume_up,
                  () => _showSoundSettingsDetail(context, themeSettings),
                ),
                SizedBox(height: 12),
                _buildListItem(
                  themeSettings,
                  '通知設定の調整',
                  'アラームと通知の設定',
                  Icons.notifications,
                  () => _showNotificationSettingsDetail(context, themeSettings),
                ),
                SizedBox(height: 12),
                _buildListItem(
                  themeSettings,
                  'セキュリティ設定',
                  'パスコードロックと生体認証',
                  Icons.security,
                  () => _showSecuritySettingsDetail(context, themeSettings),
                ),
                SizedBox(height: 12),
                _buildListItem(
                  themeSettings,
                  'データ管理とバックアップ',
                  'データのエクスポート・インポート',
                  Icons.storage,
                  () => _showDataManagementDetail(context, themeSettings),
                ),
                SizedBox(height: 12),
                _buildListItem(
                  themeSettings,
                  'フィードバック送信',
                  '要望やバグ報告を送信',
                  Icons.feedback,
                  () => _showFeedbackDetail(context, themeSettings),
                ),
                SizedBox(height: 12),
                _buildListItem(
                  themeSettings,
                  '便利な使い方のコツ',
                  'アプリを効率的に使うためのヒント',
                  Icons.lightbulb,
                  () => _showUsageTipsDetail(context, themeSettings),
                ),
              ],
            ),
    );
  }

  Widget _buildListItem(
    ThemeSettings themeSettings,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      color: themeSettings.cardBackgroundColor,
      child: ListTile(
        leading: Icon(icon, color: Colors.blue, size: 28),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  void _showRoastingTimerDetail(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailPage(
          title: '焙煎タイマーって何？',
          content: [
            '焙煎作業って、焙煎機の前でじっと待っているわけじゃないんですよね。',
            '予熱中や焙煎中は、上に行ってハンドピックをしたり、他の作業をしたりします。',
            '',
            'でも、いつ焙煎室に戻ればいいか分からないと困りますよね。',
            '',
            'いや、タイマーで測ればいいじゃんって話なんですけど、',
            '豆の種類、重さ、煎り度によって焙煎時間って変わるじゃないですか？',
            'だから何分に設定すればいいかわからないときがありますよね。',
            '',
            '時間を間違えると、焙煎機に行く前に豆が落ちてきてしまったり、',
            '早く来すぎて何分も待ったり。',
            'そんなときに役立つのがこの焙煎タイマーです。',
            '',
            '【予熱タイマー】',
            '• 焙煎機の予熱時間を測ってくれます',
            '• デフォルトで30分に設定済み',
            '• 時間になったらアラームで知らせてくれます',
            '',
            '【焙煎タイマー】',
            '• 実際の焙煎時間を測ります',
            '• 手動で時間を設定するか、おすすめ時間を使えます',
            '• 一時停止や再開も自由自在',
            '',
            '【おすすめ焙煎タイマー】',
            '• 過去の焙煎記録があると、最適な焙煎時間を提案してくれます',
            '• 「この豆なら○分くらいがいいよ」って教えてくれるんです',
            '• 焙煎の記録が増えるごとに、より最適な時間を教えてくれます',
          ],
          themeSettings: themeSettings,
        ),
      ),
    );
  }

  void _showSoundSettingsDetail(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailPage(
          title: '音声通知の設定',
          content: [
            '【アラーム音の変更】',
            '1. ドロワーメニュー → 設定',
            '2. 「音声設定」をタップ',
            '3. 「タイマー音」から選択',
            '4. 5種類のアラーム音から選択可能',
            '',
            '【音量の調整】',
            '1. 音声設定画面で「音量」を調整',
            '2. スライダーで0〜100%の範囲で設定',
            '3. 「テスト」ボタンで音を確認',
            '',
            '【バイブレーション設定】',
            '1. 「バイブレーション」をオン/オフ',
            '2. 音が鳴らない環境でも通知を受け取れます',
          ],
          themeSettings: themeSettings,
        ),
      ),
    );
  }

  void _showRoastingRecordDetail(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailPage(
          title: '焙煎記録の作成',
          content: [
            '焙煎機にも記録機能はついていますが、豆の種類を記録することはできませんよね。この焙煎記録機能は、豆の種類、重さ、煎り度、焙煎時間の４つすべての記録することができます。',
            '',
            '【記録の作成方法】',
            '1. ドロワーメニュー（≡）から「焙煎記録を入力する」を選択',
            '2. または、記録タブから「焙煎記録」を選択',
            '3. A台・B台の両方の記録を同時に入力可能',
            '',
            '【入力項目の詳細】',
            '【豆の種類】',
            '• 自由入力：ブラジル、コロンビア、エチオピアなど',
            '• 焙煎機の記録にはない、重要な情報です',
            '',
            '【重さ】',
            '• 200g、300g、500gから選択',
            '• 焙煎機の容量に合わせた標準的な重量設定',
            '• 正確な重量記録で、品質の一貫性を保てます',
            '',
            '【煎り度】',
            '• 浅煎り、中煎り、中深煎り、深煎りから選択',
            '• 焙煎機の記録と合わせて、豆の状態を正確に記録',
            '',
            '【焙煎時間】',
            '• 分：秒の形式で入力（例：12:30）',
            '• 焙煎機のタイマーで確認した時間を手動で入力',
            '• 時間記録で、後で何分かかったかを確認可能',
            '',
            '【記録の活用】',
            '• 過去の記録を見返して、焙煎時間を確認',
            '• 豆の種類ごとに何分かかったかを把握',
            '• グループ機能で、チーム全体で記録を共有',
            '',
            '【記録の管理】',
            '• 記録一覧で過去の記録を検索・確認',
            '• 豆の種類、煎り度、日付でフィルタリング可能',
            '• 記録の編集・削除も簡単に実行',
            '',
            '【実用的な使い方】',
            '• 焙煎作業の直後に記録を入力',
            '• 豆の種類と煎り度を正確に入力',
            '• 焙煎時間を記録して、後で確認できるようにする',
          ],
          themeSettings: themeSettings,
        ),
      ),
    );
  }

  void _showBasicOperationDetail(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailPage(
          title: 'アプリの起動と基本操作',
          content: [
            'アプリを初めて使う時って、どこから始めればいいかわからないですよね。',
            'でも大丈夫です。このアプリは、あなたの焙煎作業をサポートするためのものです。',
            '',
            '【まずはここから始めましょう】',
            '1. アプリを起動したら、まずは「焙煎」タブを見てみてください',
            '2. 焙煎タイマーが表示されているはずです',
            '3. これがこのアプリのメイン機能の一つです',
            '',
            '【基本的な使い方】',
            '• 画面下部のタブをタップすると、それぞれの機能に切り替わります',
            '• 「焙煎」：タイマーと記録',
            '• 「管理」：スケジュールやTODO',
            '• 「記録」：焙煎記録やテイスティング',
            '• 「ドリップ」：ドリップパックのカウント',
            '• 「カレンダー」：日付別のデータ表示',
            '• 「グループ」：チームでの協力作業',
            '• 「ゲーム」：バッジとレベルアップ',
            '• 「設定」：アプリの設定',
            '',
            '【最初にやってみること】',
            '• 焙煎タイマーを試してみる（実際に焙煎しなくても大丈夫）',
            '• 各タブをタップして、どんな機能があるか見てみる',
            '• 左上のメニューボタン（≡）をタップして、設定画面も確認',
            '• ゲームタブでバッジシステムを確認',
            '',
            '【安心してください】',
            '• 間違った操作をしても、データは簡単に修正できます',
            '• 分からないことがあれば、この使い方ガイドをいつでも見てください',
            '• 最初は基本的な機能だけ使って、徐々に慣れていきましょう',
          ],
          themeSettings: themeSettings,
        ),
      ),
    );
  }

  void _showDrawerMenuDetail(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailPage(
          title: 'ドロワーメニューの使い方',
          content: [
            '画面左上にある「≡」マーク、これがドロワーメニューです。',
            'このメニューには、アプリの重要な機能がまとまっています。',
            '',
            '【メニューの開き方】',
            '• 画面左上の「≡」マークをタップするだけです',
            '• 左側からメニューがスライドして出てきます',
            '',
            '【メニューの中身】',
            '• 「焙煎記録を入力する」：焙煎作業の記録を作成',
            '• 「焙煎記録の一覧を見る」：過去の焙煎記録を確認',
            '• 「焙煎分析」：焙煎データの統計や分析',
            '• 「作業状況記録」：作業の進捗を記録',
            '• 「試飲感想記録」：コーヒーの試飲評価を記録',
            '• 「グループ管理」：他の人と一緒に使いたい時に',
            '• 「バッジ一覧」：獲得したバッジを確認',
            '• 「使い方」：今見ているこのページです',
            '• 「設定」：アプリの見た目や通知の設定',
            '',
            '【よく使う場面】',
            '• 焙煎作業の記録を入力したい時',
            '• 過去の焙煎記録を確認したい時',
            '• 作業の進捗を記録したい時',
            '• コーヒーの試飲評価を記録したい時',
            '• アプリの設定を変えたい時',
            '• グループ機能を使いたい時',
            '• バッジの獲得状況を確認したい時',
            '• 使い方が分からなくなった時',
            '',
            '【メニューの閉じ方】',
            '• メニュー外の暗い部分をタップ',
            '• または、画面を右にスワイプ',
            '',
            '【コツ】',
            '• 設定は最初に一度確認しておくと安心です',
            '• グループ機能は後からでも使えます',
            '• 使い方ガイドはいつでも見られるので、困ったらここに戻ってきてください',
          ],
          themeSettings: themeSettings,
        ),
      ),
    );
  }

  void _showDataSyncDetail(BuildContext context, ThemeSettings themeSettings) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailPage(
          title: 'データの保存と同期',
          content: [
            '【データの自動保存】',
            '• 入力したデータは自動的にローカルに保存されます',
            '• TODOリスト、スケジュール、焙煎記録など全てのデータが保存対象',
            '• 保存はリアルタイムで行われ、手動保存は不要です',
            '',
            '【Firebaseクラウド同期】',
            '• Googleアカウントでログインすると自動的にクラウド同期が開始',
            '• 焙煎記録、TODOリスト、スケジュール、担当表などが同期対象',
            '• 複数のスマートフォンやタブレットで同じデータにアクセス可能',
            '• インターネット接続が不安定な場合でも、接続時に自動同期',
            '',
            '【グループ同期機能】',
            '• グループに参加すると、メンバー間でデータを共有',
            '• リーダー権限：全メンバーのデータを編集・管理可能',
            '• メンバー権限：グループのデータを閲覧・一部編集可能',
            '• リアルタイムで他のメンバーの変更が反映されます',
            '',
            '【同期されるデータ】',
            '• 焙煎記録：豆の種類、重さ、焙煎度合い、時間、メモ',
            '• TODOリスト：タスク、完了状況、時間設定',
            '• スケジュール：作業スケジュール、時間ラベル',
            '• 担当表：メンバー、ラベル、担当履歴',
            '• ドリップカウンター：記録、統計データ',
            '• テイスティング記録：評価、感想、写真',
            '• 作業進捗：作業状況、進捗率',
            '',
            '【オフライン対応】',
            '• インターネット接続がない場合でも基本的な機能は利用可能',
            '• オフライン中に作成・編集したデータは接続時に自動同期',
            '• 同期の競合が発生した場合は最新のデータが優先されます',
            '',
            '【同期の確認方法】',
            '• データを編集すると自動的に同期が開始',
            '• グループ機能では他のメンバーの変更がリアルタイムで反映',
            '• 同期エラーが発生した場合はアプリ内で通知されます',
            '• 設定画面で同期状況を確認できます',
          ],
          themeSettings: themeSettings,
        ),
      ),
    );
  }

  void _showScheduleDetail(BuildContext context, ThemeSettings themeSettings) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailPage(
          title: 'スケジュールの作成',
          content: [
            '【スケジュールの作成】',
            '1. スケジュールタブを開く',
            '2. 右上の「+」ボタンをタップ',
            '3. 「スケジュール追加」を選択',
            '',
            '【基本スケジュールの設定】',
            '1. タイトル：スケジュールの名前を入力',
            '2. 日時：開始日時を設定',
            '3. 時間ラベル：作業時間を設定',
            '4. 詳細：スケジュールの詳細を入力',
            '',
            '【ローストスケジュールの自動作成】',
            '1. 「ローストスケジュール」を選択',
            '2. 豆の種類、重さ、煎り度を入力',
            '3. 「自動スケジュール作成」をタップ',
            '4. 最適な時間配分でスケジュールが作成されます',
            '',
            '【スケジュールの管理】',
            '• 編集：スケジュールをタップして編集',
            '• 削除：スケジュールを長押しして削除',
            '• 完了：チェックボックスで完了マーク',
          ],
          themeSettings: themeSettings,
        ),
      ),
    );
  }

  void _showTodoDetail(BuildContext context, ThemeSettings themeSettings) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailPage(
          title: 'TODOリストの使い方',
          content: [
            '【TODOの追加】',
            '1. TODOタブを開く',
            '2. 右上の「+」ボタンをタップ',
            '3. 「TODO追加」を選択',
            '',
            '【TODOの設定】',
            '1. タイトル：タスクの名前を入力',
            '2. 時間：完了予定時間を設定',
            '3. 詳細：タスクの詳細説明を入力',
            '4. 通知：通知の有効/無効を設定',
            '5. 「保存」ボタンをタップ',
            '',
            '【TODOの管理】',
            '• 完了：チェックボックスをタップ',
            '• 編集：TODOをタップして編集',
            '• 削除：TODOを長押しして削除',
            '• 並び替え：時間順で自動ソート',
            '',
            '【通知の設定】',
            '1. 設定画面で「通知設定」を開く',
            '2. 「TODO通知」をオン/オフ',
            '3. 通知音を選択',
            '4. 通知時間を調整',
          ],
          themeSettings: themeSettings,
        ),
      ),
    );
  }

  void _showDripCounterDetail(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailPage(
          title: 'ドリップカウンターの使い方',
          content: [
            '【カウンターの基本操作】',
            '1. ドリップタブを開く',
            '2. 大きな「+」ボタンでカウントアップ',
            '3. 大きな「-」ボタンでカウントダウン',
            '4. 現在のカウント数が中央に表示',
            '',
            '【記録の保存】',
            '1. 「記録保存」ボタンをタップ',
            '2. 豆の種類を選択',
            '3. 煎り度を選択',
            '4. 数量を確認・修正',
            '5. 「保存」ボタンをタップ',
            '',
            '【履歴の確認】',
            '1. 「履歴」ボタンをタップ',
            '2. 過去の記録一覧を表示',
            '3. 日付、豆の種類、数量で検索可能',
            '4. 記録をタップして詳細確認',
            '',
            '【統計の確認】',
            '1. 「統計」ボタンをタップ',
            '2. 日別・月別の使用統計を表示',
            '3. グラフで視覚的に確認',
          ],
          themeSettings: themeSettings,
        ),
      ),
    );
  }

  void _showTastingDetail(BuildContext context, ThemeSettings themeSettings) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailPage(
          title: 'テイスティング記録の作成',
          content: [
            '【テイスティング記録の作成】',
            '1. 記録タブを開く',
            '2. 右上の「+」ボタンをタップ',
            '3. 「テイスティング記録」を選択',
            '',
            '【評価項目の入力】',
            '1. 香り：1〜5段階で評価',
            '2. 味：1〜5段階で評価',
            '3. 酸味：1〜5段階で評価',
            '4. 苦味：1〜5段階で評価',
            '5. 後味：1〜5段階で評価',
            '',
            '【詳細情報の追加】',
            '1. 焙煎度合い：ライト〜ダークから選択',
            '2. 抽出方法：ドリップ、エスプレッソ等を選択',
            '3. 感想：詳細な感想を入力',
            '4. 写真：テイスティング時の写真を追加',
            '',
            '【記録の管理】',
            '• 保存：「保存」ボタンで記録保存',
            '• 編集：記録をタップして編集',
            '• 削除：記録を長押しして削除',
            '• 比較：複数の記録を並べて比較',
          ],
          themeSettings: themeSettings,
        ),
      ),
    );
  }

  void _showWorkProgressDetail(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailPage(
          title: '作業状況記録の使い方',
          content: [
            '【作業状況記録の作成】',
            '1. 記録タブを開く',
            '2. 右上の「+」ボタンをタップ',
            '3. 「作業状況記録」を選択',
            '',
            '【作業項目の設定】',
            '1. 作業名：作業の名前を入力',
            '2. 作業内容：詳細な作業内容を入力',
            '3. 開始時間：作業開始時間を設定',
            '4. 予定終了時間：完了予定時間を設定',
            '',
            '【進捗の記録】',
            '1. 進捗状況：0〜100%で設定',
            '2. 作業時間：実際の作業時間を記録',
            '3. メモ：作業に関するメモを入力',
            '4. 写真：作業状況の写真を追加',
            '',
            '【作業の管理】',
            '• 開始：「作業開始」ボタン',
            '• 一時停止：「一時停止」ボタン',
            '• 完了：「作業完了」ボタン',
            '• 編集：記録をタップして編集',
          ],
          themeSettings: themeSettings,
        ),
      ),
    );
  }

  void _showGroupCreateDetail(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailPage(
          title: 'グループの作成',
          content: [
            '【グループの作成手順】',
            '1. ドロワーメニュー → グループ管理',
            '2. 「グループ作成」ボタンをタップ',
            '3. グループ名を入力',
            '4. グループの説明を入力（任意）',
            '5. グループ画像を設定（任意）',
            '6. 「作成」ボタンをタップ',
            '',
            '【グループ設定】',
            '• プライバシー：公開/非公開を選択',
            '• 招待制限：招待可能な人数を設定',
            '• 編集権限：メンバーの編集権限を設定',
            '',
            '【グループの確認】',
            '• 作成したグループが一覧に表示',
            '• グループをタップして詳細確認',
            '• 設定変更は「編集」ボタンから',
          ],
          themeSettings: themeSettings,
        ),
      ),
    );
  }

  void _showMemberInviteDetail(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailPage(
          title: 'メンバーの招待',
          content: [
            '【メンバー招待の方法】',
            '1. グループ詳細画面を開く',
            '2. 「メンバー招待」ボタンをタップ',
            '3. 招待方法を選択',
            '',
            '【招待方法の種類】',
            '• リンク招待：招待リンクを生成',
            '• メール招待：メールアドレスで招待',
            '• QRコード：QRコードで招待',
            '',
            '【リンク招待の手順】',
            '1. 「リンク招待」を選択',
            '2. 招待リンクが生成されます',
            '3. リンクをコピーまたは共有',
            '4. 招待された人がリンクをタップ',
            '5. グループに参加確認',
            '',
            '【招待の管理】',
            '• 招待状況：招待一覧で確認',
            '• 招待取り消し：招待を削除可能',
            '• 招待期限：24時間で自動期限切れ',
          ],
          themeSettings: themeSettings,
        ),
      ),
    );
  }

  void _showGroupShareDetail(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailPage(
          title: 'グループ内での共有',
          content: [
            '【データの共有】',
            '1. 各機能で「グループ共有」オプションを有効化',
            '2. 焙煎記録、テイスティング記録等を共有',
            '3. グループメンバー全員で確認可能',
            '',
            '【共有設定】',
            '• 焙煎記録：グループ内で記録を共有',
            '• スケジュール：グループのスケジュールを共有',
            '• TODO：グループのタスクを共有',
            '• 統計：グループ全体の統計を表示',
            '',
            '【共有の管理】',
            '• 共有停止：個別に共有を停止可能',
            '• 権限管理：編集権限を設定',
            '• プライバシー：共有範囲を制限',
            '',
            '【リアルタイム同期】',
            '• グループ内の変更はリアルタイムで同期',
            '• オフライン時は自動同期',
            '• 同期状況は設定画面で確認',
          ],
          themeSettings: themeSettings,
        ),
      ),
    );
  }

  void _showThemeSettingsDetail(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailPage(
          title: 'テーマ設定の変更',
          content: [
            '【プリセットテーマの選択】',
            '1. 設定画面を開く',
            '2. 「テーマ設定」をタップ',
            '3. プリセットテーマから選択：',
            '   • デフォルト：標準的なテーマ',
            '   • ダーク：暗いテーマ',
            '   • ライト：明るいテーマ',
            '   • ライトグレー：グレー系テーマ',
            '   • ブラウン：茶色系テーマ',
            '   • レッド：赤系テーマ',
            '   • オレンジ：オレンジ系テーマ',
            '',
            '【カスタムテーマの作成】',
            '1. 「カスタムテーマ」を選択',
            '2. 各色項目をタップして色を変更',
            '3. プレビューで確認',
            '4. 「保存」ボタンでテーマ保存',
            '',
            '【フォント設定】',
            '1. 「フォント設定」をタップ',
            '2. フォントサイズを調整',
            '3. フォントファミリーを選択',
            '4. 変更は即座に反映されます',
          ],
          themeSettings: themeSettings,
        ),
      ),
    );
  }

  void _showNotificationSettingsDetail(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailPage(
          title: '通知設定の調整',
          content: [
            '【TODO通知の設定】',
            '1. 設定画面で「通知設定」を開く',
            '2. 「TODO通知」をオン/オフ',
            '3. 通知時間を設定',
            '4. 通知音を選択',
            '',
            '【タイマー通知の設定】',
            '1. 「タイマー通知」をオン/オフ',
            '2. タイマー音を選択',
            '3. 音量を調整',
            '4. バイブレーションを設定',
            '',
            '【通知のテスト】',
            '1. 「テスト通知」ボタンをタップ',
            '2. 設定した通知が実際に鳴ります',
            '3. 音やバイブレーションを確認',
            '',
            '【通知の管理】',
            '• 通知履歴：過去の通知を確認',
            '• 通知の削除：不要な通知を削除',
            '• 通知の優先度：重要度を設定',
          ],
          themeSettings: themeSettings,
        ),
      ),
    );
  }

  void _showSecuritySettingsDetail(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailPage(
          title: 'セキュリティ設定',
          content: [
            '【パスコードロックの設定】',
            '1. 設定画面で「セキュリティ」を開く',
            '2. 「パスコードロック」をオン',
            '3. 4桁のパスコードを入力',
            '4. パスコードを再入力して確認',
            '5. 「設定完了」をタップ',
            '',
            '【生体認証の設定】',
            '1. 「生体認証」をオン',
            '2. 指紋または顔認証を設定',
            '3. デバイスの設定画面で認証方法を追加',
            '4. アプリで認証をテスト',
            '',
            '【自動ロックの設定】',
            '1. 「自動ロック」をオン',
            '2. ロック時間を設定（1分〜30分）',
            '3. アプリを閉じた時に自動ロック',
            '',
            '【ロックの解除】',
            '• パスコード：4桁の数字を入力',
            '• 生体認証：指紋または顔認証',
            '• 緊急時：アプリ再インストール（データは失われます）',
          ],
          themeSettings: themeSettings,
        ),
      ),
    );
  }

  void _showDataManagementDetail(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailPage(
          title: 'データ管理とバックアップ',
          content: [
            '【データのエクスポート】',
            '1. 設定画面で「データ管理」を開く',
            '2. 「データエクスポート」をタップ',
            '3. エクスポート形式を選択（JSON/CSV）',
            '4. 保存先を選択',
            '5. 「エクスポート開始」をタップ',
            '',
            '【データのインポート】',
            '1. 「データインポート」をタップ',
            '2. インポートするファイルを選択',
            '3. インポート形式を確認',
            '4. 「インポート開始」をタップ',
            '5. 既存データとの重複を確認',
            '',
            '【キャッシュのクリア】',
            '1. 「キャッシュクリア」をタップ',
            '2. 確認ダイアログで「OK」をタップ',
            '3. アプリの一時データが削除されます',
            '4. アプリが再起動されます',
            '',
            '【バックアップの確認】',
            '• クラウドバックアップ：自動で実行',
            '• バックアップ状況：設定画面で確認',
            '• 手動バックアップ：「手動バックアップ」ボタン',
          ],
          themeSettings: themeSettings,
        ),
      ),
    );
  }

  void _showAttendanceDetail(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailPage(
          title: '出勤退勤機能の使い方',
          content: [
            '【出勤退勤機能とは】',
            '• 担当表でメンバーの出勤退勤状態を管理できます',
            '• 白いカード：出勤状態',
            '• 赤いカード：退勤状態',
            '• 各メンバーが自分の端末で状態を変更可能',
            '',
            '【出勤退勤状態の変更】',
            '1. 担当表タブを開く',
            '2. メンバー名のカードをタップ',
            '3. 確認ダイアログで「変更」をタップ',
            '4. 出勤⇔退勤の状態が切り替わります',
            '',
            '【状態の表示】',
            '• 出勤：白い背景、緑の「出勤」ラベル',
            '• 退勤：赤い背景、赤の「退勤」ラベル',
            '• 未設定：グレーの背景（タップ不可）',
            '',
            '【今日の出勤状況】',
            '• 担当表の上部に出勤状況が表示されます',
            '• 全メンバーの出勤退勤状態を一目で確認可能',
            '• リアルタイムで更新されます',
            '',
            '【データの同期】',
            '• 出勤退勤記録は自動的にクラウドに保存',
            '• グループ機能でメンバー間で共有',
            '• 複数端末で同じ状態を確認可能',
            '',
            '【活用のコツ】',
            '• 朝の出勤時に自分の状態を「出勤」に変更',
            '• 退勤時に「退勤」に変更',
            '• チーム全体の出勤状況を把握して作業調整',
            '• 欠勤者がいる場合は担当の再調整を検討',
          ],
          themeSettings: themeSettings,
        ),
      ),
    );
  }

  void _showUsageTipsDetail(BuildContext context, ThemeSettings themeSettings) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailPage(
          title: '便利な使い方のコツ',
          content: [
            '【効率的な焙煎作業】',
            '• 予熱タイマーを活用して時間を節約',
            '• 連続焙煎モードで複数回の焙煎を効率化',
            '• おすすめ時間を参考に最適な焙煎時間を見つける',
            '',
            '【スケジュール管理のコツ】',
            '• 前日にスケジュールを作成して準備',
            '• ローストスケジュールの自動作成機能を活用',
            '• 休憩時間を適切に設定して作業効率を向上',
            '',
            '【記録の活用】',
            '• 焙煎後すぐに記録を入力（記憶を頼りにしない）',
            '• 写真を活用して視覚的な記録を残す',
            '• 統計機能で焙煎の傾向を分析',
            '',
            '【グループ機能の活用】',
            '• チーム内で情報を共有して効率化',
            '• グループ統計でチーム全体の傾向を把握',
            '• リアルタイム同期で常に最新情報を共有',
            '',
            '【ゲーミフィケーションの活用】',
            '• バッジ獲得を目標に作業のモチベーションを向上',
            '• グループで協力してレベルアップを目指す',
            '• 出勤記録や作業記録で経験値を効率的に獲得',
            '',
            '【設定のカスタマイズ】',
            '• よく使う設定はお気に入りに登録',
            '• テーマ設定で長時間の作業でも目に優しい環境を作る',
            '• 通知設定で重要なタイミングを見逃さない',
          ],
          themeSettings: themeSettings,
        ),
      ),
    );
  }

  void _showCalendarDetail(BuildContext context, ThemeSettings themeSettings) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailPage(
          title: 'カレンダー機能の使い方',
          content: [
            '【カレンダー機能とは】',
            '• 日付別にスケジュール、記録、担当を一覧表示',
            '• 過去のデータを簡単に確認・検索可能',
            '• グループ参加時はチーム全体のデータも表示',
            '',
            '【カレンダーの基本操作】',
            '1. カレンダータブを開く',
            '2. 日付をタップして詳細を表示',
            '3. 左右の矢印で月を移動',
            '4. 今日の日付はハイライト表示',
            '',
            '【表示されるデータ】',
            '• 本日のスケジュール：作業予定と時間',
            '• ローストスケジュール：焙煎予定とメモ',
            '• 担当履歴：その日の担当者と作業内容',
            '• ドリップパック記録：使用した豆の種類と数量',
            '• 作業進捗：作業の完了状況と進捗率',
            '',
            '【データの確認方法】',
            '• 日付をタップして詳細データを表示',
            '• 各セクションをタップして詳細画面に移動',
            '• グループ参加時は他のメンバーのデータも確認可能',
            '',
            '【活用のコツ】',
            '• 過去の記録を参考に作業計画を立てる',
            '• 担当履歴で公平な作業分担を確認',
            '• ドリップパック使用量で在庫管理を効率化',
          ],
          themeSettings: themeSettings,
        ),
      ),
    );
  }

  void _showAssignmentDetail(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailPage(
          title: '担当表の使い方',
          content: [
            '【担当表機能とは】',
            '• チームメンバーの担当を自動で決める機能',
            '• 公平な担当分担で作業効率を向上',
            '• 出勤退勤状態に応じて担当を調整',
            '',
            '【担当表の基本設定】',
            '1. 担当表タブを開く',
            '2. 「メンバー設定」でチームメンバーを登録',
            '3. 「ラベル設定」で作業内容を設定',
            '4. 「担当を決める」ボタンで自動割り当て',
            '',
            '【担当の決め方】',
            '• 出勤しているメンバーから自動選択',
            '• 前回の担当履歴を考慮して公平に割り当て',
            '• 手動で担当を変更することも可能',
            '',
            '【出勤退勤機能】',
            '• 各メンバーが自分の出勤退勤状態を設定',
            '• 白いカード：出勤状態',
            '• 赤いカード：退勤状態',
            '• 出勤状態のメンバーのみが担当対象',
            '',
            '【担当表の管理】',
            '• 担当履歴で過去の担当を確認',
            '• グループ参加時はチーム全体で共有',
            '• 担当のリセット機能で翌日から新しく開始',
            '',
            '【活用のコツ】',
            '• 朝の出勤時に担当を決める',
            '• 出勤退勤状態を正確に設定',
            '• 担当履歴で公平性を確認',
          ],
          themeSettings: themeSettings,
        ),
      ),
    );
  }

  void _showBadgeSystemDetail(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailPage(
          title: 'バッジシステムとは',
          content: [
            '【バッジシステムの概要】',
            '• 作業や活動に応じてバッジを獲得できる機能',
            '• モチベーション向上と達成感の向上をサポート',
            '• グループ参加時はチーム全体でバッジを共有',
            '',
            '【バッジの種類】',
            '• 出勤バッジ：出勤日数に応じて獲得',
            '• 焙煎バッジ：焙煎時間に応じて獲得',
            '• ドリップパックバッジ：使用数量に応じて獲得',
            '• レベルバッジ：グループレベルに応じて獲得',
            '• 特別バッジ：特別な条件を満たすと獲得',
            '',
            '【バッジの獲得条件】',
            '• 出勤バッジ：10日、25日、50日、100日...',
            '• 焙煎バッジ：10分、30分、1時間、3時間...',
            '• ドリップパックバッジ：50袋、150袋、500袋...',
            '• レベルバッジ：レベル1、5、10、20...',
            '',
            '【バッジの確認方法】',
            '1. ゲームタブを開く',
            '2. 「バッジ一覧」をタップ',
            '3. カテゴリ別にバッジを確認',
            '4. 獲得済みバッジと進捗状況を表示',
            '',
            '【進捗の確認】',
            '• 未獲得バッジは進捗率を表示',
            '• 獲得済みバッジは獲得日時を表示',
            '• レベルバッジは現在レベルと必要レベルを表示',
            '',
            '【活用のコツ】',
            '• バッジ獲得を目標に作業のモチベーションを向上',
            '• グループで協力してバッジを効率的に獲得',
            '• 進捗状況を確認して次の目標を設定',
          ],
          themeSettings: themeSettings,
        ),
      ),
    );
  }

  void _showLevelSystemDetail(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailPage(
          title: 'レベルアップシステム',
          content: [
            '【レベルアップシステムの概要】',
            '• グループの活動に応じてレベルが上昇',
            '• 経験値を獲得してレベルアップを目指す',
            '• レベルが上がると新しいバッジが解放',
            '',
            '【経験値の獲得方法】',
            '• 出勤：1日につき1000経験値',
            '• 焙煎：1分につき10経験値',
            '• ドリップパック：1袋につき2経験値',
            '• テイスティング記録：1回につき500経験値',
            '• 作業進捗更新：1回につき150経験値',
            '',
            '【レベルアップの仕組み】',
            '• レベル1-20：10経験値ずつ増加',
            '• レベル21-100：15経験値ずつ増加',
            '• レベル101-1000：20経験値ずつ増加',
            '• レベル1001以上：25経験値ずつ増加',
            '',
            '【レベルバッジの解放】',
            '• レベル1：初心者バッジ',
            '• レベル5：見習いバッジ',
            '• レベル10：中級者バッジ',
            '• レベル20：上級者バッジ',
            '• レベル50：エキスパートバッジ',
            '• レベル100：マスターバッジ',
            '',
            '【レベル確認方法】',
            '1. ゲームタブを開く',
            '2. 現在のレベルと経験値を確認',
            '3. 次のレベルまでの必要経験値を表示',
            '4. バッジ一覧でレベルバッジを確認',
            '',
            '【効率的なレベルアップ】',
            '• 毎日の出勤で安定した経験値を獲得',
            '• 焙煎作業で大量の経験値を獲得',
            '• テイスティング記録で高経験値を獲得',
            '• グループで協力して効率的にレベルアップ',
          ],
          themeSettings: themeSettings,
        ),
      ),
    );
  }

  void _showFeedbackDetail(BuildContext context, ThemeSettings themeSettings) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailPage(
          title: 'フィードバック送信',
          content: [
            '【フィードバック機能とは】',
            '• アプリの改善要望やバグ報告を送信',
            '• 開発者に直接意見を伝えることが可能',
            '• アプリの品質向上に貢献',
            '',
            '【フィードバックの種類】',
            '• 要望・改善案：新機能や機能改善の提案',
            '• バグ報告：不具合やエラーの報告',
            '• その他：その他の意見や感想',
            '',
            '【フィードバックの送信方法】',
            '1. 設定画面を開く',
            '2. 「フィードバック送信」をタップ',
            '3. カテゴリを選択',
            '4. 件名とメッセージを入力',
            '5. 「送信」ボタンをタップ',
            '',
            '【効果的なフィードバックの書き方】',
            '• 具体的な状況や問題を説明',
            '• 再現手順を詳しく記載',
            '• 期待する動作を明確に記述',
            '• スクリーンショットがあるとより効果的',
            '',
            '【フィードバックの活用】',
            '• 開発チームが優先的に改善を検討',
            '• ユーザーの声を反映した機能追加',
            '• バグの早期発見と修正',
            '',
            '【注意事項】',
            '• 個人情報は含めないでください',
            '• 建設的な意見をお願いします',
            '• 返信は保証されませんが、全て確認しています',
          ],
          themeSettings: themeSettings,
        ),
      ),
    );
  }
}
