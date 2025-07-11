import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScheduleFirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  /// 本日のスケジュール（ラベル・内容）を保存
  static Future<void> saveTodayTodoSchedule({
    required List<String> labels,
    required Map<String, String> contents,
  }) async {
    if (_uid == null) throw Exception('未ログイン');
    final today = DateTime.now();
    final docId =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('todaySchedule')
        .doc(docId)
        .set({
          'labels': labels,
          'contents': contents,
          'savedAt': FieldValue.serverTimestamp(),
        });
  }

  /// 本日のスケジュール（ラベル・内容）を取得
  static Future<Map<String, dynamic>?> loadTodayTodoSchedule() async {
    if (_uid == null) throw Exception('未ログイン');
    final today = DateTime.now();
    final docId =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final doc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('todaySchedule')
        .doc(docId)
        .get();
    if (!doc.exists) return null;
    return doc.data();
  }

  /// 本日のローストスケジュールを取得
  static Future<Map<String, dynamic>?> loadTodaySchedule() async {
    if (_uid == null) throw Exception('未ログイン');
    final today = DateTime.now();
    final docId =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final doc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('schedules')
        .doc(docId)
        .get();
    return doc.exists ? doc.data() : null;
  }

  /// 時間ラベルを保存
  static Future<void> saveTimeLabels(List<String> labels) async {
    if (_uid == null) throw Exception('未ログイン');
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('labels')
        .doc('timeLabels')
        .set({'labels': labels, 'savedAt': FieldValue.serverTimestamp()});
  }

  /// 時間ラベルを取得
  static Future<List<String>?> loadTimeLabels() async {
    if (_uid == null) throw Exception('未ログイン');
    final doc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('labels')
        .doc('timeLabels')
        .get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null || data['labels'] == null) return null;
    return List<String>.from(data['labels']);
  }

  /// TODOリストのタスクを保存
  static Future<void> saveTodayTodoList({
    required List<Map<String, dynamic>> todos,
  }) async {
    if (_uid == null) throw Exception('未ログイン');
    final today = DateTime.now();
    final docId =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('todoList')
        .doc(docId)
        .set({'todos': todos, 'savedAt': FieldValue.serverTimestamp()});
  }

  /// TODOリストのタスクを取得
  static Future<List<Map<String, dynamic>>?> loadTodayTodoList() async {
    if (_uid == null) throw Exception('未ログイン');
    final today = DateTime.now();
    final docId =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final doc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('todoList')
        .doc(docId)
        .get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null || data['todos'] == null) return null;
    return List<Map<String, dynamic>>.from(data['todos']);
  }

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

  /// 担当履歴を保存
  static Future<void> saveAssignmentHistory({
    required String dateKey,
    required List<String> assignments,
  }) async {
    if (_uid == null) throw Exception('未ログイン');
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('assignmentHistory')
        .doc(dateKey)
        .set({
          'assignments': assignments,
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
