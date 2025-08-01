import 'package:flutter/material.dart';
import '../../services/roast_timer_settings_firestore_service.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../services/user_settings_firestore_service.dart';
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
  bool _useCooling = false; // デフォルトをオフに変更
  bool _useRoast = true;
  final TextEditingController _recommendedOffsetController =
      TextEditingController();
  int _recommendedOffsetSeconds = 60;

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
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    setState(() {
      _loading = true;
    });
    await Future.wait([
      _loadPreheat(),
      _loadCooling(),
      _loadSwitches(),
      _loadRecommendedOffset(),
    ]);
    setState(() {
      _loading = false;
    });
  }

  Future<void> _loadPreheat() async {
    try {
      final value =
          await UserSettingsFirestoreService.getSetting('preheatMinutes') ?? 30;
      setState(() {
        _preheatMinutes = value;
        _preheatController.text = _preheatMinutes.toString();
      });
    } catch (e) {
      print('予熱時間読み込みエラー: $e');
      setState(() {
        _preheatMinutes = 30;
        _preheatController.text = '30';
      });
    }
  }

  Future<void> _loadCooling() async {
    try {
      final value =
          await UserSettingsFirestoreService.getSetting('coolingMinutes') ?? 10;
      setState(() {
        _coolingMinutes = value;
        _coolingController.text = _coolingMinutes.toString();
      });
    } catch (e) {
      print('豆冷まし時間読み込みエラー: $e');
      setState(() {
        _coolingMinutes = 10;
        _coolingController.text = '10';
      });
    }
  }

  Future<void> _loadSwitches() async {
    try {
      final settings = await UserSettingsFirestoreService.getMultipleSettings([
        'usePreheat',
        'useCooling',
        'useRoast',
      ]);
      setState(() {
        _usePreheat = settings['usePreheat'] ?? true;
        _useCooling = settings['useCooling'] ?? false; // デフォルトをオフに変更
        _useRoast = settings['useRoast'] ?? true;
      });
    } catch (e) {
      print('スイッチ設定読み込みエラー: $e');
      setState(() {
        _usePreheat = true;
        _useCooling = false; // デフォルトをオフに変更
        _useRoast = true;
      });
    }
  }

  Future<void> _loadRecommendedOffset() async {
    try {
      final value =
          await UserSettingsFirestoreService.getSetting(
            'recommendedRoastOffsetSeconds',
          ) ??
          60;
      setState(() {
        _recommendedOffsetSeconds = value;
        _recommendedOffsetController.text = _recommendedOffsetSeconds
            .toString();
      });
    } catch (e) {
      print('おすすめ焙煎設定読み込みエラー: $e');
      setState(() {
        _recommendedOffsetSeconds = 60;
        _recommendedOffsetController.text = '60';
      });
    }
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
    if (!value && !_useCooling && !_useRoast) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('予熱、焙煎、豆冷ましのタイマーは最低1つはオンにしてください')));
      return; // 何もしないで終了
    }
    try {
      await UserSettingsFirestoreService.saveSetting('usePreheat', value);
      _usePreheat = value; // 先に値を更新
      setState(() {});
      await _saveAllToFirestore();
    } catch (e) {
      print('予熱設定保存エラー: $e');
    }
  }

  Future<void> _saveUseCooling(bool value) async {
    if (!value && !_usePreheat && !_useRoast) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('予熱、焙煎、豆冷ましのタイマーは最低1つはオンにしてください')));
      return; // 何もしないで終了
    }
    try {
      await UserSettingsFirestoreService.saveSetting('useCooling', value);
      _useCooling = value; // 先に値を更新
      setState(() {});
      await _saveAllToFirestore();
    } catch (e) {
      print('豆冷まし設定保存エラー: $e');
    }
  }

  Future<void> _saveUseRoast(bool value) async {
    if (!value && !_usePreheat && !_useCooling) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('予熱、焙煎、豆冷ましのタイマーは最低1つはオンにしてください')));
      return; // 何もしないで終了
    }
    try {
      await UserSettingsFirestoreService.saveSetting('useRoast', value);
      _useRoast = value; // 先に値を更新
      setState(() {});
      await _saveAllToFirestore();
    } catch (e) {
      print('焙煎設定保存エラー: $e');
    }
  }

  Future<void> _savePreheat() async {
    try {
      final value = int.tryParse(_preheatController.text) ?? 30;
      await UserSettingsFirestoreService.saveSetting('preheatMinutes', value);
      _preheatMinutes = value; // 先に値を更新
      setState(() {});
      await _saveAllToFirestore();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('予熱時間を$value分に保存しました')));
    } catch (e) {
      print('予熱時間保存エラー: $e');
    }
  }

  Future<void> _saveCooling() async {
    try {
      final value = int.tryParse(_coolingController.text) ?? 10;
      await UserSettingsFirestoreService.saveSetting('coolingMinutes', value);
      _coolingMinutes = value; // 先に値を更新
      setState(() {});
      await _saveAllToFirestore();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('豆冷ましタイマーを$value分に保存しました')));
    } catch (e) {
      print('豆冷まし時間保存エラー: $e');
    }
  }

  Future<void> _saveRecommendedOffset() async {
    try {
      final value = int.tryParse(_recommendedOffsetController.text) ?? 60;
      await UserSettingsFirestoreService.saveSetting(
        'recommendedRoastOffsetSeconds',
        value,
      );
      _recommendedOffsetSeconds = value;
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('おすすめ焙煎の引き秒数を$value秒に保存しました')));
    } catch (e) {
      print('おすすめ焙煎設定保存エラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('焙煎タイマー設定')),
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
                    color: Provider.of<ThemeSettings>(context).backgroundColor2,
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
                                '豆冷まし時間（分）',
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
                          // おすすめ焙煎の引き秒数設定欄
                          Row(
                            children: [
                              Icon(
                                Icons.recommend,
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).iconColor,
                                size: 24,
                              ),
                              SizedBox(width: 10),
                              Text(
                                '焙煎室にいくまでの時間（秒）',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Color(0xFF795548),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            '焙煎室に移動するために必要な秒数を設定してください。おすすめタイマーは、この秒数分だけ短く提案されます。',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(height: 18),
                          Row(
                            children: [
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: _recommendedOffsetController,
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
                                onPressed: _saveRecommendedOffset,
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
                          SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '【おすすめ焙煎タイマーとは】\n過去の記録から平均焙煎時間を計算し、「焙煎室に行くまでの時間」を引いた値を自動でタイマーに設定します。',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
