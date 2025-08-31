import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group_gamification_models.dart';
import 'group_firestore_service.dart';
import 'gamification_firestore_service.dart';

class GroupDataSyncService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  /// グループの焙煎記録を同期
  static Future<void> syncRoastRecords(
    String groupId,
    Map<String, dynamic> roastData,
  ) async {
    developer.log('GroupDataSyncService: 焙煎記録の同期権限チェック開始');
    // 同期権限チェック（編集権限とは別）
    final canSync = await GroupFirestoreService.canSyncDataType(
      groupId: groupId,
      dataType: 'roast_records',
    );

    if (!canSync) {
      developer.log('GroupDataSyncService: 焙煎記録の同期権限がありません');
      throw Exception('焙煎記録の同期権限がありません');
    }
    developer.log('GroupDataSyncService: 焙煎記録の同期権限チェック完了');

    developer.log('GroupDataSyncService: 焙煎記録データをFirestoreに保存中...');
    await GroupFirestoreService.syncGroupData(
      groupId: groupId,
      dataType: 'roast_records',
      data: roastData,
    );
    developer.log('GroupDataSyncService: 焙煎記録データの保存完了');
  }

  /// グループの焙煎記録を取得
  static Future<Map<String, dynamic>?> getGroupRoastRecords(
    String groupId,
  ) async {
    return await GroupFirestoreService.getGroupData(
      groupId: groupId,
      dataType: 'roast_records',
    );
  }

  /// グループの焙煎記録の変更を監視
  static Stream<Map<String, dynamic>?> watchGroupRoastRecords(String groupId) {
    return GroupFirestoreService.watchGroupData(
      groupId: groupId,
      dataType: 'roast_records',
    );
  }

  /// グループのTODOリストを同期
  static Future<void> syncTodoList(
    String groupId,
    Map<String, dynamic> todoData,
  ) async {
    // 同期権限チェック（編集権限とは別）
    final canSync = await GroupFirestoreService.canSyncDataType(
      groupId: groupId,
      dataType: 'todo_list',
    );

    if (!canSync) {
      throw Exception('TODOリストの同期権限がありません');
    }

    await GroupFirestoreService.syncGroupData(
      groupId: groupId,
      dataType: 'todo_list',
      data: todoData,
    );
  }

  /// グループのTODOリストを取得
  static Future<Map<String, dynamic>?> getGroupTodoList(String groupId) async {
    return await GroupFirestoreService.getGroupData(
      groupId: groupId,
      dataType: 'todo_list',
    );
  }

  /// グループのTODOリストの変更を監視
  static Stream<Map<String, dynamic>?> watchGroupTodoList(String groupId) {
    return GroupFirestoreService.watchGroupData(
      groupId: groupId,
      dataType: 'todo_list',
    );
  }

  /// グループのドリップカウンター記録を同期
  static Future<void> syncDripCounterRecords(
    String groupId,
    Map<String, dynamic> dripData,
  ) async {
    // 同期権限チェック（編集権限とは別）
    final canSync = await GroupFirestoreService.canSyncDataType(
      groupId: groupId,
      dataType: 'drip_counter_records',
    );

    if (!canSync) {
      throw Exception('ドリップカウンター記録の同期権限がありません');
    }

    // sharedData への同期のみ（古いdrip_pack_recordsコレクションは使用しない）
    await GroupFirestoreService.syncGroupData(
      groupId: groupId,
      dataType: 'drip_counter_records',
      data: dripData,
    );

    developer.log(
      'GroupDataSyncService: ドリップカウンター記録を同期しました - groupId: $groupId, 記録数: ${dripData['records']?.length ?? 0}',
    );
  }

  /// グループのドリップカウンター記録を取得
  static Future<Map<String, dynamic>?> getGroupDripCounterRecords(
    String groupId,
  ) async {
    return await GroupFirestoreService.getGroupData(
      groupId: groupId,
      dataType: 'drip_counter_records',
    );
  }

  /// グループのドリップカウンター記録の変更を監視
  static Stream<Map<String, dynamic>?> watchGroupDripCounterRecords(
    String groupId,
  ) {
    return GroupFirestoreService.watchGroupData(
      groupId: groupId,
      dataType: 'drip_counter_records',
    );
  }

  /// グループのドリップパック記録の合計数を取得
  static Future<int> getGroupDripPackTotalCount(String groupId) async {
    try {
      // グループの共有データからドリップパック記録を取得
      final sharedDataDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('sharedData')
          .doc('drip_counter_records')
          .get();

      int totalCount = 0;

      if (sharedDataDoc.exists) {
        final data = sharedDataDoc.data();
        final records = data?['data']?['records'] as List<dynamic>?;

        if (records != null) {
          for (final record in records) {
            final count = record['count'] ?? 0;
            final intCount = (count is int)
                ? count
                : (count is num)
                ? count.toInt()
                : 0;
            totalCount += intCount;
          }
        }
      }

      developer.log('GroupDataSyncService: ドリップパック合計数取得完了: $totalCount個');
      return totalCount;
    } catch (e) {
      developer.log('GroupDataSyncService: ドリップパック合計数取得エラー: $e');
      return 0;
    }
  }

  /// グループの担当表を同期
  static Future<void> syncAssignmentBoard(
    String groupId,
    Map<String, dynamic> assignmentData,
  ) async {
    // 同期権限チェック（編集権限とは別）
    final canSync = await GroupFirestoreService.canSyncDataType(
      groupId: groupId,
      dataType: 'assignment_board',
    );

    if (!canSync) {
      throw Exception('担当表の同期権限がありません');
    }

    await GroupFirestoreService.syncGroupData(
      groupId: groupId,
      dataType: 'assignment_board',
      data: assignmentData,
    );
  }

  /// グループの担当表を取得
  static Future<Map<String, dynamic>?> getGroupAssignmentBoard(
    String groupId,
  ) async {
    return await GroupFirestoreService.getGroupData(
      groupId: groupId,
      dataType: 'assignment_board',
    );
  }

  /// グループの担当表の変更を監視
  static Stream<Map<String, dynamic>?> watchGroupAssignmentBoard(
    String groupId,
  ) {
    return GroupFirestoreService.watchGroupData(
      groupId: groupId,
      dataType: 'assignment_board',
    );
  }

  /// グループのスケジュールを同期
  static Future<void> syncSchedule(
    String groupId,
    Map<String, dynamic> scheduleData,
  ) async {
    // 同期権限チェック（編集権限とは別）
    final canSync = await GroupFirestoreService.canSyncDataType(
      groupId: groupId,
      dataType: 'schedule',
    );

    if (!canSync) {
      throw Exception('スケジュールの同期権限がありません');
    }

    await GroupFirestoreService.syncGroupData(
      groupId: groupId,
      dataType: 'schedule',
      data: scheduleData,
    );
  }

  /// グループのスケジュールを取得
  static Future<Map<String, dynamic>?> getGroupSchedule(String groupId) async {
    return await GroupFirestoreService.getGroupData(
      groupId: groupId,
      dataType: 'schedule',
    );
  }

  /// グループのスケジュールの変更を監視
  static Stream<Map<String, dynamic>?> watchGroupSchedule(String groupId) {
    return GroupFirestoreService.watchGroupData(
      groupId: groupId,
      dataType: 'schedule',
    );
  }

  /// グループのメモリストを同期
  static Future<void> syncMemoList(
    String groupId,
    Map<String, dynamic> memoData,
  ) async {
    // 同期権限チェック（編集権限とは別）
    final canSync = await GroupFirestoreService.canSyncDataType(
      groupId: groupId,
      dataType: 'memos',
    );

    if (!canSync) {
      throw Exception('メモリストの同期権限がありません');
    }

    await GroupFirestoreService.syncGroupData(
      groupId: groupId,
      dataType: 'memos',
      data: memoData,
    );
  }

  /// グループのメモリストを取得
  static Future<Map<String, dynamic>?> getGroupMemoList(String groupId) async {
    return await GroupFirestoreService.getGroupData(
      groupId: groupId,
      dataType: 'memos',
    );
  }

  /// グループのメモリストの変更を監視
  static Stream<Map<String, dynamic>?> watchGroupMemoList(String groupId) {
    return GroupFirestoreService.watchGroupData(
      groupId: groupId,
      dataType: 'memos',
    );
  }

  /// グループの本日のスケジュールを同期
  static Future<void> syncTodaySchedule(
    String groupId,
    Map<String, dynamic> todayScheduleData,
  ) async {
    // 同期権限チェック（編集権限とは別）
    final canSync = await GroupFirestoreService.canSyncDataType(
      groupId: groupId,
      dataType: 'today_schedule',
    );

    if (!canSync) {
      throw Exception('本日のスケジュールの同期権限がありません');
    }

    await GroupFirestoreService.syncGroupData(
      groupId: groupId,
      dataType: 'today_schedule',
      data: todayScheduleData,
    );
  }

  /// グループの本日のスケジュールを取得
  static Future<Map<String, dynamic>?> getGroupTodaySchedule(
    String groupId,
  ) async {
    return await GroupFirestoreService.getGroupData(
      groupId: groupId,
      dataType: 'today_schedule',
    );
  }

  /// グループの本日のスケジュールの変更を監視
  static Stream<Map<String, dynamic>?> watchGroupTodaySchedule(String groupId) {
    return GroupFirestoreService.watchGroupData(
      groupId: groupId,
      dataType: 'today_schedule',
    );
  }

  /// グループの時間ラベルを同期
  static Future<void> syncTimeLabels(
    String groupId,
    Map<String, dynamic> timeLabelsData,
  ) async {
    // 同期権限チェック（編集権限とは別）
    final canSync = await GroupFirestoreService.canSyncDataType(
      groupId: groupId,
      dataType: 'time_labels',
    );

    if (!canSync) {
      throw Exception('時間ラベルの同期権限がありません');
    }

    await GroupFirestoreService.syncGroupData(
      groupId: groupId,
      dataType: 'time_labels',
      data: timeLabelsData,
    );
  }

  /// グループの時間ラベルを取得
  static Future<Map<String, dynamic>?> getGroupTimeLabels(
    String groupId,
  ) async {
    return await GroupFirestoreService.getGroupData(
      groupId: groupId,
      dataType: 'time_labels',
    );
  }

  /// グループの時間ラベルの変更を監視
  static Stream<Map<String, dynamic>?> watchGroupTimeLabels(String groupId) {
    return GroupFirestoreService.watchGroupData(
      groupId: groupId,
      dataType: 'time_labels',
    );
  }

  /// グループの設定を同期
  static Future<void> syncSettings(
    String groupId,
    Map<String, dynamic> settingsData,
  ) async {
    // 同期権限チェック（編集権限とは別）
    final canSync = await GroupFirestoreService.canSyncDataType(
      groupId: groupId,
      dataType: 'settings',
    );

    if (!canSync) {
      throw Exception('設定の同期権限がありません');
    }

    await GroupFirestoreService.syncGroupData(
      groupId: groupId,
      dataType: 'settings',
      data: settingsData,
    );
  }

  /// グループの設定を取得
  static Future<Map<String, dynamic>?> getGroupSettings(String groupId) async {
    return await GroupFirestoreService.getGroupData(
      groupId: groupId,
      dataType: 'settings',
    );
  }

  /// グループの設定の変更を監視
  static Stream<Map<String, dynamic>?> watchGroupSettings(String groupId) {
    return GroupFirestoreService.watchGroupData(
      groupId: groupId,
      dataType: 'settings',
    );
  }

  /// グループの今日の担当履歴を同期
  static Future<void> syncTodayAssignment(
    String groupId,
    Map<String, dynamic> todayAssignmentData,
  ) async {
    // 同期権限チェック（編集権限とは別）
    final canSync = await GroupFirestoreService.canSyncDataType(
      groupId: groupId,
      dataType: 'assignment_board', // assignment_boardに統一
    );

    if (!canSync) {
      throw Exception('担当表の同期権限がありません');
    }

    await GroupFirestoreService.syncGroupData(
      groupId: groupId,
      dataType: 'today_assignment', // データ保存場所は変更なし
      data: todayAssignmentData,
    );
  }

  /// グループの今日の担当履歴を取得
  static Future<Map<String, dynamic>?> getGroupTodayAssignment(
    String groupId,
  ) async {
    return await GroupFirestoreService.getGroupData(
      groupId: groupId,
      dataType: 'today_assignment',
    );
  }

  /// グループの今日の担当履歴の変更を監視
  static Stream<Map<String, dynamic>?> watchGroupTodayAssignment(
    String groupId,
  ) {
    return GroupFirestoreService.watchGroupData(
      groupId: groupId,
      dataType: 'today_assignment',
    );
  }

  /// グループの担当履歴を同期
  static Future<void> syncAssignmentHistory(
    String groupId,
    Map<String, dynamic> assignmentHistoryData,
  ) async {
    // 同期権限チェック（編集権限とは別）
    final canSync = await GroupFirestoreService.canSyncDataType(
      groupId: groupId,
      dataType: 'assignment_board', // assignment_boardに統一
    );

    if (!canSync) {
      throw Exception('担当表の同期権限がありません');
    }

    await GroupFirestoreService.syncGroupData(
      groupId: groupId,
      dataType: 'assignment_history', // データ保存場所は変更なし
      data: assignmentHistoryData,
    );
  }

  /// グループの担当履歴を取得
  static Future<Map<String, dynamic>?> getGroupAssignmentHistory(
    String groupId,
  ) async {
    return await GroupFirestoreService.getGroupData(
      groupId: groupId,
      dataType: 'assignment_history',
    );
  }

  /// グループの担当履歴の変更を監視
  static Stream<Map<String, dynamic>?> watchGroupAssignmentHistory(
    String groupId,
  ) {
    return GroupFirestoreService.watchGroupData(
      groupId: groupId,
      dataType: 'assignment_history',
    );
  }

  /// グループのテイスティング記録を同期
  static Future<void> syncTastingRecords(
    String groupId,
    Map<String, dynamic> tastingData,
  ) async {
    // 同期権限チェック（編集権限とは別）
    final canSync = await GroupFirestoreService.canSyncDataType(
      groupId: groupId,
      dataType: 'tasting_records',
    );

    if (!canSync) {
      throw Exception('テイスティング記録の同期権限がありません');
    }

    await GroupFirestoreService.syncGroupData(
      groupId: groupId,
      dataType: 'tasting_records',
      data: tastingData,
    );
  }

  /// グループのテイスティング記録を取得
  static Future<Map<String, dynamic>?> getGroupTastingRecords(
    String groupId,
  ) async {
    return await GroupFirestoreService.getGroupData(
      groupId: groupId,
      dataType: 'tasting_records',
    );
  }

  /// グループのテイスティング記録の変更を監視
  static Stream<Map<String, dynamic>?> watchGroupTastingRecords(
    String groupId,
  ) {
    return GroupFirestoreService.watchGroupData(
      groupId: groupId,
      dataType: 'tasting_records',
    );
  }

  /// グループの作業進捗記録を同期
  static Future<void> syncWorkProgress(
    String groupId,
    Map<String, dynamic> workProgressData,
  ) async {
    // 同期権限チェック（編集権限とは別）
    final canSync = await GroupFirestoreService.canSyncDataType(
      groupId: groupId,
      dataType: 'work_progress',
    );

    if (!canSync) {
      throw Exception('作業進捗記録の同期権限がありません');
    }

    await GroupFirestoreService.syncGroupData(
      groupId: groupId,
      dataType: 'work_progress',
      data: workProgressData,
    );
  }

  /// グループの作業進捗記録を取得
  static Future<Map<String, dynamic>?> getGroupWorkProgress(
    String groupId,
  ) async {
    return await GroupFirestoreService.getGroupData(
      groupId: groupId,
      dataType: 'work_progress',
    );
  }

  /// グループの作業進捗記録の変更を監視
  static Stream<Map<String, dynamic>?> watchGroupWorkProgress(String groupId) {
    return GroupFirestoreService.watchGroupData(
      groupId: groupId,
      dataType: 'work_progress',
    );
  }

  /// グループのアプリ設定を同期
  static Future<void> syncAppSettings(
    String groupId,
    Map<String, dynamic> appSettingsData,
  ) async {
    // 同期権限チェック（編集権限とは別）
    final canSync = await GroupFirestoreService.canSyncDataType(
      groupId: groupId,
      dataType: 'app_settings',
    );

    if (!canSync) {
      throw Exception('アプリ設定の同期権限がありません');
    }

    await GroupFirestoreService.syncGroupData(
      groupId: groupId,
      dataType: 'app_settings',
      data: appSettingsData,
    );
  }

  /// グループのアプリ設定を取得
  static Future<Map<String, dynamic>?> getGroupAppSettings(
    String groupId,
  ) async {
    return await GroupFirestoreService.getGroupData(
      groupId: groupId,
      dataType: 'app_settings',
    );
  }

  /// グループのゲーミフィケーションデータを同期
  static Future<void> syncGamificationData(
    String groupId,
    Map<String, dynamic> data,
  ) async {
    developer.log('GroupDataSyncService: ゲーミフィケーションデータの同期権限チェック開始');

    // 同期権限チェック
    final canSync = await GroupFirestoreService.canSyncDataType(
      groupId: groupId,
      dataType: 'gamification',
    );

    if (!canSync) {
      developer.log('GroupDataSyncService: ゲーミフィケーションデータの同期権限がありません');
      throw Exception('ゲーミフィケーションデータの同期権限がありません');
    }
    developer.log('GroupDataSyncService: ゲーミフィケーションデータの同期権限チェック完了');

    developer.log('GroupDataSyncService: ゲーミフィケーションデータをFirestoreに保存中...');
    await GamificationFirestoreService.saveGroupGamificationData(groupId, data);
    developer.log('GroupDataSyncService: ゲーミフィケーションデータの保存完了');
  }

  /// グループのゲーミフィケーションデータを取得
  static Future<Map<String, dynamic>?> getGroupGamificationData(
    String groupId,
    String userId,
  ) async {
    try {
      final data = await GamificationFirestoreService.loadGroupGamificationData(
        groupId,
        userId,
      );
      return data;
    } catch (e) {
      developer.log('グループゲーミフィケーションデータ取得エラー: $e');
      return null;
    }
  }

  /// グループメンバー全員のゲーミフィケーションデータを取得
  static Future<List<GroupGamificationProfile>> getGroupMembersGamificationData(
    String groupId,
  ) async {
    return await GamificationFirestoreService.loadGroupMembersGamificationData(
      groupId,
    );
  }

  /// グループのアプリ設定の変更を監視
  static Stream<Map<String, dynamic>?> watchGroupAppSettings(String groupId) {
    return GroupFirestoreService.watchGroupData(
      groupId: groupId,
      dataType: 'app_settings',
    );
  }

  /// グループの出勤退勤記録を同期
  static Future<void> syncAttendanceData(
    String groupId,
    Map<String, dynamic> attendanceData,
  ) async {
    // 同期権限チェック（編集権限とは別）
    final canSync = await GroupFirestoreService.canSyncDataType(
      groupId: groupId,
      dataType: 'attendance',
    );

    if (!canSync) {
      throw Exception('出勤退勤記録の同期権限がありません');
    }

    await GroupFirestoreService.syncGroupData(
      groupId: groupId,
      dataType: 'attendance',
      data: attendanceData,
    );
  }

  /// グループの出勤退勤記録を取得
  static Future<Map<String, dynamic>?> getGroupAttendanceData(
    String groupId,
  ) async {
    return await GroupFirestoreService.getGroupData(
      groupId: groupId,
      dataType: 'attendance',
    );
  }

  /// グループの出勤退勤記録の変更を監視
  static Stream<Map<String, dynamic>?> watchGroupAttendanceData(
    String groupId,
  ) {
    return GroupFirestoreService.watchGroupData(
      groupId: groupId,
      dataType: 'attendance',
    );
  }

  /// 全データをグループに同期
  static Future<void> syncAllDataToGroup(String groupId) async {
    developer.log(
      'GroupDataSyncService: syncAllDataToGroup 開始 - groupId: $groupId',
    );

    if (_uid == null || _uid!.isEmpty) {
      throw Exception('未ログイン');
    }

    developer.log('GroupDataSyncService: データ同期は全メンバーで可能です');

    // 焙煎記録を同期
    developer.log('GroupDataSyncService: 焙煎記録の同期を開始');
    final roastRecordsSnapshot = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('roast_records')
        .get();

    developer.log(
      'GroupDataSyncService: 焙煎記録数: ${roastRecordsSnapshot.docs.length}',
    );
    final roastRecords = roastRecordsSnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    developer.log('GroupDataSyncService: 焙煎記録をグループに同期中...');
    await syncRoastRecords(groupId, {'records': roastRecords});
    developer.log('GroupDataSyncService: 焙煎記録の同期完了');

    final today = DateTime.now();
    final todoDocId =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final todoDoc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('todoList')
        .doc(todoDocId)
        .get();

    if (todoDoc.exists) {
      await syncTodoList(groupId, todoDoc.data()!);
    }

    // ドリップカウンター記録の同期は削除（新しいグループではsharedData/drip_counter_recordsのみを使用）

    // 担当表を同期
    final assignmentDoc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('assignmentMembers')
        .doc('assignment')
        .get();

    if (assignmentDoc.exists) {
      await syncAssignmentBoard(groupId, assignmentDoc.data()!);
    }

    // スケジュールを同期
    final scheduleDoc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('schedules')
        .doc(todoDocId)
        .get();

    if (scheduleDoc.exists) {
      await syncSchedule(groupId, scheduleDoc.data()!);
    }

    // 本日のスケジュールを同期
    developer.log('GroupDataSyncService: 本日のスケジュール同期を開始');
    final todayScheduleDoc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('todaySchedule')
        .doc(todoDocId)
        .get();

    developer.log(
      'GroupDataSyncService: 本日のスケジュールドキュメント存在: ${todayScheduleDoc.exists}',
    );
    if (todayScheduleDoc.exists) {
      developer.log(
        'GroupDataSyncService: 本日のスケジュールデータ: ${todayScheduleDoc.data()}',
      );
      await syncTodaySchedule(groupId, todayScheduleDoc.data()!);
      developer.log('GroupDataSyncService: 本日のスケジュール同期完了');
    } else {
      developer.log('GroupDataSyncService: 本日のスケジュールドキュメントが存在しません');
    }

    // 時間ラベルを同期
    developer.log('GroupDataSyncService: 時間ラベル同期を開始');
    final timeLabelsDoc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('labels')
        .doc('timeLabels')
        .get();

    developer.log(
      'GroupDataSyncService: 時間ラベルドキュメント存在: ${timeLabelsDoc.exists}',
    );
    if (timeLabelsDoc.exists) {
      developer.log('GroupDataSyncService: 時間ラベルデータ: ${timeLabelsDoc.data()}');
      await syncTimeLabels(groupId, timeLabelsDoc.data()!);
      developer.log('GroupDataSyncService: 時間ラベル同期完了');
    } else {
      developer.log('GroupDataSyncService: 時間ラベルドキュメントが存在しません');
    }

    // 出勤退勤記録を同期
    developer.log('GroupDataSyncService: 出勤退勤記録同期を開始');
    final todayDate = DateTime.now();
    final todayKey =
        '${todayDate.year}-${todayDate.month.toString().padLeft(2, '0')}-${todayDate.day.toString().padLeft(2, '0')}';
    final attendanceDoc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('attendance')
        .doc(todayKey)
        .get();

    developer.log(
      'GroupDataSyncService: 出勤退勤記録ドキュメント存在: ${attendanceDoc.exists}',
    );
    if (attendanceDoc.exists) {
      developer.log('GroupDataSyncService: 出勤退勤記録データ: ${attendanceDoc.data()}');
      await syncAttendanceData(groupId, {todayKey: attendanceDoc.data()!});
      developer.log('GroupDataSyncService: 出勤退勤記録同期完了');
    } else {
      developer.log('GroupDataSyncService: 出勤退勤記録ドキュメントが存在しません');
    }

    // 今日の担当履歴を同期
    developer.log('GroupDataSyncService: 今日の担当履歴同期を開始');
    final todayAssignmentDoc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('assignmentHistory')
        .doc(todayKey)
        .get();

    developer.log(
      'GroupDataSyncService: 今日の担当履歴ドキュメント存在: ${todayAssignmentDoc.exists}',
    );
    if (todayAssignmentDoc.exists) {
      developer.log(
        'GroupDataSyncService: 今日の担当履歴データ: ${todayAssignmentDoc.data()}',
      );
      await syncTodayAssignment(groupId, todayAssignmentDoc.data()!);
      developer.log('GroupDataSyncService: 今日の担当履歴同期完了');
    } else {
      developer.log('GroupDataSyncService: 今日の担当履歴ドキュメントが存在しません');
    }

    // 担当履歴を同期
    developer.log('GroupDataSyncService: 担当履歴同期を開始');
    final assignmentHistorySnapshot = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('assignmentHistory')
        .get();

    developer.log(
      'GroupDataSyncService: 担当履歴数: ${assignmentHistorySnapshot.docs.length}',
    );
    final assignmentHistory = <String, dynamic>{};
    for (final doc in assignmentHistorySnapshot.docs) {
      assignmentHistory[doc.id] = doc.data();
    }

    if (assignmentHistory.isNotEmpty) {
      developer.log('GroupDataSyncService: 担当履歴データ: $assignmentHistory');
      await syncAssignmentHistory(groupId, assignmentHistory);
      developer.log('GroupDataSyncService: 担当履歴同期完了');
    } else {
      developer.log('GroupDataSyncService: 担当履歴データがありません');
    }

    // テイスティング記録を同期
    developer.log('GroupDataSyncService: テイスティング記録同期を開始');
    final tastingRecordsSnapshot = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('tasting_records')
        .get();

    developer.log(
      'GroupDataSyncService: テイスティング記録数: ${tastingRecordsSnapshot.docs.length}',
    );
    final tastingRecords = tastingRecordsSnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    if (tastingRecords.isNotEmpty) {
      developer.log('GroupDataSyncService: テイスティング記録をグループに同期中...');
      await syncTastingRecords(groupId, {'records': tastingRecords});
      developer.log('GroupDataSyncService: テイスティング記録の同期完了');
    } else {
      developer.log('GroupDataSyncService: テイスティング記録データがありません');
    }

    // 作業進捗記録を同期
    developer.log('GroupDataSyncService: 作業進捗記録同期を開始');
    final workProgressSnapshot = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('work_progress')
        .get();

    developer.log(
      'GroupDataSyncService: 作業進捗記録数: ${workProgressSnapshot.docs.length}',
    );
    final workProgressRecords = workProgressSnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    if (workProgressRecords.isNotEmpty) {
      developer.log('GroupDataSyncService: 作業進捗記録をグループに同期中...');
      await syncWorkProgress(groupId, {'records': workProgressRecords});
      developer.log('GroupDataSyncService: 作業進捗記録の同期完了');
    } else {
      developer.log('GroupDataSyncService: 作業進捗記録データがありません');
    }

    // アプリ設定を同期
    developer.log('GroupDataSyncService: アプリ設定同期を開始');
    final appSettings = await _getAllAppSettingsFromUser();
    if (appSettings.isNotEmpty) {
      developer.log('GroupDataSyncService: アプリ設定をグループに同期中...');
      await syncAppSettings(groupId, appSettings);
      developer.log('GroupDataSyncService: アプリ設定の同期完了');
    } else {
      developer.log('GroupDataSyncService: アプリ設定データがありません');
    }

    // ゲーミフィケーションデータを同期
    try {
      developer.log('GroupDataSyncService: ゲーミフィケーションデータ同期を開始');
      // 個人レベルシステムは削除されたため、グループゲーミフィケーションのみを使用
      return;
      // 個人レベルシステムは削除されたため、グループゲーミフィケーションのみを使用
    } catch (e) {
      developer.log('GroupDataSyncService: ゲーミフィケーションデータ同期エラー: $e');
    }
  }

  /// ユーザーの全アプリ設定を取得
  static Future<Map<String, dynamic>> _getAllAppSettingsFromUser() async {
    final appSettings = <String, dynamic>{};

    try {
      // 音声設定
      final soundDoc = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('sound')
          .get();
      if (soundDoc.exists) {
        appSettings['sound'] = soundDoc.data();
      }

      // フォントサイズ設定
      final fontSizeDoc = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('font_size')
          .get();
      if (fontSizeDoc.exists) {
        appSettings['font_size'] = fontSizeDoc.data();
      }

      // パスコード設定
      final passcodeDoc = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('passcode')
          .get();
      if (passcodeDoc.exists) {
        appSettings['passcode'] = passcodeDoc.data();
      }

      final todoNotificationDoc = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('todo_notifications')
          .get();
      if (todoNotificationDoc.exists) {
        appSettings['todo_notifications'] = todoNotificationDoc.data();
      }

      return appSettings;
    } catch (e, st) {
      developer.log(
        'GroupDataSyncService: アプリ設定取得エラー',
        error: e,
        stackTrace: st,
      );
      return {};
    }
  }

  /// グループから全データを取得
  static Future<Map<String, dynamic>> getAllDataFromGroup(
    String groupId,
  ) async {
    final data = <String, dynamic>{};

    try {
      // 各データタイプを並行して取得
      final futures = await Future.wait([
        getGroupRoastRecords(groupId),
        getGroupTodoList(groupId),
        getGroupDripCounterRecords(groupId),
        getGroupAssignmentBoard(groupId),
        getGroupSchedule(groupId),
        getGroupTodaySchedule(groupId),
        getGroupTimeLabels(groupId),
        getGroupSettings(groupId),
        getGroupTodayAssignment(groupId),
        getGroupAssignmentHistory(groupId),
        getGroupTastingRecords(groupId),
        getGroupWorkProgress(groupId),
        getGroupAppSettings(groupId),
        getGroupMembersGamificationData(groupId),
        getGroupAttendanceData(groupId),
      ]);

      data['roast_records'] = futures[0];
      data['todo_list'] = futures[1];
      data['drip_counter_records'] = futures[2];
      data['assignment_board'] = futures[3];
      data['schedule'] = futures[4];
      data['today_schedule'] = futures[5];
      data['time_labels'] = futures[6];
      data['settings'] = futures[7];
      data['today_assignment'] = futures[8];
      data['assignment_history'] = futures[9];
      data['tasting_records'] = futures[10];
      data['work_progress'] = futures[11];
      data['app_settings'] = futures[12];
      data['gamification'] = futures[13];
      data['attendance'] = futures[14];

      return data;
    } catch (e) {
      throw Exception('データの取得に失敗しました: $e');
    }
  }

  /// グループデータをローカルに適用
  static Future<void> applyGroupDataToLocal(String groupId) async {
    developer.log(
      'GroupDataSyncService: applyGroupDataToLocal 開始 - groupId: $groupId',
    );
    if (_uid == null) throw Exception('未ログイン');

    try {
      final groupData = await getAllDataFromGroup(groupId);
      developer.log(
        'GroupDataSyncService: 取得したグループデータ: ${groupData.keys.toList()}',
      );

      // 焙煎記録を適用
      if (groupData['roast_records'] != null) {
        final records = groupData['roast_records']['records'] as List<dynamic>?;
        if (records != null) {
          for (final record in records) {
            await _firestore
                .collection('users')
                .doc(_uid)
                .collection('roast_records')
                .doc(record['id'])
                .set(record, SetOptions(merge: true));
          }
        }
      }

      if (groupData['todo_list'] != null) {
        final today = DateTime.now();
        final todoDocId =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        await _firestore
            .collection('users')
            .doc(_uid)
            .collection('todoList')
            .doc(todoDocId)
            .set(groupData['todo_list'], SetOptions(merge: true));
      }

      // ドリップカウンター記録の適用は削除（新しいグループではsharedData/drip_counter_recordsのみを使用）

      // 担当表を適用
      if (groupData['assignment_board'] != null) {
        await _firestore
            .collection('users')
            .doc(_uid)
            .collection('assignmentMembers')
            .doc('assignment')
            .set(groupData['assignment_board'], SetOptions(merge: true));
      }

      // スケジュールを適用
      if (groupData['schedule'] != null) {
        final today = DateTime.now();
        final scheduleDocId =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        await _firestore
            .collection('users')
            .doc(_uid)
            .collection('schedules')
            .doc(scheduleDocId)
            .set(groupData['schedule'], SetOptions(merge: true));
      }

      // 本日のスケジュールを適用
      developer.log('GroupDataSyncService: 本日のスケジュール適用チェック');
      if (groupData['today_schedule'] != null) {
        developer.log(
          'GroupDataSyncService: 本日のスケジュールデータを適用中: ${groupData['today_schedule']}',
        );
        final today = DateTime.now();
        final todayScheduleDocId =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        await _firestore
            .collection('users')
            .doc(_uid)
            .collection('todaySchedule')
            .doc(todayScheduleDocId)
            .set(groupData['today_schedule'], SetOptions(merge: true));
        developer.log('GroupDataSyncService: 本日のスケジュール適用完了');
      } else {
        developer.log('GroupDataSyncService: 本日のスケジュールデータがありません');
      }

      // 時間ラベルを適用
      developer.log('GroupDataSyncService: 時間ラベル適用チェック');
      if (groupData['time_labels'] != null) {
        developer.log(
          'GroupDataSyncService: 時間ラベルデータを適用中: ${groupData['time_labels']}',
        );
        await _firestore
            .collection('users')
            .doc(_uid)
            .collection('labels')
            .doc('timeLabels')
            .set(groupData['time_labels'], SetOptions(merge: true));
        developer.log('GroupDataSyncService: 時間ラベル適用完了');
      } else {
        developer.log('GroupDataSyncService: 時間ラベルデータがありません');
      }

      // 今日の担当履歴を適用
      developer.log('GroupDataSyncService: 今日の担当履歴適用チェック');
      if (groupData['today_assignment'] != null) {
        developer.log(
          'GroupDataSyncService: 今日の担当履歴データを適用中: ${groupData['today_assignment']}',
        );
        final today = DateTime.now();
        final todayKey =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        await _firestore
            .collection('users')
            .doc(_uid)
            .collection('assignmentHistory')
            .doc(todayKey)
            .set(groupData['today_assignment'], SetOptions(merge: true));
        developer.log('GroupDataSyncService: 今日の担当履歴適用完了');
      } else {
        developer.log('GroupDataSyncService: 今日の担当履歴データがありません');
      }

      // 担当履歴を適用
      developer.log('GroupDataSyncService: 担当履歴適用チェック');
      if (groupData['assignment_history'] != null) {
        developer.log(
          'GroupDataSyncService: 担当履歴データを適用中: ${groupData['assignment_history']}',
        );
        final assignmentHistory =
            groupData['assignment_history'] as Map<String, dynamic>;
        for (final entry in assignmentHistory.entries) {
          final dateKey = entry.key;
          final historyData = entry.value as Map<String, dynamic>;
          await _firestore
              .collection('users')
              .doc(_uid)
              .collection('assignmentHistory')
              .doc(dateKey)
              .set(historyData, SetOptions(merge: true));
        }
        developer.log('GroupDataSyncService: 担当履歴適用完了');
      } else {
        developer.log('GroupDataSyncService: 担当履歴データがありません');
      }

      // テイスティング記録を適用
      developer.log('GroupDataSyncService: テイスティング記録適用チェック');
      if (groupData['tasting_records'] != null) {
        developer.log(
          'GroupDataSyncService: テイスティング記録データを適用中: ${groupData['tasting_records']}',
        );
        final records =
            groupData['tasting_records']['records'] as List<dynamic>?;
        if (records != null) {
          for (final record in records) {
            await _firestore
                .collection('users')
                .doc(_uid)
                .collection('tasting_records')
                .doc(record['id'])
                .set(record, SetOptions(merge: true));
          }
        }
        developer.log('GroupDataSyncService: テイスティング記録適用完了');
      } else {
        developer.log('GroupDataSyncService: テイスティング記録データがありません');
      }

      // 作業進捗記録を適用
      developer.log('GroupDataSyncService: 作業進捗記録適用チェック');
      if (groupData['work_progress'] != null) {
        developer.log(
          'GroupDataSyncService: 作業進捗記録データを適用中: ${groupData['work_progress']}',
        );
        final records = groupData['work_progress']['records'] as List<dynamic>?;
        if (records != null) {
          for (final record in records) {
            await _firestore
                .collection('users')
                .doc(_uid)
                .collection('work_progress')
                .doc(record['id'])
                .set(record, SetOptions(merge: true));
          }
        }
        developer.log('GroupDataSyncService: 作業進捗記録適用完了');
      } else {
        developer.log('GroupDataSyncService: 作業進捗記録データがありません');
      }

      // 出勤退勤記録を適用
      developer.log('GroupDataSyncService: 出勤退勤記録適用チェック');
      if (groupData['attendance'] != null) {
        developer.log(
          'GroupDataSyncService: 出勤退勤記録データを適用中: ${groupData['attendance']}',
        );
        final attendanceData = groupData['attendance'] as Map<String, dynamic>;
        for (final entry in attendanceData.entries) {
          final dateKey = entry.key;
          final dateData = entry.value as Map<String, dynamic>;
          await _firestore
              .collection('users')
              .doc(_uid)
              .collection('attendance')
              .doc(dateKey)
              .set(dateData, SetOptions(merge: true));
        }
        developer.log('GroupDataSyncService: 出勤退勤記録適用完了');
      } else {
        developer.log('GroupDataSyncService: 出勤退勤記録データがありません');
      }

      // アプリ設定を適用
      developer.log('GroupDataSyncService: アプリ設定適用チェック');
      if (groupData['app_settings'] != null) {
        developer.log(
          'GroupDataSyncService: アプリ設定データを適用中: ${groupData['app_settings']}',
        );
        final appSettings = groupData['app_settings'] as Map<String, dynamic>;

        // 音声設定
        if (appSettings['sound'] != null) {
          await _firestore
              .collection('users')
              .doc(_uid)
              .collection('settings')
              .doc('sound')
              .set(appSettings['sound'], SetOptions(merge: true));
        }

        // フォントサイズ設定
        if (appSettings['font_size'] != null) {
          await _firestore
              .collection('users')
              .doc(_uid)
              .collection('settings')
              .doc('font_size')
              .set(appSettings['font_size'], SetOptions(merge: true));
        }

        // パスコード設定
        if (appSettings['passcode'] != null) {
          await _firestore
              .collection('users')
              .doc(_uid)
              .collection('settings')
              .doc('passcode')
              .set(appSettings['passcode'], SetOptions(merge: true));
        }

        if (appSettings['todo_notifications'] != null) {
          await _firestore
              .collection('users')
              .doc(_uid)
              .collection('settings')
              .doc('todo_notifications')
              .set(appSettings['todo_notifications'], SetOptions(merge: true));
        }

        developer.log('GroupDataSyncService: アプリ設定適用完了');
      } else {
        developer.log('GroupDataSyncService: アプリ設定データがありません');
      }
    } catch (e) {
      throw Exception('ローカルデータの適用に失敗しました: $e');
    }
  }
}
