import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/work_progress_models.dart';
import '../../models/theme_settings.dart';
import '../../widgets/bean_name_with_sticker.dart';
import 'work_progress_edit_page.dart';
import '../../models/group_provider.dart';
import '../../services/user_settings_firestore_service.dart';

class WorkProgressPage extends StatefulWidget {
  const WorkProgressPage({super.key});

  @override
  State<WorkProgressPage> createState() => _WorkProgressPageState();
}

class _WorkProgressPageState extends State<WorkProgressPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.hasGroup) {
        context.read<WorkProgressProvider>().loadWorkProgress(
          groupId: groupProvider.currentGroup!.id,
        );
      } else {
        context.read<WorkProgressProvider>().loadWorkProgress();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // アプリが復帰した時にデータを再読み込み
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.hasGroup) {
        context.read<WorkProgressProvider>().loadWorkProgress(
          groupId: groupProvider.currentGroup!.id,
        );
      } else {
        context.read<WorkProgressProvider>().loadWorkProgress();
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
      case WorkStatus.after:
        return '済';
    }
  }

  // ステータスごとのアイコン
  IconData _getStatusIcon(WorkStatus status, WorkStage stage) {
    switch (status) {
      case WorkStatus.before:
        return Icons.close; // 未完了はバツ
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
            return Center(
              child: CircularProgressIndicator(color: themeSettings.iconColor),
            );
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            WorkProgressEditPage(workProgress: workProgress),
                      ),
                    );
                  },
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
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          WorkProgressEditPage(
                                            workProgress: workProgress,
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
                                          .deleteWorkProgress(workProgress.id);
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => WorkProgressEditPage()),
          );
        },
        backgroundColor: themeSettings.buttonColor,
        foregroundColor: themeSettings.fontColor2,
        child: Icon(Icons.add),
      ),
    );
  }
}
