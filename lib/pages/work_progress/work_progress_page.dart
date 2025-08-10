import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/work_progress_models.dart';
import '../../models/theme_settings.dart';
import '../../widgets/bean_name_with_sticker.dart';
import 'work_progress_edit_page.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../widgets/lottie_animation_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

// GroupProviderのsettingsを更新するメソッドを追加（本体に追加する想定）
// lib/models/group_provider.dart に以下を追加してください:
//
// void updateCurrentGroupSettings(Map<String, dynamic> newSettings) {
//   if (_currentGroup != null) {
//     _currentGroup = _currentGroup!.copyWith(settings: newSettings);
//     _safeNotifyListeners();
//   }
// }

class WorkProgressPage extends StatefulWidget {
  const WorkProgressPage({super.key});

  @override
  State<WorkProgressPage> createState() => _WorkProgressPageState();
}

class _WorkProgressPageState extends State<WorkProgressPage>
    with WidgetsBindingObserver {
  Stream? _groupWorkProgressStream;
  StreamSubscription? _groupWorkProgressSubscription;
  StreamSubscription<DocumentSnapshot>? _settingsSubscription;
  bool _canEdit = true;
  GroupProvider? _groupProvider;
  String? _currentGroupId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _groupProvider = context.read<GroupProvider>();
      _groupProvider?.addListener(_onGroupProviderChanged);
      _setupWorkProgressAndSettingsListener();
    });
  }

  void _setupWorkProgressAndSettingsListener() {
    final groupProvider = context.read<GroupProvider>();
    final workProgressProvider = context.read<WorkProgressProvider>();
    final newGroupId = groupProvider.currentGroup?.id;
    if (_currentGroupId == newGroupId) return;
    _currentGroupId = newGroupId;
    _settingsSubscription?.cancel();
    if (newGroupId != null) {
      print('[DEBUG] settings listener set for groupId: $newGroupId');
      _settingsSubscription = FirebaseFirestore.instance
          .collection('groups')
          .doc(newGroupId)
          .snapshots()
          .listen((doc) {
            if (!mounted) return;
            final settings = doc.data()?['settings'];
            print('[DEBUG] settings snapshot fired: $settings');
            if (settings != null && settings['dataPermissions'] != null) {
              final dataPermissions =
                  settings['dataPermissions'] as Map<String, dynamic>;
              // work_progressが無い場合はtaskStatusも参照（後方互換）
              final accessStr =
                  dataPermissions['work_progress'] ??
                  dataPermissions['taskStatus'];
              final access = AccessLevel.values.firstWhere(
                (e) => e.name == accessStr,
                orElse: () => AccessLevel.adminLeader,
              );
              final groupRole = groupProvider.getCurrentUserRole();
              print(
                '[DEBUG] work_progress access: $access, groupRole: $groupRole',
              );
              if (groupRole != null) {
                bool canEdit = false;
                if (access == AccessLevel.allMembers) {
                  canEdit = true;
                } else if (access == AccessLevel.adminLeader) {
                  canEdit =
                      groupRole == GroupRole.admin ||
                      groupRole == GroupRole.leader;
                } else if (access == AccessLevel.adminOnly) {
                  canEdit = groupRole == GroupRole.admin;
                }
                print('[DEBUG] canEdit判定: $canEdit');
                setState(() {
                  _canEdit = canEdit;
                });
              }
              // GroupProviderのsettingsも更新
              print('[DEBUG] updateCurrentGroupSettings呼び出し: $settings');
              groupProvider.updateCurrentGroupSettings(settings);
            }
          });
    }
    // work_progressの監視もグループIDごとに再設置
    _groupWorkProgressSubscription?.cancel();
    if (newGroupId != null) {
      _groupWorkProgressStream = FirebaseFirestore.instance
          .collection('groups')
          .doc(newGroupId)
          .collection('work_progress')
          .orderBy('createdAt', descending: true)
          .snapshots();
      _groupWorkProgressSubscription = _groupWorkProgressStream!.listen((
        snapshot,
      ) {
        final docs = (snapshot as QuerySnapshot).docs;
        final records = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return WorkProgress.fromMap(data);
        }).toList();
        workProgressProvider.replaceAll(records);
      });
      workProgressProvider.loadWorkProgress(groupId: newGroupId);
    } else {
      workProgressProvider.loadWorkProgress();
    }
  }

  void _onGroupProviderChanged() {
    if (!mounted) return;
    _setupWorkProgressAndSettingsListener();
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _groupWorkProgressSubscription?.cancel();
    _settingsSubscription?.cancel();
    _groupProvider?.removeListener(_onGroupProviderChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // アプリが復帰した時にデータを再読み込み
      final groupProvider = context.read<GroupProvider>();
      final workProgressProvider = context.read<WorkProgressProvider>();
      if (groupProvider.hasGroup) {
        _groupWorkProgressSubscription?.cancel();
        _groupWorkProgressStream = FirebaseFirestore.instance
            .collection('groups')
            .doc(groupProvider.currentGroup!.id)
            .collection('work_progress')
            .orderBy('createdAt', descending: true)
            .snapshots();
        _groupWorkProgressSubscription = _groupWorkProgressStream!.listen((
          snapshot,
        ) {
          final docs = (snapshot as QuerySnapshot).docs;
          final records = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return WorkProgress.fromMap(data);
          }).toList();
          workProgressProvider.replaceAll(records);
        });
        workProgressProvider.loadWorkProgress(
          groupId: groupProvider.currentGroup!.id,
        );
      } else {
        workProgressProvider.loadWorkProgress();
      }
    }
  }

  String _getStageDisplayName(WorkStage stage) {
    switch (stage) {
      case WorkStage.handpick:
        return 'ハンドピック';
      case WorkStage.roast:
        return 'ロースト';
      case WorkStage.afterPick:
        return 'アフターピック';
      case WorkStage.mill:
        return 'ミル';
      case WorkStage.dripPack:
        return 'ドリップパック';
      case WorkStage.threeWayBag:
        return '三方袋';
      case WorkStage.packaging:
        return '梱包';
      case WorkStage.shipping:
        return '発送';
    }
  }

  String _getStatusDisplayName(WorkStatus status) {
    switch (status) {
      case WorkStatus.before:
        return '前';
      case WorkStatus.inProgress:
        return '途中';
      case WorkStatus.after:
        return '済';
    }
  }

  // ステータスごとのアイコン
  IconData _getStatusIcon(WorkStatus status, WorkStage stage) {
    switch (status) {
      case WorkStatus.before:
        return Icons.close; // 未完了はバツ
      case WorkStatus.inProgress:
        return Icons.timelapse; // 途中は時計アイコン
      case WorkStatus.after:
        return _getStageIcon(stage); // 完了は作業種別アイコン
    }
  }

  // ステータスごとの色
  Color _getStatusColor(
    BuildContext context,
    WorkStatus status,
    WorkStage stage,
  ) {
    switch (status) {
      case WorkStatus.before:
        return Colors.grey;
      case WorkStatus.inProgress:
        return Colors.orange;
      case WorkStatus.after:
        return _getStageColor(context, stage);
    }
  }

  // ステータスごとの背景色
  Color _getStatusBgColor(
    BuildContext context,
    WorkStatus status,
    WorkStage stage,
  ) {
    switch (status) {
      case WorkStatus.before:
        return Colors.grey.withOpacity(0.08);
      case WorkStatus.inProgress:
        return Colors.orange.withOpacity(0.12);
      case WorkStatus.after:
        return _getStageColor(context, stage).withOpacity(0.18);
    }
  }

  // 作業種別ごとのアイコン
  IconData _getStageIcon(WorkStage stage) {
    switch (stage) {
      case WorkStage.handpick:
        return Icons.pan_tool_alt; // ハンドピック
      case WorkStage.roast:
        return Icons.local_fire_department; // ロースト
      case WorkStage.afterPick:
        return Icons.check_circle_outline; // アフターピック
      case WorkStage.mill:
        return Icons.coffee; // ミル
      case WorkStage.dripPack:
        return Icons.local_cafe; // ドリップパック
      case WorkStage.threeWayBag:
        return Icons.shopping_bag; // 三方袋
      case WorkStage.packaging:
        return Icons.all_inbox; // 梱包
      case WorkStage.shipping:
        return Icons.local_shipping; // 発送
    }
  }

  // 作業種別ごとの色（コーヒー工程イメージに合わせて）
  Color _getStageColor(BuildContext context, WorkStage stage) {
    switch (stage) {
      case WorkStage.handpick:
        return const Color(0xFFB7C29A); // 生豆の色
      case WorkStage.roast:
        return Colors.deepOrange; // 炎の色
      case WorkStage.afterPick:
        return const Color(0xFF6F4E37); // 焙煎後のコーヒー豆色
      case WorkStage.mill:
        return const Color(0xFF4B2E19); // コーヒー粉の色
      case WorkStage.dripPack:
        // テーマによって白色を工夫
        final brightness = Theme.of(context).brightness;
        return brightness == Brightness.dark
            ? const Color(0xFFEEEEEE) // ダークテーマでは明るいグレー
            : Colors.white; // ライトテーマでは白
      case WorkStage.threeWayBag:
        return const Color(0xFFC0C0C0); // 銀色
      case WorkStage.packaging:
        return const Color(0xFFD2B48C); // 段ボール色
      case WorkStage.shipping:
        return Colors.blue; // 発送（青系のまま）
    }
  }

  // ドリップパック工程のラベル用に、背景色が明るい場合は文字色・枠線色を暗色に、暗い場合は明色にする
  Color _getStageTextColor(BuildContext context, WorkStage stage) {
    if (stage == WorkStage.dripPack) {
      final brightness = Theme.of(context).brightness;
      return brightness == Brightness.dark ? Colors.black : Colors.black87;
    }
    // それ以外は工程色をそのまま使う
    return _getStageColor(context, stage);
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);
    final workProgressProvider = context.read<WorkProgressProvider>();
    final groupProvider = context.watch<GroupProvider>();

    // 権限チェック（リアルタイム反映対応）
    final canEdit = _canEdit;

    // ページが表示されるたびにデータを読み込む
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupProvider = context.read<GroupProvider>();
      if (!workProgressProvider.isLoading &&
          workProgressProvider.workProgressList.isEmpty) {
        if (groupProvider.groups.isNotEmpty) {
          workProgressProvider.loadWorkProgress(
            groupId: groupProvider.groups.first.id,
          );
        } else {
          workProgressProvider.loadWorkProgress();
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('作業状況記録'),
            // グループ状態バッジを追加
            Consumer<GroupProvider>(
              builder: (context, groupProvider, _) {
                if (groupProvider.groups.isNotEmpty) {
                  // グループ名のテキストを削除し、アイコンのみ表示
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
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
      ),
      body: Consumer<WorkProgressProvider>(
        builder: (context, workProgressProvider, child) {
          if (workProgressProvider.isLoading) {
            return Center(child: const LoadingAnimationWidget());
          }

          if (workProgressProvider.workProgressList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.work_outline,
                    size: 64,
                    color: themeSettings.iconColor.withOpacity(0.5),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '作業状況記録がありません',
                    style: TextStyle(
                      fontSize: 18,
                      color: themeSettings.fontColor1,
                    ),
                  ),
                  SizedBox(height: 8),
                  if (canEdit)
                    Text(
                      '右下のボタンから新しい記録を作成してください',
                      style: TextStyle(
                        fontSize: 14,
                        color: themeSettings.fontColor1.withOpacity(0.7),
                      ),
                    ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: workProgressProvider.workProgressList.length,
            itemBuilder: (context, index) {
              final workProgress = workProgressProvider.workProgressList[index];
              return Card(
                margin: EdgeInsets.only(bottom: 12),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: canEdit && groupProvider.currentGroup != null
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WorkProgressEditPage(
                                workProgress: workProgress,
                                groupId: groupProvider.currentGroup!.id,
                              ),
                            ),
                          ).then((result) {
                            if (result == true) {
                              workProgressProvider.loadWorkProgress(
                                groupId: groupProvider.currentGroup!.id,
                              );
                            }
                          });
                        }
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 上部: 豆の名前と作業状況
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: BeanNameWithSticker(
                                beanName: workProgress.beanName,
                                textStyle: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: themeSettings.fontColor1,
                                ),
                                stickerSize: 18.0,
                              ),
                            ),
                            // 作業状況を表示
                            if (workProgress.stageStatus.isNotEmpty) ...[
                              Builder(
                                builder: (context) {
                                  final stage =
                                      workProgress.stageStatus.keys.first;
                                  final status =
                                      workProgress.stageStatus.values.first;
                                  return Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusBgColor(
                                        context,
                                        status,
                                        stage,
                                      ),
                                      border: Border.all(
                                        color: stage == WorkStage.dripPack
                                            ? _getStageTextColor(context, stage)
                                            : _getStatusColor(
                                                context,
                                                status,
                                                stage,
                                              ),
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _getStatusIcon(status, stage),
                                          color: stage == WorkStage.dripPack
                                              ? _getStageTextColor(
                                                  context,
                                                  stage,
                                                )
                                              : _getStatusColor(
                                                  context,
                                                  status,
                                                  stage,
                                                ),
                                          size: 18,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          '${_getStageDisplayName(stage)} ${_getStatusDisplayName(status)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: stage == WorkStage.dripPack
                                                ? _getStageTextColor(
                                                    context,
                                                    stage,
                                                  )
                                                : _getStatusColor(
                                                    context,
                                                    status,
                                                    stage,
                                                  ),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              SizedBox(width: 8),
                            ],
                            if (canEdit)
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            WorkProgressEditPage(
                                              workProgress: workProgress,
                                              groupId: groupProvider.hasGroup
                                                  ? groupProvider
                                                        .currentGroup!
                                                        .id
                                                  : null,
                                            ),
                                      ),
                                    );
                                  } else if (value == 'delete') {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text('削除確認'),
                                        content: Text('この作業状況記録を削除しますか？'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: Text('キャンセル'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: Text('削除'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmed == true) {
                                      try {
                                        await workProgressProvider
                                            .deleteWorkProgress(
                                              workProgress.id,
                                              groupId: groupProvider.hasGroup
                                                  ? groupProvider
                                                        .currentGroup!
                                                        .id
                                                  : null,
                                            );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('削除しました')),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('削除に失敗しました')),
                                        );
                                      }
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 20),
                                        SizedBox(width: 8),
                                        Text('編集'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete,
                                          size: 20,
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          '削除',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                child: Icon(
                                  Icons.more_vert,
                                  color: themeSettings.iconColor,
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 8),
                        // 中部: 作成日
                        Text(
                          '作成日: ${workProgress.createdAt.toString().substring(0, 16)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: themeSettings.fontColor1.withOpacity(0.7),
                          ),
                        ),
                        // 下部: メモ（存在する場合のみ）
                        if (workProgress.notes != null &&
                            workProgress.notes!.isNotEmpty) ...[
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: themeSettings.fontColor1.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.note,
                                  size: 16,
                                  color: themeSettings.fontColor1.withOpacity(
                                    0.6,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    workProgress.notes!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: themeSettings.fontColor1
                                          .withOpacity(0.8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkProgressEditPage(
                      groupId: groupProvider.currentGroup?.id,
                    ),
                  ),
                ).then((result) {
                  if (result == true && groupProvider.currentGroup != null) {
                    workProgressProvider.loadWorkProgress(
                      groupId: groupProvider.currentGroup!.id,
                    );
                  }
                });
              },
              backgroundColor: themeSettings.buttonColor,
              foregroundColor: themeSettings.fontColor2,
              child: Icon(Icons.add),
            )
          : null,
    );
  }
}
