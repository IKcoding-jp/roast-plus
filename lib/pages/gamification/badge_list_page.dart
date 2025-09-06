import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../models/gamification_provider.dart';
import '../../models/group_provider.dart';
import '../../models/group_gamification_models.dart';
import '../../utils/web_ui_utils.dart';

class BadgeListPage extends StatefulWidget {
  const BadgeListPage({super.key});

  @override
  State<BadgeListPage> createState() => _BadgeListPageState();
}

class _BadgeListPageState extends State<BadgeListPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _selectedCategory = 'all';
  GroupGamificationProfile? _cachedProfile;
  String? _currentGroupId;

  final Map<String, String> _categories = {
    'all': 'すべて',
    'attendance': '出勤',
    'roasting': '焙煎',
    'dripPack': 'ドリップパック',
    'level': 'レベル',
    'special': '特別',
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();

    // プロフィールを事前読み込み
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadProfile();
    });

    // 定期的にプロフィールを更新チェック
    _startPeriodicUpdate();
  }

  /// 定期的なプロフィール更新チェックを開始
  void _startPeriodicUpdate() {
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        _checkProfileUpdate();
        _startPeriodicUpdate(); // 再帰的に次のチェックをスケジュール
      }
    });
  }

  /// プロフィールの更新をチェック
  void _checkProfileUpdate() {
    try {
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      if (groupProvider.hasGroup && mounted) {
        final groupId = groupProvider.currentGroup!.id;
        final profile = groupProvider.getGroupGamificationProfile(groupId);

        if (profile != null && _cachedProfile != profile) {
          setState(() {
            _cachedProfile = profile;
            debugPrint(
              'バッジ一覧: プロフィールが更新されました - レベル: ${profile.level}, バッジ数: ${profile.badges.length}',
            );
          });
        }
      }
    } catch (e) {
      debugPrint('プロフィール更新チェックエラー: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // プロフィールの更新を監視
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    if (groupProvider.hasGroup) {
      final groupId = groupProvider.currentGroup!.id;

      // グループIDが変更された場合のみ監視を開始
      if (_currentGroupId != groupId) {
        _currentGroupId = groupId;

        // --- 修正ここから ---
        // グループが切り替わったらキャッシュを必ずリセット
        setState(() {
          _cachedProfile = null;
        });
        // --- 修正ここまで ---

        // プロフィールの監視を開始
        groupProvider.watchGroupGamificationProfile(groupId);

        // 最新のプロフィールを取得してキャッシュを更新
        final profile = groupProvider.getGroupGamificationProfile(groupId);
        if (profile != null && mounted) {
          setState(() {
            _cachedProfile = profile;
          });
        }
      } else {
        // 同じグループの場合は最新のプロフィールを取得
        final profile = groupProvider.getGroupGamificationProfile(groupId);
        if (profile != null && mounted && _cachedProfile != profile) {
          setState(() {
            _cachedProfile = profile;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();

    // プロフィールの監視を停止
    try {
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      if (groupProvider.hasGroup) {
        final groupId = groupProvider.currentGroup!.id;
        groupProvider.unwatchGroupGamificationProfile(groupId);
      }
    } catch (e) {
      // エラーは無視（dispose中なので）
    }

    super.dispose();
  }

  /// プロフィールを事前読み込み
  Future<void> _preloadProfile() async {
    try {
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      if (groupProvider.hasGroup) {
        final groupId = groupProvider.currentGroup!.id;

        // プロフィールの監視を開始（バックグラウンドで更新される）
        groupProvider.watchGroupGamificationProfile(groupId);

        final profile = groupProvider.getGroupGamificationProfile(groupId);

        if (profile != null) {
          setState(() {
            _cachedProfile = profile;
          });
        } else {
          // プロフィールがキャッシュされていない場合は非同期で読み込み
          setState(() {});
        }
      } else {
        setState(() {});
      }
    } catch (e) {
      debugPrint('プロフィール事前読み込みエラー: $e');
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: themeSettings.iconColor, size: 24),
            SizedBox(width: 8),
            Text(
              'バッジ一覧',
              style: TextStyle(
                color: themeSettings.appBarTextColor,
                fontSize: 20 * themeSettings.fontSizeScale,
                fontWeight: FontWeight.bold,
                fontFamily: themeSettings.fontFamily,
              ),
            ),
          ],
        ),
        backgroundColor: themeSettings.appBarColor,
        iconTheme: IconThemeData(color: themeSettings.iconColor),
        elevation: 0,
      ),
      body: WebUIUtils.isWeb
          ? _buildWebLayout(themeSettings)
          : _buildMobileLayout(themeSettings),
    );
  }

  Widget _buildWebLayout(ThemeSettings themeSettings) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            themeSettings.backgroundColor,
            themeSettings.backgroundColor.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 1400),
          child: Consumer2<GroupProvider, GamificationProvider>(
            builder: (context, groupProvider, gamificationProvider, child) {
              if (!groupProvider.hasGroup) {
                return Center(
                  child: Container(
                    padding: EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: themeSettings.cardBackgroundColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: themeSettings.iconColor.withValues(
                              alpha: 0.1,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.groups_outlined,
                            size: 48,
                            color: themeSettings.iconColor,
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'グループに参加すると\nバッジを確認できます',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            color: themeSettings.fontColor1,
                            fontWeight: FontWeight.bold,
                            fontFamily: themeSettings.fontFamily,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'チームで協力してバッジを獲得しましょう',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: themeSettings.fontColor2,
                            fontFamily: themeSettings.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final groupId = groupProvider.currentGroup!.id;

              // リアルタイムでプロフィールを取得（キャッシュも使用）
              GroupGamificationProfile? profile = _cachedProfile;
              profile ??= groupProvider.getGroupGamificationProfile(groupId);

              if (profile == null) {
                return Center(
                  child: Container(
                    padding: EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: themeSettings.cardBackgroundColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: themeSettings.iconColor,
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 24),
                        Text(
                          'バッジデータを読み込み中...',
                          style: TextStyle(
                            color: themeSettings.fontColor2,
                            fontSize: 16,
                            fontFamily: themeSettings.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    // カテゴリフィルター
                    _buildCategoryFilter(themeSettings),

                    SizedBox(height: 24),

                    // バッジグリッド
                    Expanded(
                      child: _buildBadgeGrid(
                        profile,
                        themeSettings,
                        isWeb: true,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(ThemeSettings themeSettings) {
    return Consumer2<GroupProvider, GamificationProvider>(
      builder: (context, groupProvider, gamificationProvider, child) {
        if (!groupProvider.hasGroup) {
          return Center(
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
                  'グループに参加すると\nバッジを確認できます',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontFamily: themeSettings.fontFamily,
                  ),
                ),
              ],
            ),
          );
        }

        final groupId = groupProvider.currentGroup!.id;

        // リアルタイムでプロフィールを取得（キャッシュも使用）
        GroupGamificationProfile? profile = _cachedProfile;
        profile ??= groupProvider.getGroupGamificationProfile(groupId);

        if (profile == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: themeSettings.iconColor),
                SizedBox(height: 16),
                Text(
                  'Loading...',
                  style: TextStyle(
                    color: themeSettings.fontColor2,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // カテゴリフィルター
              _buildCategoryFilter(themeSettings),

              // バッジグリッド
              Expanded(
                child: _buildBadgeGrid(profile, themeSettings, isWeb: false),
              ),
            ],
          ),
        );
      },
    );
  }

  /// カテゴリフィルター
  Widget _buildCategoryFilter(ThemeSettings themeSettings) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _categories.entries.map((entry) {
            final category = entry.key;
            final label = entry.value;
            final isSelected = _selectedCategory == category;

            return Container(
              margin: EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = category;
                  });
                },
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? themeSettings.iconColor
                        : themeSettings.cardBackgroundColor,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isSelected
                          ? themeSettings.iconColor
                          : themeSettings.iconColor.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: themeSettings.iconColor.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        Icon(Icons.check_circle, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : themeSettings.fontColor1,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: 14,
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// バッジグリッド
  Widget _buildBadgeGrid(
    GroupGamificationProfile profile,
    ThemeSettings themeSettings, {
    required bool isWeb,
  }) {
    final filteredBadges = _getFilteredBadges();
    final earnedBadgeIds = profile.badges.map((b) => b.id).toSet();

    // バッジ一覧を表示

    // WEB版では6列、モバイル版では2列
    final crossAxisCount = isWeb ? 6 : 2;
    final childAspectRatio = isWeb ? 0.8 : 0.85;
    final spacing = isWeb ? 16.0 : 16.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        cacheExtent: 1000,
        addAutomaticKeepAlives: false,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
        ),
        itemCount: filteredBadges.length,
        itemBuilder: (context, index) {
          final condition = filteredBadges[index];
          final isEarned = earnedBadgeIds.contains(condition.badgeId);
          final progress = _calculateBadgeProgress(condition, profile);
          final earnedBadge = isEarned
              ? profile.badges.firstWhere((b) => b.id == condition.badgeId)
              : null;

          // レベルバッジの場合は条件ベースでも判定
          bool finalIsEarned = isEarned;
          if (condition.category == BadgeCategory.level && !isEarned) {
            finalIsEarned = _checkLevelBadgeCondition(condition, profile.level);
            // レベルバッジ条件達成
          }

          // 獲得済みの場合は進捗を100%にする
          final finalProgress = finalIsEarned ? 1.0 : progress;

          // バッジ状態を確認

          return BadgeCard(
            condition: condition,
            isEarned: finalIsEarned,
            progress: finalProgress,
            earnedBadge: earnedBadge,
            themeSettings: themeSettings,
            animationDelay: index * 20,
            description: _getBadgeDescription(condition),
            progressText: _getBadgeProgressText(condition),
            isWeb: isWeb,
          );
        },
      ),
    );
  }

  /// バッジ進捗を計算
  double _calculateBadgeProgress(
    GroupBadgeCondition condition,
    GroupGamificationProfile? profile,
  ) {
    if (profile == null) return 0.0;
    // グループの統計データに基づいて進捗を計算
    final stats = profile.stats;

    switch (condition.badgeId) {
      // 出勤バッジの進捗率
      case 'group_attendance_10':
        return (stats.totalAttendanceDays / 10).clamp(0.0, 1.0);
      case 'group_attendance_25':
        return (stats.totalAttendanceDays / 25).clamp(0.0, 1.0);
      case 'group_attendance_50':
        return (stats.totalAttendanceDays / 50).clamp(0.0, 1.0);
      case 'group_attendance_100':
        return (stats.totalAttendanceDays / 100).clamp(0.0, 1.0);
      case 'group_attendance_200':
        return (stats.totalAttendanceDays / 200).clamp(0.0, 1.0);
      case 'group_attendance_300':
        return (stats.totalAttendanceDays / 300).clamp(0.0, 1.0);
      case 'group_attendance_500':
        return (stats.totalAttendanceDays / 500).clamp(0.0, 1.0);
      case 'group_attendance_800':
        return (stats.totalAttendanceDays / 800).clamp(0.0, 1.0);
      case 'group_attendance_1000':
        return (stats.totalAttendanceDays / 1000).clamp(0.0, 1.0);
      case 'group_attendance_2000':
        return (stats.totalAttendanceDays / 2000).clamp(0.0, 1.0);
      case 'group_attendance_3000':
        return (stats.totalAttendanceDays / 3000).clamp(0.0, 1.0);
      case 'group_attendance_5000':
        return (stats.totalAttendanceDays / 5000).clamp(0.0, 1.0);

      // 焙煎時間バッジの進捗率（新システム）
      case 'roast_time_10min':
        return (stats.totalRoastTimeMinutes / 10).clamp(0.0, 1.0);
      case 'roast_time_30min':
        return (stats.totalRoastTimeMinutes / 30).clamp(0.0, 1.0);
      case 'roast_time_1h':
        return (stats.totalRoastTimeMinutes / 60).clamp(0.0, 1.0);
      case 'roast_time_3h':
        return (stats.totalRoastTimeMinutes / 180).clamp(0.0, 1.0);
      case 'roast_time_6h':
        return (stats.totalRoastTimeMinutes / 360).clamp(0.0, 1.0);
      case 'roast_time_12h':
        return (stats.totalRoastTimeMinutes / 720).clamp(0.0, 1.0);
      case 'roast_time_25h':
        return (stats.totalRoastTimeMinutes / 1500).clamp(0.0, 1.0);
      case 'roast_time_50h':
        return (stats.totalRoastTimeMinutes / 3000).clamp(0.0, 1.0);
      case 'roast_time_100h':
        return (stats.totalRoastTimeMinutes / 6000).clamp(0.0, 1.0);
      case 'roast_time_166h':
        return (stats.totalRoastTimeMinutes / 10000).clamp(0.0, 1.0);

      // ドリップパックバッジの進捗率（新システム）
      case 'drip_pack_50':
        return (stats.totalDripPackCount / 50).clamp(0.0, 1.0);
      case 'drip_pack_150':
        return (stats.totalDripPackCount / 150).clamp(0.0, 1.0);
      case 'drip_pack_500':
        return (stats.totalDripPackCount / 500).clamp(0.0, 1.0);
      case 'drip_pack_1000':
        return (stats.totalDripPackCount / 1000).clamp(0.0, 1.0);
      case 'drip_pack_2000':
        return (stats.totalDripPackCount / 2000).clamp(0.0, 1.0);
      case 'drip_pack_5000':
        return (stats.totalDripPackCount / 5000).clamp(0.0, 1.0);
      case 'drip_pack_8000':
        return (stats.totalDripPackCount / 8000).clamp(0.0, 1.0);
      case 'drip_pack_12000':
        return (stats.totalDripPackCount / 12000).clamp(0.0, 1.0);
      case 'drip_pack_16000':
        return (stats.totalDripPackCount / 16000).clamp(0.0, 1.0);
      case 'drip_pack_20000':
        return (stats.totalDripPackCount / 20000).clamp(0.0, 1.0);
      case 'drip_pack_25000':
        return (stats.totalDripPackCount / 25000).clamp(0.0, 1.0);
      case 'drip_pack_30000':
        return (stats.totalDripPackCount / 30000).clamp(0.0, 1.0);
      case 'drip_pack_50000':
        return (stats.totalDripPackCount / 50000).clamp(0.0, 1.0);

      // レベルバッジの進捗率
      case 'group_level_1':
      case 'group_level_5':
      case 'group_level_10':
      case 'group_level_20':
      case 'group_level_50':
      case 'group_level_100':
      case 'group_level_250':
      case 'group_level_500':
      case 'group_level_1000':
      case 'group_level_2000':
      case 'group_level_3000':
      case 'group_level_5000':
      case 'group_level_7500':
      case 'group_level_9999':
        return _calculateLevelBadgeProgress(condition, profile.stats);

      // 特殊バッジの進捗率
      case 'group_tasting_100':
        return (profile.stats.totalTastingRecords / 100).clamp(0.0, 1.0);

      default:
        return 0.0;
    }
  }

  /// レベルバッジの進捗率を計算
  double _calculateLevelBadgeProgress(
    GroupBadgeCondition condition,
    GroupStats stats,
  ) {
    try {
      // バッジIDから必要なレベルを抽出
      final levelMatch = RegExp(
        r'group_level_(\d+)',
      ).firstMatch(condition.badgeId);
      if (levelMatch == null) return 0.0;

      final requiredLevel = int.parse(levelMatch.group(1)!);

      // グループプロバイダーから実際のレベルを取得
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      if (groupProvider.hasGroup) {
        final groupId = groupProvider.currentGroup!.id;
        final profile = groupProvider.getGroupGamificationProfile(groupId);
        if (profile != null) {
          final progress = (profile.level / requiredLevel).clamp(0.0, 1.0);
          debugPrint(
            'レベルバッジ進捗計算: ${condition.badgeId} - 現在レベル=${profile.level}, 必要レベル=$requiredLevel, 進捗=$progress',
          );
          return progress;
        }
      }
    } catch (e) {
      debugPrint('レベル進捗計算エラー: $e');
    }

    // フォールバック: 統計から経験値を推定してレベルを計算
    final estimatedXP =
        (stats.totalAttendanceDays * 10) +
        (stats.totalRoastTimeMinutes.toInt() * 1) +
        (stats.totalDripPackCount * 5) +
        (stats.totalTastingRecords * 20);

    final estimatedLevel = _calculateLevelFromXP(estimatedXP);
    final levelMatch = RegExp(
      r'group_level_(\d+)',
    ).firstMatch(condition.badgeId);
    if (levelMatch != null) {
      final requiredLevel = int.parse(levelMatch.group(1)!);
      return (estimatedLevel / requiredLevel).clamp(0.0, 1.0);
    }

    return 0.0;
  }

  /// レベルバッジの進捗テキストを取得
  String _getLevelBadgeProgressText(GroupBadgeCondition condition) {
    try {
      // バッジIDから必要なレベルを抽出
      final levelMatch = RegExp(
        r'group_level_(\d+)',
      ).firstMatch(condition.badgeId);
      if (levelMatch == null) return '';

      final requiredLevel = int.parse(levelMatch.group(1)!);

      // グループプロバイダーから現在のレベルを取得
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      if (groupProvider.hasGroup) {
        final groupId = groupProvider.currentGroup!.id;
        final profile = groupProvider.getGroupGamificationProfile(groupId);
        if (profile != null) {
          final currentLevel = profile.level;
          final isEarned = currentLevel >= requiredLevel;

          if (isEarned) {
            return 'Lv.$currentLevel / Lv.$requiredLevel';
          } else {
            return 'Lv.$currentLevel / Lv.$requiredLevel';
          }
        }
      }

      return 'Lv.? / Lv.$requiredLevel';
    } catch (e) {
      debugPrint('レベルバッジ進捗テキスト生成エラー: $e');
      return '';
    }
  }

  /// バッジの進捗テキストを取得（レベルバッジの場合は特別な表示）
  String _getBadgeProgressText(GroupBadgeCondition condition) {
    if (_cachedProfile == null) return '';
    if (condition.category == BadgeCategory.level) {
      return _getLevelBadgeProgressText(condition);
    }
    return '${(_calculateBadgeProgress(condition, _cachedProfile!) * 100).toInt()}%';
  }

  /// レベルバッジの達成条件を動的に生成
  String _getLevelBadgeDescription(GroupBadgeCondition condition) {
    try {
      // バッジIDから必要なレベルを抽出
      final levelMatch = RegExp(
        r'group_level_(\d+)',
      ).firstMatch(condition.badgeId);
      if (levelMatch == null) return condition.description;

      final requiredLevel = int.parse(levelMatch.group(1)!);

      // グループプロバイダーから現在のレベルを取得
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      if (groupProvider.hasGroup) {
        final groupId = groupProvider.currentGroup!.id;
        final profile = groupProvider.getGroupGamificationProfile(groupId);
        if (profile != null) {
          final currentLevel = profile.level;
          final isEarned = currentLevel >= requiredLevel;

          if (isEarned) {
            return 'グループレベルがLv.$requiredLevelに到達しました！';
          } else {
            return 'グループレベルをLv.$requiredLevelまで上げる\n（現在: Lv.$currentLevel）';
          }
        }
      }

      // プロフィールが取得できない場合はデフォルトの説明
      return 'グループレベルをLv.$requiredLevelまで上げる';
    } catch (e) {
      debugPrint('レベルバッジ説明生成エラー: $e');
      return condition.description;
    }
  }

  /// バッジの達成条件を取得（レベルバッジの場合は動的に生成）
  String _getBadgeDescription(GroupBadgeCondition condition) {
    if (condition.category == BadgeCategory.level) {
      return _getLevelBadgeDescription(condition);
    }
    return condition.description;
  }

  /// 経験値からレベルを計算
  int _calculateLevelFromXP(int experiencePoints) {
    int level = 1;
    while (experiencePoints >= _calculateRequiredXP(level + 1)) {
      level++;
    }
    return level;
  }

  /// レベルに必要な経験値を計算（GroupGamificationProfileと統一）
  int _calculateRequiredXP(int level) {
    if (level <= 1) return 0; // レベル1は0XPから開始
    if (level <= 20) return (level - 1) * 10; // レベル2-20: 10XPずつ増加
    if (level <= 100) return 190 + (level - 20) * 15; // レベル21-100: 15XPずつ増加
    if (level <= 1000) {
      return 1390 + (level - 100) * 20; // レベル101-1000: 20XPずつ増加
    }
    return 18190 + (level - 1000) * 25; // レベル1001以上: 25XPずつ増加
  }

  /// フィルタリングされたバッジリスト
  List<GroupBadgeCondition> _getFilteredBadges() {
    final allBadges = GroupBadgeConditions.conditions;

    if (_selectedCategory == 'all') {
      return allBadges;
    }

    return allBadges.where((badge) {
      switch (_selectedCategory) {
        case 'attendance':
          return badge.category == BadgeCategory.attendance;
        case 'roasting':
          return badge.category == BadgeCategory.roasting;
        case 'dripPack':
          return badge.category == BadgeCategory.dripPack;
        case 'level':
          return badge.category == BadgeCategory.level;
        case 'special':
          return badge.category == BadgeCategory.special;
        default:
          return false;
      }
    }).toList();
  }

  /// レベルバッジの条件を満たしているかチェック
  bool _checkLevelBadgeCondition(
    GroupBadgeCondition condition,
    int currentLevel,
  ) {
    try {
      final levelMatch = RegExp(
        r'group_level_(\d+)',
      ).firstMatch(condition.badgeId);
      if (levelMatch == null) return false;

      final requiredLevel = int.parse(levelMatch.group(1)!);
      return currentLevel >= requiredLevel;
    } catch (e) {
      debugPrint('レベルバッジ条件チェックエラー: $e');
      return false;
    }
  }
}

/// 個別バッジカードウィジェット
class BadgeCard extends StatefulWidget {
  final GroupBadgeCondition condition;
  final bool isEarned;
  final double progress;
  final GroupBadge? earnedBadge;
  final ThemeSettings themeSettings;
  final int animationDelay;
  final String description;
  final String progressText;
  final bool isWeb;

  const BadgeCard({
    super.key,
    required this.condition,
    required this.isEarned,
    required this.progress,
    this.earnedBadge,
    required this.themeSettings,
    required this.animationDelay,
    required this.description,
    required this.progressText,
    required this.isWeb,
  });

  @override
  State<BadgeCard> createState() => _BadgeCardState();
}

class _BadgeCardState extends State<BadgeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _rotationAnimation =
        Tween<double>(begin: 0.0, end: widget.isEarned ? 1.0 : 0.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(0.6, 1.0, curve: Curves.easeInOut),
          ),
        );

    // アニメーション遅延
    Future.delayed(Duration(milliseconds: widget.animationDelay), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: () => _showBadgeDetails(context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: widget.isEarned
                ? LinearGradient(
                    colors: [
                      widget.condition.color.withValues(alpha: 0.15),
                      widget.condition.color.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      widget.themeSettings.cardBackgroundColor.withValues(
                        alpha: 0.8,
                      ),
                      widget.themeSettings.cardBackgroundColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            boxShadow: [
              BoxShadow(
                color: widget.isEarned
                    ? widget.condition.color.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.1),
                blurRadius: widget.isEarned ? 12 : 8,
                offset: Offset(0, 4),
                spreadRadius: widget.isEarned ? 1 : 0,
              ),
            ],
            border: Border.all(
              color: widget.isEarned
                  ? widget.condition.color.withValues(alpha: 0.3)
                  : widget.themeSettings.borderColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Container(
            padding: EdgeInsets.all(widget.isWeb ? 12 : 16),
            child: Column(
              children: [
                // バッジアイコン
                Expanded(
                  flex: 3,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // グラデーション背景
                      Container(
                        width: widget.isWeb ? 70 : 80,
                        height: widget.isWeb ? 70 : 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: widget.isEarned
                              ? LinearGradient(
                                  colors: [
                                    widget.condition.color.withValues(
                                      alpha: 0.9,
                                    ),
                                    widget.condition.color,
                                    widget.condition.color.withValues(
                                      alpha: 0.8,
                                    ),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: [
                                    widget.themeSettings.borderColor.withValues(
                                      alpha: 0.5,
                                    ),
                                    widget.themeSettings.borderColor,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          boxShadow: widget.isEarned
                              ? [
                                  BoxShadow(
                                    color: widget.condition.color.withValues(
                                      alpha: 0.5,
                                    ),
                                    blurRadius: widget.isWeb ? 15 : 25,
                                    spreadRadius: widget.isWeb ? 3 : 5,
                                    offset: Offset(0, 4),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                        ),
                      ),
                      // アイコン
                      RotationTransition(
                        turns: _rotationAnimation,
                        child: Icon(
                          widget.isEarned
                              ? Icons
                                    .star // デフォルトアイコンを使用
                              : Icons.lock,
                          color: Colors.white,
                          size: widget.isWeb ? 28 : 40,
                        ),
                      ),
                      // 進捗リング（未獲得の場合）
                      if (!widget.isEarned)
                        SizedBox(
                          width: widget.isWeb ? 80 : 90,
                          height: widget.isWeb ? 80 : 90,
                          child: CircularProgressIndicator(
                            value: widget.progress,
                            backgroundColor: widget.themeSettings.borderColor
                                .withValues(alpha: 0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.condition.color,
                            ),
                            strokeWidth: widget.isWeb ? 3 : 4,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                    ],
                  ),
                ),

                SizedBox(height: widget.isWeb ? 8 : 12),

                // バッジ名
                Expanded(
                  flex: 1,
                  child: Text(
                    widget.condition.name,
                    style: TextStyle(
                      color: widget.isEarned
                          ? widget.themeSettings.fontColor1
                          : widget.themeSettings.fontColor1.withValues(
                              alpha: 0.6,
                            ),
                      fontSize:
                          (widget.isWeb ? 14 : 14) *
                          widget.themeSettings.fontSizeScale,
                      fontWeight: FontWeight.bold,
                      fontFamily: widget.themeSettings.fontFamily,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: widget.isWeb ? 2 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // 進捗ゲージとテキスト
                if (!widget.isEarned) ...[
                  SizedBox(height: widget.isWeb ? 4 : 8),
                  // 進捗バー
                  Container(
                    width: double.infinity,
                    height: widget.isWeb ? 2 : 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: widget.progress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: widget.condition.color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: widget.isWeb ? 2 : 4),
                  // 進捗テキスト
                  Text(
                    widget.progressText,
                    style: TextStyle(
                      color: widget.condition.color,
                      fontSize:
                          (widget.isWeb ? 12 : 12) *
                          widget.themeSettings.fontSizeScale,
                      fontWeight: FontWeight.bold,
                      fontFamily: widget.themeSettings.fontFamily,
                    ),
                  ),
                ],

                // 獲得日時
                if (widget.isEarned && widget.earnedBadge != null)
                  Text(
                    '${widget.earnedBadge!.earnedAt.month}/${widget.earnedBadge!.earnedAt.day} 獲得',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize:
                          (widget.isWeb ? 10 : 10) *
                          widget.themeSettings.fontSizeScale,
                      fontFamily: widget.themeSettings.fontFamily,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// バッジ詳細ダイアログ
  void _showBadgeDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.themeSettings.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: widget.isEarned
                      ? [
                          widget.condition.color.withValues(alpha: 0.8),
                          widget.condition.color,
                        ]
                      : [
                          widget.themeSettings.borderColor.withValues(
                            alpha: 0.6,
                          ),
                          widget.themeSettings.borderColor,
                        ],
                ),
              ),
              child: Icon(
                widget.isEarned
                    ? Icons
                          .star // デフォルトアイコンを使用
                    : Icons.lock,
                color: Colors.white,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.condition.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: widget.themeSettings.fontFamily,
                  color: widget.themeSettings.dialogTextColor,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '達成条件',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: widget.themeSettings.dialogTextColor,
                fontFamily: widget.themeSettings.fontFamily,
              ),
            ),
            SizedBox(height: 4),
            Text(
              widget.description,
              style: TextStyle(
                fontFamily: widget.themeSettings.fontFamily,
                color: widget.themeSettings.dialogTextColor,
              ),
            ),
            if (!widget.isEarned) ...[
              SizedBox(height: 16),
              Text(
                '進捗状況',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: widget.themeSettings.dialogTextColor,
                  fontFamily: widget.themeSettings.fontFamily,
                ),
              ),
              SizedBox(height: 8),
              LinearProgressIndicator(
                value: widget.progress,
                backgroundColor: widget.themeSettings.borderColor.withValues(
                  alpha: 0.3,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.condition.color,
                ),
              ),
              SizedBox(height: 4),
              Text(
                widget.progressText,
                style: TextStyle(
                  color: widget.condition.color,
                  fontWeight: FontWeight.w600,
                  fontFamily: widget.themeSettings.fontFamily,
                ),
              ),
            ],
            if (widget.isEarned) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.condition.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: widget.condition.color,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.earnedBadge != null
                            ? '${widget.earnedBadge!.earnedAt.year}/${widget.earnedBadge!.earnedAt.month}/${widget.earnedBadge!.earnedAt.day} に獲得'
                            : '獲得済み',
                        style: TextStyle(
                          color: widget.condition.color,
                          fontWeight: FontWeight.w600,
                          fontFamily: widget.themeSettings.fontFamily,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(fontFamily: widget.themeSettings.fontFamily),
            ),
          ),
        ],
      ),
    );
  }
}
