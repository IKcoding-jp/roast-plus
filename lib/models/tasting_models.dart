import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import '../services/tasting_firestore_service.dart';
import '../services/user_settings_firestore_service.dart';
import 'dart:async';

/// --- 新モデル: グループ協調用セッション/エントリ ---
class TastingSession {
  final String
  id; // sessionId = normalize(beanName) + "__" + roastKey(roastLevel)
  final String beanName;
  final String roastLevel; // 表示用（例: 浅煎り/中煎り/中深煎り/深煎り）
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final int entriesCount;
  final double avgBitterness;
  final double avgAcidity;
  final double avgBody;
  final double avgSweetness;
  final double avgAroma;
  final double avgOverall;

  const TastingSession({
    required this.id,
    required this.beanName,
    required this.roastLevel,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.entriesCount,
    required this.avgBitterness,
    required this.avgAcidity,
    required this.avgBody,
    required this.avgSweetness,
    required this.avgAroma,
    required this.avgOverall,
  });

  TastingSession copyWith({
    String? id,
    String? beanName,
    String? roastLevel,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    int? entriesCount,
    double? avgBitterness,
    double? avgAcidity,
    double? avgBody,
    double? avgSweetness,
    double? avgAroma,
    double? avgOverall,
  }) {
    return TastingSession(
      id: id ?? this.id,
      beanName: beanName ?? this.beanName,
      roastLevel: roastLevel ?? this.roastLevel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      entriesCount: entriesCount ?? this.entriesCount,
      avgBitterness: avgBitterness ?? this.avgBitterness,
      avgAcidity: avgAcidity ?? this.avgAcidity,
      avgBody: avgBody ?? this.avgBody,
      avgSweetness: avgSweetness ?? this.avgSweetness,
      avgAroma: avgAroma ?? this.avgAroma,
      avgOverall: avgOverall ?? this.avgOverall,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'beanName': beanName,
      'roastLevel': roastLevel,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'entriesCount': entriesCount,
      'avgBitterness': avgBitterness,
      'avgAcidity': avgAcidity,
      'avgBody': avgBody,
      'avgSweetness': avgSweetness,
      'avgAroma': avgAroma,
      'avgOverall': avgOverall,
    };
  }

  factory TastingSession.fromMap(Map<String, dynamic> map) {
    double d(dynamic v, [double fallback = 0.0]) {
      if (v == null) return fallback;
      if (v is int) return v.toDouble();
      if (v is double) return v;
      return double.tryParse(v.toString()) ?? fallback;
    }

    return TastingSession(
      id: map['id'] ?? '',
      beanName: map['beanName'] ?? '',
      roastLevel: map['roastLevel'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
      entriesCount: (map['entriesCount'] ?? 0) as int,
      avgBitterness: d(map['avgBitterness']),
      avgAcidity: d(map['avgAcidity']),
      avgBody: d(map['avgBody']),
      avgSweetness: d(map['avgSweetness']),
      avgAroma: d(map['avgAroma']),
      avgOverall: d(map['avgOverall']),
    );
  }

  // 補助: セッションID生成
  static String makeSessionId(String beanName, String roastLevel) {
    return '${_normalize(beanName)}__${_roastKey(roastLevel)}';
  }

  // roastKey: 浅=light, 中=medium, 中深=med_dark, 深=dark
  static String _roastKey(String roastLevel) {
    final s = roastLevel.trim();
    if (s.contains('浅')) return 'light';
    if (s.contains('中深')) return 'med_dark';
    if (s.contains('中')) return 'medium';
    if (s.contains('深')) return 'dark';
    switch (s.toLowerCase()) {
      case 'light':
        return 'light';
      case 'medium':
        return 'medium';
      case 'med_dark':
      case 'medium_dark':
      case 'med-dark':
        return 'med_dark';
      case 'dark':
        return 'dark';
      default:
        return 'medium';
    }
  }

  // 正規化: toLowerCase + NFKC相当の簡易処理 + 空白/記号除去
  static String _normalize(String input) {
    // 簡易: 全角空白→半角、全空白削除、英数小文字化、記号削除（和文は保持）
    final lower = input.toLowerCase();
    final replacedSpace = lower.replaceAll('\u3000', ' ');
    final noSpaces = replacedSpace.replaceAll(RegExp(r'\s+'), '');
    // 許容: ASCII英数/かな/カナ/CJK/全角英数カナ
    final buffer = StringBuffer();
    final pattern = RegExp(
      r'[a-z0-9\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF\uFF10-\uFF19\uFF21-\uFF3A\uFF41-\uFF5A\uFF66-\uFF9F]',
    );
    for (final ch in noSpaces.split('')) {
      if (pattern.hasMatch(ch)) buffer.write(ch);
    }
    return buffer.toString();
  }
}

class TastingEntry {
  final String id; // = userId と同一
  final String userId;
  final double bitterness;
  final double acidity;
  final double body;
  final double sweetness;
  final double aroma;
  final double overall;
  final String comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TastingEntry({
    required this.id,
    required this.userId,
    required this.bitterness,
    required this.acidity,
    required this.body,
    required this.sweetness,
    required this.aroma,
    required this.overall,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  TastingEntry copyWith({
    String? id,
    String? userId,
    double? bitterness,
    double? acidity,
    double? body,
    double? sweetness,
    double? aroma,
    double? overall,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TastingEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bitterness: bitterness ?? this.bitterness,
      acidity: acidity ?? this.acidity,
      body: body ?? this.body,
      sweetness: sweetness ?? this.sweetness,
      aroma: aroma ?? this.aroma,
      overall: overall ?? this.overall,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'bitterness': bitterness,
      'acidity': acidity,
      'body': body,
      'sweetness': sweetness,
      'aroma': aroma,
      'overall': overall,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TastingEntry.fromMap(Map<String, dynamic> map) {
    double d(dynamic v, [double fallback = 3.0]) {
      if (v == null) return fallback;
      if (v is int) return v.toDouble();
      if (v is double) return v;
      return double.tryParse(v.toString()) ?? fallback;
    }

    double clamp(double v) => v < 1.0 ? 1.0 : (v > 5.0 ? 5.0 : v);

    return TastingEntry(
      id: map['id'] ?? map['userId'] ?? '',
      userId: map['userId'] ?? '',
      bitterness: clamp(d(map['bitterness'])),
      acidity: clamp(d(map['acidity'])),
      body: clamp(d(map['body'])),
      sweetness: clamp(d(map['sweetness'])),
      aroma: clamp(d(map['aroma'])),
      overall: clamp(d(map['overall'] ?? map['overallRating'])),
      comment: (map['comment'] ?? map['overallImpression'] ?? '').toString(),
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

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
  // --- 新: セッション主導 ---
  List<TastingSession> _sessions = [];
  final Map<String, List<TastingEntry>> _entriesBySession = {};
  StreamSubscription<List<TastingSession>>? _sessionsSub;
  final Map<String, StreamSubscription<List<TastingEntry>>> _entriesSubs = {};
  static const String _storageKey = 'tasting_records';

  StreamSubscription<List<TastingRecord>>? _tastingStreamSub;

  List<TastingRecord> get tastingRecords => _tastingRecords;
  bool get isLoading => _isLoading;
  List<TastingSession> get sessions => _sessions;

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

    int retryCount = 0;
    const maxRetries = 3;

    void subscribe() {
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
          // 成功したらリトライカウントをリセット
          retryCount = 0;
        },
        onError: (e, st) {
          developer.log(
            'テイスティング記録ストリーム購読エラー',
            name: 'TastingProvider',
            error: e,
            stackTrace: st,
          );

          // INTERNAL ASSERTION FAILEDエラーの場合、再接続を試みる
          if (e.toString().contains('INTERNAL ASSERTION FAILED') &&
              retryCount < maxRetries) {
            retryCount++;
            developer.log(
              'INTERNAL ASSERTION FAILED検出、ストリーム再購読を試行します ($retryCount/$maxRetries)',
              name: 'TastingProvider',
            );

            _isLoading = true;
            notifyListeners();

            // 少し待機してから再購読
            Future.delayed(Duration(seconds: retryCount), () {
              subscribe();
            });
          } else {
            _isLoading = false;
            notifyListeners();
          }
        },
      );
    }

    subscribe();
  }

  /// グループのテイスティングセッションを購読
  void subscribeGroupTastingSessions(String groupId) {
    _sessionsSub?.cancel();
    _isLoading = true;
    notifyListeners();

    int retryCount = 0;
    const maxRetries = 3;

    void subscribe() {
      _sessionsSub =
          TastingFirestoreService.getGroupTastingSessionsStream(groupId).listen(
            (list) {
              _sessions = List.from(list);
              _isLoading = false;
              notifyListeners();
              // 成功したらリトライカウントをリセット
              retryCount = 0;
            },
            onError: (e, st) {
              developer.log(
                'セッション購読エラー',
                name: 'TastingProvider',
                error: e,
                stackTrace: st,
              );

              // INTERNAL ASSERTION FAILEDエラーの場合、再接続を試みる
              if (e.toString().contains('INTERNAL ASSERTION FAILED') &&
                  retryCount < maxRetries) {
                retryCount++;
                developer.log(
                  'INTERNAL ASSERTION FAILED検出、セッションストリーム再購読を試行します ($retryCount/$maxRetries)',
                  name: 'TastingProvider',
                );

                _isLoading = true;
                notifyListeners();

                // 少し待機してから再購読
                Future.delayed(Duration(seconds: retryCount), () {
                  subscribe();
                });
              } else {
                _isLoading = false;
                notifyListeners();
              }
            },
          );
    }

    subscribe();
  }

  /// セッションのエントリ一覧を購読（詳細画面入場時）
  void loadEntries(String groupId, String sessionId) {
    // 既存購読をクリア
    _entriesSubs[sessionId]?.cancel();

    int retryCount = 0;
    const maxRetries = 3;

    void subscribe() {
      _entriesSubs[sessionId] =
          TastingFirestoreService.getSessionEntriesStream(
            groupId,
            sessionId,
          ).listen(
            (entries) {
              _entriesBySession[sessionId] = entries;
              notifyListeners();
              // 成功したらリトライカウントをリセット
              retryCount = 0;
            },
            onError: (e, st) {
              developer.log(
                'エントリ購読エラー',
                name: 'TastingProvider',
                error: e,
                stackTrace: st,
              );

              // INTERNAL ASSERTION FAILEDエラーの場合、再接続を試みる
              if (e.toString().contains('INTERNAL ASSERTION FAILED') &&
                  retryCount < maxRetries) {
                retryCount++;
                developer.log(
                  'INTERNAL ASSERTION FAILED検出、再接続を試行します ($retryCount/$maxRetries)',
                  name: 'TastingProvider',
                );

                // 少し待機してから再接続
                Future.delayed(Duration(seconds: retryCount), () {
                  if (_entriesSubs.containsKey(sessionId)) {
                    subscribe();
                  }
                });
              }
            },
          );
    }

    subscribe();
  }

  List<TastingEntry> getEntriesOf(String sessionId) {
    return _entriesBySession[sessionId] ?? const [];
  }

  bool hasMyEntry(String sessionId, String uid) {
    return getEntriesOf(sessionId).any((e) => e.userId == uid);
  }

  /// セッションを削除
  Future<void> deleteSession(String groupId, String sessionId) async {
    try {
      debugPrint(
        'TastingProvider: セッション削除開始 - groupId: $groupId, sessionId: $sessionId',
      );
      await TastingFirestoreService.deleteSession(groupId, sessionId);

      // ローカルのセッションリストからも削除
      _sessions.removeWhere((s) => s.id == sessionId);

      // エントリの購読も停止
      _entriesSubs[sessionId]?.cancel();
      _entriesSubs.remove(sessionId);
      _entriesBySession.remove(sessionId);

      notifyListeners();
      debugPrint('TastingProvider: セッション削除完了');
    } catch (e) {
      debugPrint('TastingProvider: セッション削除エラー: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _sessionsSub?.cancel();
    for (final sub in _entriesSubs.values) {
      sub.cancel();
    }
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
        } catch (e, st) {
          developer.log(
            'Firebaseからのテイスティング記録読み込みエラー',
            name: 'TastingProvider',
            error: e,
            stackTrace: st,
          );
          _tastingRecords = [];
        }
      }
    } catch (e, st) {
      developer.log(
        'Error loading tasting records',
        name: 'TastingProvider',
        error: e,
        stackTrace: st,
      );
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
    } catch (e, st) {
      developer.log(
        'Error saving tasting records',
        name: 'TastingProvider',
        error: e,
        stackTrace: st,
      );
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
    } catch (e, st) {
      developer.log(
        'Firestore存在確認エラー',
        name: 'TastingProvider',
        error: e,
        stackTrace: st,
      );
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
        developer.log(
          '同じIDのレコードがFirestoreに存在するため、保存をスキップします',
          name: 'TastingProvider',
        );
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
      } catch (e, st) {
        developer.log(
          'Firestore保存エラー',
          name: 'TastingProvider',
          error: e,
          stackTrace: st,
        );
        // Firestore保存に失敗してもローカル保存は続行
      }

      await _saveToStorage();
      notifyListeners();
    } catch (e, st) {
      developer.log(
        'Error adding tasting record',
        name: 'TastingProvider',
        error: e,
        stackTrace: st,
      );
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
        } catch (e, st) {
          developer.log(
            'Firestore更新エラー',
            name: 'TastingProvider',
            error: e,
            stackTrace: st,
          );
          // Firestore更新に失敗してもローカル保存は続行
        }

        await _saveToStorage();
        notifyListeners();
      }
    } catch (e, st) {
      developer.log(
        'Error updating tasting record',
        name: 'TastingProvider',
        error: e,
        stackTrace: st,
      );
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
      } catch (e, st) {
        developer.log(
          'Firestore削除エラー',
          name: 'TastingProvider',
          error: e,
          stackTrace: st,
        );
        // Firestore削除に失敗してもローカル保存は続行
      }

      await _saveToStorage();
      notifyListeners();
    } catch (e, st) {
      developer.log(
        'Error deleting tasting record',
        name: 'TastingProvider',
        error: e,
        stackTrace: st,
      );
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
