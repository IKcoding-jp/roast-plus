import '../settings/assignment_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:roastplus/pages/members/member_edit_page.dart';
import 'package:roastplus/pages/labels/label_edit_page.dart';
import 'package:roastplus/pages/history/assignment_history_page.dart';
import 'dart:math';
import '../../services/assignment_firestore_service.dart';
import '../../services/group_firestore_service.dart';
import '../../services/group_data_sync_service.dart';
import '../../services/attendance_firestore_service.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../models/dashboard_stats_provider.dart';
import '../../models/attendance_models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:roastplus/utils/app_performance_config.dart';
import '../../services/user_settings_firestore_service.dart';
import '../../services/first_login_service.dart';
import '../../widgets/lottie_animation_widget.dart';
import 'package:lottie/lottie.dart';

class AssignmentBoard extends StatefulWidget {
  const AssignmentBoard({super.key});

  @override
  State<AssignmentBoard> createState() => AssignmentBoardState();
}

class AssignmentBoardState extends State<AssignmentBoard> {
  late SharedPreferences prefs;
  bool _isLoading = true;
  bool _isDataInitialized = false; // データ初期化完了フラグ
  bool _isRemoteSyncCompleted = false; // リモート同期完了フラグ
  bool? _canEditAssignment; // null: 未判定, true/false: 判定済み

  List<Team> teams = [];
  List<String> leftLabels = [];
  List<String> rightLabels = [];

  bool isShuffling = false;
  bool isAssignedToday = false;
  bool isDeveloperMode = false;
  Timer? shuffleTimer;

  // 出勤退勤機能用
  List<AttendanceRecord> _todayAttendance = [];

  // グループ同期用
  StreamSubscription<Map<String, dynamic>?>? _groupAssignmentSubscription;
  StreamSubscription<GroupSettings?>? _groupSettingsSubscription;
  StreamSubscription<Map<String, dynamic>?>? _groupTodayAssignmentSubscription;
  StreamSubscription<Map<String, dynamic>>? _developerModeSubscription;
  StreamSubscription<List<AttendanceRecord>>? _groupAttendanceSubscription;
  StreamSubscription<dynamic>? _displayNameSubscription;
  Timer? _autoSyncTimer;

  /// 安全な文字列リスト変換
  List<String> _safeStringListFromDynamic(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      try {
        return data.map((item) => item?.toString() ?? '').toList();
      } catch (e) {
        debugPrint('AssignmentBoard: リスト変換エラー: $e, data: $data');
        return [];
      }
    }
    debugPrint('AssignmentBoard: 予期しないデータ型: ${data.runtimeType}, data: $data');
    return [];
  }

  /// グループデータとローカルデータをマージ（publicメソッド）
  void mergeGroupDataWithLocal(Map<String, dynamic> groupAssignmentData) {
    _mergeGroupDataWithLocal(groupAssignmentData);
  }

  /// グループデータとローカルデータをマージ（ローカルデータ優先）
  void _mergeGroupDataWithLocal(
    Map<String, dynamic> groupAssignmentData,
  ) async {
    if (!mounted) return;
    debugPrint('AssignmentBoard: グループデータとローカルデータをマージ開始');
    debugPrint('AssignmentBoard: 受信データ: $groupAssignmentData');

    // グループメンバーの有効性をチェックしてクリーンアップ
    await _cleanupInvalidMembers();

    // 今日の担当が既に決定されているかチェック
    final today = _todayKey();
    final todayAssignedPairs = await UserSettingsFirestoreService.getSetting(
      'assignment_$today',
    );
    final savedDate = await UserSettingsFirestoreService.getSetting(
      'assignedDate',
    );
    final lastResetDate = await UserSettingsFirestoreService.getSetting(
      'lastResetDate',
    );

    final hasTodayAssignment =
        todayAssignedPairs != null &&
        todayAssignedPairs is List &&
        todayAssignedPairs.isNotEmpty &&
        savedDate == today &&
        lastResetDate != today;

    debugPrint(
      'AssignmentBoard: 今日の担当状態チェック - hasTodayAssignment: $hasTodayAssignment',
    );

    // データを一旦変数に格納してから一括更新
    List<Team> newTeams = [];
    List<String> newLeftLabels = leftLabels;
    List<String> newRightLabels = rightLabels;

    // 新しい形式（teams）または古い形式（aMembers, bMembers）に対応
    if (groupAssignmentData['teams'] != null) {
      final teamsList = groupAssignmentData['teams'] as List;
      newTeams = teamsList.map((teamMap) => Team.fromMap(teamMap)).toList();
    } else {
      // 古い形式の場合は新しい形式に変換
      final aMembers = _safeStringListFromDynamic(
        groupAssignmentData['aMembers'],
      );
      final bMembers = _safeStringListFromDynamic(
        groupAssignmentData['bMembers'],
      );
      newTeams = [
        Team(id: 'team_a', name: 'A班', members: aMembers),
        Team(id: 'team_b', name: 'B班', members: bMembers),
      ];
    }

    // グループ状態では、グループデータを完全に使用（ローカルデータは保持しない）
    newLeftLabels = _safeStringListFromDynamic(
      groupAssignmentData['leftLabels'],
    );
    newRightLabels = _safeStringListFromDynamic(
      groupAssignmentData['rightLabels'],
    );

    // 今日の担当が決定済みの場合は、基本構成を今日の担当で上書き
    if (hasTodayAssignment) {
      debugPrint('AssignmentBoard: 今日の担当決定済み - 基本構成に担当データを適用');
      try {
        final assignedPairs = todayAssignedPairs;
        if (assignedPairs.length == newLeftLabels.length &&
            newTeams.length >= 2) {
          // 基本構成を今日の担当で上書き
          for (int i = 0; i < newTeams.length; i++) {
            final newTeamMembers = assignedPairs
                .map((e) => e.toString().split('-')[i])
                .toList();
            newTeams[i] = newTeams[i].copyWith(members: newTeamMembers);
          }
          debugPrint('AssignmentBoard: 基本構成に今日の担当を適用完了');
        }
      } catch (e) {
        debugPrint('AssignmentBoard: 今日の担当適用エラー: $e');
      }
    }

    // ローカルデータが既に存在する場合は更新をスキップ（ちらつき防止）
    if (mounted) {
      // ローカルデータが空の場合のみ更新
      if (teams.isEmpty && leftLabels.isEmpty) {
        setState(() {
          teams = newTeams;
          leftLabels = newLeftLabels;
          rightLabels = newRightLabels;
          _isLoading = false;
          _isDataInitialized = true;
          // 担当決定状態も同時に更新
          if (hasTodayAssignment) {
            isAssignedToday = true;
          }
        });
        debugPrint('AssignmentBoard: ローカルデータが空のため、グループデータで更新');
      } else {
        debugPrint('AssignmentBoard: ローカルデータが存在するため、グループデータの更新をスキップ');
      }
    }

    // グループ状態でない場合のみローカルデータを更新
    if (mounted) {
      final groupProvider = context.read<GroupProvider>();
      if (!groupProvider.hasGroup) {
        _updateLocalData();
      }
    }

    // マージ完了
  }

  /// 無効なメンバーをクリーンアップ
  Future<void> _cleanupInvalidMembers() async {
    try {
      final groupProvider = context.read<GroupProvider>();
      if (!groupProvider.hasGroup) return;

      // 有効なグループメンバー名のリストを作成
      final validMemberNames = groupProvider.currentGroup!.members
          .map((m) => m.displayName)
          .toSet();

      bool hasChanges = false;
      List<Team> cleanedTeams = [];

      for (final team in teams) {
        final validMembers = <String>[];

        for (final memberName in team.members) {
          if (validMemberNames.contains(memberName)) {
            validMembers.add(memberName);
          } else {
            hasChanges = true;
            // 無効なメンバー名を削除
          }
        }

        cleanedTeams.add(team.copyWith(members: validMembers));
      }

      if (hasChanges) {
        setState(() {
          teams = cleanedTeams;
        });
        // メンバーデータのクリーンアップ完了

        // クリーンアップ後のデータを保存
        await _updateLocalData();
      }
    } catch (e) {
      debugPrint('AssignmentBoard: メンバークリーンアップエラー: $e');
    }
  }

  /// 強制クリーンアップ（古いデータを完全に削除）
  Future<void> _forceCleanupAllOldData() async {
    try {
      // 強制クリーンアップ開始

      final groupProvider = context.read<GroupProvider>();
      if (!groupProvider.hasGroup) return;

      // 有効なグループメンバー名のリストを作成
      final validMemberNames = groupProvider.currentGroup!.members
          .map((m) => m.displayName)
          .toSet();

      bool hasChanges = false;
      List<Team> cleanedTeams = [];

      for (final team in teams) {
        final validMembers = <String>[];

        for (final memberName in team.members) {
          if (validMemberNames.contains(memberName)) {
            validMembers.add(memberName);
          } else {
            hasChanges = true;
            // 強制クリーンアップ: 無効なメンバー名を削除
          }
        }

        cleanedTeams.add(team.copyWith(members: validMembers));
      }

      if (hasChanges) {
        setState(() {
          teams = cleanedTeams;
        });
        // 強制クリーンアップ完了

        // クリーンアップ後のデータを保存
        await _updateLocalData();

        // Firestoreにも保存
        try {
          final teamsJson = jsonEncode(
            teams.map((team) => team.toMap()).toList(),
          );
          await UserSettingsFirestoreService.saveMultipleSettings({
            'teams': teamsJson,
            'leftLabels': leftLabels,
            'rightLabels': rightLabels,
          });

          // 後方互換性のため、最初の2つの班をA班、B班としても保存
          if (teams.isNotEmpty) {
            await UserSettingsFirestoreService.saveMultipleSettings({
              'assignment_team_a': teams[0].members,
              'assignment_team_b': teams.length > 1 ? teams[1].members : [],
            });
          }

          debugPrint('AssignmentBoard: Firestoreデータ更新完了');
        } catch (e) {
          debugPrint('AssignmentBoard: Firestoreデータ更新エラー: $e');
        }
      } else {
        // 強制クリーンアップ: 変更なし
      }
    } catch (e) {
      debugPrint('AssignmentBoard: 強制クリーンアップエラー: $e');
    }
  }

  /// ローカルデータを更新
  Future<void> _updateLocalData() async {
    try {
      // グループ状態の場合はローカルデータを保存しない
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.hasGroup) {
        // グループ状態のため、ローカルデータ保存をスキップ
        return;
      }

      // 新しい形式で保存
      final teamsJson = jsonEncode(teams.map((team) => team.toMap()).toList());
      await UserSettingsFirestoreService.saveMultipleSettings({
        'teams': teamsJson,
        'leftLabels': leftLabels,
        'rightLabels': rightLabels,
      });

      // 後方互換性のため、最初の2つの班をA班、B班としても保存
      if (teams.isNotEmpty) {
        await UserSettingsFirestoreService.saveMultipleSettings({
          'assignment_team_a': teams[0].members,
          'assignment_team_b': teams.length > 1 ? teams[1].members : [],
        });
      }

      debugPrint('AssignmentBoard: Firebaseデータ更新完了');
    } catch (e) {
      debugPrint('AssignmentBoard: Firebaseデータ更新エラー: $e');
    }
  }

  void setAssignmentHistoryFromFirestore(List<String> history) async {
    if (!mounted) return;

    final today = _todayKey();
    bool shouldUpdateState = false;
    bool newAssignedStatus = false;

    // 今日の担当履歴設定開始

    if (history.isNotEmpty &&
        history.length == leftLabels.length &&
        teams.length >= 2) {
      try {
        // 履歴を各チームに分配
        List<Team> updatedTeams = [];
        for (int i = 0; i < teams.length; i++) {
          final teamMembers = history.map((e) => e.split('-')[i]).toList();
          updatedTeams.add(teams[i].copyWith(members: teamMembers));
        }

        // グループ状態でない場合のみローカルに保存
        final groupProvider = context.read<GroupProvider>();
        if (!groupProvider.hasGroup) {
          UserSettingsFirestoreService.saveMultipleSettings({
            'assignment_$today': history,
            'assignedDate': today,
            'lastResetDate': null, // リセット状態をクリア
            'resetVerified': false,
          });
        }

        if (mounted) {
          setState(() {
            teams = updatedTeams;
            isAssignedToday = true;
          });
        }

        // グループから今日の担当履歴を受信・適用完了
      } catch (e) {
        debugPrint('AssignmentBoard: 履歴データ適用エラー: $e');
        shouldUpdateState = true;
        newAssignedStatus = false;
      }
    } else {
      // 履歴が空または無効な場合は決定済みフラグをリセット
      shouldUpdateState = true;
      newAssignedStatus = false;
      // 履歴データが無効または空 - 決定済みフラグをリセット

      // 状態変更が必要かつ値が変わる場合のみsetStateを呼ぶ
      if (shouldUpdateState && isAssignedToday != newAssignedStatus) {
        setState(() {
          isAssignedToday = newAssignedStatus;
        });
      }
    }
  }

  void setAssignmentMembersFromFirestore(
    Map<String, dynamic> assignmentMembers,
  ) {
    if (mounted) {
      setState(() {
        // 新しい形式（teams）または古い形式（aMembers, bMembers）に対応
        if (assignmentMembers['teams'] != null) {
          final teamsList = assignmentMembers['teams'] as List;
          teams = teamsList.map((teamMap) => Team.fromMap(teamMap)).toList();
        } else {
          // 古い形式の場合は新しい形式に変換
          final aMembers = _safeStringListFromDynamic(
            assignmentMembers['aMembers'],
          );
          final bMembers = _safeStringListFromDynamic(
            assignmentMembers['bMembers'],
          );
          teams = [
            Team(id: 'team_a', name: 'A班', members: aMembers),
            Team(id: 'team_b', name: 'B班', members: bMembers),
          ];
        }

        // ラベルデータも更新
        leftLabels = _safeStringListFromDynamic(
          assignmentMembers['leftLabels'],
        );
        rightLabels = _safeStringListFromDynamic(
          assignmentMembers['rightLabels'],
        );
      });
    }
  }

  @override
  void initState() {
    super.initState();

    // 読み込み状態を開始
    _isLoading = true;
    _isDataInitialized = false;
    _isRemoteSyncCompleted = false;

    // 権限の初期値を設定（グループ未参加時は編集可能・担当決定可能）
    _canEditAssignment = true;

    // まずローカルデータを読み込み（ラベルを確実に保持）
    _loadLocalDataFirst();

    _loadTodayAttendance();
    _initializeGroupMonitoring();
    _loadDeveloperMode();
    _startDeveloperModeListener();
    _startDisplayNameMonitoring();

    // 初期権限チェックを実行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkEditPermission();
    });

    // 初期化後に強制クリーンアップを実行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _forceCleanupAllOldData();
    });
  }

  /// ローカルデータを最初に読み込み（常に実行）
  Future<void> _loadLocalDataFirst() async {
    if (!mounted) return;
    try {
      // ローカルデータ読み込み開始
      debugPrint('AssignmentBoard: ローカルデータ読み込み開始');

      final settings = await UserSettingsFirestoreService.getMultipleSettings([
        'teams',
        'leftLabels',
        'rightLabels',
        'assignment_team_a',
        'assignment_team_b',
      ]);

      // 新しい形式で班データを読み込み
      List<Team> loadedTeams = [];
      final teamsJson = settings['teams'];
      if (teamsJson != null) {
        final teamsList = jsonDecode(teamsJson) as List;
        loadedTeams = teamsList
            .map((teamMap) => Team.fromMap(teamMap))
            .toList();
      } else {
        // 既存のA班、B班データを新しい形式に変換
        final loadedA = settings['assignment_team_a'] ?? [];
        final loadedB = settings['assignment_team_b'] ?? [];
        loadedTeams = [
          Team(id: 'team_a', name: 'A班', members: loadedA),
          Team(id: 'team_b', name: 'B班', members: loadedB),
        ];
      }

      // ラベルデータを確実に読み込み
      final loadedLeftLabels = settings['leftLabels'] ?? [];
      final loadedRightLabels = settings['rightLabels'] ?? [];

      // ローカルデータ読み込み完了

      // 今日の担当があるかチェック
      final today = _todayKey();
      final todayAssignedPairs = await UserSettingsFirestoreService.getSetting(
        'assignment_$today',
      );
      final savedDate = await UserSettingsFirestoreService.getSetting(
        'assignedDate',
      );
      final lastResetDate = await UserSettingsFirestoreService.getSetting(
        'lastResetDate',
      );

      final hasTodayAssignment =
          todayAssignedPairs != null &&
          todayAssignedPairs is List &&
          todayAssignedPairs.isNotEmpty &&
          savedDate == today &&
          lastResetDate != today;

      // 今日の担当が決定済みの場合は、基本構成を今日の担当で上書き
      if (hasTodayAssignment) {
        // 今日の担当決定済み - 基本構成に担当データを適用
        try {
          final assignedPairs = todayAssignedPairs;
          if (assignedPairs.length == loadedLeftLabels.length &&
              loadedTeams.length >= 2) {
            // 基本構成を今日の担当で上書き
            for (int i = 0; i < loadedTeams.length; i++) {
              final newTeamMembers = assignedPairs
                  .map((e) => e.toString().split('-')[i])
                  .toList();
              loadedTeams[i] = loadedTeams[i].copyWith(members: newTeamMembers);
            }
            // ローカルデータに今日の担当を適用完了
          }
        } catch (e) {
          debugPrint('AssignmentBoard: ローカルデータでの今日の担当適用エラー: $e');
        }
      }

      // データを即座に表示（ちらつき防止）
      if (mounted) {
        setState(() {
          teams = loadedTeams;
          leftLabels = loadedLeftLabels;
          rightLabels = loadedRightLabels;
          _isLoading = false;
          _isDataInitialized = true;
          // 担当決定状態も同時に更新
          if (hasTodayAssignment) {
            isAssignedToday = true;
          }
        });
        // ローカルデータ読み込み完了後、バックグラウンドでFirebaseと同期
        _isRemoteSyncCompleted = false;
        _syncWithFirebaseInBackground().then((_) {
          if (mounted) {
            setState(() {
              _isRemoteSyncCompleted = true;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('AssignmentBoard: ローカルデータ読み込みエラー: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isDataInitialized = true;
        });
      }
    }
  }

  /// バックグラウンドでFirebaseと同期
  Future<void> _syncWithFirebaseInBackground() async {
    try {
      final groupProvider = context.read<GroupProvider>();

      if (groupProvider.hasGroup) {
        // グループ状態の場合、グループデータと同期
        debugPrint('AssignmentBoard: グループデータとバックグラウンド同期開始');
        await _syncWithGroupData();
      } else {
        // 個人状態の場合、Firestoreデータと同期
        debugPrint('AssignmentBoard: Firestoreデータとバックグラウンド同期開始');
        await _syncWithFirestoreData();
      }
      // 同期完了フラグを立てる（nil安全）
      if (mounted) {
        _isRemoteSyncCompleted = true;
      }
    } catch (e) {
      debugPrint('AssignmentBoard: バックグラウンド同期エラー: $e');
    }
  }

  /// Firestoreデータと同期
  Future<void> _syncWithFirestoreData() async {
    try {
      final assignmentData =
          await AssignmentFirestoreService.loadAssignmentMembers();
      if (assignmentData != null && mounted) {
        // Firestoreデータがローカルデータより新しい場合のみ更新
        final firestoreSavedAt = assignmentData['savedAt'];
        if (firestoreSavedAt != null) {
          // 必要に応じてデータを更新（ここでは簡略化）
          debugPrint('AssignmentBoard: Firestoreデータ同期完了');
        }
      }
    } catch (e) {
      debugPrint('AssignmentBoard: Firestore同期エラー: $e');
    }
  }

  /// グループデータと同期
  Future<void> _syncWithGroupData() async {
    try {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.groups.isNotEmpty) {
        final group = groupProvider.groups.first;
        final groupData = await GroupDataSyncService.getGroupAssignmentBoard(
          group.id,
        );

        if (groupData != null && mounted) {
          // グループデータがローカルデータより新しい場合のみ更新
          final groupSavedAt = groupData['savedAt'];
          if (groupSavedAt != null) {
            // 必要に応じてデータを更新（ここでは簡略化）
            debugPrint('AssignmentBoard: グループデータ同期完了');
          }
        }
      }
    } catch (e) {
      debugPrint('AssignmentBoard: グループ同期エラー: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ページ切り替え時にローディング状態を開始
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _isDataInitialized = false;
      });
    }

    // ラベルデータを再読み込み
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadLabelsOnly();
    });
  }

  /// 今日の出勤退勤記録を読み込み
  Future<void> _loadTodayAttendance() async {
    if (!mounted) return;
    try {
      // 出勤退勤記録読み込み開始

      // グループ状態の場合はグループデータを優先的に読み込み
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.hasGroup) {
        final group = groupProvider.currentGroup!;
        final today = DateTime.now();
        final dateKey =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

        // グループ出勤退勤記録読み込み開始

        final groupAttendance =
            await AttendanceFirestoreService.getGroupAttendanceData(
              group.id,
              dateKey,
            );
        if (mounted) {
          setState(() {
            _todayAttendance = groupAttendance;
          });
        }
        // グループ出勤退勤記録読み込み完了
      } else {
        // グループ状態でない場合はローカルデータを読み込み
        final attendance =
            await AttendanceFirestoreService.getTodayAttendance();
        if (mounted) {
          setState(() {
            _todayAttendance = attendance;
          });
        }
        // ローカル出勤退勤記録読み込み完了
      }
    } catch (e) {
      // 出勤退勤記録読み込みエラー
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('出勤退勤記録の読み込みに失敗しました')));
      }
    } finally {
      // ローディング状態を確実に解除
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isDataInitialized = true;
        });
      }
    }
  }

  /// メンバーの出勤退勤状態を取得
  AttendanceStatus _getMemberAttendanceStatus(String memberName) {
    final record = _todayAttendance.firstWhere(
      (r) => r.memberName == memberName,
      orElse: () => AttendanceRecord(
        memberId: '',
        memberName: memberName,
        status: AttendanceStatus.present, // デフォルトは出勤
        timestamp: DateTime.now(),
        dateKey: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      ),
    );
    return record.status;
  }

  /// メンバーの出勤退勤状態を更新
  Future<void> _updateMemberAttendance(
    String memberName,
    AttendanceStatus status,
  ) async {
    if (!mounted) return;

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // 出勤退勤状態更新開始

      // ローディング状態を設定
      setState(() {
        _isLoading = true;
        _isDataInitialized = false;
      });

      await AttendanceFirestoreService.updateMemberAttendance(
        userId,
        memberName,
        status,
      );

      // 出勤の場合、経験値を追加
      if (status == AttendanceStatus.present && mounted) {
        await _addAttendanceExperience();
      }

      // 統計データを更新
      if (mounted) {
        final statsProvider = Provider.of<DashboardStatsProvider>(
          context,
          listen: false,
        );
        await statsProvider.onAttendanceUpdated();
      }

      // 状態更新後にUIを更新
      if (!mounted) return;
      final groupProvider = context.read<GroupProvider>();
      if (!groupProvider.hasGroup) {
        // グループ状態でない場合はローカル状態を更新
        await _loadTodayAttendance();
      } else {
        // グループ状態の場合は少し待ってから再読み込み（リアルタイム同期の遅延を考慮）
        // グループ状態のため、少し待ってから再読み込みします
        await Future.delayed(Duration(milliseconds: 500));
        if (mounted) {
          await _loadTodayAttendance();
        }
      }

      // ローディング状態を解除
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isDataInitialized = true;
        });
      }
    } catch (e) {
      // 出勤退勤状態更新エラー
      // エラー時もローディング状態を解除
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isDataInitialized = true;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('出勤退勤状態の更新に失敗しました')));
      }
    }
  }

  /// 出勤記録からXPを加算
  Future<void> _addAttendanceExperience() async {
    try {
      // グループレベルシステムで出勤記録を処理
      await _processAttendanceForGroup();

      // 成果表示（グループレベルシステム用に簡略化）
      _showGroupAttendanceResult();
    } catch (e) {
      // 出勤記録処理エラー
    }
  }

  /// グループレベルシステムで出勤記録を処理
  Future<void> _processAttendanceForGroup() async {
    try {
      // グループプロバイダーを取得
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);

      if (groupProvider.hasGroup) {
        final groupId = groupProvider.currentGroup!.id;

        // グループのゲーミフィケーションシステムに通知
        await groupProvider.processGroupAttendance(groupId, context: context);
      }
    } catch (e) {
      // グループレベルシステム処理エラー
    }
  }

  /// グループレベルシステム用の出勤結果表示
  void _showGroupAttendanceResult() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('出勤記録を保存しました'), backgroundColor: Colors.green),
    );
  }

  /// グループ監視の初期化
  void _initializeGroupMonitoring() {
    if (!mounted) return;
    // グループ監視初期化開始
    // 既に監視中の場合は何もしない
    if (_groupAssignmentSubscription != null) {
      // 既にグループ監視中です
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupProvider = context.read<GroupProvider>();
      _startGroupMonitoring(groupProvider);
    });
  }

  /// グループ監視を開始
  void _startGroupMonitoring(GroupProvider groupProvider) {
    if (!mounted) return;
    // グループ監視開始

    // 既存のサブスクリプションをクリーンアップ
    _groupAssignmentSubscription?.cancel();
    _groupSettingsSubscription?.cancel();
    _groupTodayAssignmentSubscription?.cancel();
    _groupAttendanceSubscription?.cancel();

    if (groupProvider.hasGroup) {
      final group = groupProvider.currentGroup!;
      // グループ監視開始

      // グループの担当表データを監視（基本構成）
      _groupAssignmentSubscription =
          GroupDataSyncService.watchGroupAssignmentBoard(group.id).listen((
            groupAssignmentData,
          ) {
            if (!mounted) return; // ウィジェットが破棄されている場合は処理しない
            // グループ担当表データ変更検知
            if (groupAssignmentData != null) {
              // グループデータが利用可能になった場合、バックグラウンドで同期
              // ローカルデータを優先し、必要に応じて更新
              _mergeGroupDataWithLocal(groupAssignmentData);

              // グループデータ受信後にクリーンアップを実行
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _forceCleanupAllOldData();
              });
            } else {
              // グループ担当表データが空です - ローカルデータを維持
              // グループデータが空の場合は、ローカルデータを維持
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _isDataInitialized = true;
                });
              }
            }
          });

      // グループ設定を監視
      // グループ設定監視を開始
      _groupSettingsSubscription =
          GroupFirestoreService.watchGroupSettings(group.id).listen((
            groupSettings,
          ) {
            if (!mounted) return; // ウェットが破棄されている場合は処理しない
            // グループ設定変更検知

            if (groupSettings != null) {
              // グループ設定変換成功

              // グループ設定が変更されたら権限を再チェック
              _checkEditPermissionFromSettings(groupSettings, groupProvider);
            } else {
              // グループ設定データがnullです
            }
          });

      // グループの今日の担当履歴を監視
      _groupTodayAssignmentSubscription =
          GroupDataSyncService.watchGroupTodayAssignment(group.id).listen((
            groupTodayAssignmentData,
          ) {
            if (!mounted) return; // ウェットが破棄されている場合は処理しない
            // グループ今日の担当履歴変更検知

            // データがnullまたは削除された場合の処理を強化
            if (groupTodayAssignmentData == null) {
              // グループの今日の担当データが削除されました
              setAssignmentHistoryFromFirestore([]);
              return;
            }

            if (groupTodayAssignmentData['assignments'] != null) {
              final assignments = _safeStringListFromDynamic(
                groupTodayAssignmentData['assignments'],
              );
              if (assignments.isNotEmpty) {
                // グループから今日の担当データを受信 - 最優先で適用
                setAssignmentHistoryFromFirestore(assignments);
              } else {
                // グループの今日の担当データが空です
                setAssignmentHistoryFromFirestore([]);
              }
            } else {
              // グループの今日の担当履歴が削除された場合
              // グループの今日の担当履歴が削除されました
              setAssignmentHistoryFromFirestore([]);
            }
          });

      // グループの出勤退勤データをリアルタイム監視
      final today = DateTime.now();
      final dateKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      // グループ出勤退勤データ監視開始

      _groupAttendanceSubscription =
          AttendanceFirestoreService.watchGroupAttendanceData(
            group.id,
            dateKey,
          ).listen((groupAttendanceRecords) {
            if (!mounted) return;
            // グループ出勤退勤データ変更検知

            // グループの出勤退勤データをローカルに反映
            setState(() {
              _todayAttendance = groupAttendanceRecords;
            });
          });
    }
  }

  /// グループ設定から直接権限をチェック
  void _checkEditPermissionFromSettings(
    GroupSettings groupSettings,
    GroupProvider groupProvider,
  ) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('未ログインのため権限チェックをスキップ');
      setState(() {
        _canEditAssignment = false;
      });
      return;
    }

    // 権限チェック開始

    try {
      final userRole = groupProvider.currentGroup!.getMemberRole(
        currentUser.uid,
      );
      if (userRole == null) {
        // ユーザーロールが取得できません
        setState(() {
          _canEditAssignment = false;
        });
        return;
      }

      // ユーザーロール確認

      final canEdit = groupSettings.canEditDataType(
        'assignment_board',
        userRole,
      );

      // 設定変更による権限チェック

      if (mounted && _canEditAssignment != canEdit) {
        // 権限状態を更新
        setState(() {
          _canEditAssignment = canEdit;
        });
        // 権限状態を更新完了
      } else {
        // 権限状態は変更されませんでした
      }
    } catch (e) {
      debugPrint('AssignmentBoard: 設定変更による権限チェックエラー - $e');
      if (mounted) {
        setState(() {
          _canEditAssignment = false;
        });
      }
    }
  }

  /// 担当表編集権限をチェック
  Future<void> _checkEditPermission() async {
    try {
      final groupProvider = context.read<GroupProvider>();
      final groups = groupProvider.groups;

      debugPrint('AssignmentBoard: 権限チェック開始 - groups: ${groups.length}');

      // グループが存在することを前提とする
      if (groups.isNotEmpty) {
        final group = groups.first;
        debugPrint('AssignmentBoard: グループ権限チェック - groupId: ${group.id}');

        // 現在のグループ設定から直接権限を取得
        final groupSettings = await GroupFirestoreService.getGroupSettings(
          group.id,
        );
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          debugPrint('未ログインのため権限チェックをスキップ');
          setState(() {
            _canEditAssignment = false;
          });
          return;
        }
        if (groupSettings != null) {
          final userRole = group.getMemberRole(currentUser.uid);
          if (userRole != null) {
            final canEdit = groupSettings.canEditDataType(
              'assignment_board',
              userRole,
            );
            debugPrint(
              'AssignmentBoard: 初期権限チェック結果 - ユーザーロール: $userRole, 編集権限: $canEdit',
            );
            setState(() {
              _canEditAssignment = canEdit;
            });
            return;
          }
        }

        // フォールバック: 既存の方法で権限チェック
        final canEdit = await GroupFirestoreService.canEditDataType(
          groupId: group.id,
          dataType: 'assignment_board',
        );

        debugPrint('AssignmentBoard: フォールバック権限チェック結果 - canEdit: $canEdit');

        setState(() {
          _canEditAssignment = canEdit;
        });
      } else {
        // グループ未参加の場合は編集不可
        debugPrint('AssignmentBoard: グループ未参加 - 編集不可に設定');
        setState(() {
          _canEditAssignment = false;
        });
      }
    } catch (e) {
      // エラーの場合は編集不可として扱う
      debugPrint('AssignmentBoard: 権限チェックエラー - $e, 編集不可に設定');
      setState(() {
        _canEditAssignment = false;
      });
    }
  }

  /// リアルタイムで権限をチェック（Consumer内で使用）
  void _checkEditPermissionRealtime(GroupProvider groupProvider) {
    if (!mounted) return; // ウィジェットが破棄されている場合は処理しない

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('未ログインのため権限チェックをスキップ');
      setState(() {
        _canEditAssignment = false;
      });
      return;
    }

    if (groupProvider.hasGroup) {
      final group = groupProvider.currentGroup!;
      debugPrint('AssignmentBoard: リアルタイム権限チェック開始 - groupId: ${group.id}');

      GroupFirestoreService.canEditDataType(
            groupId: group.id,
            dataType: 'assignment_board',
          )
          .then((canEdit) {
            // リアルタイムチェック時の権限判定
            final groupSettings = groupProvider.getCurrentGroupSettings();
            final userRole = group.getMemberRole(currentUser.uid);
            final accessLevel = groupSettings?.getPermissionForDataType(
              'assignment_board',
            );
            debugPrint(
              'AssignmentBoard: リアルタイム権限判定 - userRole: $userRole, accessLevel: $accessLevel',
            );
            if (mounted && _canEditAssignment != canEdit) {
              setState(() {
                _canEditAssignment = canEdit;
              });
            }
          })
          .catchError((e) {
            // エラーの場合は編集不可として扱う
            debugPrint('AssignmentBoard: リアルタイム権限チェックエラー - $e');
            if (mounted && (_canEditAssignment != false)) {
              setState(() {
                _canEditAssignment = false;
              });
            }
          });
    } else {
      // グループ未参加の場合は編集不可
      if (mounted && (_canEditAssignment != false)) {
        setState(() {
          _canEditAssignment = false;
        });
      }
    }
  }

  /// グループに今日の担当履歴を同期
  Future<void> _syncTodayAssignmentToGroup(List<String> assignments) async {
    try {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.hasGroup) {
        final group = groupProvider.currentGroup!;
        debugPrint('AssignmentBoard: 今日の担当履歴をグループに同期開始 - groupId: ${group.id}');

        final todayAssignmentData = {
          'assignments': assignments,
          'savedAt': DateTime.now().toIso8601String(),
        };

        await GroupDataSyncService.syncTodayAssignment(
          group.id,
          todayAssignmentData,
        );
        debugPrint('AssignmentBoard: 今日の担当履歴同期完了');
      }
    } catch (e) {
      debugPrint('AssignmentBoard: 今日の担当履歴同期エラー: $e');
    }
  }

  Future<void> _loadState() async {
    if (!mounted) return;

    // このメソッドは非グループ状態でのみ使用
    final groupProvider = context.read<GroupProvider>();
    if (groupProvider.groups.isNotEmpty) {
      debugPrint('AssignmentBoard: グループ状態 - _loadStateはスキップ');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isDataInitialized = true;
        });
      }
      return;
    }

    // 個人データ取得
    try {
      final assignmentMembers =
          await AssignmentFirestoreService.loadAssignmentMembers();
      if (assignmentMembers != null) {
        debugPrint('AssignmentBoard: Firestoreから担当表データを取得しました');
        _mergeGroupDataWithLocal(assignmentMembers);
        // 今日の担当履歴も取得
        final today = _todayKey();
        final assignmentHistory =
            await AssignmentFirestoreService.loadAssignmentHistory(today);
        if (assignmentHistory != null && assignmentHistory.isNotEmpty) {
          setAssignmentHistoryFromFirestore(assignmentHistory);
        }
        return;
      }
    } catch (e) {
      debugPrint('AssignmentBoard: Firestoreからのデータ取得に失敗しました: $e');
    } finally {
      // データ読み込み完了時にローディング状態を終了
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isDataInitialized = true;
        });
      }
    }
  }

  /// ラベルのみを再読み込み（メンバーデータは保持）
  Future<void> _reloadLabelsOnly() async {
    try {
      debugPrint('AssignmentBoard: ラベル再読み込み開始');

      final settings = await UserSettingsFirestoreService.getMultipleSettings([
        'leftLabels',
        'rightLabels',
      ]);

      debugPrint('AssignmentBoard: 取得したラベル設定: $settings');

      if (mounted) {
        setState(() {
          leftLabels = List<String>.from(settings['leftLabels'] ?? []);
          rightLabels = List<String>.from(settings['rightLabels'] ?? []);
        });
        debugPrint(
          'AssignmentBoard: ラベル再読み込み完了 - leftLabels: $leftLabels, rightLabels: $rightLabels',
        );
      }
    } catch (e) {
      debugPrint('AssignmentBoard: ラベル再読み込みエラー: $e');
    }
  }

  /// メンバーのみを再読み込み（ラベルデータは保持）
  Future<void> _reloadMembersOnly() async {
    try {
      debugPrint('AssignmentBoard: メンバー再読み込み開始');

      final settings = await UserSettingsFirestoreService.getMultipleSettings([
        'teams',
        'assignment_team_a',
        'assignment_team_b',
      ]);

      if (mounted) {
        // 新しい形式で班データを読み込み
        final teamsJson = settings['teams'];
        if (teamsJson != null) {
          final teamsList = jsonDecode(teamsJson) as List;
          teams = teamsList.map((teamMap) => Team.fromMap(teamMap)).toList();
        } else {
          // 既存のA班、B班データを新しい形式に変換
          final loadedA = settings['assignment_team_a'] ?? [];
          final loadedB = settings['assignment_team_b'] ?? [];
          teams = [
            Team(id: 'team_a', name: 'A班', members: loadedA),
            Team(id: 'team_b', name: 'B班', members: loadedB),
          ];
        }
        setState(() {});
        debugPrint('AssignmentBoard: メンバー再読み込み完了');
      }
    } catch (e) {
      debugPrint('AssignmentBoard: メンバー再読み込みエラー: $e');
    }
  }

  String _todayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  String _dayKeyAgo(int d) => DateFormat(
    'yyyy-MM-dd',
  ).format(DateTime.now().subtract(Duration(days: d)));

  /// リセット後の状態を検証して永続化
  Future<void> _verifyResetState() async {
    try {
      final today = _todayKey();
      debugPrint('AssignmentBoard: リセット状態の検証開始 - today: $today');

      // グループ状態でない場合のみローカルデータを保存
      final groupProvider = context.read<GroupProvider>();
      if (!groupProvider.hasGroup) {
        await UserSettingsFirestoreService.saveMultipleSettings({
          'assignment_$today': null,
          'assignedDate': null,
          'lastResetDate': today, // リセット実行日を記録
          'resetVerified': true, // リセット検証フラグ
        });
      }

      // 現在の状態を確認
      final assignedPairs = await UserSettingsFirestoreService.getSetting(
        'assignment_$today',
      );
      final savedDate = await UserSettingsFirestoreService.getSetting(
        'assignedDate',
      );

      debugPrint(
        'AssignmentBoard: リセット後の確認 - assignedPairs: $assignedPairs, savedDate: $savedDate',
      );

      // 状態が正しくリセットされていることを確認
      if (assignedPairs == null && savedDate == null) {
        debugPrint('AssignmentBoard: リセット状態の検証成功');

        // UIの状態も確実に更新
        if (mounted) {
          setState(() {
            isAssignedToday = false;
          });
        }
      } else {
        debugPrint('AssignmentBoard: リセット状態の検証失敗 - 再試行');

        // 再度リセットを実行
        await UserSettingsFirestoreService.saveMultipleSettings({
          'assignment_$today': null,
          'assignedDate': null,
        });

        if (mounted) {
          setState(() {
            isAssignedToday = false;
          });
        }
      }
    } catch (e) {
      debugPrint('AssignmentBoard: リセット状態の検証エラー: $e');

      // エラーの場合も確実にリセット状態にする
      if (mounted) {
        setState(() {
          isAssignedToday = false;
        });
      }
    }
  }

  bool _isWeekend() {
    final wd = DateTime.now().weekday;
    return wd == DateTime.saturday || wd == DateTime.sunday;
  }

  List<String> _makePairs() {
    final count = leftLabels.length;
    if (teams.length < 2) return [];

    // 複数の班に対応するため、すべての班のメンバーを結合
    List<String> pairs = [];
    for (int i = 0; i < count; i++) {
      List<String> rowMembers = [];
      for (int teamIndex = 0; teamIndex < teams.length; teamIndex++) {
        if (i < teams[teamIndex].members.length &&
            teams[teamIndex].members[i].isNotEmpty) {
          rowMembers.add(teams[teamIndex].members[i]);
        } else {
          rowMembers.add('未設定');
        }
      }
      pairs.add(rowMembers.join('-'));
    }
    return pairs;
  }

  bool _isDuplicate(List<String> newPairs, List<String>? old) {
    if (old == null || old.isEmpty) return false;
    try {
      return newPairs.any((pair) => old.contains(pair));
    } catch (e) {
      debugPrint(
        'AssignmentBoard: _isDuplicateエラー: $e, newPairs: $newPairs, old: $old',
      );
      return false;
    }
  }

  void _shuffleAssignments() {
    final count = leftLabels.length;

    // すべての班のメンバー数が十分かチェック
    bool hasEnoughMembers = true;
    for (int i = 0; i < teams.length; i++) {
      if (teams[i].members.length < count) {
        hasEnoughMembers = false;
        break;
      }
    }

    if (teams.length < 2 || !hasEnoughMembers) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('エラー'),
          content: Text('メンバー数が担当数に足りません。編集画面で調整してください。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => isShuffling = true);
    int cnt = 0;
    const dur = Duration(milliseconds: 100);
    // ローカルでシャッフルを行い、UI更新は間引いて行う
    List<List<String>> shuffledMembers = List.generate(
      teams.length,
      (i) => List.from(teams[i].members),
    );
    shuffleTimer = Timer.periodic(dur, (_) async {
      try {
        // 各チームのメンバーをシャッフル（ローカル配列）
        for (int i = 0; i < shuffledMembers.length; i++) {
          shuffledMembers[i].shuffle(Random());
        }

        // UI更新は間引いて行う（5回に1回）
        if (cnt % 5 == 0) {
          if (!mounted) return;
          setState(() {
            for (int i = 0; i < teams.length; i++) {
              teams[i] = teams[i].copyWith(
                members: List.from(shuffledMembers[i]),
              );
            }
          });
        }

        if (++cnt >= 50) {
          shuffleTimer?.cancel();

          final today = _todayKey();
          final y1 = _dayKeyAgo(1), y2 = _dayKeyAgo(2);
          List<String> pairs = _makePairs();
          final p1Data = await UserSettingsFirestoreService.getSetting(
            'assignment_$y1',
          );
          final p2Data = await UserSettingsFirestoreService.getSetting(
            'assignment_$y2',
          );

          final p1 = _safeStringListFromDynamic(p1Data);
          final p2 = _safeStringListFromDynamic(p2Data);

          int retry = 0;
          // 重い同期ループを避けるため、再シャッフルは非同期に行い、UI更新は最小化する
          while ((_isDuplicate(pairs, p1) || _isDuplicate(pairs, p2)) &&
              retry < 100) {
            // 再シャッフル（ローカル配列のみ）
            for (int i = 0; i < shuffledMembers.length; i++) {
              shuffledMembers[i].shuffle(Random());
            }

            // 最終結果のみUIに反映
            final newPairs = _makePairs();
            if (!_isDuplicate(newPairs, p1) && !_isDuplicate(newPairs, p2)) {
              // pairs を更新してループを抜ける
              pairs = newPairs;
              break;
            }

            retry++;
            // 小さく待機してUIスレッドへの負担を分散
            await Future.delayed(Duration(milliseconds: 5));
          }

          await UserSettingsFirestoreService.saveMultipleSettings({
            'assignment_$today': pairs,
            'assignedDate': today,
          });

          setState(() {
            isShuffling = false;
            isAssignedToday = true;
          });

          // Firestoreに必ず保存（グループ未参加時も）
          try {
            await AssignmentFirestoreService.saveAssignmentHistory(
              dateKey: today,
              assignments: pairs,
              leftLabels: leftLabels, // 追加
              rightLabels: rightLabels, // 追加
            );
            debugPrint('AssignmentBoard: 担当履歴をFirestoreに保存完了');
          } catch (e) {
            debugPrint('AssignmentBoard: 担当履歴のFirestore保存エラー: $e');
          }

          // グループに同期（グループ参加時のみ）
          _syncTodayAssignmentToGroup(pairs);
          // 担当決定後に広告を表示
          _showInterstitialAdAfterAssignment();
        }
      } catch (e) {
        debugPrint('AssignmentBoard: シャッフル処理エラー: $e');
        shuffleTimer?.cancel();
        setState(() {
          isShuffling = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('シャッフル処理中にエラーが発生しました: $e')));
      }
    });
  }

  /// 開発者モードを読み込み
  Future<void> _loadDeveloperMode() async {
    try {
      final devMode = await UserSettingsFirestoreService.getSetting(
        'developerMode',
        defaultValue: false,
      );
      if (mounted) {
        setState(() {
          isDeveloperMode = devMode;
        });
      }
    } catch (e) {
      debugPrint('AssignmentBoard: 開発者モード読み込みエラー: $e');
    }
  }

  /// 開発者モードの監視を開始
  void _startDeveloperModeListener() {
    _developerModeSubscription?.cancel();
    _developerModeSubscription =
        UserSettingsFirestoreService.watchSettings(['developerMode']).listen((
          settings,
        ) {
          if (mounted && settings.containsKey('developerMode')) {
            setState(() {
              isDeveloperMode = settings['developerMode'] ?? false;
            });
          }
        });
  }

  /// 表示名の変更を監視
  void _startDisplayNameMonitoring() {
    debugPrint('AssignmentBoard: 表示名監視を開始');

    // 定期的に表示名をチェックして更新を検知
    _displayNameSubscription?.cancel();
    _displayNameSubscription = Stream.periodic(Duration(seconds: 10)).listen((
      _,
    ) async {
      if (!mounted) return;

      try {
        final currentDisplayName =
            await FirstLoginService.getCurrentDisplayName();
        final currentUser = FirebaseAuth.instance.currentUser;

        if (currentUser != null && currentDisplayName != null) {
          // 表示名が変更された場合、担当表を再構築
          setState(() {
            // 状態を更新してMemberCardを再描画
          });
          debugPrint('AssignmentBoard: 表示名変更を検知 - 担当表を更新: $currentDisplayName');
        }
      } catch (e) {
        debugPrint('AssignmentBoard: 表示名監視エラー: $e');
      }
    });
  }

  /// 今日の担当をリセット
  Future<void> _resetTodayAssignment() async {
    final today = _todayKey();
    debugPrint('AssignmentBoard: 今日の担当リセット開始 - today: $today');

    // グループ状態でない場合のみローカルデータをリセット
    final currentGroupProvider = context.read<GroupProvider>();
    if (!currentGroupProvider.hasGroup) {
      await UserSettingsFirestoreService.saveMultipleSettings({
        'assignment_$today': null,
        'assignedDate': null,
      });
    }

    // Firestoreからも削除
    try {
      await AssignmentFirestoreService.deleteAssignmentHistory(today);
      debugPrint('AssignmentBoard: Firestoreから今日の担当履歴削除完了');
    } catch (e) {
      debugPrint('AssignmentBoard: Firestoreからの今日の担当履歴削除エラー: $e');
    }

    // グループにも同期（今日の担当データを完全に削除）
    try {
      if (!mounted) return;
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.hasGroup) {
        final group = groupProvider.currentGroup!;
        debugPrint(
          'AssignmentBoard: 今日の担当履歴をグループから削除開始 - groupId: ${group.id}',
        );

        // 今日の担当データを完全に削除（空のマップを送信）
        await GroupDataSyncService.syncTodayAssignment(
          group.id,
          {}, // 空のマップを送信してデータをクリア
        );

        // 担当履歴からも削除
        final assignmentHistoryData = {
          today: {'deleted': true, 'savedAt': DateTime.now().toIso8601String()},
        };

        await GroupDataSyncService.syncAssignmentHistory(
          group.id,
          assignmentHistoryData,
        );
        debugPrint('AssignmentBoard: 今日の担当履歴削除完了');
      }
    } catch (e) {
      debugPrint('AssignmentBoard: グループからの今日の担当履歴削除エラー: $e');
    }

    // グループ状態の場合は、メンバー構成を復元しない（グループデータに任せる）
    if (!mounted) return;
    final groupProvider = context.read<GroupProvider>();
    if (groupProvider.groups.isNotEmpty) {
      debugPrint('AssignmentBoard: グループ状態のため、メンバー構成復元をスキップ');
      if (mounted) {
        setState(() {
          isAssignedToday = false;
        });
      }
    } else {
      // 個人状態の場合は、_loadState()を呼び出してデータを再読み込み
      await _loadState();
    }

    // リセット後の状態を確実にチェックして永続化
    await _verifyResetState();

    debugPrint('AssignmentBoard: 今日の担当リセット完了');
  }

  void _showInterstitialAdAfterAssignment() async {
    if (await isDonorUser()) return; // 寄付者は広告を表示しない
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712', // テスト用ID
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (error) {},
      ),
    );
  }

  @override
  void dispose() {
    shuffleTimer?.cancel();
    _groupAssignmentSubscription?.cancel();
    _groupSettingsSubscription?.cancel();
    _groupTodayAssignmentSubscription?.cancel();
    _developerModeSubscription?.cancel();
    _groupAttendanceSubscription?.cancel();
    _displayNameSubscription?.cancel();
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GroupProvider>(
      builder: (context, groupProvider, child) {
        // リアルタイム権限チェックを実行
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkEditPermissionRealtime(groupProvider);
        });

        // グループデータの監視状態を確認
        if (groupProvider.hasGroup && !groupProvider.isWatchingGroupData) {
          // グループデータの監視を開始
          WidgetsBinding.instance.addPostFrameCallback((_) {
            groupProvider.startWatchingGroupData();
          });
        }

        if (_isLoading) {
          return Scaffold(
            backgroundColor: Provider.of<ThemeSettings>(
              context,
            ).backgroundColor,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LoadingAnimationWidget(width: 200, height: 200),
                  SizedBox(height: 24),
                  Text(
                    '担当表を読み込み中...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Provider.of<ThemeSettings>(context).fontColor1,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final todayIsWeekend = _isWeekend();
        final isButtonDisabled =
            todayIsWeekend && !isDeveloperMode ||
            isAssignedToday ||
            isShuffling;

        final themeSettings = Provider.of<ThemeSettings>(context);

        // Web版とスマホ版でUIを分岐
        if (kIsWeb) {
          return _buildWebUI(
            context,
            groupProvider,
            themeSettings,
            isButtonDisabled,
            todayIsWeekend,
          );
        } else {
          return _buildMobileUI(
            context,
            groupProvider,
            themeSettings,
            isButtonDisabled,
            todayIsWeekend,
          );
        }
      },
    );
  }

  /// Web版専用のUIを構築
  Widget _buildWebUI(
    BuildContext context,
    GroupProvider groupProvider,
    ThemeSettings themeSettings,
    bool isButtonDisabled,
    bool todayIsWeekend,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.group, color: themeSettings.iconColor),
            SizedBox(width: 8),
            Flexible(child: Text('担当表', overflow: TextOverflow.ellipsis)),
            // グループ状態バッジを追加
            if (groupProvider.groups.isNotEmpty)
              Container(
                margin: EdgeInsets.only(left: 12),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade400),
                ),
                child: Icon(
                  Icons.groups,
                  size: 18,
                  color: Colors.blue.shade700,
                ),
              ),
          ],
        ),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
        actions: [
          if (_canEditAssignment == true) ...[
            IconButton(
              icon: Icon(Icons.person_add),
              tooltip: 'メンバー編集',
              onPressed: () async {
                final currentLeftLabels = List<String>.from(leftLabels);
                final currentRightLabels = List<String>.from(rightLabels);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MemberEditPage()),
                );
                await _reloadMembersOnly();
                setState(() {
                  leftLabels = currentLeftLabels;
                  rightLabels = currentRightLabels;
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.label),
              tooltip: 'ラベル編集',
              onPressed: () async {
                final currentTeams = List<Team>.from(teams);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LabelEditPage()),
                );
                await _reloadLabelsOnly();
                setState(() {
                  teams = currentTeams;
                });
              },
            ),
          ],
          IconButton(
            icon: Icon(Icons.list),
            tooltip: '担当履歴',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AssignmentHistoryPage()),
              );
            },
          ),
          if (_canEditAssignment == true)
            IconButton(
              icon: Icon(Icons.settings),
              tooltip: '設定',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SettingsPage(onReset: _resetTodayAssignment),
                  ),
                );
              },
            ),
        ],
      ),
      body: Container(
        color: themeSettings.backgroundColor,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1200), // Web版はより広い幅
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  SizedBox(height: 24),
                  // Web版専用の担当表レイアウト
                  _buildWebAssignmentTable(themeSettings),
                  SizedBox(height: 40),
                  // Web版専用のボタンレイアウト
                  _buildWebButtonLayout(isButtonDisabled, todayIsWeekend),
                  SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// スマホ版専用のUIを構築
  Widget _buildMobileUI(
    BuildContext context,
    GroupProvider groupProvider,
    ThemeSettings themeSettings,
    bool isButtonDisabled,
    bool todayIsWeekend,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.group, color: themeSettings.iconColor),
            SizedBox(width: 8),
            Flexible(child: Text('担当表', overflow: TextOverflow.ellipsis)),
            // グループ状態バッジを追加
            if (groupProvider.groups.isNotEmpty)
              Container(
                margin: EdgeInsets.only(left: 12),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade400),
                ),
                child: Icon(
                  Icons.groups,
                  size: 18,
                  color: Colors.blue.shade700,
                ),
              ),
          ],
        ),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
        actions: [
          if (_canEditAssignment == true) ...[
            IconButton(
              icon: Icon(Icons.person_add),
              tooltip: 'メンバー編集',
              onPressed: () async {
                final currentLeftLabels = List<String>.from(leftLabels);
                final currentRightLabels = List<String>.from(rightLabels);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MemberEditPage()),
                );
                await _reloadMembersOnly();
                setState(() {
                  leftLabels = currentLeftLabels;
                  rightLabels = currentRightLabels;
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.label),
              tooltip: 'ラベル編集',
              onPressed: () async {
                final currentTeams = List<Team>.from(teams);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LabelEditPage()),
                );
                await _reloadLabelsOnly();
                setState(() {
                  teams = currentTeams;
                });
              },
            ),
          ],
          IconButton(
            icon: Icon(Icons.list),
            tooltip: '担当履歴',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AssignmentHistoryPage()),
              );
            },
          ),
          if (_canEditAssignment == true)
            IconButton(
              icon: Icon(Icons.settings),
              tooltip: '設定',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SettingsPage(onReset: _resetTodayAssignment),
                  ),
                );
              },
            ),
        ],
      ),
      body: Container(
        color: themeSettings.backgroundColor,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(height: 40), // 上部の余白を増加
              // スマホ版専用の担当表レイアウト
              _buildMobileAssignmentTable(themeSettings),
              SizedBox(height: 40), // 担当表とボタンの間の余白を増加
              // スマホ版専用のボタンレイアウト
              _buildMobileButtonLayout(isButtonDisabled, todayIsWeekend),
              SizedBox(height: 40), // 下部の余白を増加
            ],
          ),
        ),
      ),
    );
  }

  /// Web版専用の担当表テーブル
  Widget _buildWebAssignmentTable(ThemeSettings themeSettings) {
    return Container(
      padding: EdgeInsets.all(32),
      constraints: BoxConstraints(maxWidth: 1000),
      decoration: BoxDecoration(
        color: themeSettings.cardBackgroundColor,
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Web版ヘッダー行
          Container(
            padding: EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: themeSettings.backgroundColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(width: 120), // 左ラベル用スペース
                ...teams
                    .map<Widget>(
                      (team) => SizedBox(
                        width: 160,
                        child: Center(
                          child: Text(
                            team.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24 * themeSettings.fontSizeScale,
                              color: themeSettings.fontColor1,
                            ),
                          ),
                        ),
                      ),
                    )
                    ,
                SizedBox(width: 120), // 右ラベル用スペース
              ],
            ),
          ),
          SizedBox(height: 16),
          // データ表示部分
          if (_isLoading)
            _buildLoadingWidget(themeSettings)
          else if (_isDataInitialized &&
              _isRemoteSyncCompleted &&
              leftLabels.isEmpty &&
              teams.every((t) => t.members.isEmpty))
            _buildEmptyStateWidget()
          else
            _buildWebDataRows(themeSettings),
        ],
      ),
    );
  }

  /// スマホ版専用の担当表テーブル
  Widget _buildMobileAssignmentTable(ThemeSettings themeSettings) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: themeSettings.cardBackgroundColor,
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // スマホ版ヘッダー行（班名をカードの上に配置）
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 60), // 左ラベル用スペース
                SizedBox(width: 4), // スペーサー
                ...teams
                    .map<Widget>(
                      (team) => Container(
                        width: 85, // カードと同じ幅に調整
                        margin: EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          team.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16 * themeSettings.fontSizeScale,
                            color: themeSettings.fontColor1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    ,
                SizedBox(width: 4), // スペーサー
                SizedBox(width: 60), // 右ラベル用スペース
              ],
            ),
          ),
          // データ表示部分
          if (_isLoading)
            _buildLoadingWidget(themeSettings)
          else if (_isDataInitialized &&
              _isRemoteSyncCompleted &&
              leftLabels.isEmpty &&
              teams.every((t) => t.members.isEmpty))
            _buildEmptyStateWidget()
          else
            _buildMobileDataRows(themeSettings),
        ],
      ),
    );
  }

  /// Web版データ行
  Widget _buildWebDataRows(ThemeSettings themeSettings) {
    return Column(
      children: List.generate(
        leftLabels.isNotEmpty
            ? leftLabels.length
            : teams.fold<int>(
                0,
                (max, team) =>
                    team.members.length > max ? team.members.length : max,
              ),
        (i) => Container(
          margin: EdgeInsets.symmetric(vertical: 8),
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: i % 2 == 0
                ? themeSettings.backgroundColor.withOpacity(0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 左ラベル
              SizedBox(
                width: 120,
                child: Text(
                  leftLabels.isNotEmpty && i < leftLabels.length
                      ? leftLabels[i]
                      : '',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18 * themeSettings.fontSizeScale,
                    color: themeSettings.fontColor1,
                  ),
                ),
              ),
              // メンバーカード
              ...teams
                  .map<Widget>(
                    (team) => SizedBox(
                      width: 160,
                      child: Center(
                        child: MemberCard(
                          name:
                              i < team.members.length &&
                                  team.members[i].isNotEmpty
                              ? team.members[i]
                              : '未設定',
                          attendanceStatus: _getMemberAttendanceStatus(
                            i < team.members.length &&
                                    team.members[i].isNotEmpty
                                ? team.members[i]
                                : '未設定',
                          ),
                          onTap: () {
                            if (i < team.members.length &&
                                team.members[i].isNotEmpty) {
                              _showAttendanceDialog(team.members[i]);
                            }
                          },
                        ),
                      ),
                    ),
                  )
                  ,
              // 右ラベル
              SizedBox(
                width: 120,
                child: Text(
                  rightLabels.isNotEmpty && i < rightLabels.length
                      ? rightLabels[i]
                      : '',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18 * themeSettings.fontSizeScale,
                    color: themeSettings.fontColor1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// スマホ版データ行
  Widget _buildMobileDataRows(ThemeSettings themeSettings) {
    return Column(
      children: List.generate(
        leftLabels.isNotEmpty
            ? leftLabels.length
            : teams.fold<int>(
                0,
                (max, team) =>
                    team.members.length > max ? team.members.length : max,
              ),
        (i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 左ラベル
              SizedBox(
                width: 60,
                child: Text(
                  leftLabels.isNotEmpty && i < leftLabels.length
                      ? leftLabels[i]
                      : '',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13 * themeSettings.fontSizeScale,
                    color: themeSettings.fontColor1,
                  ),
                  overflow: TextOverflow.visible,
                  maxLines: 2,
                ),
              ),
              SizedBox(width: 4), // ラベルとカードの間の小さなスペース
              // メンバーカード
              ...teams
                  .map<Widget>(
                    (team) => Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: 2,
                      ), // カード間の小さなスペース
                      child: MemberCard(
                        name:
                            i < team.members.length &&
                                team.members[i].isNotEmpty
                            ? team.members[i]
                            : '未設定',
                        attendanceStatus: _getMemberAttendanceStatus(
                          i < team.members.length && team.members[i].isNotEmpty
                              ? team.members[i]
                              : '未設定',
                        ),
                        onTap: () {
                          if (i < team.members.length &&
                              team.members[i].isNotEmpty) {
                            _showAttendanceDialog(team.members[i]);
                          }
                        },
                      ),
                    ),
                  )
                  ,
              SizedBox(width: 4), // カードとラベルの間の小さなスペース
              // 右ラベル
              SizedBox(
                width: 60,
                child: Text(
                  rightLabels.isNotEmpty && i < rightLabels.length
                      ? rightLabels[i]
                      : '',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13 * themeSettings.fontSizeScale,
                    color: themeSettings.fontColor1,
                  ),
                  overflow: TextOverflow.visible,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Web版ボタンレイアウト
  Widget _buildWebButtonLayout(bool isButtonDisabled, bool todayIsWeekend) {
    return Container(
      constraints: BoxConstraints(maxWidth: 600),
      child: Column(
        children: [
          if (_canEditAssignment == true) ...[
            if (isDeveloperMode)
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'デバッグ: 編集権限=$_canEditAssignment',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            SizedBox(
              width: 300,
              height: 50,
              child: ElevatedButton(
                onPressed: isButtonDisabled ? null : _shuffleAssignments,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  () {
                    if (todayIsWeekend && !isDeveloperMode) return '土日は休み';
                    if (isAssignedToday) return '今日はすでに決定済み';
                    if (isShuffling) return 'シャッフル中...';
                    return '今日の担当を決める';
                  }(),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// スマホ版ボタンレイアウト
  Widget _buildMobileButtonLayout(bool isButtonDisabled, bool todayIsWeekend) {
    return Column(
      children: [
        if (_canEditAssignment == true) ...[
          if (isDeveloperMode)
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'デバッグ: 編集権限=$_canEditAssignment',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ElevatedButton(
            onPressed: isButtonDisabled ? null : _shuffleAssignments,
            child: Text(() {
              if (todayIsWeekend && !isDeveloperMode) return '土日は休み';
              if (isAssignedToday) return '今日はすでに決定済み';
              if (isShuffling) return 'シャッフル中...';
              return '今日の担当を決める';
            }()),
          ),
        ],
      ],
    );
  }

  /// ローディングウィジェット
  Widget _buildLoadingWidget(ThemeSettings themeSettings) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0),
      child: Center(
        child: Column(
          children: [
            Lottie.asset(
              'assets/animations/Loading coffee bean.json',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
            ),
            SizedBox(height: 16),
            Text(
              '担当表を読み込み中...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: themeSettings.fontColor1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 空状態ウィジェット
  Widget _buildEmptyStateWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Center(
        child: Text(
          'メンバーとラベルを追加してください',
          style: TextStyle(
            color: Colors.red,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// 出勤退勤状態変更ダイアログを表示
  void _showAttendanceDialog(String memberName) {
    // 現在のユーザーが変更しようとしているメンバーと一致するかチェック
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserName = currentUser?.displayName ?? '';

    // グループ状態の場合は、グループメンバー情報から現在のユーザー名を取得
    final groupProvider = context.read<GroupProvider>();
    String currentUserNameInGroup = currentUserName;

    if (groupProvider.hasGroup) {
      final currentUserInGroup = groupProvider.currentGroup!.members.firstWhere(
        (member) => member.uid == currentUser?.uid,
        orElse: () => GroupMember(
          uid: '',
          email: '',
          displayName: currentUserName,
          role: GroupRole.member,
          joinedAt: DateTime.now(),
        ),
      );
      currentUserNameInGroup = currentUserInGroup.displayName;
    }

    // 自分以外のメンバーの状態は変更できない
    if (memberName != currentUserNameInGroup) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('変更不可'),
          content: Text('自分の出勤・退勤状態のみ変更できます。\n\n$memberName の状態は変更できません。'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final currentStatus = _getMemberAttendanceStatus(memberName);
    final newStatus = currentStatus == AttendanceStatus.present
        ? AttendanceStatus.absent
        : AttendanceStatus.present;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('出勤退勤状態の変更'),
        content: Text(
          '自分の状態を変更しますか？\n\n現在: ${currentStatus == AttendanceStatus.present ? '白カード（出勤）' : '赤カード（退勤）'}\n変更後: ${newStatus == AttendanceStatus.present ? '白カード（出勤）' : '赤カード（退勤）'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _updateMemberAttendance(memberName, newStatus);
            },
            child: Text('変更'),
          ),
        ],
      ),
    );
  }
}

class MemberCard extends StatefulWidget {
  final String name;
  final AttendanceStatus attendanceStatus;
  final VoidCallback? onTap;

  const MemberCard({
    super.key,
    required this.name,
    this.attendanceStatus = AttendanceStatus.present,
    this.onTap,
  });

  @override
  State<MemberCard> createState() => _MemberCardState();
}

class _MemberCardState extends State<MemberCard> {
  String? _customDisplayName;
  bool _isLoadingDisplayName = true;

  @override
  void initState() {
    super.initState();
    _loadCustomDisplayName();
    _startDisplayNameMonitoring();
  }

  /// カスタム表示名を読み込み
  Future<void> _loadCustomDisplayName() async {
    try {
      // 現在のユーザーのカスタム表示名を取得
      final customDisplayName = await FirstLoginService.getCurrentDisplayName();

      if (mounted) {
        setState(() {
          _customDisplayName = customDisplayName;
          _isLoadingDisplayName = false;
        });
      }
    } catch (e) {
      debugPrint('MemberCard: カスタム表示名読み込みエラー: $e');
      if (mounted) {
        setState(() {
          _isLoadingDisplayName = false;
        });
      }
    }
  }

  /// 表示名の変更を監視
  void _startDisplayNameMonitoring() {
    // 定期的に表示名をチェック
    Timer.periodic(Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        final newDisplayName = await FirstLoginService.getCurrentDisplayName();
        if (_customDisplayName != newDisplayName) {
          if (mounted) {
            setState(() {
              _customDisplayName = newDisplayName;
            });
            debugPrint(
              'MemberCard: 表示名変更を検知: $_customDisplayName -> $newDisplayName',
            );
          }
        }
      } catch (e) {
        debugPrint('MemberCard: 表示名監視エラー: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 表示名を決定（カスタム表示名を優先）
    String displayName;
    if (_isLoadingDisplayName) {
      displayName = '読み込み中...';
    } else if (widget.name.isEmpty) {
      displayName = '未設定';
    } else {
      // 現在のユーザーのカードの場合、カスタム表示名を使用
      final currentUser = FirebaseAuth.instance.currentUser;
      final currentUserName = currentUser?.displayName ?? '';

      // グループ状態の場合は、グループメンバー情報から現在のユーザー名を取得
      final groupProvider = context.read<GroupProvider>();
      String currentUserNameInGroup = currentUserName;

      if (groupProvider.hasGroup) {
        final currentUserInGroup = groupProvider.currentGroup!.members
            .firstWhere(
              (member) => member.uid == currentUser?.uid,
              orElse: () => GroupMember(
                uid: '',
                email: '',
                displayName: currentUserName,
                role: GroupRole.member,
                joinedAt: DateTime.now(),
              ),
            );
        currentUserNameInGroup = currentUserInGroup.displayName;
      }

      // 自分のカードかどうかを判定
      final isMyCard = widget.name == currentUserNameInGroup;

      if (isMyCard &&
          _customDisplayName != null &&
          _customDisplayName!.isNotEmpty) {
        displayName = _customDisplayName!;
      } else {
        displayName = widget.name;
      }
    }

    final isUnset = displayName == '未設定' || displayName == '読み込み中...';

    // 現在のユーザー名を取得
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserName = currentUser?.displayName ?? '';

    // グループ状態の場合は、グループメンバー情報から現在のユーザー名を取得
    final groupProvider = context.read<GroupProvider>();
    String currentUserNameInGroup = currentUserName;

    if (groupProvider.hasGroup) {
      final currentUserInGroup = groupProvider.currentGroup!.members.firstWhere(
        (member) => member.uid == currentUser?.uid,
        orElse: () => GroupMember(
          uid: '',
          email: '',
          displayName: currentUserName,
          role: GroupRole.member,
          joinedAt: DateTime.now(),
        ),
      );
      currentUserNameInGroup = currentUserInGroup.displayName;
    }

    // 自分のカードかどうかを判定
    final isMyCard = displayName == currentUserNameInGroup && !isUnset;

    // 出勤退勤状態に基づいて色を決定
    Color cardColor;
    Color textColor;
    Color borderColor;

    if (isUnset) {
      cardColor = Provider.of<ThemeSettings>(context).cardBackgroundColor;
      textColor = Colors.grey[600]!;
      borderColor = Colors.grey.shade400;
    } else {
      switch (widget.attendanceStatus) {
        case AttendanceStatus.present:
          cardColor = Colors.white; // 白カード（出勤）
          textColor = Colors.black;
          borderColor = isMyCard
              ? Provider.of<ThemeSettings>(context).iconColor
              : Colors.grey.shade400;
          break;
        case AttendanceStatus.absent:
          cardColor = Colors.red.shade600; // 赤カード（退勤）
          textColor = Colors.white;
          borderColor = isMyCard
              ? Provider.of<ThemeSettings>(context).iconColor
              : Colors.red.shade700;
          break;
      }
    }

    return GestureDetector(
      onTap: isUnset ? null : widget.onTap,
      child: Container(
        width: kIsWeb ? 120 : 85,
        height: kIsWeb ? 60 : 50, // Web版は高さを固定
        padding: EdgeInsets.symmetric(vertical: kIsWeb ? 12 : 10),
        margin: EdgeInsets.symmetric(horizontal: kIsWeb ? 2 : 2),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isMyCard ? 3 : 2, // 自分のカードは太い枠線
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              displayName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: kIsWeb ? 16 : 12,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
