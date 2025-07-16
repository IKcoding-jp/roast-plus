import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/attendance_models.dart';

class AttendanceFirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

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
    } catch (e) {
      print('AttendanceFirestoreService: 今日の出勤退勤記録取得エラー: $e');
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
    } catch (e) {
      print('AttendanceFirestoreService: 指定日の出勤退勤記録取得エラー: $e');
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

      // 同じメンバーの既存記録を更新または新規追加
      final updatedRecords = <AttendanceRecord>[];
      bool found = false;

      for (final existingRecord in existingRecords) {
        if (existingRecord.memberId == record.memberId) {
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
    } catch (e) {
      print('AttendanceFirestoreService: 出勤退勤記録保存エラー: $e');
    }
  }

  // メンバーの出勤退勤状態を更新
  static Future<void> updateMemberAttendance(
    String memberId,
    String memberName,
    AttendanceStatus status,
  ) async {
    try {
      final record = AttendanceRecord(
        memberId: memberId,
        memberName: memberName,
        status: status,
        timestamp: DateTime.now(),
        dateKey: _getTodayDateKey(),
      );

      await saveAttendanceRecord(record);
    } catch (e) {
      print('AttendanceFirestoreService: メンバー出勤退勤状態更新エラー: $e');
    }
  }

  // グループに同期
  static Future<void> _syncToGroup(
    String dateKey,
    List<AttendanceRecord> records,
  ) async {
    try {
      // GroupDataSyncServiceを使用してグループに同期
      final attendanceData = {
        'dateKey': dateKey,
        'records': records.map((r) => r.toMap()).toList(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      // グループ同期サービスに追加する必要があります
      // await GroupDataSyncService.syncAttendanceData(groupId, attendanceData);
    } catch (e) {
      print('AttendanceFirestoreService: グループ同期エラー: $e');
    }
  }

  // 出勤退勤統計を取得
  static Future<AttendanceSummary> getAttendanceSummary(DateTime date) async {
    try {
      final records = await getAttendanceByDate(date);
      final dateKey = _getDateKey(date);
      return AttendanceSummary(dateKey: dateKey, records: records);
    } catch (e) {
      print('AttendanceFirestoreService: 出勤退勤統計取得エラー: $e');
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
    } catch (e) {
      print('AttendanceFirestoreService: 期間の出勤退勤記録取得エラー: $e');
      return [];
    }
  }
}
