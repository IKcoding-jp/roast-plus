import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoastTimerSettingsFirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  /// 焙煎タイマー設定（全項目）を保存
  static Future<void> saveRoastTimerSettings({
    required int preheatMinutes,
    required int coolingMinutes,
    required bool usePreheat,
    required bool useCooling,
    required bool useRoast,
  }) async {
    if (_uid == null) throw Exception('未ログイン');
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('roastTimerSettings')
        .doc('settings')
        .set({
          'preheatMinutes': preheatMinutes,
          'coolingMinutes': coolingMinutes,
          'usePreheat': usePreheat,
          'useCooling': useCooling,
          'useRoast': useRoast,
          'savedAt': FieldValue.serverTimestamp(),
        });
  }

  /// 焙煎タイマー設定（全項目）を取得
  static Future<Map<String, dynamic>?> loadRoastTimerSettings() async {
    if (_uid == null) throw Exception('未ログイン');
    final doc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('roastTimerSettings')
        .doc('settings')
        .get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return data;
  }
}
