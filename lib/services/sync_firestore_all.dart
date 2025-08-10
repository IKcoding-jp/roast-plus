import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pages/todo/todo_page.dart';
import '../pages/todo/todo_list_tab.dart';
import '../services/schedule_firestore_service.dart';
import '../services/assignment_firestore_service.dart';
import '../services/drip_counter_firestore_service.dart';
import '../services/roast_timer_settings_firestore_service.dart';
import '../services/tasting_firestore_service.dart';
import '../services/work_progress_firestore_service.dart';
import 'package:roastplus/pages/drip/drip_counter_page.dart';
import '../pages/business/assignment_board_page.dart';
import 'package:roastplus/pages/roast/roast_timer_settings_page.dart';
import '../models/tasting_models.dart';
import '../models/work_progress_models.dart';
import '../models/gamification_provider.dart';
import 'dart:developer' as developer;

import '../services/user_settings_firestore_service.dart';

const String _logNameSyncAll = 'SyncFirestoreAll';
void _logInfo(String message) => developer.log(message, name: _logNameSyncAll);
void _logError(String message, [Object? error, StackTrace? stackTrace]) =>
    developer.log(
      message,
      name: _logNameSyncAll,
      error: error,
      stackTrace: stackTrace,
    );

// TodoPage用のグローバルKeyを用意
final GlobalKey<TodoPageState> todoListPageKey = GlobalKey<TodoPageState>();

final GlobalKey<DripCounterPageState> dripCounterPageKey =
    GlobalKey<DripCounterPageState>();

final GlobalKey<AssignmentBoardState> assignmentBoardKey =
    GlobalKey<AssignmentBoardState>();

final GlobalKey<RoastTimerSettingsPageState> roastTimerSettingsPageKey =
    GlobalKey<RoastTimerSettingsPageState>();

/// Firestoreから全データを取得し、各ProviderやStateに反映する共通同期関数
Future<void> syncAllFirestoreData(
  BuildContext context, {
  bool isLightSync = false,
}) async {
  // Providerは非同期ギャップ前に取得しておく
  final tastingProvider = Provider.of<TastingProvider>(context, listen: false);
  final workProgressProvider = Provider.of<WorkProgressProvider>(
    context,
    listen: false,
  );
  final gamificationProvider = Provider.of<GamificationProvider>(
    context,
    listen: false,
  );

  if (!isLightSync) {
    try {
      final todos = await ScheduleFirestoreService.loadTodayTodoList();
      if (todos != null && todoListPageKey.currentState != null) {
        todoListPageKey.currentState!.setTodosFromFirestore(todos);
      }
      // ローカルにも保存
      await UserSettingsFirestoreService.saveSetting(
        'todoList',
        todos?.map((e) => TodoItem.fromMap(e).toStorageString()).toList() ?? [],
      );
    } catch (e) {
      _logError('同期エラー', e as Object?);
    }
  }

  // 2. 本日のスケジュール（内容・ラベル）（軽量同期の場合はスキップ）
  if (!isLightSync) {
    try {
      final todaySchedule =
          await ScheduleFirestoreService.loadTodayTodoSchedule();
      if (todaySchedule != null) {
        await UserSettingsFirestoreService.saveMultipleSettings({
          'todaySchedule_labels': todaySchedule['labels'] ?? [],
          'todaySchedule_contents': todaySchedule['contents'] ?? {},
        });
      }
    } catch (e) {
      _logError('同期エラー', e as Object?);
    }
  }

  // 3. 本日のスケジュールの時間ラベル
  try {
    final timeLabels = await ScheduleFirestoreService.loadTimeLabels();
    if (timeLabels != null) {
      await UserSettingsFirestoreService.saveSetting(
        'todaySchedule_timeLabels', // ← 保存先キーを変更
        timeLabels,
      );
    }
  } catch (e) {
    _logError('同期エラー', e as Object?);
  }

  // 4. ドリップパック記録
  try {
    final dripRecords = await DripCounterFirestoreService.loadDripPackRecords();
    if (dripCounterPageKey.currentState != null) {
      dripCounterPageKey.currentState!.setDripRecordsFromFirestore(dripRecords);
    }
    // ローカルにも保存
    await UserSettingsFirestoreService.saveSetting(
      'dripPackRecords',
      dripRecords,
    );
  } catch (e) {
    _logError('同期エラー', e as Object?);
  }

  // 5. 担当表メンバー・ラベル
  try {
    final assignmentMembers =
        await AssignmentFirestoreService.loadAssignmentMembers();
    if (assignmentMembers != null && assignmentBoardKey.currentState != null) {
      assignmentBoardKey.currentState!.setAssignmentMembersFromFirestore(
        assignmentMembers,
      );
      // ローカルにも保存（新しい形式と古い形式の両方）
      final settingsToSave = <String, dynamic>{};

      // 新しい形式（teams）で保存
      if (assignmentMembers['teams'] != null) {
        settingsToSave['teams'] = assignmentMembers['teams'];
      }

      // 後方互換性のため、古い形式でも保存
      settingsToSave['assignment_a班'] = List<String>.from(
        assignmentMembers['aMembers'] ?? [],
      );
      settingsToSave['assignment_b班'] = List<String>.from(
        assignmentMembers['bMembers'] ?? [],
      );
      settingsToSave['assignment_leftLabels'] = List<String>.from(
        assignmentMembers['leftLabels'] ?? [],
      );
      settingsToSave['assignment_rightLabels'] = List<String>.from(
        assignmentMembers['rightLabels'] ?? [],
      );

      await UserSettingsFirestoreService.saveMultipleSettings(settingsToSave);

      _logInfo('担当表データの同期完了');
    }
  } catch (e) {
    _logError('担当表データの同期エラー', e as Object?);
  }

  // 6. 担当履歴（本日分のみ例示）
  try {
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final assignmentHistory =
        await AssignmentFirestoreService.loadAssignmentHistory(dateKey);
    if (assignmentHistory != null && assignmentBoardKey.currentState != null) {
      assignmentBoardKey.currentState!.setAssignmentHistoryFromFirestore(
        assignmentHistory,
      );
      // ローカルにも保存
      await UserSettingsFirestoreService.saveSetting(
        'assignment_$dateKey',
        List<String>.from(assignmentHistory),
      );
    }
  } catch (e) {
    _logError('同期エラー', e as Object?);
  }

  // 7. 焙煎タイマー設定
  try {
    final timerSettings =
        await RoastTimerSettingsFirestoreService.loadRoastTimerSettings();
    if (timerSettings != null &&
        roastTimerSettingsPageKey.currentState != null) {
      roastTimerSettingsPageKey.currentState!.setPreheatMinutesFromFirestore(
        timerSettings['preheatMinutes'] ?? 30,
      );
      // 必要に応じて他の設定も反映可能
    }
  } catch (e) {
    _logError('同期エラー', e as Object?);
  }

  // 8. テイスティング記録
  try {
    final tastingRecords = await TastingFirestoreService.getTastingRecords();
    // 一括セット用メソッドに修正
    tastingProvider.replaceAll(tastingRecords);
    // ローカルにも保存
    await UserSettingsFirestoreService.saveSetting(
      'tastingRecords',
      tastingRecords.map((e) => e.toMap()).toList(),
    );
  } catch (e) {
    _logError('同期エラー', e as Object?);
  }

  // 9. 作業進捗記録
  try {
    final workProgressRecords =
        await WorkProgressFirestoreService.getWorkProgressRecords();
    // 一括セット用メソッドに修正
    workProgressProvider.replaceAll(workProgressRecords);
    // ローカルにも保存
    await UserSettingsFirestoreService.saveSetting(
      'workProgressRecords',
      workProgressRecords.map((e) => e.toMap()).toList(),
    );
  } catch (e) {
    _logError('同期エラー', e as Object?);
  }

  // 10. ゲーミフィケーションデータ
  try {
    // Firestoreからデータを読み込んでローカルと同期
    // 個人レベルシステムは削除されたため、グループゲーミフィケーションのみを使用
    // プロバイダーを初期化（最新データで更新）
    await gamificationProvider.initialize();
    _logInfo('ゲーミフィケーションデータの同期完了');
  } catch (e) {
    _logError('ゲーミフィケーション同期エラー', e as Object?);
  }
}
