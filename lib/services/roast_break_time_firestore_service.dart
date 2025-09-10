import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/roast_break_time.dart';

class RoastBreakTimeFirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  /// 休憩時間設定を保存
  static Future<void> saveBreakTimes(List<RoastBreakTime> breaks) async {
    if (_uid == null) throw Exception('未ログイン');
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('roastBreakTimes')
        .doc('settings')
        .set({
          'breakTimes': breaks.map((b) => b.toJson()).toList(),
          'savedAt': FieldValue.serverTimestamp(),
        });
  }

  /// 休憩時間設定を取得
  static Future<List<RoastBreakTime>> loadBreakTimes() async {
    if (_uid == null) throw Exception('未ログイン');
    final doc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('roastBreakTimes')
        .doc('settings')
        .get();
    if (!doc.exists) return [];
    final data = doc.data();
    if (data == null || data['breakTimes'] == null) return [];
    return List<Map<String, dynamic>>.from(
      data['breakTimes'],
    ).map((e) => RoastBreakTime.fromJson(e)).toList();
  }
}
