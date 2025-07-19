import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../models/group_provider.dart';
import '../../models/group_gamification_provider.dart';
import '../../models/group_gamification_models.dart';
import '../../services/attendance_firestore_service.dart';
import '../../models/attendance_models.dart';

import '../gamification/badge_list_page.dart';
import '../../app.dart' show mainScaffoldKey;

/// グループ中心の新しいダッシュボード画面
class GroupDashboardPage extends StatefulWidget {
  const GroupDashboardPage({super.key});

  @override
  State<GroupDashboardPage> createState() => _GroupDashboardPageState();
}

class _GroupDashboardPageState extends State<GroupDashboardPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _detailedStats;
  GroupProvider? _groupProvider;
  GroupGamificationProvider? _gamificationProvider;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 安全にプロバイダーの参照を保存
    try {
      _groupProvider = Provider.of<GroupProvider>(context, listen: false);
      _gamificationProvider = Provider.of<GroupGamificationProvider>(
        context,
        listen: false,
      );

      // 初回読み込み（一度だけ）
      if (_isLoading && _groupProvider?.hasGroup == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadDetailedStats();
        });
      }
    } catch (e) {
      // プロバイダー取得エラー: $e
    }
  }

  @override
  void dispose() {
    // dispose時にプロバイダーへの参照をクリア
    _groupProvider = null;
    _gamificationProvider = null;
    super.dispose();
  }

  Future<void> _loadDetailedStats() async {
    if (!mounted || _gamificationProvider == null) return;

    try {
      final stats = await _gamificationProvider!.getDetailedStats();
      if (mounted) {
        setState(() {
          _detailedStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      // 詳細統計の読み込みエラー: $e
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Consumer2<GroupProvider, GroupGamificationProvider>(
      builder: (context, groupProvider, gamificationProvider, child) {
        // データ読み込み中の場合はローディング画面を表示
        if (groupProvider.loading) {
          return Scaffold(
            appBar: AppBar(
              title: Text('ホーム'),
              backgroundColor: themeSettings.appBarColor,
              foregroundColor: themeSettings.appBarTextColor,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        themeSettings.iconColor,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '読み込み中...',
                    style: TextStyle(
                      fontSize: 14,
                      color: themeSettings.fontColor2,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // グループに参加していない場合
        if (!groupProvider.hasGroup) {
          return Scaffold(
            appBar: AppBar(
              title: Text('ホーム'),
              backgroundColor: themeSettings.appBarColor,
              foregroundColor: themeSettings.appBarTextColor,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.groups_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'グループに参加すると\nホーム画面が表示されます',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/group_list');
                    },
                    child: Text('グループ一覧へ'),
                  ),
                ],
              ),
            ),
          );
        }

        final currentGroup = groupProvider.currentGroup;
        final profile = gamificationProvider.profile;

        return Scaffold(
          backgroundColor: themeSettings.backgroundColor,
          appBar: AppBar(
            title: Text(
              'ホーム',
              style: TextStyle(
                color: themeSettings.appBarTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: themeSettings.appBarColor,
            iconTheme: IconThemeData(color: themeSettings.appBarTextColor),
          ),
          body: _isLoading
              ? Center(child: CircularProgressIndicator())
              : Padding(
                  padding: EdgeInsets.all(16),
                  child: _buildMainFunctionShortcuts(context, themeSettings),
                ),
        );
      },
    );
  }

  /// グループ情報カード
  Widget _buildGroupInfoCard(
    BuildContext context,
    ThemeSettings themeSettings,
    GroupGamificationProfile profile,
  ) {
    return Card(
      color: themeSettings.backgroundColor2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.group, color: themeSettings.iconColor, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    profile.displayTitle,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: profile.levelColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'グループレベル ${profile.level}',
              style: TextStyle(fontSize: 16, color: themeSettings.fontColor2),
            ),
            if (profile.stats.daysSinceStart > 0) ...[
              SizedBox(height: 4),
              Text(
                '活動開始から ${profile.stats.daysSinceStart} 日',
                style: TextStyle(fontSize: 14, color: themeSettings.fontColor2),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// レベル・経験値カード
  Widget _buildLevelCard(
    BuildContext context,
    ThemeSettings themeSettings,
    GroupGamificationProfile profile,
  ) {
    return Card(
      color: themeSettings.backgroundColor2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '経験値・レベル',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: themeSettings.fontColor1,
              ),
            ),
            SizedBox(height: 12),

            // 経験値バー
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${profile.experiencePoints} XP',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: themeSettings.fontColor1,
                      ),
                    ),
                    Text(
                      'あと ${profile.experienceToNextLevel} XP',
                      style: TextStyle(
                        fontSize: 14,
                        color: themeSettings.fontColor2,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TweenAnimationBuilder<double>(
                    duration: Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(
                      begin: 0.0,
                      end: profile.levelProgress,
                    ),
                    builder: (context, value, child) {
                      return LinearProgressIndicator(
                        value: value,
                        backgroundColor: themeSettings.backgroundColor
                            .withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          profile.levelColor,
                        ),
                        minHeight: 12,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 統計情報カード
  Widget _buildStatsCard(
    BuildContext context,
    ThemeSettings themeSettings,
    GroupGamificationProfile profile,
  ) {
    final stats = profile.stats;

    return Card(
      color: themeSettings.backgroundColor2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'グループ実績',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: themeSettings.fontColor1,
              ),
            ),
            SizedBox(height: 16),

            // 統計グリッド
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              childAspectRatio: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildStatItem(
                  context,
                  themeSettings,
                  Icons.work,
                  '出勤日数',
                  '${stats.totalAttendanceDays}日',
                  Colors.blue,
                ),
                _buildStatItem(
                  context,
                  themeSettings,
                  Icons.local_fire_department,
                  '焙煎時間',
                  '${stats.totalRoastTimeHours.toStringAsFixed(1)}h',
                  Colors.orange,
                ),
                _buildStatItem(
                  context,
                  themeSettings,
                  Icons.local_cafe,
                  'ドリップパック',
                  '${stats.totalDripPackCount}個',
                  Colors.brown,
                ),
                _buildStatItem(
                  context,
                  themeSettings,
                  Icons.wine_bar,
                  'テイスティング',
                  '${stats.totalTastingRecords}回',
                  Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 統計アイテム
  Widget _buildStatItem(
    BuildContext context,
    ThemeSettings themeSettings,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: themeSettings.fontColor2,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: themeSettings.fontColor1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 次のバッジへの進捗カード
  Widget _buildUpcomingBadgesCard(
    BuildContext context,
    ThemeSettings themeSettings,
    GroupGamificationProvider gamificationProvider,
  ) {
    final upcomingBadges = gamificationProvider.getUpcomingBadges(limit: 2);

    return Card(
      color: themeSettings.backgroundColor2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '次のバッジ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: themeSettings.fontColor1,
              ),
            ),
            SizedBox(height: 12),

            if (upcomingBadges.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'すべてのバッジを獲得済みです！',
                    style: TextStyle(
                      color: themeSettings.fontColor2,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else
              ...upcomingBadges.map((condition) {
                final progress = gamificationProvider.getBadgeProgress(
                  condition,
                );
                return _buildUpcomingBadgeItem(
                  context,
                  themeSettings,
                  condition,
                  progress,
                );
              }),
          ],
        ),
      ),
    );
  }

  /// 次のバッジアイテム
  Widget _buildUpcomingBadgeItem(
    BuildContext context,
    ThemeSettings themeSettings,
    GroupBadgeCondition condition,
    double progress,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(condition.icon, color: condition.color, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  condition.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: themeSettings.fontColor1,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 12, color: themeSettings.fontColor2),
              ),
            ],
          ),
          SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: themeSettings.backgroundColor.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(condition.color),
              minHeight: 6,
            ),
          ),
          SizedBox(height: 4),
          Text(
            condition.description,
            style: TextStyle(fontSize: 12, color: themeSettings.fontColor2),
          ),
        ],
      ),
    );
  }

  /// 機能ショートカット
  Widget _buildFunctionShortcuts(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    return Card(
      color: themeSettings.backgroundColor2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '機能ショートカット',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: themeSettings.fontColor1,
              ),
            ),
            SizedBox(height: 16),

            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              childAspectRatio: 1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildShortcutItem(
                  context,
                  themeSettings,
                  Icons.work,
                  '出勤記録',
                  Colors.blue,
                  () => _recordAttendance(),
                ),
                _buildShortcutItem(
                  context,
                  themeSettings,
                  Icons.local_fire_department,
                  '焙煎記録',
                  Colors.orange,
                  () => Navigator.pushNamed(context, '/roast'),
                ),
                _buildShortcutItem(
                  context,
                  themeSettings,
                  Icons.local_cafe,
                  'ドリップパック',
                  Colors.brown,
                  () => Navigator.pushNamed(context, '/drip'),
                ),
                _buildShortcutItem(
                  context,
                  themeSettings,
                  Icons.wine_bar,
                  'テイスティング',
                  Colors.purple,
                  () => Navigator.pushNamed(context, '/tasting'),
                ),
                _buildShortcutItem(
                  context,
                  themeSettings,
                  Icons.analytics,
                  '分析',
                  Colors.green,
                  () => Navigator.pushNamed(context, '/analytics'),
                ),
                _buildShortcutItem(
                  context,
                  themeSettings,
                  Icons.calendar_today,
                  'カレンダー',
                  Colors.indigo,
                  () => Navigator.pushNamed(context, '/calendar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ショートカットアイテム
  Widget _buildShortcutItem(
    BuildContext context,
    ThemeSettings themeSettings,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: themeSettings.fontColor1,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// メンバー貢献度カード
  Widget _buildMemberContributionCard(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    if (_detailedStats == null) return SizedBox.shrink();

    return Card(
      color: themeSettings.backgroundColor2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'メンバー統計',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: themeSettings.fontColor1,
              ),
            ),
            SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildStatSummary(
                    themeSettings,
                    '総メンバー数',
                    '${_detailedStats!['totalMembers']}人',
                    Icons.people,
                    Colors.blue,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatSummary(
                    themeSettings,
                    '平均貢献度',
                    '${(_detailedStats!['averageContribution'] ?? 0).toStringAsFixed(0)}XP',
                    Icons.trending_up,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 統計サマリー
  Widget _buildStatSummary(
    ThemeSettings themeSettings,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: themeSettings.fontColor1,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: themeSettings.fontColor2),
          ),
        ],
      ),
    );
  }

  /// 出勤記録
  Future<void> _recordAttendance() async {
    if (!mounted || _gamificationProvider == null) return;

    try {
      final result = await _gamificationProvider!.recordAttendance();

      if (result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.green,
          ),
        );

        // レベルアップやバッジ獲得のアニメーションを表示
        if (result.levelUp || result.newBadges.isNotEmpty) {
          _showCelebrationAnimation(result);
        }

        await _loadDetailedStats();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('出勤記録に失敗しました'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// お祝いアニメーションを表示
  void _showCelebrationAnimation(GroupActivityResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // お祝いアニメーション
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.celebration,
                    size: 60,
                    color: Colors.orange,
                  ),
                ),
                SizedBox(height: 16),

                if (result.levelUp) ...[
                  Text(
                    '🎉 レベルアップ！',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  Text(
                    'レベル ${result.newLevel} に上がりました！',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 16),
                ],

                if (result.newBadges.isNotEmpty) ...[
                  Text(
                    '🏆 新しいバッジを獲得！',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                  ...result.newBadges.map((badge) => Text(badge.name)),
                  SizedBox(height: 16),
                ],

                Text(
                  result.message,
                  style: TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),

                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('OK'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// データを再読み込み
  Future<void> _refreshData() async {
    if (!mounted || _gamificationProvider == null) return;

    try {
      await _gamificationProvider!.refreshProfile();
      await _loadDetailedStats();
    } catch (e) {
      // データ再読み込みエラー: $e
    }
  }

  // シンプルレイアウト用メソッド

  /// メイン機能ショートカット（全画面版）
  Widget _buildMainFunctionShortcuts(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    final gamificationProvider = Provider.of<GroupGamificationProvider>(
      context,
      listen: false,
    );
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          Container(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: themeSettings.iconColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.coffee,
                    color: themeSettings.iconColor,
                    size: 30,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'おはようございます！',
                        style: TextStyle(
                          fontSize: 24 * themeSettings.fontSizeScale,
                          fontWeight: FontWeight.bold,
                          color: themeSettings.fontColor1,
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '今日も素晴らしい焙煎を',
                        style: TextStyle(
                          fontSize: 16 * themeSettings.fontSizeScale,
                          color: themeSettings.fontColor1.withOpacity(0.7),
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 業務機能セクション
          _buildFeatureSection(
            context,
            themeSettings,
            '業務機能',
            Icons.work,
            Colors.orange.shade600,
            [
              _buildFeatureCard(
                context,
                themeSettings,
                '焙煎タイマー',
                Icons.timer,
                () => _switchToBottomNavTab(0),
              ),
              _buildFeatureCard(
                context,
                themeSettings,
                '焙煎記録',
                Icons.edit_note,
                () => Navigator.pushNamed(context, '/roast_record'),
              ),
              _buildFeatureCard(
                context,
                themeSettings,
                '焙煎分析',
                Icons.insights,
                () => Navigator.pushNamed(context, '/roast_analysis'),
              ),
              _buildFeatureCard(
                context,
                themeSettings,
                '記録一覧',
                Icons.analytics,
                () => Navigator.pushNamed(context, '/roast_record_list'),
              ),
            ],
          ),
          SizedBox(height: 24),

          // 分析・記録セクション
          _buildFeatureSection(
            context,
            themeSettings,
            '分析・記録',
            Icons.assessment,
            Colors.blue.shade600,
            [
              _buildAttendanceFeatureCard(context, themeSettings),
              _buildFeatureCard(
                context,
                themeSettings,
                'カレンダー',
                Icons.calendar_today,
                () => _switchToBottomNavTab(1),
              ),
              _buildFeatureCard(
                context,
                themeSettings,
                'メモ・TODO',
                Icons.edit_note,
                () => Navigator.pushNamed(context, '/todo'),
              ),
              _buildFeatureCard(
                context,
                themeSettings,
                '電卓',
                Icons.calculate,
                () => Navigator.pushNamed(context, '/calculator'),
              ),
              _buildFeatureCard(
                context,
                themeSettings,
                'カウンター',
                Icons.local_cafe,
                () => _switchToBottomNavTab(3),
              ),
              _buildFeatureCard(
                context,
                themeSettings,
                '試飲記録',
                Icons.wine_bar,
                () => Navigator.pushNamed(context, '/tasting'),
              ),
            ],
          ),
          SizedBox(height: 24),

          // 成長と実績セクション
          _buildFeatureSection(
            context,
            themeSettings,
            '成長と実績',
            Icons.emoji_events,
            Colors.purple.shade600,
            [
              _buildFeatureCard(
                context,
                themeSettings,
                'グループ',
                Icons.group,
                () => Navigator.pushNamed(context, '/group_info'),
              ),
              _buildFeatureCard(
                context,
                themeSettings,
                'バッジ',
                Icons.military_tech,
                () => Navigator.pushNamed(context, '/badge_list'),
              ),
            ],
          ),
          SizedBox(height: 24),

          // サポート・設定セクション
          _buildFeatureSection(
            context,
            themeSettings,
            'サポート・設定',
            Icons.settings,
            Colors.grey.shade600,
            [
              _buildFeatureCard(
                context,
                themeSettings,
                '使い方',
                Icons.help_outline,
                () => Navigator.pushNamed(context, '/help'),
              ),
              _buildFeatureCard(
                context,
                themeSettings,
                '設定',
                Icons.settings,
                () => Navigator.pushNamed(context, '/settings'),
              ),
            ],
          ),
          SizedBox(height: 32),
        ],
      ),
    );
  }

  // 機能セクションのヘッダー
  Widget _buildFeatureSection(
    BuildContext context,
    ThemeSettings themeSettings,
    String title,
    IconData icon,
    Color accentColor,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // セクションヘッダー
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withOpacity(0.2), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              SizedBox(width: 16),
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
        ),
        SizedBox(height: 16),

        // 機能カードグリッド（2列固定レイアウト）
        Column(
          children: [
            if (children.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(child: children[0]),
                  SizedBox(width: 12),
                  Expanded(
                    child: children.length > 1 ? children[1] : Container(),
                  ),
                ],
              ),
            ],
            if (children.length > 2) ...[
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: children[2]),
                  SizedBox(width: 12),
                  Expanded(
                    child: children.length > 3 ? children[3] : Container(),
                  ),
                ],
              ),
            ],
            if (children.length > 4) ...[
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: children[4]),
                  SizedBox(width: 12),
                  Expanded(
                    child: children.length > 5 ? children[5] : Container(),
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }

  // 機能カード（新しいデザイン）
  Widget _buildFeatureCard(
    BuildContext context,
    ThemeSettings themeSettings,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Container(
      height: 120, // 統一された高さ
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: themeSettings.backgroundColor2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: themeSettings.iconColor.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: themeSettings.iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: themeSettings.iconColor, size: 24),
                ),
                SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13 * themeSettings.fontSizeScale,
                    fontWeight: FontWeight.w600,
                    color: themeSettings.fontColor1,
                    fontFamily: themeSettings.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 担当表機能カード（出勤状態表示付き）
  Widget _buildAttendanceFeatureCard(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    return FutureBuilder<bool>(
      future: _checkTodayAttendance(),
      builder: (context, snapshot) {
        final isAttended = snapshot.data ?? false;

        return Container(
          height: 120, // 統一された高さ
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: themeSettings.backgroundColor2,
            child: InkWell(
              onTap: () => _switchToBottomNavTab(4),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isAttended
                        ? Colors.green.withOpacity(0.4)
                        : themeSettings.iconColor.withOpacity(0.15),
                    width: isAttended ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isAttended
                                ? Colors.green.withOpacity(0.1)
                                : themeSettings.iconColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.assignment_ind,
                            color: isAttended
                                ? Colors.green
                                : themeSettings.iconColor,
                            size: 24,
                          ),
                        ),
                        if (isAttended)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      '担当表',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13 * themeSettings.fontSizeScale,
                        fontWeight: FontWeight.w600,
                        color: themeSettings.fontColor1,
                        fontFamily: themeSettings.fontFamily,
                      ),
                    ),
                    if (isAttended)
                      Container(
                        margin: EdgeInsets.only(top: 4),
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '出勤済み',
                          style: TextStyle(
                            fontSize: 10 * themeSettings.fontSizeScale,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontFamily: themeSettings.fontFamily,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// ボトムナビゲーションタブに切り替え
  void _switchToBottomNavTab(int index) {
    // GlobalKeyを使用してMainScaffoldのタブ切り替えメソッドを呼び出し
    final mainScaffoldState = mainScaffoldKey.currentState;
    if (mainScaffoldState != null && mainScaffoldState.mounted) {
      mainScaffoldState.switchToTab(index);
    }
  }

  /// 今日の出勤記録をチェック
  Future<bool> _checkTodayAttendance() async {
    if (!mounted) return false;

    try {
      // 今日の出勤記録を取得
      final records = await AttendanceFirestoreService.getTodayAttendance();

      // 出勤記録が存在するかチェック
      return records.isNotEmpty &&
          records.any((record) => record.status == AttendanceStatus.present);
    } catch (e) {
      // エラーの場合は未出勤として扱う
      return false;
    }
  }
}
