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
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
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
          color: Colors.black.withValues(alpha: 0.7 * _fadeAnimation.value),
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
                      width: 80,
                      height: 80,
                      child: Lottie.asset(
                        'assets/animations/Drip Coffee.json',
                        fit: BoxFit.contain,
                        repeat: false,
                        errorBuilder: (context, error, stackTrace) {
                          // フォールバック用のアイコン
                          return Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.brown.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.coffee,
                              size: 50,
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
}

class LoadingAnimationWidget extends StatelessWidget {
  final double? width;
  final double? height;
  final Color? backgroundColor;

  const LoadingAnimationWidget({
    super.key,
    this.width,
    this.height,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? Colors.transparent,
      child: Center(
        child: Lottie.asset(
          'assets/animations/Loading coffee bean.json',
          width: width ?? 200,
          height: height ?? 200,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class LoadingScreen extends StatelessWidget {
  final String? title;
  final Color? backgroundColor;

  const LoadingScreen({super.key, this.title, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const LoadingAnimationWidget(),
          if (title != null) ...[
            const SizedBox(height: 20),
            Text(
              title!,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
