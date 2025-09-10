import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../models/theme_settings.dart';
import '../../services/group_data_sync_service.dart';
import '../../models/group_provider.dart';
import '../../services/assignment_firestore_service.dart';
import '../../services/user_settings_firestore_service.dart';
import 'dart:async';

class LabelEditPage extends StatefulWidget {
  const LabelEditPage({super.key});

  @override
  LabelEditPageState createState() => LabelEditPageState();
}

class LabelEditPageState extends State<LabelEditPage> {
  List<String> leftLabels = [];
  List<String> rightLabels = [];
  List<String> aMembers = [];
  List<String> bMembers = [];

  // コントローラーを管理
  final List<TextEditingController> _leftLabelControllers = [];
  final List<TextEditingController> _rightLabelControllers = [];

  // グループ同期用
  StreamSubscription<Map<String, dynamic>?>? _groupAssignmentSubscription;

  @override
  void initState() {
    super.initState();
    _loadLabels();
    _initializeGroupMonitoring();
  }

  @override
  void dispose() {
    // コントローラーを破棄
    for (var controller in _leftLabelControllers) {
      controller.dispose();
    }
    for (var controller in _rightLabelControllers) {
      controller.dispose();
    }
    _groupAssignmentSubscription?.cancel();
    super.dispose();
  }

  /// グループ監視の初期化
  void _initializeGroupMonitoring() {
    developer.log('グループ監視初期化開始', name: 'LabelEditPage');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupProvider = context.read<GroupProvider>();
      _startGroupMonitoring(groupProvider);
    });
  }

  /// グループ監視を開始
  void _startGroupMonitoring(GroupProvider groupProvider) {
    developer.log('グループ監視開始', name: 'LabelEditPage');

    // 既存のサブスクリプションをクリーンアップ
    _groupAssignmentSubscription?.cancel();

    if (groupProvider.hasGroup) {
      final group = groupProvider.currentGroup!;
      developer.log('グループ監視開始 - groupId: ${group.id}', name: 'LabelEditPage');

      // グループの担当表データを監視
      _groupAssignmentSubscription =
          GroupDataSyncService.watchGroupAssignmentBoard(group.id).listen((
            groupAssignmentData,
          ) {
            if (!mounted) return; // ウィジェットが破棄されている場合は処理しない
            developer.log(
              'グループ担当表データ変更検知: $groupAssignmentData',
              name: 'LabelEditPage',
            );
            if (groupAssignmentData != null) {
              setState(() {
                if (groupAssignmentData['leftLabels'] != null) {
                  leftLabels = List<String>.from(
                    groupAssignmentData['leftLabels'],
                  );
                }
                if (groupAssignmentData['rightLabels'] != null) {
                  rightLabels = List<String>.from(
                    groupAssignmentData['rightLabels'],
                  );
                }
                if (groupAssignmentData['aMembers'] != null) {
                  aMembers = List<String>.from(groupAssignmentData['aMembers']);
                }
                if (groupAssignmentData['bMembers'] != null) {
                  bMembers = List<String>.from(groupAssignmentData['bMembers']);
                }

                // コントローラーを再初期化
                _initializeControllers();
              });
            }
          });
    }
  }

  Future<void> _loadLabels() async {
    try {
      final settings = await UserSettingsFirestoreService.getMultipleSettings([
        'leftLabels',
        'rightLabels',
        'a班',
        'b班',
      ]);

      if (mounted) {
        setState(() {
          leftLabels = List<String>.from(settings['leftLabels'] ?? []);
          rightLabels = List<String>.from(settings['rightLabels'] ?? []);
          aMembers = List<String>.from(settings['a班'] ?? []);
          bMembers = List<String>.from(settings['b班'] ?? []);
          // デフォルトで空の状態にする
          if (leftLabels.isEmpty && rightLabels.isEmpty) {
            leftLabels = [''];
            rightLabels = [''];
          }

          // コントローラーを初期化
          _initializeControllers();
        });
      }
    } catch (e) {
      developer.log('ラベル読み込みエラー: $e', name: 'LabelEditPage', error: e);
      if (mounted) {
        setState(() {
          leftLabels = [''];
          rightLabels = [''];
          aMembers = [];
          bMembers = [];

          // コントローラーを初期化
          _initializeControllers();
        });
      }
    }
  }

  /// コントローラーを初期化
  void _initializeControllers() {
    // 既存のコントローラーを破棄
    for (var controller in _leftLabelControllers) {
      controller.dispose();
    }
    for (var controller in _rightLabelControllers) {
      controller.dispose();
    }
    _leftLabelControllers.clear();
    _rightLabelControllers.clear();

    // 新しいコントローラーを作成
    for (int i = 0; i < leftLabels.length; i++) {
      _leftLabelControllers.add(TextEditingController(text: leftLabels[i]));
      _rightLabelControllers.add(TextEditingController(text: rightLabels[i]));
    }
  }

  Future<void> _saveLabels() async {
    try {
      final messenger = ScaffoldMessenger.of(context);
      final groupProvider = context.read<GroupProvider>();
      // コントローラーから値を取得
      leftLabels.clear();
      rightLabels.clear();
      for (int i = 0; i < _leftLabelControllers.length; i++) {
        leftLabels.add(_leftLabelControllers[i].text);
        rightLabels.add(_rightLabelControllers[i].text);
      }

      // 現在のメンバーデータを取得（既存のデータを保持）
      developer.log('現在のメンバーデータ取得開始', name: 'LabelEditPage');
      final currentSettings =
          await UserSettingsFirestoreService.getMultipleSettings([
            'teams',
            'assignment_team_a',
            'assignment_team_b',
          ]);
      developer.log('現在のメンバーデータ取得完了: $currentSettings', name: 'LabelEditPage');
      developer.log(
        'teamsの型: ${currentSettings['teams']?.runtimeType}',
        name: 'LabelEditPage',
      );
      developer.log(
        'assignment_team_aの型: ${currentSettings['assignment_team_a']?.runtimeType}',
        name: 'LabelEditPage',
      );
      developer.log(
        'assignment_team_bの型: ${currentSettings['assignment_team_b']?.runtimeType}',
        name: 'LabelEditPage',
      );

      // 新しい形式のteamsデータがある場合は使用、なければ古い形式を使用
      List<String> currentAMembers = [];
      List<String> currentBMembers = [];

      try {
        if (currentSettings['teams'] != null) {
          final teamsJson = currentSettings['teams'];
          developer.log('新しい形式のteamsデータを使用: $teamsJson', name: 'LabelEditPage');

          // teamsJsonがListかどうかチェック
          if (teamsJson is List && teamsJson.isNotEmpty) {
            final teamA = teamsJson[0];
            if (teamA is Map && teamA['members'] != null) {
              final members = teamA['members'];
              if (members is List) {
                currentAMembers = List<String>.from(members);
              } else {
                developer.log(
                  'teamAのmembersがListではありません: $members',
                  name: 'LabelEditPage',
                );
                currentAMembers = [];
              }
            }

            if (teamsJson.length > 1) {
              final teamB = teamsJson[1];
              if (teamB is Map && teamB['members'] != null) {
                final members = teamB['members'];
                if (members is List) {
                  currentBMembers = List<String>.from(members);
                } else {
                  developer.log(
                    'teamBのmembersがListではありません: $members',
                    name: 'LabelEditPage',
                  );
                  currentBMembers = [];
                }
              }
            }
          } else if (teamsJson is String) {
            // 文字列として保存されている場合、JSONとしてパースを試行
            developer.log(
              'teamsJsonが文字列です。JSONパースを試行: $teamsJson',
              name: 'LabelEditPage',
            );
            try {
              final decodedTeams = json.decode(teamsJson) as List;
              if (decodedTeams.isNotEmpty) {
                final teamA = decodedTeams[0];
                if (teamA is Map && teamA['members'] != null) {
                  final members = teamA['members'];
                  if (members is List) {
                    currentAMembers = List<String>.from(members);
                  }
                }

                if (decodedTeams.length > 1) {
                  final teamB = decodedTeams[1];
                  if (teamB is Map && teamB['members'] != null) {
                    final members = teamB['members'];
                    if (members is List) {
                      currentBMembers = List<String>.from(members);
                    }
                  }
                }
              }
            } catch (parseError) {
              developer.log(
                'teamsJsonのJSONパースに失敗: $parseError',
                name: 'LabelEditPage',
                error: parseError,
              );
            }
          } else {
            developer.log(
              'teamsJsonがListでもStringでもありません: $teamsJson',
              name: 'LabelEditPage',
            );
          }
        } else {
          // 古い形式のデータを使用
          developer.log('古い形式のデータを使用', name: 'LabelEditPage');
          final aMembersData = currentSettings['assignment_team_a'];
          final bMembersData = currentSettings['assignment_team_b'];

          if (aMembersData is List) {
            currentAMembers = List<String>.from(aMembersData);
          } else if (aMembersData is String) {
            // 文字列として保存されている場合
            developer.log(
              'assignment_team_aが文字列です: $aMembersData',
              name: 'LabelEditPage',
            );
            try {
              final decoded = json.decode(aMembersData) as List;
              currentAMembers = List<String>.from(decoded);
            } catch (parseError) {
              developer.log(
                'assignment_team_aのJSONパースに失敗: $parseError',
                name: 'LabelEditPage',
                error: parseError,
              );
              currentAMembers = [];
            }
          } else {
            developer.log(
              'assignment_team_aがListでもStringでもありません: $aMembersData',
              name: 'LabelEditPage',
            );
            currentAMembers = [];
          }

          if (bMembersData is List) {
            currentBMembers = List<String>.from(bMembersData);
          } else if (bMembersData is String) {
            // 文字列として保存されている場合
            developer.log(
              'assignment_team_bが文字列です: $bMembersData',
              name: 'LabelEditPage',
            );
            try {
              final decoded = json.decode(bMembersData) as List;
              currentBMembers = List<String>.from(decoded);
            } catch (parseError) {
              developer.log(
                'assignment_team_bのJSONパースに失敗: $parseError',
                name: 'LabelEditPage',
                error: parseError,
              );
              currentBMembers = [];
            }
          } else {
            developer.log(
              'assignment_team_bがListでもStringでもありません: $bMembersData',
              name: 'LabelEditPage',
            );
            currentBMembers = [];
          }
        }
        developer.log(
          'メンバーデータ処理完了 - A班: $currentAMembers, B班: $currentBMembers',
          name: 'LabelEditPage',
        );
      } catch (e) {
        developer.log('メンバーデータ処理エラー: $e', name: 'LabelEditPage', error: e);
        // エラーが発生した場合は空の配列を使用
        currentAMembers = [];
        currentBMembers = [];
      }

      developer.log('UserSettings保存開始', name: 'LabelEditPage');
      await UserSettingsFirestoreService.saveMultipleSettings({
        'leftLabels': leftLabels,
        'rightLabels': rightLabels,
        'a班': currentAMembers,
        'b班': currentBMembers,
      });
      developer.log('UserSettings保存完了', name: 'LabelEditPage');

      // 新しい形式でも保存（後方互換性のため）
      try {
        final teamsJson = jsonEncode([
          {'id': 'team_a', 'name': 'A班', 'members': currentAMembers},
          {'id': 'team_b', 'name': 'B班', 'members': currentBMembers},
        ]);
        await UserSettingsFirestoreService.saveMultipleSettings({
          'teams': teamsJson,
        });
        developer.log('新しい形式での保存完了', name: 'LabelEditPage');
      } catch (e) {
        developer.log('新しい形式での保存エラー: $e', name: 'LabelEditPage', error: e);
      }

      // Firestoreにも保存（メンバーは既存のデータを保持）
      developer.log('Firestore保存開始', name: 'LabelEditPage');
      await AssignmentFirestoreService.saveAssignmentMembers(
        aMembers: currentAMembers,
        bMembers: currentBMembers,
        leftLabels: leftLabels,
        rightLabels: rightLabels,
      );
      developer.log('Firestore保存完了', name: 'LabelEditPage');

      // グループに同期
      try {
        if (groupProvider.groups.isNotEmpty) {
          final group = groupProvider.groups.first;
          developer.log(
            '担当表データをグループに同期開始 - groupId: ${group.id}',
            name: 'LabelEditPage',
          );

          final assignmentData = {
            'aMembers': currentAMembers,
            'bMembers': currentBMembers,
            'leftLabels': leftLabels,
            'rightLabels': rightLabels,
            'savedAt': DateTime.now().toIso8601String(),
          };

          await GroupDataSyncService.syncAssignmentBoard(
            group.id,
            assignmentData,
          );
          developer.log('担当表データ同期完了', name: 'LabelEditPage');
        }
      } catch (e) {
        developer.log('担当表データ同期エラー: $e', name: 'LabelEditPage', error: e);
      }

      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('ラベル保存しました')));

      // 保存完了後に少し待ってからページを閉じる（データ同期のため）
      await Future.delayed(Duration(milliseconds: 500));
    } catch (e, stackTrace) {
      developer.log(
        'ラベル保存エラー: $e',
        name: 'LabelEditPage',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(content: Text('ラベル保存に失敗しました: $e')));
    }
  }

  void _addLabel() {
    setState(() {
      leftLabels.add('');
      rightLabels.add('');

      // ラベル追加時、メンバーも追加
      if (aMembers.length < leftLabels.length) {
        aMembers.add('');
      }
      if (bMembers.length < leftLabels.length) {
        bMembers.add('');
      }

      // 新しいコントローラーを追加
      _leftLabelControllers.add(TextEditingController(text: ''));
      _rightLabelControllers.add(TextEditingController(text: ''));
    });
  }

  void _deleteLabel(int i) {
    // 削除するコントローラーを破棄
    _leftLabelControllers[i].dispose();
    _rightLabelControllers[i].dispose();
    _leftLabelControllers.removeAt(i);
    _rightLabelControllers.removeAt(i);

    setState(() {
      leftLabels.removeAt(i);
      rightLabels.removeAt(i);

      // メンバー数が多い場合のみ削除
      if (aMembers.length > leftLabels.length) {
        aMembers.removeAt(i);
      }
      if (bMembers.length > leftLabels.length) {
        bMembers.removeAt(i);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('担当ラベル編集'),
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
        actions: [IconButton(icon: Icon(Icons.save), onPressed: _saveLabels)],
        backgroundColor: Provider.of<ThemeSettings>(context).appBarColor,
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
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Provider.of<ThemeSettings>(
                    context,
                  ).cardBackgroundColor,
                  child: Padding(
                    padding: EdgeInsets.all(kIsWeb ? 28 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.label,
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).iconColor,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '担当ラベル一覧',
                              style: TextStyle(
                                fontSize: kIsWeb ? 20 : 18,
                                fontWeight: FontWeight.bold,
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).fontColor1,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: kIsWeb ? 16 : 12),
                        ...List.generate(leftLabels.length, (i) {
                          return Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: kIsWeb ? 6 : 4,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _leftLabelControllers[i],
                                    style: TextStyle(
                                      color: Provider.of<ThemeSettings>(
                                        context,
                                      ).fontColor1,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: '左ラベル',
                                      labelStyle: TextStyle(
                                        color: Provider.of<ThemeSettings>(
                                          context,
                                        ).fontColor1,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      prefixIcon: Icon(
                                        Icons.label_outline,
                                        color: Provider.of<ThemeSettings>(
                                          context,
                                        ).iconColor,
                                      ),
                                      filled: true,
                                      fillColor: Provider.of<ThemeSettings>(
                                        context,
                                      ).inputBackgroundColor,
                                    ),
                                  ),
                                ),
                                SizedBox(width: kIsWeb ? 12 : 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _rightLabelControllers[i],
                                    style: TextStyle(
                                      color: Provider.of<ThemeSettings>(
                                        context,
                                      ).fontColor1,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: '右ラベル',
                                      labelStyle: TextStyle(
                                        color: Provider.of<ThemeSettings>(
                                          context,
                                        ).fontColor1,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      prefixIcon: Icon(
                                        Icons.label_outline,
                                        color: Provider.of<ThemeSettings>(
                                          context,
                                        ).iconColor,
                                      ),
                                      filled: true,
                                      fillColor: Provider.of<ThemeSettings>(
                                        context,
                                      ).inputBackgroundColor,
                                    ),
                                  ),
                                ),
                                SizedBox(width: kIsWeb ? 12 : 8),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteLabel(i),
                                ),
                              ],
                            ),
                          );
                        }),
                        SizedBox(height: kIsWeb ? 12 : 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.add),
                            label: Text('ラベルを追加'),
                            onPressed: _addLabel,
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
                              padding: EdgeInsets.symmetric(
                                vertical: kIsWeb ? 16 : 14,
                              ),
                            ),
                          ),
                        ),
                      ],
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
