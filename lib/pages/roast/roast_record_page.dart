import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
  String _roastLevelA = '中深煎り';

  // B台入力欄
  final _beanBController = TextEditingController();
  final _weightBController = TextEditingController();
  final _minuteBController = TextEditingController();
  final _secondBController = TextEditingController();
  String _roastLevelB = '中深煎り';

  Widget _buildRoastForm({
    required String title,
    required TextEditingController beanController,
    required TextEditingController weightController,
    required TextEditingController minController,
    required TextEditingController secController,
    required String roastLevel,
    required Function(String?) onRoastLevelChanged,
  }) {
    final isA = title.contains('A台');
    final cardColor = isA ? Color(0xFFFFF8E1) : Color(0xFFFFF8E1);
    final accentColor = isA ? Color(0xFF795548) : Color(0xFF795548);
    final iconColor = isA ? Color(0xFF795548) : Color(0xFF795548);

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isA
                        ? Icons.local_fire_department
                        : Icons.local_fire_department,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // 1. 豆の種類
            _buildInputField(
              controller: beanController,
              label: '豆の種類',
              hint: '例：ブラジル、コロンビア',
              icon: Icons.coffee,
              iconColor: iconColor,
            ),
            SizedBox(height: 16),

            // 2. 重さ
            _buildWeightDropdown(
              controller: weightController,
              iconColor: iconColor,
            ),
            SizedBox(height: 16),

            // 3. 煎り度
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.local_fire_department,
                    color: iconColor,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '煎り度',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentColor.withOpacity(0.3)),
              ),
              child: DropdownButtonFormField<String>(
                value: roastLevel,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
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
            SizedBox(height: 16),

            // 4. 焙煎時間
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.timer, color: iconColor, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '焙煎時間',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTimeInputField(
                    controller: minController,
                    label: '分',
                    iconColor: iconColor,
                  ),
                ),
                SizedBox(width: 16),
                Text(
                  ':',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildTimeInputField(
                    controller: secController,
                    label: '秒',
                    iconColor: iconColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: iconColor.withOpacity(0.3)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400]),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.scale, color: iconColor, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '重さ（g）',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: iconColor.withOpacity(0.3)),
          ),
          child: DropdownButtonFormField<String>(
            value: controller.text.isEmpty ? null : controller.text,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              hintText: '重さを選択',
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
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();
    List<Map<String, String>> newRecords = [];

    if (_beanAController.text.isNotEmpty &&
        _weightAController.text.isNotEmpty) {
      final aData = {
        'bean': _beanAController.text.trim(),
        'weight': _weightAController.text.trim(),
        'time':
            '${_minuteAController.text.padLeft(2, '0')}:${_secondAController.text.padLeft(2, '0')}',
        'roast': _roastLevelA,
        'side': 'A台',
        'timestamp': now,
      };
      newRecords.add(aData);
    }
    if (_beanBController.text.isNotEmpty &&
        _weightBController.text.isNotEmpty) {
      final bData = {
        'bean': _beanBController.text.trim(),
        'weight': _weightBController.text.trim(),
        'time':
            '${_minuteBController.text.padLeft(2, '0')}:${_secondBController.text.padLeft(2, '0')}',
        'roast': _roastLevelB,
        'side': 'B台',
        'timestamp': now,
      };
      newRecords.add(bData);
    }
    if (newRecords.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('どちらかの記録を入力してください')));
      return;
    }

    final saved = prefs.getString('roastRecords');
    List<dynamic> recordList = saved != null ? json.decode(saved) : [];
    recordList.addAll(newRecords);
    prefs.setString('roastRecords', json.encode(recordList));

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${newRecords.length}件の記録を保存しました')));

    _beanAController.clear();
    _weightAController.clear();
    _minuteAController.clear();
    _secondAController.clear();
    _roastLevelA = '中深煎り';

    _beanBController.clear();
    _weightBController.clear();
    _minuteBController.clear();
    _secondBController.clear();
    _roastLevelB = '中深煎り';

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.edit_note, color: Colors.brown[600]),
            SizedBox(width: 8),
            Text('焙煎記録入力'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF8E1), Color(0xFFFFF8E1)],
          ),
        ),
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
                    backgroundColor: Color(0xFF795548),
                    foregroundColor: Colors.white,
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
