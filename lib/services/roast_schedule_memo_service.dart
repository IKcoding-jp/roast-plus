import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/roast_schedule_models.dart';
import 'dart:developer' as developer;

class RoastScheduleMemoService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _logName = 'RoastScheduleMemoService';
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

  // ユーザーのローストスケジュールメモを取得（日付別）
  static Future<List<RoastScheduleMemo>> getUserMemosForDate(
    DateTime date,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final dateString =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('roast_schedule_memos')
          .doc(dateString)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final memosList = data['memos'] as List<dynamic>? ?? [];
        return memosList
            .map((memo) => RoastScheduleMemo.fromJson(memo))
            .toList();
      }
      return [];
    } catch (e, st) {
      _logError('ローストスケジュールメモ取得エラー', e, st);
      return [];
    }
  }

  // ユーザーのローストスケジュールメモをリアルタイム購読（日付別）
  static Stream<List<RoastScheduleMemo>> watchUserMemosForDate(DateTime date) {
    final user = _auth.currentUser;
    if (user == null) {
      _logInfo('未ログインのためユーザーメモ購読を空ストリームで返却');
      return Stream.value(<RoastScheduleMemo>[]);
    }

    final dateString =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    _logInfo('ユーザーメモ購読開始: uid=${user.uid}, date=$dateString');
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('roast_schedule_memos')
        .doc(dateString)
        .snapshots()
        .map((doc) {
          final memosList = (doc.data()?['memos'] as List<dynamic>?) ?? [];
          final memos = memosList
              .map((memo) => RoastScheduleMemo.fromJson(memo))
              .toList();
          return memos;
        });
  }

  // ユーザーのローストスケジュールメモを取得（後方互換性のため）
  static Future<List<RoastScheduleMemo>> getUserMemos() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('roast_schedule_memos')
          .doc('memos')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final memosList = data['memos'] as List<dynamic>? ?? [];
        return memosList
            .map((memo) => RoastScheduleMemo.fromJson(memo))
            .toList();
      }
      return [];
    } catch (e, st) {
      _logError('ローストスケジュールメモ取得エラー', e, st);
      return [];
    }
  }

  // ローストスケジュールメモを保存（日付別）
  static Future<void> saveUserMemosForDate(
    DateTime date,
    List<RoastScheduleMemo> memos,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final dateString =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final memosData = memos.map((memo) => memo.toJson()).toList();

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('roast_schedule_memos')
          .doc(dateString)
          .set({
            'memos': memosData,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': user.uid,
          });
    } catch (e, st) {
      _logError('ローストスケジュールメモ保存エラー', e, st);
      rethrow;
    }
  }

  // ローストスケジュールメモを保存（後方互換性のため）
  static Future<void> saveUserMemos(List<RoastScheduleMemo> memos) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final memosData = memos.map((memo) => memo.toJson()).toList();

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('roast_schedule_memos')
          .doc('memos')
          .set({
            'memos': memosData,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': user.uid,
          });
    } catch (e, st) {
      _logError('ローストスケジュールメモ保存エラー', e, st);
      rethrow;
    }
  }

  // グループのローストスケジュールメモを取得（日付別）
  static Future<List<RoastScheduleMemo>> getGroupMemosForDate(
    String groupId,
    DateTime date,
  ) async {
    try {
      final dateString =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final doc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('roast_schedule_memos')
          .doc(dateString)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final memosList = data['memos'] as List<dynamic>? ?? [];
        return memosList
            .map((memo) => RoastScheduleMemo.fromJson(memo))
            .toList();
      }
      return [];
    } catch (e, st) {
      _logError('グループローストスケジュールメモ取得エラー', e, st);
      return [];
    }
  }

  // グループのローストスケジュールメモをリアルタイム購読（日付別）
  static Stream<List<RoastScheduleMemo>> watchGroupMemosForDate(
    String groupId,
    DateTime date,
  ) {
    final user = _auth.currentUser;
    if (user == null) {
      _logInfo('未ログインのためグループメモ購読を空ストリームで返却');
      return Stream.value(<RoastScheduleMemo>[]);
    }

    final dateString =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    _logInfo('グループメモ購読開始: groupId=$groupId, uid=${user.uid}, date=$dateString');
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('roast_schedule_memos')
        .doc(dateString)
        .snapshots()
        .map((doc) {
          final memosList = (doc.data()?['memos'] as List<dynamic>?) ?? [];
          final memos = memosList
              .map((memo) => RoastScheduleMemo.fromJson(memo))
              .toList();
          return memos;
        });
  }

  // グループのローストスケジュールメモを取得（後方互換性のため）
  static Future<List<RoastScheduleMemo>> getGroupMemos(String groupId) async {
    try {
      final doc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('roast_schedule_memos')
          .doc('memos')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final memosList = data['memos'] as List<dynamic>? ?? [];
        return memosList
            .map((memo) => RoastScheduleMemo.fromJson(memo))
            .toList();
      }
      return [];
    } catch (e, st) {
      _logError('グループローストスケジュールメモ取得エラー', e, st);
      return [];
    }
  }

  // グループのローストスケジュールメモを保存（日付別）
  static Future<void> saveGroupMemosForDate(
    String groupId,
    DateTime date,
    List<RoastScheduleMemo> memos,
  ) async {
    try {
      final dateString =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final memosData = memos.map((memo) => memo.toJson()).toList();

      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('roast_schedule_memos')
          .doc(dateString)
          .set({
            'memos': memosData,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': _auth.currentUser?.uid,
          });
    } catch (e, st) {
      _logError('グループローストスケジュールメモ保存エラー', e, st);
      rethrow;
    }
  }

  // グループのローストスケジュールメモを保存（後方互換性のため）
  static Future<void> saveGroupMemos(
    String groupId,
    List<RoastScheduleMemo> memos,
  ) async {
    try {
      final memosData = memos.map((memo) => memo.toJson()).toList();

      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('roast_schedule_memos')
          .doc('memos')
          .set({
            'memos': memosData,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': _auth.currentUser?.uid,
          });
    } catch (e, st) {
      _logError('グループローストスケジュールメモ保存エラー', e, st);
      rethrow;
    }
  }

  // メモを追加
  static Future<void> addMemo(RoastScheduleMemo memo, {String? groupId}) async {
    try {
      List<RoastScheduleMemo> memos;

      if (groupId != null) {
        memos = await getGroupMemosForDate(groupId, memo.date);
      } else {
        memos = await getUserMemosForDate(memo.date);
      }

      memos.add(memo);

      if (groupId != null) {
        await saveGroupMemosForDate(groupId, memo.date, memos);
      } else {
        await saveUserMemosForDate(memo.date, memos);
      }
    } catch (e, st) {
      _logError('メモ追加エラー', e, st);
      rethrow;
    }
  }

  // メモを更新
  static Future<void> updateMemo(
    RoastScheduleMemo memo, {
    String? groupId,
  }) async {
    try {
      List<RoastScheduleMemo> memos;

      if (groupId != null) {
        memos = await getGroupMemosForDate(groupId, memo.date);
      } else {
        memos = await getUserMemosForDate(memo.date);
      }

      final index = memos.indexWhere((m) => m.id == memo.id);
      if (index != -1) {
        memos[index] = memo;

        if (groupId != null) {
          await saveGroupMemosForDate(groupId, memo.date, memos);
        } else {
          await saveUserMemosForDate(memo.date, memos);
        }
      }
    } catch (e, st) {
      _logError('メモ更新エラー', e, st);
      rethrow;
    }
  }

  // メモを削除
  static Future<void> deleteMemo(
    String memoId, {
    String? groupId,
    DateTime? date,
  }) async {
    try {
      List<RoastScheduleMemo> memos;
      final targetDate = date ?? DateTime.now();

      if (groupId != null) {
        memos = await getGroupMemosForDate(groupId, targetDate);
      } else {
        memos = await getUserMemosForDate(targetDate);
      }

      memos.removeWhere((m) => m.id == memoId);

      if (groupId != null) {
        await saveGroupMemosForDate(groupId, targetDate, memos);
      } else {
        await saveUserMemosForDate(targetDate, memos);
      }
    } catch (e, st) {
      _logError('メモ削除エラー', e, st);
      rethrow;
    }
  }
}
