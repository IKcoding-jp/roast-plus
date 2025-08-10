import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/roast_record.dart';
import '../utils/permission_utils.dart';
import 'dart:developer' as developer;

class RoastRecordFirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ユーザーの焙煎記録を取得（ページネーション対応）
  static Future<List<RoastRecord>> getRecords({
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      Query query = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('roastRecords')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        if (data == null) {
          return RoastRecord(
            id: doc.id,
            bean: '',
            weight: 0,
            roast: '',
            time: '',
            memo: '',
            timestamp: DateTime.now(),
          );
        }
        final dataMap = data as Map<String, dynamic>;
        return RoastRecord.fromMap(dataMap, id: doc.id);
      }).toList();
    } catch (e, st) {
      developer.log(
        '焙煎記録取得エラー: $e',
        name: 'RoastRecordFirestoreService',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  // 焙煎記録のストリームを取得
  static Stream<List<RoastRecord>> getRecordsStream() {
    try {
      final user = _auth.currentUser;
      if (user == null) return Stream.value([]);

      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('roastRecords')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((querySnapshot) {
            return querySnapshot.docs.map((doc) {
              final data = doc.data();
              return RoastRecord.fromMap(data, id: doc.id);
            }).toList();
          });
    } catch (e, st) {
      developer.log(
        '焙煎記録ストリーム取得エラー: $e',
        name: 'RoastRecordFirestoreService',
        error: e,
        stackTrace: st,
      );
      return Stream.value([]);
    }
  }

  // 焙煎記録を追加
  static Future<void> addRecord(RoastRecord record) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('ユーザーが認証されていません');

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('roastRecords')
          .add(record.toMap());
    } catch (e, st) {
      developer.log(
        '焙煎記録追加エラー: $e',
        name: 'RoastRecordFirestoreService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  // 焙煎記録を更新
  static Future<void> updateRecord(RoastRecord record) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('ユーザーが認証されていません');

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('roastRecords')
          .doc(record.id)
          .update(record.toMap());
    } catch (e, st) {
      developer.log(
        '焙煎記録更新エラー: $e',
        name: 'RoastRecordFirestoreService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  // 焙煎記録を削除
  static Future<void> deleteRecord(String recordId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('ユーザーが認証されていません');

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('roastRecords')
          .doc(recordId)
          .delete();
    } catch (e, st) {
      developer.log(
        '焙煎記録削除エラー: $e',
        name: 'RoastRecordFirestoreService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  // グループの焙煎記録を取得
  static Future<List<RoastRecord>> getGroupRecords(String groupId) async {
    try {
      final querySnapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('roastRecords')
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return RoastRecord.fromMap(data, id: doc.id);
      }).toList();
    } catch (e, st) {
      developer.log(
        'グループ焙煎記録取得エラー: $e',
        name: 'RoastRecordFirestoreService',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  // グループの焙煎記録ストリームを取得
  static Stream<List<RoastRecord>> getGroupRecordsStream(String groupId) {
    try {
      return _firestore
          .collection('groups')
          .doc(groupId)
          .collection('roastRecords')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((querySnapshot) {
            return querySnapshot.docs.map((doc) {
              final data = doc.data();
              return RoastRecord.fromMap(data, id: doc.id);
            }).toList();
          });
    } catch (e, st) {
      developer.log(
        'グループ焙煎記録ストリーム取得エラー: $e',
        name: 'RoastRecordFirestoreService',
        error: e,
        stackTrace: st,
      );
      return Stream.value([]);
    }
  }

  // グループに焙煎記録を追加（権限チェック付き）
  static Future<void> addGroupRecord(String groupId, RoastRecord record) async {
    try {
      // 権限チェック
      final canCreate = await PermissionUtils.canCreateDataType(
        groupId: groupId,
        dataType: 'roastRecordInput',
      );

      if (!canCreate) {
        throw Exception(PermissionUtils.getPermissionErrorMessage('焙煎記録入力'));
      }

      final user = _auth.currentUser;

      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('roastRecords')
          .add({
            ...record.toMap(),
            'createdBy': user?.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (e, st) {
      developer.log(
        'グループ焙煎記録追加エラー: $e',
        name: 'RoastRecordFirestoreService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  // グループの焙煎記録を更新（権限チェック付き）
  static Future<void> updateGroupRecord(
    String groupId,
    RoastRecord record,
  ) async {
    try {
      // 権限チェック
      final canEdit = await PermissionUtils.canEditDataType(
        groupId: groupId,
        dataType: 'roastRecords',
      );

      if (!canEdit) {
        throw Exception(PermissionUtils.getPermissionErrorMessage('焙煎記録一覧'));
      }

      final user = _auth.currentUser;

      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('roastRecords')
          .doc(record.id)
          .update({
            ...record.toMap(),
            'updatedBy': user?.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e, st) {
      developer.log(
        'グループ焙煎記録更新エラー: $e',
        name: 'RoastRecordFirestoreService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  // グループの焙煎記録を削除（権限チェック付き）
  static Future<void> deleteGroupRecord(String groupId, String recordId) async {
    try {
      // 権限チェック
      final canDelete = await PermissionUtils.canDeleteDataType(
        groupId: groupId,
        dataType: 'roastRecords',
      );

      if (!canDelete) {
        throw Exception(PermissionUtils.getPermissionErrorMessage('焙煎記録一覧'));
      }

      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('roastRecords')
          .doc(recordId)
          .delete();
    } catch (e, st) {
      developer.log(
        'グループ焙煎記録削除エラー: $e',
        name: 'RoastRecordFirestoreService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// 焙煎時間文字列を分単位に変換
  static int parseRoastTimeToMinutes(String timeString) {
    try {
      // "10:30" 形式の時間文字列を分に変換
      final parts = timeString.split(':');
      if (parts.length == 2) {
        final minutes = int.tryParse(parts[0]) ?? 0;
        final seconds = int.tryParse(parts[1]) ?? 0;
        return minutes + (seconds / 60).round();
      }
      // 数値のみの場合は分として扱う
      return int.tryParse(timeString) ?? 0;
    } catch (e, st) {
      developer.log(
        '焙煎時間パースエラー: $e',
        name: 'RoastRecordFirestoreService',
        error: e,
        stackTrace: st,
      );
      return 0;
    }
  }

  /// グループの累積焙煎時間を計算（分単位）
  static Future<double> calculateGroupTotalRoastTime(String groupId) async {
    try {
      final records = await getGroupRecords(groupId);
      double totalMinutes = 0.0;

      for (final record in records) {
        final minutes = parseRoastTimeToMinutes(record.time);
        totalMinutes += minutes;
      }

      developer.log(
        'グループ $groupId の累積焙煎時間: ${totalMinutes.toStringAsFixed(1)}分',
        name: 'RoastRecordFirestoreService',
      );
      return totalMinutes;
    } catch (e, st) {
      developer.log(
        '累積焙煎時間計算エラー: $e',
        name: 'RoastRecordFirestoreService',
        error: e,
        stackTrace: st,
      );
      return 0.0;
    }
  }

  /// グループの焙煎統計を再計算
  static Future<Map<String, dynamic>> recalculateGroupRoastStats(
    String groupId,
  ) async {
    try {
      final records = await getGroupRecords(groupId);
      double totalMinutes = 0.0;
      Set<String> roastDays = {};

      for (final record in records) {
        final minutes = parseRoastTimeToMinutes(record.time);
        totalMinutes += minutes;

        // 焙煎日を記録（1日最大3回としてカウント）
        final dateKey =
            '${record.timestamp.year}-${record.timestamp.month.toString().padLeft(2, '0')}-${record.timestamp.day.toString().padLeft(2, '0')}';
        roastDays.add(dateKey);
      }

      final stats = {
        'totalRoastTimeMinutes': totalMinutes,
        'totalRoastDays': roastDays.length,
        'totalRoastSessions': records.length,
        'lastCalculated': DateTime.now().toIso8601String(),
      };

      developer.log(
        'グループ $groupId の焙煎統計再計算完了: $stats',
        name: 'RoastRecordFirestoreService',
      );
      return stats;
    } catch (e, st) {
      developer.log(
        '焙煎統計再計算エラー: $e',
        name: 'RoastRecordFirestoreService',
        error: e,
        stackTrace: st,
      );
      return {
        'totalRoastTimeMinutes': 0.0,
        'totalRoastDays': 0,
        'totalRoastSessions': 0,
        'lastCalculated': DateTime.now().toIso8601String(),
      };
    }
  }
}
