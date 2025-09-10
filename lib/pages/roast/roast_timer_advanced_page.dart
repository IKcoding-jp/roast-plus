import 'package:flutter/material.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:roastplus/pages/roast/roast_timer_settings_page.dart';
import 'package:roastplus/pages/roast/roast_record_page.dart';
import 'package:roastplus/pages/roast/roast_analysis_page.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../utils/sound_utils.dart';
import '../../services/user_settings_firestore_service.dart';

class RoastTimerAdvancedPage extends StatefulWidget {
  final Duration? initialDuration;
  const RoastTimerAdvancedPage({super.key, this.initialDuration});
  @override
  State<RoastTimerAdvancedPage> createState() => _RoastTimerAdvancedPageState();
}

class _RoastTimerAdvancedPageState extends State<RoastTimerAdvancedPage>
    with TickerProviderStateMixin {
  Timer? _timer;
  int _remainingSeconds = 0;
  int _totalSeconds = 0;
  bool _isPreheating = false;
  bool _isRoasting = false;
  bool _isCooling = false; // 豆冷ましタイマー用
  bool _isPaused = false; // 一時停止状態を管理
  bool? _usePreheat; // nullableに変更
  // アニメーション用
  // late AnimationController _progressController;
  // late AnimationController _pulseController;
  // late Animation<double> _progressAnimation;
  // late Animation<double> _pulseAnimation;

  // ★追加：サウンド再生用
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    // _progressController = AnimationController(
    //   duration: const Duration(milliseconds: 300),
    //   vsync: this,
    // );
    // _pulseController = AnimationController(
    //   duration: const Duration(milliseconds: 1000),
    //   vsync: this,
    // );
    // _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
    //   CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    // );
    // _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
    //   CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    // );
    _loadUsePreheat();
    if (widget.initialDuration != null) {
      _startRecommendedRoast(widget.initialDuration!);
    }
  }

  Future<void> _loadUsePreheat() async {
    final usePreheat =
        await UserSettingsFirestoreService.getSetting('usePreheat') ?? true;
    setState(() {
      _usePreheat = usePreheat;
      if (_usePreheat == false &&
          !_isRoasting &&
          !_isPreheating &&
          !_isCooling) {
        _isRoasting = true;
      }
    });
  }

  void _startPreheating() {
    setState(() {
      _isPreheating = true;
      _isRoasting = false;
      _isCooling = false;
      _totalSeconds = 30 * 60;
      _remainingSeconds = _totalSeconds;
    });
    // _progressController.forward();
    _startTimer();
  }

  void _startRoasting(int minutes) {
    setState(() {
      _isPreheating = false;
      _isRoasting = true;
      _isCooling = false;
      _totalSeconds = minutes * 60;
      _remainingSeconds = _totalSeconds;
    });
    // _progressController.forward();
    _startTimer();
  }

  void _startRecommendedRoast(Duration duration) {
    setState(() {
      _isPreheating = false;
      _isRoasting = true;
      _isCooling = false;
      _totalSeconds = duration.inSeconds;
      _remainingSeconds = _totalSeconds;
    });
    // _progressController.forward();
    _startTimer();
  }

  // 豆冷ましタイマー開始用
  void _startCooling(int minutes) {
    setState(() {
      _isPreheating = false;
      _isRoasting = false;
      _isCooling = true;
      _totalSeconds = minutes * 60;
      _remainingSeconds = _totalSeconds;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      if (!_isPaused) {
        // 一時停止中でない場合のみカウントダウン
        setState(() {
          _remainingSeconds--;
        });
        if (_remainingSeconds <= 0) {
          _timer?.cancel();

          // サウンド設定を確認
          final isSoundEnabled = await SoundUtils.isTimerSoundEnabled();
          if (isSoundEnabled) {
            final selectedSound = await SoundUtils.getSelectedTimerSound();
            final volume = await SoundUtils.getTimerVolume();

            // 通知ストリームを使用するように設定（通知音量で制御）
            try {
              await _audioPlayer.setPlayerMode(PlayerMode.lowLatency);
              await _audioPlayer.setReleaseMode(ReleaseMode.loop);
              await _audioPlayer.setVolume(volume);
              await _audioPlayer.play(AssetSource(selectedSound));
            } catch (e) {
              debugPrint('AudioPlayer設定エラー: $e');
              // フォールバック: デフォルト設定で再生
              await _audioPlayer.setReleaseMode(ReleaseMode.loop);
              await _audioPlayer.setVolume(volume);
              await _audioPlayer.play(AssetSource(selectedSound));
            }
          }

          if (!mounted) return;
          _showCompletionDialog();
        }
      }
    });
  }

  void _pauseTimer() {
    setState(() {
      _isPaused = true;
    });
  }

  void _resumeTimer() {
    setState(() {
      _isPaused = false;
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
        titleTextStyle: TextStyle(
          color: Provider.of<ThemeSettings>(context).dialogTextColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: Provider.of<ThemeSettings>(context).dialogTextColor,
          fontSize: 16,
        ),
        title: Text(_isPreheating ? '予熱完了' : 'もうすぐ焙煎が完了します。'),
        content: Text(
          _isPreheating ? '用意した豆を持って焙煎しに行きましょう。' : 'タッパーと木べらを持って焙煎室に行きましょう。',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // await _audioPlayer.stop(); // ←OK押したタイミングで止める！
              // _pulseController.stop();
              Navigator.pop(context);
              if (_isPreheating) {
                _goToAdvisor();
              } else {
                _showAfterRoastDialog();
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Provider.of<ThemeSettings>(context).fontColor1,
            ),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _goToAdvisor() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoastAnalysisPage()), // 必要に応じて調整
    );
  }

  void _showAfterRoastDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Provider.of<ThemeSettings>(
          context,
        ).dialogBackgroundColor,
        titleTextStyle: TextStyle(
          color: Provider.of<ThemeSettings>(context).dialogTextColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: Provider.of<ThemeSettings>(context).dialogTextColor,
          fontSize: 16,
        ),
        title: Text('連続焙煎しますか？'),
        content: Text('焙煎機が温かいうちに次の焙煎が可能です。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _goToAdvisor(); // 連続焙煎もAdvisorから！
            },
            style: TextButton.styleFrom(
              foregroundColor: Provider.of<ThemeSettings>(context).fontColor1,
            ),
            child: Text('はい（連続焙煎）'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showCoolingDialog();
            },
            style: TextButton.styleFrom(
              foregroundColor: Provider.of<ThemeSettings>(context).fontColor1,
            ),
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
        titleTextStyle: TextStyle(
          color: Provider.of<ThemeSettings>(context).dialogTextColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: Provider.of<ThemeSettings>(context).dialogTextColor,
          fontSize: 16,
        ),
        title: Text('アフターパージに設定しましょう。'),
        content: Text('機械を冷却モードに設定してください。\nお疲れ様でした！\n焙煎時間の記録ができます。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, true); // true: 記録画面へ
            },
            style: TextButton.styleFrom(
              foregroundColor: Provider.of<ThemeSettings>(context).buttonColor,
            ),
            child: Text('記録に進む'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, false); // false: 閉じるだけ
            },
            style: TextButton.styleFrom(
              foregroundColor: Provider.of<ThemeSettings>(context).fontColor1,
            ),
            child: Text('閉じる'),
          ),
        ],
      ),
    );

    // どちらのボタンでもここでリセット
    _timer?.cancel();
    setState(() {
      _isPreheating = false;
      _isRoasting = false;
      _isCooling = false;
      _timer?.cancel();
      _remainingSeconds = 0;
      _totalSeconds = 0;
    });

    if (!mounted) return;
    if (result == true) {
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
      _audioPlayer.dispose(); // AudioPlayerのリソース解放を有効化
    } catch (e) {
      debugPrint('AudioPlayer破棄エラー: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_usePreheat == null) {
      // 設定取得前はローディング
      return Scaffold(
        appBar: AppBar(title: Text('タイマー')),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final progress = _totalSeconds == 0
        ? 0.0
        : (_totalSeconds - _remainingSeconds) / _totalSeconds;

    // --- タイトル・中央テキスト分岐 ---
    String title;
    String centerText;
    List<Widget> actionButtons = [];

    if (_isCooling) {
      title = '豆冷ましタイマー';
      centerText = '豆冷ましタイマー';
      actionButtons.add(
        TextButton(
          onPressed: _totalSeconds == 0 ? () => _startCooling(10) : null,
          child: Text('豆冷ましタイマーを開始'),
        ),
      );
    } else if (_isPreheating) {
      title = '予熱タイマー';
      centerText = '予熱タイマー';
      actionButtons.add(
        ElevatedButton(
          onPressed: _isPaused ? _resumeTimer : _pauseTimer,
          child: Text(_isPaused ? '再開' : '一時停止'),
        ),
      );
    } else if (_isRoasting) {
      title = '焙煎タイマー';
      centerText = '焙煎タイマー';
      actionButtons.add(
        ElevatedButton(
          onPressed: _isPaused ? _resumeTimer : _pauseTimer,
          child: Text(_isPaused ? '再開' : '一時停止'),
        ),
      );
    } else if (!_usePreheat!) {
      // 予熱タイマーOFF時の初期画面
      title = '焙煎タイマー';
      centerText = '焙煎タイマー';
      actionButtons.add(
        ElevatedButton(
          onPressed: () => _startRoasting(10), // デフォルト10分
          child: Text('焙煎開始'),
        ),
      );
    } else {
      // 予熱タイマーON時の初期画面
      title = '予熱タイマー';
      centerText = '予熱タイマー';
      actionButtons.add(
        ElevatedButton(onPressed: _startPreheating, child: Text('予熱開始')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.local_fire_department, color: Colors.orange[600]),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            tooltip: 'タイマー設定',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RoastTimerSettingsPage()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            color: Provider.of<ThemeSettings>(context).cardBackgroundColor,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    centerText,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'HannariMincho',
                    ),
                  ),
                  SizedBox(height: 40),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 10,
                          color: Provider.of<ThemeSettings>(
                            context,
                          ).timerCircleColor,
                        ),
                      ),
                      Text(
                        _formatTime(_remainingSeconds),
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'HannariMincho',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 40),
                  ...actionButtons,
                  SizedBox(height: 20),
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
      ),
    );
  }
}
