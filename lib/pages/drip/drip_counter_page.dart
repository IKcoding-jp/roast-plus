import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:bysnapp/pages/drip/DripPackRecordListPage.dart';
import '../../services/drip_counter_firestore_service.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';

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
  }

  @override
  void dispose() {
    _beanController.dispose();
    super.dispose();
  }

  // カウンター更新時
  void _addToCounter(int value) {
    setState(() {
      _counter = (_counter + value).clamp(0, 9999);
      _counterColor = Colors.orange.shade700; // 例: 変化色
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 共通の枠デザイン
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    final cardElevation = 6.0;
    final cardColor =
        Provider.of<ThemeSettings>(context).backgroundColor2 ?? Colors.white;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('ドリップパックカウンター'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.history),
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
                    child: Card(
                      shape: cardShape,
                      elevation: cardElevation,
                      color: cardColor,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
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
                                  color: Provider.of<ThemeSettings>(
                                    context,
                                  ).fontColor1,
                                  letterSpacing: 2,
                                  fontFamily: 'Arial',
                                  shadows: [
                                    Shadow(
                                      color: Colors.white,
                                      blurRadius: 4,
                                      offset: Offset(1, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '袋',
                            style: TextStyle(
                              fontSize: 22,
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).fontColor1,
                              fontWeight: FontWeight.bold,
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
                    child: Card(
                      shape: cardShape,
                      elevation: cardElevation,
                      color: cardColor,
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
                    child: Card(
                      shape: cardShape,
                      elevation: cardElevation,
                      color: cardColor,
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
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 8,
                                ),
                                onPressed: _addRecord,
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

  Widget _buildCountButton(int value, {double fontSize = 22}) {
    return ElevatedButton(
      onPressed: () => _addToCounter(value),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            Theme.of(
              context,
            ).elevatedButtonTheme.style?.backgroundColor?.resolve({}) ??
            Theme.of(context).colorScheme.primary,
        foregroundColor:
            Theme.of(
              context,
            ).elevatedButtonTheme.style?.foregroundColor?.resolve({}) ??
            Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 6,
        padding: EdgeInsets.zero,
        textStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      child: Text(value > 0 ? '+$value' : '$value'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: Provider.of<ThemeSettings>(context).iconColor,
              size: iconSize,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: labelFontSize,
                color: Provider.of<ThemeSettings>(context).fontColor1,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: Provider.of<ThemeSettings>(context).inputBackgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: contentPadding,
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey, fontSize: fontSize),
          ),
          style: TextStyle(
            fontSize: fontSize,
            color: Provider.of<ThemeSettings>(context).fontColor1,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.local_fire_department,
              color: Provider.of<ThemeSettings>(context).iconColor,
              size: iconSize,
            ),
            const SizedBox(width: 6),
            Text(
              '煎り度',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: labelFontSize,
                color: Provider.of<ThemeSettings>(context).fontColor1,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedRoast,
          items: _roastLevels
              .map(
                (level) => DropdownMenuItem(
                  value: level,
                  child: Text(
                    level,
                    style: TextStyle(
                      fontSize: fontSize,
                      color: Provider.of<ThemeSettings>(context).fontColor1,
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
            fillColor: Provider.of<ThemeSettings>(context).inputBackgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: contentPadding,
            hintText: '煎り度を選択',
            hintStyle: TextStyle(
              color: Provider.of<ThemeSettings>(context).fontColor1,
              fontSize: fontSize,
            ),
          ),
          style: TextStyle(
            fontSize: fontSize,
            color: Provider.of<ThemeSettings>(context).fontColor1,
          ),
          dropdownColor: Provider.of<ThemeSettings>(context).backgroundColor2,
          icon: Icon(
            Icons.arrow_drop_down,
            color: Provider.of<ThemeSettings>(context).iconColor,
          ),
          selectedItemBuilder: (BuildContext context) {
            return _roastLevels.map<Widget>((String item) {
              return Text(
                item,
                style: TextStyle(
                  fontSize: fontSize,
                  color: Provider.of<ThemeSettings>(context).fontColor1,
                ),
              );
            }).toList();
          },
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
    setState(() {
      _counter = 0;
      _selectedRoast = null;
    });
    _beanController.clear();
  }
}
