import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../models/theme_settings.dart';

/// 経験値獲得アニメーション
class ExperienceGainAnimation extends StatefulWidget {
  final int xpGained;
  final String activityDescription;
  final VoidCallback onComplete;

  const ExperienceGainAnimation({
    super.key,
    required this.xpGained,
    required this.activityDescription,
    required this.onComplete,
  });

  @override
  State<ExperienceGainAnimation> createState() =>
      _ExperienceGainAnimationState();
}

class _ExperienceGainAnimationState extends State<ExperienceGainAnimation>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _textController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _textController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.elasticOut),
    );

    _startAnimation();
  }

  void _startAnimation() async {
    await _fadeController.forward();
    await Future.delayed(Duration(milliseconds: 300));
    await _textController.forward();

    // アニメーション終了後3秒待機してから閉じる
    await Future.delayed(Duration(seconds: 3));
    await _fadeController.reverse();
    widget.onComplete();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Container(
          color: Colors.black.withOpacity(0.7 * _fadeAnimation.value),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 300,
                height: 350,
                decoration: BoxDecoration(
                  color: themeSettings.backgroundColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Lottieアニメーション
                    Container(
                      width: 200,
                      height: 200,
                      child: Lottie.asset(
                        'assets/animations/Morning Coffee.json',
                        fit: BoxFit.contain,
                        repeat: false,
                        errorBuilder: (context, error, stackTrace) {
                          // フォールバック用のアイコン
                          return Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.brown.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.coffee,
                              size: 80,
                              color: Colors.brown.shade600,
                            ),
                          );
                        },
                      ),
                    ),

                    SizedBox(height: 20),

                    // XP獲得テキスト
                    AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Column(
                            children: [
                              Text(
                                '+${widget.xpGained} XP',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade600,
                                  fontFamily: themeSettings.fontFamily,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                widget.activityDescription,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: themeSettings.fontColor1,
                                  fontFamily: themeSettings.fontFamily,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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
}

/// レベルアップアニメーション
class LevelUpAnimation extends StatefulWidget {
  final int oldLevel;
  final int newLevel;
  final List<String> newBadges;
  final VoidCallback onComplete;

  const LevelUpAnimation({
    super.key,
    required this.oldLevel,
    required this.newLevel,
    required this.newBadges,
    required this.onComplete,
  });

  @override
  State<LevelUpAnimation> createState() => _LevelUpAnimationState();
}

class _LevelUpAnimationState extends State<LevelUpAnimation>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _textController;
  late AnimationController _badgeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _textController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _badgeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.elasticOut),
    );

    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _badgeController, curve: Curves.easeOut));

    _startAnimation();
  }

  void _startAnimation() async {
    await _fadeController.forward();
    await Future.delayed(Duration(milliseconds: 300));
    await _textController.forward();

    if (widget.newBadges.isNotEmpty) {
      await Future.delayed(Duration(milliseconds: 500));
      await _badgeController.forward();
    }

    // アニメーション終了後4秒待機してから閉じる
    await Future.delayed(Duration(seconds: 4));
    await _fadeController.reverse();
    widget.onComplete();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _textController.dispose();
    _badgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Container(
          color: Colors.black.withOpacity(0.8 * _fadeAnimation.value),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 320,
                height: widget.newBadges.isNotEmpty ? 420 : 350,
                decoration: BoxDecoration(
                  color: themeSettings.backgroundColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.shade400, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.3),
                      blurRadius: 30,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Lottieアニメーション
                    Container(
                      width: 180,
                      height: 180,
                      child: Lottie.asset(
                        'assets/animations/Hot Smiling Coffee _ Good Morning.json',
                        fit: BoxFit.contain,
                        repeat: false,
                        errorBuilder: (context, error, stackTrace) {
                          // フォールバック用のアイコン
                          return Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  Colors.amber.shade200,
                                  Colors.amber.shade400,
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.emoji_events,
                              size: 80,
                              color: Colors.amber.shade700,
                            ),
                          );
                        },
                      ),
                    ),

                    SizedBox(height: 20),

                    // レベルアップテキスト
                    AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Column(
                            children: [
                              Text(
                                'LEVEL UP!',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade600,
                                  fontFamily: themeSettings.fontFamily,
                                  shadows: [
                                    Shadow(
                                      color: Colors.amber.withOpacity(0.5),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'LEVEL ${widget.oldLevel} → LEVEL ${widget.newLevel}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: themeSettings.fontColor1,
                                  fontFamily: themeSettings.fontFamily,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // 新しいバッジ表示
                    if (widget.newBadges.isNotEmpty) ...[
                      SizedBox(height: 20),
                      AnimatedBuilder(
                        animation: _slideAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _slideAnimation.value),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amber.shade300,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '🏆 新しい称号獲得！',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade700,
                                      fontFamily: themeSettings.fontFamily,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  ...widget.newBadges.map(
                                    (badge) => Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: Text(
                                        badge,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: themeSettings.fontColor1,
                                          fontFamily: themeSettings.fontFamily,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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

/// アニメーション表示ヘルパー関数
class AnimationHelper {
  /// 経験値獲得アニメーションを表示
  static void showExperienceGainAnimation(
    BuildContext context, {
    required int xpGained,
    required String description,
    required VoidCallback onComplete,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => ExperienceGainAnimation(
        xpGained: xpGained,
        activityDescription: description,
        onComplete: () {
          Navigator.of(context).pop();
          onComplete();
        },
      ),
    );
  }

  /// レベルアップアニメーションを表示
  static void showLevelUpAnimation(
    BuildContext context, {
    required int oldLevel,
    required int newLevel,
    required List<String> newBadges,
    required VoidCallback onComplete,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => LevelUpAnimation(
        oldLevel: oldLevel,
        newLevel: newLevel,
        newBadges: newBadges,
        onComplete: () {
          Navigator.of(context).pop();
          onComplete();
        },
      ),
    );
  }
}
