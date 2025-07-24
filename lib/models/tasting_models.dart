import 'package:flutter/foundation.dart';
import '../services/tasting_firestore_service.dart';
import '../services/user_settings_firestore_service.dart';
import 'dart:async';

class TastingRecord {
  final String id;
  final String beanName;
  final DateTime tastingDate;
  final String roastLevel; // 浅煎り、中煎り、深煎りなど（焙煎度合い）
  final double acidity; // 酸味 (1-5)
  final double bitterness; // 苦味 (1-5)
  final double aroma; // 香り (1-5)
  final double overallRating; // おいしさ (1-5)
  final String overallImpression; // 全体的な印象
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userId;
  final String? groupId; // 追加: グループID（個人用はnull）

  TastingRecord({
    required this.id,
    required this.beanName,
    required this.tastingDate,
    required this.roastLevel,
    required this.acidity,
    required this.bitterness,
    required this.aroma,
    required this.overallRating,
    required this.overallImpression,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
    this.groupId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'beanName': beanName,
      'tastingDate': tastingDate.toIso8601String(),
      'roastLevel': roastLevel,
      'acidity': acidity,
      'bitterness': bitterness,
      'aroma': aroma,
      'overallRating': overallRating,
      'overallImpression': overallImpression,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'userId': userId,
      'groupId': groupId,
    };
  }

  factory TastingRecord.fromMap(Map<String, dynamic> map) {
    double clamp(double v) => v < 1.0 ? 1.0 : (v > 5.0 ? 5.0 : v);
    return TastingRecord(
      id: map['id'] ?? '',
      beanName: map['beanName'] ?? '',
      tastingDate: DateTime.parse(map['tastingDate']),
      roastLevel: map['roastLevel'] ?? '',
      acidity: clamp((map['acidity'] ?? 3.0).toDouble()),
      bitterness: clamp((map['bitterness'] ?? 3.0).toDouble()),
      aroma: clamp((map['aroma'] ?? 3.0).toDouble()),
      overallRating: clamp((map['overallRating'] ?? 3.0).toDouble()),
      overallImpression: map['overallImpression'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      userId: map['userId'] ?? '',
      groupId: map['groupId'],
    );
  }

  TastingRecord copyWith({
    String? id,
    String? beanName,
    DateTime? tastingDate,
    String? roastLevel,
    double? acidity,
    double? bitterness,
    double? aroma,
    double? overallRating,
    String? overallImpression,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    String? groupId,
  }) {
    return TastingRecord(
      id: id ?? this.id,
      beanName: beanName ?? this.beanName,
      tastingDate: tastingDate ?? this.tastingDate,
      roastLevel: roastLevel ?? this.roastLevel,
      acidity: acidity ?? this.acidity,
      bitterness: bitterness ?? this.bitterness,
      aroma: aroma ?? this.aroma,
      overallRating: overallRating ?? this.overallRating,
      overallImpression: overallImpression ?? this.overallImpression,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      groupId: groupId ?? this.groupId,
    );
  }
}

/// 同じ豆の評価をグループ化したクラス
class TastingGroup {
  final String beanName;
  final List<TastingRecord> records;
  final double averageRating;
  final int totalRecords;

  TastingGroup({
    required this.beanName,
    required this.records,
    required this.averageRating,
    required this.totalRecords,
  });

  /// 各評価項目の平均値を計算
  double get averageAcidity {
    if (records.isEmpty) return 0.0;
    return records.map((r) => r.acidity).reduce((a, b) => a + b) /
        records.length;
  }

  double get averageBitterness {
    if (records.isEmpty) return 0.0;
    return records.map((r) => r.bitterness).reduce((a, b) => a + b) /
        records.length;
  }

  double get averageAroma {
    if (records.isEmpty) return 0.0;
    return records.map((r) => r.aroma).reduce((a, b) => a + b) / records.length;
  }

  double get averageOverallRating {
    if (records.isEmpty) return 0.0;
    return records.map((r) => r.overallRating).reduce((a, b) => a + b) /
        records.length;
  }

  /// 最新の記録を取得
  TastingRecord get latestRecord => records.first;

  /// 焙煎度合いの一覧を取得（重複を除く）
  List<String> get roastLevels {
    final levels = records.map((r) => r.roastLevel).toSet().toList();
    levels.sort();
    return levels;
  }

  /// 全体的な印象をまとめて取得
  List<String> get allOverallImpressions {
    return records
        .where((r) => r.overallImpression.isNotEmpty)
        .map((r) => r.overallImpression)
        .toList();
  }
}

class TastingProvider extends ChangeNotifier {
  List<TastingRecord> _tastingRecords = [];
  bool _isLoading = false;
  static const String _storageKey = 'tasting_records';

  StreamSubscription<List<TastingRecord>>? _tastingStreamSub;

  List<TastingRecord> get tastingRecords => _tastingRecords;
  bool get isLoading => _isLoading;

  // --- 追加: Firestore同期用の一括セットメソッド ---
  void replaceAll(List<TastingRecord> records) {
    _tastingRecords = records;
    notifyListeners();
  }
  // --- ここまで追加 ---

  /// ストリーム購読を開始（グループID指定でグループ用、未指定で個人用）
  void subscribeTastingRecords({String? groupId}) {
    _tastingStreamSub?.cancel();
    _isLoading = true;
    notifyListeners();
    Stream<List<TastingRecord>> stream;
    if (groupId != null && groupId.isNotEmpty) {
      stream = TastingFirestoreService.getGroupTastingRecordsStream(groupId);
    } else {
      stream = TastingFirestoreService.getTastingRecordsStream();
    }
    _tastingStreamSub = stream.listen(
      (records) {
        _tastingRecords = List.from(records);
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        print('テイスティング記録ストリーム購読エラー: $e');
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _tastingStreamSub?.cancel();
    super.dispose();
  }

  /// 同じ豆の評価をグループ化して返す
  List<TastingGroup> getTastingGroups() {
    final Map<String, List<TastingRecord>> groupedRecords = {};

    for (final record in _tastingRecords) {
      final key = record.beanName.toLowerCase().trim();
      if (!groupedRecords.containsKey(key)) {
        groupedRecords[key] = [];
      }
      groupedRecords[key]!.add(record);
    }

    return groupedRecords.entries.map((entry) {
      final records = entry.value;
      records.sort((a, b) => b.tastingDate.compareTo(a.tastingDate));

      return TastingGroup(
        beanName: records.first.beanName,
        records: records,
        averageRating: _calculateAverageRating(records),
        totalRecords: records.length,
      );
    }).toList()..sort(
      (a, b) =>
          b.records.first.tastingDate.compareTo(a.records.first.tastingDate),
    );
  }

  /// 平均評価を計算
  double _calculateAverageRating(List<TastingRecord> records) {
    if (records.isEmpty) return 0.0;
    double total = 0.0;
    for (final record in records) {
      total += record.overallRating;
    }
    return total / records.length;
  }

  Future<void> loadTastingRecords({String? groupId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      List<TastingRecord> firestoreRecords = [];
      if (groupId != null && groupId.isNotEmpty) {
        // グループ用API
        firestoreRecords = await TastingFirestoreService.getGroupTastingRecords(
          groupId,
        );
      } else {
        // 個人用API
        firestoreRecords = await TastingFirestoreService.getTastingRecords();
      }

      if (firestoreRecords.isNotEmpty) {
        _tastingRecords = firestoreRecords;
        // 試飲日順にソート（新しい順）
        _tastingRecords.sort((a, b) => b.tastingDate.compareTo(a.tastingDate));
      } else {
        // Firestoreにデータがない場合はFirebaseから読み込み
        try {
          final jsonString = await UserSettingsFirestoreService.getSetting(
            _storageKey,
          );

          if (jsonString != null) {
            final List<dynamic> jsonList = jsonString;
            _tastingRecords = jsonList
                .map((json) => TastingRecord.fromMap(json))
                .toList();

            // 試飲日順にソート（新しい順）
            _tastingRecords.sort(
              (a, b) => b.tastingDate.compareTo(a.tastingDate),
            );
          } else {
            _tastingRecords = [];
          }
        } catch (e) {
          print('Firebaseからのテイスティング記録読み込みエラー: $e');
          _tastingRecords = [];
        }
      }
    } catch (e) {
      print('Error loading tasting records: $e');
      _tastingRecords = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final jsonString = _tastingRecords.map((tr) => tr.toMap()).toList();
      await UserSettingsFirestoreService.saveSetting(_storageKey, jsonString);
    } catch (e) {
      print('Error saving tasting records: $e');
      rethrow;
    }
  }

  Future<bool> _existsTastingRecordOnFirestore(
    String id, {
    String? groupId,
  }) async {
    try {
      if (groupId != null && groupId.isNotEmpty) {
        // グループ用
        final doc = await TastingFirestoreService.getGroupTastingRecordDoc(
          groupId,
          id,
        );
        return doc.exists;
      } else {
        // 個人用
        final doc = await TastingFirestoreService.getTastingRecordDoc(id);
        return doc.exists;
      }
    } catch (e) {
      print('Firestore存在確認エラー: $e');
      return false;
    }
  }

  Future<void> addTastingRecord(
    TastingRecord tastingRecord, {
    String? groupId,
  }) async {
    try {
      final newTastingRecord = tastingRecord.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: 'local_user', // ローカル保存なので固定ID
        groupId: groupId,
      );

      // Firestore上に同じIDが存在する場合は保存しない
      final exists = await _existsTastingRecordOnFirestore(
        newTastingRecord.id,
        groupId: groupId,
      );
      if (exists) {
        print('同じIDのレコードがFirestoreに存在するため、保存をスキップします');
        return;
      }

      _tastingRecords.insert(0, newTastingRecord);

      // Firestoreに保存
      try {
        if (groupId != null && groupId.isNotEmpty) {
          await TastingFirestoreService.saveGroupTastingRecord(
            groupId,
            newTastingRecord,
          );
        } else {
          await TastingFirestoreService.saveTastingRecord(newTastingRecord);
        }
      } catch (e) {
        print('Firestore保存エラー: $e');
        // Firestore保存に失敗してもローカル保存は続行
      }

      await _saveToStorage();
      notifyListeners();
    } catch (e) {
      print('Error adding tasting record: $e');
      rethrow;
    }
  }

  Future<void> updateTastingRecord(
    TastingRecord tastingRecord, {
    String? groupId,
  }) async {
    try {
      final index = _tastingRecords.indexWhere(
        (tr) => tr.id == tastingRecord.id,
      );
      if (index != -1) {
        final updatedRecord = tastingRecord.copyWith(groupId: groupId);
        _tastingRecords[index] = updatedRecord;

        // Firestoreに更新
        try {
          if (groupId != null && groupId.isNotEmpty) {
            await TastingFirestoreService.updateGroupTastingRecord(
              groupId,
              updatedRecord,
            );
          } else {
            await TastingFirestoreService.updateTastingRecord(updatedRecord);
          }
        } catch (e) {
          print('Firestore更新エラー: $e');
          // Firestore更新に失敗してもローカル保存は続行
        }

        await _saveToStorage();
        notifyListeners();
      }
    } catch (e) {
      print('Error updating tasting record: $e');
      rethrow;
    }
  }

  Future<void> deleteTastingRecord(String id, {String? groupId}) async {
    try {
      _tastingRecords.removeWhere((tr) => tr.id == id);

      // Firestoreから削除
      try {
        if (groupId != null && groupId.isNotEmpty) {
          await TastingFirestoreService.deleteGroupTastingRecord(groupId, id);
        } else {
          await TastingFirestoreService.deleteTastingRecord(id);
        }
      } catch (e) {
        print('Firestore削除エラー: $e');
        // Firestore削除に失敗してもローカル保存は続行
      }

      await _saveToStorage();
      notifyListeners();
    } catch (e) {
      print('Error deleting tasting record: $e');
      rethrow;
    }
  }

  /// 同じ豆の種類と焙煎度合いの組み合わせが既に存在するかチェック
  bool isDuplicateTasting(String beanName, String roastLevel) {
    final normalizedBeanName = beanName.toLowerCase().trim();
    final normalizedRoastLevel = roastLevel.toLowerCase().trim();

    return _tastingRecords.any(
      (record) =>
          record.beanName.toLowerCase().trim() == normalizedBeanName &&
          record.roastLevel.toLowerCase().trim() == normalizedRoastLevel,
    );
  }

  /// 同じ豆の種類と焙煎度合いの組み合わせの既存記録を取得
  List<TastingRecord> getExistingTastings(String beanName, String roastLevel) {
    final normalizedBeanName = beanName.toLowerCase().trim();
    final normalizedRoastLevel = roastLevel.toLowerCase().trim();

    return _tastingRecords
        .where(
          (record) =>
              record.beanName.toLowerCase().trim() == normalizedBeanName &&
              record.roastLevel.toLowerCase().trim() == normalizedRoastLevel,
        )
        .toList();
  }
}
