import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;
import '../models/memo_models.dart';

class MemoFirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static const String _logName = 'MemoFirestoreService';
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

  static String? get _uid {
    final uid = _auth.currentUser?.uid;
    return uid != null && uid.isNotEmpty ? uid : null;
  }

  /// メモ一覧を取得
  static Future<List<MemoItem>> getMemos() async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('memos')
          .orderBy('updatedAt', descending: true)
          .get();

      final memos = snapshot.docs
          .map((doc) => MemoItem.fromJson(doc.data()))
          .toList();
      // ピン留めされたメモを先頭に並べる
      memos.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      return memos;
    } catch (e, st) {
      _logError('メモ取得エラー', e, st);
      return [];
    }
  }

  /// メモを保存
  static Future<void> saveMemo(MemoItem memo) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('memos')
          .doc(memo.id)
          .set(memo.toJson());
    } catch (e, st) {
      _logError('メモ保存エラー', e, st);
      rethrow;
    }
  }

  /// メモを更新
  static Future<void> updateMemo(MemoItem memo) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final updatedMemo = memo.copyWith(updatedAt: DateTime.now());
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('memos')
          .doc(memo.id)
          .update(updatedMemo.toJson());
    } catch (e, st) {
      _logError('メモ更新エラー', e, st);
      rethrow;
    }
  }

  /// メモを削除
  static Future<void> deleteMemo(String memoId) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('memos')
          .doc(memoId)
          .delete();
    } catch (e, st) {
      _logError('メモ削除エラー', e, st);
      rethrow;
    }
  }

  /// メモをピン留め/ピン留め解除
  static Future<void> togglePinMemo(String memoId, bool isPinned) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('memos')
          .doc(memoId)
          .update({
            'isPinned': isPinned,
            'updatedAt': DateTime.now().toIso8601String(),
          });
    } catch (e, st) {
      _logError('メモピン留めエラー', e, st);
      rethrow;
    }
  }

  /// グループのメモ一覧を取得
  static Future<List<MemoItem>> getGroupMemos(String groupId) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final snapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('memos')
          .orderBy('updatedAt', descending: true)
          .get();

      final memos = snapshot.docs
          .map((doc) => MemoItem.fromJson(doc.data()))
          .toList();
      // ピン留めされたメモを先頭に並べる
      memos.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      return memos;
    } catch (e, st) {
      _logError('グループメモ取得エラー', e, st);
      return [];
    }
  }

  /// グループにメモを保存
  static Future<void> saveGroupMemo(String groupId, MemoItem memo) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('memos')
          .doc(memo.id)
          .set(memo.toJson());
    } catch (e, st) {
      _logError('グループメモ保存エラー', e, st);
      rethrow;
    }
  }

  /// グループのメモを更新
  static Future<void> updateGroupMemo(String groupId, MemoItem memo) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final updatedMemo = memo.copyWith(updatedAt: DateTime.now());
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('memos')
          .doc(memo.id)
          .update(updatedMemo.toJson());
    } catch (e, st) {
      _logError('グループメモ更新エラー', e, st);
      rethrow;
    }
  }

  /// グループのメモを削除
  static Future<void> deleteGroupMemo(String groupId, String memoId) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('memos')
          .doc(memoId)
          .delete();
    } catch (e, st) {
      _logError('グループメモ削除エラー', e, st);
      rethrow;
    }
  }
}
