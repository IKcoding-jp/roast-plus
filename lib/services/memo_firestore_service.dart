import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/memo_models.dart';

class MemoFirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

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
    } catch (e) {
      print('メモ取得エラー: $e');
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
    } catch (e) {
      print('メモ保存エラー: $e');
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
    } catch (e) {
      print('メモ更新エラー: $e');
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
    } catch (e) {
      print('メモ削除エラー: $e');
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
    } catch (e) {
      print('メモピン留めエラー: $e');
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

      final memos = snapshot.docs.map((doc) => MemoItem.fromJson(doc.data())).toList();
      // ピン留めされたメモを先頭に並べる
      memos.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      return memos;
    } catch (e) {
      print('グループメモ取得エラー: $e');
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
    } catch (e) {
      print('グループメモ保存エラー: $e');
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
    } catch (e) {
      print('グループメモ更新エラー: $e');
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
    } catch (e) {
      print('グループメモ削除エラー: $e');
      rethrow;
    }
  }
}
