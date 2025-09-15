import 'package:flutter/material.dart';
import '../../services/roast_timer_settings_firestore_service.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../services/user_settings_firestore_service.dart';
import '../../models/group_provider.dart';
import '../../utils/text_input_utils.dart';

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
      debugPrint('予熱時間読み込みエラー: $e');
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
      debugPrint('豆冷まし時間読み込みエラー: $e');
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
      debugPrint('スイッチ設定読み込みエラー: $e');
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
      debugPrint('おすすめ焙煎設定読み込みエラー: $e');
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
      debugPrint('予熱設定保存エラー: $e');
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
      debugPrint('豆冷まし設定保存エラー: $e');
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
      debugPrint('焙煎設定保存エラー: $e');
    }
  }

  Future<void> _savePreheat() async {
    try {
      final value = int.tryParse(_preheatController.text) ?? 30;
      await UserSettingsFirestoreService.saveSetting('preheatMinutes', value);
      _preheatMinutes = value; // 先に値を更新
      setState(() {});
      await _saveAllToFirestore();
      if (!mounted) return;
      final themeSettings = Provider.of<ThemeSettings>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('予熱時間を$value分に保存しました'),
          backgroundColor: themeSettings.appButtonColor,
        ),
      );
    } catch (e) {
      debugPrint('予熱時間保存エラー: $e');
    }
  }

  Future<void> _saveCooling() async {
    try {
      final value = int.tryParse(_coolingController.text) ?? 10;
      await UserSettingsFirestoreService.saveSetting('coolingMinutes', value);
      _coolingMinutes = value; // 先に値を更新
      setState(() {});
      await _saveAllToFirestore();
      if (!mounted) return;
      final themeSettings = Provider.of<ThemeSettings>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('豆冷ましタイマーを$value分に保存しました'),
          backgroundColor: themeSettings.appButtonColor,
        ),
      );
    } catch (e) {
      debugPrint('豆冷まし時間保存エラー: $e');
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
      if (!mounted) return;
      final themeSettings = Provider.of<ThemeSettings>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('おすすめ焙煎の引き秒数を$value秒に保存しました'),
          backgroundColor: themeSettings.appButtonColor,
        ),
      );
    } catch (e) {
      debugPrint('おすすめ焙煎設定保存エラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('焙煎タイマー設定'),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
      ),
      backgroundColor: themeSettings.backgroundColor,
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: themeSettings.iconColor),
            )
          : Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: isWeb ? 40.0 : 20.0,
                  right: isWeb ? 40.0 : 20.0,
                  top: 24.0,
                  bottom: isWeb ? 24.0 : 60.0, // モバイル版の下部余白を増加
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWeb ? 600 : double.infinity,
                    minHeight:
                        MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        kToolbarHeight -
                        48.0, // 適切な最小高さを設定
                  ),
                  child: Card(
                    elevation: isWeb ? 2 : 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isWeb ? 12 : 16),
                    ),
                    color: themeSettings.cardBackgroundColor,
                    child: Padding(
                      padding: EdgeInsets.all(isWeb ? 32 : 24),
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
                                activeThumbColor: themeSettings.appButtonColor,
                              ),
                              SizedBox(width: 10),
                              Text(
                                '予熱タイマーを使う',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isWeb ? 16 : 16,
                                  color: themeSettings.fontColor1,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isWeb ? 16 : 10),
                          Row(
                            children: [
                              Switch(
                                value: _useRoast,
                                onChanged: (v) => _saveUseRoast(v),
                                activeThumbColor: themeSettings.appButtonColor,
                              ),
                              SizedBox(width: 10),
                              Text(
                                '焙煎タイマーを使う',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isWeb ? 16 : 16,
                                  color: themeSettings.fontColor1,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isWeb ? 16 : 10),
                          Row(
                            children: [
                              Switch(
                                value: _useCooling,
                                onChanged: (v) => _saveUseCooling(v),
                                activeThumbColor: themeSettings.appButtonColor,
                              ),
                              SizedBox(width: 10),
                              Text(
                                '豆冷ましタイマーを使う',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isWeb ? 16 : 16,
                                  color: themeSettings.fontColor1,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isWeb ? 40 : 32),
                          // 時間設定欄を下にまとめる
                          Row(
                            children: [
                              Icon(
                                Icons.timer,
                                color: themeSettings.iconColor,
                                size: isWeb ? 24 : 24,
                              ),
                              SizedBox(width: 10),
                              Text(
                                '予熱時間（分）',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isWeb ? 18 : 18,
                                  color: themeSettings.fontColor1,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isWeb ? 20 : 18),
                          Row(
                            children: [
                              SizedBox(
                                width: isWeb ? 120 : 100,
                                child: TextField(
                                  controller: _preheatController,
                                  keyboardType: TextInputType.numberWithOptions(
                                    decimal: false,
                                    signed: false,
                                  ),
                                  style: TextStyle(
                                    fontSize: isWeb ? 16 : 16,
                                    color: themeSettings.inputTextColor,
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor:
                                        themeSettings.inputBackgroundColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: themeSettings.borderColor,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: themeSettings.borderColor,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: themeSettings.appButtonColor,
                                        width: 2,
                                      ),
                                    ),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: isWeb ? 16 : 14,
                                      vertical: isWeb ? 16 : 12,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    // 全角数字を半角数字に変換
                                    final convertedValue =
                                        TextInputUtils.convertFullWidthToHalfWidth(
                                          value,
                                        );
                                    if (convertedValue != value) {
                                      _preheatController.text = convertedValue;
                                      _preheatController.selection =
                                          TextSelection.fromPosition(
                                            TextPosition(
                                              offset: convertedValue.length,
                                            ),
                                          );
                                    }
                                  },
                                ),
                              ),
                              SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: _savePreheat,
                                icon: Icon(Icons.save, size: isWeb ? 20 : 20),
                                label: Text(
                                  '保存',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isWeb ? 16 : 16,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeSettings.appButtonColor,
                                  foregroundColor: themeSettings.fontColor2,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isWeb ? 24 : 24,
                                    vertical: isWeb ? 16 : 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 4,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isWeb ? 40 : 32),
                          Row(
                            children: [
                              Icon(
                                Icons.ac_unit,
                                color: themeSettings.iconColor,
                                size: isWeb ? 24 : 24,
                              ),
                              SizedBox(width: 10),
                              Text(
                                '豆冷まし時間（分）',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isWeb ? 18 : 18,
                                  color: themeSettings.fontColor1,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isWeb ? 20 : 18),
                          Row(
                            children: [
                              SizedBox(
                                width: isWeb ? 120 : 100,
                                child: TextField(
                                  controller: _coolingController,
                                  keyboardType: TextInputType.numberWithOptions(
                                    decimal: false,
                                    signed: false,
                                  ),
                                  style: TextStyle(
                                    fontSize: isWeb ? 16 : 16,
                                    color: themeSettings.inputTextColor,
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor:
                                        themeSettings.inputBackgroundColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: themeSettings.borderColor,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: themeSettings.borderColor,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: themeSettings.appButtonColor,
                                        width: 2,
                                      ),
                                    ),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: isWeb ? 16 : 14,
                                      vertical: isWeb ? 16 : 12,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    // 全角数字を半角数字に変換
                                    final convertedValue =
                                        TextInputUtils.convertFullWidthToHalfWidth(
                                          value,
                                        );
                                    if (convertedValue != value) {
                                      _coolingController.text = convertedValue;
                                      _coolingController.selection =
                                          TextSelection.fromPosition(
                                            TextPosition(
                                              offset: convertedValue.length,
                                            ),
                                          );
                                    }
                                  },
                                ),
                              ),
                              SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: _saveCooling,
                                icon: Icon(Icons.save, size: isWeb ? 20 : 20),
                                label: Text(
                                  '保存',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isWeb ? 16 : 16,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeSettings.appButtonColor,
                                  foregroundColor: themeSettings.fontColor2,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isWeb ? 24 : 24,
                                    vertical: isWeb ? 16 : 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 4,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isWeb ? 40 : 32),
                          // おすすめ焙煎の引き秒数設定欄
                          Row(
                            children: [
                              Icon(
                                Icons.recommend,
                                color: themeSettings.iconColor,
                                size: isWeb ? 24 : 24,
                              ),
                              SizedBox(width: 10),
                              Text(
                                '焙煎室にいくまでの時間（秒）',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isWeb ? 18 : 18,
                                  color: themeSettings.fontColor1,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isWeb ? 12 : 8),
                          Text(
                            '焙煎室に移動するために必要な秒数を設定してください。おすすめタイマーは、この秒数分だけ短く提案されます。',
                            style: TextStyle(
                              fontSize: isWeb ? 14 : 14,
                              color: themeSettings.fontColor1,
                            ),
                          ),
                          SizedBox(height: isWeb ? 20 : 18),
                          Row(
                            children: [
                              SizedBox(
                                width: isWeb ? 120 : 100,
                                child: TextField(
                                  controller: _recommendedOffsetController,
                                  keyboardType: TextInputType.numberWithOptions(
                                    decimal: false,
                                    signed: false,
                                  ),
                                  style: TextStyle(
                                    fontSize: isWeb ? 16 : 16,
                                    color: themeSettings.inputTextColor,
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor:
                                        themeSettings.inputBackgroundColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: themeSettings.borderColor,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: themeSettings.borderColor,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: themeSettings.appButtonColor,
                                        width: 2,
                                      ),
                                    ),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: isWeb ? 16 : 14,
                                      vertical: isWeb ? 16 : 12,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    // 全角数字を半角数字に変換
                                    final convertedValue =
                                        TextInputUtils.convertFullWidthToHalfWidth(
                                          value,
                                        );
                                    if (convertedValue != value) {
                                      _recommendedOffsetController.text =
                                          convertedValue;
                                      _recommendedOffsetController.selection =
                                          TextSelection.fromPosition(
                                            TextPosition(
                                              offset: convertedValue.length,
                                            ),
                                          );
                                    }
                                  },
                                ),
                              ),
                              SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: _saveRecommendedOffset,
                                icon: Icon(Icons.save, size: isWeb ? 20 : 20),
                                label: Text(
                                  '保存',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isWeb ? 16 : 16,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeSettings.appButtonColor,
                                  foregroundColor: themeSettings.fontColor2,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isWeb ? 24 : 24,
                                    vertical: isWeb ? 16 : 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 4,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isWeb ? 24 : 16),
                          Container(
                            padding: EdgeInsets.all(isWeb ? 16 : 12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.orange,
                                  size: isWeb ? 20 : 20,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '【おすすめ焙煎タイマーとは】\n過去の記録から平均焙煎時間を計算し、「焙煎室に行くまでの時間」を引いた値を自動でタイマーに設定します。',
                                    style: TextStyle(
                                      fontSize: isWeb ? 14 : 14,
                                      color: themeSettings.fontColor1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: isWeb ? 10 : 10), // 下部の余白を増加
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
