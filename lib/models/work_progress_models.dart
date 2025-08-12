import 'package:flutter/widgets.dart';
import '../services/work_progress_firestore_service.dart';
import '../services/user_settings_firestore_service.dart';
import 'dart:developer' as developer;

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
  inProgress, // 途中
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
    // ビルド中でないことを確認してからnotifyListenersを呼び出す
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
  // --- ここまで追加 ---

  Future<void> loadWorkProgress({String? groupId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      List<WorkProgress> firestoreRecords = [];
      if (groupId != null && groupId.isNotEmpty) {
        // グループ用APIのみ
        firestoreRecords =
            await WorkProgressFirestoreService.getGroupWorkProgressRecords(
              groupId,
            );
      } else {
        // 個人用APIのみ
        firestoreRecords =
            await WorkProgressFirestoreService.getWorkProgressRecords();
      }

      if (firestoreRecords.isNotEmpty) {
        _workProgressList = firestoreRecords;
        // 作成日順にソート（新しい順）
        _workProgressList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        // Firestoreにデータがない場合
        if (groupId != null && groupId.isNotEmpty) {
          // グループ時は何も読み込まない
          _workProgressList = [];
        } else {
          // 個人用のみローカルストレージを参照
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
          } catch (e, st) {
            developer.log(
              'Firebaseからの作業進捗読み込みエラー',
              name: 'WorkProgressProvider',
              error: e,
              stackTrace: st,
            );
            _workProgressList = [];
          }
        }
      }
    } catch (e, st) {
      developer.log(
        'Error loading work progress',
        name: 'WorkProgressProvider',
        error: e,
        stackTrace: st,
      );
      _workProgressList = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveToStorage({String? groupId}) async {
    // グループ時はローカル保存しない
    if (groupId != null && groupId.isNotEmpty) return;
    try {
      final jsonString = _workProgressList.map((wp) => wp.toMap()).toList();
      await UserSettingsFirestoreService.saveSetting(_storageKey, jsonString);
    } catch (e, st) {
      developer.log(
        'Error saving work progress',
        name: 'WorkProgressProvider',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> addWorkProgress(
    WorkProgress workProgress, {
    String? groupId,
  }) async {
    try {
      final newWorkProgress = workProgress.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: 'local_user', // ローカル保存なので固定ID
      );

      _workProgressList.insert(0, newWorkProgress);

      // Firestoreに保存
      try {
        if (groupId != null && groupId.isNotEmpty) {
          await WorkProgressFirestoreService.saveGroupWorkProgressRecord(
            groupId,
            newWorkProgress,
          );
          // グループ時は個人Firestoreやローカルストレージに保存しない
          return;
        } else {
          await WorkProgressFirestoreService.saveWorkProgressRecord(
            newWorkProgress,
          );
        }
      } catch (e, st) {
        developer.log(
          'Firestore保存エラー',
          name: 'WorkProgressProvider',
          error: e,
          stackTrace: st,
        );
        // Firestore保存に失敗してもローカル保存は続行
      }

      await _saveToStorage(groupId: groupId);
      notifyListeners();
    } catch (e, st) {
      developer.log(
        'Error adding work progress',
        name: 'WorkProgressProvider',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> updateWorkProgress(
    WorkProgress workProgress, {
    String? groupId,
  }) async {
    try {
      final index = _workProgressList.indexWhere(
        (wp) => wp.id == workProgress.id,
      );
      if (index != -1) {
        _workProgressList[index] = workProgress;

        // Firestoreに更新
        try {
          if (groupId != null && groupId.isNotEmpty) {
            await WorkProgressFirestoreService.updateGroupWorkProgressRecord(
              groupId,
              workProgress,
            );
            // グループ時は個人Firestoreやローカルストレージに保存しない
            return;
          } else {
            await WorkProgressFirestoreService.updateWorkProgressRecord(
              workProgress,
            );
          }
        } catch (e, st) {
          developer.log(
            'Firestore更新エラー',
            name: 'WorkProgressProvider',
            error: e,
            stackTrace: st,
          );
          // Firestore更新に失敗してもローカル保存は続行
        }

        await _saveToStorage(groupId: groupId);
        notifyListeners();
      }
    } catch (e, st) {
      developer.log(
        'Error updating work progress',
        name: 'WorkProgressProvider',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> deleteWorkProgress(String id, {String? groupId}) async {
    try {
      final index = _workProgressList.indexWhere((wp) => wp.id == id);
      if (index != -1) {
        _workProgressList.removeAt(index);

        // Firestoreから削除
        try {
          if (groupId != null && groupId.isNotEmpty) {
            await WorkProgressFirestoreService.deleteGroupWorkProgressRecord(
              groupId,
              id,
            );
            // グループ時は個人Firestoreやローカルストレージに保存しない
            return;
          } else {
            await WorkProgressFirestoreService.deleteWorkProgressRecord(id);
          }
        } catch (e, st) {
          developer.log(
            'Firestore削除エラー',
            name: 'WorkProgressProvider',
            error: e,
            stackTrace: st,
          );
          // Firestore削除に失敗してもローカル保存は続行
        }

        await _saveToStorage(groupId: groupId);
        notifyListeners();
      }
    } catch (e, st) {
      developer.log(
        'Error deleting work progress',
        name: 'WorkProgressProvider',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  List<WorkProgress> getWorkProgressByBean(String beanId) {
    return _workProgressList.where((wp) => wp.beanId == beanId).toList();
  }
}
