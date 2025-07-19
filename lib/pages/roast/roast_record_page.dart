import 'package:flutter/material.dart';
import 'package:bysnapp/models/roast_record.dart';
import 'package:bysnapp/services/roast_record_firestore_service.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../models/group_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../services/experience_manager.dart';
import '../../models/gamification_provider.dart';
import '../../widgets/lottie_animation_widget.dart';
import '../../models/dashboard_stats_provider.dart';

class RoastRecordPage extends StatefulWidget {
  const RoastRecordPage({super.key});

  @override
  State<RoastRecordPage> createState() => _RoastRecordPageState();
}

class _RoastRecordPageState extends State<RoastRecordPage> {
  // A台入力欄
  final _beanAController = TextEditingController();
  final _weightAController = TextEditingController();
  final _minuteAController = TextEditingController();
  final _secondAController = TextEditingController();
  String? _roastLevelA;

  // B台入力欄
  final _beanBController = TextEditingController();
  final _weightBController = TextEditingController();
  final _minuteBController = TextEditingController();
  final _secondBController = TextEditingController();
  String? _roastLevelB;

  List<RoastRecord> _records = [];
  StreamSubscription? _roastRecordsSubscription;
  void _startRoastRecordsListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _roastRecordsSubscription?.cancel();
    _roastRecordsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('roastRecords')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
          _records = snapshot.docs.map((doc) {
            final data = doc.data();
            return RoastRecord(
              id: doc.id,
              bean: data['bean'] ?? '',
              weight: data['weight'] ?? 0,
              roast: data['roast'] ?? '',
              time: data['time'] ?? '',
              memo: data['memo'] ?? '',
              timestamp: (data['timestamp'] as Timestamp).toDate(),
            );
          }).toList();
          setState(() {});
        });
  }

  @override
  void initState() {
    super.initState();
    _loadRoastRecordsFromFirestore();
    _startRoastRecordsListener();
  }

  Future<void> _loadRoastRecordsFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('roastRecords')
        .orderBy('timestamp', descending: true)
        .get();
    _records = snapshot.docs.map((doc) {
      final data = doc.data();
      return RoastRecord(
        id: doc.id,
        bean: data['bean'] ?? '',
        weight: data['weight'] ?? 0,
        roast: data['roast'] ?? '',
        time: data['time'] ?? '',
        memo: data['memo'] ?? '',
        timestamp: (data['timestamp'] as Timestamp).toDate(),
      );
    }).toList();
    setState(() {});
  }

  Widget _buildRoastForm({
    required String title,
    required TextEditingController beanController,
    required TextEditingController weightController,
    required TextEditingController minController,
    required TextEditingController secController,
    required String? roastLevel,
    required Function(String?) onRoastLevelChanged,
  }) {
    final isA = title.contains('A台');
    final cardColor =
        Provider.of<ThemeSettings>(context).backgroundColor2 ?? Colors.white;
    final accentColor = Provider.of<ThemeSettings>(context).fontColor1;
    final iconColor = Provider.of<ThemeSettings>(context).iconColor;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // タイトル部分
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.coffee_maker, color: iconColor, size: 24),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 18),

            // 1. 豆の種類
            _buildInputField(
              controller: beanController,
              label: '豆の種類',
              hint: '例：ブラジル、コロンビア',
              icon: Icons.coffee,
              iconColor: iconColor,
            ),
            SizedBox(height: 14),

            // 2. 重さ
            _buildWeightDropdown(
              controller: weightController,
              iconColor: iconColor,
            ),
            SizedBox(height: 14),

            // 3. 煎り度
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.local_fire_department,
                    color: iconColor,
                    size: 20,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '煎り度',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonFormField<String>(
                value: roastLevel,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  hintText: '煎り度を選択',
                ),
                items: ['浅煎り', '中煎り', '中深煎り', '深煎り']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: onRoastLevelChanged,
              ),
            ),
            SizedBox(height: 14),

            // 4. 焙煎時間
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.timer, color: iconColor, size: 20),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '焙煎時間',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _buildTimeInputField(
                    controller: minController,
                    label: '分',
                    iconColor: iconColor,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  ':',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildTimeInputField(
                    controller: secController,
                    label: '秒',
                    iconColor: iconColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
    TextInputType? keyboardType,
  }) {
    final accentColor = Provider.of<ThemeSettings>(context).fontColor1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              hintText: hint,
              hintStyle: TextStyle(color: accentColor.withOpacity(0.6)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeInputField({
    required TextEditingController controller,
    required String label,
    required Color iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(
          decimal: false,
          signed: false,
        ),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          hintText: label,
          hintStyle: TextStyle(color: Colors.grey[400]),
        ),
      ),
    );
  }

  Widget _buildWeightDropdown({
    required TextEditingController controller,
    required Color iconColor,
  }) {
    final accentColor = Provider.of<ThemeSettings>(context).fontColor1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.scale, color: iconColor, size: 20),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '重さ（g）',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonFormField<String>(
            value: controller.text.isEmpty ? null : controller.text,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              hintText: '重さを選択',
              hintStyle: TextStyle(color: accentColor.withOpacity(0.6)),
            ),
            items: [
              '200',
              '300',
              '500',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (value) {
              if (value != null) {
                controller.text = value;
              }
            },
          ),
        ),
      ],
    );
  }

  void _saveBothRoasts() async {
    final now = DateTime.now();
    List<RoastRecord> newRecords = [];

    if (_beanAController.text.isNotEmpty &&
        _weightAController.text.isNotEmpty &&
        _roastLevelA != null) {
      final aRecord = RoastRecord(
        id: '', // Firestoreで自動生成
        bean: _beanAController.text.trim(),
        weight: int.tryParse(_weightAController.text.trim()) ?? 0,
        roast: _roastLevelA!,
        time:
            '${_minuteAController.text.padLeft(2, '0')}:${_secondAController.text.padLeft(2, '0')}',
        memo: '',
        timestamp: now,
      );
      newRecords.add(aRecord);
    }
    if (_beanBController.text.isNotEmpty &&
        _weightBController.text.isNotEmpty &&
        _roastLevelB != null) {
      final bRecord = RoastRecord(
        id: '', // Firestoreで自動生成
        bean: _beanBController.text.trim(),
        weight: int.tryParse(_weightBController.text.trim()) ?? 0,
        roast: _roastLevelB!,
        time:
            '${_minuteBController.text.padLeft(2, '0')}:${_secondBController.text.padLeft(2, '0')}',
        memo: '',
        timestamp: now,
      );
      newRecords.add(bRecord);
    }
    if (newRecords.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('どちらかの記録を入力してください')));
      }
      return;
    }

    try {
      if (!mounted) return;

      final groupProvider = context.read<GroupProvider>();

      for (final record in newRecords) {
        if (!mounted) return;

        if (groupProvider.hasGroup) {
          // グループに参加している場合はグループに記録を追加
          await RoastRecordFirestoreService.addGroupRecord(
            groupProvider.currentGroup!.id,
            record,
          );
        } else {
          // グループに参加していない場合は個人の記録を追加
          await RoastRecordFirestoreService.addRecord(record);
        }

        // 焙煎記録からXPを加算
        await _addRoastingExperience(record);
      }

      // 統計データを更新
      if (mounted) {
        final statsProvider = Provider.of<DashboardStatsProvider>(
          context,
          listen: false,
        );
        await statsProvider.onRoastRecordAdded();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${newRecords.length}件の記録を保存しました')),
        );
      }

      _beanAController.clear();
      _weightAController.clear();
      _minuteAController.clear();
      _secondAController.clear();
      _roastLevelA = null;

      _beanBController.clear();
      _weightBController.clear();
      _minuteBController.clear();
      _secondBController.clear();
      _roastLevelB = null;

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      }
    }
  }

  /// 焙煎記録からXPを加算
  Future<void> _addRoastingExperience(RoastRecord record) async {
    try {
      // 焙煎時間を分に変換
      final timeParts = record.time.split(':');
      if (timeParts.length != 2) return;

      final minutes = int.tryParse(timeParts[0]) ?? 0;
      final seconds = int.tryParse(timeParts[1]) ?? 0;
      final totalMinutes = minutes + (seconds / 60.0);

      if (totalMinutes <= 0) return;

      // ExperienceManagerでXPを加算
      final result = await ExperienceManager.instance.addRoastingExperience(
        roastTimeMinutes: totalMinutes,
        beanName: record.bean,
        roastDate: record.timestamp,
      );

      if (mounted && result.success) {
        // GamificationProviderに通知
        final gamificationProvider = context.read<GamificationProvider>();
        gamificationProvider.refreshFromExperienceManager();

        // 成果表示
        _showExperienceGainResult(result);
      }
    } catch (e) {
      debugPrint('焙煎XP加算エラー: $e');
    }
  }

  /// XP獲得結果を表示（Lottieアニメーション付き）
  void _showExperienceGainResult(ExperienceGainResult result) {
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
        description: result.description,
        onComplete: () {
          // アニメーション完了後の処理
          if (mounted) {
            // 必要に応じて追加の処理
          }
        },
      );
    }
  }

  @override
  void dispose() {
    // コントローラーを適切に破棄
    _beanAController.dispose();
    _weightAController.dispose();
    _minuteAController.dispose();
    _secondAController.dispose();
    _beanBController.dispose();
    _weightBController.dispose();
    _minuteBController.dispose();
    _secondBController.dispose();
    _roastRecordsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.edit_note,
              color: Provider.of<ThemeSettings>(context).iconColor,
            ),
            SizedBox(width: 8),
            Text('焙煎記録入力'),
          ],
        ),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // A台の記録
              _buildRoastForm(
                title: 'A台の記録',
                beanController: _beanAController,
                weightController: _weightAController,
                minController: _minuteAController,
                secController: _secondAController,
                roastLevel: _roastLevelA,
                onRoastLevelChanged: (val) {
                  if (val != null) setState(() => _roastLevelA = val);
                },
              ),
              SizedBox(height: 20),

              // B台の記録
              _buildRoastForm(
                title: 'B台の記録',
                beanController: _beanBController,
                weightController: _weightBController,
                minController: _minuteBController,
                secController: _secondBController,
                roastLevel: _roastLevelB,
                onRoastLevelChanged: (val) {
                  if (val != null) setState(() => _roastLevelB = val);
                },
              ),
              SizedBox(height: 32),

              // 保存ボタン
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveBothRoasts,
                  icon: Icon(Icons.save, size: 20),
                  label: Text(
                    '記録を保存',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context)
                            .elevatedButtonTheme
                            .style
                            ?.backgroundColor
                            ?.resolve({}) ??
                        Theme.of(context).colorScheme.primary,
                    foregroundColor:
                        Theme.of(context)
                            .elevatedButtonTheme
                            .style
                            ?.foregroundColor
                            ?.resolve({}) ??
                        Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
