import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/gamification_models.dart';
import '../models/theme_settings.dart';

/// バッジ獲得時のお祝いウィジェット
class BadgeCelebrationWidget extends StatefulWidget {
  final List<UserBadge> newBadges;
  final ThemeSettings themeSettings;
  final VoidCallback onComplete;

  const BadgeCelebrationWidget({
    super.key,
    required this.newBadges,
    required this.themeSettings,
    required this.onComplete,
  });

  @override
  State<BadgeCelebrationWidget> createState() => _BadgeCelebrationWidgetState();
}

class _BadgeCelebrationWidgetState extends State<BadgeCelebrationWidget>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _confettiController;
  late AnimationController _badgeController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotationAnimation;

  List<ConfettiParticle> _confettiParticles = [];
  final int _particleCount = 50;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      duration: Duration(milliseconds: 3000),
      vsync: this,
    );

    _confettiController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );

    _badgeController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _badgeController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 2.0).animate(
      CurvedAnimation(parent: _badgeController, curve: Curves.easeInOut),
    );

    _initializeConfetti();
    _startAnimations();
  }

  void _initializeConfetti() {
    final random = math.Random();
    _confettiParticles = List.generate(_particleCount, (index) {
      return ConfettiParticle(
        x: random.nextDouble(),
        y: -0.1,
        velocityX: (random.nextDouble() - 0.5) * 2,
        velocityY: random.nextDouble() * 2 + 1,
        color: _getRandomColor(),
        size: random.nextDouble() * 8 + 4,
        rotation: random.nextDouble() * 2 * math.pi,
        rotationSpeed: (random.nextDouble() - 0.5) * 0.2,
      );
    });
  }

  Color _getRandomColor() {
    final colors = [
      Colors.amber,
      Colors.orange,
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.blue,
      Colors.green,
      Colors.yellow,
    ];
    return colors[math.Random().nextInt(colors.length)];
  }

  void _startAnimations() {
    _mainController.forward();

    Future.delayed(Duration(milliseconds: 500), () {
      _badgeController.forward();
    });

    Future.delayed(Duration(milliseconds: 800), () {
      _confettiController.forward();
    });

    Future.delayed(Duration(milliseconds: 3500), () {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _confettiController.dispose();
    _badgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.8),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            // 背景のグラデーション
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [Colors.amber.withOpacity(0.3), Colors.transparent],
                  center: Alignment.center,
                  radius: 1.0,
                ),
              ),
            ),

            // コンフェッティ
            AnimatedBuilder(
              animation: _confettiController,
              builder: (context, child) {
                return CustomPaint(
                  painter: ConfettiPainter(
                    particles: _confettiParticles,
                    progress: _confettiController.value,
                  ),
                  size: Size.infinite,
                );
              },
            ),

            // メインコンテンツ
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // タイトル
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.amber, Colors.orange],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.celebration,
                            color: Colors.white,
                            size: 32,
                          ),
                          SizedBox(width: 12),
                          Text(
                            '新しい称号獲得！',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24 * widget.themeSettings.fontSizeScale,
                              fontWeight: FontWeight.bold,
                              fontFamily: widget.themeSettings.fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 40),

                  // バッジ表示
                  ...widget.newBadges.map((badge) => _buildBadgeDisplay(badge)),

                  SizedBox(height: 40),

                  // 閉じるボタン
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: ElevatedButton.icon(
                      onPressed: widget.onComplete,
                      icon: Icon(Icons.emoji_events, color: Colors.white),
                      label: Text(
                        'おめでとうございます！',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16 * widget.themeSettings.fontSizeScale,
                          fontWeight: FontWeight.bold,
                          fontFamily: widget.themeSettings.fontFamily,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown.shade600,
                        foregroundColor: Colors.white,
                        elevation: 8,
                        padding: EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeDisplay(UserBadge badge) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: RotationTransition(
          turns: _rotationAnimation,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: badge.color.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // バッジアイコン
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [badge.color.withOpacity(0.8), badge.color],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: badge.color.withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Icon(badge.icon, color: Colors.white, size: 40),
                ),

                SizedBox(width: 20),

                // バッジ情報
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge.name,
                      style: TextStyle(
                        color: widget.themeSettings.fontColor1,
                        fontSize: 20 * widget.themeSettings.fontSizeScale,
                        fontWeight: FontWeight.bold,
                        fontFamily: widget.themeSettings.fontFamily,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      badge.description,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14 * widget.themeSettings.fontSizeScale,
                        fontFamily: widget.themeSettings.fontFamily,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// コンフェッティパーティクル
class ConfettiParticle {
  double x;
  double y;
  double velocityX;
  double velocityY;
  Color color;
  double size;
  double rotation;
  double rotationSpeed;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.velocityX,
    required this.velocityY,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
  });

  void update(double deltaTime) {
    x += velocityX * deltaTime;
    y += velocityY * deltaTime;
    rotation += rotationSpeed * deltaTime;
    velocityY += 0.5 * deltaTime; // 重力
  }
}

/// コンフェッティペインター
class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  final double progress;

  ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      // プログレスに基づいてパーティクルを更新
      final updatedParticle = ConfettiParticle(
        x: particle.x + particle.velocityX * progress,
        y: particle.y + particle.velocityY * progress,
        velocityX: particle.velocityX,
        velocityY: particle.velocityY + 0.5 * progress, // 重力効果
        color: particle.color,
        size: particle.size,
        rotation: particle.rotation + particle.rotationSpeed * progress,
        rotationSpeed: particle.rotationSpeed,
      );

      // 画面外のパーティクルはスキップ
      if (updatedParticle.y > 1.2) continue;

      final paint = Paint()
        ..color = updatedParticle.color.withOpacity(1.0 - progress * 0.5)
        ..style = PaintingStyle.fill;

      final center = Offset(
        updatedParticle.x * size.width,
        updatedParticle.y * size.height,
      );

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(updatedParticle.rotation);

      // 星型のパーティクル
      _drawStar(canvas, paint, updatedParticle.size);

      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, Paint paint, double size) {
    final path = Path();
    final points = 5;
    final angle = 2 * math.pi / points;
    final radius = size / 2;
    final innerRadius = radius * 0.4;

    for (int i = 0; i < points * 2; i++) {
      final currentAngle = i * angle / 2;
      final currentRadius = i.isEven ? radius : innerRadius;
      final x = math.cos(currentAngle) * currentRadius;
      final y = math.sin(currentAngle) * currentRadius;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
