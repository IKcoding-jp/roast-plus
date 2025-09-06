import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../models/group_gamification_models.dart';

/// グループの成長・実績獲得時の演出を管理するヘルパークラス
class GroupCelebrationHelper {
  /// XP獲得演出
  static Future<void> showXpGain(BuildContext context, int xp) async {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (_) => _CelebrationDialog(
        lottieAsset: 'assets/animations/Drip Coffee.json',
        message: 'グループが $xp XP を獲得！',
        duration: Duration(seconds: 2),
        isFullScreen: false,
      ),
    );

    await Future.delayed(Duration(seconds: 2));
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  /// レベルアップ演出
  static Future<void> showLevelUp(BuildContext context, int newLevel) async {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _CelebrationDialog(
        lottieAsset: 'assets/animations/Coffie Cap.json',
        message: '🎉 グループレベルが $newLevel になりました！',
        duration: Duration(seconds: 3),
        isFullScreen: true,
      ),
    );

    await Future.delayed(Duration(seconds: 3));
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  /// バッジ獲得演出（複数バッジ対応）- 非推奨：showUnifiedBadgeCelebrationを使用
  @Deprecated('showUnifiedBadgeCelebrationを使用してください')
  static Future<void> showBadgeCelebration(
    BuildContext context,
    List<GroupBadge> badges,
  ) async {
    return showUnifiedBadgeCelebration(context, badges);
  }

  /// 複合演出（XP獲得 + レベルアップ + バッジ獲得）
  static Future<void> showCompleteCelebration(
    BuildContext context, {
    int? xpGained,
    int? newLevel,
    List<GroupBadge> newBadges = const [],
  }) async {
    if (!context.mounted) return;

    // XP獲得演出
    if (xpGained != null && xpGained > 0) {
      await showXpGain(context, xpGained);
      if (!context.mounted) return;
    }

    // レベルアップ演出
    if (newLevel != null) {
      await showLevelUp(context, newLevel);
      if (!context.mounted) return;
    }

    // バッジ獲得演出（新しい順次アニメーション演出）
    if (newBadges.isNotEmpty) {
      await showSequentialBadgeCelebration(context, newBadges);
    }
  }

  /// 統合バッジ獲得演出（複数バッジを一度に表示）
  static Future<void> showUnifiedBadgeCelebration(
    BuildContext context,
    List<GroupBadge> badges,
  ) async {
    if (!context.mounted || badges.isEmpty) return;

    // 新しい順次バッジ獲得演出を使用
    await showSequentialBadgeCelebration(context, badges);
  }

  /// 新しいバッジ獲得演出（1つずつアニメーション表示）
  static Future<void> showSequentialBadgeCelebration(
    BuildContext context,
    List<GroupBadge> badges,
  ) async {
    if (!context.mounted || badges.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _SequentialBadgeCelebrationDialog(badges: badges),
    );

    // バッジ数に応じて表示時間を調整（各バッジ1.5秒 + 開始・終了時間）
    final displayDuration = Duration(
      seconds: 1 + (badges.length * 1.5).round() + 1,
    );
    await Future.delayed(displayDuration);
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

/// 内部用：共通演出ダイアログ
class _CelebrationDialog extends StatefulWidget {
  final String lottieAsset;
  final String message;
  final Duration duration;
  final bool isFullScreen;

  const _CelebrationDialog({
    required this.lottieAsset,
    required this.message,
    required this.duration,
    this.isFullScreen = false,
  });

  @override
  State<_CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<_CelebrationDialog>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
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
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Container(
          color: Colors.black.withValues(alpha: 0.7 * _fadeAnimation.value),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: widget.isFullScreen ? 350 : 300,
                      height: widget.isFullScreen ? 400 : 350,
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Lottieアニメーション
                          SizedBox(
                            width:
                                widget.lottieAsset.contains('Coffie Cap.json')
                                ? 300
                                : 180,
                            height:
                                widget.lottieAsset.contains('Coffie Cap.json')
                                ? 300
                                : 180,
                            child: Lottie.asset(
                              widget.lottieAsset,
                              fit: BoxFit.contain,
                            ),
                          ),
                          SizedBox(height: 20),
                          // メッセージ
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              widget.message,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 内部用：統合バッジ獲得演出ダイアログ
class _UnifiedBadgeCelebrationDialog extends StatefulWidget {
  final List<GroupBadge> badges;

  const _UnifiedBadgeCelebrationDialog({required this.badges});

  @override
  State<_UnifiedBadgeCelebrationDialog> createState() =>
      _UnifiedBadgeCelebrationDialogState();
}

class _UnifiedBadgeCelebrationDialogState
    extends State<_UnifiedBadgeCelebrationDialog>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
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
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Container(
          color: Colors.black.withValues(alpha: 0.7 * _fadeAnimation.value),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 350,
                      height: 400,
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // タイトル
                          Text(
                            '🏆 新しいバッジを獲得！',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade700,
                            ),
                          ),
                          SizedBox(height: 20),
                          // バッジ一覧
                          Expanded(
                            child: ListView.builder(
                              itemCount: widget.badges.length,
                              itemBuilder: (context, index) {
                                final badge = widget.badges[index];
                                return ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: badge.color,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.star,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    badge.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(badge.description),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 内部用：順次バッジ獲得演出ダイアログ（1つずつアニメーション表示）
class _SequentialBadgeCelebrationDialog extends StatefulWidget {
  final List<GroupBadge> badges;

  const _SequentialBadgeCelebrationDialog({required this.badges});

  @override
  State<_SequentialBadgeCelebrationDialog> createState() =>
      _SequentialBadgeCelebrationDialogState();
}

class _SequentialBadgeCelebrationDialogState
    extends State<_SequentialBadgeCelebrationDialog>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _badgeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _badgeScaleAnimation;
  late Animation<double> _badgeRotationAnimation;

  int _currentBadgeIndex = 0;
  bool _isShowingBadge = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _badgeController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _badgeScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _badgeController,
        curve: Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _badgeRotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _badgeController,
        curve: Interval(0.6, 1.0, curve: Curves.easeInOut),
      ),
    );

    _startAnimation();
  }

  void _startAnimation() async {
    if (!mounted) return;
    await _fadeController.forward();
    await _showNextBadge();
  }

  Future<void> _showNextBadge() async {
    if (!mounted) return;

    if (_currentBadgeIndex >= widget.badges.length) {
      // すべてのバッジを表示完了
      await Future.delayed(Duration(seconds: 1));
      if (!mounted) return;
      await _fadeController.reverse();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      return;
    }

    if (mounted) {
      setState(() {
        _isShowingBadge = true;
      });
    }

    _badgeController.reset();
    await _badgeController.forward();

    // バッジ表示時間
    await Future.delayed(Duration(seconds: 1));

    if (mounted) {
      setState(() {
        _isShowingBadge = false;
        _currentBadgeIndex++;
      });
    }

    // 次のバッジへ
    await Future.delayed(Duration(milliseconds: 300));
    await _showNextBadge();
  }

  @override
  void dispose() {
    _fadeController.stop();
    _badgeController.stop();
    _fadeController.dispose();
    _badgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Container(
          color: Colors.black.withValues(alpha: 0.8 * _fadeAnimation.value),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 350,
                height: 450,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // タイトル
                    Text(
                      '🏆 バッジ獲得！',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade700,
                      ),
                    ),
                    SizedBox(height: 20),

                    // 現在のバッジ表示エリア
                    Expanded(
                      child:
                          _isShowingBadge &&
                              _currentBadgeIndex < widget.badges.length
                          ? _buildCurrentBadge(
                              widget.badges[_currentBadgeIndex],
                            )
                          : SizedBox.shrink(),
                    ),

                    // 進捗表示
                    Padding(
                      padding: EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${_isShowingBadge ? _currentBadgeIndex + 1 : _currentBadgeIndex}/${widget.badges.length}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        ],
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

  Widget _buildCurrentBadge(GroupBadge badge) {
    return AnimatedBuilder(
      animation: _badgeController,
      builder: (context, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // バッジアイコン（スケール + 回転アニメーション）
            Transform.scale(
              scale: _badgeScaleAnimation.value,
              child: Transform.rotate(
                angle: _badgeRotationAnimation.value * 2 * 3.14159,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [badge.color.withValues(alpha: 0.8), badge.color],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: badge.color.withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(Icons.star, color: Colors.white, size: 60),
                ),
              ),
            ),
            SizedBox(height: 20),

            // バッジ名
            Text(
              badge.name,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: badge.color,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),

            // バッジ説明
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                badge.description,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }
}
