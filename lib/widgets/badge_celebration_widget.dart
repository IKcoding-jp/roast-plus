import 'package:flutter/material.dart';
import '../models/group_gamification_models.dart';
import '../models/theme_settings.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class BadgeCelebrationWidget extends StatefulWidget {
  final List<GroupBadge> badges;
  final VoidCallback? onTap;

  const BadgeCelebrationWidget({super.key, required this.badges, this.onTap});

  @override
  State<BadgeCelebrationWidget> createState() => _BadgeCelebrationWidgetState();
}

class _BadgeCelebrationWidgetState extends State<BadgeCelebrationWidget> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    if (widget.badges.isEmpty) {
      return SizedBox.shrink();
    }

    // 最新3個のバッジを取得
    final recentBadges = widget.badges.take(3).toList();

    return Container(
      height: 120,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // ヘッダー
          Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.amber.shade600, size: 20),
              SizedBox(width: 8),
              Text(
                '最新獲得バッジ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: themeSettings.fontColor1,
                ),
              ),
              Spacer(),
              if (recentBadges.length > 1) ...[
                Text(
                  '${_currentPage + 1}/${recentBadges.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: themeSettings.fontColor2,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 8),

          // バッジスライダー
          Expanded(
            child: GestureDetector(
              onTap: widget.onTap,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: recentBadges.length,
                itemBuilder: (context, index) {
                  final badge = recentBadges[index];
                  return _buildBadgeCard(badge, themeSettings);
                },
              ),
            ),
          ),

          // ページインジケーター
          if (recentBadges.length > 1) ...[
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                recentBadges.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _currentPage
                        ? Colors.amber.shade600
                        : Colors.grey.shade300,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadgeCard(GroupBadge badge, ThemeSettings themeSettings) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: themeSettings.cardBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeSettings.borderColor),
        boxShadow: [
          BoxShadow(
            color: badge.color.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
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
                    color: badge.color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.star, color: Colors.white, size: 24),
            ),
            SizedBox(width: 12),

            // バッジ情報
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    badge.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: themeSettings.fontColor1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    badge.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: themeSettings.fontColor2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    '獲得日: ${DateFormat('MM/dd').format(badge.earnedAt)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: themeSettings.fontColor2,
                    ),
                  ),
                ],
              ),
            ),

            // 矢印アイコン
            Icon(
              Icons.chevron_right,
              color: themeSettings.fontColor2,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
