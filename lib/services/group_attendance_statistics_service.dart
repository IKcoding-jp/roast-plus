import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_models.dart';
import '../models/group_gamification_models.dart';
import 'dart:developer' as developer;

class GroupAttendanceStatisticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _logName = 'GroupAttendanceStatisticsService';
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

  /// グループの出勤統計を計算
  static Future<GroupStats> calculateGroupAttendanceStats(
    String groupId,
  ) async {
    try {
      _logInfo('グループ出勤統計計算開始 - groupId: $groupId');

      // グループの出勤記録を取得
      final attendanceRecords = await _getGroupAttendanceRecords(groupId);

      // 焙煎記録を取得
      final roastRecords = await _getGroupRoastRecords(groupId);

      // ドリップパック記録を取得
      final dripPackRecords = await _getGroupDripPackRecords(groupId);

      // テイスティング記録を取得
      final tastingRecords = await _getGroupTastingRecords(groupId);

      // 作業進捗記録を取得
      final workProgressRecords = await _getGroupWorkProgressRecords(groupId);

      // 統計を計算
      final stats = _calculateStats(
        attendanceRecords,
        roastRecords,
        dripPackRecords,
        tastingRecords,
        workProgressRecords,
      );

      _logInfo(
        'グループ出勤統計計算完了 - totalAttendanceDays: ${stats.totalAttendanceDays}',
      );
      return stats;
    } catch (e, st) {
      _logError('グループ出勤統計計算エラー', e, st);
      return GroupStats.initial();
    }
  }

  /// グループの出勤記録を取得
  static Future<List<AttendanceRecord>> _getGroupAttendanceRecords(
    String groupId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('attendance')
          .get();

      final records = <AttendanceRecord>[];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final recordsList = data['records'] as List<dynamic>?;

        if (recordsList != null) {
          for (final recordData in recordsList) {
            try {
              final record = AttendanceRecord.fromMap(recordData);
              if (record.status == AttendanceStatus.present) {
                records.add(record);
              }
            } catch (e, st) {
              _logError('出勤記録のパースエラー', e, st);
            }
          }
        }
      }

      return records;
    } catch (e, st) {
      _logError('グループ出勤記録取得エラー', e, st);
      return [];
    }
  }

  /// グループの焙煎記録を取得
  static Future<List<Map<String, dynamic>>> _getGroupRoastRecords(
    String groupId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('roast_records')
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e, st) {
      _logError('グループ焙煎記録取得エラー', e, st);
      return [];
    }
  }

  /// グループのドリップパック記録を取得
  static Future<List<Map<String, dynamic>>> _getGroupDripPackRecords(
    String groupId,
  ) async {
    try {
      // グループの共有データからドリップパック記録を取得
      final sharedDataDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('sharedData')
          .doc('drip_counter_records')
          .get();

      if (sharedDataDoc.exists) {
        final data = sharedDataDoc.data();
        final records = data?['data']?['records'] as List<dynamic>?;

        if (records != null) {
          return records.cast<Map<String, dynamic>>();
        }
      }

      return [];
    } catch (e, st) {
      _logError('グループドリップパック記録取得エラー', e, st);
      return [];
    }
  }

  /// グループのテイスティング記録を取得
  static Future<List<Map<String, dynamic>>> _getGroupTastingRecords(
    String groupId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('tasting_records')
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e, st) {
      _logError('グループテイスティング記録取得エラー', e, st);
      return [];
    }
  }

  /// グループの作業進捗記録を取得
  static Future<List<Map<String, dynamic>>> _getGroupWorkProgressRecords(
    String groupId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('work_progress')
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e, st) {
      _logError('グループ作業進捗記録取得エラー', e, st);
      return [];
    }
  }

  /// 統計を計算
  static GroupStats _calculateStats(
    List<AttendanceRecord> attendanceRecords,
    List<Map<String, dynamic>> roastRecords,
    List<Map<String, dynamic>> dripPackRecords,
    List<Map<String, dynamic>> tastingRecords,
    List<Map<String, dynamic>> workProgressRecords,
  ) {
    // 出勤日数（重複なしの日付）
    final attendanceDays = attendanceRecords
        .map((r) => r.dateKey)
        .toSet()
        .length;

    // 焙煎時間（分）
    double totalRoastTimeMinutes = 0;
    for (final record in roastRecords) {
      final timeString = record['time'] as String?;
      if (timeString != null) {
        final timeParts = timeString.split(':');
        if (timeParts.length == 2) {
          final minutes = int.tryParse(timeParts[0]) ?? 0;
          final seconds = int.tryParse(timeParts[1]) ?? 0;
          totalRoastTimeMinutes += minutes + (seconds / 60);
        }
      }
    }

    // 焙煎日数（重複なしの日付）
    final roastDays = roastRecords
        .map((r) {
          final timestamp = r['timestamp'];
          if (timestamp is Timestamp) {
            final date = timestamp.toDate();
            return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          }
          return null;
        })
        .where((date) => date != null)
        .cast<String>()
        .toSet()
        .length;

    // ドリップパック数
    int totalDripPackCount = 0;
    for (final record in dripPackRecords) {
      totalDripPackCount += record['count'] as int? ?? 0;
    }

    // テイスティング記録数
    final totalTastingRecords = tastingRecords.length;

    // 最初の活動日と最後の活動日
    DateTime? firstActivityDate;
    DateTime? lastActivityDate;

    // 出勤記録から日付を取得
    for (final record in attendanceRecords) {
      final date = DateTime.parse(record.dateKey);
      if (firstActivityDate == null || date.isBefore(firstActivityDate)) {
        firstActivityDate = date;
      }
      if (lastActivityDate == null || date.isAfter(lastActivityDate)) {
        lastActivityDate = date;
      }
    }

    // 焙煎記録から日付を取得
    for (final record in roastRecords) {
      final timestamp = record['timestamp'];
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        if (firstActivityDate == null || date.isBefore(firstActivityDate)) {
          firstActivityDate = date;
        }
        if (lastActivityDate == null || date.isAfter(lastActivityDate)) {
          lastActivityDate = date;
        }
      }
    }

    // デフォルト値
    final now = DateTime.now();
    firstActivityDate ??= now;
    lastActivityDate ??= now;

    // メンバー別貢献度（簡易版）
    final memberContributions = <String, int>{};
    for (final record in attendanceRecords) {
      memberContributions[record.memberName] =
          (memberContributions[record.memberName] ?? 0) + 1;
    }

    // 全員出勤日（簡易版）
    final allMemberAttendanceDays = <String>{};
    final attendanceByDate = <String, Set<String>>{};

    for (final record in attendanceRecords) {
      if (!attendanceByDate.containsKey(record.dateKey)) {
        attendanceByDate[record.dateKey] = {};
      }
      attendanceByDate[record.dateKey]!.add(record.memberName);
    }

    // 全員出勤日を判定（実際の実装では、グループの全メンバー数と比較する必要があります）
    for (final entry in attendanceByDate.entries) {
      if (entry.value.length >= 2) {
        // 2人以上出勤した日を全員出勤日として扱う
        allMemberAttendanceDays.add(entry.key);
      }
    }

    return GroupStats(
      totalAttendanceDays: attendanceDays,
      totalRoastTimeMinutes: totalRoastTimeMinutes,
      totalRoastDays: roastDays,
      totalDripPackCount: totalDripPackCount,
      totalTastingRecords: totalTastingRecords,
      firstActivityDate: firstActivityDate,
      lastActivityDate: lastActivityDate,
      memberContributions: memberContributions,
      allMemberAttendanceDays: allMemberAttendanceDays,
    );
  }

  /// グループの出勤統計をリアルタイムで監視
  static Stream<GroupStats> watchGroupAttendanceStats(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('attendance')
        .snapshots()
        .asyncMap((_) => calculateGroupAttendanceStats(groupId));
  }
}
