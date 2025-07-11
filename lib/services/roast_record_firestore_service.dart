import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/roast_record.dart';

class RoastRecordFirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get _uid => _auth.currentUser?.uid ?? '';

  static CollectionReference get _collection =>
      _firestore.collection('users').doc(_uid).collection('roast_records');

  // 追加
  static Future<void> addRecord(RoastRecord record) async {
    await _collection.add(record.toMap());
  }

  // 取得（ストリーム）
  static Stream<List<RoastRecord>> getRecordsStream() {
    return _collection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => RoastRecord.fromMap(
                  doc.data() as Map<String, dynamic>,
                  id: doc.id,
                ),
              )
              .toList(),
        );
  }

  // 単発取得
  static Future<List<RoastRecord>> getRecordsOnce() async {
    final snapshot = await _collection
        .orderBy('timestamp', descending: true)
        .get();
    return snapshot.docs
        .map(
          (doc) => RoastRecord.fromMap(
            doc.data() as Map<String, dynamic>,
            id: doc.id,
          ),
        )
        .toList();
  }

  // 更新
  static Future<void> updateRecord(RoastRecord record) async {
    await _collection.doc(record.id).update(record.toMap());
  }

  // 削除
  static Future<void> deleteRecord(String id) async {
    await _collection.doc(id).delete();
  }
}
