import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

class DripCounterFirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static const String _logName = 'DripCounterFirestoreService';
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

  /// ドリップパックカウンターの記録を追加
  static Future<void> addDripPackRecord({
    required String bean,
    required String roast,
    required int count,
    required DateTime timestamp,
  }) async {
    if (_uid == null) throw Exception('未ログイン');
    final dateId =
        '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('dripPackRecords')
        .doc(dateId)
        .set({
          'records': FieldValue.arrayUnion([
            {
              'bean': bean,
              'roast': roast,
              'count': count,
              'timestamp': timestamp.toIso8601String(),
            },
          ]),
          'savedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  /// ドリップパックカウンターの記録を取得
  static Future<List<Map<String, dynamic>>> loadDripPackRecords({
    DateTime? date,
  }) async {
    if (_uid == null) throw Exception('未ログイン');
    final target = date ?? DateTime.now();
    final dateId =
        '${target.year}-${target.month.toString().padLeft(2, '0')}-${target.day.toString().padLeft(2, '0')}';
    final doc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('dripPackRecords')
        .doc(dateId)
        .get();
    if (!doc.exists) return [];
    final data = doc.data();
    if (data == null || data['records'] == null) return [];
    return List<Map<String, dynamic>>.from(data['records']);
  }

  /// 指定した日付に追加されたドリップパック記録のみを取得
  static Future<List<Map<String, dynamic>>> loadDripPackRecordsAddedOnDate({
    required DateTime date,
  }) async {
    if (_uid == null) throw Exception('未ログイン');

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(Duration(days: 1));

    final dateId =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final doc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('dripPackRecords')
        .doc(dateId)
        .get();

    if (!doc.exists) return [];
    final data = doc.data();
    if (data == null || data['records'] == null) return [];

    final allRecords = List<Map<String, dynamic>>.from(data['records']);

    // 指定した日付に追加された記録のみをフィルタリング
    return allRecords.where((record) {
      final recordTimestamp = DateTime.tryParse(record['timestamp'] ?? '');
      if (recordTimestamp == null) return false;

      return recordTimestamp.isAfter(startOfDay) &&
          recordTimestamp.isBefore(endOfDay);
    }).toList();
  }

  /// 全ドリップパック記録を取得（累積計算用）
  static Future<List<Map<String, dynamic>>> getAllDripPackRecords() async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('dripPackRecords')
          .get();

      final allRecords = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['records'] != null) {
          final records = List<Map<String, dynamic>>.from(data['records']);
          allRecords.addAll(records);
        }
      }

      // タイムスタンプでソート（古い順）
      allRecords.sort((a, b) {
        final aTime = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime.now();
        final bTime = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime.now();
        return aTime.compareTo(bTime);
      });

      return allRecords;
    } catch (e, st) {
      _logError('全ドリップパック記録取得エラー', e, st);
      return [];
    }
  }

  /// 累積ドリップパック数を計算
  static int calculateTotalDripPackCount(List<Map<String, dynamic>> records) {
    int totalCount = 0;
    for (final record in records) {
      final count = record['count'] as int? ?? 0;
      totalCount += count;
    }
    return totalCount;
  }

  /// グループのドリップパック統計を再計算
  static Future<Map<String, dynamic>> recalculateGroupDripPackStats(
    String groupId,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      _logInfo('グループドリップパック統計の再計算を開始 - groupId: $groupId');

      // グループの共有データからドリップパック記録を取得
      final sharedDataDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('sharedData')
          .doc('drip_counter_records')
          .get();

      final allRecords = <Map<String, dynamic>>[];

      if (sharedDataDoc.exists) {
        final data = sharedDataDoc.data();
        final records = data?['data']?['records'] as List<dynamic>?;

        if (records != null) {
          allRecords.addAll(records.cast<Map<String, dynamic>>());
        }
      }

      // タイムスタンプでソート（古い順）
      allRecords.sort((a, b) {
        final aTime = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime.now();
        final bTime = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime.now();
        return aTime.compareTo(bTime);
      });

      // 累積数を計算
      final totalCount = calculateTotalDripPackCount(allRecords);

      // 最初と最後の活動日を取得
      DateTime? firstActivityDate;
      DateTime? lastActivityDate;

      if (allRecords.isNotEmpty) {
        final firstRecord = allRecords.first;
        final lastRecord = allRecords.last;

        firstActivityDate = DateTime.tryParse(firstRecord['timestamp'] ?? '');
        lastActivityDate = DateTime.tryParse(lastRecord['timestamp'] ?? '');
      }

      final stats = {
        'totalDripPackCount': totalCount,
        'totalRecords': allRecords.length,
        'firstActivityDate': firstActivityDate?.toIso8601String(),
        'lastActivityDate': lastActivityDate?.toIso8601String(),
        'recalculatedAt': DateTime.now().toIso8601String(),
      };

      _logInfo('再計算完了 - 累積数: $totalCount, 記録数: ${allRecords.length}');

      return stats;
    } catch (e, st) {
      _logError('グループドリップパック統計再計算エラー', e, st);
      rethrow;
    }
  }
}
