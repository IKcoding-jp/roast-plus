import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/tasting_models.dart';
import 'auto_sync_service.dart';

class TastingFirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  /// テイスティング記録を取得
  static Future<List<TastingRecord>> getTastingRecords() async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('tasting_records')
          .orderBy('tastingDate', descending: true)
          .get();

      final records = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return TastingRecord.fromMap(data);
      }).toList();

      return records;
    } catch (e) {
      print('テイスティング記録取得エラー: $e');
      return [];
    }
  }

  /// テイスティング記録のストリームを取得
  static Stream<List<TastingRecord>> getTastingRecordsStream() {
    if (_uid == null) return Stream.value([]);

    try {
      return _firestore
          .collection('users')
          .doc(_uid)
          .collection('tasting_records')
          .orderBy('tastingDate', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return TastingRecord.fromMap(data);
            }).toList();
          });
    } catch (e) {
      print('テイスティング記録ストリームエラー: $e');
      return Stream.value([]);
    }
  }

  /// テイスティング記録を保存
  static Future<void> saveTastingRecord(TastingRecord record) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final recordData = record.toMap();
      recordData['userId'] = _uid;
      recordData['updatedAt'] = DateTime.now().toIso8601String();

      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('tasting_records')
          .doc(record.id)
          .set(recordData);

      // 自動同期を実行
      await AutoSyncService.triggerAutoSyncForDataType('tasting_records');
    } catch (e) {
      print('テイスティング記録保存エラー: $e');
      rethrow;
    }
  }

  /// テイスティング記録を更新
  static Future<void> updateTastingRecord(TastingRecord record) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final recordData = record.toMap();
      recordData['updatedAt'] = DateTime.now().toIso8601String();

      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('tasting_records')
          .doc(record.id)
          .update(recordData);

      // 自動同期を実行
      await AutoSyncService.triggerAutoSyncForDataType('tasting_records');
    } catch (e) {
      print('テイスティング記録更新エラー: $e');
      rethrow;
    }
  }

  /// テイスティング記録を削除
  static Future<void> deleteTastingRecord(String recordId) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('tasting_records')
          .doc(recordId)
          .delete();

      // 自動同期を実行
      await AutoSyncService.triggerAutoSyncForDataType('tasting_records');
    } catch (e) {
      print('テイスティング記録削除エラー: $e');
      rethrow;
    }
  }

  /// グループのテイスティング記録を取得
  static Future<List<TastingRecord>> getGroupTastingRecords(
    String groupId,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final snapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('tasting_records')
          .orderBy('tastingDate', descending: true)
          .get();

      final records = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return TastingRecord.fromMap(data);
      }).toList();

      return records;
    } catch (e) {
      print('グループテイスティング記録取得エラー: $e');
      return [];
    }
  }

  /// グループにテイスティング記録を保存
  static Future<void> saveGroupTastingRecord(
    String groupId,
    TastingRecord record,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final recordData = record.toMap();
      recordData['userId'] = _uid;
      recordData['updatedAt'] = DateTime.now().toIso8601String();

      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('tasting_records')
          .doc(record.id)
          .set(recordData);
    } catch (e) {
      print('グループテイスティング記録保存エラー: $e');
      rethrow;
    }
  }

  /// グループのテイスティング記録を更新
  static Future<void> updateGroupTastingRecord(
    String groupId,
    TastingRecord record,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final recordData = record.toMap();
      recordData['updatedAt'] = DateTime.now().toIso8601String();

      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('tasting_records')
          .doc(record.id)
          .update(recordData);
    } catch (e) {
      print('グループテイスティング記録更新エラー: $e');
      rethrow;
    }
  }

  /// グループのテイスティング記録を削除
  static Future<void> deleteGroupTastingRecord(
    String groupId,
    String recordId,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('tasting_records')
          .doc(recordId)
          .delete();
    } catch (e) {
      print('グループテイスティング記録削除エラー: $e');
      rethrow;
    }
  }

  /// グループのテイスティング記録のストリームを取得
  static Stream<List<TastingRecord>> getGroupTastingRecordsStream(
    String groupId,
  ) {
    try {
      return _firestore
          .collection('groups')
          .doc(groupId)
          .collection('tasting_records')
          .orderBy('tastingDate', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return TastingRecord.fromMap(data);
            }).toList();
          });
    } catch (e) {
      print('グループテイスティング記録ストリームエラー: $e');
      return Stream.value([]);
    }
  }

  /// 個人用テイスティング記録のドキュメント参照を取得
  static Future<DocumentSnapshot<Map<String, dynamic>>> getTastingRecordDoc(
    String id,
  ) async {
    if (_uid == null) throw Exception('未ログイン');
    return await _firestore
        .collection('users')
        .doc(_uid)
        .collection('tasting_records')
        .doc(id)
        .get();
  }

  /// グループ用テイスティング記録のドキュメント参照を取得
  static Future<DocumentSnapshot<Map<String, dynamic>>>
  getGroupTastingRecordDoc(String groupId, String id) async {
    return await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('tasting_records')
        .doc(id)
        .get();
  }
}
