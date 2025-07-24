import '../settings/assignment_settings_page.dart';
import 'package:flutter/material.dart';
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
import '../../widgets/lottie_animation_widget.dart';

class AssignmentBoard extends StatefulWidget {
  const AssignmentBoard({super.key});

  @override
  State<AssignmentBoard> createState() => AssignmentBoardState();
}

class AssignmentBoardState extends State<AssignmentBoard> {
  late SharedPreferences prefs;
  bool _isLoading = true;
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
  bool _isAttendanceLoading = true;

  // グループ同期用
  StreamSubscription<Map<String, dynamic>?>? _groupAssignmentSubscription;
  StreamSubscription<GroupSettings?>? _groupSettingsSubscription;
  StreamSubscription<Map<String, dynamic>?>? _groupTodayAssignmentSubscription;
  StreamSubscription<Map<String, dynamic>>? _developerModeSubscription;
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

  /// グループデータとローカルデータをマージ
  void _mergeGroupDataWithLocal(Map<String, dynamic> groupAssignmentData) {
    debugPrint('AssignmentBoard: グループデータとローカルデータをマージ開始');
    debugPrint('AssignmentBoard: 受信データ: $groupAssignmentData');

    if (mounted) {
      setState(() {
        // 新しい形式（teams）または古い形式（aMembers, bMembers）に対応
        if (groupAssignmentData['teams'] != null) {
          final teamsList = groupAssignmentData['teams'] as List;
          teams = teamsList.map((teamMap) => Team.fromMap(teamMap)).toList();
        } else {
          // 古い形式の場合は新しい形式に変換
          final aMembers = _safeStringListFromDynamic(
            groupAssignmentData['aMembers'],
          );
          final bMembers = _safeStringListFromDynamic(
            groupAssignmentData['bMembers'],
          );
          teams = [
            Team(id: 'team_a', name: 'A班', members: aMembers),
            Team(id: 'team_b', name: 'B班', members: bMembers),
          ];
        }

        // ラベルデータはグループデータを優先、ただし空の場合はローカルデータを保持
        if ((groupAssignmentData['leftLabels'] as List?)?.isNotEmpty ?? false) {
          leftLabels = _safeStringListFromDynamic(
            groupAssignmentData['leftLabels'],
          );
        }
        if ((groupAssignmentData['rightLabels'] as List?)?.isNotEmpty ??
            false) {
          rightLabels = _safeStringListFromDynamic(
            groupAssignmentData['rightLabels'],
          );
        }

        // データ設定完了後、ローディング状態を解除
        _isLoading = false;
      });
    }

    // ローカルデータも更新
    _updateLocalData();

    debugPrint(
      'AssignmentBoard: マージ完了 - teams: ${teams.length}, leftLabels: $leftLabels, rightLabels: $rightLabels',
    );
  }

  /// ローカルデータを更新
  Future<void> _updateLocalData() async {
    try {
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

  void setAssignmentHistoryFromFirestore(List<String> history) {
    if (mounted) {
      setState(() {
        if (history.isNotEmpty &&
            history.length == leftLabels.length &&
            teams.length >= 2) {
          // 履歴を各チームに分配
          for (int i = 0; i < teams.length; i++) {
            final teamMembers = history.map((e) => e.split('-')[i]).toList();
            teams[i] = teams[i].copyWith(members: teamMembers);
          }
          isAssignedToday = true;
        } else {
          // 履歴が空または無効な場合は決定済みフラグをリセット
          isAssignedToday = false;
        }
      });
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

    // 権限の初期値を設定（グループ未参加時は編集可能・担当決定可能）
    _canEditAssignment = true;

    // まずローカルデータを読み込み（ラベルを確実に保持）
    _loadLocalDataFirst();

    _loadTodayAttendance();
    _initializeGroupMonitoring();
    _loadDeveloperMode();
    _startDeveloperModeListener();

    // 初期権限チェックを実行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkEditPermission();
    });
  }

  /// ローカルデータを最初に読み込み（ラベルを確実に保持）
  Future<void> _loadLocalDataFirst() async {
    try {
      debugPrint('AssignmentBoard: ローカルデータ優先読み込み開始');

      final settings = await UserSettingsFirestoreService.getMultipleSettings([
        'teams',
        'leftLabels',
        'rightLabels',
        'assignment_team_a',
        'assignment_team_b',
      ]);

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

      // ラベルデータを確実に読み込み
      leftLabels = settings['leftLabels'] ?? [];
      rightLabels = settings['rightLabels'] ?? [];

      debugPrint(
        'AssignmentBoard: ローカルデータ読み込み完了 - leftLabels: $leftLabels, rightLabels: $rightLabels',
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // 今日の担当履歴も読み込み
      final today = _todayKey();
      final assignedPairs =
          await UserSettingsFirestoreService.getSetting('assignment_$today') ??
          [];
      final savedDate = settings['assignedDate'];
      final wasAssigned = savedDate == today && assignedPairs.isNotEmpty;

      if (wasAssigned &&
          assignedPairs.length == leftLabels.length &&
          teams.length >= 2) {
        for (int i = 0; i < teams.length; i++) {
          final newTeamMembers = assignedPairs
              .map((e) => e.split('-')[i])
              .toList();
          teams[i] = teams[i].copyWith(members: newTeamMembers);
        }
        isAssignedToday = true;
      }
    } catch (e) {
      debugPrint('AssignmentBoard: ローカルデータ読み込みエラー: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // グループ状態でない場合のみローカルデータを再読み込み
    final groupProvider = context.read<GroupProvider>();
    if (!groupProvider.hasGroup && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadState();
      });
    }
  }

  /// 今日の出勤退勤記録を読み込み
  Future<void> _loadTodayAttendance() async {
    try {
      if (mounted) {
        setState(() {
          _isAttendanceLoading = true;
        });
      }

      final attendance = await AttendanceFirestoreService.getTodayAttendance();
      if (mounted) {
        setState(() {
          _todayAttendance = attendance;
          _isAttendanceLoading = false;
        });
      }
    } catch (e) {
      debugPrint('AssignmentBoard: 出勤退勤記録読み込みエラー: $e');
      if (mounted) {
        setState(() {
          _isAttendanceLoading = false;
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
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

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

      // ローカル状態を更新
      await _loadTodayAttendance();
    } catch (e) {
      debugPrint('AssignmentBoard: 出勤退勤状態更新エラー: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('出勤退勤状態の更新に失敗しました')));
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
      debugPrint('出勤記録処理エラー: $e');
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
      debugPrint('グループレベルシステム処理エラー: $e');
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
    debugPrint('AssignmentBoard: グループ監視初期化開始');
    // 既に監視中の場合は何もしない
    if (_groupAssignmentSubscription != null) {
      debugPrint('AssignmentBoard: 既にグループ監視中です');
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupProvider = context.read<GroupProvider>();
      _startGroupMonitoring(groupProvider);
    });
  }

  /// グループ監視を開始
  void _startGroupMonitoring(GroupProvider groupProvider) {
    debugPrint('AssignmentBoard: グループ監視開始');

    // 既存のサブスクリプションをクリーンアップ
    _groupAssignmentSubscription?.cancel();
    _groupSettingsSubscription?.cancel();
    _groupTodayAssignmentSubscription?.cancel();

    if (groupProvider.hasGroup) {
      final group = groupProvider.currentGroup!;
      debugPrint('AssignmentBoard: グループ監視開始 - groupId: ${group.id}');

      // グループの担当表データを監視
      _groupAssignmentSubscription =
          GroupDataSyncService.watchGroupAssignmentBoard(group.id).listen((
            groupAssignmentData,
          ) {
            if (!mounted) return; // ウィジェットが破棄されている場合は処理しない
            debugPrint('AssignmentBoard: グループ担当表データ変更検知: $groupAssignmentData');
            if (groupAssignmentData != null) {
              // グループデータが利用可能になった場合、ローカルデータとマージ
              _mergeGroupDataWithLocal(groupAssignmentData);
            } else {
              debugPrint('AssignmentBoard: グループ担当表データが空です - ローカルデータを維持');
              // グループデータが空の場合は、ローカルデータを維持
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            }
          });

      // グループ設定を監視
      debugPrint('AssignmentBoard: グループ設定監視を開始 - groupId: ${group.id}');
      _groupSettingsSubscription =
          GroupFirestoreService.watchGroupSettings(group.id).listen((
            groupSettings,
          ) {
            if (!mounted) return; // ウェットが破棄されている場合は処理しない
            debugPrint('AssignmentBoard: グループ設定変更検知: $groupSettings');

            if (groupSettings != null) {
              debugPrint(
                'AssignmentBoard: グループ設定変換成功: ${groupSettings.dataPermissions}',
              );

              // グループ設定が変更されたら権限を再チェック
              _checkEditPermissionFromSettings(groupSettings, groupProvider);
            } else {
              debugPrint('AssignmentBoard: グループ設定データがnullです');
            }
          });

      // グループの今日の担当履歴を監視
      _groupTodayAssignmentSubscription =
          GroupDataSyncService.watchGroupTodayAssignment(group.id).listen((
            groupTodayAssignmentData,
          ) {
            if (!mounted) return; // ウェットが破棄されている場合は処理しない
            debugPrint(
              'AssignmentBoard: グループ今日の担当履歴変更検知: $groupTodayAssignmentData',
            );
            if (groupTodayAssignmentData != null &&
                groupTodayAssignmentData['assignments'] != null) {
              setAssignmentHistoryFromFirestore(
                _safeStringListFromDynamic(
                  groupTodayAssignmentData['assignments'],
                ),
              );
            } else {
              // グループの今日の担当履歴が削除された場合
              setAssignmentHistoryFromFirestore([]);
            }
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

    debugPrint('AssignmentBoard: _checkEditPermissionFromSettings開始');
    debugPrint('AssignmentBoard: 現在の権限状態: $_canEditAssignment');
    debugPrint('AssignmentBoard: 受信したグループ設定: $groupSettings');
    debugPrint(
      'AssignmentBoard: 受信したグループ設定のdataPermissions: ${groupSettings.dataPermissions}',
    );

    try {
      final userRole = groupProvider.currentGroup!.getMemberRole(
        currentUser.uid,
      );
      if (userRole == null) {
        debugPrint('AssignmentBoard: ユーザーロールが取得できません');
        setState(() {
          _canEditAssignment = false;
        });
        return;
      }

      debugPrint('AssignmentBoard: ユーザーロール: $userRole');
      debugPrint(
        'AssignmentBoard: グループ設定のdataPermissions: ${groupSettings.dataPermissions}',
      );

      final canEdit = groupSettings.canEditDataType(
        'assignment_board',
        userRole,
      );

      debugPrint(
        'AssignmentBoard: 設定変更による権限チェック - ユーザーロール: $userRole, 編集権限: $canEdit',
      );

      if (mounted && _canEditAssignment != canEdit) {
        debugPrint(
          'AssignmentBoard: 権限状態を更新します - 編集権限: $_canEditAssignment -> $canEdit',
        );
        setState(() {
          _canEditAssignment = canEdit;
        });
        debugPrint('AssignmentBoard: 権限状態を更新完了 - canEdit: $canEdit');
      } else {
        debugPrint(
          'AssignmentBoard: 権限状態は変更されませんでした - 現在: $_canEditAssignment, 新しい値: $canEdit',
        );
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

      // 参加しているグループがあるかチェック
      if (groups.isNotEmpty) {
        // 最初のグループの権限をチェック（複数グループの場合は要改善）
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

        // フォールバック時はメンバー以上に担当決定権限を付与
        final canAssignToday = true;

        debugPrint(
          'AssignmentBoard: フォールバック権限チェック結果 - canEdit: $canEdit, canAssignToday: $canAssignToday',
        );

        setState(() {
          _canEditAssignment = canEdit;
        });
      } else {
        // グループ未参加時も編集可・担当決定可
        debugPrint('AssignmentBoard: グループ未参加 - 編集可能・担当決定可能に設定');
        setState(() {
          _canEditAssignment = true;
        });
      }
    } catch (e) {
      // エラーの場合は編集可能・担当決定可能として扱う（グループに参加していない場合など）
      debugPrint('AssignmentBoard: 権限チェックエラー - $e, 編集可能・担当決定可能に設定');
      setState(() {
        _canEditAssignment = true;
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
            // エラーの場合は編集可能・担当決定可能として扱う
            debugPrint('AssignmentBoard: リアルタイム権限チェックエラー - $e');
            if (mounted && (_canEditAssignment != true)) {
              setState(() {
                _canEditAssignment = true;
              });
            }
          });
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
    // このメソッドは非グループ状態でのみ使用
    final groupProvider = context.read<GroupProvider>();
    if (groupProvider.groups.isNotEmpty) {
      debugPrint('AssignmentBoard: グループ状態 - _loadStateはスキップ');
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
    }
  }

  /// ラベルのみを再読み込み（メンバーデータは保持）
  Future<void> _reloadLabelsOnly() async {
    try {
      final settings = await UserSettingsFirestoreService.getMultipleSettings([
        'leftLabels',
        'rightLabels',
      ]);

      if (mounted) {
        setState(() {
          leftLabels = settings['leftLabels'] ?? [];
          rightLabels = settings['rightLabels'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('AssignmentBoard: ラベル再読み込みエラー: $e');
    }
  }

  /// メンバーのみを再読み込み（ラベルデータは保持）
  Future<void> _reloadMembersOnly() async {
    try {
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
      }
    } catch (e) {
      debugPrint('AssignmentBoard: メンバー再読み込みエラー: $e');
    }
  }

  String _todayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  String _dayKeyAgo(int d) => DateFormat(
    'yyyy-MM-dd',
  ).format(DateTime.now().subtract(Duration(days: d)));

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
    shuffleTimer = Timer.periodic(dur, (_) async {
      try {
        // 各チームのメンバーをシャッフル
        List<List<String>> shuffledMembers = [];
        for (int i = 0; i < teams.length; i++) {
          final teamMembers = List<String>.from(teams[i].members);
          teamMembers.shuffle(Random());
          shuffledMembers.add(teamMembers);
        }

        setState(() {
          for (int i = 0; i < teams.length; i++) {
            teams[i] = teams[i].copyWith(members: shuffledMembers[i]);
          }
        });

        if (++cnt >= 50) {
          shuffleTimer?.cancel();

          final today = _todayKey();
          final y1 = _dayKeyAgo(1), y2 = _dayKeyAgo(2);
          final pairs = _makePairs();
          final p1Data = await UserSettingsFirestoreService.getSetting(
            'assignment_$y1',
          );
          final p2Data = await UserSettingsFirestoreService.getSetting(
            'assignment_$y2',
          );

          final p1 = _safeStringListFromDynamic(p1Data);
          final p2 = _safeStringListFromDynamic(p2Data);

          int retry = 0;
          while ((_isDuplicate(pairs, p1) || _isDuplicate(pairs, p2)) &&
              retry < 100) {
            // 再シャッフル
            for (int i = 0; i < teams.length; i++) {
              shuffledMembers[i].shuffle(Random());
            }
            setState(() {
              for (int i = 0; i < teams.length; i++) {
                teams[i] = teams[i].copyWith(members: shuffledMembers[i]);
              }
            });
            final newPairs = _makePairs();
            if (!_isDuplicate(newPairs, p1) && !_isDuplicate(newPairs, p2)) {
              break;
            }
            retry++;
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

  /// 今日の担当をリセット
  Future<void> _resetTodayAssignment() async {
    final today = _todayKey();
    debugPrint('AssignmentBoard: 今日の担当リセット開始 - today: $today');

    // Firebaseデータをリセット
    await UserSettingsFirestoreService.saveMultipleSettings({
      'assignment_$today': null,
      'assignedDate': null,
    });

    // Firestoreからも削除
    try {
      await AssignmentFirestoreService.deleteAssignmentHistory(today);
      debugPrint('AssignmentBoard: Firestoreから今日の担当履歴削除完了');
    } catch (e) {
      debugPrint('AssignmentBoard: Firestoreからの今日の担当履歴削除エラー: $e');
    }

    // グループにも同期
    try {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.hasGroup) {
        final group = groupProvider.currentGroup!;
        debugPrint(
          'AssignmentBoard: 今日の担当履歴をグループから削除開始 - groupId: ${group.id}',
        );

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

    // グループ状態の場合は、メンバーを元の構成に戻す
    final groupProvider = context.read<GroupProvider>();
    if (groupProvider.groups.isNotEmpty) {
      // グループ状態の場合は、保存されたメンバー構成を読み込む
      try {
        final settings = await UserSettingsFirestoreService.getMultipleSettings(
          ['teams', 'leftLabels', 'rightLabels'],
        );

        // 新しい形式で班データを読み込み
        final teamsJson = settings['teams'];
        if (teamsJson != null) {
          final teamsList = jsonDecode(teamsJson) as List;
          final originalTeams = teamsList
              .map((teamMap) => Team.fromMap(teamMap))
              .toList();

          if (mounted) {
            setState(() {
              teams = originalTeams;
              leftLabels = settings['leftLabels'] ?? [];
              rightLabels = settings['rightLabels'] ?? [];
              isAssignedToday = false;
            });
          }
        } else {
          // 既存のA班、B班データを新しい形式に変換
          final loadedA = settings['assignment_team_a'] ?? [];
          final loadedB = settings['assignment_team_b'] ?? [];
          final originalTeams = [
            Team(id: 'team_a', name: 'A班', members: loadedA),
            Team(id: 'team_b', name: 'B班', members: loadedB),
          ];

          if (mounted) {
            setState(() {
              teams = originalTeams;
              leftLabels = settings['leftLabels'] ?? [];
              rightLabels = settings['rightLabels'] ?? [];
              isAssignedToday = false;
            });
          }
        }
        debugPrint('AssignmentBoard: グループ状態でのメンバー構成復元完了');
      } catch (e) {
        debugPrint('AssignmentBoard: グループ状態でのメンバー構成復元エラー: $e');
        // エラーの場合は既存のメンバー構成をそのまま使用
        if (mounted) {
          setState(() {
            isAssignedToday = false;
          });
        }
      }
    } else {
      // 個人状態の場合は、_loadState()を呼び出してデータを再読み込み
      await _loadState();
    }

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
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleAttendance = _todayAttendance.where((record) {
      final allMembers = teams.expand((t) => t.members).toSet();
      return allMembers.contains(record.memberName);
    }).toList();
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
          return const LoadingScreen(title: 'Loading...');
        }

        final todayIsWeekend = _isWeekend();
        final isButtonDisabled =
            todayIsWeekend && !isDeveloperMode ||
            isAssignedToday ||
            isShuffling;

        final themeSettings = Provider.of<ThemeSettings>(context);
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Icon(Icons.group, color: themeSettings.iconColor),
                SizedBox(width: 8),
                Flexible(child: Text('担当表', overflow: TextOverflow.ellipsis)),
                // グループ状態バッジを追加
                Consumer<GroupProvider>(
                  builder: (context, groupProvider, _) {
                    if (groupProvider.groups.isNotEmpty) {
                      // グループ名のテキストを削除し、アイコンのみ表示
                      return Container(
                        margin: EdgeInsets.only(left: 12),
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
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
                      );
                    } else {
                      return SizedBox.shrink();
                    }
                  },
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
                    final groupProvider = context.read<GroupProvider>();

                    // グループ状態の場合はラベルデータを保存
                    List<String>? currentLeftLabels;
                    List<String>? currentRightLabels;
                    if (groupProvider.hasGroup) {
                      currentLeftLabels = List<String>.from(leftLabels);
                      currentRightLabels = List<String>.from(rightLabels);
                    }

                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => MemberEditPage()),
                    );

                    // グループ状態の場合は手動での再読み込みは不要（監視が自動更新）
                    if (!groupProvider.hasGroup) {
                      // メンバー編集ページから戻った時にメンバーのみ再読み込み
                      await _reloadMembersOnly();
                    }

                    // グループ状態の場合はラベルデータを復元
                    if (groupProvider.hasGroup &&
                        currentLeftLabels != null &&
                        currentRightLabels != null) {
                      setState(() {
                        leftLabels = currentLeftLabels!;
                        rightLabels = currentRightLabels!;
                      });
                    }
                  },
                ),
                IconButton(
                  icon: Icon(Icons.label),
                  tooltip: 'ラベル編集',
                  onPressed: () async {
                    final groupProvider = context.read<GroupProvider>();

                    // グループ状態の場合はメンバーデータを保存
                    List<Team>? currentTeams;
                    if (groupProvider.hasGroup) {
                      currentTeams = List<Team>.from(teams);
                    }

                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => LabelEditPage()),
                    );

                    // グループ状態の場合は手動での再読み込みは不要（監視が自動更新）
                    if (!groupProvider.hasGroup) {
                      // ラベル編集ページから戻った時にラベルのみ再読み込み
                      await _reloadLabelsOnly();
                    }

                    // グループ状態の場合はメンバーデータを復元
                    if (groupProvider.hasGroup && currentTeams != null) {
                      setState(() {
                        teams = currentTeams!;
                      });
                    }
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
            color: Provider.of<ThemeSettings>(context).backgroundColor,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // 出勤退勤状況の表示
                  if (!_isAttendanceLoading && visibleAttendance.isNotEmpty)
                    Card(
                      elevation: 4,
                      color: Provider.of<ThemeSettings>(
                        context,
                      ).backgroundColor2,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.access_time, color: Colors.blue),
                                SizedBox(width: 8),
                                Text(
                                  '今日の出勤状況',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Provider.of<ThemeSettings>(
                                      context,
                                    ).fontColor1,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: visibleAttendance.map((record) {
                                return Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        record.status ==
                                            AttendanceStatus.present
                                        ? Colors.white
                                        : Colors.red,
                                    border: Border.all(
                                      color:
                                          record.status ==
                                              AttendanceStatus.present
                                          ? Colors.grey.shade400
                                          : Colors.red.shade700,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    record.memberName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          record.status ==
                                              AttendanceStatus.present
                                          ? Colors.black
                                          : Colors.white,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SizedBox(height: 16),
                  // 担当表の表示
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Provider.of<ThemeSettings>(
                        context,
                      ).backgroundColor2,
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // ヘッダー行
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(width: 80),
                              ...teams.map(
                                (team) => Expanded(
                                  child: Center(
                                    child: Text(
                                      team.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: Provider.of<ThemeSettings>(
                                          context,
                                        ).fontColor1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 80),
                            ],
                          ),
                        ),
                        // ラベルが空かつ全チームのメンバーが空の場合のみ赤字で表示
                        if (leftLabels.isEmpty &&
                            teams.every((t) => t.members.isEmpty))
                          Padding(
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
                          )
                        else
                          // 柔軟な行数で表示（ラベル数分のみ）
                          ...List.generate(leftLabels.length, (i) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      i < leftLabels.length
                                          ? leftLabels[i]
                                          : '',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Provider.of<ThemeSettings>(
                                          context,
                                        ).fontColor1,
                                      ),
                                    ),
                                  ),
                                  ...teams.map(
                                    (team) => Expanded(
                                      child: Center(
                                        child: MemberCard(
                                          name:
                                              i < team.members.length &&
                                                  team.members[i].isNotEmpty
                                              ? team.members[i]
                                              : '未設定',
                                          attendanceStatus:
                                              _getMemberAttendanceStatus(
                                                i < team.members.length &&
                                                        team
                                                            .members[i]
                                                            .isNotEmpty
                                                    ? team.members[i]
                                                    : '未設定',
                                              ),
                                          onTap: () {
                                            if (i < team.members.length &&
                                                team.members[i].isNotEmpty) {
                                              _showAttendanceDialog(
                                                team.members[i],
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      i < rightLabels.length
                                          ? rightLabels[i]
                                          : '',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Provider.of<ThemeSettings>(
                                          context,
                                        ).fontColor1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  SizedBox(height: 32),
                  // 担当決定ボタン（編集権限がある場合のみ表示）
                  if (_canEditAssignment == true) ...[
                    // デバッグ情報を表示（開発時のみ）
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
                  ] else
                    SizedBox.shrink(),
                  SizedBox(height: 20), // 下部に余白を追加
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 出勤退勤状態変更ダイアログを表示
  void _showAttendanceDialog(String memberName) {
    final currentStatus = _getMemberAttendanceStatus(memberName);
    final newStatus = currentStatus == AttendanceStatus.present
        ? AttendanceStatus.absent
        : AttendanceStatus.present;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('出勤退勤状態の変更'),
        content: Text(
          '$memberName の状態を変更しますか？\n\n現在: ${currentStatus == AttendanceStatus.present ? '緑カード（出勤）' : '赤カード（退勤）'}\n変更後: ${newStatus == AttendanceStatus.present ? '緑カード（出勤）' : '赤カード（退勤）'}',
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

class MemberCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final displayName = name.isEmpty ? '未設定' : name;
    final isUnset = displayName == '未設定';

    // 出勤退勤状態に基づいて色を決定
    Color? cardColor;
    Color? textColor;
    Color? borderColor;

    if (isUnset) {
      cardColor = Provider.of<ThemeSettings>(context).backgroundColor2;
      textColor = Colors.grey[600];
      borderColor = Colors.grey.shade400;
    } else {
      switch (attendanceStatus) {
        case AttendanceStatus.present:
          cardColor = Colors.white;
          textColor = Colors.black;
          borderColor = Colors.grey.shade400;
          break;
        case AttendanceStatus.absent:
          cardColor = Colors.red;
          textColor = Colors.white;
          borderColor = Colors.red.shade700;
          break;
      }
    }

    return GestureDetector(
      onTap: isUnset ? null : onTap,
      child: Container(
        width: 100,
        padding: EdgeInsets.symmetric(vertical: 10),
        margin: EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
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
