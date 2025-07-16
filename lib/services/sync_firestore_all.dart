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
import 'package:bysnapp/pages/drip/drip_counter_page.dart';
import 'package:bysnapp/pages/home/AssignmentBoard.dart';
import 'package:bysnapp/pages/roast/roast_timer_settings_page.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tasting_models.dart';
import '../models/work_progress_models.dart';

// TodoPage用のグローバルKeyを用意
final GlobalKey<TodoPageState> todoListPageKey = GlobalKey<TodoPageState>();

final GlobalKey<DripCounterPageState> dripCounterPageKey =
    GlobalKey<DripCounterPageState>();

final GlobalKey<AssignmentBoardState> assignmentBoardKey =
    GlobalKey<AssignmentBoardState>();

final GlobalKey<RoastTimerSettingsPageState> roastTimerSettingsPageKey =
    GlobalKey<RoastTimerSettingsPageState>();

/// Firestoreから全データを取得し、各ProviderやStateに反映する共通同期関数
Future<void> syncAllFirestoreData(BuildContext context) async {
  // 1. TODOリスト
  try {
    final todos = await ScheduleFirestoreService.loadTodayTodoList();
    if (todos != null && todoListPageKey.currentState != null) {
      todoListPageKey.currentState!.setTodosFromFirestore(todos);
    }
    // ローカルにも保存
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'todoList',
      todos?.map((e) => TodoItem.fromMap(e).toStorageString()).toList() ?? [],
    );
  } catch (e) {
    print('同期エラー: $e');
  }

  // 2. 本日のスケジュール（内容・ラベル）
  try {
    final todaySchedule =
        await ScheduleFirestoreService.loadTodayTodoSchedule();
    if (todaySchedule != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'todaySchedule_labels',
        json.encode(todaySchedule['labels'] ?? []),
      );
      await prefs.setString(
        'todaySchedule_contents',
        json.encode(todaySchedule['contents'] ?? {}),
      );
    }
  } catch (e) {
    print('同期エラー: $e');
  }

  // 3. 本日のスケジュールの時間ラベル
  try {
    final timeLabels = await ScheduleFirestoreService.loadTimeLabels();
    if (timeLabels != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('todaySchedule_labels', json.encode(timeLabels));
    }
  } catch (e) {
    print('同期エラー: $e');
  }

  // 4. ドリップパック記録
  try {
    final dripRecords = await DripCounterFirestoreService.loadDripPackRecords();
    if (dripCounterPageKey.currentState != null) {
      dripCounterPageKey.currentState!.setDripRecordsFromFirestore(dripRecords);
    }
    // ローカルにも保存
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dripPackRecords', json.encode(dripRecords ?? []));
  } catch (e) {
    print('同期エラー: $e');
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
      final prefs = await SharedPreferences.getInstance();

      // 新しい形式（teams）で保存
      if (assignmentMembers['teams'] != null) {
        await prefs.setString('teams', json.encode(assignmentMembers['teams']));
      }

      // 後方互換性のため、古い形式でも保存
      await prefs.setStringList(
        'a班',
        List<String>.from(assignmentMembers['aMembers'] ?? []),
      );
      await prefs.setStringList(
        'b班',
        List<String>.from(assignmentMembers['bMembers'] ?? []),
      );
      await prefs.setStringList(
        'leftLabels',
        List<String>.from(assignmentMembers['leftLabels'] ?? []),
      );
      await prefs.setStringList(
        'rightLabels',
        List<String>.from(assignmentMembers['rightLabels'] ?? []),
      );

      print('担当表データの同期完了');
    }
  } catch (e) {
    print('担当表データの同期エラー: $e');
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'assignment_$dateKey',
        List<String>.from(assignmentHistory),
      );
    }
  } catch (e) {
    print('同期エラー: $e');
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
    print('同期エラー: $e');
  }

  // 8. テイスティング記録
  try {
    final tastingRecords = await TastingFirestoreService.getTastingRecords();
    final tastingProvider = Provider.of<TastingProvider>(
      context,
      listen: false,
    );
    // 一括セット用メソッドに修正
    tastingProvider.replaceAll(tastingRecords);
    // ローカルにも保存
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'tastingRecords',
      json.encode(tastingRecords.map((e) => e.toMap()).toList()),
    );
  } catch (e) {
    print('同期エラー: $e');
  }

  // 9. 作業進捗記録
  try {
    final workProgressRecords =
        await WorkProgressFirestoreService.getWorkProgressRecords();
    final workProgressProvider = Provider.of<WorkProgressProvider>(
      context,
      listen: false,
    );
    // 一括セット用メソッドに修正
    workProgressProvider.replaceAll(workProgressRecords);
    // ローカルにも保存
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'workProgressRecords',
      json.encode(workProgressRecords.map((e) => e.toMap()).toList()),
    );
  } catch (e) {
    print('同期エラー: $e');
  }
}
