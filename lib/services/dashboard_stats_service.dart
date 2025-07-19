import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../models/roast_record.dart';
import '../models/attendance_models.dart';
import '../services/roast_record_firestore_service.dart';
import '../services/attendance_firestore_service.dart';
import '../services/drip_counter_firestore_service.dart';

class DashboardStatsService {
  static final DashboardStatsService _instance =
      DashboardStatsService._internal();
  factory DashboardStatsService() => _instance;
  DashboardStatsService._internal();

  static DashboardStatsService get instance => _instance;

  // キャッシュ
  static Map<String, dynamic>? _cachedStats;
  static DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(
    minutes: 5,
  ); // 5分間キャッシュ有効

  /// 統計データを取得（キャッシュ対応）
  Future<Map<String, dynamic>> getStatsData() async {
    try {
      // キャッシュチェック
      if (_cachedStats != null &&
          _lastCacheTime != null &&
          DateTime.now()
                  .difference(_lastCacheTime!)
                  .compareTo(_cacheValidDuration) <
              0) {
        print('DashboardStatsService: キャッシュからデータを返します');
        return _cachedStats!;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return _getDefaultStats();
      }

      print('DashboardStatsService: 統計データを並列取得開始');
      final startTime = DateTime.now();

      // 軽量化された並列処理で統計データを取得
      final results = await Future.wait([
        _getTotalRoastingTimeOptimized(),
        _getAttendanceDaysOptimized(),
        _getDripPackCountOptimized(),
        _getCompletedTasksOptimized(),
      ]);

      final stats = {
        'totalRoastingTime': results[0],
        'totalRoastingHours': results[0] ~/ 60, // 時間
        'totalRoastingMinutes': results[0] % 60, // 分
        'attendanceDays': results[1],
        'dripPackCount': results[2],
        'completedTasks': results[3],
      };

      // キャッシュに保存
      _cachedStats = stats;
      _lastCacheTime = DateTime.now();

      final endTime = DateTime.now();
      final processingTime = endTime.difference(startTime).inMilliseconds;
      print('DashboardStatsService: 統計データ取得完了 (${processingTime}ms)');

      return stats;
    } catch (e) {
      print('統計データ取得エラー: $e');
      return _getDefaultStats();
    }
  }

  /// デフォルトの統計データ
  Map<String, dynamic> _getDefaultStats() {
    return {
      'totalRoastingTime': 0,
      'totalRoastingHours': 0,
      'totalRoastingMinutes': 0,
      'attendanceDays': 0,
      'dripPackCount': 0,
      'completedTasks': 0,
    };
  }

  /// 最適化された総焙煎時間を取得（分）
  Future<int> _getTotalRoastingTimeOptimized() async {
    try {
      int totalMinutes = 0;

      // まずキャッシュから確認
      final prefs = await SharedPreferences.getInstance();
      final cachedTime = prefs.getInt('cached_total_roasting_time');
      final cacheTimestamp = prefs.getInt('roasting_time_cache_timestamp');

      if (cachedTime != null && cacheTimestamp != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTimestamp;
        if (cacheAge < Duration(hours: 1).inMilliseconds) {
          // 1時間キャッシュ
          print('DashboardStatsService: 焙煎時間をキャッシュから取得: ${cachedTime}分');
          return cachedTime;
        }
      }

      // Firestoreから軽量クエリで取得（最新100件のみ）
      try {
        final records = await RoastRecordFirestoreService.getRecords(
          limit: 100,
        );

        for (final record in records) {
          final timeString = record.time;
          totalMinutes += _parseTimeToMinutes(timeString);
        }

        // さらに古いデータがある場合は集計クエリを使用（実装は後で）
        // 現在は最新100件のみで概算値を提供

        // キャッシュに保存
        await prefs.setInt('cached_total_roasting_time', totalMinutes);
        await prefs.setInt(
          'roasting_time_cache_timestamp',
          DateTime.now().millisecondsSinceEpoch,
        );

        print('DashboardStatsService: 焙煎時間を計算: ${totalMinutes}分');
      } catch (e) {
        print('Firestore焙煎記録取得エラー: $e');
        // フォールバック: ローカルデータから取得
        totalMinutes = await _getRoastingTimeFromLocal(prefs);
      }

      return totalMinutes;
    } catch (e) {
      print('総焙煎時間計算エラー: $e');
      return 0;
    }
  }

  /// 最適化された出勤日数を取得
  Future<int> _getAttendanceDaysOptimized() async {
    try {
      // キャッシュから確認
      final prefs = await SharedPreferences.getInstance();
      final cachedDays = prefs.getInt('cached_attendance_days');
      final cacheTimestamp = prefs.getInt('attendance_cache_timestamp');

      if (cachedDays != null && cacheTimestamp != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTimestamp;
        if (cacheAge < Duration(hours: 6).inMilliseconds) {
          // 6時間キャッシュ
          print('DashboardStatsService: 出勤日数をキャッシュから取得: ${cachedDays}日');
          return cachedDays;
        }
      }

      Set<String> uniqueDates = {};

      try {
        // 軽量化: 最近3ヶ月分のみ取得
        final currentDate = DateTime.now();
        final startDate = DateTime(
          currentDate.year,
          currentDate.month - 3,
          currentDate.day,
        );

        final summaries =
            await AttendanceFirestoreService.getAttendanceByDateRange(
              startDate,
              currentDate,
            );

        for (final summary in summaries) {
          final presentRecords = summary.records.where(
            (record) => record.status == AttendanceStatus.present,
          );

          if (presentRecords.isNotEmpty) {
            uniqueDates.add(summary.dateKey);
          }
        }

        // キャッシュに保存
        final result = uniqueDates.length;
        await prefs.setInt('cached_attendance_days', result);
        await prefs.setInt(
          'attendance_cache_timestamp',
          DateTime.now().millisecondsSinceEpoch,
        );

        print('DashboardStatsService: 出勤日数を計算: ${result}日');
        return result;
      } catch (e) {
        print('Firestore出勤記録取得エラー: $e');
        return await _getAttendanceDaysFromLocal(prefs);
      }
    } catch (e) {
      print('出勤日数計算エラー: $e');
      return 0;
    }
  }

  /// 最適化されたドリップパック数を取得
  Future<int> _getDripPackCountOptimized() async {
    try {
      // キャッシュから確認
      final prefs = await SharedPreferences.getInstance();
      final cachedCount = prefs.getInt('cached_drip_pack_count');
      final cacheTimestamp = prefs.getInt('drip_pack_cache_timestamp');

      if (cachedCount != null && cacheTimestamp != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTimestamp;
        if (cacheAge < Duration(hours: 1).inMilliseconds) {
          // 1時間キャッシュ
          print('DashboardStatsService: ドリップパック数をキャッシュから取得: ${cachedCount}袋');
          return cachedCount;
        }
      }

      int totalCount = 0;

      try {
        // 軽量化: 最近1ヶ月分のみ取得
        final currentDate = DateTime.now();
        final startDate = DateTime(
          currentDate.year,
          currentDate.month - 1,
          currentDate.day,
        );

        // 効率的なループ処理（週単位で処理）
        DateTime checkDate = startDate;
        final futures = <Future<List<Map<String, dynamic>>>>[];

        while (checkDate.isBefore(currentDate)) {
          futures.add(
            DripCounterFirestoreService.loadDripPackRecords(date: checkDate),
          );
          checkDate = checkDate.add(Duration(days: 7)); // 週単位でスキップ

          if (futures.length >= 5) break; // 最大5週間分
        }

        final results = await Future.wait(futures);
        for (final records in results) {
          for (final record in records) {
            totalCount += (record['count'] as int? ?? 0);
          }
        }

        // キャッシュに保存
        await prefs.setInt('cached_drip_pack_count', totalCount);
        await prefs.setInt(
          'drip_pack_cache_timestamp',
          DateTime.now().millisecondsSinceEpoch,
        );

        print('DashboardStatsService: ドリップパック数を計算: ${totalCount}袋');
      } catch (e) {
        print('Firestoreドリップパック記録取得エラー: $e');
        totalCount = await _getDripPackCountFromLocal(prefs);
      }

      return totalCount;
    } catch (e) {
      print('ドリップパック数計算エラー: $e');
      return 0;
    }
  }

  /// 最適化された完了タスク数を取得
  Future<int> _getCompletedTasksOptimized() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todoRecordsJson = prefs.getStringList('todos') ?? [];

      int completedCount = 0;
      for (String todoJson in todoRecordsJson) {
        try {
          final todo = json.decode(todoJson);
          if (todo['isCompleted'] as bool? ?? false) {
            completedCount++;
          }
        } catch (e) {
          continue;
        }
      }

      return completedCount;
    } catch (e) {
      print('完了タスク数計算エラー: $e');
      return 0;
    }
  }

  /// 時間文字列を分に変換
  int _parseTimeToMinutes(String timeString) {
    try {
      if (timeString.contains(':')) {
        final parts = timeString.split(':');
        if (parts.length == 2) {
          final minutes = int.tryParse(parts[0]) ?? 0;
          final seconds = int.tryParse(parts[1]) ?? 0;
          return minutes + (seconds >= 30 ? 1 : 0);
        }
      } else {
        return int.tryParse(timeString) ?? 0;
      }
    } catch (e) {
      return 0;
    }
    return 0;
  }

  /// ローカルから焙煎時間を取得
  Future<int> _getRoastingTimeFromLocal(SharedPreferences prefs) async {
    try {
      final roastRecordsJson = prefs.getStringList('roast_records') ?? [];
      int totalMinutes = 0;

      for (String recordJson in roastRecordsJson) {
        try {
          final record = json.decode(recordJson);
          final timeString = record['time'] as String? ?? '';
          totalMinutes += _parseTimeToMinutes(timeString);
        } catch (e) {
          continue;
        }
      }

      return totalMinutes;
    } catch (e) {
      return 0;
    }
  }

  /// ローカルから出勤日数を取得
  Future<int> _getAttendanceDaysFromLocal(SharedPreferences prefs) async {
    try {
      final attendanceRecordsJson =
          prefs.getStringList('attendance_records') ?? [];
      Set<String> uniqueDates = {};

      for (String recordJson in attendanceRecordsJson) {
        try {
          final record = json.decode(recordJson);
          final status = record['status'] as String? ?? '';
          final dateKey = record['dateKey'] as String? ?? '';

          if (status == 'present' && dateKey.isNotEmpty) {
            uniqueDates.add(dateKey);
          }
        } catch (e) {
          continue;
        }
      }

      return uniqueDates.length;
    } catch (e) {
      return 0;
    }
  }

  /// ローカルからドリップパック数を取得
  Future<int> _getDripPackCountFromLocal(SharedPreferences prefs) async {
    try {
      final dripRecordsJson = prefs.getString('dripPackRecords');

      if (dripRecordsJson != null) {
        final records = json.decode(dripRecordsJson) as List<dynamic>;
        int totalCount = 0;
        for (final record in records) {
          totalCount += (record['count'] as int? ?? 0);
        }
        return totalCount;
      }

      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// 統計データをリアルタイムで更新
  Future<void> refreshStats() async {
    print('DashboardStatsService: 強制リフレッシュ開始');

    // キャッシュをクリア
    _cachedStats = null;
    _lastCacheTime = null;

    // ローカルキャッシュもクリア
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_total_roasting_time');
      await prefs.remove('roasting_time_cache_timestamp');
      await prefs.remove('cached_attendance_days');
      await prefs.remove('attendance_cache_timestamp');
      await prefs.remove('cached_drip_pack_count');
      await prefs.remove('drip_pack_cache_timestamp');
    } catch (e) {
      print('ローカルキャッシュクリアエラー: $e');
    }

    // Firestoreキャッシュをクリア
    try {
      await FirebaseFirestore.instance.clearPersistence();
    } catch (e) {
      print('Firestoreキャッシュクリアエラー: $e');
    }

    print('DashboardStatsService: リフレッシュ完了');
  }

  /// キャッシュを手動でクリア
  static void clearCache() {
    _cachedStats = null;
    _lastCacheTime = null;
    print('DashboardStatsService: メモリキャッシュをクリアしました');
  }

  /// 焙煎時間の表示用フォーマット
  String formatRoastingTime(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0) {
      return '${hours}時間${minutes}分';
    } else {
      return '${minutes}分';
    }
  }

  /// データの更新を通知（Provider用）
  void notifyStatsUpdate() {
    // キャッシュをクリアして次回読み込み時に最新データを取得
    clearCache();
  }
}
