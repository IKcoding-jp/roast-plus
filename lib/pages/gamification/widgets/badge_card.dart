import 'package:flutter/material.dart';
import 'package:roastplus/models/theme_settings.dart';
import 'package:roastplus/models/group_gamification_models.dart';

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
                    widget.progressText,
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
              widget.description,
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
