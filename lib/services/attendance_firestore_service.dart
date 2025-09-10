import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/attendance_models.dart';
import 'group_data_sync_service.dart';
import 'group_firestore_service.dart';
import 'dart:developer' as developer;

class AttendanceFirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _logName = 'AttendanceFirestoreService';

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

  // 今日の日付キーを取得
  static String _getTodayDateKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // 指定日の日付キーを取得
  static String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 今日の出勤退勤記録を取得
  static Future<List<AttendanceRecord>> getTodayAttendance() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      final dateKey = _getTodayDateKey();
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('attendance')
          .doc(dateKey)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final records = data['records'] as List<dynamic>?;
        if (records != null) {
          return records.map((r) => AttendanceRecord.fromMap(r)).toList();
        }
      }
      return [];
    } catch (e, st) {
      _logError('今日の出勤退勤記録取得エラー', e, st);
      return [];
    }
  }

  // 指定日の出勤退勤記録を取得
  static Future<List<AttendanceRecord>> getAttendanceByDate(
    DateTime date,
  ) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      final dateKey = _getDateKey(date);
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('attendance')
          .doc(dateKey)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final records = data['records'] as List<dynamic>?;
        if (records != null) {
          return records.map((r) => AttendanceRecord.fromMap(r)).toList();
        }
      }
      return [];
    } catch (e, st) {
      _logError('指定日の出勤退勤記録取得エラー', e, st);
      return [];
    }
  }

  // 出勤退勤記録を保存
  static Future<void> saveAttendanceRecord(AttendanceRecord record) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // 既存の記録を取得
      final existingRecords = await getAttendanceByDate(record.timestamp);

      // 同じメンバー名の既存記録を更新または新規追加
      final updatedRecords = <AttendanceRecord>[];
      bool found = false;

      for (final existingRecord in existingRecords) {
        if (existingRecord.memberName == record.memberName) {
          updatedRecords.add(record);
          found = true;
        } else {
          updatedRecords.add(existingRecord);
        }
      }

      if (!found) {
        updatedRecords.add(record);
      }

      // Firestoreに保存
      final dateKey = record.dateKey;
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('attendance')
          .doc(dateKey)
          .set({
            'records': updatedRecords.map((r) => r.toMap()).toList(),
            'lastUpdated': DateTime.now().toIso8601String(),
          });

      // グループ同期
      await _syncToGroup(dateKey, updatedRecords);
    } catch (e, st) {
      _logError('出勤退勤記録保存エラー', e, st);
    }
  }

  // メンバーの出勤退勤状態を更新
  static Future<void> updateMemberAttendance(
    String memberId,
    String memberName,
    AttendanceStatus status,
  ) async {
    try {
      _logInfo(
        'メンバー出勤退勤状態更新開始 - memberId: $memberId, memberName: $memberName, status: $status',
      );

      final record = AttendanceRecord(
        memberId: memberId,
        memberName: memberName,
        status: status,
        timestamp: DateTime.now(),
        dateKey: _getTodayDateKey(),
      );

      await saveAttendanceRecord(record);
      _logInfo('メンバー出勤退勤状態更新完了');
    } catch (e, st) {
      _logError('メンバー出勤退勤状態更新エラー', e, st);
    }
  }

  // グループに同期
  static Future<void> _syncToGroup(
    String dateKey,
    List<AttendanceRecord> records,
  ) async {
    try {
      _logInfo('グループ同期開始 - dateKey: $dateKey');

      // ユーザーが参加しているグループを取得
      final groups = await GroupFirestoreService.getUserGroups();
      if (groups.isEmpty) {
        _logInfo('参加しているグループがありません');
        return;
      }

      final group = groups.first; // 最初のグループを使用
      _logInfo('グループ同期対象: ${group.name} (${group.id})');

      // 既存のグループデータを取得
      final existingGroupData =
          await GroupDataSyncService.getGroupAttendanceData(group.id);
      List<AttendanceRecord> existingRecords = [];

      if (existingGroupData != null && existingGroupData.containsKey(dateKey)) {
        final dateData = existingGroupData[dateKey] as Map<String, dynamic>?;
        if (dateData != null && dateData.containsKey('records')) {
          final recordsData = dateData['records'] as List<dynamic>?;
          if (recordsData != null) {
            existingRecords = recordsData
                .map((r) => AttendanceRecord.fromMap(r))
                .toList();
          }
        }
      }

      // 新しい記録を既存の記録とマージ
      final mergedRecords = <AttendanceRecord>[];
      final updatedMemberNames = records.map((r) => r.memberName).toSet();

      // 既存の記録を追加（更新されるメンバー以外）
      for (final existingRecord in existingRecords) {
        if (!updatedMemberNames.contains(existingRecord.memberName)) {
          mergedRecords.add(existingRecord);
        }
      }

      // 新しい記録を追加
      mergedRecords.addAll(records);

      _logInfo(
        'グループ同期 - 既存記録数: ${existingRecords.length}, 新規記録数: ${records.length}, マージ後記録数: ${mergedRecords.length}',
      );

      // 出勤退勤データをグループに同期
      final attendanceData = {
        dateKey: {
          'records': mergedRecords.map((r) => r.toMap()).toList(),
          'lastUpdated': DateTime.now().toIso8601String(),
          'updatedBy': _auth.currentUser?.uid,
          'updatedByName': _auth.currentUser?.displayName ?? 'Unknown',
        },
      };

      await GroupDataSyncService.syncAttendanceData(group.id, attendanceData);
      _logInfo('グループ同期完了');
    } catch (e, st) {
      _logError('グループ同期エラー', e, st);
    }
  }

  // グループの出勤退勤記録を取得
  static Future<List<AttendanceRecord>> getGroupAttendanceData(
    String groupId,
    String dateKey,
  ) async {
    try {
      _logInfo('グループ出勤退勤記録取得開始 - groupId: $groupId, dateKey: $dateKey');

      final groupData = await GroupDataSyncService.getGroupAttendanceData(
        groupId,
      );
      if (groupData == null || !groupData.containsKey(dateKey)) {
        _logInfo('グループに出勤退勤記録がありません');
        return [];
      }

      final dateData = groupData[dateKey] as Map<String, dynamic>?;
      if (dateData == null || !dateData.containsKey('records')) {
        return [];
      }

      final records = dateData['records'] as List<dynamic>?;
      if (records == null) return [];

      final allRecords = records
          .map((r) => AttendanceRecord.fromMap(r))
          .toList();

      // 同じメンバー名の場合は最新の記録のみを保持
      final latestRecords = <String, AttendanceRecord>{};
      for (final record in allRecords) {
        if (!latestRecords.containsKey(record.memberName) ||
            record.timestamp.isAfter(
              latestRecords[record.memberName]!.timestamp,
            )) {
          latestRecords[record.memberName] = record;
        }
      }

      final attendanceRecords = latestRecords.values.toList();
      _logInfo(
        'グループ出勤退勤記録取得完了 - 全記録数: ${allRecords.length}, 最新記録数: ${attendanceRecords.length}',
      );

      return attendanceRecords;
    } catch (e, st) {
      _logError('グループ出勤退勤記録取得エラー', e, st);
      return [];
    }
  }

  // グループの出勤退勤記録の変更をリアルタイム監視
  static Stream<List<AttendanceRecord>> watchGroupAttendanceData(
    String groupId,
    String dateKey,
  ) {
    _logInfo('グループ出勤退勤記録監視開始 - groupId: $groupId, dateKey: $dateKey');

    return GroupDataSyncService.watchGroupAttendanceData(groupId).map((
      groupData,
    ) {
      if (groupData == null || !groupData.containsKey(dateKey)) {
        return <AttendanceRecord>[];
      }

      final dateData = groupData[dateKey] as Map<String, dynamic>?;
      if (dateData == null || !dateData.containsKey('records')) {
        return <AttendanceRecord>[];
      }

      final records = dateData['records'] as List<dynamic>?;
      if (records == null) return <AttendanceRecord>[];

      final allRecords = records
          .map((r) => AttendanceRecord.fromMap(r))
          .toList();

      // 同じメンバー名の場合は最新の記録のみを保持
      final latestRecords = <String, AttendanceRecord>{};
      for (final record in allRecords) {
        if (!latestRecords.containsKey(record.memberName) ||
            record.timestamp.isAfter(
              latestRecords[record.memberName]!.timestamp,
            )) {
          latestRecords[record.memberName] = record;
        }
      }

      final attendanceRecords = latestRecords.values.toList();
      _logInfo(
        'グループ出勤退勤記録更新検知 - 全記録数: ${allRecords.length}, 最新記録数: ${attendanceRecords.length}',
      );

      return attendanceRecords;
    });
  }

  // 出勤退勤統計を取得
  static Future<AttendanceSummary> getAttendanceSummary(DateTime date) async {
    try {
      final records = await getAttendanceByDate(date);
      final dateKey = _getDateKey(date);
      return AttendanceSummary(dateKey: dateKey, records: records);
    } catch (e, st) {
      _logError('出勤退勤統計取得エラー', e, st);
      return AttendanceSummary(dateKey: _getDateKey(date), records: []);
    }
  }

  // 期間の出勤退勤記録を取得
  static Future<List<AttendanceSummary>> getAttendanceByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final summaries = <AttendanceSummary>[];
      DateTime currentDate = startDate;

      while (currentDate.isBefore(endDate) ||
          currentDate.isAtSameMomentAs(endDate)) {
        final summary = await getAttendanceSummary(currentDate);
        summaries.add(summary);
        currentDate = currentDate.add(Duration(days: 1));
      }

      return summaries;
    } catch (e, st) {
      _logError('期間の出勤退勤記録取得エラー', e, st);
      return [];
    }
  }
}
