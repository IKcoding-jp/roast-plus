import 'package:roastplus/pages/roast/roast_record_page.dart'
    show RoastRecordPage;
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:roastplus/pages/roast/roast_timer_settings_page.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../utils/sound_utils.dart';
import '../../models/group_provider.dart';
import '../../models/roast_record.dart';
import '../../services/roast_record_firestore_service.dart';
import '../../services/roast_timer_notification_service.dart';
import '../../services/user_settings_firestore_service.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../utils/app_performance_config.dart';

enum RoastMode {
  idle,
  preheating,
  roasting,
  inputManualTime,
  inputRecommended,
  cooling,
}

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
  bool _isPaused = false; // 一時停止状態を管理
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _justFinishedPreheat = false; // 予熱完了直後フラグ

  final TextEditingController _manualMinuteController = TextEditingController();
  final TextEditingController _beanController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  String _recommendErrorText = '';

  // おすすめ焙煎条件用の選択肢リスト
  List<String> _recommendBeanList = [];
  List<String> _recommendWeightList = [];
  List<String> _recommendRoastList = [];
  String? _selectedRecommendBean;
  String? _selectedRecommendWeight;
  String? _selectedRecommendRoast;
  List<RoastRecord> _recommendRecords = [];

  // 設定をキャッシュ（Firebase読み込みを最適化）
  bool? _usePreheat;
  int? _preheatMinutes;
  bool? _useRoast;
  bool? _useCooling;
  int? _coolingMinutes;

  void _loadInterstitialAdAndShow(VoidCallback onAdClosed) async {
    if (await isDonorUser()) {
      onAdClosed();
      return;
    }
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712', // テスト用ID
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              onAdClosed();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              onAdClosed();
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (error) {
          onAdClosed();
        },
      ),
    );
  }

  // Firestoreから記録を取得しておすすめ条件の組み合わせを抽出
  Future<void> _loadRecommendOptions() async {
    try {
      final groupProvider = context.read<GroupProvider>();
      List<RoastRecord> allRecords = [];

      if (groupProvider.groups.isNotEmpty) {
        // グループに参加している場合は個人とグループの記録を結合
        final personalRecords = await RoastRecordFirestoreService.getRecords();
        final groupRecords = await RoastRecordFirestoreService.getGroupRecords(
          groupProvider.groups.first.id,
        );

        // 重複を避けるため、IDでフィルタリング
        final personalIds = personalRecords.map((r) => r.id).toSet();
        final uniqueGroupRecords = groupRecords
            .where((r) => !personalIds.contains(r.id))
            .toList();
        allRecords = [...personalRecords, ...uniqueGroupRecords];
      } else {
        // グループに参加していない場合は個人の記録のみ
        allRecords = await RoastRecordFirestoreService.getRecords();
      }

      // 組み合わせごとに件数カウント
      final Map<String, int> countMap = {};
      for (var r in allRecords) {
        final bean = r.bean;
        final weight = r.weight.toString();
        final roast = r.roast;
        if (bean.isEmpty || weight.isEmpty || roast.isEmpty) continue;
        final key = '$bean|$weight|$roast';
        countMap[key] = (countMap[key] ?? 0) + 1;
      }

      // 2件以上ある組み合わせのみ
      final validKeys = countMap.entries
          .where((e) => e.value >= 2)
          .map((e) => e.key)
          .toList();

      _recommendRecords = allRecords.where((r) {
        final key = '${r.bean}|${r.weight}|${r.roast}';
        return validKeys.contains(key);
      }).toList();

      // 豆リスト
      _recommendBeanList = _recommendRecords
          .map((r) => r.bean)
          .toSet()
          .toList();

      // 初期選択
      if (_recommendBeanList.isNotEmpty) {
        _selectedRecommendBean ??= _recommendBeanList.first;
        _updateRecommendWeightList();
      }

      // mountedチェックを追加してからsetStateを呼び出し
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('おすすめ焙煎条件の読み込みエラー: $e');
    }
  }

  void _updateRecommendWeightList() {
    _recommendWeightList = _recommendRecords
        .where((r) => r.bean == _selectedRecommendBean)
        .map((r) => r.weight.toString())
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
              r.bean == _selectedRecommendBean &&
              r.weight.toString() == _selectedRecommendWeight,
        )
        .map((r) => r.roast)
        .toSet()
        .toList();
    if (_recommendRoastList.isNotEmpty) {
      _selectedRecommendRoast ??= _recommendRoastList.first;
    }
  }

  @override
  void initState() {
    super.initState();
    _initializePermissions();
    _loadSettings(); // 設定を初期化時に読み込み
    if (widget.initialDuration != null) {
      _startRecommendedRoast(widget.initialDuration!);
    }
    _loadRecommendOptions();

    // アプリのライフサイクル監視を追加
    SystemChannels.lifecycle.setMessageHandler((msg) async {
      if (msg == AppLifecycleState.resumed.toString()) {
        // アプリが復帰した時にタイマー状態をチェック
        _checkTimerStateOnResume();
      }
      return null;
    });
  }

  // 設定を初期化時に一度だけ読み込み
  Future<void> _loadSettings() async {
    try {
      _usePreheat =
          await UserSettingsFirestoreService.getSetting('usePreheat') ?? true;
      _preheatMinutes =
          await UserSettingsFirestoreService.getSetting('preheatMinutes') ?? 30;
      _useRoast =
          await UserSettingsFirestoreService.getSetting('useRoast') ?? true;
      _useCooling =
          await UserSettingsFirestoreService.getSetting('useCooling') ?? false;
      _coolingMinutes =
          await UserSettingsFirestoreService.getSetting('coolingMinutes') ?? 10;
    } catch (e) {
      print('設定読み込みエラー: $e');
      // エラー時はデフォルト値を使用
      _usePreheat = true;
      _preheatMinutes = 30;
      _useRoast = true;
      _useCooling = false;
      _coolingMinutes = 10;
    }
  }

  // 通知権限を初期化
  Future<void> _initializePermissions() async {
    try {
      // 通知権限をリクエスト
      final notificationGranted =
          await RoastTimerNotificationService.requestPermissions();
      if (!notificationGranted) {
        print('通知権限が拒否されました');
      }
    } catch (e) {
      print('権限初期化エラー: $e');
    }
  }

  // タイマー状態をローカルに保存（Firebaseとの同期を削除）
  void _saveTimerState() {
    // ローカルストレージに保存（Firebaseとの同期なし）
    // タイマー動作中の頻繁な保存を避けるため、ローカルでのみ管理
  }

  // タイマー完了状態を保存（簡素化）
  Future<void> _saveTimerCompletionState() async {
    // タイマー完了時のみFirebaseに保存（必要最小限）
    await UserSettingsFirestoreService.saveSetting(
      'roast_timer_completed',
      true,
    );
  }

  // アプリ復帰時のタイマー状態チェック
  void _checkTimerStateOnResume() async {
    if (!mounted) return;

    final isCompleted =
        await UserSettingsFirestoreService.getSetting(
          'roast_timer_completed',
        ) ??
        false;

    if (isCompleted) {
      // タイマー完了状態をクリア
      await UserSettingsFirestoreService.deleteSetting('roast_timer_completed');
      await UserSettingsFirestoreService.deleteSetting(
        'roast_timer_completed_mode',
      );
      await UserSettingsFirestoreService.deleteSetting(
        'roast_timer_completed_at',
      );

      print('アプリ復帰時にタイマー完了を検出');

      // 画面が本当にRoastTimerPageのままか確認
      if (ModalRoute.of(context)?.isCurrent != true) {
        print('RoastTimerPageが最前面でないため、完了ダイアログを表示しません');
        return;
      }
      // 完了ダイアログを表示
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          _showCompletionDialog();
        }
      });
    }
  }

  // おすすめ焙煎画面に遷移する際にデータを再読み込み
  void _refreshRecommendOptions() {
    _loadRecommendOptions();
  }

  void _startPreheating() async {
    // キャッシュされた設定を使用（Firebase読み込みを削除）
    final usePreheat = _usePreheat ?? true;
    if (!usePreheat) {
      // 予熱タイマーをスキップし、手動入力画面へ
      setState(() {
        _mode = RoastMode.inputManualTime;
      });
      return;
    }
    final preheatMinutes = _preheatMinutes ?? 30;
    setState(() {
      _mode = RoastMode.preheating;
      _totalSeconds = preheatMinutes * 60;
      _remainingSeconds = _totalSeconds;
    });

    // 予熱完了通知をスケジュール
    await RoastTimerNotificationService.scheduleRoastTimerNotification(
      id: 1, // 予熱用のID
      duration: Duration(minutes: preheatMinutes),
      title: '🔥 予熱完了！',
      body: '用意した豆を持って焙煎室に行きましょう。',
    );

    _startTimer();
  }

  void _startRoasting(int minutes) async {
    // キャッシュされた設定を使用（Firebase読み込みを削除）
    final useRoast = _useRoast ?? true;
    final useCooling = _useCooling ?? false;
    if (!useRoast) {
      // 焙煎タイマーをスキップ
      if (useCooling) {
        _startBeanCooling();
      } else {
        _showCoolingDialog();
      }
      return;
    }
    setState(() {
      _mode = RoastMode.roasting;
      _totalSeconds = minutes * 60;
      _remainingSeconds = _totalSeconds;
    });

    // 焙煎完了通知をスケジュール
    await RoastTimerNotificationService.scheduleRoastTimerNotification(
      id: 2, // 焙煎用のID
      duration: Duration(minutes: minutes),
      title: '🔥 焙煎完了！',
      body: 'タッパーと木べらを持って焙煎室に行きましょう。',
    );

    _startTimer();
  }

  void _startRecommendedRoast(Duration duration) async {
    // キャッシュされた設定を使用（Firebase読み込みを削除）
    final useRoast = _useRoast ?? true;
    final useCooling = _useCooling ?? false;
    if (!useRoast) {
      // 焙煎タイマーをスキップ
      if (useCooling) {
        _startBeanCooling();
      } else {
        _showCoolingDialog();
      }
      return;
    }
    setState(() {
      _mode = RoastMode.roasting;
      _totalSeconds = duration.inSeconds;
      _remainingSeconds = _totalSeconds;
    });

    // おすすめ焙煎完了通知をスケジュール
    await RoastTimerNotificationService.scheduleRoastTimerNotification(
      id: 3, // おすすめ焙煎用のID
      duration: duration,
      title: '🔥 焙煎完了！',
      body: 'タッパーと木べらを持って焙煎室に行きましょう。',
    );

    _startTimer();
  }

  void _startBeanCooling() async {
    setState(() {
      _justFinishedPreheat = false;
    });
    // キャッシュされた設定を使用（Firebase読み込みを削除）
    final coolingMinutes = _coolingMinutes ?? 10;
    setState(() {
      _mode = RoastMode.cooling;
      _totalSeconds = coolingMinutes * 60;
      _remainingSeconds = _totalSeconds;
    });
    // 豆冷ましタイマー通知
    await RoastTimerNotificationService.scheduleRoastTimerNotification(
      id: 4,
      duration: Duration(minutes: coolingMinutes),
      title: '🫘 豆冷ましタイマー完了！',
      body: '豆冷ましタイマーが終了しました。',
    );
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_isPaused) {
        // 一時停止中でない場合のみカウントダウン
        if (mounted) {
          setState(() {
            _remainingSeconds--;
          });
        }

        // タイマー状態を保存
        _saveTimerState();

        if (_remainingSeconds <= 0) {
          _timer?.cancel();

          // mountedチェックを追加
          if (!mounted) return;

          // タイマー完了状態を保存
          await _saveTimerCompletionState();

          // 通知をキャンセル（既に表示されているため）
          try {
            await RoastTimerNotificationService.cancelAllRoastTimerNotifications();
          } catch (e) {
            print('通知キャンセルエラー: $e');
          }

          // サウンド設定を確認
          try {
            final isSoundEnabled = await SoundUtils.isTimerSoundEnabled();
            if (isSoundEnabled) {
              final selectedSound = await SoundUtils.getSelectedTimerSound();
              final volume = await SoundUtils.getTimerVolume();

              await _audioPlayer.setReleaseMode(ReleaseMode.loop);
              await _audioPlayer.setVolume(volume);
              await _audioPlayer.play(AssetSource(selectedSound));
            }
          } catch (e) {
            print('サウンド再生エラー: $e');
          }

          // mountedチェックを再度追加
          if (mounted) {
            _showCompletionDialog();
          }
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
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Provider.of<ThemeSettings>(
          context,
        ).dialogBackgroundColor,
        titleTextStyle: TextStyle(
          color: Provider.of<ThemeSettings>(context).dialogTextColor,
          fontSize: (20 * Provider.of<ThemeSettings>(context).fontSizeScale)
              .clamp(16.0, 28.0),
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: Provider.of<ThemeSettings>(context).dialogTextColor,
          fontSize: (16 * Provider.of<ThemeSettings>(context).fontSizeScale)
              .clamp(12.0, 24.0),
        ),
        title: Text(
          _mode == RoastMode.preheating
              ? '予熱完了！'
              : _mode == RoastMode.cooling
              ? '豆冷ましタイマー完了！'
              : 'もうすぐ焙煎が完了します。',
        ),
        content: Text(
          _mode == RoastMode.preheating
              ? '用意した豆を持って焙煎室に行きましょう。'
              : _mode == RoastMode.cooling
              ? '豆が十分に冷めました。焙煎した豆を回収しましょう。'
              : 'タッパーと木べらを持って焙煎室に行きましょう。',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _audioPlayer.stop();
              Navigator.pop(context);
              if (_mode == RoastMode.preheating) {
                // 予熱タイマーのみオンの場合はidleに戻す
                final useRoast =
                    await UserSettingsFirestoreService.getSetting('useRoast') ??
                    true;
                final useCooling =
                    await UserSettingsFirestoreService.getSetting(
                      'useCooling',
                    ) ??
                    true;
                if (!useRoast && !useCooling) {
                  setState(() {
                    _mode = RoastMode.idle;
                    _totalSeconds = 0;
                    _remainingSeconds = 0;
                    _justFinishedPreheat = false;
                  });
                } else if (!useRoast && useCooling) {
                  // idle画面に戻し、豆冷ましタイマーを開始ボタンを表示
                  setState(() {
                    _mode = RoastMode.idle;
                    _totalSeconds = 0;
                    _remainingSeconds = 0;
                    _justFinishedPreheat = true;
                  });
                } else {
                  setState(() {
                    _mode = RoastMode.inputManualTime;
                    _justFinishedPreheat = false;
                  });
                }
              } else if (_mode == RoastMode.cooling) {
                _showCoolingDialog();
              } else {
                // 焙煎完了時（経験値獲得は焙煎記録入力でのみ）
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

  void _showAfterRoastDialog() {
    showDialog(
      context: context,
      builder: (_) => FutureBuilder<bool>(
        future: (() async {
          final result = await UserSettingsFirestoreService.getSetting(
            'useCooling',
          );
          return (result as bool?) ?? false; // デフォルトをオフに変更
        })(),
        builder: (context, snapshot) {
          final useCooling = snapshot.data ?? false; // デフォルトをオフに変更
          return AlertDialog(
            backgroundColor: Provider.of<ThemeSettings>(
              context,
            ).dialogBackgroundColor,
            titleTextStyle: TextStyle(
              color: Provider.of<ThemeSettings>(context).dialogTextColor,
              fontSize: (20 * Provider.of<ThemeSettings>(context).fontSizeScale)
                  .clamp(16.0, 28.0),
              fontWeight: FontWeight.bold,
            ),
            contentTextStyle: TextStyle(
              color: Provider.of<ThemeSettings>(context).dialogTextColor,
              fontSize: (16 * Provider.of<ThemeSettings>(context).fontSizeScale)
                  .clamp(12.0, 24.0),
            ),
            title: Text('連続焙煎しますか？'),
            content: Text('焙煎機が温かいうちに次の焙煎が可能です。'),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() {
                    _mode = RoastMode.inputManualTime;
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: Provider.of<ThemeSettings>(
                    context,
                  ).fontColor1,
                ),
                child: Text('はい（連続焙煎）'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final useCooling =
                      await UserSettingsFirestoreService.getSetting(
                        'useCooling',
                      ) ??
                      false; // デフォルトをオフに変更
                  if (useCooling) {
                    _startBeanCooling(); // 豆冷ましタイマーを開始
                  } else {
                    _showCoolingDialog(); // 豆冷ましタイマーOFF時は直接アフターパージ
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: Provider.of<ThemeSettings>(
                    context,
                  ).fontColor1,
                ),
                child: Text(useCooling ? 'いいえ（豆冷ましタイマー）' : 'いいえ（アフターパージ）'),
              ),
            ],
          );
        },
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
          fontSize: (20 * Provider.of<ThemeSettings>(context).fontSizeScale)
              .clamp(16.0, 28.0),
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: Provider.of<ThemeSettings>(context).dialogTextColor,
          fontSize: (16 * Provider.of<ThemeSettings>(context).fontSizeScale)
              .clamp(12.0, 24.0),
        ),
        title: Text('お疲れ様でした！'),
        content: Text('機械をアフターパージに設定してください。\n焙煎時間の記録ができます。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, true);
              _loadInterstitialAdAndShow(() {
                setState(() {
                  _mode = RoastMode.idle;
                  _totalSeconds = 0;
                  _remainingSeconds = 0;
                });
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: Provider.of<ThemeSettings>(context).fontColor1,
            ),
            child: Text('記録に進む'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
              _loadInterstitialAdAndShow(() async {
                final usePreheat =
                    await UserSettingsFirestoreService.getSetting(
                      'usePreheat',
                    ) ??
                    true;
                final useRoast =
                    await UserSettingsFirestoreService.getSetting('useRoast') ??
                    true;
                final useCooling =
                    await UserSettingsFirestoreService.getSetting(
                      'useCooling',
                    ) ??
                    false; // デフォルトをオフに変更
                if (!usePreheat && !useRoast && useCooling) {
                  setState(() {
                    _mode = RoastMode.idle;
                    _totalSeconds = 0;
                    _remainingSeconds = 0;
                  });
                } else {
                  setState(() {
                    _mode = RoastMode.idle;
                    _totalSeconds = 0;
                    _remainingSeconds = 0;
                  });
                }
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: Provider.of<ThemeSettings>(context).fontColor1,
            ),
            child: Text('閉じる'),
          ),
        ],
      ),
    );

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
    _audioPlayer.dispose();
    _manualMinuteController.dispose();
    _beanController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 手動入力画面
    if (_mode == RoastMode.inputManualTime) {
      return Scaffold(
        appBar: AppBar(title: Text('焙煎時間入力')),
        body: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Provider.of<ThemeSettings>(context).backgroundColor2,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '焙煎時間を入力してください',
                        style: TextStyle(
                          fontSize:
                              18 *
                              Provider.of<ThemeSettings>(context).fontSizeScale,
                          fontWeight: FontWeight.bold,
                          color: Provider.of<ThemeSettings>(context).fontColor1,
                        ),
                      ),
                      SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: Color(0xFFF3EDE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextField(
                          controller: _manualMinuteController,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: false,
                            signed: false,
                          ),
                          style: TextStyle(
                            fontSize:
                                18 *
                                Provider.of<ThemeSettings>(
                                  context,
                                ).fontSizeScale,
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).inputTextColor,
                          ),
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.timer,
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).iconColor,
                            ),
                            labelText: '分数を入力',
                            labelStyle: TextStyle(
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).inputTextColor,
                            ),
                            hintStyle: TextStyle(
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).inputTextColor.withOpacity(0.6),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
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
                              fontSize: 15,
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
                            padding: EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
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
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFFF8225),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // キーボードを閉じる
                            FocusScope.of(context).unfocus();

                            setState(() {
                              _mode = RoastMode.idle;
                            });
                          },
                          icon: Icon(Icons.arrow_back),
                          label: Text('最初の画面に戻る'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).brightness ==
                                        Brightness.dark ||
                                    Provider.of<ThemeSettings>(
                                          context,
                                        ).backgroundColor.computeLuminance() <
                                        0.2
                                ? Colors.white
                                : Provider.of<ThemeSettings>(
                                    context,
                                  ).buttonColor,
                            side: BorderSide(
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark ||
                                      Provider.of<ThemeSettings>(
                                            context,
                                          ).backgroundColor.computeLuminance() <
                                          0.2
                                  ? Colors.white
                                  : Provider.of<ThemeSettings>(
                                      context,
                                    ).buttonColor,
                            ),
                            padding: EdgeInsets.symmetric(vertical: 13),
                            textStyle: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
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
        appBar: AppBar(
          title: Text('おすすめ焙煎入力'),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _refreshRecommendOptions,
              tooltip: 'データを更新',
            ),
          ],
        ),
        body: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(
            child: SingleChildScrollView(
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                color: Provider.of<ThemeSettings>(context).backgroundColor2,
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
                          color: Provider.of<ThemeSettings>(context).fontColor1,
                        ),
                      ),
                      SizedBox(height: 24),
                      // 豆の種類プルダウン
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).buttonColor.withOpacity(0.3),
                          ),
                        ),
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.coffee,
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).buttonColor,
                            ),
                            labelText: '豆の種類',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          value: _selectedRecommendBean,
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).buttonColor.withOpacity(0.3),
                          ),
                        ),
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.scale,
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).buttonColor,
                            ),
                            labelText: '重さ（g）',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          value: _selectedRecommendWeight,
                          items: _recommendWeightList
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text('${e}g'),
                                ),
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).buttonColor.withOpacity(0.3),
                          ),
                        ),
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.local_fire_department,
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).buttonColor,
                            ),
                            labelText: '煎り度',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          value: _selectedRecommendRoast,
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
                                      r.bean == bean &&
                                      r.roast == roast &&
                                      r.weight.toString() == weightText,
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
                              final t = (r.time).split(':');
                              int min = int.tryParse(t[0]) ?? 0;
                              int sec =
                                  int.tryParse(t.length > 1 ? t[1] : '0') ?? 0;
                              totalSeconds += min * 60 + sec;
                              count++;
                            }
                            if (count == 0) return;
                            int avgSeconds = (totalSeconds ~/ count);
                            int offset =
                                await UserSettingsFirestoreService.getSetting(
                                  'recommendedRoastOffsetSeconds',
                                );
                            int setSeconds = avgSeconds - offset;
                            if (setSeconds < 60) setSeconds = 60;
                            String format(int sec) =>
                                '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                backgroundColor: Provider.of<ThemeSettings>(
                                  context,
                                ).dialogBackgroundColor,
                                titleTextStyle: TextStyle(
                                  color: Provider.of<ThemeSettings>(
                                    context,
                                  ).dialogTextColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                contentTextStyle: TextStyle(
                                  color: Provider.of<ThemeSettings>(
                                    context,
                                  ).dialogTextColor,
                                  fontSize: 16,
                                ),
                                title: Text('おすすめ焙煎時間'),
                                content: Text(
                                  '平均焙煎時間: ${format(avgSeconds)}\n'
                                  'おすすめタイマー: ${format(setSeconds)}（平均−$offset秒）\n\n'
                                  'この時間でタイマーを開始しますか？',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          Provider.of<ThemeSettings>(
                                            context,
                                          ).fontColor1,
                                    ),
                                    child: Text('キャンセル'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          Provider.of<ThemeSettings>(
                                            context,
                                          ).fontColor1,
                                    ),
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
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _mode = RoastMode.inputManualTime;
                            });
                          },
                          icon: Icon(Icons.arrow_back),
                          label: Text('戻る'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).brightness ==
                                        Brightness.dark ||
                                    Provider.of<ThemeSettings>(
                                          context,
                                        ).backgroundColor.computeLuminance() <
                                        0.2
                                ? Colors.white
                                : Provider.of<ThemeSettings>(
                                    context,
                                  ).buttonColor,
                            side: BorderSide(
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark ||
                                      Provider.of<ThemeSettings>(
                                            context,
                                          ).backgroundColor.computeLuminance() <
                                          0.2
                                  ? Colors.white
                                  : Provider.of<ThemeSettings>(
                                      context,
                                    ).buttonColor,
                            ),
                            padding: EdgeInsets.symmetric(vertical: 15),
                            textStyle: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
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
        ? '🔥 予熱中・・・'
        : _mode == RoastMode.roasting
        ? '🔥 焙煎中・・・'
        : _mode == RoastMode.cooling
        ? '🫘 豆冷まし中・・・'
        : '⏱ 焙煎タイマー';

    // 予熱タイマーの設定値を取得
    final Future<List<bool>> useTimerSettingsFuture = (() async {
      final usePreheat =
          (await UserSettingsFirestoreService.getSetting('usePreheat')
              as bool?) ??
          true;
      final useRoast =
          (await UserSettingsFirestoreService.getSetting('useRoast')
              as bool?) ??
          true;
      final useCooling =
          (await UserSettingsFirestoreService.getSetting('useCooling')
              as bool?) ??
          false; // デフォルトをオフに変更
      return [usePreheat, useRoast, useCooling];
    })();

    return Scaffold(
      appBar: AppBar(
        title: const Text('焙煎タイマー'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            tooltip: 'タイマー設定',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RoastTimerSettingsPage()),
              ).then((_) {
                setState(() {}); // 設定変更後に画面をリビルド
              });
            },
          ),
        ],
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              top: 24.0,
              bottom: 24.0 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Provider.of<ThemeSettings>(context).backgroundColor2,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).fontColor1,
                          ),
                        ),
                        SizedBox(height: 28),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 240,
                              height: 240,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 13,
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).timerCircleColor,
                                backgroundColor: Provider.of<ThemeSettings>(
                                  context,
                                ).timerCircleColor.withOpacity(0.18),
                              ),
                            ),
                            Text(
                              _formatTime(_remainingSeconds),
                              style: TextStyle(
                                fontSize: 60,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).fontColor1,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 24),
                        FutureBuilder<List<bool>>(
                          future: useTimerSettingsFuture,
                          builder: (context, snapshot) {
                            final usePreheat = snapshot.data != null
                                ? snapshot.data![0]
                                : true;
                            final useRoast = snapshot.data != null
                                ? snapshot.data![1]
                                : true;
                            final useCooling = snapshot.data != null
                                ? snapshot.data![2]
                                : false; // デフォルトをオフに変更
                            if (_mode == RoastMode.idle) {
                              if (_justFinishedPreheat &&
                                  !useRoast &&
                                  useCooling) {
                                // 予熱完了直後・焙煎タイマーOFF・豆冷ましタイマーON時は豆冷ましタイマーボタン
                                return SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _startBeanCooling,
                                    icon: Icon(Icons.ac_unit, size: 20),
                                    label: Text(
                                      '豆冷ましタイマーを開始',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF00B8D4),
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                        vertical: 15,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 4,
                                    ),
                                  ),
                                );
                              } else if (usePreheat) {
                                // 予熱タイマーON時は予熱開始ボタン
                                return SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _startPreheating,
                                    icon: Icon(
                                      Icons.local_fire_department,
                                      size: 20,
                                    ),
                                    label: Text(
                                      '予熱開始',
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
                                      padding: EdgeInsets.symmetric(
                                        vertical: 15,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 4,
                                    ),
                                  ),
                                );
                              } else if (!usePreheat &&
                                  !useRoast &&
                                  useCooling) {
                                // 予熱タイマーOFF・焙煎タイマーOFF・豆冷ましタイマーON時は豆冷ましタイマーボタン
                                return SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _startBeanCooling,
                                    icon: Icon(Icons.ac_unit, size: 20),
                                    label: Text(
                                      '豆冷ましタイマーを開始',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF00B8D4),
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                        vertical: 15,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 4,
                                    ),
                                  ),
                                );
                              } else {
                                // 予熱タイマーOFF時は手動・おすすめ焙煎ボタン
                                return Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _mode = RoastMode.inputManualTime;
                                          });
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
                                          backgroundColor:
                                              Theme.of(context)
                                                  .elevatedButtonTheme
                                                  .style
                                                  ?.backgroundColor
                                                  ?.resolve({}) ??
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                          foregroundColor:
                                              Theme.of(context)
                                                  .elevatedButtonTheme
                                                  .style
                                                  ?.foregroundColor
                                                  ?.resolve({}) ??
                                              Colors.white,
                                          padding: EdgeInsets.symmetric(
                                            vertical: 15,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          elevation: 4,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 12),
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
                                          'おすすめ焙煎でスタート',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFFFF8225),
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                            vertical: 15,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          elevation: 4,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                            } else {
                              // idle以外は従来通り
                              return SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isPaused
                                      ? _resumeTimer
                                      : _pauseTimer,
                                  icon: Icon(
                                    _isPaused ? Icons.play_arrow : Icons.pause,
                                    size: 20,
                                  ),
                                  label: Text(
                                    _isPaused ? '再開' : '一時停止',
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
                              );
                            }
                          },
                        ),
                        SizedBox(height: 16),
                        TextButton(
                          onPressed: _totalSeconds == 0 ? null : _skipTime,
                          child: Text(
                            '⏩ スキップ',
                            style: TextStyle(
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).fontColor1,
                              fontSize: 14,
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
      ),
    );
  }
}
