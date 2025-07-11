import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoastTimerSettingsFirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  /// 焙煎タイマー設定（予熱時間）を保存
  static Future<void> saveRoastTimerSettings({
    required int preheatMinutes,
  }) async {
    if (_uid == null) throw Exception('未ログイン');
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('roastTimerSettings')
        .doc('settings')
        .set({
          'preheatMinutes': preheatMinutes,
          'savedAt': FieldValue.serverTimestamp(),
        });
  }

  /// 焙煎タイマー設定（予熱時間）を取得
  static Future<int?> loadRoastTimerSettings() async {
    if (_uid == null) throw Exception('未ログイン');
    final doc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('roastTimerSettings')
        .doc('settings')
        .get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null || data['preheatMinutes'] == null) return null;
    return data['preheatMinutes'] as int;
  }
}
