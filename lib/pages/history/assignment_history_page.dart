import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../services/assignment_firestore_service.dart';
import '../../services/group_firestore_service.dart';
import '../../services/group_data_sync_service.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../models/group_provider.dart';
import '../../services/user_settings_firestore_service.dart';

class AssignmentHistoryPage extends StatefulWidget {
  const AssignmentHistoryPage({super.key});

  @override
  State<AssignmentHistoryPage> createState() => _AssignmentHistoryPageState();
}

class _AssignmentHistoryPageState extends State<AssignmentHistoryPage> {
  bool isReady = false;
  bool? _canEditAssignmentHistory; // null: 未判定, true/false: 判定済み

  final formatter = DateFormat('yyyy-MM-dd');
  final weekdayFormatter = DateFormat('E', 'ja_JP');

  // グループ同期用
  StreamSubscription<Map<String, dynamic>?>?
  _groupAssignmentHistorySubscription;
  bool _isGroupDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _checkEditPermission();
    _initializeGroupMonitoring();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 初回のみデータを再読み込み（無限ループを防ぐ）
    if (isReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadAssignmentHistoryFromFirestore().then((_) {
            if (mounted) {
              setState(() {});
            }
          });
        }
      });
    }
  }

  /// グループ監視の初期化
  void _initializeGroupMonitoring() {
    print('AssignmentHistoryPage: グループ監視初期化開始');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupProvider = context.read<GroupProvider>();
      _startGroupMonitoring(groupProvider);
    });
  }

  /// グループ監視を開始
  void _startGroupMonitoring(GroupProvider groupProvider) {
    print('AssignmentHistoryPage: グループ監視開始');

    // 既存のサブスクリプションをクリーンアップ
    _groupAssignmentHistorySubscription?.cancel();

    if (groupProvider.groups.isNotEmpty) {
      final group = groupProvider.groups.first;
      print('AssignmentHistoryPage: グループ監視開始 - groupId: ${group.id}');

      // グループの担当履歴を監視
      _groupAssignmentHistorySubscription =
          GroupDataSyncService.watchGroupAssignmentHistory(group.id).listen((
            groupAssignmentHistoryData,
          ) {
            print(
              'AssignmentHistoryPage: グループ担当履歴変更検知: $groupAssignmentHistoryData',
            );
            if (groupAssignmentHistoryData != null) {
              _updateLocalAssignmentHistory(groupAssignmentHistoryData);
              _isGroupDataLoaded = true;
            }
          });
    }
  }

  /// ローカルの担当履歴を更新
  void _updateLocalAssignmentHistory(
    Map<String, dynamic> groupAssignmentHistoryData,
  ) {
    print('AssignmentHistoryPage: ローカル担当履歴更新開始');
    groupAssignmentHistoryData.forEach((dateKey, historyData) async {
      if (historyData is Map<String, dynamic>) {
        if (historyData['deleted'] == true) {
          // 削除の場合
          try {
            await UserSettingsFirestoreService.deleteSetting(
              'assignment_$dateKey',
            );
            print('AssignmentHistoryPage: 担当履歴削除 - $dateKey');
          } catch (e) {
            print('担当履歴削除エラー: $e');
          }
        } else if (historyData['assignments'] != null) {
          // 更新の場合
          final assignments = List<String>.from(historyData['assignments']);
          try {
            await UserSettingsFirestoreService.saveSetting(
              'assignment_$dateKey',
              assignments,
            );
            print('AssignmentHistoryPage: 担当履歴更新 - $dateKey: $assignments');
          } catch (e) {
            print('担当履歴更新エラー: $e');
          }
        }
      }
    });
    setState(() {});
  }

  Future<void> _loadPrefs() async {
    if (isReady) return; // 既に読み込み済みの場合は何もしない

    // Firestoreから担当履歴を読み込み
    await _loadAssignmentHistoryFromFirestore();

    if (mounted) {
      setState(() {
        isReady = true;
      });
    }
  }

  /// Firestoreから担当履歴を一括取得
  Future<void> _loadAssignmentHistoryFromFirestore() async {
    if (!mounted) return;
    try {
      final allHistory =
          await AssignmentFirestoreService.loadAllAssignmentHistory();
      for (final entry in allHistory.entries) {
        await UserSettingsFirestoreService.saveSetting(
          'assignment_${entry.key}',
          entry.value,
        );
      }
      if (mounted) setState(() {});
    } catch (e) {
      print('AssignmentHistoryPage: Firestoreからの履歴一括取得エラー: $e');
    }
  }

  /// 担当履歴編集権限をチェック
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
          dataType: 'assignment_history',
        );
        setState(() {
          _canEditAssignmentHistory = canEdit;
        });
      }
    } catch (e) {
      // エラーの場合は編集可能として扱う（グループに参加していない場合など）
      setState(() {
        _canEditAssignmentHistory = true;
      });
    }
  }

  /// グループに担当履歴を同期
  Future<void> _syncAssignmentHistoryToGroup(
    String dateKey,
    List<String> assignments,
  ) async {
    try {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.groups.isNotEmpty) {
        final group = groupProvider.groups.first;
        print(
          'AssignmentHistoryPage: 担当履歴をグループに同期開始 - groupId: ${group.id}, dateKey: $dateKey',
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
        print('AssignmentHistoryPage: 担当履歴同期完了');
      }
    } catch (e) {
      print('AssignmentHistoryPage: 担当履歴同期エラー: $e');
    }
  }

  /// グループに担当履歴削除を同期
  Future<void> _syncAssignmentHistoryDeletionToGroup(String dateKey) async {
    try {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.groups.isNotEmpty) {
        final group = groupProvider.groups.first;
        print(
          'AssignmentHistoryPage: 担当履歴削除をグループに同期開始 - groupId: ${group.id}, dateKey: $dateKey',
        );
        // 削除マーカーを送信
        final assignmentHistoryData = {
          dateKey: {
            'deleted': true,
            'deletedAt': DateTime.now().toIso8601String(),
          },
        };
        await GroupDataSyncService.syncAssignmentHistory(
          group.id,
          assignmentHistoryData,
        );
        print('AssignmentHistoryPage: 担当履歴削除同期完了');
      }
    } catch (e) {
      print('AssignmentHistoryPage: 担当履歴削除同期エラー: $e');
    }
  }

  Future<void> _editAssignment(String dateKey, List<String> original) async {
    final groupProvider = context.read<GroupProvider>();
    final isInGroup = groupProvider.groups.isNotEmpty;

    List<TextEditingController> controllers = original
        .map((e) => TextEditingController(text: e))
        .toList();

    // ラベルを取得（なければ空リスト）
    final settings = await UserSettingsFirestoreService.getMultipleSettings([
      'leftLabels',
      'rightLabels',
    ]);
    final leftLabels = List<String>.from(settings['leftLabels'] ?? []);
    final rightLabels = List<String>.from(settings['rightLabels'] ?? []);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          isInGroup ? '担当編集 ($dateKey) - グループ同期' : '担当編集 ($dateKey)',
          style: TextStyle(
            color: Provider.of<ThemeSettings>(context).fontColor1,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(controllers.length, (i) {
            final label =
                '${leftLabels.length > i ? leftLabels[i] : ''}${(rightLabels.length > i && rightLabels[i].isNotEmpty) ? '・${rightLabels[i]}' : ''}';
            return TextFormField(
              controller: controllers[i],
              style: TextStyle(
                color: Provider.of<ThemeSettings>(context).fontColor1,
              ),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(
                  color: Provider.of<ThemeSettings>(context).fontColor1,
                ),
              ),
            );
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'キャンセル',
              style: TextStyle(
                color: Provider.of<ThemeSettings>(context).fontColor1,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = controllers.map((c) => c.text).toList();
              try {
                await UserSettingsFirestoreService.saveSetting(
                  'assignment_$dateKey',
                  updated,
                );
                // Firestoreにも保存（ラベルも必ず渡す）
                await AssignmentFirestoreService.saveAssignmentHistory(
                  dateKey: dateKey,
                  assignments: updated,
                  leftLabels: leftLabels, // 追加
                  rightLabels: rightLabels, // 追加
                );
                // グループに参加している場合のみグループに同期
                if (isInGroup) {
                  await _syncAssignmentHistoryToGroup(dateKey, updated);
                }
                Navigator.pop(context);
                setState(() {});
              } catch (e) {
                print('担当履歴保存エラー: $e');
              }
            },
            child: Text(
              '保存',
              style: TextStyle(
                color: Provider.of<ThemeSettings>(context).fontColor2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAssignment(String dateKey) async {
    final groupProvider = context.read<GroupProvider>();
    final isInGroup = groupProvider.groups.isNotEmpty;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          '削除の確認',
          style: TextStyle(
            color: Provider.of<ThemeSettings>(context).fontColor1,
          ),
        ),
        content: Text(
          isInGroup
              ? 'この日の担当を削除してもよろしいですか？\n($dateKey)\n\n※グループメンバー全員に反映されます'
              : 'この日の担当を削除してもよろしいですか？\n($dateKey)',
          style: TextStyle(
            color: Provider.of<ThemeSettings>(context).fontColor1,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'キャンセル',
              style: TextStyle(
                color: Provider.of<ThemeSettings>(context).fontColor1,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '削除',
              style: TextStyle(
                color: Provider.of<ThemeSettings>(context).fontColor2,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await UserSettingsFirestoreService.deleteSetting('assignment_$dateKey');
        // Firestoreからも削除
        await AssignmentFirestoreService.deleteAssignmentHistory(dateKey);
        // グループに参加している場合のみグループに削除を同期
        if (isInGroup) {
          await _syncAssignmentHistoryDeletionToGroup(dateKey);
        }
        setState(() {});
      } catch (e) {
        print('担当履歴削除エラー: $e');
      }
    }
  }

  @override
  void dispose() {
    _groupAssignmentHistorySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context, listen: true);
    if (!isReady) {
      return Scaffold(
        appBar: AppBar(
          title: Text('担当履歴'),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Consumer<GroupProvider>(
      builder: (context, groupProvider, child) {
        // グループ監視を開始（初回のみ）
        if (!_isGroupDataLoaded && groupProvider.groups.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startGroupMonitoring(groupProvider);
          });
        }

        final now = DateTime.now();
        final List<Widget> items = [];

        for (int i = 0; i < 31; i++) {
          final date = now.subtract(Duration(days: i));
          final dayKey = formatter.format(date);
          final weekday = weekdayFormatter.format(date);
          // 担当履歴を非同期で取得するため、FutureBuilderを使用
          items.add(
            FutureBuilder<List<String>?>(
              future: (() async {
                final result = await UserSettingsFirestoreService.getSetting(
                  'assignment_$dayKey',
                );
                return result as List<String>?;
              })(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  final data = snapshot.data!;
                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: themeSettings.backgroundColor2 ?? Colors.white,
                    margin: EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).iconColor,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$dayKey（$weekday）',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Provider.of<ThemeSettings>(
                                      context,
                                    ).fontColor1,
                                  ),
                                ),
                              ),
                              // グループに参加していない場合、または編集権限がある場合は編集・削除ボタンを表示
                              if (groupProvider.groups.isEmpty ||
                                  _canEditAssignmentHistory == true) ...[
                                IconButton(
                                  icon: Icon(
                                    Icons.edit,
                                    color: Provider.of<ThemeSettings>(
                                      context,
                                    ).iconColor,
                                  ),
                                  tooltip: '編集',
                                  onPressed: () =>
                                      _editAssignment(dayKey, data),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  tooltip: '削除',
                                  onPressed: () => _deleteAssignment(dayKey),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 8),
                          if (data.isNotEmpty)
                            _buildAssignmentRow('掃除機', data[0]),
                          if (data.length > 1)
                            _buildAssignmentRow('机・ロースト', data[1]),
                          if (data.length > 2)
                            _buildAssignmentRow('洗い物', data[2]),
                        ],
                      ),
                    ),
                  );
                }
                return SizedBox.shrink();
              },
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('担当履歴'),
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          ),
          body: items.isEmpty
              ? Center(
                  child: Text(
                    '履歴がまだありません',
                    style: TextStyle(
                      color: Provider.of<ThemeSettings>(context).fontColor1,
                    ),
                  ),
                )
              : Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: ListView(padding: EdgeInsets.all(16), children: items),
                ),
        );
      },
    );
  }

  Widget _buildAssignmentRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            Icons.label_outline,
            size: 18,
            color: Provider.of<ThemeSettings>(context).iconColor,
          ),
          SizedBox(width: 6),
          Text(
            '$label：',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Provider.of<ThemeSettings>(context).fontColor1,
            ),
          ),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                color: Provider.of<ThemeSettings>(context).fontColor1,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
