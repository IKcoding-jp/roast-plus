import 'package:bysnapp/settings/assignment_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:bysnapp/pages/members/member_edit_page.dart';
import 'package:bysnapp/pages/labels/label_edit_page.dart';
import 'package:bysnapp/pages/history/assignment_history_page.dart';
import 'dart:math';
import '../../services/assignment_firestore_service.dart';
import '../../services/group_firestore_service.dart';
import '../../services/group_data_sync_service.dart';
import '../../services/attendance_firestore_service.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../models/gamification_provider.dart';
import '../../services/experience_manager.dart';
import '../../widgets/lottie_animation_widget.dart';
import '../../models/dashboard_stats_provider.dart';
import '../../models/attendance_models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:bysnapp/utils/app_performance_config.dart';

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
  Timer? shuffleTimer;

  // 出勤退勤機能用
  List<AttendanceRecord> _todayAttendance = [];
  bool _isAttendanceLoading = true;

  // グループ同期用
  StreamSubscription<Map<String, dynamic>?>? _groupAssignmentSubscription;
  StreamSubscription<Map<String, dynamic>?>? _groupSettingsSubscription;
  StreamSubscription<Map<String, dynamic>?>? _groupTodayAssignmentSubscription;
  bool _isGroupDataLoaded = false;
  Timer? _autoSyncTimer;

  // Firestore同期用setter
  void setAssignmentMembersFromFirestore(Map<String, dynamic> members) {
    print('AssignmentBoard: setAssignmentMembersFromFirestore 呼び出し');
    print('AssignmentBoard: 受信データ: $members');
    if (mounted) {
      setState(() {
        // 新しい形式（teams）または古い形式（aMembers, bMembers）に対応
        if (members['teams'] != null) {
          final teamsList = members['teams'] as List;
          teams = teamsList.map((teamMap) => Team.fromMap(teamMap)).toList();
        } else {
          // 古い形式の場合は新しい形式に変換
          final aMembers = List<String>.from(members['aMembers'] ?? []);
          final bMembers = List<String>.from(members['bMembers'] ?? []);
          teams = [
            Team(id: 'team_a', name: 'A班', members: aMembers),
            Team(id: 'team_b', name: 'B班', members: bMembers),
          ];
        }

        if ((members['leftLabels'] as List?)?.isNotEmpty ?? false) {
          leftLabels = List<String>.from(members['leftLabels']);
        }
        if ((members['rightLabels'] as List?)?.isNotEmpty ?? false) {
          rightLabels = List<String>.from(members['rightLabels']);
        }
      });
    }

    // ローカルデータも更新
    _updateLocalData();

    print(
      'AssignmentBoard: 状態更新完了 - teams: ${teams.length}, leftLabels: $leftLabels, rightLabels: $rightLabels',
    );
  }

  /// ローカルデータを更新
  Future<void> _updateLocalData() async {
    // 新しい形式で保存
    final teamsJson = jsonEncode(teams.map((team) => team.toMap()).toList());
    await prefs.setString('teams', teamsJson);

    // 後方互換性のため、最初の2つの班をA班、B班としても保存
    if (teams.isNotEmpty) {
      await prefs.setStringList('a班', teams[0].members);
      if (teams.length > 1) {
        await prefs.setStringList('b班', teams[1].members);
      } else {
        await prefs.setStringList('b班', []);
      }
    }

    await prefs.setStringList('leftLabels', leftLabels);
    await prefs.setStringList('rightLabels', rightLabels);
    print('AssignmentBoard: ローカルデータ更新完了');
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

  @override
  void initState() {
    super.initState();
    _loadState();
    _loadTodayAttendance();
    _checkEditPermission();
    _initializeGroupMonitoring();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ページがフォーカスされた時にデータを再読み込み
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadState();
    });
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
      print('AssignmentBoard: 出勤退勤記録読み込みエラー: $e');
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
      print('AssignmentBoard: 出勤退勤状態更新エラー: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('出勤退勤状態の更新に失敗しました')));
    }
  }

  /// 出勤記録からXPを加算
  Future<void> _addAttendanceExperience() async {
    try {
      // ExperienceManagerでXPを加算
      final result = await ExperienceManager.instance.addAttendanceExperience(
        attendanceDate: DateTime.now(),
        isCheckIn: true,
      );

      if (mounted && result.success) {
        // GamificationProviderに通知
        final gamificationProvider = context.read<GamificationProvider>();
        gamificationProvider.refreshFromExperienceManager();

        // 成果表示
        _showAttendanceExperienceResult(result);
      }
    } catch (e) {
      print('出勤XP加算エラー: $e');
    }
  }

  /// 出勤XP獲得結果を表示（Lottieアニメーション付き）
  void _showAttendanceExperienceResult(ExperienceGainResult result) {
    if (!mounted) return;

    // レベルアップした場合はレベルアップアニメーションを優先
    if (result.leveledUp) {
      final badgeNames = result.newBadges.map((b) => b.name).toList();

      AnimationHelper.showLevelUpAnimation(
        context,
        oldLevel: result.oldProfile.level,
        newLevel: result.newLevel,
        newBadges: badgeNames,
        onComplete: () {
          // アニメーション完了後の処理
          if (mounted) {
            // 状態更新は既にExperienceManager内で完了している
          }
        },
      );
    } else if (result.xpGained > 0) {
      // 経験値獲得アニメーションを表示
      AnimationHelper.showExperienceGainAnimation(
        context,
        xpGained: result.xpGained,
        description: '出勤記録',
        onComplete: () {
          // アニメーション完了後の処理
          if (mounted) {
            // 必要に応じて追加の処理
          }
        },
      );
    }
  }

  /// グループ監視の初期化
  void _initializeGroupMonitoring() {
    print('AssignmentBoard: グループ監視初期化開始');
    // 既に監視中の場合は何もしない
    if (_groupAssignmentSubscription != null) {
      print('AssignmentBoard: 既にグループ監視中です');
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupProvider = context.read<GroupProvider>();
      _startGroupMonitoring(groupProvider);
    });
  }

  /// グループ監視を開始
  void _startGroupMonitoring(GroupProvider groupProvider) {
    print('AssignmentBoard: グループ監視開始');

    // 既存のサブスクリプションをクリーンアップ
    _groupAssignmentSubscription?.cancel();
    _groupSettingsSubscription?.cancel();
    _groupTodayAssignmentSubscription?.cancel();

    if (groupProvider.hasGroup) {
      final group = groupProvider.currentGroup!;
      print('AssignmentBoard: グループ監視開始 - groupId: ${group.id}');

      // グループの担当表データを監視
      _groupAssignmentSubscription =
          GroupDataSyncService.watchGroupAssignmentBoard(group.id).listen((
            groupAssignmentData,
          ) {
            if (!mounted) return; // ウィジェットが破棄されている場合は処理しない
            print('AssignmentBoard: グループ担当表データ変更検知: $groupAssignmentData');
            if (groupAssignmentData != null) {
              setAssignmentMembersFromFirestore(groupAssignmentData);
              _isGroupDataLoaded = true;
            }
          });

      // グループ設定を監視
      _groupSettingsSubscription =
          GroupDataSyncService.watchGroupSettings(group.id).listen((
            groupSettings,
          ) {
            if (!mounted) return; // ウィジェットが破棄されている場合は処理しない
            print('AssignmentBoard: グループ設定変更検知: $groupSettings');
            if (groupSettings != null) {
              _checkEditPermissionRealtime(groupProvider);
            }
          });

      // グループの今日の担当履歴を監視
      _groupTodayAssignmentSubscription =
          GroupDataSyncService.watchGroupTodayAssignment(group.id).listen((
            groupTodayAssignmentData,
          ) {
            if (!mounted) return; // ウィジェットが破棄されている場合は処理しない
            print(
              'AssignmentBoard: グループ今日の担当履歴変更検知: $groupTodayAssignmentData',
            );
            if (groupTodayAssignmentData != null &&
                groupTodayAssignmentData['assignments'] != null) {
              setAssignmentHistoryFromFirestore(
                List<String>.from(groupTodayAssignmentData['assignments']),
              );
            } else {
              // グループの今日の担当履歴が削除された場合
              setAssignmentHistoryFromFirestore([]);
            }
          });
    }
  }

  /// 担当表編集権限をチェック
  Future<void> _checkEditPermission() async {
    try {
      final groupProvider = context.read<GroupProvider>();
      final groups = groupProvider.groups;

      // 参加しているグループがあるかチェック
      if (groups.isNotEmpty) {
        // 最初のグループの権限をチェック（複数グループの場合は要改善）
        final group = groups.first;
        final canEdit = await GroupFirestoreService.canEditDataType(
          groupId: group.id,
          dataType: 'assignment_board',
        );
        setState(() {
          _canEditAssignment = canEdit;
        });
      } else {
        // グループ未参加時も編集可
        setState(() {
          _canEditAssignment = true;
        });
      }
    } catch (e) {
      // エラーの場合は編集可能として扱う（グループに参加していない場合など）
      setState(() {
        _canEditAssignment = true;
      });
    }
  }

  /// リアルタイムで権限をチェック（Consumer内で使用）
  void _checkEditPermissionRealtime(GroupProvider groupProvider) {
    if (!mounted) return; // ウィジェットが破棄されている場合は処理しない

    if (groupProvider.hasGroup) {
      final group = groupProvider.currentGroup!;
      GroupFirestoreService.canEditDataType(
            groupId: group.id,
            dataType: 'assignment_board',
          )
          .then((canEdit) {
            if (mounted && _canEditAssignment != canEdit) {
              setState(() {
                _canEditAssignment = canEdit;
              });
            }
          })
          .catchError((e) {
            // エラーの場合は編集可能として扱う
            if (mounted && _canEditAssignment != true) {
              setState(() {
                _canEditAssignment = true;
              });
            }
          });
    }
  }

  /// グループに担当表データを同期
  Future<void> _syncAssignmentToGroup() async {
    try {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.hasGroup) {
        final group = groupProvider.currentGroup!;
        print('AssignmentBoard: 担当表データをグループに同期開始 - groupId: ${group.id}');

        final assignmentData = {
          'teams': teams.map((team) => team.toMap()).toList(),
          'leftLabels': leftLabels,
          'rightLabels': rightLabels,
          'savedAt': DateTime.now().toIso8601String(),
        };

        await GroupDataSyncService.syncAssignmentBoard(
          group.id,
          assignmentData,
        );
        print('AssignmentBoard: 担当表データ同期完了');
      }
    } catch (e) {
      print('AssignmentBoard: 担当表データ同期エラー: $e');
    }
  }

  /// グループに今日の担当履歴を同期
  Future<void> _syncTodayAssignmentToGroup(List<String> assignments) async {
    try {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.hasGroup) {
        final group = groupProvider.currentGroup!;
        print('AssignmentBoard: 今日の担当履歴をグループに同期開始 - groupId: ${group.id}');

        final todayAssignmentData = {
          'assignments': assignments,
          'savedAt': DateTime.now().toIso8601String(),
        };

        await GroupDataSyncService.syncTodayAssignment(
          group.id,
          todayAssignmentData,
        );
        print('AssignmentBoard: 今日の担当履歴同期完了');
      }
    } catch (e) {
      print('AssignmentBoard: 今日の担当履歴同期エラー: $e');
    }
  }

  /// グループに担当履歴を同期
  Future<void> _syncAssignmentHistoryToGroup(
    String dateKey,
    List<String> assignments,
  ) async {
    try {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.hasGroup) {
        final group = groupProvider.currentGroup!;
        print(
          'AssignmentBoard: 担当履歴をグループに同期開始 - groupId: ${group.id}, dateKey: $dateKey',
        );

        final assignmentHistoryData = {
          dateKey: {
            'assignments': assignments,
            'savedAt': DateTime.now().toIso8601String(),
          },
        };

        await GroupDataSyncService.syncAssignmentHistory(
          group.id,
          assignmentHistoryData,
        );
        print('AssignmentBoard: 担当履歴同期完了');
      }
    } catch (e) {
      print('AssignmentBoard: 担当履歴同期エラー: $e');
    }
  }

  Future<void> _loadState() async {
    prefs = await SharedPreferences.getInstance();
    final groupProvider = context.read<GroupProvider>();
    // グループ状態ならグループデータのみ監視・利用
    if (groupProvider.groups.isNotEmpty) {
      // グループ監視はinitStateで既に開始されているため、ここでは何もしない
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }
    // 個人データ取得
    try {
      final assignmentMembers =
          await AssignmentFirestoreService.loadAssignmentMembers();
      if (assignmentMembers != null) {
        print('AssignmentBoard: Firestoreから担当表データを取得しました');
        setAssignmentMembersFromFirestore(assignmentMembers);
        // 今日の担当履歴も取得
        final today = _todayKey();
        final assignmentHistory =
            await AssignmentFirestoreService.loadAssignmentHistory(today);
        if (assignmentHistory != null && assignmentHistory.isNotEmpty) {
          setAssignmentHistoryFromFirestore(assignmentHistory);
        }
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      print('AssignmentBoard: Firestoreからのデータ取得に失敗しました: $e');
    }
    // Firestoreからデータを取得できなかった場合はローカルデータを使用
    print('AssignmentBoard: ローカルデータを使用します');

    // 新しい形式で班データを読み込み
    final teamsJson = prefs.getString('teams');
    if (teamsJson != null) {
      final teamsList = jsonDecode(teamsJson) as List;
      teams = teamsList.map((teamMap) => Team.fromMap(teamMap)).toList();
    } else {
      // 既存のA班、B班データを新しい形式に変換
      final loadedA = prefs.getStringList('a班') ?? [];
      final loadedB = prefs.getStringList('b班') ?? [];
      teams = [
        Team(id: 'team_a', name: 'A班', members: loadedA),
        Team(id: 'team_b', name: 'B班', members: loadedB),
      ];
    }

    final loadedLeft = prefs.getStringList('leftLabels') ?? [];
    final loadedRight = prefs.getStringList('rightLabels') ?? [];

    final today = _todayKey();
    final savedDate = prefs.getString('assignedDate');
    final assignedPairs = prefs.getStringList('assignment_$today');

    // 今日の担当履歴が実際に存在し、かつ日付も一致する場合のみ決定済みとする
    final wasAssigned =
        savedDate == today && assignedPairs != null && assignedPairs.isNotEmpty;

    // 今日の担当履歴があれば適用
    if (wasAssigned &&
        assignedPairs.length == loadedLeft.length &&
        teams.length >= 2) {
      for (int i = 0; i < teams.length; i++) {
        final newTeamMembers = assignedPairs
            .map((e) => e.split('-')[i])
            .toList();
        teams[i] = teams[i].copyWith(members: newTeamMembers);
      }
    }

    if (mounted) {
      setState(() {
        // ラベルは常に保存値を反映（メンバーが空でも消さない）
        leftLabels = loadedLeft;
        rightLabels = loadedRight;
        isAssignedToday = wasAssigned && !_isWeekend();
        _isLoading = false;
      });
    }
  }

  String _todayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  String _dayKeyAgo(int d) => DateFormat(
    'yyyy-MM-dd',
  ).format(DateTime.now().subtract(Duration(days: d)));

  bool _isWeekend() {
    final wd = DateTime.now().weekday;
    final devMode = prefs.getBool('developerMode') ?? false;
    if (devMode) return false;
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
    if (old == null) return false;
    return newPairs.any(old.contains);
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
        final p1 = prefs.getStringList('assignment_$y1');
        final p2 = prefs.getStringList('assignment_$y2');

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

        await prefs.setStringList('assignment_$today', pairs);
        await prefs.setString('assignedDate', today);

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
          print('AssignmentBoard: 担当履歴をFirestoreに保存完了');
        } catch (e) {
          print('AssignmentBoard: 担当履歴のFirestore保存エラー: $e');
        }

        // グループに同期（グループ参加時のみ）
        _syncTodayAssignmentToGroup(pairs);
        // 担当決定後に広告を表示
        _showInterstitialAdAfterAssignment();
      }
    });
  }

  /// 今日の担当をリセット
  Future<void> _resetTodayAssignment() async {
    final today = _todayKey();

    // ローカルデータをリセット
    await prefs.remove('assignment_$today');
    await prefs.remove('assignedDate');

    // 元のメンバー構成に戻す
    await _loadState();

    // Firestoreからも削除
    try {
      await AssignmentFirestoreService.deleteAssignmentHistory(today);

      // グループにも同期
      try {
        final groupProvider = context.read<GroupProvider>();
        if (groupProvider.hasGroup) {
          final group = groupProvider.currentGroup!;
          print('AssignmentBoard: 今日の担当履歴をグループから削除開始 - groupId: ${group.id}');

          final assignmentHistoryData = {
            today: {
              'deleted': true,
              'savedAt': DateTime.now().toIso8601String(),
            },
          };

          await GroupDataSyncService.syncAssignmentHistory(
            group.id,
            assignmentHistoryData,
          );
          print('AssignmentBoard: 今日の担当履歴削除完了');
        }
      } catch (e) {
        print('AssignmentBoard: グループからの今日の担当履歴削除エラー: $e');
      }
    } catch (e) {
      print('AssignmentBoard: Firestoreからの今日の担当履歴削除エラー: $e');
    }

    setState(() {
      isAssignedToday = false;
    });
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
        // グループデータの監視状態を確認
        if (groupProvider.hasGroup && !groupProvider.isWatchingGroupData) {
          // グループデータの監視を開始
          WidgetsBinding.instance.addPostFrameCallback((_) {
            groupProvider.startWatchingGroupData();
          });
        }

        // 権限チェックを実行
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _checkEditPermissionRealtime(groupProvider);
            }
          });
        }

        if (_isLoading) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final todayIsWeekend = _isWeekend();
        final isDev = prefs.getBool('developerMode') ?? false;
        final isButtonDisabled =
            todayIsWeekend && !isDev || isAssignedToday || isShuffling;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Icon(
                  Icons.group,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                ),
                SizedBox(width: 8),
                Text('担当表'),
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
            actions: [
              IconButton(
                icon: Icon(Icons.person_add),
                tooltip: 'メンバー編集',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MemberEditPage()),
                  );
                  // メンバー編集ページから戻った時にデータを再読み込み
                  _loadState();
                },
              ),
              IconButton(
                icon: Icon(Icons.label),
                tooltip: 'ラベル編集',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => LabelEditPage()),
                  );
                  // ラベル編集ページから戻った時にデータを再読み込み
                  _loadState();
                },
              ),
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
                      color:
                          Provider.of<ThemeSettings>(
                            context,
                          ).backgroundColor2 ??
                          Colors.grey[100],
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
                  if (_canEditAssignment != null && _canEditAssignment == true)
                    ElevatedButton(
                      onPressed: isButtonDisabled ? null : _shuffleAssignments,
                      child: Text(() {
                        if (todayIsWeekend && !isDev) return '土日は休み';
                        if (isAssignedToday) return '今日はすでに決定済み';
                        if (isShuffling) return 'シャッフル中...';
                        return '今日の担当を決める';
                      }()),
                    )
                  else
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
      cardColor =
          Provider.of<ThemeSettings>(context).backgroundColor2 ??
          Colors.grey[300]!;
      textColor = Colors.grey[600];
      borderColor = Colors.grey[400] ?? Colors.grey.shade400 ?? Colors.black;
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
          color: cardColor ?? Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor ?? Colors.black, width: 2),
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
                color: textColor ?? Colors.black,
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
