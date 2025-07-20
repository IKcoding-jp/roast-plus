import 'package:flutter/material.dart';
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
  _MemberEditPageState createState() => _MemberEditPageState();
}

class _MemberEditPageState extends State<MemberEditPage> {
  List<Team> teams = [];
  List<String> leftLabels = [];
  List<String> rightLabels = [];
  late SharedPreferences prefs;

  // コントローラーを管理
  Map<String, TextEditingController> _teamNameControllers = {};
  Map<String, TextEditingController> _memberControllers = {};

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _loadAssignmentMembersFromFirestore();
    _startAssignmentMembersListener();
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
    _teamNameControllers.values.forEach((controller) => controller.dispose());
    _memberControllers.values.forEach((controller) => controller.dispose());
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

      final aMembers = settings['assignment_team_a'] ?? [];
      final bMembers = settings['assignment_team_b'] ?? [];
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
      print('メンバー読み込みエラー: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  /// コントローラーを初期化
  void _initializeControllers() {
    // 既存のコントローラーを破棄
    _teamNameControllers.values.forEach((controller) => controller.dispose());
    _memberControllers.values.forEach((controller) => controller.dispose());
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
      print('メンバー保存エラー: $e');
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
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.groups.isNotEmpty) {
        final group = groupProvider.groups.first;
        print('MemberEditPage: 担当表データをグループに同期開始 - groupId: ${group.id}');

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
        print('MemberEditPage: 担当表データ同期完了');
      }
    } catch (e) {
      print('MemberEditPage: 担当表データ同期エラー: $e');
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('メンバー保存しました')));
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

  void _adjustLabelsToTeams() {
    // 最大メンバー数に合わせてラベル数を調整
    final maxMembers = teams.fold<int>(
      0,
      (max, team) => team.members.length > max ? team.members.length : max,
    );
    final currentLabels = leftLabels.length;

    if (maxMembers < currentLabels) {
      // メンバー数が少ない場合、ラベルを削除
      setState(() {
        leftLabels = leftLabels.take(maxMembers).toList();
        rightLabels = rightLabels.take(maxMembers).toList();
      });
    } else if (maxMembers > currentLabels) {
      // メンバー数が多い場合、ラベルを追加
      setState(() {
        while (leftLabels.length < maxMembers) {
          leftLabels.add('');
          rightLabels.add('');
        }
      });
    }
  }

  Widget _buildTeamCard(Team team, int teamIndex) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color:
          Provider.of<ThemeSettings>(context).backgroundColor2 ?? Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.group,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _teamNameControllers[team.id],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Provider.of<ThemeSettings>(context).fontColor1,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) => _updateTeamName(teamIndex, value),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteTeam(teamIndex),
                ),
              ],
            ),
            SizedBox(height: 12),
            ...List.generate(team.members.length, (memberIndex) {
              final memberKey = '${team.id}_$memberIndex';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _memberControllers[memberKey],
                        style: TextStyle(
                          color: Provider.of<ThemeSettings>(context).fontColor1,
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
            }),
            SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.add),
                label: Text('メンバー追加'),
                onPressed: () => _addMember(teamIndex),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context)
                          .elevatedButtonTheme
                          .style
                          ?.backgroundColor
                          ?.resolve({}) ??
                      Theme.of(context).colorScheme.primary,
                  foregroundColor:
                      Theme.of(context)
                          .elevatedButtonTheme
                          .style
                          ?.foregroundColor
                          ?.resolve({}) ??
                      Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 14),
                ),
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
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // 班一覧
            ...List.generate(teams.length, (index) {
              return Column(
                children: [
                  _buildTeamCard(teams[index], index),
                  if (index < teams.length - 1) SizedBox(height: 16),
                ],
              );
            }),
            SizedBox(height: 16),
            // 班追加ボタン（一番下に配置）
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color:
                  Provider.of<ThemeSettings>(context).backgroundColor2 ??
                  Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.add_business),
                    label: Text('新しい班を追加'),
                    onPressed: _addTeam,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Provider.of<ThemeSettings>(
                        context,
                      ).buttonColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
