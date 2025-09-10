import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:roastplus/pages/roast/roast_timer_settings_page.dart';
import 'package:roastplus/pages/roast/roast_record_page.dart';
import '../../services/user_settings_firestore_service.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../utils/text_input_utils.dart';

// ------ タイマー・ページ遷移管理 ------
enum RoastMode { idle, preheating, roasting, inputManualTime, inputRecommended }

class RoastTimerPage extends StatefulWidget {
  final Duration? initialDuration;
  const RoastTimerPage({super.key, this.initialDuration});
  @override
  State<RoastTimerPage> createState() => _RoastTimerPageState();
}

class _RoastTimerPageState extends State<RoastTimerPage> {
  Timer? _timer;
  int _remainingSeconds = 0;
  int _totalSeconds = 0;
  RoastMode _mode = RoastMode.idle;
  final AudioPlayer _audioPlayer = AudioPlayer();

  final TextEditingController _manualMinuteController = TextEditingController();
  final TextEditingController _beanController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final FocusNode _manualMinuteFocusNode = FocusNode();

  String _recommendErrorText = '';

  // おすすめ焙煎条件用の選択肢リスト
  List<String> _recommendBeanList = [];
  List<String> _recommendWeightList = [];
  List<String> _recommendRoastList = [];
  String? _selectedRecommendBean;
  String? _selectedRecommendWeight;
  String? _selectedRecommendRoast;
  List<Map<String, dynamic>> _recommendRecords = [];

  // 記録からおすすめ条件の組み合わせを抽出
  Future<void> _loadRecommendOptions() async {
    final saved = await UserSettingsFirestoreService.getSetting('roastRecords');
    if (saved != null) {
      final records = saved.map((e) => Map<String, dynamic>.from(e)).toList();
      // 組み合わせごとに件数カウント
      final Map<String, int> countMap = {};
      for (var r in records) {
        final bean = (r['bean'] ?? '').toString();
        final weight = (r['weight'] ?? '').toString();
        final roast = (r['roast'] ?? '').toString();
        if (bean.isEmpty || weight.isEmpty || roast.isEmpty) continue;
        final key = '$bean|$weight|$roast';
        countMap[key] = (countMap[key] ?? 0) + 1;
      }
      // 2件以上ある組み合わせのみ
      final validKeys = countMap.entries
          .where((e) => e.value >= 2)
          .map((e) => e.key)
          .toList();
      _recommendRecords = records.where((r) {
        final key = '${r['bean']}|${r['weight']}|${r['roast']}';
        return validKeys.contains(key);
      }).toList();
      // 豆リスト
      _recommendBeanList = _recommendRecords
          .map((r) => r['bean'] as String)
          .toSet()
          .toList();
      // 初期選択
      if (_recommendBeanList.isNotEmpty) {
        _selectedRecommendBean ??= _recommendBeanList.first;
        _updateRecommendWeightList();
      }
    }
  }

  void _updateRecommendWeightList() {
    _recommendWeightList = _recommendRecords
        .where((r) => r['bean'] == _selectedRecommendBean)
        .map((r) => r['weight'] as String)
        .toSet()
        .toList();
    if (_recommendWeightList.isNotEmpty) {
      _selectedRecommendWeight ??= _recommendWeightList.first;
      _updateRecommendRoastList();
    }
  }

  void _updateRecommendRoastList() {
    _recommendRoastList = _recommendRecords
        .where(
          (r) =>
              r['bean'] == _selectedRecommendBean &&
              r['weight'] == _selectedRecommendWeight,
        )
        .map((r) => r['roast'] as String)
        .toSet()
        .toList();
    if (_recommendRoastList.isNotEmpty) {
      _selectedRecommendRoast ??= _recommendRoastList.first;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialDuration != null) {
      _startRecommendedRoast(widget.initialDuration!);
    }
    _loadRecommendOptions();
  }

  void _startPreheating() {
    setState(() {
      _mode = RoastMode.preheating;
      _totalSeconds = 30 * 60;
      _remainingSeconds = _totalSeconds;
    });
    _startTimer();
  }

  void _startRoasting(int minutes) {
    setState(() {
      _mode = RoastMode.roasting;
      _totalSeconds = minutes * 60;
      _remainingSeconds = _totalSeconds;
    });
    _startTimer();
  }

  void _startRecommendedRoast(Duration duration) {
    setState(() {
      _mode = RoastMode.roasting;
      _totalSeconds = duration.inSeconds;
      _remainingSeconds = _totalSeconds;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      setState(() {
        _remainingSeconds--;
      });
      if (_remainingSeconds <= 0) {
        _timer?.cancel();
        // 通知ストリームを使用するように設定（通知音量で制御）
        try {
          await _audioPlayer.setPlayerMode(PlayerMode.lowLatency);
          await _audioPlayer.setReleaseMode(ReleaseMode.loop);
          await _audioPlayer.setVolume(1.0); // 音量を最大に設定
          await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
        } catch (e) {
          debugPrint('AudioPlayer設定エラー: $e');
          // フォールバック: デフォルト設定で再生
          await _audioPlayer.setReleaseMode(ReleaseMode.loop);
          await _audioPlayer.setVolume(1.0);
          await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
        }
        _showCompletionDialog();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = 0;
      _totalSeconds = 0;
      _mode = RoastMode.idle;
    });
  }

  void _skipTime() {
    setState(() => _remainingSeconds = 1);
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Provider.of<ThemeSettings>(
          context,
        ).dialogBackgroundColor,
        title: Text(
          _mode == RoastMode.preheating ? '予熱完了！' : 'もうすぐ焙煎が完了します。',
          style: TextStyle(
            color: Provider.of<ThemeSettings>(context).dialogTextColor,
          ),
        ),
        content: Text(
          _mode == RoastMode.preheating
              ? '用意した豆を持って焙煎室に行きましょう。'
              : 'タッパーと木べらを持って焙煎室に行きましょう。',
          style: TextStyle(
            color: Provider.of<ThemeSettings>(context).dialogTextColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _audioPlayer.stop();
              if (!mounted) return;
              Navigator.pop(context);
              if (_mode == RoastMode.preheating) {
                setState(() {
                  _mode = RoastMode.inputManualTime;
                });
              } else {
                _showAfterRoastDialog();
              }
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAfterRoastDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Provider.of<ThemeSettings>(
          context,
        ).dialogBackgroundColor,
        title: Text(
          '連続焙煎しますか？',
          style: TextStyle(
            color: Provider.of<ThemeSettings>(context).dialogTextColor,
          ),
        ),
        content: Text(
          '焙煎機が温かいうちに次の焙煎が可能です。',
          style: TextStyle(
            color: Provider.of<ThemeSettings>(context).dialogTextColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _mode = RoastMode.inputManualTime;
              });
            },
            child: Text('はい（連続焙煎）'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _stopTimer(); // ここでタイマーを完全停止・リセット！
              _showCoolingDialog();
            },
            child: Text('いいえ（アフターパージ）'),
          ),
        ],
      ),
    );
  }

  void _showCoolingDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Provider.of<ThemeSettings>(
          context,
        ).dialogBackgroundColor,
        title: Text(
          'お疲れ様でした！',
          style: TextStyle(
            color: Provider.of<ThemeSettings>(context).dialogTextColor,
          ),
        ),
        content: Text(
          '機械をアフターパージに設定してください。',
          style: TextStyle(
            color: Provider.of<ThemeSettings>(context).dialogTextColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: Text('記録に進む'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: Text('閉じる'),
          ),
        ],
      ),
    );

    if (result == true) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RoastRecordPage()),
      );
    }
  }

  String _formatTime(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    try {
      _audioPlayer.dispose();
    } catch (e) {
      debugPrint('AudioPlayer破棄エラー: $e');
    }
    _manualMinuteController.dispose();
    _beanController.dispose();
    _weightController.dispose();
    _manualMinuteFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 手動入力画面
    if (_mode == RoastMode.inputManualTime) {
      return Scaffold(
        appBar: AppBar(title: Text('焙煎時間入力')),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF8E1), Color(0xFFFFF8E1)],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                color: Color(0xFFFFF8E1),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '焙煎時間を入力してください',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C1D17),
                        ),
                      ),
                      SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          color: Provider.of<ThemeSettings>(
                            context,
                          ).inputBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).borderColor,
                          ),
                        ),
                        child: TextField(
                          controller: _manualMinuteController,
                          focusNode: _manualMinuteFocusNode,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: false,
                            signed: false,
                          ),
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9０-９]'),
                            ),
                          ],
                          onTap: () {
                            // IMEを半角モードに強制設定
                            SystemChannels.textInput
                                .invokeMethod('TextInput.setInputType', {
                                  'inputType': 'TextInputType.number',
                                  'inputAction': 'TextInputAction.done',
                                });
                          },
                          onChanged: (value) {
                            // 全角数字を半角数字に変換
                            String convertedValue =
                                TextInputUtils.convertFullWidthToHalfWidth(
                                  value,
                                );

                            // 数字以外の文字を除去
                            convertedValue = convertedValue.replaceAll(
                              RegExp(r'[^0-9]'),
                              '',
                            );

                            if (convertedValue != value) {
                              _manualMinuteController.text = convertedValue;
                              _manualMinuteController.selection =
                                  TextSelection.fromPosition(
                                    TextPosition(offset: convertedValue.length),
                                  );
                            }
                          },
                          style: TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.timer,
                              color: Color(0xFF795548),
                            ),
                            hintText: '分数を入力',
                            filled: true,
                            fillColor: Provider.of<ThemeSettings>(
                              context,
                            ).inputBackgroundColor,
                            hintStyle: TextStyle(color: Colors.black),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final min = int.tryParse(
                              _manualMinuteController.text,
                            );
                            if (min != null && min > 0) {
                              _startRoasting(min);
                            }
                          },
                          icon: Icon(Icons.play_arrow, size: 20),
                          label: Text(
                            '手動で焙煎スタート',
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
                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _mode = RoastMode.inputRecommended;
                            });
                          },
                          icon: Icon(Icons.lightbulb, size: 20),
                          label: Text(
                            'おすすめ焙煎時間を自動で設定する',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(
                              0xFFFF8225,
                            ), // オレンジ色（#FF8225）
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
            ),
          ),
        ),
      );
    }

    // おすすめ自動入力画面
    if (_mode == RoastMode.inputRecommended) {
      return Scaffold(
        appBar: AppBar(title: Text('おすすめ焙煎入力')),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF8E1), Color(0xFFFFF8E1)],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                color: Color(0xFFFFF8E1),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '焙煎条件を選択してください',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C1D17),
                        ),
                      ),
                      SizedBox(height: 24),
                      // 豆の種類プルダウン
                      Container(
                        decoration: BoxDecoration(
                          color: Provider.of<ThemeSettings>(
                            context,
                          ).inputBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).borderColor,
                          ),
                        ),
                        child: DropdownButtonFormField<String>(
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
                          initialValue: _selectedRecommendBean,
                          items: _recommendBeanList
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _selectedRecommendBean = v;
                              _selectedRecommendWeight = null;
                              _selectedRecommendRoast = null;
                              _updateRecommendWeightList();
                            });
                          },
                        ),
                      ),
                      SizedBox(height: 16),
                      // 重さプルダウン
                      Container(
                        decoration: BoxDecoration(
                          color: Provider.of<ThemeSettings>(
                            context,
                          ).inputBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).borderColor,
                          ),
                        ),
                        child: DropdownButtonFormField<String>(
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
                          initialValue: _selectedRecommendWeight,
                          items: _recommendWeightList
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _selectedRecommendWeight = v;
                              _selectedRecommendRoast = null;
                              _updateRecommendRoastList();
                            });
                          },
                        ),
                      ),
                      SizedBox(height: 16),
                      // 煎り度プルダウン
                      Container(
                        decoration: BoxDecoration(
                          color: Provider.of<ThemeSettings>(
                            context,
                          ).inputBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).borderColor,
                          ),
                        ),
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.local_fire_department,
                              color: Color(0xFF795548),
                            ),
                            labelText: '煎り度',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          initialValue: _selectedRecommendRoast,
                          items: _recommendRoastList
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _selectedRecommendRoast = v;
                            });
                          },
                        ),
                      ),
                      SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            setState(() {
                              _recommendErrorText = '';
                            });
                            final bean = _selectedRecommendBean;
                            final weightText = _selectedRecommendWeight;
                            final roast = _selectedRecommendRoast;
                            if (bean == null ||
                                weightText == null ||
                                roast == null) {
                              setState(() {
                                _recommendErrorText = 'データが足りません。全て選択してください。';
                              });
                              return;
                            }
                            final matching = _recommendRecords
                                .where(
                                  (r) =>
                                      (r['bean'] ?? '') == bean &&
                                      (r['roast'] ?? '') == roast &&
                                      (r['weight'] ?? '') == weightText,
                                )
                                .toList();
                            if (matching.isEmpty) {
                              setState(() {
                                _recommendErrorText =
                                    '焙煎記録のデータが不足しています。焙煎記録が複数必要です。';
                              });
                              return;
                            }
                            int totalSeconds = 0;
                            int count = 0;
                            for (var r in matching) {
                              final t = (r['time'] ?? '08:00').split(':');
                              int min = int.tryParse(t[0] ?? '0') ?? 0;
                              int sec =
                                  int.tryParse(t.length > 1 ? t[1] : '0') ?? 0;
                              totalSeconds += min * 60 + sec;
                              count++;
                            }
                            if (count == 0) return;
                            int avgSeconds = (totalSeconds ~/ count);
                            int setSeconds = avgSeconds - 60;
                            if (setSeconds < 60) setSeconds = 60;
                            String format(int sec) =>
                                '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                backgroundColor: Provider.of<ThemeSettings>(
                                  context,
                                ).dialogBackgroundColor,
                                title: Text(
                                  'おすすめ焙煎時間',
                                  style: TextStyle(
                                    color: Provider.of<ThemeSettings>(
                                      context,
                                    ).dialogTextColor,
                                  ),
                                ),
                                content: Text(
                                  '平均焙煎時間: ${format(avgSeconds)}\n'
                                  'おすすめタイマー: ${format(setSeconds)}（平均−60秒）\n\n'
                                  'この時間でタイマーを開始しますか？',
                                  style: TextStyle(
                                    color: Provider.of<ThemeSettings>(
                                      context,
                                    ).dialogTextColor,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text('キャンセル'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: Text('OK'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              _startRecommendedRoast(
                                Duration(seconds: setSeconds),
                              );
                            }
                          },
                          icon: Icon(Icons.play_arrow, size: 20),
                          label: Text(
                            'おすすめ焙煎でスタート',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(
                              0xFFFF8225,
                            ), // オレンジ色（#FF8225）
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ),
                      if (_recommendErrorText.isNotEmpty) ...[
                        SizedBox(height: 16),
                        Text(
                          _recommendErrorText,
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _mode = RoastMode.inputManualTime;
                            });
                          },
                          icon: Icon(Icons.arrow_back, size: 20),
                          label: Text(
                            '戻る',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF8D6E63),
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
            ),
          ),
        ),
      );
    }

    // タイマー画面
    final progress = _totalSeconds == 0
        ? 0.0
        : (_totalSeconds - _remainingSeconds) / _totalSeconds;
    final title = _mode == RoastMode.preheating
        ? '🔥 予熱中'
        : _mode == RoastMode.roasting
        ? '🔥 焙煎中'
        : '⏱ 予熱タイマー';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.timer, color: Colors.white),
            SizedBox(width: 8),
            Text('予熱タイマー'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            tooltip: 'タイマー設定',
            onPressed: () {
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RoastTimerSettingsPage()),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF8E1), Color(0xFFFFF8E1)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: Color(0xFFFFF8E1),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C1D17),
                          ),
                        ),
                        SizedBox(height: 32),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 220,
                              height: 220,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 12,
                                color: Color(0xFF795548),
                                backgroundColor: const Color(
                                  0xFF795548,
                                ).withValues(alpha: 0.2),
                              ),
                            ),
                            Text(
                              _formatTime(_remainingSeconds),
                              style: TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: Color(0xFF2C1D17),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 32),
                        if (_mode == RoastMode.idle)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _startPreheating,
                              icon: Icon(Icons.local_fire_department, size: 20),
                              label: Text(
                                '予熱開始',
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
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _stopTimer,
                              icon: Icon(Icons.stop, size: 20),
                              label: Text(
                                '停止',
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
                SizedBox(height: 16),
                TextButton(
                  onPressed: _totalSeconds == 0 ? null : _skipTime,
                  child: Text(
                    '⏩ スキップ',
                    style: TextStyle(color: Color(0xFF795548), fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
