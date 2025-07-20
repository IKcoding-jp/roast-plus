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
    }

    // レベルアップ演出
    if (newLevel != null) {
      await showLevelUp(context, newLevel);
    }

    // バッジ獲得演出（単一の統合演出）
    if (newBadges.isNotEmpty) {
      await showUnifiedBadgeCelebration(context, newBadges);
    }
  }

  /// 統合バッジ獲得演出（複数バッジを一度に表示）
  static Future<void> showUnifiedBadgeCelebration(
    BuildContext context,
    List<GroupBadge> badges,
  ) async {
    if (!context.mounted || badges.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => _UnifiedBadgeCelebrationDialog(badges: badges),
    );

    await Future.delayed(Duration(seconds: 3));
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
                    // Lottieアニメーション（統一サイズ）
                    Container(
                      width: 180,
                      height: 180,
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

/// 内部用：統合バッジ獲得ダイアログ
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
      animation: _animationController,
      builder: (context, child) {
        return Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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
                    // ヘッダー
                    Row(
                      children: [
                        Icon(
                          Icons.emoji_events,
                          color: Colors.amber.shade600,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'バッジ獲得！',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'KiwiMaru',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),

                    // バッジ一覧
                    ...widget.badges
                        .map((badge) => _buildBadgeItem(badge, theme))
                        .toList(),

                    SizedBox(height: 16),
                    Text(
                      'タップして閉じる',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
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

  Widget _buildBadgeItem(GroupBadge badge, ThemeData theme) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: badge.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badge.color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // バッジアイコン
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: badge.color,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: badge.color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(badge.icon, color: Colors.white, size: 24),
          ),
          SizedBox(width: 12),

          // バッジ情報
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  badge.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                if (badge.earnedByUserName.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    'by ${badge.earnedByUserName}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
