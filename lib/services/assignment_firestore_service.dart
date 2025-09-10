import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AssignmentFirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  /// 担当表のメンバー・ラベルを保存
  static Future<void> saveAssignmentMembers({
    required List<String> aMembers,
    required List<String> bMembers,
    required List<String> leftLabels,
    required List<String> rightLabels,
  }) async {
    if (_uid == null) throw Exception('未ログイン');
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('assignmentMembers')
        .doc('assignment')
        .set({
          'aMembers': aMembers,
          'bMembers': bMembers,
          'leftLabels': leftLabels,
          'rightLabels': rightLabels,
          'savedAt': FieldValue.serverTimestamp(),
        });
  }

  /// 担当表の班データ（新しい形式）を保存
  static Future<void> saveAssignmentTeams({
    required List<Map<String, dynamic>> teams,
    required List<String> leftLabels,
    required List<String> rightLabels,
  }) async {
    if (_uid == null) throw Exception('未ログイン');
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('assignmentMembers')
        .doc('assignment')
        .set({
          'teams': teams,
          'leftLabels': leftLabels,
          'rightLabels': rightLabels,
          'savedAt': FieldValue.serverTimestamp(),
        });
  }

  /// 担当表のメンバー・ラベルを取得
  static Future<Map<String, dynamic>?> loadAssignmentMembers() async {
    if (_uid == null) throw Exception('未ログイン');
    final doc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('assignmentMembers')
        .doc('assignment')
        .get();
    if (!doc.exists) return null;
    return doc.data();
  }

  /// 担当表のメンバー・ラベルデータをクリア
  static Future<void> clearAssignmentMembers() async {
    if (_uid == null) throw Exception('未ログイン');
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('assignmentMembers')
        .doc('assignment')
        .delete();
  }

  /// 担当履歴を保存
  static Future<void> saveAssignmentHistory({
    required String dateKey,
    required List<String> assignments,
    required List<String> leftLabels,
    required List<String> rightLabels,
  }) async {
    if (_uid == null) throw Exception('未ログイン');
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('assignmentHistory')
        .doc(dateKey)
        .set({
          'assignments': assignments,
          'leftLabels': leftLabels,
          'rightLabels': rightLabels,
          'savedAt': FieldValue.serverTimestamp(),
        });
  }

  /// 担当履歴を取得
  static Future<List<String>?> loadAssignmentHistory(String dateKey) async {
    if (_uid == null) throw Exception('未ログイン');
    final doc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('assignmentHistory')
        .doc(dateKey)
        .get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null || data['assignments'] == null) return null;
    return List<String>.from(data['assignments']);
  }

  /// 担当履歴とラベル情報を取得
  static Future<Map<String, dynamic>?> loadAssignmentHistoryWithLabels(
    String dateKey,
  ) async {
    if (_uid == null) throw Exception('未ログイン');
    final doc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('assignmentHistory')
        .doc(dateKey)
        .get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return {
      'assignments': data['assignments'] != null
          ? List<String>.from(data['assignments'])
          : [],
      'leftLabels': data['leftLabels'] != null
          ? List<String>.from(data['leftLabels'])
          : [],
      'rightLabels': data['rightLabels'] != null
          ? List<String>.from(data['rightLabels'])
          : [],
    };
  }

  /// 担当履歴を削除
  static Future<void> deleteAssignmentHistory(String dateKey) async {
    if (_uid == null) throw Exception('未ログイン');
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('assignmentHistory')
        .doc(dateKey)
        .delete();
  }

  /// 担当履歴を全件取得
  static Future<Map<String, List<String>>> loadAllAssignmentHistory() async {
    if (_uid == null) throw Exception('未ログイン');
    final snapshot = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('assignmentHistory')
        .orderBy('savedAt', descending: true)
        .get();
    final result = <String, List<String>>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['assignments'] != null) {
        result[doc.id] = List<String>.from(data['assignments']);
      }
    }
    return result;
  }
}
