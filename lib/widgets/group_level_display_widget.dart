import 'package:flutter/material.dart';
import '../models/group_gamification_models.dart';
import '../models/theme_settings.dart';
import 'package:provider/provider.dart';

/// グループレベルと経験値を表示するウィジェット
class GroupLevelDisplayWidget extends StatelessWidget {
  final GroupGamificationProfile profile;
  final double? width;
  final double? height;
  final bool showProgressBar;
  final bool showNextLevelInfo;

  const GroupLevelDisplayWidget({
    super.key,
    required this.profile,
    this.width,
    this.height,
    this.showProgressBar = true,
    this.showNextLevelInfo = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeSettings.cardBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // レベル表示
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                profile.levelIcon, // 修正箇所: profile.levelIconを使用
                color: profile.levelColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Lv.${profile.level}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: profile.levelColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // グループタイトル
          Text(
            profile.displayTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              color: themeSettings.fontColor1.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          if (showProgressBar) ...[
            // 経験値バー
            _buildExperienceBar(context),
            const SizedBox(height: 8),
          ],

          // 経験値情報
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '現在XP: ${profile.experiencePoints}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: themeSettings.fontColor1.withValues(alpha: 0.7),
                ),
              ),
              if (showNextLevelInfo && profile.level < 9999)
                Text(
                  '次レベルまで: ${profile.experienceToNextLevel}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: themeSettings.fontColor1.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),

          // 累積必要経験値情報
          if (showNextLevelInfo) ...[
            const SizedBox(height: 4),
            Text(
              '累積必要XP: ${_calculateTotalRequiredXP(profile.level)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: themeSettings.fontColor1.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 経験値バーを構築
  Widget _buildExperienceBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '経験値',
              style: theme.textTheme.bodySmall?.copyWith(
                color: themeSettings.fontColor1.withValues(alpha: 0.7),
              ),
            ),
            Text(
              '${(profile.levelProgress * 100).toStringAsFixed(1)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: themeSettings.fontColor1.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: profile.levelProgress,
          backgroundColor: colorScheme.outline.withValues(alpha: 0.2),
          valueColor: AlwaysStoppedAnimation<Color>(profile.levelColor),
          minHeight: 8,
        ),
      ],
    );
  }

  /// 指定レベルまでの累積必要経験値を計算
  int _calculateTotalRequiredXP(int level) {
    int totalXP = 0;
    for (int i = 1; i <= level; i++) {
      totalXP += _calculateRequiredXPForLevel(i);
    }
    return totalXP;
  }

  /// レベルに必要な経験値を計算（新しい仕様に基づく）
  int _calculateRequiredXPForLevel(int level) {
    if (level <= 20) return 10; // 最初はサクサク
    if (level <= 100) return 10 + (level - 20); // 緩やかに上昇
    if (level <= 1000) return 30 + ((level - 100) ~/ 10); // 徐々に増える
    return 50 + ((level - 1000) ~/ 100); // 高Lv帯でも急激に伸びない
  }
}

/// グループレベルバッジ表示ウィジェット
class GroupLevelBadgeWidget extends StatelessWidget {
  final List<GroupBadge> levelBadges;
  final VoidCallback? onTap;

  const GroupLevelBadgeWidget({
    super.key,
    required this.levelBadges,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeSettings = Provider.of<ThemeSettings>(context);

    if (levelBadges.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: themeSettings.cardBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 48,
              color: themeSettings.fontColor1.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 8),
            Text(
              'まだレベルバッジを獲得していません',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: themeSettings.fontColor1.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeSettings.cardBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events,
                color: themeSettings.iconColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'レベルバッジ (${levelBadges.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: themeSettings.fontColor1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: levelBadges.map((badge) {
              return _buildBadgeItem(context, badge);
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// バッジアイテムを構築
  Widget _buildBadgeItem(BuildContext context, GroupBadge badge) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: badge.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: badge.color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, color: badge.color, size: 16),
            const SizedBox(width: 6),
            Text(
              badge.name,
              style: theme.textTheme.bodySmall?.copyWith(
                color: badge.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
