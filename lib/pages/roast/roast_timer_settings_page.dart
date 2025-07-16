import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/roast_timer_settings_firestore_service.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../models/group_provider.dart';

class RoastTimerSettingsPage extends StatefulWidget {
  const RoastTimerSettingsPage({super.key});

  @override
  State<RoastTimerSettingsPage> createState() => RoastTimerSettingsPageState();
}

class RoastTimerSettingsPageState extends State<RoastTimerSettingsPage> {
  final TextEditingController _preheatController = TextEditingController();
  int _preheatMinutes = 30;
  final TextEditingController _coolingController = TextEditingController();
  int _coolingMinutes = 10;
  bool _loading = true;
  bool _usePreheat = true;
  bool _useCooling = true;
  bool _useRoast = true;

  // Firestore同期用setter
  void setPreheatMinutesFromFirestore(int minutes) {
    setState(() {
      _preheatMinutes = minutes;
      _preheatController.text = minutes.toString();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadPreheat();
    _loadCooling();
    _loadSwitches();
  }

  Future<void> _loadPreheat() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _preheatMinutes = prefs.getInt('preheatMinutes') ?? 30;
      _preheatController.text = _preheatMinutes.toString();
      _loading = false;
    });
  }

  Future<void> _loadCooling() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _coolingMinutes = prefs.getInt('coolingMinutes') ?? 10;
      _coolingController.text = _coolingMinutes.toString();
    });
  }

  Future<void> _loadSwitches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _usePreheat = prefs.getBool('usePreheat') ?? true;
      _useCooling = prefs.getBool('useCooling') ?? true;
      _useRoast = prefs.getBool('useRoast') ?? true;
    });
  }

  Future<void> _saveAllToFirestore() async {
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    if (groupProvider.groups.isEmpty) {
      try {
        await RoastTimerSettingsFirestoreService.saveRoastTimerSettings(
          preheatMinutes: _preheatMinutes,
          coolingMinutes: _coolingMinutes,
          usePreheat: _usePreheat,
          useCooling: _useCooling,
          useRoast: _useRoast,
        );
      } catch (_) {}
    }
  }

  Future<void> _saveUsePreheat(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('usePreheat', value);
    _usePreheat = value; // 先に値を更新
    setState(() {});
    await _saveAllToFirestore();
  }

  Future<void> _saveUseCooling(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useCooling', value);
    _useCooling = value; // 先に値を更新
    setState(() {});
    await _saveAllToFirestore();
  }

  Future<void> _saveUseRoast(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useRoast', value);
    _useRoast = value; // 先に値を更新
    setState(() {});
    await _saveAllToFirestore();
  }

  Future<void> _savePreheat() async {
    final prefs = await SharedPreferences.getInstance();
    final value = int.tryParse(_preheatController.text) ?? 30;
    await prefs.setInt('preheatMinutes', value);
    _preheatMinutes = value; // 先に値を更新
    setState(() {});
    await _saveAllToFirestore();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('予熱時間を$value分に保存しました')));
  }

  Future<void> _saveCooling() async {
    final prefs = await SharedPreferences.getInstance();
    final value = int.tryParse(_coolingController.text) ?? 10;
    await prefs.setInt('coolingMinutes', value);
    _coolingMinutes = value; // 先に値を更新
    setState(() {});
    await _saveAllToFirestore();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('豆冷ましタイマーを$value分に保存しました')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('予熱タイマー設定')),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: SingleChildScrollView(
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color:
                        Provider.of<ThemeSettings>(context).backgroundColor2 ??
                        Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // オンオフスイッチを上にまとめる
                          Row(
                            children: [
                              Switch(
                                value: _usePreheat,
                                onChanged: (v) => _saveUsePreheat(v),
                              ),
                              SizedBox(width: 10),
                              Text(
                                '予熱タイマーを使う',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF795548),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              Switch(
                                value: _useRoast,
                                onChanged: (v) => _saveUseRoast(v),
                              ),
                              SizedBox(width: 10),
                              Text(
                                '焙煎タイマーを使う',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF795548),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              Switch(
                                value: _useCooling,
                                onChanged: (v) => _saveUseCooling(v),
                              ),
                              SizedBox(width: 10),
                              Text(
                                '豆冷ましタイマーを使う',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF795548),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 32),
                          // 時間設定欄を下にまとめる
                          Row(
                            children: [
                              Icon(
                                Icons.timer,
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).iconColor, // テーマのアイコン色を適用
                                size: 24,
                              ),
                              SizedBox(width: 10),
                              Text(
                                '予熱時間（分）',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Color(0xFF795548),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 18),
                          Row(
                            children: [
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: _preheatController,
                                  keyboardType: TextInputType.numberWithOptions(
                                    decimal: false,
                                    signed: false,
                                  ),
                                  style: TextStyle(fontSize: 16),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: Color(0xFF795548),
                                        width: 2,
                                      ),
                                    ),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: _savePreheat,
                                icon: Icon(Icons.save, size: 20),
                                label: Text(
                                  '保存',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
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
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 4,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 32),
                          Row(
                            children: [
                              Icon(
                                Icons.ac_unit,
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).iconColor,
                                size: 24,
                              ),
                              SizedBox(width: 10),
                              Text(
                                '豆冷ましタイマー（分）',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Color(0xFF795548),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 18),
                          Row(
                            children: [
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: _coolingController,
                                  keyboardType: TextInputType.numberWithOptions(
                                    decimal: false,
                                    signed: false,
                                  ),
                                  style: TextStyle(fontSize: 16),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: Color(0xFF795548),
                                        width: 2,
                                      ),
                                    ),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: _saveCooling,
                                icon: Icon(Icons.save, size: 20),
                                label: Text(
                                  '保存',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
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
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 4,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
