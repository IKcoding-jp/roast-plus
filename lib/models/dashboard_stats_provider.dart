import 'package:flutter/widgets.dart';
import 'dart:async';
import '../services/dashboard_stats_service.dart';
import 'dart:developer' as developer;

class DashboardStatsProvider extends ChangeNotifier {
  Map<String, dynamic> _statsData = {};
  bool _isLoading = false;
  DateTime? _lastUpdateTime;

  Map<String, dynamic> get statsData => _statsData;
  bool get isLoading => _isLoading;
  DateTime? get lastUpdateTime => _lastUpdateTime;

  /// 統計データを初期化（軽量化）
  Future<void> initialize() async {
    // 初期化時は軽量に処理し、必要時にのみデータを読み込む
    _isLoading = false;
    _statsData = {
      'totalRoastingTime': 0,
      'totalRoastingHours': 0,
      'totalRoastingMinutes': 0,
      'attendanceDays': 0,
      'dripPackCount': 0,
      'completedTasks': 0,
    };

    // ビルド完了後にバックグラウンドで実際のデータを取得
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadStatsInBackground();
    });
  }

  /// 統計データを読み込み
  Future<void> loadStats() async {
    _isLoading = true;
    notifyListeners();

    try {
      final statsService = DashboardStatsService.instance;
      _statsData = await statsService.getStatsData();
      _lastUpdateTime = DateTime.now();
    } catch (e) {
      developer.log('統計データ読み込みエラー: $e', name: 'DashboardStatsProvider');
      _statsData = {
        'totalRoastingTime': 0,
        'totalRoastingHours': 0,
        'totalRoastingMinutes': 0,
        'attendanceDays': 0,
        'dripPackCount': 0,
        'completedTasks': 0,
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// バックグラウンドで統計データを読み込み
  Future<void> loadStatsInBackground() async {
    try {
      final statsService = DashboardStatsService.instance;
      final newData = await statsService.getStatsData();

      if (mounted) {
        // フレーム完了後にnotifyListenersを呼ぶ
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _statsData = newData;
            _lastUpdateTime = DateTime.now();
            notifyListeners();
          }
        });
      }
    } catch (e) {
      developer.log('バックグラウンド統計データ読み込みエラー: $e', name: 'DashboardStatsProvider');
    }
  }

  /// Providerがmountされているかチェック
  bool get mounted => hasListeners;

  /// 統計データを強制リフレッシュ
  Future<void> refreshStats() async {
    try {
      final statsService = DashboardStatsService.instance;
      await statsService.refreshStats();
      await loadStats();
    } catch (e) {
      developer.log('統計データリフレッシュエラー: $e', name: 'DashboardStatsProvider');
    }
  }

  /// 焙煎記録追加時の更新（軽量化）
  Future<void> onRoastRecordAdded() async {
    // 頻繁な更新を避けるため、デバウンス処理
    _scheduleUpdate();
  }

  /// 出勤記録更新時の更新（軽量化）
  Future<void> onAttendanceUpdated() async {
    _scheduleUpdate();
  }

  /// ドリップパック記録追加時の更新（軽量化）
  Future<void> onDripPackAdded() async {
    _scheduleUpdate();
  }

  Future<void> onTodoCompleted() async {
    _scheduleUpdate();
  }

  Timer? _updateTimer;

  /// デバウンス処理で統計更新をスケジュール
  void _scheduleUpdate() {
    _updateTimer?.cancel();
    _updateTimer = Timer(Duration(seconds: 2), () {
      if (mounted) {
        // フレーム完了後に実行
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            loadStatsInBackground();
          }
        });
      }
    });
  }

  /// データが古い場合の自動更新チェック
  bool shouldAutoUpdate() {
    if (_lastUpdateTime == null) return true;

    final now = DateTime.now();
    final difference = now.difference(_lastUpdateTime!);

    // 5分以上経過している場合は更新
    return difference.inMinutes >= 5;
  }

  /// 自動更新チェックと実行
  Future<void> checkAndAutoUpdate() async {
    if (shouldAutoUpdate()) {
      await loadStats();
    }
  }

  /// 焙煎時間の表示フォーマット
  String formatRoastingTime(int totalMinutes) {
    if (totalMinutes == 0) return '0分';

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0) {
      if (minutes > 0) {
        return '$hours時間$minutes分';
      } else {
        return '$hours時間';
      }
    } else {
      return '$minutes分';
    }
  }

  /// 統計データの概要情報
  Map<String, String> getStatsSummary() {
    return {
      '累積焙煎時間': formatRoastingTime(_statsData['totalRoastingTime'] ?? 0),
      '累積出勤日数': '${_statsData['attendanceDays'] ?? 0}日',
      'ドリップパック': '${_statsData['dripPackCount'] ?? 0}袋',
      '完了タスク': '${_statsData['completedTasks'] ?? 0}件',
    };
  }

  /// ログアウト時にプロバイダー情報をクリア
  void clearOnLogout() {
    developer.log(
      'DashboardStatsProvider: ログアウト時のクリア開始',
      name: 'DashboardStatsProvider',
    );

    _statsData.clear();
    _isLoading = false;
    _lastUpdateTime = null;

    // タイマーをキャンセル
    _updateTimer?.cancel();
    _updateTimer = null;

    developer.log(
      'DashboardStatsProvider: ログアウト時のクリア完了',
      name: 'DashboardStatsProvider',
    );
    notifyListeners();
  }
}
