import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/roast_schedule_models.dart';

class RoastScheduleMemoService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ユーザーのローストスケジュールメモを取得
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
    } catch (e) {
      print('ローストスケジュールメモ取得エラー: $e');
      return [];
    }
  }

  // ローストスケジュールメモを保存
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
          .set({'memos': memosData, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      print('ローストスケジュールメモ保存エラー: $e');
      throw e;
    }
  }

  // グループのローストスケジュールメモを取得
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
    } catch (e) {
      print('グループローストスケジュールメモ取得エラー: $e');
      return [];
    }
  }

  // グループのローストスケジュールメモを保存
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
          .set({'memos': memosData, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      print('グループローストスケジュールメモ保存エラー: $e');
      throw e;
    }
  }

  // メモを追加
  static Future<void> addMemo(RoastScheduleMemo memo, {String? groupId}) async {
    try {
      List<RoastScheduleMemo> memos;

      if (groupId != null) {
        memos = await getGroupMemos(groupId);
      } else {
        memos = await getUserMemos();
      }

      memos.add(memo);

      if (groupId != null) {
        await saveGroupMemos(groupId, memos);
      } else {
        await saveUserMemos(memos);
      }
    } catch (e) {
      print('メモ追加エラー: $e');
      throw e;
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
        memos = await getGroupMemos(groupId);
      } else {
        memos = await getUserMemos();
      }

      final index = memos.indexWhere((m) => m.id == memo.id);
      if (index != -1) {
        memos[index] = memo;

        if (groupId != null) {
          await saveGroupMemos(groupId, memos);
        } else {
          await saveUserMemos(memos);
        }
      }
    } catch (e) {
      print('メモ更新エラー: $e');
      throw e;
    }
  }

  // メモを削除
  static Future<void> deleteMemo(String memoId, {String? groupId}) async {
    try {
      List<RoastScheduleMemo> memos;

      if (groupId != null) {
        memos = await getGroupMemos(groupId);
      } else {
        memos = await getUserMemos();
      }

      memos.removeWhere((m) => m.id == memoId);

      if (groupId != null) {
        await saveGroupMemos(groupId, memos);
      } else {
        await saveUserMemos(memos);
      }
    } catch (e) {
      print('メモ削除エラー: $e');
      throw e;
    }
  }
}
