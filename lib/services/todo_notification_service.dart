import 'dart:async';
import 'dart:developer' as developer;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/sound_utils.dart';
import '../models/theme_settings.dart';
import 'user_settings_firestore_service.dart';

class TodoNotificationService {
  static final TodoNotificationService _instance =
      TodoNotificationService._internal();
  factory TodoNotificationService() => _instance;
  TodoNotificationService._internal();

  static const String _logName = 'TodoNotificationService';
  static void _logInfo(String message) =>
      developer.log(message, name: _logName);
  static void _logWarn(String message) =>
      developer.log(message, name: _logName);
  static void _logError(
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) => developer.log(
    message,
    name: _logName,
    error: error,
    stackTrace: stackTrace,
  );

  Timer? _checkTimer;
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  final Set<String> _notifiedTodos = {};

  // グローバルナビゲーションキー（どの画面からでもダイアログを表示するため）
  GlobalKey<NavigatorState>? _navigatorKey;

  // ナビゲーションキーを設定
  void setNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
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
          return todos.map((todo) => Map<String, dynamic>.from(todo)).toList();
        }
      }
    } catch (e) {
      _logError('FirebaseからTODO取得エラー', e);
    }
    return [];
  }

  /// FirebaseからTODOリストを取得
  Future<List<String>> _getTodosFromFirebase() async {
    try {
      final dynamic raw = await UserSettingsFirestoreService.getSetting(
        'todo_list',
        defaultValue: [],
      );

      if (raw is List) {
        // 動的リストを厳密な List<String> に変換
        return raw.map((e) => e.toString()).toList();
      }
      return [];
    } catch (e) {
      _logError('FirebaseからTODO取得エラー', e);
      return [];
    }
  }

  /// 通知サービスを開始
  void startNotificationService() {
    _logInfo('startNotificationService() が呼ばれました');
    _logInfo('通知サービス開始');

    // AudioPlayerを遅延初期化
    _audioPlayer = AudioPlayer();

    // まず現在時刻の秒数を取得し、次の00秒まで待ってから毎分チェック
    void scheduleNextMinuteCheck() {
      final now = DateTime.now();
      final int secondsToNextMinute = 60 - now.second;
      Future.delayed(Duration(seconds: secondsToNextMinute), () {
        _checkTodoNotifications();
        _checkTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
          _checkTodoNotifications();
        });
      });
    }

    scheduleNextMinuteCheck();

    _logInfo('通知サービス開始完了');
  }

  /// 通知サービスを停止
  void stopNotificationService() {
    _logInfo('通知サービス停止開始');
    _checkTimer?.cancel();
    _checkTimer = null;
    _audioPlayer?.dispose();
    _audioPlayer = null;
    _navigatorKey = null;
    _logInfo('通知サービス停止完了');
  }

  /// タスク通知をチェック
  Future<void> _checkTodoNotifications() async {
    try {
      // FirestoreとFirebaseの両方からTODOを取得
      final firestoreTodos = await _getTodosFromFirestore();
      final firebaseTodos = await _getTodosFromFirebase();

      final now = DateTime.now();
      _logInfo('TODO通知チェック: 現在時刻 ${now.hour}:${now.minute}:${now.second}');
      _logInfo('TODO通知チェック: Firestore TODO数 ${firestoreTodos.length}');
      _logInfo('TODO通知チェック: Firebase TODO数 ${firebaseTodos.length}');

      // FirestoreのTODOをチェック
      for (final todo in firestoreTodos) {
        final title = todo['title'] as String? ?? '';
        final isDone = todo['isDone'] as bool? ?? false;
        final time = todo['time'] as String? ?? '';

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
              now.minute == todoDateTime.minute &&
              now.second == 0) {
            // 現在時刻が00秒で、TODO時刻と一致
            _logInfo('TODO通知: $title の時刻になりました！（時刻一致）');
            await _playNotificationSound();
            await _showTodoNotificationDialog(title, time);
            _notifiedTodos.add(notifiedKey);
            _saveNotificationHistory();
          }
        }
      }

      // FirebaseのTODOもチェック（重複を避けるため、既に通知済みのものはスキップ）
      for (final todoStr in firebaseTodos) {
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
                now.minute == todoDateTime.minute &&
                now.second == 0) {
              // 現在時刻が00秒で、TODO時刻と一致
              _logInfo('TODO通知: $title の時刻になりました！（時刻一致）');
              await _playNotificationSound();
              await _showTodoNotificationDialog(title, time);
              _notifiedTodos.add(notifiedKey);
              _saveNotificationHistory();
            }
          }
        }
      }
    } catch (e) {
      _logError('TODO通知チェックエラー', e);
    }
  }

  /// タスク通知を表示
  Future<void> _showTodoNotificationDialog(
    String title,
    String time, {
    int retry = 0,
  }) async {
    if (_navigatorKey?.currentContext == null) {
      _logWarn('ナビゲーションキーが設定されていないため、通知を表示できません（リトライ$retry）');
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
      _logError('TODO通知表示エラー', e);
    }
  }

  /// 通知音を再生
  Future<void> _playNotificationSound() async {
    try {
      _logInfo('通知音再生開始');

      // 既に再生中の場合は停止
      if (_isPlaying) {
        await _audioPlayer?.stop();
        _isPlaying = false;
      }

      // 通知音設定を確認
      final isSoundEnabled = await SoundUtils.isNotificationSoundEnabled();
      _logInfo('通知音有効: $isSoundEnabled');
      if (!isSoundEnabled) {
        _logInfo('通知音が無効のため再生しません');
        return;
      }

      final selectedSound = await SoundUtils.getSelectedNotificationSound();
      final volume = await SoundUtils.getNotificationVolume();
      _logInfo('選択された通知音: $selectedSound, 音量: $volume');

      _isPlaying = true;
      // 通知ストリームを使用するように設定（通知音量で制御）
      try {
        await _audioPlayer?.setPlayerMode(PlayerMode.lowLatency);
        await _audioPlayer?.setVolume(volume);
        // 修正: selectedSoundが既にフルパスの場合はそのまま渡す
        await _audioPlayer?.play(AssetSource(selectedSound));
      } catch (e) {
        debugPrint('AudioPlayer設定エラー: $e');
        // フォールバック: デフォルト設定で再生
        await _audioPlayer?.setVolume(volume);
        await _audioPlayer?.play(AssetSource(selectedSound));
      }
      _logInfo('通知音再生中...');

      // 3秒後に停止
      Timer(const Duration(seconds: 3), () async {
        if (_isPlaying) {
          await _audioPlayer?.stop();
          _isPlaying = false;
          _logInfo('通知音停止');
        }
      });
    } catch (e) {
      _logError('通知音再生エラー', e);
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
      await UserSettingsFirestoreService.saveSetting(
        'todo_notification_history',
        _notifiedTodos.toList(),
      );
    } catch (e) {
      _logError('通知履歴保存エラー', e);
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
