import 'package:flutter/material.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:bysnapp/pages/roast/roast_timer_settings_page.dart';
import 'package:bysnapp/pages/roast/roast_record_page.dart';
import 'package:bysnapp/pages/roast/roast_advisor_page.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';

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
    if (widget.initialDuration != null) {
      _startRecommendedRoast(widget.initialDuration!);
    }
  }

  void _startPreheating() {
    setState(() {
      _isPreheating = true;
      _isRoasting = false;
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
      _totalSeconds = duration.inSeconds;
      _remainingSeconds = _totalSeconds;
    });
    // _progressController.forward();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      setState(() {
        _remainingSeconds--;
      });
      if (_remainingSeconds <= 0) {
        _timer?.cancel();
        // _pulseController.repeat(reverse: true);
        // ループ再生モードにしてアラームを鳴らす
        // await _audioPlayer.setReleaseMode(ReleaseMode.loop);
        // await _audioPlayer.setVolume(1.0); // 音量を最大に設定
        // await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
        _showCompletionDialog();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    // _progressController.reset();
    // _pulseController.stop();
    setState(() {
      _remainingSeconds = 0;
      _isPreheating = false;
      _isRoasting = false;
    });
  }

  void _skipTime() {
    setState(() => _remainingSeconds = 1);
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _goToAdvisor() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoastAdvisorPage()), // 必要に応じて調整
    );
  }

  void _showAfterRoastDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('連続焙煎しますか？'),
        content: Text('焙煎機が温かいうちに次の焙煎が可能です。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _goToAdvisor(); // 連続焙煎もAdvisorから！
            },
            child: Text('はい（連続焙煎）'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
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
        title: Text('アフターパージに設定しましょう。'),
        content: Text('機械を冷却モードに設定してください。\nお疲れ様でした！'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, true); // true: 記録画面へ
            },
            child: Text('記録に進む'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, false); // false: 閉じるだけ
            },
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
      _timer?.cancel();
      _remainingSeconds = 0;
      _totalSeconds = 0;
    });

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
    // _audioPlayer.dispose(); // ★サウンド用リソース解放
    // _progressController.dispose();
    // _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalSeconds == 0
        ? 0.0
        : (_totalSeconds - _remainingSeconds) / _totalSeconds;
    final title = _isPreheating
        ? '🔥 予熱中'
        : _isRoasting
        ? '🔥 焙煎中'
        : '⏱ 焙煎タイマー';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.local_fire_department, color: Colors.orange[600]),
            SizedBox(width: 8),
            Text('焙煎タイマー'),
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
            color:
                Provider.of<ThemeSettings>(context).backgroundColor2 ??
                Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
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
                  if (!_isPreheating && !_isRoasting)
                    ElevatedButton(
                      onPressed: _startPreheating,
                      child: Text('予熱開始'),
                    )
                  else
                    ElevatedButton(onPressed: _stopTimer, child: Text('停止')),
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
