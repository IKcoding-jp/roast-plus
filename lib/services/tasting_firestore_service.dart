import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/tasting_models.dart';
import 'auto_sync_service.dart';
import 'dart:developer' as developer;

class TastingFirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static const String _logName = 'TastingFirestoreService';
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

  // --- グループ協調: コレクション参照 ---
  static CollectionReference<Map<String, dynamic>> _groupSessionsCol(
    String groupId,
  ) => _firestore
      .collection('groups')
      .doc(groupId)
      .collection('tasting_sessions');

  static DocumentReference<Map<String, dynamic>> _sessionDoc(
    String groupId,
    String sessionId,
  ) => _groupSessionsCol(groupId).doc(sessionId);

  static CollectionReference<Map<String, dynamic>> _entriesCol(
    String groupId,
    String sessionId,
  ) => _sessionDoc(groupId, sessionId).collection('entries');

  // 補助: 1–5クランプ
  static double _clamp(double v) => v < 1.0 ? 1.0 : (v > 5.0 ? 5.0 : v);

  /// テイスティング記録を取得
  static Future<List<TastingRecord>> getTastingRecords() async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('tasting_records')
          .orderBy('tastingDate', descending: true)
          .get();

      final records = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return TastingRecord.fromMap(data);
      }).toList();

      return records;
    } catch (e, st) {
      _logError('テイスティング記録取得エラー', e, st);
      return [];
    }
  }

  /// テイスティング記録のストリームを取得
  static Stream<List<TastingRecord>> getTastingRecordsStream() {
    if (_uid == null) return Stream.value([]);

    try {
      return _firestore
          .collection('users')
          .doc(_uid)
          .collection('tasting_records')
          .orderBy('tastingDate', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return TastingRecord.fromMap(data);
            }).toList();
          });
    } catch (e, st) {
      _logError('テイスティング記録ストリームエラー', e, st);
      return Stream.value([]);
    }
  }

  /// テイスティング記録を保存
  static Future<void> saveTastingRecord(TastingRecord record) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      developer.log('試飲記録保存開始: ${record.id}', name: _logName);

      final recordData = record.toMap();
      recordData['userId'] = _uid;
      recordData['updatedAt'] = DateTime.now().toIso8601String();

      developer.log(
        '試飲記録データ準備完了: ${recordData.keys.join(', ')}',
        name: _logName,
      );

      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('tasting_records')
          .doc(record.id)
          .set(recordData);

      developer.log('試飲記録保存完了: ${record.id}', name: _logName);

      // 自動同期を実行
      await AutoSyncService.triggerAutoSyncForDataType('tasting_records');
    } catch (e, st) {
      _logError('テイスティング記録保存エラー', e, st);
      developer.log('試飲記録保存エラー詳細: $e', name: _logName);
      rethrow;
    }
  }

  /// テイスティング記録を更新
  static Future<void> updateTastingRecord(TastingRecord record) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final recordData = record.toMap();
      recordData['updatedAt'] = DateTime.now().toIso8601String();

      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('tasting_records')
          .doc(record.id)
          .update(recordData);

      // 自動同期を実行
      await AutoSyncService.triggerAutoSyncForDataType('tasting_records');
    } catch (e, st) {
      _logError('テイスティング記録更新エラー', e, st);
      rethrow;
    }
  }

  /// テイスティング記録を削除
  static Future<void> deleteTastingRecord(String recordId) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('tasting_records')
          .doc(recordId)
          .delete();

      // 自動同期を実行
      await AutoSyncService.triggerAutoSyncForDataType('tasting_records');
    } catch (e, st) {
      _logError('テイスティング記録削除エラー', e, st);
      rethrow;
    }
  }

  /// グループのテイスティング記録を取得
  static Future<List<TastingRecord>> getGroupTastingRecords(
    String groupId,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final snapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('tasting_records')
          .orderBy('tastingDate', descending: true)
          .get();

      final records = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return TastingRecord.fromMap(data);
      }).toList();

      return records;
    } catch (e, st) {
      _logError('グループテイスティング記録取得エラー', e, st);
      return [];
    }
  }

  /// グループにテイスティング記録を保存
  static Future<void> saveGroupTastingRecord(
    String groupId,
    TastingRecord record,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      developer.log(
        'グループ試飲記録保存開始: ${record.id} (グループ: $groupId)',
        name: _logName,
      );

      final recordData = record.toMap();
      recordData['userId'] = _uid;
      recordData['updatedAt'] = DateTime.now().toIso8601String();

      developer.log(
        'グループ試飲記録データ準備完了: ${recordData.keys.join(', ')}',
        name: _logName,
      );

      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('tasting_records')
          .doc(record.id)
          .set(recordData);

      developer.log('グループ試飲記録保存完了: ${record.id}', name: _logName);
    } catch (e, st) {
      _logError('グループテイスティング記録保存エラー', e, st);
      developer.log('グループ試飲記録保存エラー詳細: $e', name: _logName);
      rethrow;
    }
  }

  /// グループのテイスティング記録を更新
  static Future<void> updateGroupTastingRecord(
    String groupId,
    TastingRecord record,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final recordData = record.toMap();
      recordData['updatedAt'] = DateTime.now().toIso8601String();

      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('tasting_records')
          .doc(record.id)
          .update(recordData);
    } catch (e, st) {
      _logError('グループテイスティング記録更新エラー', e, st);
      rethrow;
    }
  }

  /// グループのテイスティング記録を削除
  static Future<void> deleteGroupTastingRecord(
    String groupId,
    String recordId,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('tasting_records')
          .doc(recordId)
          .delete();
    } catch (e, st) {
      _logError('グループテイスティング記録削除エラー', e, st);
      rethrow;
    }
  }

  /// グループのテイスティング記録のストリームを取得
  static Stream<List<TastingRecord>> getGroupTastingRecordsStream(
    String groupId,
  ) {
    try {
      return _firestore
          .collection('groups')
          .doc(groupId)
          .collection('tasting_records')
          .orderBy('tastingDate', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return TastingRecord.fromMap(data);
            }).toList();
          });
    } catch (e, st) {
      _logError('グループテイスティング記録ストリームエラー', e, st);
      return Stream.value([]);
    }
  }

  /// 個人用テイスティング記録のドキュメント参照を取得
  static Future<DocumentSnapshot<Map<String, dynamic>>> getTastingRecordDoc(
    String id,
  ) async {
    if (_uid == null) throw Exception('未ログイン');
    return await _firestore
        .collection('users')
        .doc(_uid)
        .collection('tasting_records')
        .doc(id)
        .get();
  }

  /// グループ用テイスティング記録のドキュメント参照を取得
  static Future<DocumentSnapshot<Map<String, dynamic>>>
  getGroupTastingRecordDoc(String groupId, String id) async {
    return await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('tasting_records')
        .doc(id)
        .get();
  }

  // --- 追加: グループ協調API ---
  /// sessionId = normalize(beanName) + "__" + roastKey(roastLevel)
  static Future<TastingSession> createOrGetSession(
    String groupId,
    String beanName,
    String roastLevel,
  ) async {
    if (_uid == null) throw Exception('未ログイン');
    final sessionId = TastingSession.makeSessionId(beanName, roastLevel);
    final nowIso = DateTime.now().toIso8601String();
    final docRef = _sessionDoc(groupId, sessionId);
    final snap = await docRef.get();
    if (snap.exists) {
      final data = snap.data()!..['id'] = sessionId;
      return TastingSession.fromMap(data);
    }
    final session = TastingSession(
      id: sessionId,
      beanName: beanName,
      roastLevel: roastLevel,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: _uid!,
      entriesCount: 0,
      avgBitterness: 0,
      avgAcidity: 0,
      avgBody: 0,
      avgSweetness: 0,
      avgAroma: 0,
      avgOverall: 0,
    );
    await docRef.set({
      ...session.toMap(),
      'createdAt': nowIso,
      'updatedAt': nowIso,
    });
    return session;
  }

  static Stream<List<TastingSession>> getGroupTastingSessionsStream(
    String groupId,
  ) {
    try {
      return _groupSessionsCol(groupId)
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return TastingSession.fromMap(data);
            }).toList(),
          );
    } catch (e, st) {
      _logError('セッションストリームエラー', e, st);
      return Stream.value([]);
    }
  }

  static Stream<List<TastingEntry>> getSessionEntriesStream(
    String groupId,
    String sessionId,
  ) {
    try {
      return _entriesCol(groupId, sessionId)
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return TastingEntry.fromMap(data);
            }).toList(),
          );
    } catch (e, st) {
      _logError('エントリストリームエラー', e, st);
      return Stream.value([]);
    }
  }

  /// エントリをupsertし、トランザクションで平均と件数を更新
  static Future<void> upsertEntry(
    String groupId,
    String sessionId,
    TastingEntry entry,
  ) async {
    if (_uid == null) throw Exception('未ログイン');
    final uid = _uid!;
    final entriesRef = _entriesCol(groupId, sessionId);
    final sessionRef = _sessionDoc(groupId, sessionId);
    final nowIso = DateTime.now().toIso8601String();

    try {
      developer.log(
        '試飲エントリ保存開始: グループ=$groupId, セッション=$sessionId, ユーザー=$uid',
        name: _logName,
      );
      developer.log('エントリデータ: ${entry.toMap()}', name: _logName);

      await _firestore.runTransaction((txn) async {
        final entryRef = entriesRef.doc(uid);
        final entrySnap = await txn.get(entryRef);
        final sessionSnap = await txn.get(sessionRef);

        // 現在の合計と件数を取得（存在しない場合は0）
        int currentCount = (sessionSnap.data()?['entriesCount'] ?? 0);
        double sumBit = ((sessionSnap.data()?['sumBitterness'] ?? 0) as num)
            .toDouble();
        double sumAci = ((sessionSnap.data()?['sumAcidity'] ?? 0) as num)
            .toDouble();
        double sumBody = ((sessionSnap.data()?['sumBody'] ?? 0) as num)
            .toDouble();
        double sumSw = ((sessionSnap.data()?['sumSweetness'] ?? 0) as num)
            .toDouble();
        double sumAroma = ((sessionSnap.data()?['sumAroma'] ?? 0) as num)
            .toDouble();
        double sumOv = ((sessionSnap.data()?['sumOverall'] ?? 0) as num)
            .toDouble();

        // 既存エントリとの差分
        double oldBit = 0,
            oldAci = 0,
            oldBody = 0,
            oldSw = 0,
            oldAroma = 0,
            oldOv = 0;
        bool existed = entrySnap.exists;
        if (existed) {
          final m = entrySnap.data()!;
          double d(dynamic v) =>
              v is int ? v.toDouble() : (v as num).toDouble();
          oldBit = _clamp(d(m['bitterness'] ?? 3));
          oldAci = _clamp(d(m['acidity'] ?? 3));
          oldBody = _clamp(d(m['body'] ?? 3));
          oldSw = _clamp(d(m['sweetness'] ?? 3));
          oldAroma = _clamp(d(m['aroma'] ?? 3));
          oldOv = _clamp(d(m['overall'] ?? m['overallRating'] ?? 3));
        }

        final newBit = _clamp(entry.bitterness);
        final newAci = _clamp(entry.acidity);
        final newBody = _clamp(entry.body);
        final newSw = _clamp(entry.sweetness);
        final newAroma = _clamp(entry.aroma);
        final newOv = _clamp(entry.overall);

        // 件数更新
        final nextCount = existed ? currentCount : currentCount + 1;

        // 合計更新
        sumBit = sumBit - oldBit + newBit;
        sumAci = sumAci - oldAci + newAci;
        sumBody = sumBody - oldBody + newBody;
        sumSw = sumSw - oldSw + newSw;
        sumAroma = sumAroma - oldAroma + newAroma;
        sumOv = sumOv - oldOv + newOv;

        // エントリ保存
        final toSave = {
          ...entry.copyWith(id: uid, userId: uid).toMap(),
          'updatedAt': nowIso,
          if (!existed) 'createdAt': nowIso,
        };
        txn.set(entryRef, toSave);

        double avg(double s) => nextCount == 0
            ? 0
            : double.parse((s / nextCount).toStringAsFixed(2));
        txn.set(sessionRef, {
          'entriesCount': nextCount,
          'sumBitterness': double.parse(sumBit.toStringAsFixed(2)),
          'sumAcidity': double.parse(sumAci.toStringAsFixed(2)),
          'sumBody': double.parse(sumBody.toStringAsFixed(2)),
          'sumSweetness': double.parse(sumSw.toStringAsFixed(2)),
          'sumAroma': double.parse(sumAroma.toStringAsFixed(2)),
          'sumOverall': double.parse(sumOv.toStringAsFixed(2)),
          'avgBitterness': avg(sumBit),
          'avgAcidity': avg(sumAci),
          'avgBody': avg(sumBody),
          'avgSweetness': avg(sumSw),
          'avgAroma': avg(sumAroma),
          'avgOverall': avg(sumOv),
          'updatedAt': nowIso,
        }, SetOptions(merge: true));
      });

      developer.log(
        '試飲エントリ保存完了: グループ=$groupId, セッション=$sessionId',
        name: _logName,
      );
      await AutoSyncService.triggerAutoSyncForDataType('tasting_sessions');
    } catch (e, st) {
      _logError('試飲エントリ保存エラー', e, st);
      developer.log('試飲エントリ保存エラー詳細: $e', name: _logName);
      rethrow;
    }
  }

  static Future<void> deleteEntry(
    String groupId,
    String sessionId,
    String userId,
  ) async {
    final entriesRef = _entriesCol(groupId, sessionId);
    final sessionRef = _sessionDoc(groupId, sessionId);
    final nowIso = DateTime.now().toIso8601String();
    await _firestore.runTransaction((txn) async {
      final entryRef = entriesRef.doc(userId);
      final entrySnap = await txn.get(entryRef);
      if (!entrySnap.exists) {
        // 何もしない
        return;
      }
      final sessionSnap = await txn.get(sessionRef);
      int currentCount = (sessionSnap.data()?['entriesCount'] ?? 0);
      double sumBit = ((sessionSnap.data()?['sumBitterness'] ?? 0) as num)
          .toDouble();
      double sumAci = ((sessionSnap.data()?['sumAcidity'] ?? 0) as num)
          .toDouble();
      double sumBody = ((sessionSnap.data()?['sumBody'] ?? 0) as num)
          .toDouble();
      double sumSw = ((sessionSnap.data()?['sumSweetness'] ?? 0) as num)
          .toDouble();
      double sumAroma = ((sessionSnap.data()?['sumAroma'] ?? 0) as num)
          .toDouble();
      double sumOv = ((sessionSnap.data()?['sumOverall'] ?? 0) as num)
          .toDouble();

      final m = entrySnap.data()!;
      double d(dynamic v) => v is int ? v.toDouble() : (v as num).toDouble();
      final oldBit = _clamp(d(m['bitterness'] ?? 3));
      final oldAci = _clamp(d(m['acidity'] ?? 3));
      final oldBody = _clamp(d(m['body'] ?? 3));
      final oldSw = _clamp(d(m['sweetness'] ?? 3));
      final oldAroma = _clamp(d(m['aroma'] ?? 3));
      final oldOv = _clamp(d(m['overall'] ?? m['overallRating'] ?? 3));

      final nextCount = (currentCount > 0) ? currentCount - 1 : 0;
      sumBit -= oldBit;
      sumAci -= oldAci;
      sumBody -= oldBody;
      sumSw -= oldSw;
      sumAroma -= oldAroma;
      sumOv -= oldOv;

      txn.delete(entryRef);

      double avg(double s) =>
          nextCount == 0 ? 0 : double.parse((s / nextCount).toStringAsFixed(2));
      txn.set(sessionRef, {
        'entriesCount': nextCount,
        'sumBitterness': double.parse(sumBit.toStringAsFixed(2)),
        'sumAcidity': double.parse(sumAci.toStringAsFixed(2)),
        'sumBody': double.parse(sumBody.toStringAsFixed(2)),
        'sumSweetness': double.parse(sumSw.toStringAsFixed(2)),
        'sumAroma': double.parse(sumAroma.toStringAsFixed(2)),
        'sumOverall': double.parse(sumOv.toStringAsFixed(2)),
        'avgBitterness': avg(sumBit),
        'avgAcidity': avg(sumAci),
        'avgBody': avg(sumBody),
        'avgSweetness': avg(sumSw),
        'avgAroma': avg(sumAroma),
        'avgOverall': avg(sumOv),
        'updatedAt': nowIso,
      }, SetOptions(merge: true));
    });
  }

  /// セッション全体を削除（エントリも含む）
  static Future<void> deleteSession(String groupId, String sessionId) async {
    try {
      developer.log(
        'セッション削除開始: グループ=$groupId, セッション=$sessionId',
        name: _logName,
      );

      // セッションとそのエントリを削除
      await _firestore.runTransaction((txn) async {
        final sessionRef = _sessionDoc(groupId, sessionId);
        final entriesRef = _entriesCol(groupId, sessionId);

        // セッションの存在確認
        final sessionSnap = await txn.get(sessionRef);
        if (!sessionSnap.exists) {
          throw Exception('セッションが見つかりません');
        }

        // エントリをすべて削除
        final entriesSnap = await entriesRef.get();
        for (final doc in entriesSnap.docs) {
          txn.delete(doc.reference);
        }

        // セッションを削除
        txn.delete(sessionRef);
      });

      developer.log(
        'セッション削除完了: グループ=$groupId, セッション=$sessionId',
        name: _logName,
      );
      await AutoSyncService.triggerAutoSyncForDataType('tasting_sessions');
    } catch (e, st) {
      _logError('セッション削除エラー', e, st);
      developer.log('セッション削除エラー詳細: $e', name: _logName);
      rethrow;
    }
  }
}
