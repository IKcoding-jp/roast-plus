import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/roast_schedule_form_provider.dart';
import '../pages/todo/todo_list_page.dart';
import '../services/schedule_firestore_service.dart';
import '../services/roast_break_time_firestore_service.dart';
import '../services/assignment_firestore_service.dart';
import '../services/drip_counter_firestore_service.dart';
import '../services/roast_timer_settings_firestore_service.dart';
import 'package:bysnapp/pages/drip/drip_counter_page.dart';
import 'package:bysnapp/pages/home/AssignmentBoard.dart';
import 'package:bysnapp/pages/roast/roast_timer_settings_page.dart';
import 'package:bysnapp/pages/roast/roast_scheduler_tab.dart';

// TodoListPage用のグローバルKeyを用意
final GlobalKey<TodoListPageState> todoListPageKey =
    GlobalKey<TodoListPageState>();

final GlobalKey<DripCounterPageState> dripCounterPageKey =
    GlobalKey<DripCounterPageState>();

final GlobalKey<AssignmentBoardState> assignmentBoardKey =
    GlobalKey<AssignmentBoardState>();

final GlobalKey<RoastTimerSettingsPageState> roastTimerSettingsPageKey =
    GlobalKey<RoastTimerSettingsPageState>();

final GlobalKey<RoastSchedulerTabState> roastSchedulerTabKey =
    GlobalKey<RoastSchedulerTabState>();

/// Firestoreから全データを取得し、各ProviderやStateに反映する共通同期関数
Future<void> syncAllFirestoreData(BuildContext context) async {
  // 1. 本日のスケジュール
  try {
    final todaySchedule =
        await ScheduleFirestoreService.loadTodayTodoSchedule();
    if (todaySchedule != null && todoListPageKey.currentState != null) {
      todoListPageKey.currentState!.setScheduleFromFirestore(todaySchedule);
    }
  } catch (_) {}

  // 2. 時間ラベル
  try {
    final timeLabels = await ScheduleFirestoreService.loadTimeLabels();
    if (timeLabels != null && todoListPageKey.currentState != null) {
      todoListPageKey.currentState!.setTimeLabelsFromFirestore(timeLabels);
    }
  } catch (_) {}

  // 3. TODOリスト
  try {
    final todos = await ScheduleFirestoreService.loadTodayTodoList();
    if (todos != null && todoListPageKey.currentState != null) {
      todoListPageKey.currentState!.setTodosFromFirestore(todos);
    }
  } catch (_) {}

  // 4. ドリップパック記録
  try {
    final dripRecords = await DripCounterFirestoreService.loadDripPackRecords();
    if (dripCounterPageKey.currentState != null) {
      dripCounterPageKey.currentState!.setDripRecordsFromFirestore(dripRecords);
    }
  } catch (_) {}

  // 5. 担当表メンバー
  try {
    final assignmentMembers =
        await AssignmentFirestoreService.loadAssignmentMembers();
    if (assignmentMembers != null && assignmentBoardKey.currentState != null) {
      assignmentBoardKey.currentState!.setAssignmentMembersFromFirestore(
        assignmentMembers,
      );
    }
  } catch (_) {}

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
    }
  } catch (_) {}

  // 7. 焙煎タイマー設定
  try {
    final preheatMinutes =
        await RoastTimerSettingsFirestoreService.loadRoastTimerSettings();
    if (preheatMinutes != null &&
        roastTimerSettingsPageKey.currentState != null) {
      roastTimerSettingsPageKey.currentState!.setPreheatMinutesFromFirestore(
        preheatMinutes,
      );
    }
  } catch (_) {}

  // 8. 休憩時間設定
  try {
    final breakTimes = await RoastBreakTimeFirestoreService.loadBreakTimes();
    if (todoListPageKey.currentState != null) {
      todoListPageKey.currentState!.setRoastBreakTimesFromFirestore(breakTimes);
    }
  } catch (_) {}

  // 9. ローストスケジュール
  try {
    final schedule = await ScheduleFirestoreService.loadTodaySchedule();
    if (schedule != null && roastSchedulerTabKey.currentState != null) {
      roastSchedulerTabKey.currentState!.setScheduleFromFirestore(schedule);
    }
  } catch (_) {}
}
