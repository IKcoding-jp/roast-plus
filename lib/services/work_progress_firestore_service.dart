import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;
import '../models/work_progress_models.dart';
import 'auto_sync_service.dart';

class WorkProgressFirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static const String _logName = 'WorkProgressFirestoreService';
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

  static String? get _uid => _auth.currentUser?.uid;

  /// 作業進捗記録を取得
  static Future<List<WorkProgress>> getWorkProgressRecords() async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('work_progress')
          .orderBy('createdAt', descending: true)
          .get();

      final records = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return WorkProgress.fromMap(data);
      }).toList();

      return records;
    } catch (e, st) {
      _logError('作業進捗記録取得エラー', e, st);
      return [];
    }
  }

  /// 指定した日付の作業進捗記録を取得
  static Future<List<WorkProgress>> getWorkProgressRecordsByDate(
    DateTime date,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(Duration(days: 1));

      final snapshot = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('work_progress')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: startOfDay.toIso8601String(),
          )
          .where('createdAt', isLessThan: endOfDay.toIso8601String())
          .orderBy('createdAt', descending: true)
          .get();

      final records = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return WorkProgress.fromMap(data);
      }).toList();

      return records;
    } catch (e, st) {
      _logError('指定日付の作業進捗記録取得エラー', e, st);
      return [];
    }
  }

  /// 作業進捗記録のストリームを取得
  static Stream<List<WorkProgress>> getWorkProgressRecordsStream() {
    if (_uid == null) return Stream.value([]);

    try {
      return _firestore
          .collection('users')
          .doc(_uid)
          .collection('work_progress')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return WorkProgress.fromMap(data);
            }).toList();
          });
    } catch (e, st) {
      _logError('作業進捗記録ストリームエラー', e, st);
      return Stream.value([]);
    }
  }

  /// 作業進捗記録を保存
  static Future<void> saveWorkProgressRecord(WorkProgress record) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final recordData = record.toMap();
      recordData['userId'] = _uid;
      recordData['updatedAt'] = DateTime.now().toIso8601String();

      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('work_progress')
          .doc(record.id)
          .set(recordData);

      // 自動同期を実行
      await AutoSyncService.triggerAutoSyncForDataType('work_progress');
    } catch (e, st) {
      _logError('作業進捗記録保存エラー', e, st);
      rethrow;
    }
  }

  /// 作業進捗記録を更新
  static Future<void> updateWorkProgressRecord(WorkProgress record) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final recordData = record.toMap();
      recordData['updatedAt'] = DateTime.now().toIso8601String();

      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('work_progress')
          .doc(record.id)
          .update(recordData);

      // 自動同期を実行
      await AutoSyncService.triggerAutoSyncForDataType('work_progress');
    } catch (e, st) {
      _logError('作業進捗記録更新エラー', e, st);
      rethrow;
    }
  }

  /// 作業進捗記録を削除
  static Future<void> deleteWorkProgressRecord(String recordId) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('work_progress')
          .doc(recordId)
          .delete();

      // 自動同期を実行
      await AutoSyncService.triggerAutoSyncForDataType('work_progress');
    } catch (e, st) {
      _logError('作業進捗記録削除エラー', e, st);
      rethrow;
    }
  }

  /// 豆IDで作業進捗記録を取得
  static Future<List<WorkProgress>> getWorkProgressByBean(String beanId) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('work_progress')
          .where('beanId', isEqualTo: beanId)
          .orderBy('createdAt', descending: true)
          .get();

      final records = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return WorkProgress.fromMap(data);
      }).toList();

      return records;
    } catch (e, st) {
      _logError('豆別作業進捗記録取得エラー', e, st);
      return [];
    }
  }

  /// グループの作業進捗記録を取得
  static Future<List<WorkProgress>> getGroupWorkProgressRecords(
    String groupId,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final snapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('work_progress')
          .orderBy('createdAt', descending: true)
          .get();

      final records = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return WorkProgress.fromMap(data);
      }).toList();

      return records;
    } catch (e, st) {
      _logError('グループ作業進捗記録取得エラー', e, st);
      return [];
    }
  }

  /// グループに作業進捗記録を保存
  static Future<void> saveGroupWorkProgressRecord(
    String groupId,
    WorkProgress record,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final recordData = record.toMap();
      recordData['userId'] = _uid;
      recordData['updatedAt'] = DateTime.now().toIso8601String();

      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('work_progress')
          .doc(record.id)
          .set(recordData);
    } catch (e, st) {
      _logError('グループ作業進捗記録保存エラー', e, st);
      rethrow;
    }
  }

  /// グループの作業進捗記録を更新
  static Future<void> updateGroupWorkProgressRecord(
    String groupId,
    WorkProgress record,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final recordData = record.toMap();
      recordData['updatedAt'] = DateTime.now().toIso8601String();

      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('work_progress')
          .doc(record.id)
          .update(recordData);
    } catch (e, st) {
      _logError('グループ作業進捗記録更新エラー', e, st);
      rethrow;
    }
  }

  /// グループの作業進捗記録を削除
  static Future<void> deleteGroupWorkProgressRecord(
    String groupId,
    String recordId,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('work_progress')
          .doc(recordId)
          .delete();
    } catch (e, st) {
      _logError('グループ作業進捗記録削除エラー', e, st);
      rethrow;
    }
  }
}
