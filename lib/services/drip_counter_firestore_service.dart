import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DripCounterFirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

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
      
      return recordTimestamp.isAfter(startOfDay) && recordTimestamp.isBefore(endOfDay);
    }).toList();
  }
}
