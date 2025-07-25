import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:roastplus/models/attendance_models.dart';
import 'package:roastplus/models/dashboard_stats_provider.dart';
import 'package:roastplus/models/group_models.dart';
import 'package:roastplus/models/group_provider.dart';
import 'package:roastplus/pages/business/utils/assignment_utils.dart';
import 'package:roastplus/services/assignment_firestore_service.dart';
import 'package:roastplus/services/attendance_firestore_service.dart';
import 'package:roastplus/services/group_data_sync_service.dart';
import 'package:roastplus/services/group_firestore_service.dart';
import 'package:roastplus/services/user_settings_firestore_service.dart';

class AssignmentBoardController extends ChangeNotifier {
  bool _isLoading = true;
  bool? _canEditAssignment; // null: 未判定, true/false: 判定済み
  bool _disposed = false; // disposedフラグを追加

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

  BuildContext? _context; // Providerのcontextを保持

  // Getters for UI
  bool get isLoading => _isLoading;
  bool? get canEditAssignment => _canEditAssignment;
  List<Team> get currentTeams => teams;
  List<String> get currentLeftLabels => leftLabels;
  List<String> get currentRightLabels => rightLabels;
  bool get shuffling => isShuffling;
  bool get assignedToday => isAssignedToday;
  bool get developerMode => isDeveloperMode;
  List<AttendanceRecord> get todayAttendance => _todayAttendance;
  bool get isAttendanceLoading => _isAttendanceLoading;
  bool get disposed => _disposed; // disposedゲッターを追加

  bool get hasGroup {
    if (_context == null) return false;
    return Provider.of<GroupProvider>(_context!, listen: false).hasGroup;
  }

  void initialize(BuildContext context) {
    if (_context != null) return; // 既に初期化済み
    if (_disposed) return; // disposedの場合は初期化をスキップ
    _context = context;
    _canEditAssignment = true;
    _loadLocalDataFirst();
    _loadTodayAttendance();
    _initializeGroupMonitoring();
    _loadDeveloperMode();
    _startDeveloperModeListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkEditPermission();
    });
  }

  /// 安全なnotifyListeners呼び出し
  void _safeNotifyListeners() {
    if (!_disposed && _context != null) {
      notifyListeners();
    }
  }

  /// 安全な文字列リスト変換
  List<String> _safeStringListFromDynamic(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      try {
        return data.map((item) => item?.toString() ?? '').toList();
      } catch (e) {
        debugPrint('AssignmentBoardController: リスト変換エラー: $e, data: $data');
        return [];
      }
    }
    debugPrint(
      'AssignmentBoardController: 予期しないデータ型: ${data.runtimeType}, data: $data',
    );
    return [];
  }

  /// グループデータとローカルデータをマージ（publicメソッド）
  void mergeGroupDataWithLocal(Map<String, dynamic> groupAssignmentData) {
    _mergeGroupDataWithLocal(groupAssignmentData);
  }

  /// グループデータとローカルデータをマージ
  void _mergeGroupDataWithLocal(Map<String, dynamic> groupAssignmentData) {
    debugPrint('AssignmentBoardController: グループデータとローカルデータをマージ開始');
    debugPrint('AssignmentBoardController: 受信データ: $groupAssignmentData');

    if (_context != null) {
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
      if ((groupAssignmentData['rightLabels'] as List?)?.isNotEmpty ?? false) {
        rightLabels = _safeStringListFromDynamic(
          groupAssignmentData['rightLabels'],
        );
      }

      // データ設定完了後、ローディング状態を解除
      _isLoading = false;
      _safeNotifyListeners();
    }

    // ローカルデータも更新
    _updateLocalData();

    debugPrint(
      'AssignmentBoardController: マージ完了 - teams: ${teams.length}, leftLabels: $leftLabels, rightLabels: $rightLabels',
    );
  }

  /// ローカルデータを更新
  Future<void> _updateLocalData() async {
    if (_disposed) return;
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

      debugPrint('AssignmentBoardController: Firebaseデータ更新完了');
    } catch (e) {
      debugPrint('AssignmentBoardController: Firebaseデータ更新エラー: $e');
    }
  }

  void setAssignmentHistoryFromFirestore(List<String> history) {
    if (_disposed || _context == null) return;
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
    _safeNotifyListeners();
  }

  void setAssignmentMembersFromFirestore(
    Map<String, dynamic> assignmentMembers,
  ) {
    if (_disposed || _context == null) return;

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
    leftLabels = _safeStringListFromDynamic(assignmentMembers['leftLabels']);
    rightLabels = _safeStringListFromDynamic(assignmentMembers['rightLabels']);
    _safeNotifyListeners();
  }

  /// ローカルデータを最初に読み込み（ラベルを確実に保持）
  Future<void> _loadLocalDataFirst() async {
    try {
      debugPrint('AssignmentBoardController: ローカルデータ優先読み込み開始');

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
        'AssignmentBoardController: ローカルデータ読み込み完了 - leftLabels: $leftLabels, rightLabels: $rightLabels',
      );

      if (_context != null) {
        _isLoading = false;
        _safeNotifyListeners();
      }

      // 今日の担当履歴も読み込み
      final today = todayKey();
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
      debugPrint('AssignmentBoardController: ローカルデータ読み込みエラー: $e');
      if (_context != null) {
        _isLoading = false;
        _safeNotifyListeners();
      }
    }
  }

  /// 今日の出勤退勤記録を読み込み
  Future<void> _loadTodayAttendance() async {
    if (_disposed) return;
    try {
      if (_context != null) {
        _isAttendanceLoading = true;
        _safeNotifyListeners();
      }

      final attendance = await AttendanceFirestoreService.getTodayAttendance();
      if (_disposed) return; // 非同期処理後に再度チェック
      if (_context != null) {
        _todayAttendance = attendance;
        _isAttendanceLoading = false;
        _safeNotifyListeners();
      }
    } catch (e) {
      debugPrint('AssignmentBoardController: 出勤退勤記録読み込みエラー: $e');
      if (_disposed) return;
      if (_context != null) {
        _isAttendanceLoading = false;
        _safeNotifyListeners();
      }
    }
  }

  /// メンバーの出勤退勤状態を取得
  AttendanceStatus getMemberAttendanceStatus(String memberName) {
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

  /// 出勤退勤状態変更ダイアログを表示
  void showAttendanceDialog(BuildContext context, String memberName) {
    final currentStatus = getMemberAttendanceStatus(memberName);
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
              await updateMemberAttendance(memberName, newStatus);
            },
            child: Text('変更'),
          ),
        ],
      ),
    );
  }

  /// メンバーの出勤退勤状態を更新
  Future<void> updateMemberAttendance(
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
      if (status == AttendanceStatus.present && _context != null) {
        await _addAttendanceExperience();
      }

      // 統計データを更新
      if (_context != null) {
        final statsProvider = Provider.of<DashboardStatsProvider>(
          _context!,
          listen: false,
        );
        await statsProvider.onAttendanceUpdated();
      }

      // ローカル状態を更新
      await _loadTodayAttendance();
    } catch (e) {
      debugPrint('AssignmentBoardController: 出勤退勤状態更新エラー: $e');
      if (_context == null) return;
      ScaffoldMessenger.of(
        _context!,
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
      debugPrint('AssignmentBoardController: 出勤記録処理エラー: $e');
    }
  }

  /// グループレベルシステムで出勤記録を処理
  Future<void> _processAttendanceForGroup() async {
    try {
      // グループプロバイダーを取得
      if (_context == null) return; // contextがnullの場合は処理をスキップ

      final groupProvider = Provider.of<GroupProvider>(
        _context!,
        listen: false,
      );

      if (groupProvider.hasGroup) {
        final groupId = groupProvider.currentGroup!.id;

        // グループのゲーミフィケーションシステムに通知
        await groupProvider.processGroupAttendance(groupId, context: _context!);
      }
    } catch (e) {
      debugPrint('AssignmentBoardController: グループレベルシステム処理エラー: $e');
    }
  }

  /// グループレベルシステム用の出勤結果表示
  void _showGroupAttendanceResult() {
    if (_context == null) return;

    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(content: Text('出勤記録を保存しました'), backgroundColor: Colors.green),
    );
  }

  /// グループ監視の初期化
  void _initializeGroupMonitoring() {
    debugPrint('AssignmentBoardController: グループ監視初期化開始');
    // 既に監視中の場合は何もしない
    if (_groupAssignmentSubscription != null) {
      debugPrint('AssignmentBoardController: 既にグループ監視中です');
      return;
    }

    if (_context != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final groupProvider = _context!.read<GroupProvider>();
        _startGroupMonitoring(groupProvider);
      });
    }
  }

  /// グループ監視を開始
  void _startGroupMonitoring(GroupProvider groupProvider) {
    debugPrint('AssignmentBoardController: グループ監視開始');

    // 既存のサブスクリプションをクリーンアップ
    _groupAssignmentSubscription?.cancel();
    _groupSettingsSubscription?.cancel();
    _groupTodayAssignmentSubscription?.cancel();

    if (groupProvider.hasGroup) {
      final group = groupProvider.currentGroup!;
      debugPrint('AssignmentBoardController: グループ監視開始 - groupId: ${group.id}');

      // グループの担当表データを監視
      _groupAssignmentSubscription =
          GroupDataSyncService.watchGroupAssignmentBoard(group.id).listen((
            groupAssignmentData,
          ) {
            if (_context == null) return; // ウィジェットが破棄されている場合は処理しない
            debugPrint(
              'AssignmentBoardController: グループ担当表データ変更検知: $groupAssignmentData',
            );
            if (groupAssignmentData != null) {
              // グループデータが利用可能になった場合、ローカルデータとマージ
              _mergeGroupDataWithLocal(groupAssignmentData);
            } else {
              debugPrint(
                'AssignmentBoardController: グループ担当表データが空です - ローカルデータを維持',
              );
              // グループデータが空の場合は、ローカルデータを維持
              if (_context != null) {
                _isLoading = false;
                _safeNotifyListeners();
              }
            }
          });

      // グループ設定を監視
      debugPrint(
        'AssignmentBoardController: グループ設定監視を開始 - groupId: ${group.id}',
      );
      _groupSettingsSubscription =
          GroupFirestoreService.watchGroupSettings(group.id).listen((
            groupSettings,
          ) {
            if (_context == null) return; // ウェットが破棄されている場合は処理しない
            debugPrint('AssignmentBoardController: グループ設定変更検知: $groupSettings');

            if (groupSettings != null) {
              debugPrint(
                'AssignmentBoardController: グループ設定変換成功: ${groupSettings.dataPermissions}',
              );

              // グループ設定が変更されたら権限を再チェック
              _checkEditPermissionFromSettings(groupSettings, groupProvider);
            } else {
              debugPrint('AssignmentBoardController: グループ設定データがnullです');
            }
          });

      // グループの今日の担当履歴を監視
      _groupTodayAssignmentSubscription =
          GroupDataSyncService.watchGroupTodayAssignment(group.id).listen((
            groupTodayAssignmentData,
          ) {
            if (_context == null) return; // ウェットが破棄されている場合は処理しない
            debugPrint(
              'AssignmentBoardController: グループ今日の担当履歴変更検知: $groupTodayAssignmentData',
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
      if (_context != null) {
        _canEditAssignment = false;
        _safeNotifyListeners();
      }
      return;
    }

    debugPrint('AssignmentBoardController: _checkEditPermissionFromSettings開始');
    debugPrint('AssignmentBoardController: 現在の権限状態: $_canEditAssignment');
    debugPrint('AssignmentBoardController: 受信したグループ設定: $groupSettings');
    debugPrint(
      'AssignmentBoardController: 受信したグループ設定のdataPermissions: ${groupSettings.dataPermissions}',
    );

    try {
      final userRole = groupProvider.currentGroup!.getMemberRole(
        currentUser.uid,
      );
      if (userRole == null) {
        debugPrint('AssignmentBoardController: ユーザーロールが取得できません');
        if (_context != null) {
          _canEditAssignment = false;
          _safeNotifyListeners();
        }
        return;
      }

      debugPrint('AssignmentBoardController: ユーザーロール: $userRole');
      debugPrint(
        'AssignmentBoardController: グループ設定のdataPermissions: ${groupSettings.dataPermissions}',
      );

      final canEdit = groupSettings.canEditDataType(
        'assignment_board',
        userRole,
      );

      debugPrint(
        'AssignmentBoardController: 設定変更による権限チェック - ユーザーロール: $userRole, 編集権限: $canEdit',
      );

      if (_context != null && _canEditAssignment != canEdit) {
        debugPrint(
          'AssignmentBoardController: 権限状態を更新します - 編集権限: $_canEditAssignment -> $canEdit',
        );
        _canEditAssignment = canEdit;
        _safeNotifyListeners();
        debugPrint('AssignmentBoardController: 権限状態を更新完了 - canEdit: $canEdit');
      } else {
        debugPrint(
          'AssignmentBoardController: 権限状態は変更されませんでした - 現在: $_canEditAssignment, 新しい値: $canEdit',
        );
      }
    } catch (e) {
      debugPrint('AssignmentBoardController: 設定変更による権限チェックエラー - $e');
      if (_context != null) {
        _canEditAssignment = true;
        _safeNotifyListeners();
      }
    }
  }

  /// 担当表編集権限をチェック
  Future<void> _checkEditPermission() async {
    try {
      if (_context == null) return;
      final groupProvider = _context!.read<GroupProvider>();
      final groups = groupProvider.groups;

      debugPrint(
        'AssignmentBoardController: 権限チェック開始 - groups: ${groups.length}',
      );

      // 参加しているグループがあるかチェック
      if (groups.isNotEmpty) {
        // 最初のグループの権限をチェック（複数グループの場合は要改善）
        final group = groups.first;
        debugPrint(
          'AssignmentBoardController: グループ権限チェック - groupId: ${group.id}',
        );

        // 現在のグループ設定から直接権限を取得
        final groupSettings = await GroupFirestoreService.getGroupSettings(
          group.id,
        );
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          debugPrint('未ログインのため権限チェックをスキップ');
          if (_context != null) {
            _canEditAssignment = false;
            notifyListeners();
          }
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
              'AssignmentBoardController: 初期権限チェック結果 - ユーザーロール: $userRole, 編集権限: $canEdit',
            );
            _canEditAssignment = canEdit;
            _safeNotifyListeners();
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
          'AssignmentBoardController: フォールバック権限チェック結果 - canEdit: $canEdit, canAssignToday: $canAssignToday',
        );

        _canEditAssignment = canEdit;
        _safeNotifyListeners();
      } else {
        // グループ未参加時も編集可・担当決定可
        debugPrint('AssignmentBoardController: グループ未参加 - 編集可能・担当決定可能に設定');
        _canEditAssignment = true;
        _safeNotifyListeners();
      }
    } catch (e) {
      // エラーの場合は編集可能・担当決定可能として扱う（グループに参加していない場合など）
      debugPrint('AssignmentBoardController: 権限チェックエラー - $e, 編集可能・担当決定可能に設定');
      if (_context != null) {
        _canEditAssignment = true;
        _safeNotifyListeners();
      }
    }
  }

  /// リアルタイムで権限をチェック（Consumer内で使用）
  void checkEditPermissionRealtime() {
    if (_context == null) return; // ウィジェットが破棄されている場合は処理しない

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('未ログインのため権限チェックをスキップ');
      _canEditAssignment = false;
      _safeNotifyListeners();
      return;
    }

    final groupProvider = Provider.of<GroupProvider>(_context!, listen: false);

    if (groupProvider.hasGroup) {
      final group = groupProvider.currentGroup!;
      debugPrint(
        'AssignmentBoardController: リアルタイム権限チェック開始 - groupId: ${group.id}',
      );

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
              'AssignmentBoardController: リアルタイム権限判定 - userRole: $userRole, accessLevel: $accessLevel',
            );
            if (_context != null && _canEditAssignment != canEdit) {
              _canEditAssignment = canEdit;
              _safeNotifyListeners();
            }
          })
          .catchError((e) {
            // エラーの場合は編集可能・担当決定可能として扱う
            debugPrint('AssignmentBoardController: リアルタイム権限チェックエラー - $e');
            if (_context != null && (_canEditAssignment != true)) {
              _canEditAssignment = true;
              _safeNotifyListeners();
            }
          });
    }
  }

  /// グループに今日の担当履歴を同期
  Future<void> syncTodayAssignmentToGroup(List<String> assignments) async {
    try {
      if (_context == null) return;
      final groupProvider = _context!.read<GroupProvider>();
      if (groupProvider.hasGroup) {
        final group = groupProvider.currentGroup!;
        debugPrint(
          'AssignmentBoardController: 今日の担当履歴をグループに同期開始 - groupId: ${group.id}',
        );

        final todayAssignmentData = {
          'assignments': assignments,
          'savedAt': DateTime.now().toIso8601String(),
        };

        await GroupDataSyncService.syncTodayAssignment(
          group.id,
          todayAssignmentData,
        );
        debugPrint('AssignmentBoardController: 今日の担当履歴同期完了');
      }
    } catch (e) {
      debugPrint('AssignmentBoardController: 今日の担当履歴同期エラー: $e');
    }
  }

  Future<void> loadState() async {
    // このメソッドは非グループ状態でのみ使用
    if (_context == null) return;
    final groupProvider = _context!.read<GroupProvider>();
    if (groupProvider.groups.isNotEmpty) {
      debugPrint('AssignmentBoardController: グループ状態 - loadStateはスキップ');
      return;
    }

    // 個人データ取得
    try {
      final assignmentMembers =
          await AssignmentFirestoreService.loadAssignmentMembers();
      if (assignmentMembers != null) {
        debugPrint('AssignmentBoardController: Firestoreから担当表データを取得しました');
        _mergeGroupDataWithLocal(assignmentMembers);
        // 今日の担当履歴も取得
        final today = todayKey();
        final assignmentHistory =
            await AssignmentFirestoreService.loadAssignmentHistory(today);
        if (assignmentHistory != null && assignmentHistory.isNotEmpty) {
          setAssignmentHistoryFromFirestore(assignmentHistory);
        }
        return;
      }
    } catch (e) {
      debugPrint('AssignmentBoardController: Firestoreからのデータ取得に失敗しました: $e');
    }
  }

  /// ラベルのみを再読み込み（メンバーデータは保持）
  Future<void> reloadLabelsOnly() async {
    try {
      final settings = await UserSettingsFirestoreService.getMultipleSettings([
        'leftLabels',
        'rightLabels',
      ]);

      if (_context != null) {
        leftLabels = settings['leftLabels'] ?? [];
        rightLabels = settings['rightLabels'] ?? [];
        _safeNotifyListeners();
      }
    } catch (e) {
      debugPrint('AssignmentBoardController: ラベル再読み込みエラー: $e');
    }
  }

  /// メンバーのみを再読み込み（ラベルデータは保持）
  Future<void> reloadMembersOnly() async {
    try {
      final settings = await UserSettingsFirestoreService.getMultipleSettings([
        'teams',
        'assignment_team_a',
        'assignment_team_b',
      ]);

      if (_context != null) {
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
        _safeNotifyListeners();
      }
    } catch (e) {
      debugPrint('AssignmentBoardController: メンバー再読み込みエラー: $e');
    }
  }

  List<String> makePairs() {
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

  bool isDuplicate(List<String> newPairs, List<String>? old) {
    if (old == null || old.isEmpty) return false;
    try {
      return newPairs.any((pair) => old.contains(pair));
    } catch (e) {
      debugPrint(
        'AssignmentBoardController: isDuplicateエラー: $e, newPairs: $newPairs, old: $old',
      );
      return false;
    }
  }

  Future<void> shuffleAssignments() async {
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
      if (_context == null) return;
      showDialog(
        context: _context!,
        builder: (_) => AlertDialog(
          title: Text('エラー'),
          content: Text('メンバー数が担当数に足りません。編集画面で調整してください。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(_context!),
              child: Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    isShuffling = true;
    notifyListeners();

    int cnt = 0;
    const dur = Duration(milliseconds: 100);
    shuffleTimer = Timer.periodic(dur, (_) async {
      if (_disposed) return;
      try {
        // 各チームのメンバーをシャッフル
        List<List<String>> shuffledMembers = [];
        for (int i = 0; i < teams.length; i++) {
          final teamMembers = List<String>.from(teams[i].members);
          teamMembers.shuffle(Random());
          shuffledMembers.add(teamMembers);
        }

        teams = List.from(
          teams.map(
            (e) => e.copyWith(members: shuffledMembers[teams.indexOf(e)]),
          ),
        ); // Update teams directly
        _safeNotifyListeners();

        if (++cnt >= 50) {
          shuffleTimer?.cancel();

          final today = todayKey();
          final y1 = dayKeyAgo(1), y2 = dayKeyAgo(2);
          final pairs = makePairs();
          final p1Data = await UserSettingsFirestoreService.getSetting(
            'assignment_$y1',
          );
          final p2Data = await UserSettingsFirestoreService.getSetting(
            'assignment_$y2',
          );

          final p1 = _safeStringListFromDynamic(p1Data);
          final p2 = _safeStringListFromDynamic(p2Data);

          int retry = 0;
          while ((isDuplicate(pairs, p1) || isDuplicate(pairs, p2)) &&
              retry < 100) {
            // 再シャッフル
            for (int i = 0; i < teams.length; i++) {
              shuffledMembers[i].shuffle(Random());
            }
            teams = List.from(
              teams.map(
                (e) => e.copyWith(members: shuffledMembers[teams.indexOf(e)]),
              ),
            ); // Update teams directly
            final newPairs = makePairs();
            if (!isDuplicate(newPairs, p1) && !isDuplicate(newPairs, p2)) {
              break;
            }
            retry++;
          }

          await UserSettingsFirestoreService.saveMultipleSettings({
            'assignment_$today': pairs,
            'assignedDate': today,
          });

          isShuffling = false;
          isAssignedToday = true;
          _safeNotifyListeners();

          // Firestoreに必ず保存（グループ未参加時も）
          try {
            await AssignmentFirestoreService.saveAssignmentHistory(
              dateKey: today,
              assignments: pairs,
              leftLabels: leftLabels, // 追加
              rightLabels: rightLabels, // 追加
            );
            debugPrint('AssignmentBoardController: 担当履歴をFirestoreに保存完了');
          } catch (e) {
            debugPrint('AssignmentBoardController: 担当履歴のFirestore保存エラー: $e');
          }

          // グループに同期（グループ参加時のみ）
          syncTodayAssignmentToGroup(pairs);
          // 担当決定後に広告を表示
          _showInterstitialAdAfterAssignment();
        }
      } catch (e) {
        debugPrint('AssignmentBoardController: シャッフル処理エラー: $e');
        shuffleTimer?.cancel();
        isShuffling = false;
        _safeNotifyListeners();
        if (_context == null) return;
        ScaffoldMessenger.of(
          _context!,
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
      if (_context != null) {
        isDeveloperMode = devMode;
        _safeNotifyListeners();
      }
    } catch (e) {
      debugPrint('AssignmentBoardController: 開発者モード読み込みエラー: $e');
    }
  }

  /// 開発者モードの監視を開始
  void _startDeveloperModeListener() {
    _developerModeSubscription?.cancel();
    _developerModeSubscription =
        UserSettingsFirestoreService.watchSettings(['developerMode']).listen((
          settings,
        ) {
          if (_context != null && settings.containsKey('developerMode')) {
            isDeveloperMode = settings['developerMode'] ?? false;
            _safeNotifyListeners();
          }
        });
  }

  /// 今日の担当をリセット
  Future<void> resetTodayAssignment() async {
    final today = todayKey();
    debugPrint('AssignmentBoardController: 今日の担当リセット開始 - today: $today');

    // Firebaseデータをリセット
    await UserSettingsFirestoreService.saveMultipleSettings({
      'assignment_$today': null,
      'assignedDate': null,
    });

    // Firestoreからも削除
    try {
      await AssignmentFirestoreService.deleteAssignmentHistory(today);
      debugPrint('AssignmentBoardController: Firestoreから今日の担当履歴削除完了');
    } catch (e) {
      debugPrint('AssignmentBoardController: Firestoreからの今日の担当履歴削除エラー: $e');
    }

    // グループにも同期
    try {
      if (_context == null) return;
      final groupProvider = _context!.read<GroupProvider>();
      if (groupProvider.hasGroup) {
        final group = groupProvider.currentGroup!;
        debugPrint(
          'AssignmentBoardController: 今日の担当履歴をグループから削除開始 - groupId: ${group.id}',
        );

        final assignmentHistoryData = {
          today: {'deleted': true, 'savedAt': DateTime.now().toIso8601String()},
        };

        await GroupDataSyncService.syncAssignmentHistory(
          group.id,
          assignmentHistoryData,
        );
        debugPrint('AssignmentBoardController: 今日の担当履歴削除完了');
      }
    } catch (e) {
      debugPrint('AssignmentBoardController: グループからの今日の担当履歴削除エラー: $e');
    }

    // グループ状態の場合は、メンバーを元の構成に戻す
    if (_context == null) return;
    final groupProvider = _context!.read<GroupProvider>();
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

          _canEditAssignment = true;
          teams = originalTeams;
          leftLabels = settings['leftLabels'] ?? [];
          rightLabels = settings['rightLabels'] ?? [];
          isAssignedToday = false;
          _safeNotifyListeners();
        } else {
          // 既存のA班、B班データを新しい形式に変換
          final loadedA = settings['assignment_team_a'] ?? [];
          final loadedB = settings['assignment_team_b'] ?? [];
          final originalTeams = [
            Team(id: 'team_a', name: 'A班', members: loadedA),
            Team(id: 'team_b', name: 'B班', members: loadedB),
          ];

          _canEditAssignment = true;
          teams = originalTeams;
          leftLabels = settings['leftLabels'] ?? [];
          rightLabels = settings['rightLabels'] ?? [];
          isAssignedToday = false;
          _safeNotifyListeners();
        }
        debugPrint('AssignmentBoardController: グループ状態でのメンバー構成復元完了');
      } catch (e) {
        debugPrint('AssignmentBoardController: グループ状態でのメンバー構成復元エラー: $e');
        // エラーの場合は既存のメンバー構成をそのまま使用
        _canEditAssignment = true;
        isAssignedToday = false;
        _safeNotifyListeners();
      }
    } else {
      // 個人状態の場合は、_loadState()を呼び出してデータを再読み込み
      await loadState();
    }

    debugPrint('AssignmentBoardController: 今日の担当リセット完了');
  }

  void _showInterstitialAdAfterAssignment() async {
    if (_disposed || _context == null) return;
    // isDonorUser() の定義が必要
    // if (await isDonorUser()) return; // 寄付者は広告を表示しない
    // InterstitialAd.load(
    //   adUnitId: 'ca-app-pub-3940256099942544/1033173712', // テスト用ID
    //   request: AdRequest(),
    //   adLoadCallback: InterstitialAdLoadCallback(
    //     onAdLoaded: (ad) {
    //       ad.fullScreenContentCallback = FullScreenContentCallback(
    //         onAdDismissedFullScreenContent: (ad) {
    //           ad.dispose();
    //         },
    //         onAdFailedToShowFullScreenContent: (ad, error) {
    //           ad.dispose();
    //         },
    //       );
    //       ad.show();
    //     },
    //     onAdFailedToLoad: (error) {},
    //   ),
    // );
  }

  @override
  void dispose() {
    debugPrint('AssignmentBoardController: dispose() 開始');

    // disposedフラグを先に設定して、以降の処理を防ぐ
    _disposed = true;

    // すべてのタイマーをキャンセル
    shuffleTimer?.cancel();
    shuffleTimer = null;
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;

    // すべてのストリームサブスクリプションをキャンセル
    _groupAssignmentSubscription?.cancel();
    _groupAssignmentSubscription = null;
    _groupSettingsSubscription?.cancel();
    _groupSettingsSubscription = null;
    _groupTodayAssignmentSubscription?.cancel();
    _groupTodayAssignmentSubscription = null;
    _developerModeSubscription?.cancel();
    _developerModeSubscription = null;

    // contextをクリア
    _context = null;

    debugPrint('AssignmentBoardController: dispose() 完了');
    super.dispose();
  }
}
