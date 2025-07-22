import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group_gamification_models.dart';
import 'auto_sync_service.dart';

/// グループゲーミフィケーションデータのFirestore連携サービス
class GamificationFirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  /// グループ用ゲーミフィケーションデータの保存
  static Future<void> saveGroupGamificationData(
    String groupId,
    Map<String, dynamic> data,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('gamification')
          .doc(_uid)
          .set({
            ...data,
            'updatedBy': _uid,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

      print('グループゲーミフィケーションデータを保存しました');
    } catch (e) {
      print('グループゲーミフィケーションデータ保存エラー: $e');
      rethrow;
    }
  }

  /// グループ用ゲーミフィケーションデータの取得
  static Future<Map<String, dynamic>?> loadGroupGamificationData(
    String groupId,
    String userId,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final doc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('gamification')
          .doc(userId)
          .get();

      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      print('グループゲーミフィケーションデータ取得エラー: $e');
      return null;
    }
  }

  /// グループメンバー全員のゲーミフィケーションデータを取得
  static Future<List<GroupGamificationProfile>>
  loadGroupMembersGamificationData(String groupId) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final snapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('gamification')
          .get();

      final profiles = <GroupGamificationProfile>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        try {
          profiles.add(GroupGamificationProfile.fromJson(data));
        } catch (e) {
          print('プロフィール解析エラー (${doc.id}): $e');
        }
      }

      return profiles;
    } catch (e) {
      print('グループメンバーゲーミフィケーションデータ取得エラー: $e');
      return [];
    }
  }

  /// ゲーミフィケーションデータの同期
  static Future<void> syncGamificationData() async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      // 自動同期実行
      await AutoSyncService.triggerAutoSyncForDataType('gamification');
      print('ゲーミフィケーションデータの同期を実行しました');
    } catch (e) {
      print('ゲーミフィケーションデータ同期エラー: $e');
      rethrow;
    }
  }

  /// データのバックアップ作成
  static Future<void> createBackup() async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('gamification')
          .doc('backups')
          .collection('history')
          .doc('backup_$timestamp')
          .set({
            'createdAt': FieldValue.serverTimestamp(),
            'description': '自動バックアップ',
          });

      print('ゲーミフィケーションデータのバックアップを作成しました');
    } catch (e) {
      print('ゲーミフィケーションバックアップ作成エラー: $e');
    }
  }
}
