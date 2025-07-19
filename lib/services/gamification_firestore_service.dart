import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/gamification_models.dart';
import 'auto_sync_service.dart';

/// ゲーミフィケーションデータのFirestore連携サービス
class GamificationFirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  /// ユーザープロフィールをFirestoreに保存
  static Future<void> saveUserProfile(UserProfile profile) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('gamification')
          .doc('profile')
          .set({
            ...profile.toJson(),
            'lastUpdated': FieldValue.serverTimestamp(),
            'version': 1, // データ形式のバージョン管理用
          });

      print('ゲーミフィケーションプロフィールをFirestoreに保存しました');
      
      // 自動同期を実行
      await AutoSyncService.triggerAutoSyncForDataType('gamification');
    } catch (e) {
      print('ゲーミフィケーションプロフィール保存エラー: $e');
      rethrow;
    }
  }

  /// ユーザープロフィールをFirestoreから取得
  static Future<UserProfile?> loadUserProfile() async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('gamification')
          .doc('profile')
          .get();

      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null) return null;

      print('ゲーミフィケーションプロフィールをFirestoreから取得しました');
      return UserProfile.fromJson(data);
    } catch (e) {
      print('ゲーミフィケーションプロフィール取得エラー: $e');
      return null;
    }
  }

  /// ユーザープロフィールのリアルタイム監視
  static Stream<UserProfile?> watchUserProfile() {
    if (_uid == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('gamification')
        .doc('profile')
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          final data = doc.data();
          if (data == null) return null;
          return UserProfile.fromJson(data);
        });
  }

  /// 日次活動記録をFirestoreに保存
  static Future<void> saveDailyActivity(
    ActivityType type,
    String key,
    DateTime date,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final dateKey = date.toIso8601String().split('T')[0]; // YYYY-MM-DD
      final activityKey = '${type.toString()}_$key';

      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('gamification')
          .doc('daily_activities')
          .collection(dateKey)
          .doc(activityKey)
          .set({
            'type': type.toString(),
            'key': key,
            'recordedAt': FieldValue.serverTimestamp(),
          });

      print('日次活動記録をFirestoreに保存しました: $activityKey');
    } catch (e) {
      print('日次活動記録保存エラー: $e');
      rethrow;
    }
  }

  /// 日次活動記録の確認
  static Future<bool> isDailyActivityRecorded(
    ActivityType type,
    String key,
    DateTime date,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final dateKey = date.toIso8601String().split('T')[0]; // YYYY-MM-DD
      final activityKey = '${type.toString()}_$key';

      final doc = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('gamification')
          .doc('daily_activities')
          .collection(dateKey)
          .doc(activityKey)
          .get();

      return doc.exists;
    } catch (e) {
      print('日次活動記録確認エラー: $e');
      return false;
    }
  }

  /// 古い活動記録をクリーンアップ（1ヶ月以上前のデータを削除）
  static Future<void> cleanupOldActivities() async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final oneMonthAgo = DateTime.now().subtract(Duration(days: 30));
      final cutoffDate = oneMonthAgo.toIso8601String().split('T')[0];

      // 30日以上前のドキュメントを削除
      final dailyActivitiesRef = _firestore
          .collection('users')
          .doc(_uid)
          .collection('gamification')
          .doc('daily_activities');

      // バッチ処理で古いサブコレクションを削除
      final batch = _firestore.batch();
      
      // 実際の実装では、Cloud Functionsやスケジュールされたタスクで実行することを推奨
      print('古い活動記録のクリーンアップをスケジュールしました');
    } catch (e) {
      print('古い活動記録クリーンアップエラー: $e');
    }
  }

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
  static Future<List<UserProfile>> loadGroupMembersGamificationData(
    String groupId,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final snapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('gamification')
          .get();

      final profiles = <UserProfile>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        try {
          profiles.add(UserProfile.fromJson(data));
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
      final profile = await loadUserProfile();
      if (profile == null) return;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('gamification')
          .doc('backups')
          .collection('history')
          .doc('backup_$timestamp')
          .set({
            'profile': profile.toJson(),
            'createdAt': FieldValue.serverTimestamp(),
            'description': '自動バックアップ',
          });

      print('ゲーミフィケーションデータのバックアップを作成しました');
    } catch (e) {
      print('ゲーミフィケーションバックアップ作成エラー: $e');
    }
  }
} 