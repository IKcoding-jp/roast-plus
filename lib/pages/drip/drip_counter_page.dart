import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:bysnapp/pages/drip/DripPackRecordListPage.dart';
import '../../services/drip_counter_firestore_service.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../models/gamification_provider.dart';
import '../../services/experience_manager.dart';
import '../../widgets/lottie_animation_widget.dart';
import '../../models/dashboard_stats_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class DripCounterPage extends StatefulWidget {
  const DripCounterPage({super.key});

  @override
  State<DripCounterPage> createState() => DripCounterPageState();
}

class DripCounterPageState extends State<DripCounterPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _beanController = TextEditingController();
  int _counter = 0;
  final List<String> _roastLevels = ['浅煎り', '中煎り', '中深煎り', '深煎り'];
  String? _selectedRoast;
  // Stateに追加
  Color _counterColor = Colors.black;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  // Firestore同期用 記録リスト
  List<Map<String, dynamic>> _records = [];
  void setDripRecordsFromFirestore(List<Map<String, dynamic>> records) {
    setState(() {
      _records = List<Map<String, dynamic>>.from(records);
    });
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _colorAnimation =
        ColorTween(
          begin: Colors.orange.shade700,
          end: Colors.orange.shade300,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );
    _loadDripRecordsFromFirestore();
    _startDripRecordsListener();
  }

  Future<void> _loadDripRecordsFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final today = DateTime.now();
    final docId =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('dripPackRecords')
        .doc(docId)
        .get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      if (data['records'] != null) {
        if (!mounted) return;
        setState(() {
          _records = List<Map<String, dynamic>>.from(data['records']);
        });
      }
    }
  }

  StreamSubscription? _dripRecordsSubscription;
  void _startDripRecordsListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final today = DateTime.now();
    final docId =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    _dripRecordsSubscription?.cancel();
    _dripRecordsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('dripPackRecords')
        .doc(docId)
        .snapshots()
        .listen((doc) {
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            if (data['records'] != null) {
              if (!mounted) return;
              setState(() {
                _records = List<Map<String, dynamic>>.from(data['records']);
              });
            }
          }
        });
  }

  @override
  void dispose() {
    _beanController.dispose();
    _animationController.dispose();
    _dripRecordsSubscription?.cancel();
    super.dispose();
  }

  // カウンター更新時
  void _addToCounter(int value) {
    setState(() {
      _counter = (_counter + value).clamp(0, 9999);
      _counterColor = Colors.orange.shade700;
    });
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeSettings = Provider.of<ThemeSettings>(context);

    // 美しいグラデーションカラーパレット
    final primaryGradient = LinearGradient(
      colors: [
        themeSettings.buttonColor,
        themeSettings.buttonColor.withOpacity(0.8),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final cardGradient = LinearGradient(
      colors: [
        themeSettings.backgroundColor2 ?? Colors.white,
        (themeSettings.backgroundColor2 ?? Colors.white).withOpacity(0.95),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    // 共通の枠デザイン
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    );
    final cardElevation = 8.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'ドリップパックカウンター',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1.2),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.list, color: themeSettings.iconColor),
            tooltip: '記録一覧',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DripPackRecordListPage()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double sectionHeight = (constraints.maxHeight - 32) / 3;
            final double buttonFont = 28;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  // 1. カウンター枠
                  SizedBox(
                    height: sectionHeight,
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: cardGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.8),
                            blurRadius: 1,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // 背景装飾
                          Positioned(
                            top: -20,
                            right: -20,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    themeSettings.buttonColor.withOpacity(0.1),
                                    Colors.transparent,
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          // カウンター数字
                          Center(
                            child: AnimatedBuilder(
                              animation: _scaleAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _scaleAnimation.value,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '$_counter',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 120,
                                          fontWeight: FontWeight.w900,
                                          foreground: Paint()
                                            ..shader =
                                                LinearGradient(
                                                  colors: [
                                                    themeSettings.fontColor1,
                                                    themeSettings.fontColor1
                                                        .withOpacity(0.8),
                                                  ],
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                ).createShader(
                                                  Rect.fromLTWH(0, 0, 200, 120),
                                                ),
                                          letterSpacing: 2,
                                          fontFamily: 'Arial',
                                          shadows: [
                                            Shadow(
                                              color: Colors.black.withOpacity(
                                                0.1,
                                              ),
                                              blurRadius: 8,
                                              offset: Offset(2, 2),
                                            ),
                                            Shadow(
                                              color: Colors.white.withOpacity(
                                                0.8,
                                              ),
                                              blurRadius: 2,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          // リセットボタン（右上）
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    themeSettings.iconColor.withOpacity(0.1),
                                    themeSettings.iconColor.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: themeSettings.iconColor.withOpacity(
                                    0.2,
                                  ),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.refresh,
                                  color: themeSettings.iconColor,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _counter = 0;
                                  });
                                },
                                tooltip: 'カウンターをリセット',
                                padding: EdgeInsets.all(8),
                                constraints: BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 2. ボタン枠
                  SizedBox(
                    height: sectionHeight,
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: cardGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.8),
                            blurRadius: 1,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (final v in [-10, -5, -1, 1, 5, 10])
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: SizedBox(
                                    height: sectionHeight * 0.7,
                                    child: _buildCountButton(
                                      v,
                                      fontSize: buttonFont,
                                      primaryGradient: primaryGradient,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 3. 入力フォーム枠
                  SizedBox(
                    height: sectionHeight,
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: cardGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.8),
                            blurRadius: 1,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: _buildInputField(
                                    label: '豆の種類',
                                    controller: _beanController,
                                    icon: Icons.coffee,
                                    hint: '例: グアテマラ',
                                    fontSize: 17,
                                    iconSize: 22,
                                    labelFontSize: 16,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _buildRoastDropdown(
                                    fontSize: 17,
                                    iconSize: 22,
                                    labelFontSize: 16,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: primaryGradient,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: themeSettings.buttonColor
                                          .withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.save, size: 22),
                                  label: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      '記録を保存',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: _addRecord,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCountButton(
    int value, {
    double fontSize = 22,
    LinearGradient? primaryGradient,
  }) {
    final themeSettings = Provider.of<ThemeSettings>(context);
    final isPositive = value > 0;

    return Container(
      decoration: BoxDecoration(
        gradient:
            primaryGradient ??
            LinearGradient(
              colors: [
                themeSettings.buttonColor,
                themeSettings.buttonColor.withOpacity(0.8),
              ],
            ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: themeSettings.buttonColor.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 1,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _addToCounter(value),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            alignment: Alignment.center,
            child: Text(
              isPositive ? '+$value' : '$value',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 2,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    double fontSize = 17,
    double iconSize = 22,
    double labelFontSize = 16,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 10,
    ),
  }) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    themeSettings.iconColor.withOpacity(0.1),
                    themeSettings.iconColor.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: themeSettings.iconColor, size: iconSize),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: labelFontSize,
                color: themeSettings.fontColor1,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: themeSettings.inputBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.transparent,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: contentPadding,
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey.shade500,
                fontSize: fontSize,
              ),
            ),
            style: TextStyle(
              fontSize: fontSize,
              color: themeSettings.fontColor1,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoastDropdown({
    double fontSize = 17,
    double iconSize = 22,
    double labelFontSize = 16,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 10,
    ),
  }) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    themeSettings.iconColor.withOpacity(0.1),
                    themeSettings.iconColor.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.local_fire_department,
                color: themeSettings.iconColor,
                size: iconSize,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '煎り度',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: labelFontSize,
                color: themeSettings.fontColor1,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: themeSettings.inputBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedRoast,
            items: _roastLevels
                .map(
                  (level) => DropdownMenuItem(
                    value: level,
                    child: Text(
                      level,
                      style: TextStyle(
                        fontSize: fontSize,
                        color: themeSettings.fontColor1,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) {
              setState(() {
                _selectedRoast = val;
              });
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.transparent,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: contentPadding,
              hintText: '煎り度を選択',
              hintStyle: TextStyle(
                color: Colors.grey.shade500,
                fontSize: fontSize,
              ),
            ),
            style: TextStyle(
              fontSize: fontSize,
              color: themeSettings.fontColor1,
              fontWeight: FontWeight.w500,
            ),
            dropdownColor: themeSettings.backgroundColor2,
            icon: Icon(Icons.arrow_drop_down, color: themeSettings.iconColor),
            selectedItemBuilder: (BuildContext context) {
              return _roastLevels.map<Widget>((String item) {
                return Text(
                  item,
                  style: TextStyle(
                    fontSize: fontSize,
                    color: themeSettings.fontColor1,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ],
    );
  }

  Future<void> _addRecord() async {
    final bean = _beanController.text.trim();
    final roast = _selectedRoast;
    final count = _counter;
    if (bean.isEmpty || roast == null || roast.isEmpty || count <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('dripPackRecords');
    List<Map<String, dynamic>> records = [];
    if (saved != null) {
      records = List<Map<String, dynamic>>.from(json.decode(saved));
    }
    final now = DateTime.now();
    records.insert(0, {
      'bean': bean,
      'roast': roast,
      'count': count,
      'timestamp': now.toIso8601String(),
    });
    await prefs.setString('dripPackRecords', json.encode(records));
    // Firestoreにも保存
    try {
      await DripCounterFirestoreService.addDripPackRecord(
        bean: bean,
        roast: roast,
        count: count,
        timestamp: now,
      );
    } catch (_) {}

    // ドリップパック作成の経験値を追加
    await _addDripPackExperience(count, bean, now);

    // 統計データを更新
    if (mounted) {
      final statsProvider = Provider.of<DashboardStatsProvider>(
        context,
        listen: false,
      );
      await statsProvider.onDripPackAdded();
    }

    // UIをリセット
    setState(() {
      _beanController.clear();
      _selectedRoast = null;
      _counter = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$count袋の記録を保存しました'),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// ドリップパック作成からXPを加算
  Future<void> _addDripPackExperience(
    int count,
    String bean,
    DateTime createDate,
  ) async {
    try {
      // ExperienceManagerでXPを加算
      final result = await ExperienceManager.instance.addDripPackExperience(
        packCount: count,
        createDate: createDate,
      );

      if (mounted && result.success) {
        // GamificationProviderに通知
        final gamificationProvider = context.read<GamificationProvider>();
        gamificationProvider.refreshFromExperienceManager();

        // 成果表示
        _showDripPackExperienceResult(result, count, bean);
      }
    } catch (e) {
      print('ドリップパックXP加算エラー: $e');
    }
  }

  /// ドリップパックXP獲得結果を表示（Lottieアニメーション付き）
  void _showDripPackExperienceResult(
    ExperienceGainResult result,
    int count,
    String bean,
  ) {
    if (!mounted) return;

    // 少し遅延させてからアニメーションを表示（記録保存のSnackBarの後）
    Future.delayed(Duration(milliseconds: 800), () {
      if (!mounted) return;

      // レベルアップした場合はレベルアップアニメーションを優先
      if (result.leveledUp) {
        final badgeNames = result.newBadges.map((b) => b.name).toList();

        AnimationHelper.showLevelUpAnimation(
          context,
          oldLevel: result.oldProfile.level,
          newLevel: result.newLevel,
          newBadges: badgeNames,
          onComplete: () {
            // アニメーション完了後の処理
            if (mounted) {
              // 状態更新は既にExperienceManager内で完了している
            }
          },
        );
      } else if (result.xpGained > 0) {
        // 経験値獲得アニメーションを表示
        AnimationHelper.showExperienceGainAnimation(
          context,
          xpGained: result.xpGained,
          description: '$bean $count袋作成',
          onComplete: () {
            // アニメーション完了後の処理
            if (mounted) {
              // 必要に応じて追加の処理
            }
          },
        );
      }
    });
  }
}
