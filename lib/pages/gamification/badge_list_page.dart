import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as Math;
import '../../models/theme_settings.dart';
import '../../models/gamification_provider.dart';
import '../../models/gamification_models.dart';
import '../../models/group_provider.dart';
import '../../models/group_gamification_models.dart';
import '../../services/gamification_service.dart';

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
  bool _isLoading = true;
  GroupGamificationProfile? _cachedProfile;

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
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    // プロフィールを事前読み込み
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadProfile();
    });
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
            _isLoading = false;
          });
        } else {
          // プロフィールがキャッシュされていない場合は非同期で読み込み
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('プロフィール事前読み込みエラー: $e');
      setState(() {
        _isLoading = false;
      });
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
      body: Consumer<GroupProvider>(
        builder: (context, groupProvider, child) {
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

          // キャッシュされたプロフィールを優先使用
          GroupGamificationProfile? profile = _cachedProfile;
          if (profile == null) {
            profile = groupProvider.getGroupGamificationProfile(groupId);
          }

          if (profile == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: themeSettings.iconColor),
                  SizedBox(height: 16),
                  Text(
                    'バッジ情報を読み込み中...',
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
                Expanded(child: _buildBadgeGrid(profile, themeSettings)),
              ],
            ),
          );
        },
      ),
    );
  }

  /// カテゴリフィルター
  Widget _buildCategoryFilter(ThemeSettings themeSettings) {
    return Container(
      height: 50,
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories.keys.elementAt(index);
          final label = _categories[category]!;
          final isSelected = _selectedCategory == category;

          return Padding(
            padding: EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : themeSettings.fontColor1,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontFamily: themeSettings.fontFamily,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category;
                });
              },
              backgroundColor: themeSettings.backgroundColor2,
              selectedColor: Colors.brown.shade600,
              checkmarkColor: Colors.white,
              elevation: isSelected ? 4 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }

  /// バッジグリッド
  Widget _buildBadgeGrid(
    GroupGamificationProfile profile,
    ThemeSettings themeSettings,
  ) {
    final filteredBadges = _getFilteredBadges();
    final earnedBadgeIds = profile.badges.map((b) => b.id).toSet();

    return Padding(
      padding: EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: filteredBadges.length,
        itemBuilder: (context, index) {
          final condition = filteredBadges[index];
          final isEarned = earnedBadgeIds.contains(condition.badgeId);
          final progress = _calculateBadgeProgress(condition, profile);
          final earnedBadge = isEarned
              ? profile.badges.firstWhere((b) => b.id == condition.badgeId)
              : null;

          return AnimatedContainer(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: BadgeCard(
              condition: condition,
              isEarned: isEarned,
              progress: progress,
              earnedBadge: earnedBadge,
              themeSettings: themeSettings,
              animationDelay: index * 100,
            ),
          );
        },
      ),
    );
  }

  /// バッジ進捗を計算
  double _calculateBadgeProgress(
    GroupBadgeCondition condition,
    GroupGamificationProfile profile,
  ) {
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
      case 'group_level_5':
        return _calculateLevelProgress(stats, 5);
      case 'group_level_10':
        return _calculateLevelProgress(stats, 10);
      case 'group_level_20':
        return _calculateLevelProgress(stats, 20);
      case 'group_level_50':
        return _calculateLevelProgress(stats, 50);
      case 'group_level_100':
        return _calculateLevelProgress(stats, 100);

      // 特殊バッジの進捗率
      case 'group_tasting_100':
        return (stats.totalTastingRecords / 100).clamp(0.0, 1.0);

      default:
        return 0.0;
    }
  }

  /// レベル進捗を計算
  double _calculateLevelProgress(GroupStats stats, int requiredLevel) {
    // 実際のグループレベルを使用（統計から推定するのではなく）
    try {
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      if (groupProvider.hasGroup) {
        final groupId = groupProvider.currentGroup!.id;
        final profile = groupProvider.getGroupGamificationProfile(groupId);
        if (profile != null) {
          return (profile.level / requiredLevel).clamp(0.0, 1.0);
        }
      }
    } catch (e) {
      print('レベル進捗計算エラー: $e');
    }

    // フォールバック: 統計から経験値を推定してレベルを計算
    final estimatedXP =
        (stats.totalAttendanceDays * 10) +
        (stats.totalRoastTimeMinutes.toInt() * 1) +
        (stats.totalDripPackCount * 5) +
        (stats.totalTastingRecords * 20);

    final estimatedLevel = _calculateLevelFromXP(estimatedXP);
    return (estimatedLevel / requiredLevel).clamp(0.0, 1.0);
  }

  /// 経験値からレベルを計算
  int _calculateLevelFromXP(int experiencePoints) {
    int level = 1;
    while (experiencePoints >= _calculateRequiredXP(level + 1)) {
      level++;
    }
    return level;
  }

  /// レベルに必要な経験値を計算
  int _calculateRequiredXP(int level) {
    if (level <= 1) return 0;
    return (50 * level * Math.pow(level, 0.5)).round();
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
}

/// 個別バッジカードウィジェット
class BadgeCard extends StatefulWidget {
  final GroupBadgeCondition condition;
  final bool isEarned;
  final double progress;
  final GroupBadge? earnedBadge;
  final ThemeSettings themeSettings;
  final int animationDelay;

  const BadgeCard({
    super.key,
    required this.condition,
    required this.isEarned,
    required this.progress,
    this.earnedBadge,
    required this.themeSettings,
    required this.animationDelay,
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
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.6, curve: Curves.elasticOut),
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
        child: Card(
          elevation: widget.isEarned ? 8 : 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: widget.isEarned ? Colors.white : Colors.grey.shade100,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: widget.isEarned
                  ? LinearGradient(
                      colors: [
                        widget.condition.color.withOpacity(0.1),
                        widget.condition.color.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
            ),
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
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: widget.isEarned
                              ? LinearGradient(
                                  colors: [
                                    widget.condition.color.withOpacity(0.8),
                                    widget.condition.color,
                                  ],
                                )
                              : LinearGradient(
                                  colors: [
                                    Colors.grey.shade400,
                                    Colors.grey.shade600,
                                  ],
                                ),
                          boxShadow: widget.isEarned
                              ? [
                                  BoxShadow(
                                    color: widget.condition.color.withOpacity(
                                      0.4,
                                    ),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ]
                              : [],
                        ),
                      ),
                      // アイコン
                      RotationTransition(
                        turns: _rotationAnimation,
                        child: Icon(
                          widget.isEarned ? widget.condition.icon : Icons.lock,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      // 進捗リング（未獲得の場合）
                      if (!widget.isEarned)
                        SizedBox(
                          width: 90,
                          height: 90,
                          child: CircularProgressIndicator(
                            value: widget.progress,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.condition.color.withOpacity(0.7),
                            ),
                            strokeWidth: 4,
                          ),
                        ),
                    ],
                  ),
                ),

                SizedBox(height: 12),

                // バッジ名
                Expanded(
                  flex: 1,
                  child: Text(
                    widget.condition.name,
                    style: TextStyle(
                      color: widget.isEarned
                          ? widget.themeSettings.fontColor1
                          : Colors.grey.shade600,
                      fontSize: 14 * widget.themeSettings.fontSizeScale,
                      fontWeight: FontWeight.bold,
                      fontFamily: widget.themeSettings.fontFamily,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // 進捗ゲージとテキスト
                if (!widget.isEarned) ...[
                  SizedBox(height: 8),
                  // 進捗バー
                  Container(
                    width: double.infinity,
                    height: 4,
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
                  SizedBox(height: 4),
                  // 進捗テキスト
                  Text(
                    '${(widget.progress * 100).toInt()}%',
                    style: TextStyle(
                      color: widget.condition.color,
                      fontSize: 12 * widget.themeSettings.fontSizeScale,
                      fontWeight: FontWeight.w600,
                      fontFamily: widget.themeSettings.fontFamily,
                    ),
                  ),
                ],

                // 獲得日時
                if (widget.isEarned && widget.earnedBadge != null)
                  Text(
                    '${widget.earnedBadge!.earnedAt.month}/${widget.earnedBadge!.earnedAt.day} 獲得',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 10 * widget.themeSettings.fontSizeScale,
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
                          widget.condition.color.withOpacity(0.8),
                          widget.condition.color,
                        ]
                      : [Colors.grey.shade400, Colors.grey.shade600],
                ),
              ),
              child: Icon(
                widget.isEarned ? widget.condition.icon : Icons.lock,
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
                color: Colors.grey.shade700,
                fontFamily: widget.themeSettings.fontFamily,
              ),
            ),
            SizedBox(height: 4),
            Text(
              widget.condition.description,
              style: TextStyle(fontFamily: widget.themeSettings.fontFamily),
            ),
            if (!widget.isEarned) ...[
              SizedBox(height: 16),
              Text(
                '進捗状況',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                  fontFamily: widget.themeSettings.fontFamily,
                ),
              ),
              SizedBox(height: 8),
              LinearProgressIndicator(
                value: widget.progress,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.condition.color,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '${(widget.progress * 100).toInt()}% 完了',
                style: TextStyle(
                  color: widget.condition.color,
                  fontWeight: FontWeight.w600,
                  fontFamily: widget.themeSettings.fontFamily,
                ),
              ),
            ],
            if (widget.isEarned && widget.earnedBadge != null) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.condition.color.withOpacity(0.1),
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
                    Text(
                      '${widget.earnedBadge!.earnedAt.year}/${widget.earnedBadge!.earnedAt.month}/${widget.earnedBadge!.earnedAt.day} に獲得',
                      style: TextStyle(
                        color: widget.condition.color,
                        fontWeight: FontWeight.w600,
                        fontFamily: widget.themeSettings.fontFamily,
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
