import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/sound_utils.dart';
import '../models/theme_settings.dart';

class TodoNotificationService {
  static final TodoNotificationService _instance =
      TodoNotificationService._internal();
  factory TodoNotificationService() => _instance;
  TodoNotificationService._internal();

  Timer? _checkTimer;
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  Set<String> _notifiedTodos = {};

  // グローバルナビゲーションキー（どの画面からでもダイアログを表示するため）
  GlobalKey<NavigatorState>? _navigatorKey;

  DateTime? _lastCheckTime;

  // ナビゲーションキーを設定
  void setNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  /// 時間文字列を24時間形式に正規化
  String _normalizeTimeTo24Hour(String time) {
    if (time.contains('AM') || time.contains('PM')) {
      // 12時間形式の場合
      final timeParts = time.split(' ');
      if (timeParts.length == 2) {
        final timeStr = timeParts[0];
        final period = timeParts[1];
        final timeComponents = timeStr.split(':');
        if (timeComponents.length == 2) {
          int hour = int.tryParse(timeComponents[0]) ?? 0;
          int minute = int.tryParse(timeComponents[1]) ?? 0;

          // AM/PMを24時間形式に変換
          if (period == 'PM' && hour != 12) {
            hour += 12;
          } else if (period == 'AM' && hour == 12) {
            hour = 0;
          }

          return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        }
      }
    }
    // 既に24時間形式または無効な形式の場合はそのまま返す
    return time;
  }

  /// 文字列の時刻をDateTimeとしてパース（今日の日付で）
  DateTime? _parseTimeToToday(String time) {
    try {
      final now = DateTime.now();
      if (time.contains('AM') || time.contains('PM')) {
        // 12時間形式
        final timeParts = time.split(' ');
        if (timeParts.length == 2) {
          final timeStr = timeParts[0];
          final period = timeParts[1];
          final timeComponents = timeStr.split(':');
          if (timeComponents.length == 2) {
            int hour = int.tryParse(timeComponents[0]) ?? 0;
            int minute = int.tryParse(timeComponents[1]) ?? 0;
            if (period == 'PM' && hour != 12) hour += 12;
            if (period == 'AM' && hour == 12) hour = 0;
            return DateTime(now.year, now.month, now.day, hour, minute);
          }
        }
      } else {
        // 24時間形式
        final parts = time.split(':');
        if (parts.length >= 2) {
          int hour = int.tryParse(parts[0]) ?? 0;
          int minute = int.tryParse(parts[1]) ?? 0;
          return DateTime(now.year, now.month, now.day, hour, minute);
        }
      }
    } catch (_) {}
    return null;
  }

  /// FirestoreからTODOリストを取得
  Future<List<Map<String, dynamic>>> _getTodosFromFirestore() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return [];

      final today = DateTime.now();
      final docId =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('todoList')
          .doc(docId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final todos = data['todos'] as List<dynamic>?;
        if (todos != null) {
          return todos.cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {
      print('FirestoreからTODO取得エラー: $e');
    }
    return [];
  }

  /// SharedPreferencesからTODOリストを取得
  Future<List<String>> _getTodosFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('todoList') ?? [];
    } catch (e) {
      print('SharedPreferencesからTODO取得エラー: $e');
      return [];
    }
  }

  /// 通知サービスを開始
  void startNotificationService() {
    print('TodoNotificationService: startNotificationService() が呼ばれました');
    print('TodoNotificationService: 通知サービス開始');

    // AudioPlayerを遅延初期化
    _audioPlayer = AudioPlayer();

    // 最初のチェック間隔を計算（00秒または30秒に合わせる）
    print('TodoNotificationService: _scheduleNextCheck() を呼び出します');
    _scheduleNextCheck();

    _lastCheckTime = DateTime.now().subtract(const Duration(seconds: 30));
    print('TodoNotificationService: 通知サービス開始完了');
  }

  /// 次のチェック時刻をスケジュール（00秒または30秒に合わせる）
  void _scheduleNextCheck() {
    final now = DateTime.now();
    final seconds = now.second;
    
    print('TodoNotificationService: 現在時刻 ${now.hour}:${now.minute}:${now.second}');
    
    // 次の00秒または30秒までの秒数を計算
    int secondsToNext;
    if (seconds < 30) {
      // 次の30秒まで
      secondsToNext = 30 - seconds;
      print('TodoNotificationService: 次の30秒まで ${secondsToNext}秒待機');
    } else {
      // 次の00秒まで（次の分の00秒）
      secondsToNext = 60 - seconds;
      print('TodoNotificationService: 次の00秒まで ${secondsToNext}秒待機');
    }
    
    print('TodoNotificationService: 次のチェックまで ${secondsToNext}秒');
    print('TodoNotificationService: 予定チェック時刻 ${now.add(Duration(seconds: secondsToNext)).hour}:${now.add(Duration(seconds: secondsToNext)).minute}:${now.add(Duration(seconds: secondsToNext)).second}');
    
    _checkTimer?.cancel();
    _checkTimer = Timer(Duration(seconds: secondsToNext), () {
      print('TodoNotificationService: 最初のチェック実行');
      _checkTodoNotifications();
      // その後は30秒ごとにチェック
      _checkTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        print('TodoNotificationService: 定期チェック実行');
        _checkTodoNotifications();
      });
    });
  }

  /// 通知サービスを停止
  void stopNotificationService() {
    print('TodoNotificationService: 通知サービス停止開始');
    _checkTimer?.cancel();
    _checkTimer = null;
    _audioPlayer?.dispose();
    _audioPlayer = null;
    _navigatorKey = null;
    print('TodoNotificationService: 通知サービス停止完了');
  }

  /// TODO通知をチェック
  Future<void> _checkTodoNotifications() async {
    try {
      // チェック開始時の時刻を保存（前回チェック時刻として使用）
      final lastCheck = _lastCheckTime ?? DateTime.now().subtract(const Duration(seconds: 30));
      
      // FirestoreとSharedPreferencesの両方からTODOを取得
      final firestoreTodos = await _getTodosFromFirestore();
      final sharedPrefsTodos = await _getTodosFromSharedPreferences();

      final now = DateTime.now();
      print('TODO通知チェック: 現在時刻 ${now.hour}:${now.minute}:${now.second}');
      print('TODO通知チェック: 前回チェック時刻 ${lastCheck.hour}:${lastCheck.minute}:${lastCheck.second}');
      print('TODO通知チェック: Firestore TODO数 ${firestoreTodos.length}');
      print('TODO通知チェック: SharedPreferences TODO数 ${sharedPrefsTodos.length}');

      // FirestoreのTODOをチェック
      for (final todo in firestoreTodos) {
        final title = todo['title'] as String? ?? '';
        final isDone = todo['isDone'] as bool? ?? false;
        final time = todo['time'] as String? ?? '';

        print('TODO通知チェック: $title - 時刻: $time, 完了: $isDone');

        if (time.isNotEmpty && !isDone) {
          final todoKey = '$title|$time';
          final today = DateTime.now().toIso8601String().split('T')[0];
          final notifiedKey = '$todoKey|$today';

          // 分単位で一致するか判定
          final todoDateTime = _parseTimeToToday(time);
          if (!_notifiedTodos.contains(notifiedKey) &&
              todoDateTime != null &&
              now.year == todoDateTime.year &&
              now.month == todoDateTime.month &&
              now.day == todoDateTime.day &&
              now.hour == todoDateTime.hour &&
              now.minute == todoDateTime.minute) {
            
            // 前回チェック時刻と今回チェック時刻の間に「00秒」が含まれているかチェック
            final todoTimeInSeconds = todoDateTime.hour * 3600 + todoDateTime.minute * 60;
            final lastCheckInSeconds = lastCheck.hour * 3600 + lastCheck.minute * 60 + lastCheck.second;
            final nowInSeconds = now.hour * 3600 + now.minute * 60 + now.second;
            
            print('TODO通知判定: 前回チェック ${lastCheckInSeconds}秒, TODO時刻 ${todoTimeInSeconds}秒, 今回チェック ${nowInSeconds}秒');
            
            // 前回チェック時刻 < TODO時刻 <= 今回チェック時刻 かつ TODO時刻が00秒
            if (lastCheckInSeconds < todoTimeInSeconds && 
                todoTimeInSeconds <= nowInSeconds && 
                todoDateTime.second == 0) {
              print('TODO通知: $title の時刻になりました！（00秒ちょうど）');
              print('TODO通知: 前回チェック ${lastCheck.hour}:${lastCheck.minute}:${lastCheck.second}');
              print('TODO通知: TODO時刻 ${todoDateTime.hour}:${todoDateTime.minute}:${todoDateTime.second}');
              print('TODO通知: 今回チェック ${now.hour}:${now.minute}:${now.second}');
              await _playNotificationSound();
              await _showTodoNotificationDialog(title, time);
              _notifiedTodos.add(notifiedKey);
              _saveNotificationHistory();
            }
          }
        }
      }

      // SharedPreferencesのTODOもチェック（重複を避けるため、既に通知済みのものはスキップ）
      for (final todoStr in sharedPrefsTodos) {
        final parts = todoStr.split('|');
        if (parts.length >= 3) {
          final title = parts[0];
          final isDone = parts.length > 1 && parts[1] == 'true';
          final time = parts[2];

          // Firestoreで既にチェック済みの場合はスキップ
          bool alreadyChecked = false;
          for (final firestoreTodo in firestoreTodos) {
            final firestoreTitle = firestoreTodo['title'] as String? ?? '';
            final firestoreTime = firestoreTodo['time'] as String? ?? '';
            if (title == firestoreTitle && time == firestoreTime) {
              alreadyChecked = true;
              break;
            }
          }

          if (!alreadyChecked && time.isNotEmpty && !isDone) {
            final todoKey = '$title|$time';
            final today = DateTime.now().toIso8601String().split('T')[0];
            final notifiedKey = '$todoKey|$today';

            // 分単位で一致するか判定
            final todoDateTime = _parseTimeToToday(time);
            if (!_notifiedTodos.contains(notifiedKey) &&
                todoDateTime != null &&
                now.year == todoDateTime.year &&
                now.month == todoDateTime.month &&
                now.day == todoDateTime.day &&
                now.hour == todoDateTime.hour &&
                now.minute == todoDateTime.minute) {
              
              // 前回チェック時刻と今回チェック時刻の間に「00秒」が含まれているかチェック
              final todoTimeInSeconds = todoDateTime.hour * 3600 + todoDateTime.minute * 60;
              final lastCheckInSeconds = lastCheck.hour * 3600 + lastCheck.minute * 60 + lastCheck.second;
              final nowInSeconds = now.hour * 3600 + now.minute * 60 + now.second;
              
              // 前回チェック時刻 < TODO時刻 <= 今回チェック時刻 かつ TODO時刻が00秒
              if (lastCheckInSeconds < todoTimeInSeconds && 
                  todoTimeInSeconds <= nowInSeconds && 
                  todoDateTime.second == 0) {
                print('TODO通知: $title の時刻になりました！（00秒ちょうど）');
                print('TODO通知: 前回チェック ${lastCheck.hour}:${lastCheck.minute}:${lastCheck.second}');
                print('TODO通知: TODO時刻 ${todoDateTime.hour}:${todoDateTime.minute}:${todoDateTime.second}');
                print('TODO通知: 今回チェック ${now.hour}:${now.minute}:${now.second}');
                await _playNotificationSound();
                await _showTodoNotificationDialog(title, time);
                _notifiedTodos.add(notifiedKey);
                _saveNotificationHistory();
              }
            }
          }
        }
      }
      
      // チェック終了時に今回の時刻を保存
      _lastCheckTime = now;
    } catch (e) {
      print('TODO通知チェックエラー: $e');
    }
  }

  /// TODO通知を表示
  Future<void> _showTodoNotificationDialog(
    String title,
    String time, {
    int retry = 0,
  }) async {
    if (_navigatorKey?.currentContext == null) {
      print('ナビゲーションキーが設定されていないため、通知を表示できません（リトライ$retry）');
      if (retry < 5) {
        await Future.delayed(Duration(milliseconds: 500));
        return _showTodoNotificationDialog(title, time, retry: retry + 1);
      }
      return;
    }

    try {
      // テーマ設定を取得
      final themeSettings = Provider.of<ThemeSettings>(
        _navigatorKey!.currentContext!,
        listen: false,
      );

      // SnackBarを画面上部に表示
      ScaffoldMessenger.of(_navigatorKey!.currentContext!).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.notification_important,
                  color: themeSettings.buttonColor,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TODO通知',
                      style: TextStyle(
                        fontSize: (14 * themeSettings.fontSizeScale).clamp(
                          10.0,
                          20.0,
                        ),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '$title ($time)',
                      style: TextStyle(
                        fontSize: (16 * themeSettings.fontSizeScale).clamp(
                          12.0,
                          24.0,
                        ),
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: themeSettings.buttonColor,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            top: MediaQuery.of(_navigatorKey!.currentContext!).padding.top + 10,
            left: 16,
            right: 16,
            bottom: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
        ),
      );
    } catch (e) {
      print('TODO通知表示エラー: $e');
    }
  }

  /// 通知音を再生
  Future<void> _playNotificationSound() async {
    try {
      print('通知音再生開始');

      // 既に再生中の場合は停止
      if (_isPlaying) {
        await _audioPlayer?.stop();
        _isPlaying = false;
      }

      // 通知音設定を確認
      final isSoundEnabled = await SoundUtils.isNotificationSoundEnabled();
      print('通知音有効: $isSoundEnabled');
      if (!isSoundEnabled) {
        print('通知音が無効のため再生しません');
        return;
      }

      final selectedSound = await SoundUtils.getSelectedNotificationSound();
      final volume = await SoundUtils.getNotificationVolume();
      print('選択された通知音: $selectedSound, 音量: $volume');

      _isPlaying = true;
      await _audioPlayer?.setVolume(volume);
      // 修正: selectedSoundが既にフルパスの場合はそのまま渡す
      await _audioPlayer?.play(AssetSource(selectedSound));
      print('通知音再生中...');

      // 3秒後に停止
      Timer(const Duration(seconds: 3), () async {
        if (_isPlaying) {
          await _audioPlayer?.stop();
          _isPlaying = false;
          print('通知音停止');
        }
      });
    } catch (e) {
      print('通知音再生エラー: $e');
      _isPlaying = false;
    }
  }

  /// 通知履歴をクリア（新しい日になった時など）
  void clearNotificationHistory() {
    _notifiedTodos.clear();
  }

  /// 通知履歴を保存
  Future<void> _saveNotificationHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'todo_notification_history',
        _notifiedTodos.toList(),
      );
    } catch (e) {
      print('通知履歴保存エラー: $e');
    }
  }

  /// 通知履歴を読み込み
  Future<void> _loadNotificationHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('todo_notification_history') ?? [];
      _notifiedTodos = saved.toSet();

      // 古い通知履歴をクリア（前日以前のもの）
      final today = DateTime.now().toIso8601String().split('T')[0];
      _notifiedTodos.removeWhere((key) {
        final parts = key.split('|');
        if (parts.length >= 4) {
          final keyDate = parts[3];
          return keyDate != today;
        }
        return true; // 日付がない古い形式は削除
      });

      _saveNotificationHistory(); // クリア後の履歴を保存
    } catch (e) {
      print('通知履歴読み込みエラー: $e');
    }
  }

  /// 特定のTODOの通知履歴をクリア
  void clearTodoNotification(String title, String time) {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final todoKey = '$title|$time|$today';
    _notifiedTodos.remove(todoKey);
    _saveNotificationHistory();
  }
}
