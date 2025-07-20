import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/work_progress_firestore_service.dart';
import '../services/user_settings_firestore_service.dart';

enum WorkStage {
  handpick, // ハンドピック
  roast, // ロースト
  afterPick, // アフターピック
  mill, // ミル
  dripPack, // ドリップパック
  threeWayBag, // 三方袋
  packaging, // 梱包
  shipping, // 発送
}

enum WorkStatus {
  before, // 前
  after, // 済
}

class WorkProgress {
  final String id;
  final String beanName;
  final String beanId;
  final Map<WorkStage, WorkStatus> stageStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? notes;
  final String userId;

  WorkProgress({
    required this.id,
    required this.beanName,
    required this.beanId,
    required this.stageStatus,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'beanName': beanName,
      'beanId': beanId,
      'stageStatus': stageStatus.map(
        (key, value) => MapEntry(key.name, value.name),
      ),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'notes': notes,
      'userId': userId,
    };
  }

  factory WorkProgress.fromMap(Map<String, dynamic> map) {
    return WorkProgress(
      id: map['id'] ?? '',
      beanName: map['beanName'] ?? '',
      beanId: map['beanId'] ?? '',
      stageStatus:
          (map['stageStatus'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              WorkStage.values.firstWhere((e) => e.name == key),
              WorkStatus.values.firstWhere((e) => e.name == value),
            ),
          ) ??
          {},
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      notes: map['notes'],
      userId: map['userId'] ?? '',
    );
  }

  WorkProgress copyWith({
    String? id,
    String? beanName,
    String? beanId,
    Map<WorkStage, WorkStatus>? stageStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
    String? userId,
  }) {
    return WorkProgress(
      id: id ?? this.id,
      beanName: beanName ?? this.beanName,
      beanId: beanId ?? this.beanId,
      stageStatus: stageStatus ?? this.stageStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      userId: userId ?? this.userId,
    );
  }
}

class WorkProgressProvider extends ChangeNotifier {
  List<WorkProgress> _workProgressList = [];
  bool _isLoading = false;
  static const String _storageKey = 'work_progress_list';

  List<WorkProgress> get workProgressList => _workProgressList;
  bool get isLoading => _isLoading;

  // --- 追加: Firestore同期用の一括セットメソッド ---
  void replaceAll(List<WorkProgress> records) {
    _workProgressList = records;
    notifyListeners();
  }
  // --- ここまで追加 ---

  Future<void> loadWorkProgress({String? groupId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      List<WorkProgress> firestoreRecords = [];
      if (groupId != null && groupId.isNotEmpty) {
        // グループ用API
        firestoreRecords =
            await WorkProgressFirestoreService.getGroupWorkProgressRecords(
              groupId,
            );
      } else {
        // 個人用API
        firestoreRecords =
            await WorkProgressFirestoreService.getWorkProgressRecords();
      }

      if (firestoreRecords.isNotEmpty) {
        _workProgressList = firestoreRecords;
        // 作成日順にソート（新しい順）
        _workProgressList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        // Firestoreにデータがない場合はFirebaseから読み込み
        try {
          final jsonString = await UserSettingsFirestoreService.getSetting(
            _storageKey,
          );

          if (jsonString != null) {
            final List<dynamic> jsonList = jsonString;
            _workProgressList = jsonList
                .map((json) => WorkProgress.fromMap(json))
                .toList();

            // 作成日順にソート（新しい順）
            _workProgressList.sort(
              (a, b) => b.createdAt.compareTo(a.createdAt),
            );
          } else {
            _workProgressList = [];
          }
        } catch (e) {
          print('Firebaseからの作業進捗読み込みエラー: $e');
          _workProgressList = [];
        }
      }
    } catch (e) {
      print('Error loading work progress: $e');
      _workProgressList = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final jsonString = _workProgressList.map((wp) => wp.toMap()).toList();
      await UserSettingsFirestoreService.saveSetting(_storageKey, jsonString);
    } catch (e) {
      print('Error saving work progress: $e');
      rethrow;
    }
  }

  Future<void> addWorkProgress(WorkProgress workProgress) async {
    try {
      final newWorkProgress = workProgress.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: 'local_user', // ローカル保存なので固定ID
      );

      _workProgressList.insert(0, newWorkProgress);

      // Firestoreに保存
      try {
        await WorkProgressFirestoreService.saveWorkProgressRecord(
          newWorkProgress,
        );
      } catch (e) {
        print('Firestore保存エラー: $e');
        // Firestore保存に失敗してもローカル保存は続行
      }

      await _saveToStorage();
      notifyListeners();
    } catch (e) {
      print('Error adding work progress: $e');
      rethrow;
    }
  }

  Future<void> updateWorkProgress(WorkProgress workProgress) async {
    try {
      final index = _workProgressList.indexWhere(
        (wp) => wp.id == workProgress.id,
      );
      if (index != -1) {
        _workProgressList[index] = workProgress;

        // Firestoreに更新
        try {
          await WorkProgressFirestoreService.updateWorkProgressRecord(
            workProgress,
          );
        } catch (e) {
          print('Firestore更新エラー: $e');
          // Firestore更新に失敗してもローカル保存は続行
        }

        await _saveToStorage();
        notifyListeners();
      }
    } catch (e) {
      print('Error updating work progress: $e');
      rethrow;
    }
  }

  Future<void> deleteWorkProgress(String id) async {
    try {
      _workProgressList.removeWhere((wp) => wp.id == id);

      // Firestoreから削除
      try {
        await WorkProgressFirestoreService.deleteWorkProgressRecord(id);
      } catch (e) {
        print('Firestore削除エラー: $e');
        // Firestore削除に失敗してもローカル保存は続行
      }

      await _saveToStorage();
      notifyListeners();
    } catch (e) {
      print('Error deleting work progress: $e');
      rethrow;
    }
  }

  List<WorkProgress> getWorkProgressByBean(String beanId) {
    return _workProgressList.where((wp) => wp.beanId == beanId).toList();
  }
}
