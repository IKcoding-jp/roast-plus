import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class RoastAdvisorPage extends StatefulWidget {
  const RoastAdvisorPage({super.key});

  @override
  State<RoastAdvisorPage> createState() => _RoastAdvisorPageState();
}

class _RoastAdvisorPageState extends State<RoastAdvisorPage> {
  final TextEditingController _beanController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  String? _selectedRoast;

  String? _averageTimeDisplay;
  Duration? _recommendedTime;

  List<Map<String, dynamic>> _records = [];

  final TextEditingController _manualMinController = TextEditingController();
  final TextEditingController _manualSecController = TextEditingController();
  bool _noMatch = false;

  // 記録済み豆のリストと選択中の豆
  List<String> _beanOptions = [];
  String? _selectedBean;

  // 豆の重さリスト（例）
  final List<String> _weightList = ['50', '100', '150', '200', '250', '300'];
  String? _selectedWeight;

  // 記録から豆リストを抽出するFuture
  Future<List<String>> _getBeanList() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('roastRecords');
    if (saved != null) {
      final List<dynamic> jsonList = json.decode(saved);
      final beans = jsonList
          .map((e) => e['bean'] as String?)
          .where((bean) => bean != null && bean.isNotEmpty)
          .map((bean) => bean!)
          .toSet()
          .toList();
      return beans;
    }
    return [];
  }

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('roastRecords');
    if (saved != null) {
      final List<dynamic> jsonList = json.decode(saved);
      _records = jsonList
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
      // ここで豆リストを動的に抽出
      _beanOptions = _records
          .map((e) => e['bean'] as String?)
          .where((bean) => bean != null && bean.isNotEmpty)
          .map((bean) => bean!)
          .toSet()
          .toList();
      setState(() {});
    }
  }

  void _calculateRecommendation() {
    final bean = _selectedBean ?? '';
    final weight = _weightController.text.trim();
    final roast = _selectedRoast;

    final matched = _records.where((record) {
      final matchBean = bean.isEmpty || record['bean'] == bean;
      final matchWeight = weight.isEmpty || record['weight'] == weight;
      final matchRoast = record['roast'] == roast;
      return matchBean && matchWeight && matchRoast;
    }).toList();

    if (matched.isEmpty) {
      setState(() {
        _averageTimeDisplay = '該当する記録がありません';
        _recommendedTime = null;
        _noMatch = true; // ←これを追加！！
      });
      return;
    }

    final durations = matched.map((e) {
      final timeStr = e['time'] as String;
      final parts = timeStr.split(':');
      final minutes = int.tryParse(parts[0]) ?? 0;
      final seconds = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      return Duration(minutes: minutes, seconds: seconds);
    }).toList();

    final totalSeconds = durations.fold(0, (sum, d) => sum + d.inSeconds);
    final averageSeconds = totalSeconds ~/ durations.length;

    final avgDuration = Duration(seconds: averageSeconds);
    final recommended = avgDuration - const Duration(seconds: 60);

    setState(() {
      _averageTimeDisplay =
          '平均焙煎時間：${_formatDuration(avgDuration)}\n'
          'おすすめタイマー：${_formatDuration(recommended)}';
      _recommendedTime = recommended;
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.lightbulb, color: Color(0xFF795548)),
            SizedBox(width: 8),
            Text('おすすめ焙煎タイマー'),
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
              // 入力カード
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                color: Color(0xFFFFF8E1),
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
                              color: Color(0xFF795548),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.lightbulb,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '焙煎条件を入力',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C1D17),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),

                      // 豆の種類（プルダウン化）
                      FutureBuilder<List<String>>(
                        future: _getBeanList(),
                        builder: (context, snapshot) {
                          final beanList = snapshot.data ?? [];
                          return DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              prefixIcon: Icon(
                                Icons.coffee,
                                color: Color(0xFF795548),
                              ),
                              labelText: '豆の種類',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            value: _selectedBean,
                            items: beanList
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                _selectedBean = v;
                              });
                            },
                          );
                        },
                      ),
                      SizedBox(height: 16),
                      // 豆の重さ（プルダウン化）
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.scale,
                            color: Color(0xFF795548),
                          ),
                          labelText: '豆の重さ(g)',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        value: _selectedWeight,
                        items: _weightList
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedWeight = v;
                          });
                        },
                      ),
                      SizedBox(height: 16),

                      // 煎り度
                      _buildAdvisorRoastDropdown(),
                      SizedBox(height: 20),

                      // 計算ボタン
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _calculateRecommendation,
                          icon: Icon(Icons.calculate, size: 20),
                          label: Text(
                            'おすすめ時間を計算',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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
              SizedBox(height: 20),

              // 結果表示カード
              if (_averageTimeDisplay != null)
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: Color(0xFFFFF8E1),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Color(0xFF795548).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.timer,
                                color: Color(0xFF795548),
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '計算結果',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C1D17),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Text(
                          _averageTimeDisplay!,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 20),
                        if (_recommendedTime != null)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final minutes = _recommendedTime!.inMinutes;
                                final seconds =
                                    _recommendedTime!.inSeconds % 60;
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: Text('タイマー開始確認'),
                                    content: Text(
                                      'おすすめの ${_formatDuration(_recommendedTime!)} でタイマーを開始しますか？',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          // TODO: RoastTimerPageへの遷移はmain.dartでimportして使う
                                        },
                                        child: Text('開始'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text('キャンセル'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              icon: Icon(Icons.timer, size: 20),
                              label: Text(
                                'この時間でタイマーを開始',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
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

              SizedBox(height: 20),

              // 手動入力カード
              if (_noMatch)
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: Color(0xFFFFF8E1),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Color(0xFF795548).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.edit,
                                color: Color(0xFF795548),
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '手動入力',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C1D17),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Text('手動で焙煎時間を入力してください（分・秒）'),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildAdvisorTimeInputField(
                                controller: _manualMinController,
                                label: '分',
                                iconColor: Color(0xFF795548),
                              ),
                            ),
                            SizedBox(width: 16),
                            Text(
                              ':',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF795548),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: _buildAdvisorTimeInputField(
                                controller: _manualSecController,
                                label: '秒',
                                iconColor: Color(0xFF795548),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.timer, size: 20),
                            label: Text(
                              'この時間でタイマーを開始',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () {
                              final min =
                                  int.tryParse(_manualMinController.text) ?? 0;
                              final sec =
                                  int.tryParse(_manualSecController.text) ?? 0;
                              final manualDuration = Duration(
                                minutes: min,
                                seconds: sec,
                              );
                              if (manualDuration.inSeconds == 0) return;

                              // TODO: RoastTimerPageへの遷移はmain.dartでimportして使う
                            },
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdvisorBeanDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFF795548).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.coffee, color: Color(0xFF795548), size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '豆の種類',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF795548),
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
            border: Border.all(color: Color(0xFF795548).withOpacity(0.3)),
          ),
          child: DropdownButtonFormField<String>(
            value: _beanController.text.isEmpty ? null : _beanController.text,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              hintText: '豆の種類を選択',
            ),
            items: _beanOptions
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (value) {
              setState(() => _selectedBean = value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAdvisorWeightDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFF795548).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.scale, color: Color(0xFF795548), size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '重さ（g）',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF795548),
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
            border: Border.all(color: Color(0xFF795548).withOpacity(0.3)),
          ),
          child: DropdownButtonFormField<String>(
            value: _weightController.text.isEmpty
                ? null
                : _weightController.text,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              hintText: '重さを選択',
            ),
            items: ['200', '300', '500']
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(e.isEmpty ? '選択なし' : e),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                _weightController.text = value;
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAdvisorRoastDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFF795548).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.local_fire_department,
                color: Color(0xFF795548),
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
                  color: Color(0xFF795548),
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
            border: Border.all(color: Color(0xFF795548).withOpacity(0.3)),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedRoast,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              hintText: '煎り度を選択',
            ),
            items: [
              '浅煎り',
              '中煎り',
              '中深煎り',
              '深煎り',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedRoast = v);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAdvisorTimeInputField({
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
}
