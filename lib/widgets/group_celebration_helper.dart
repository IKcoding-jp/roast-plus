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
      barrierColor: Colors.black.withOpacity(0.3),
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
      barrierColor: Colors.black.withOpacity(0.5),
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

  /// バッジ獲得演出（複数バッジ対応）
  static Future<void> showBadgeCelebration(
    BuildContext context,
    List<GroupBadge> badges,
  ) async {
    if (!context.mounted || badges.isEmpty) return;

    for (final badge in badges) {
      if (!context.mounted) break;

      showModalBottomSheet(
        context: context,
        isDismissible: false,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _BadgeCelebrationCard(badge: badge),
      );

      await Future.delayed(Duration(seconds: 2));
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // 複数バッジの場合は少し間隔を空ける
      if (badges.length > 1) {
        await Future.delayed(Duration(milliseconds: 500));
      }
    }
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
    }

    // レベルアップ演出
    if (newLevel != null) {
      await showLevelUp(context, newLevel);
    }

    // バッジ獲得演出
    if (newBadges.isNotEmpty) {
      await showBadgeCelebration(context, newBadges);
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
      animation: _animationController,
      builder: (context, child) {
        return Dialog(
          insetPadding: widget.isFullScreen
              ? EdgeInsets.zero
              : EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          backgroundColor: Colors.transparent,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Lottieアニメーション
                    Container(
                      width: widget.isFullScreen ? 200 : 150,
                      height: widget.isFullScreen ? 200 : 150,
                      child: Lottie.asset(
                        widget.lottieAsset,
                        repeat: false,
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(height: 20),

                    // メッセージ
                    Text(
                      widget.message,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'KiwiMaru',
                      ),
                      textAlign: TextAlign.center,
                    ),

                    if (widget.isFullScreen) ...[
                      SizedBox(height: 16),
                      Text(
                        'タップして閉じる',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 内部用：バッジ獲得カード
class _BadgeCelebrationCard extends StatefulWidget {
  final GroupBadge badge;

  const _BadgeCelebrationCard({required this.badge});

  @override
  State<_BadgeCelebrationCard> createState() => _BadgeCelebrationCardState();
}

class _BadgeCelebrationCardState extends State<_BadgeCelebrationCard>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(begin: Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.elasticOut,
          ),
        );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
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
      animation: _animationController,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Card(
                elevation: 12,
                shadowColor: widget.badge.color.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.badge.color.withOpacity(0.1),
                        widget.badge.color.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // バッジアイコン
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              widget.badge.color.withOpacity(0.8),
                              widget.badge.color,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.badge.color.withOpacity(0.4),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.badge.icon,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),

                      SizedBox(height: 16),

                      // バッジ名
                      Text(
                        '🎖 バッジ「${widget.badge.name}」を獲得しました！',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                          fontFamily: 'KiwiMaru',
                        ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: 8),

                      // バッジ説明
                      Text(
                        widget.badge.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: 12),

                      // 獲得者情報
                      Text(
                        'by ${widget.badge.earnedByUserName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
