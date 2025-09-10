import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group_gamification_models.dart';
import 'auto_sync_service.dart';
import 'dart:developer' as developer;

/// グループゲーミフィケーションデータのFirestore連携サービス
class GamificationFirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static const String _logName = 'GamificationFirestoreService';
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

      _logInfo('グループゲーミフィケーションデータを保存しました');
    } catch (e, st) {
      _logError('グループゲーミフィケーションデータ保存エラー', e, st);
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
    } catch (e, st) {
      _logError('グループゲーミフィケーションデータ取得エラー', e, st);
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
        } catch (e, st) {
          _logError('プロフィール解析エラー (${doc.id})', e, st);
        }
      }

      return profiles;
    } catch (e, st) {
      _logError('グループメンバーゲーミフィケーションデータ取得エラー', e, st);
      return [];
    }
  }

  /// ゲーミフィケーションデータの同期
  static Future<void> syncGamificationData() async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      // 自動同期実行
      await AutoSyncService.triggerAutoSyncForDataType('gamification');
      _logInfo('ゲーミフィケーションデータの同期を実行しました');
    } catch (e, st) {
      _logError('ゲーミフィケーションデータ同期エラー', e, st);
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

      _logInfo('ゲーミフィケーションデータのバックアップを作成しました');
    } catch (e, st) {
      _logError('ゲーミフィケーションバックアップ作成エラー', e, st);
    }
  }
}
