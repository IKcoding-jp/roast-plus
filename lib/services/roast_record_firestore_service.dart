import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/roast_record.dart';

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
        return RoastRecord(
          id: doc.id,
          bean: dataMap['bean'] ?? '',
          weight: dataMap['weight'] ?? 0,
          roast: dataMap['roast'] ?? '',
          time: dataMap['time'] ?? '',
          memo: dataMap['memo'] ?? '',
          timestamp: (dataMap['timestamp'] as Timestamp).toDate(),
        );
      }).toList();
    } catch (e) {
      print('焙煎記録取得エラー: $e');
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
              final dataMap = data;
              return RoastRecord(
                id: doc.id,
                bean: dataMap['bean'] ?? '',
                weight: dataMap['weight'] ?? 0,
                roast: dataMap['roast'] ?? '',
                time: dataMap['time'] ?? '',
                memo: dataMap['memo'] ?? '',
                timestamp: (dataMap['timestamp'] as Timestamp).toDate(),
              );
            }).toList();
          });
    } catch (e) {
      print('焙煎記録ストリーム取得エラー: $e');
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
          .add({
            'bean': record.bean,
            'weight': record.weight,
            'roast': record.roast,
            'time': record.time,
            'memo': record.memo,
            'timestamp': Timestamp.fromDate(record.timestamp),
          });
    } catch (e) {
      print('焙煎記録追加エラー: $e');
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
          .update({
            'bean': record.bean,
            'weight': record.weight,
            'roast': record.roast,
            'time': record.time,
            'memo': record.memo,
            'timestamp': Timestamp.fromDate(record.timestamp),
          });
    } catch (e) {
      print('焙煎記録更新エラー: $e');
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
    } catch (e) {
      print('焙煎記録削除エラー: $e');
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
        return RoastRecord(
          id: doc.id,
          bean: data['bean'] ?? '',
          weight: data['weight'] ?? 0,
          roast: data['roast'] ?? '',
          time: data['time'] ?? '',
          memo: data['memo'] ?? '',
          timestamp: (data['timestamp'] as Timestamp).toDate(),
        );
      }).toList();
    } catch (e) {
      print('グループ焙煎記録取得エラー: $e');
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
              return RoastRecord(
                id: doc.id,
                bean: data['bean'] ?? '',
                weight: data['weight'] ?? 0,
                roast: data['roast'] ?? '',
                time: data['time'] ?? '',
                memo: data['memo'] ?? '',
                timestamp: (data['timestamp'] as Timestamp).toDate(),
              );
            }).toList();
          });
    } catch (e) {
      print('グループ焙煎記録ストリーム取得エラー: $e');
      return Stream.value([]);
    }
  }

  // グループに焙煎記録を追加
  static Future<void> addGroupRecord(String groupId, RoastRecord record) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('roastRecords')
          .add({
            'bean': record.bean,
            'weight': record.weight,
            'roast': record.roast,
            'time': record.time,
            'memo': record.memo,
            'timestamp': Timestamp.fromDate(record.timestamp),
            'createdBy': _auth.currentUser?.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('グループ焙煎記録追加エラー: $e');
      rethrow;
    }
  }

  // グループの焙煎記録を更新
  static Future<void> updateGroupRecord(
    String groupId,
    RoastRecord record,
  ) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('roastRecords')
          .doc(record.id)
          .update({
            'bean': record.bean,
            'weight': record.weight,
            'roast': record.roast,
            'time': record.time,
            'memo': record.memo,
            'timestamp': Timestamp.fromDate(record.timestamp),
            'updatedBy': _auth.currentUser?.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('グループ焙煎記録更新エラー: $e');
      rethrow;
    }
  }

  // グループの焙煎記録を削除
  static Future<void> deleteGroupRecord(String groupId, String recordId) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('roastRecords')
          .doc(recordId)
          .delete();
    } catch (e) {
      print('グループ焙煎記録削除エラー: $e');
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
    } catch (e) {
      print('焙煎時間パースエラー: $e');
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

      print('グループ $groupId の累積焙煎時間: ${totalMinutes.toStringAsFixed(1)}分');
      return totalMinutes;
    } catch (e) {
      print('累積焙煎時間計算エラー: $e');
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

      print('グループ $groupId の焙煎統計再計算完了: $stats');
      return stats;
    } catch (e) {
      print('焙煎統計再計算エラー: $e');
      return {
        'totalRoastTimeMinutes': 0.0,
        'totalRoastDays': 0,
        'totalRoastSessions': 0,
        'lastCalculated': DateTime.now().toIso8601String(),
      };
    }
  }
}
