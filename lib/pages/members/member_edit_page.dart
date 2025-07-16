import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../services/assignment_firestore_service.dart';
import '../../services/group_data_sync_service.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
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
        .collection('settings')
        .doc('assignmentMembers')
        .get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      setState(() {
        if (data['teams'] != null) {
          teams = List<Map<String, dynamic>>.from(
            data['teams'],
          ).map((teamMap) => Team.fromMap(teamMap)).toList();
        }
        if (data['leftLabels'] != null) {
          leftLabels = List<String>.from(data['leftLabels']);
        }
        if (data['rightLabels'] != null) {
          rightLabels = List<String>.from(data['rightLabels']);
        }
        // Firestoreにデータがなければ初期値をセット
        if ((data['teams'] == null || teams.isEmpty)) {
          teams = [Team(id: 'team_default', name: '新しい班', members: [])];
        }
      });
    } else {
      // Firestoreにデータがなければ初期値をセット
      setState(() {
        teams = [Team(id: 'team_default', name: '新しい班', members: [])];
      });
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
        .collection('settings')
        .doc('assignmentMembers')
        .snapshots()
        .listen((doc) {
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            setState(() {
              // ここでteams, leftLabels, rightLabelsをFirestoreのデータで上書き
              if (data['teams'] != null) {
                teams = List<Map<String, dynamic>>.from(
                  data['teams'],
                ).map((teamMap) => Team.fromMap(teamMap)).toList();
              }
              if (data['leftLabels'] != null) {
                leftLabels = List<String>.from(data['leftLabels']);
              }
              if (data['rightLabels'] != null) {
                rightLabels = List<String>.from(data['rightLabels']);
              }
            });
          }
        });
  }

  @override
  void dispose() {
    _assignmentMembersSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    prefs = await SharedPreferences.getInstance();

    // 既存のデータを読み込み（後方互換性のため）
    final aMembers = prefs.getStringList('a班') ?? [];
    final bMembers = prefs.getStringList('b班') ?? [];
    leftLabels = prefs.getStringList('leftLabels') ?? [];
    rightLabels = prefs.getStringList('rightLabels') ?? [];

    // 班のデータを読み込み
    final teamsJson = prefs.getString('teams');
    if (teamsJson != null) {
      final teamsList = jsonDecode(teamsJson) as List;
      teams = teamsList.map((teamMap) => Team.fromMap(teamMap)).toList();
    } else {
      teams = [];
    }

    // 初期値セットは削除（Firestore取得後に行う）
    setState(() {});
  }

  Future<void> _saveMembers() async {
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

    // ラベルも保存
    await prefs.setStringList('leftLabels', leftLabels);
    await prefs.setStringList('rightLabels', rightLabels);

    // Firestoreにも保存
    await AssignmentFirestoreService.saveAssignmentMembers(
      aMembers: teams.isNotEmpty ? teams[0].members : [],
      bMembers: teams.length > 1 ? teams[1].members : [],
      leftLabels: leftLabels,
      rightLabels: rightLabels,
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
    setState(() {
      teams.add(Team(id: newId, name: '新しい班', members: []));
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
    _adjustLabelsToTeams();
  }

  void _deleteMember(int teamIndex, int memberIndex) {
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
                    initialValue: team.name,
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
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: team.members[memberIndex],
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
        title: Text('メンバー編集'),
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
