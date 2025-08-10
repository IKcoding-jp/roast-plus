import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import '../models/attendance_models.dart';
import '../services/roast_record_firestore_service.dart';
import '../services/attendance_firestore_service.dart';
import '../services/drip_counter_firestore_service.dart';
import 'user_settings_firestore_service.dart';

class DashboardStatsService {
  static final DashboardStatsService _instance =
      DashboardStatsService._internal();
  factory DashboardStatsService() => _instance;
  DashboardStatsService._internal();

  static DashboardStatsService get instance => _instance;

  static const String _logName = 'DashboardStatsService';
  static void _logInfo(String message) =>
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
        _logInfo('キャッシュからデータを返します');
        return _cachedStats!;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return _getDefaultStats();
      }

      _logInfo('統計データを並列取得開始');
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
      _logInfo('統計データ取得完了 (${processingTime}ms)');

      return stats;
    } catch (e, st) {
      _logError('統計データ取得エラー', e, st);
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
      final cachedTime = await UserSettingsFirestoreService.getSetting(
        'cached_total_roasting_time',
      );
      final cacheTimestamp = await UserSettingsFirestoreService.getSetting(
        'roasting_time_cache_timestamp',
      );

      if (cachedTime != null && cacheTimestamp != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTimestamp;
        if (cacheAge < Duration(hours: 1).inMilliseconds) {
          // 1時間キャッシュ
          _logInfo('焙煎時間をキャッシュから取得: $cachedTime分');
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
        await UserSettingsFirestoreService.saveMultipleSettings({
          'cached_total_roasting_time': totalMinutes,
          'roasting_time_cache_timestamp':
              DateTime.now().millisecondsSinceEpoch,
        });

        _logInfo('焙煎時間を計算: $totalMinutes分');
      } catch (e, st) {
        _logError('Firestore焙煎記録取得エラー', e, st);
        // フォールバック: ローカルデータから取得
        totalMinutes = await _getRoastingTimeFromLocal();
      }

      return totalMinutes;
    } catch (e, st) {
      _logError('総焙煎時間計算エラー', e, st);
      return 0;
    }
  }

  /// 最適化された出勤日数を取得
  Future<int> _getAttendanceDaysOptimized() async {
    try {
      // キャッシュから確認
      final cachedDays = await UserSettingsFirestoreService.getSetting(
        'cached_attendance_days',
      );
      final cacheTimestamp = await UserSettingsFirestoreService.getSetting(
        'attendance_cache_timestamp',
      );

      if (cachedDays != null && cacheTimestamp != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTimestamp;
        if (cacheAge < Duration(hours: 6).inMilliseconds) {
          // 6時間キャッシュ
          _logInfo('出勤日数をキャッシュから取得: $cachedDays日');
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
        await UserSettingsFirestoreService.saveMultipleSettings({
          'cached_attendance_days': result,
          'attendance_cache_timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        _logInfo('出勤日数を計算: $result日');
        return result;
      } catch (e, st) {
        _logError('Firestore出勤記録取得エラー', e, st);
        return await _getAttendanceDaysFromLocal();
      }
    } catch (e, st) {
      _logError('出勤日数計算エラー', e, st);
      return 0;
    }
  }

  /// 最適化されたドリップパック数を取得
  Future<int> _getDripPackCountOptimized() async {
    try {
      // キャッシュから確認
      final cachedCount = await UserSettingsFirestoreService.getSetting(
        'cached_drip_pack_count',
      );
      final cacheTimestamp = await UserSettingsFirestoreService.getSetting(
        'drip_pack_cache_timestamp',
      );

      if (cachedCount != null && cacheTimestamp != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTimestamp;
        if (cacheAge < Duration(hours: 1).inMilliseconds) {
          // 1時間キャッシュ
          _logInfo('ドリップパック数をキャッシュから取得: $cachedCount袋');
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
        await UserSettingsFirestoreService.saveMultipleSettings({
          'cached_drip_pack_count': totalCount,
          'drip_pack_cache_timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        _logInfo('ドリップパック数を計算: $totalCount袋');
      } catch (e, st) {
        _logError('Firestoreドリップパック記録取得エラー', e, st);
        totalCount = await _getDripPackCountFromLocal();
      }

      return totalCount;
    } catch (e, st) {
      _logError('ドリップパック数計算エラー', e, st);
      return 0;
    }
  }

  /// 最適化された完了タスク数を取得
  Future<int> _getCompletedTasksOptimized() async {
    try {
      final todoRecordsJson =
          await UserSettingsFirestoreService.getSetting('todos') ?? [];

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
    } catch (e, st) {
      _logError('完了タスク数計算エラー', e, st);
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
  Future<int> _getRoastingTimeFromLocal() async {
    try {
      final roastRecordsJson =
          await UserSettingsFirestoreService.getSetting('roast_records') ?? [];
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
  Future<int> _getAttendanceDaysFromLocal() async {
    try {
      final attendanceRecordsJson =
          await UserSettingsFirestoreService.getSetting('attendance_records') ??
          [];
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
  Future<int> _getDripPackCountFromLocal() async {
    try {
      final dripRecordsJson = await UserSettingsFirestoreService.getSetting(
        'dripPackRecords',
      );

      if (dripRecordsJson != null) {
        final records = dripRecordsJson as List<dynamic>;
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
    _logInfo('強制リフレッシュ開始');

    // キャッシュをクリア
    _cachedStats = null;
    _lastCacheTime = null;

    // ローカルキャッシュもクリア
    try {
      await UserSettingsFirestoreService.deleteSetting(
        'cached_total_roasting_time',
      );
      await UserSettingsFirestoreService.deleteSetting(
        'roasting_time_cache_timestamp',
      );
      await UserSettingsFirestoreService.deleteSetting(
        'cached_attendance_days',
      );
      await UserSettingsFirestoreService.deleteSetting(
        'attendance_cache_timestamp',
      );
      await UserSettingsFirestoreService.deleteSetting(
        'cached_drip_pack_count',
      );
      await UserSettingsFirestoreService.deleteSetting(
        'drip_pack_cache_timestamp',
      );
    } catch (e, st) {
      _logError('ローカルキャッシュクリアエラー', e, st);
    }

    // Firestoreキャッシュをクリア
    try {
      await FirebaseFirestore.instance.clearPersistence();
    } catch (e, st) {
      _logError('Firestoreキャッシュクリアエラー', e, st);
    }

    _logInfo('リフレッシュ完了');
  }

  /// キャッシュを手動でクリア
  static void clearCache() {
    _cachedStats = null;
    _lastCacheTime = null;
    _logInfo('メモリキャッシュをクリアしました');
  }

  /// 焙煎時間の表示用フォーマット
  String formatRoastingTime(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0) {
      return '$hours時間$minutes分';
    } else {
      return '$minutes分';
    }
  }

  /// データの更新を通知（Provider用）
  void notifyStatsUpdate() {
    // キャッシュをクリアして次回読み込み時に最新データを取得
    clearCache();
  }
}
