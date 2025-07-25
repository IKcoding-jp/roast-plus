import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../models/roast_record.dart';
import '../../models/theme_settings.dart';
import '../../models/group_provider.dart';
import '../../services/roast_record_firestore_service.dart';
import '../../utils/permission_utils.dart';
import '../../widgets/permission_denied_page.dart';
import '../../models/gamification_provider.dart';

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

  StreamSubscription? _roastRecordsSubscription;
  bool _canCreateRoastRecords = true;
  bool _isCheckingPermission = true;
  StreamSubscription<bool>? _permissionSubscription;

  @override
  void initState() {
    super.initState();
    _startPermissionListener();
  }

  void _startPermissionListener() {
    final groupProvider = context.read<GroupProvider>();
    if (groupProvider.hasGroup) {
      _permissionSubscription?.cancel();
      _permissionSubscription = PermissionUtils.listenForPermissionChange(
        groupId: groupProvider.currentGroup!.id,
        dataType: 'roastRecordInput',
        onPermissionChange: (canCreate) {
          setState(() {
            _canCreateRoastRecords = canCreate;
            _isCheckingPermission = false;
          });
        },
      );
    } else {
      _permissionSubscription?.cancel();
      setState(() {
        _canCreateRoastRecords = true;
        _isCheckingPermission = false;
      });
    }
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
    final cardColor = Provider.of<ThemeSettings>(context).backgroundColor2;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('入力内容を確認してください'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.hasGroup) {
        // グループに参加している場合はグループの記録を保存
        for (final record in newRecords) {
          await RoastRecordFirestoreService.addGroupRecord(
            groupProvider.currentGroup!.id,
            record,
          );
        }

        // グループレベルシステムで経験値処理
        await _processMultipleRoastingForGroup(newRecords);
      } else {
        // グループに参加していない場合は個人の記録を保存
        for (final record in newRecords) {
          await RoastRecordFirestoreService.addRecord(record);
        }
        // 個人ゲーミフィケーション（経験値加算）
        final gamificationProvider = context.read<GamificationProvider>();
        double totalMinutes = 0;
        for (final record in newRecords) {
          final timeParts = record.time.split(':');
          if (timeParts.length == 2) {
            final minutes = int.tryParse(timeParts[0]) ?? 0;
            final seconds = int.tryParse(timeParts[1]) ?? 0;
            totalMinutes += minutes + (seconds / 60.0);
          }
        }
        if (totalMinutes > 0) {
          // recordRoastingで経験値加算
          await gamificationProvider.recordRoasting(totalMinutes);
        }
      }

      // 入力フィールドをクリア
      _clearInputFields();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('焙煎記録を保存しました'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print('焙煎記録保存エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _clearInputFields() {
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

    setState(() {});
  }

  /// グループレベルシステムで焙煎記録を処理

  /// 複数の焙煎記録をまとめて処理（グループレベルシステム）
  Future<void> _processMultipleRoastingForGroup(
    List<RoastRecord> records,
  ) async {
    try {
      // グループプロバイダーを取得
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);

      if (groupProvider.hasGroup) {
        final groupId = groupProvider.currentGroup!.id;
        List<double> minutesList = [];

        // すべての記録の焙煎時間をリストに追加
        for (final record in records) {
          final timeParts = record.time.split(':');
          if (timeParts.length == 2) {
            final minutes = int.tryParse(timeParts[0]) ?? 0;
            final seconds = int.tryParse(timeParts[1]) ?? 0;
            final totalMinutes = minutes + (seconds / 60.0);
            if (totalMinutes > 0) {
              minutesList.add(totalMinutes);
            }
          }
        }

        if (minutesList.isNotEmpty) {
          // グループのゲーミフィケーションシステムに通知（複数記録対応）
          await groupProvider.processMultipleGroupRoasting(
            groupId,
            minutesList,
            context: context,
          );
        }
      }
    } catch (e) {
      print('複数焙煎記録のグループレベルシステム処理エラー: $e');
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
    _permissionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 権限チェック中
    if (_isCheckingPermission) {
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Provider.of<ThemeSettings>(context).buttonColor,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(
                  color: Provider.of<ThemeSettings>(context).fontColor1,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 権限がない場合
    if (!_canCreateRoastRecords) {
      return PermissionDeniedPage(
        title: '焙煎記録入力',
        message: '焙煎記録を入力するには、管理者またはリーダーの権限が必要です。',
        additionalInfo:
            'メンバーが焙煎記録を入力できる設定が有効になっている場合は、管理者またはリーダーに設定の確認を依頼してください。',
        customIcon: Icons.edit_note,
      );
    }

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
      body: SafeArea(
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: [
              // スクロール可能なコンテンツ部分
              Expanded(
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
                      SizedBox(height: 20), // 保存ボタンとの間隔を調整
                    ],
                  ),
                ),
              ),

              // 保存ボタン（下部に固定）
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saveBothRoasts,
                    icon: Icon(Icons.save, size: 20),
                    label: Text(
                      '記録を保存',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
