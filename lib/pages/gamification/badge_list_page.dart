import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../models/gamification_provider.dart';
import '../../models/gamification_models.dart';
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

  final Map<String, String> _categories = {
    'all': 'すべて',
    'attendance': '出勤',
    'roasting': '焙煎',
    'drip': 'ドリップ',
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
      body: Consumer<GamificationProvider>(
        builder: (context, gamificationProvider, child) {
          if (!gamificationProvider.isInitialized) {
            return Center(
              child: CircularProgressIndicator(color: themeSettings.iconColor),
            );
          }

          return FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // ユーザー統計ヘッダー
                _buildStatsHeader(gamificationProvider, themeSettings),

                // カテゴリフィルター
                _buildCategoryFilter(themeSettings),

                // バッジグリッド
                Expanded(
                  child: _buildBadgeGrid(gamificationProvider, themeSettings),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 統計ヘッダー
  Widget _buildStatsHeader(
    GamificationProvider provider,
    ThemeSettings themeSettings,
  ) {
    final profile = provider.userProfile;
    final earnedBadges = profile.badges.length;
    final totalBadges = GamificationService.badgeConditions.length;

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade400, Colors.orange.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // バッジアイコン
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.3),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(Icons.emoji_events, color: Colors.white, size: 30),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'バッジコレクション',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18 * themeSettings.fontSizeScale,
                    fontWeight: FontWeight.bold,
                    fontFamily: themeSettings.fontFamily,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '$earnedBadges / $totalBadges 獲得',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14 * themeSettings.fontSizeScale,
                    fontFamily: themeSettings.fontFamily,
                  ),
                ),
                SizedBox(height: 8),
                // 進捗バー
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: earnedBadges / totalBadges,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    GamificationProvider provider,
    ThemeSettings themeSettings,
  ) {
    final filteredBadges = _getFilteredBadges();
    final earnedBadgeIds = provider.userProfile.badges.map((b) => b.id).toSet();

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
          final progress = provider.getBadgeProgress(condition);
          final earnedBadge = isEarned
              ? provider.userProfile.badges.firstWhere(
                  (b) => b.id == condition.badgeId,
                )
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

  /// フィルタリングされたバッジリスト
  List<BadgeCondition> _getFilteredBadges() {
    final allBadges = GamificationService.badgeConditions;

    if (_selectedCategory == 'all') {
      return allBadges;
    }

    return allBadges.where((badge) {
      switch (_selectedCategory) {
        case 'attendance':
          return [
            'work_5',
            'work_20',
            'work_60',
            'work_200',
            'work_500',
            'work_2000',
          ].contains(badge.badgeId);
        case 'roasting':
          return [
            'roast_1h',
            'roast_5h',
            'roast_20h',
            'roast_50h',
            'roast_150h',
            'roast_500h',
          ].contains(badge.badgeId);
        case 'drip':
          return [
            'drip_300',
            'drip_1000',
            'drip_5000',
            'drip_15000',
            'drip_50000',
            'drip_150000',
          ].contains(badge.badgeId);
        case 'level':
          return [
            'level_5',
            'level_10',
            'level_25',
            'level_50',
            'level_100',
            'level_200',
          ].contains(badge.badgeId);
        case 'special':
          return [
            'balanced_starter',
            'balanced_master',
            'coffee_legend',
            'early_bird',
            'consistent_worker',
          ].contains(badge.badgeId);
        default:
          return false;
      }
    }).toList();
  }
}

/// 個別バッジカードウィジェット
class BadgeCard extends StatefulWidget {
  final BadgeCondition condition;
  final bool isEarned;
  final double progress;
  final UserBadge? earnedBadge;
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

                // 進捗テキスト
                if (!widget.isEarned)
                  Text(
                    '${(widget.progress * 100).toInt()}%',
                    style: TextStyle(
                      color: widget.condition.color,
                      fontSize: 12 * widget.themeSettings.fontSizeScale,
                      fontWeight: FontWeight.w600,
                      fontFamily: widget.themeSettings.fontFamily,
                    ),
                  ),

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
