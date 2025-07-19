import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../models/gamification_provider.dart';
import '../../services/experience_manager.dart';
import '../../services/dashboard_stats_service.dart';
import '../../models/dashboard_stats_provider.dart';
import '../../pages/roast/roast_record_page.dart';
import '../../pages/roast/roast_record_list_page.dart';
import '../../pages/roast/roast_analysis_page.dart';
import '../../pages/work_progress/work_progress_page.dart';
import '../../pages/tasting/tasting_record_page.dart';
import '../../pages/calculator/calculator_page.dart';
import '../../pages/calendar/calendar_page.dart';
import '../../pages/group/group_card_page.dart';
import '../../pages/gamification/badge_list_page.dart';
import '../../pages/help/usage_guide_page.dart';
import '../../settings/app_settings_page.dart';
import '../../pages/todo/todo_page.dart';
import '../../models/group_gamification_provider.dart';
import 'group_dashboard_page.dart';
import '../../pages/drip/drip_counter_page.dart';
import '../../pages/home/AssignmentBoard.dart';

import 'dart:async';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  // 統計データ（Providerから取得するため不要）
  bool _isLoading = true;

  // Provider参照の安全なキャッシュ
  DashboardStatsProvider? _statsProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Provider参照を安全に取得してキャッシュ
    try {
      _statsProvider = Provider.of<DashboardStatsProvider>(
        context,
        listen: false,
      );
    } catch (e) {
      print('Provider取得エラー: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    // アニメーションコントローラーの初期化
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    // アニメーションの設定
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // フレーム完了後にアニメーションとデータ読み込みを開始
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // アニメーションは即座に開始
        _startAnimations();
        // データ読み込みは並行して実行
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    // アニメーションコントローラーの安全な破棄
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();

    // Provider参照のクリア
    _statsProvider = null;

    super.dispose();
  }

  void _startAnimations() async {
    try {
      await Future.delayed(Duration(milliseconds: 100));
      if (mounted) {
        _fadeController.forward();
      }

      await Future.delayed(Duration(milliseconds: 200));
      if (mounted) {
        _slideController.forward();
      }

      await Future.delayed(Duration(milliseconds: 300));
      if (mounted) {
        _scaleController.forward();
      }
    } catch (e) {
      print('アニメーション実行エラー: $e');
      // アニメーションエラーは無視して続行
    }
  }

  Future<void> _loadData() async {
    try {
      print('DashboardPage: 初期化開始');
      final startTime = DateTime.now();

      // UI表示を優先（先にローディング状態を解除）
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // ビルド完了後にバックグラウンドで初期化を実行
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _initializeProvidersInBackground(startTime);
      });
    } catch (e) {
      print('データ読み込みエラー: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// バックグラウンドでProviderを初期化
  Future<void> _initializeProvidersInBackground(DateTime startTime) async {
    try {
      // バックグラウンドで必要なデータを初期化
      final futures = <Future>[];

      // ExperienceManagerを軽量初期化
      futures.add(() async {
        try {
          final experienceManager = ExperienceManager.instance;
          await experienceManager.initialize();
        } catch (e) {
          print('ExperienceManager初期化エラー: $e');
        }
      }());

      // 統計データProviderを軽量初期化
      futures.add(() async {
        try {
          if (mounted && _statsProvider != null) {
            await _statsProvider!.initialize();
          }
        } catch (e) {
          print('DashboardStatsProvider初期化エラー: $e');
        }
      }());

      // バックグラウンドで並列実行
      await Future.wait(futures);

      final endTime = DateTime.now();
      final loadTime = endTime.difference(startTime).inMilliseconds;
      print('DashboardPage: 初期化完了 (${loadTime}ms)');
    } catch (e) {
      print('バックグラウンド初期化エラー: $e');
    }
  }

  /// 焙煎時間のフォーマット
  String _formatRoastingTime(int totalMinutes) {
    if (totalMinutes == 0) return '0分';

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0) {
      if (minutes > 0) {
        return '$hours時間$minutes分';
      } else {
        return '$hours時間';
      }
    } else {
      return '$minutes分';
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupGamificationProvider = Provider.of<GroupGamificationProvider>(
      context,
      listen: false,
    );

    // グループに参加していない場合は初期化を試行
    if (!groupGamificationProvider.hasGroup) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await groupGamificationProvider.autoInitialize();
      });
    }

    // グループ中心のダッシュボードページにリダイレクト
    return GroupDashboardPage();
  }

  Widget _buildHeader(ThemeSettings themeSettings) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
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
        );
      },
    );
  }

  Widget _buildGrowthCard(ThemeSettings themeSettings) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: Consumer<GamificationProvider>(
            builder: (context, gamificationProvider, child) {
              final profile = gamificationProvider.userProfile;
              final level = profile.level;
              final currentXP = profile.experiencePoints;
              final progress = profile.levelProgress;

              return Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                color: themeSettings.backgroundColor2,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        themeSettings.iconColor.withOpacity(0.1),
                        themeSettings.buttonColor.withOpacity(0.1),
                      ],
                    ),
                  ),
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.emoji_events,
                            color: themeSettings.iconColor,
                            size: 28,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'あなたの成長',
                            style: TextStyle(
                              fontSize: 20 * themeSettings.fontSizeScale,
                              fontWeight: FontWeight.bold,
                              color: themeSettings.fontColor1,
                              fontFamily: themeSettings.fontFamily,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // レベル表示
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'レベル $level',
                                style: TextStyle(
                                  fontSize: 24 * themeSettings.fontSizeScale,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade700,
                                  fontFamily: themeSettings.fontFamily,
                                ),
                              ),
                              Text(
                                '総XP: $currentXP',
                                style: TextStyle(
                                  fontSize: 14 * themeSettings.fontSizeScale,
                                  color: themeSettings.fontColor1.withOpacity(
                                    0.7,
                                  ),
                                  fontFamily: themeSettings.fontFamily,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: themeSettings.buttonColor.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.trending_up,
                              color: themeSettings.buttonColor,
                              size: 30,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 16),

                      // XPプログレスバー
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '次のレベルまで',
                                style: TextStyle(
                                  fontSize: 14 * themeSettings.fontSizeScale,
                                  color: themeSettings.fontColor1,
                                  fontFamily: themeSettings.fontFamily,
                                ),
                              ),
                              Text(
                                '${profile.experienceToNextLevel} XP',
                                style: TextStyle(
                                  fontSize: 14 * themeSettings.fontSizeScale,
                                  color: themeSettings.fontColor1,
                                  fontFamily: themeSettings.fontFamily,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: themeSettings.inputBackgroundColor,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              themeSettings.iconColor,
                            ),
                            minHeight: 8,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatsCards(ThemeSettings themeSettings) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Consumer<DashboardStatsProvider>(
            builder: (context, statsProvider, child) {
              final statsData = statsProvider.statsData;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '累積データ',
                    style: TextStyle(
                      fontSize: 18 * themeSettings.fontSizeScale,
                      fontWeight: FontWeight.bold,
                      color: themeSettings.fontColor1,
                      fontFamily: themeSettings.fontFamily,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          themeSettings,
                          '焙煎時間',
                          _formatRoastingTime(
                            statsData['totalRoastingTime'] ?? 0,
                          ),
                          Icons.timer,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          themeSettings,
                          '出勤日数',
                          '${statsData['attendanceDays'] ?? 0}日',
                          Icons.calendar_today,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          themeSettings,
                          'ドリップパック',
                          '${statsData['dripPackCount'] ?? 0}袋',
                          Icons.local_drink,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          themeSettings,
                          '完了タスク',
                          '${statsData['completedTasks'] ?? 0}件',
                          Icons.check_circle,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    ThemeSettings themeSettings,
    String title,
    String value,
    IconData icon,
  ) {
    return Card(
      elevation: 4,
      color: themeSettings.backgroundColor2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              themeSettings.iconColor.withOpacity(0.1),
              themeSettings.iconColor.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: themeSettings.iconColor, size: 24),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20 * themeSettings.fontSizeScale,
                fontWeight: FontWeight.bold,
                color: themeSettings.fontColor1,
                fontFamily: themeSettings.fontFamily,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12 * themeSettings.fontSizeScale,
                color: themeSettings.fontColor1.withOpacity(0.7),
                fontFamily: themeSettings.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentBadges(ThemeSettings themeSettings) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Consumer<GamificationProvider>(
            builder: (context, gamificationProvider, child) {
              final earnedBadges = gamificationProvider.userProfile.badges;
              final recentBadges = earnedBadges.take(5).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '最近の称号',
                        style: TextStyle(
                          fontSize: 18 * themeSettings.fontSizeScale,
                          fontWeight: FontWeight.bold,
                          color: themeSettings.fontColor1,
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => BadgeListPage()),
                          );
                        },
                        child: Text(
                          'すべて見る',
                          style: TextStyle(
                            color: Colors.blue.shade600,
                            fontFamily: themeSettings.fontFamily,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),

                  if (recentBadges.isEmpty)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            'まだ称号がありません\n活動を続けて称号を獲得しましょう！',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: themeSettings.fontColor1.withOpacity(0.6),
                              fontFamily: themeSettings.fontFamily,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: recentBadges.length,
                        itemBuilder: (context, index) {
                          final badge = recentBadges[index];
                          return Container(
                            width: 80,
                            margin: EdgeInsets.only(right: 12),
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.amber.shade100,
                                      Colors.amber.shade50,
                                    ],
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.emoji_events,
                                      color: Colors.amber.shade600,
                                      size: 24,
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      badge.name,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize:
                                            10 * themeSettings.fontSizeScale,
                                        fontWeight: FontWeight.bold,
                                        color: themeSettings.fontColor1,
                                        fontFamily: themeSettings.fontFamily,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // 新しい機能セクション構造
  Widget _buildFeatureSections(ThemeSettings themeSettings) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 業務機能セクション
              _buildFeatureSection(
                themeSettings,
                '業務機能',
                Icons.work,
                Colors.orange.shade600,
                [
                  _buildFeatureCard(
                    themeSettings,
                    '焙煎記録',
                    Icons.edit,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RoastRecordPage()),
                    ),
                  ),
                  _buildFeatureCard(
                    themeSettings,
                    '記録一覧',
                    Icons.list,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RoastRecordListPage()),
                    ),
                  ),
                  _buildFeatureCard(
                    themeSettings,
                    '焙煎分析',
                    Icons.analytics,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RoastAnalysisPage()),
                    ),
                  ),
                  _buildFeatureCard(
                    themeSettings,
                    '作業記録',
                    Icons.work_outline,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => WorkProgressPage()),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // 分析・記録セクション
              _buildFeatureSection(
                themeSettings,
                '分析・記録',
                Icons.assessment,
                Colors.blue.shade600,
                [
                  _buildFeatureCard(
                    themeSettings,
                    '試飲記録',
                    Icons.coffee,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TastingRecordPage()),
                    ),
                  ),
                  _buildFeatureCard(
                    themeSettings,
                    'カウンター',
                    Icons.local_drink,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DripCounterPage()),
                    ),
                  ),
                  _buildFeatureCard(
                    themeSettings,
                    'カレンダー',
                    Icons.calendar_month,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CalendarPage()),
                    ),
                  ),
                  _buildFeatureCard(
                    themeSettings,
                    '担当表',
                    Icons.group,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AssignmentBoard()),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // 成長と実績セクション
              _buildFeatureSection(
                themeSettings,
                '成長と実績',
                Icons.emoji_events,
                Colors.purple.shade600,
                [
                  _buildFeatureCard(
                    themeSettings,
                    'グループ',
                    Icons.group_work,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => GroupCardPage()),
                    ),
                  ),
                  _buildFeatureCard(
                    themeSettings,
                    'バッジ',
                    Icons.military_tech,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => BadgeListPage()),
                    ),
                  ),
                  _buildFeatureCard(
                    themeSettings,
                    'メモ・TODO',
                    Icons.edit_note,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TodoPage()),
                    ),
                  ),
                  _buildFeatureCard(
                    themeSettings,
                    '電卓',
                    Icons.calculate,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CalculatorPage()),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // サポート・設定セクション
              _buildFeatureSection(
                themeSettings,
                'サポート・設定',
                Icons.settings,
                Colors.grey.shade600,
                [
                  _buildFeatureCard(
                    themeSettings,
                    '使い方',
                    Icons.help_outline,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => UsageGuidePage()),
                    ),
                  ),
                  _buildFeatureCard(
                    themeSettings,
                    '設定',
                    Icons.settings,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AppSettingsPage()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 機能セクションのヘッダー
  Widget _buildFeatureSection(
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
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withOpacity(0.3), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16 * themeSettings.fontSizeScale,
                  fontWeight: FontWeight.bold,
                  color: themeSettings.fontColor1,
                  fontFamily: themeSettings.fontFamily,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),

        // 機能カードグリッド
        Wrap(spacing: 12, runSpacing: 12, children: children),
      ],
    );
  }

  // 機能カード（新しいデザイン）
  Widget _buildFeatureCard(
    ThemeSettings themeSettings,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: Container(
        height: 100,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: themeSettings.backgroundColor2,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: themeSettings.iconColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: themeSettings.iconColor, size: 28),
                  SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14 * themeSettings.fontSizeScale,
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
      ),
    );
  }
}
