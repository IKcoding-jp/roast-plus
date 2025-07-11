import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../pages/roast/roast_scheduler_tab.dart';

class ScheduleFirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  /// 本日のスケジュールを保存
  static Future<void> saveTodaySchedule({
    required List<RoastScheduleResultModel> am,
    required List<RoastScheduleResultModel> pm,
    required String overflowMsg,
  }) async {
    if (_uid == null) throw Exception('未ログイン');
    final today = DateTime.now();
    final docId =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('schedules')
        .doc(docId)
        .set({
          'am': am.map((e) => e.toJson()).toList(),
          'pm': pm.map((e) => e.toJson()).toList(),
          'overflowMsg': overflowMsg,
          'savedAt': FieldValue.serverTimestamp(),
        });
  }

  /// 本日のスケジュールを取得
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

  /// 時間ラベルリストを保存
  static Future<void> saveTimeLabels(List<String> labels) async {
    if (_uid == null) throw Exception('未ログイン');
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('labels')
        .doc('timeLabels')
        .set({'labels': labels, 'savedAt': FieldValue.serverTimestamp()});
  }

  /// 時間ラベルリストを取得
  static Future<List<String>> loadTimeLabels() async {
    if (_uid == null) throw Exception('未ログイン');
    final doc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('labels')
        .doc('timeLabels')
        .get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      final labels = data['labels'] as List<dynamic>?;
      return labels?.map((e) => e.toString()).toList() ?? [];
    }
    return [];
  }

  /// 本日のスケジュール（TodoListPage用）を保存
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

  /// 本日のスケジュール（TodoListPage用）を取得
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
    return doc.exists ? doc.data() : null;
  }
}
