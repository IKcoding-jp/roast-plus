import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../services/assignment_firestore_service.dart';
import '../../services/group_data_sync_service.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../services/user_settings_firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class MemberEditPage extends StatefulWidget {
  const MemberEditPage({super.key});

  @override
  State<MemberEditPage> createState() => _MemberEditPageState();
}

class _MemberEditPageState extends State<MemberEditPage> {
  List<Team> teams = [];
  List<String> leftLabels = [];
  List<String> rightLabels = [];
  late SharedPreferences prefs;

  // コントローラーを管理
  final Map<String, TextEditingController> _teamNameControllers = {};
  final Map<String, TextEditingController> _memberControllers = {};

  // グループメンバーリスト
  List<GroupMember> _groupMembers = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _loadAssignmentMembersFromFirestore();
    _startAssignmentMembersListener();
    _loadGroupMembers();

    // グループメンバー読み込み後にクリーンアップを実行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cleanupTeamData();
    });

    // 初期化後に強制クリーンアップを実行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _forceCleanupOldData();
    });
  }

  /// グループメンバーを読み込み
  void _loadGroupMembers() {
    final groupProvider = context.read<GroupProvider>();
    if (groupProvider.hasGroup) {
      setState(() {
        // 重複を除去してグループメンバーを読み込み
        final uniqueMembers = <String, GroupMember>{};
        for (final member in groupProvider.currentGroup!.members) {
          if (!uniqueMembers.containsKey(member.displayName)) {
            uniqueMembers[member.displayName] = member;
          }
        }
        _groupMembers = uniqueMembers.values.toList();
      });
      developer.log(
        'グループメンバー読み込み完了: ${_groupMembers.length}人（重複除去後）',
        name: 'MemberEditPage',
      );

      // グループメンバー更新後にクリーンアップを実行
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cleanupTeamData();
      });
    }
  }

  Future<void> _loadAssignmentMembersFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('assignmentMembers')
        .doc('assignment')
        .get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      if (mounted) {
        setState(() {
          if (data['teams'] != null) {
            teams = List<Map<String, dynamic>>.from(
              data['teams'],
            ).map((teamMap) => Team.fromMap(teamMap)).toList();
          } else {
            // 古い形式の場合は新しい形式に変換
            final aMembers = List<String>.from(data['aMembers'] ?? []);
            final bMembers = List<String>.from(data['bMembers'] ?? []);
            teams = [
              Team(id: 'team_a', name: 'A班', members: aMembers),
              Team(id: 'team_b', name: 'B班', members: bMembers),
            ];
          }
          if ((data['leftLabels'] as List?)?.isNotEmpty ?? false) {
            leftLabels = List<String>.from(data['leftLabels']);
          }
          if ((data['rightLabels'] as List?)?.isNotEmpty ?? false) {
            rightLabels = List<String>.from(data['rightLabels']);
          }
          if (teams.isEmpty) {
            teams = [
              Team(id: 'team_a', name: 'A班', members: []),
              Team(id: 'team_b', name: 'B班', members: []),
            ];
          }
        });
      }
    } else {
      if (mounted) {
        setState(() {
          teams = [
            Team(id: 'team_a', name: 'A班', members: []),
            Team(id: 'team_b', name: 'B班', members: []),
          ];
        });
      }
    }
  }

  StreamSubscription? _assignmentMembersSubscription;
  void _startAssignmentMembersListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _assignmentMembersSubscription?.cancel();
    _assignmentMembersSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('assignmentMembers')
        .doc('assignment')
        .snapshots()
        .listen((doc) {
          if (!mounted) return; // ウィジェットが破棄されている場合は処理しない
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            setState(() {
              if (data['teams'] != null) {
                teams = List<Map<String, dynamic>>.from(
                  data['teams'],
                ).map((teamMap) => Team.fromMap(teamMap)).toList();
              } else {
                final aMembers = List<String>.from(data['aMembers'] ?? []);
                final bMembers = List<String>.from(data['bMembers'] ?? []);
                teams = [
                  Team(id: 'team_a', name: 'A班', members: aMembers),
                  Team(id: 'team_b', name: 'B班', members: bMembers),
                ];
              }
              if ((data['leftLabels'] as List?)?.isNotEmpty ?? false) {
                leftLabels = List<String>.from(data['leftLabels']);
              }
              if ((data['rightLabels'] as List?)?.isNotEmpty ?? false) {
                rightLabels = List<String>.from(data['rightLabels']);
              }
              if (teams.isEmpty) {
                teams = [Team(id: 'team_default', name: '新しい班', members: [])];
              }

              // コントローラーを初期化
              _initializeControllers();
            });
          }
        });
  }

  @override
  void dispose() {
    _assignmentMembersSubscription?.cancel();
    // コントローラーを破棄
    for (var controller in _teamNameControllers.values) {
      controller.dispose();
    }
    for (var controller in _memberControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      // Firebaseから既存のデータを読み込み（後方互換性のため）
      final settings = await UserSettingsFirestoreService.getMultipleSettings([
        'assignment_team_a',
        'assignment_team_b',
        'leftLabels',
        'rightLabels',
        'teams',
      ]);

      leftLabels = settings['leftLabels'] ?? [];
      rightLabels = settings['rightLabels'] ?? [];

      // 班のデータを読み込み
      final teamsJson = settings['teams'];
      if (teamsJson != null) {
        final teamsList = teamsJson;
        teams = teamsList.map((teamMap) => Team.fromMap(teamMap)).toList();
      } else {
        teams = [];
      }

      // コントローラーを初期化
      _initializeControllers();

      // 初期値セットは削除（Firestore取得後に行う）
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      developer.log('メンバー読み込みエラー: $e', name: 'MemberEditPage', error: e);
      if (mounted) {
        setState(() {});
      }
    }
  }

  /// コントローラーを初期化
  void _initializeControllers() {
    // 既存のコントローラーを破棄
    for (var controller in _teamNameControllers.values) {
      controller.dispose();
    }
    for (var controller in _memberControllers.values) {
      controller.dispose();
    }
    _teamNameControllers.clear();
    _memberControllers.clear();

    // 新しいコントローラーを作成
    for (int i = 0; i < teams.length; i++) {
      final team = teams[i];
      _teamNameControllers[team.id] = TextEditingController(text: team.name);

      for (int j = 0; j < team.members.length; j++) {
        final memberKey = '${team.id}_$j';
        _memberControllers[memberKey] = TextEditingController(
          text: team.members[j],
        );
      }
    }
  }

  Future<void> _saveMembers() async {
    final messenger = ScaffoldMessenger.of(context);
    final groupProvider = context.read<GroupProvider>();
    try {
      // 現在のラベルデータを取得（既存のデータを保持）
      final currentSettings =
          await UserSettingsFirestoreService.getMultipleSettings([
            'leftLabels',
            'rightLabels',
          ]);

      final currentLeftLabels = List<String>.from(
        currentSettings['leftLabels'] ?? [],
      );
      final currentRightLabels = List<String>.from(
        currentSettings['rightLabels'] ?? [],
      );

      // 新しい形式で保存（ラベルは既存のデータを保持）
      final teamsJson = teams.map((team) => team.toMap()).toList();
      await UserSettingsFirestoreService.saveMultipleSettings({
        'teams': teamsJson,
        'leftLabels': currentLeftLabels,
        'rightLabels': currentRightLabels,
      });

      // 後方互換性のため、最初の2つの班をA班、B班としても保存
      if (teams.isNotEmpty) {
        await UserSettingsFirestoreService.saveMultipleSettings({
          'assignment_team_a': teams[0].members,
          'assignment_team_b': teams.length > 1 ? teams[1].members : [],
        });
      }
    } catch (e) {
      developer.log('メンバー保存エラー: $e', name: 'MemberEditPage', error: e);
    }

    // 新しい形式でローカルに保存
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

    // Firestoreにも保存（ラベルは既存のデータを保持）
    await AssignmentFirestoreService.saveAssignmentMembers(
      aMembers: teams.isNotEmpty ? teams[0].members : [],
      bMembers: teams.length > 1 ? teams[1].members : [],
      leftLabels: leftLabels, // 現在のラベルデータを使用
      rightLabels: rightLabels, // 現在のラベルデータを使用
    );

    // グループに同期
    try {
      if (groupProvider.groups.isNotEmpty) {
        final group = groupProvider.groups.first;
        developer.log(
          '担当表データをグループに同期開始 - groupId: ${group.id}',
          name: 'MemberEditPage',
        );

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
        developer.log('担当表データ同期完了', name: 'MemberEditPage');
      }
    } catch (e) {
      developer.log('担当表データ同期エラー: $e', name: 'MemberEditPage', error: e);
    }

    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('メンバー保存しました')));
  }

  void _addTeam() {
    final newId = 'team_${DateTime.now().millisecondsSinceEpoch}';
    // 既存の班数に応じてアルファベットを決定
    final alphabet = String.fromCharCode('A'.codeUnitAt(0) + teams.length);
    final newName = '$alphabet班';
    setState(() {
      teams.add(Team(id: newId, name: newName, members: []));
    });
    _adjustLabelsToTeams();
  }

  void _deleteTeam(int index) {
    setState(() {
      teams.removeAt(index);
    });
    _adjustLabelsToTeams();
  }

  void _updateTeamName(int index, String name) {
    setState(() {
      teams[index] = teams[index].copyWith(name: name);
    });
  }

  void _addMember(int teamIndex) {
    setState(() {
      teams[teamIndex] = teams[teamIndex].copyWith(
        members: [...teams[teamIndex].members, ''],
      );
    });

    // 新しいメンバーのコントローラーを追加
    final team = teams[teamIndex];
    final memberIndex = team.members.length - 1;
    final memberKey = '${team.id}_$memberIndex';
    _memberControllers[memberKey] = TextEditingController(text: '');

    _adjustLabelsToTeams();
  }

  void _deleteMember(int teamIndex, int memberIndex) {
    final team = teams[teamIndex];

    // 削除するメンバーのコントローラーを破棄
    final memberKey = '${team.id}_$memberIndex';
    _memberControllers[memberKey]?.dispose();
    _memberControllers.remove(memberKey);

    // 後続のメンバーのコントローラーキーを更新
    for (int i = memberIndex + 1; i < team.members.length; i++) {
      final oldKey = '${team.id}_$i';
      final newKey = '${team.id}_${i - 1}';
      if (_memberControllers.containsKey(oldKey)) {
        _memberControllers[newKey] = _memberControllers.remove(oldKey)!;
      }
    }

    setState(() {
      final newMembers = List<String>.from(teams[teamIndex].members);
      newMembers.removeAt(memberIndex);
      teams[teamIndex] = teams[teamIndex].copyWith(members: newMembers);
    });
    _adjustLabelsToTeams();
  }

  void _updateMember(int teamIndex, int memberIndex, String value) {
    setState(() {
      final newMembers = List<String>.from(teams[teamIndex].members);
      newMembers[memberIndex] = value;
      teams[teamIndex] = teams[teamIndex].copyWith(members: newMembers);
    });
  }

  /// グループメンバーから選択してメンバーを更新
  void _selectGroupMember(
    int teamIndex,
    int memberIndex,
    String? selectedMemberName,
  ) {
    if (selectedMemberName != null) {
      _updateMember(teamIndex, memberIndex, selectedMemberName);
    }
  }

  /// 班データをクリーンアップ（無効なメンバー名を削除）
  void _cleanupTeamData() {
    final groupProvider = context.read<GroupProvider>();
    if (!groupProvider.hasGroup) return;

    // 有効なグループメンバー名のリストを作成
    final validMemberNames = _groupMembers.map((m) => m.displayName).toSet();

    bool hasChanges = false;

    for (int teamIndex = 0; teamIndex < teams.length; teamIndex++) {
      final team = teams[teamIndex];
      final validMembers = <String>[];

      for (final memberName in team.members) {
        if (validMemberNames.contains(memberName)) {
          validMembers.add(memberName);
        } else {
          hasChanges = true;
          developer.log('無効なメンバー名を削除: $memberName', name: 'MemberEditPage');
        }
      }

      if (hasChanges) {
        teams[teamIndex] = team.copyWith(members: validMembers);
      }
    }

    if (hasChanges) {
      setState(() {});
      developer.log('班データのクリーンアップ完了', name: 'MemberEditPage');

      // クリーンアップ後にデータを保存
      _saveMembers();
    }
  }

  /// 強制クリーンアップ（古いデータを完全に削除）
  Future<void> _forceCleanupOldData() async {
    try {
      developer.log('強制クリーンアップ開始', name: 'MemberEditPage');

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
            developer.log(
              '強制クリーンアップ: 無効なメンバー名を削除: $memberName',
              name: 'MemberEditPage',
            );
          }
        }

        cleanedTeams.add(team.copyWith(members: validMembers));
      }

      if (hasChanges) {
        setState(() {
          teams = cleanedTeams;
        });
        developer.log('強制クリーンアップ完了', name: 'MemberEditPage');

        // クリーンアップ後のデータを保存
        await _saveMembers();
      } else {
        developer.log('強制クリーンアップ: 変更なし', name: 'MemberEditPage');
      }
    } catch (e) {
      developer.log('強制クリーンアップエラー: $e', name: 'MemberEditPage', error: e);
    }
  }

  /// ドロップダウンの有効な値を取得
  String? _getValidDropdownValue(String currentValue) {
    if (currentValue.isEmpty) return null;

    // 現在の値がグループメンバーに存在するかチェック
    final isValid = _groupMembers.any(
      (member) => member.displayName == currentValue,
    );
    return isValid ? currentValue : null;
  }

  /// 選択可能なメンバーリストを取得（既に選択済みのメンバーを除外）
  List<GroupMember> _getAvailableMembers(
    int currentTeamIndex,
    int currentMemberIndex,
  ) {
    // 現在のメンバーが選択している値を取得
    final currentValue = teams[currentTeamIndex].members[currentMemberIndex];

    // すべての班で既に選択されているメンバー名を収集
    final selectedMemberNames = <String>{};
    for (int teamIndex = 0; teamIndex < teams.length; teamIndex++) {
      for (
        int memberIndex = 0;
        memberIndex < teams[teamIndex].members.length;
        memberIndex++
      ) {
        final memberName = teams[teamIndex].members[memberIndex];
        if (memberName.isNotEmpty) {
          // 現在のメンバー自身は除外（自分自身は選択可能）
          if (!(teamIndex == currentTeamIndex &&
              memberIndex == currentMemberIndex)) {
            selectedMemberNames.add(memberName);
          }
        }
      }
    }

    // 選択済みでないメンバーのみを返す
    return _groupMembers
        .where(
          (member) =>
              !selectedMemberNames.contains(member.displayName) ||
              member.displayName == currentValue,
        )
        .toList();
  }

  void _adjustLabelsToTeams() {
    // 班の数に応じてラベルを調整
    final maxTeamSize = teams.fold<int>(
      0,
      (max, team) => team.members.length > max ? team.members.length : max,
    );

    // 左ラベルを調整
    while (leftLabels.length < maxTeamSize) {
      leftLabels.add('');
    }
    if (leftLabels.length > maxTeamSize) {
      leftLabels = leftLabels.take(maxTeamSize).toList();
    }

    // 右ラベルを調整
    while (rightLabels.length < maxTeamSize) {
      rightLabels.add('');
    }
    if (rightLabels.length > maxTeamSize) {
      rightLabels = rightLabels.take(maxTeamSize).toList();
    }
  }

  Widget _buildTeamCard(Team team, int teamIndex) {
    final groupProvider = context.read<GroupProvider>();

    return Card(
      elevation: 4,
      color: Provider.of<ThemeSettings>(context).cardBackgroundColor,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _teamNameControllers[team.id],
                    style: TextStyle(
                      color: Provider.of<ThemeSettings>(context).fontColor1,
                    ),
                    decoration: InputDecoration(
                      labelText: '班名',
                      labelStyle: TextStyle(
                        color: Provider.of<ThemeSettings>(context).fontColor1,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(
                        Icons.group,
                        color: Provider.of<ThemeSettings>(context).iconColor,
                      ),
                      filled: true,
                      fillColor: Provider.of<ThemeSettings>(
                        context,
                      ).inputBackgroundColor,
                    ),
                    onChanged: (value) => _updateTeamName(teamIndex, value),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.add, color: Colors.green),
                  onPressed: () => _addMember(teamIndex),
                ),
                if (teams.length > 1)
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteTeam(teamIndex),
                  ),
              ],
            ),
            SizedBox(height: 12),

            ...List.generate(team.members.length, (memberIndex) {
              final memberKey = '${team.id}_$memberIndex';

              if (groupProvider.hasGroup) {
                // グループモード：プルダウンで選択
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).inputBackgroundColor,
                          ),
                          child: DropdownButtonFormField<String>(
                            initialValue: _getValidDropdownValue(
                              team.members[memberIndex],
                            ),
                            isExpanded: true, // 幅を親要素に合わせる
                            decoration: InputDecoration(
                              labelText: 'メンバーを選択',
                              labelStyle: TextStyle(
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).fontColor1,
                              ),
                              border: InputBorder.none,
                              prefixIcon: Icon(
                                Icons.person_outline,
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).iconColor,
                              ),
                            ),
                            items: [
                              DropdownMenuItem<String>(
                                value: null,
                                child: Text(
                                  'メンバーを選択してください',
                                  style: TextStyle(color: Colors.grey),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ..._getAvailableMembers(
                                teamIndex,
                                memberIndex,
                              ).map((member) {
                                return DropdownMenuItem<String>(
                                  value: member.displayName,
                                  child: Text(
                                    member.displayName,
                                    style: TextStyle(
                                      color: Provider.of<ThemeSettings>(
                                        context,
                                      ).fontColor1,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (value) => _selectGroupMember(
                              teamIndex,
                              memberIndex,
                              value,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteMember(teamIndex, memberIndex),
                      ),
                    ],
                  ),
                );
              } else {
                // 通常モード：手動入力
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _memberControllers[memberKey],
                          style: TextStyle(
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).fontColor1,
                          ),
                          decoration: InputDecoration(
                            labelText: '名前',
                            labelStyle: TextStyle(
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).fontColor1,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).iconColor,
                            ),
                            filled: true,
                            fillColor: Provider.of<ThemeSettings>(
                              context,
                            ).inputBackgroundColor,
                          ),
                          onChanged: (value) =>
                              _updateMember(teamIndex, memberIndex, value),
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteMember(teamIndex, memberIndex),
                      ),
                    ],
                  ),
                );
              }
            }),
            SizedBox(height: 8),
            Text(
              'メンバー数: ${team.members.length}人',
              style: TextStyle(
                color: Provider.of<ThemeSettings>(context).fontColor2,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('メンバー編集'),
            Consumer<GroupProvider>(
              builder: (context, groupProvider, _) {
                if (groupProvider.groups.isNotEmpty) {
                  return Container(
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
                  );
                } else {
                  return SizedBox.shrink();
                }
              },
            ),
          ],
        ),
        actions: [IconButton(icon: Icon(Icons.save), onPressed: _saveMembers)],
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: kIsWeb ? 800 : double.infinity,
            ),
            child: ListView(
              padding: EdgeInsets.all(kIsWeb ? 24 : 16),
              children: [
                // 班一覧
                ...List.generate(teams.length, (index) {
                  return Column(
                    children: [
                      _buildTeamCard(teams[index], index),
                      if (index < teams.length - 1)
                        SizedBox(height: kIsWeb ? 20 : 16),
                    ],
                  );
                }),
                SizedBox(height: kIsWeb ? 20 : 16),
                // 班追加ボタン（一番下に配置）
                Card(
                  elevation: 4,
                  color: Provider.of<ThemeSettings>(
                    context,
                  ).cardBackgroundColor,
                  child: InkWell(
                    onTap: _addTeam,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            color: Colors.green,
                            size: 24,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '班を追加',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
