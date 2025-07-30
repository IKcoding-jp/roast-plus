import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../services/assignment_firestore_service.dart';
import '../../services/group_firestore_service.dart';
import '../../services/group_data_sync_service.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../services/user_settings_firestore_service.dart';
import 'dart:convert'; // jsonDecodeを追加
import '../../widgets/lottie_animation_widget.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 追加

class AssignmentHistoryPage extends StatefulWidget {
  const AssignmentHistoryPage({super.key});

  @override
  State<AssignmentHistoryPage> createState() => _AssignmentHistoryPageState();
}

class _AssignmentHistoryPageState extends State<AssignmentHistoryPage> {
  bool isReady = false;
  bool? _canEditAssignmentHistory; // null: 未判定, true/false: 判定済み
  StreamSubscription<GroupSettings?>? _permissionSubscription;

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
    _startPermissionListener();
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
      print('AssignmentHistoryPage: Firestoreからの履歴一括取得開始');
      final allHistory =
          await AssignmentFirestoreService.loadAllAssignmentHistory();
      print('AssignmentHistoryPage: 取得した履歴数: ${allHistory.length}');

      for (final entry in allHistory.entries) {
        try {
          final assignments = _safeStringListFromDynamic(entry.value);
          await UserSettingsFirestoreService.saveSetting(
            'assignment_${entry.key}',
            assignments,
          );
          print(
            'AssignmentHistoryPage: 履歴保存完了 - ${entry.key}: ${assignments.length}件',
          );
        } catch (e) {
          print('AssignmentHistoryPage: 履歴保存エラー (${entry.key}): $e');
        }
      }

      if (mounted) {
        setState(() {});
        print('AssignmentHistoryPage: 履歴一括取得完了');
      }
    } catch (e) {
      print('AssignmentHistoryPage: Firestoreからの履歴一括取得エラー: $e');
    }
  }

  /// リアルタイム権限監視を開始
  void _startPermissionListener() {
    final groupProvider = context.read<GroupProvider>();
    if (groupProvider.hasGroup) {
      _permissionSubscription?.cancel();
      // グループ設定の変更を直接監視
      _permissionSubscription =
          GroupFirestoreService.watchGroupSettings(
            groupProvider.currentGroup!.id,
          ).listen((groupSettings) {
            if (!mounted) return;
            print('AssignmentHistoryPage: グループ設定変更検知: $groupSettings');
            if (groupSettings != null) {
              _checkEditPermissionFromSettings(groupSettings, groupProvider);
            }
          });
    } else {
      _permissionSubscription?.cancel();
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
    final leftLabels = _safeStringListFromDynamic(settings['leftLabels']);
    final rightLabels = _safeStringListFromDynamic(settings['rightLabels']);

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
                // ローカルとFirestoreの両方に保存
                await UserSettingsFirestoreService.saveSetting(
                  'assignment_$dateKey',
                  updated,
                );

                // Firestoreにも保存
                try {
                  await AssignmentFirestoreService.saveAssignmentHistory(
                    dateKey: dateKey,
                    assignments: updated,
                    leftLabels: leftLabels,
                    rightLabels: rightLabels,
                  );
                  print('AssignmentHistoryPage: 編集内容をFirestoreに保存完了');
                } catch (e) {
                  print('AssignmentHistoryPage: Firestore保存エラー: $e');
                }
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
        // ローカルから削除
        await UserSettingsFirestoreService.deleteSetting('assignment_$dateKey');

        // Firestoreからも削除
        try {
          await AssignmentFirestoreService.deleteAssignmentHistory(dateKey);
          print('AssignmentHistoryPage: Firestoreから履歴削除完了');
        } catch (e) {
          print('AssignmentHistoryPage: Firestore削除エラー: $e');
        }

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

  /// 動的データから安全にStringリストを取得
  List<String> _safeStringListFromDynamic(dynamic data) {
    if (data == null) return [];

    try {
      if (data is List) {
        return data.map((item) => item?.toString() ?? '').toList();
      } else if (data is String) {
        // JSON文字列の場合
        final decoded = jsonDecode(data);
        if (decoded is List) {
          return decoded.map((item) => item?.toString() ?? '').toList();
        }
      }
    } catch (e) {
      print(
        'AssignmentHistoryPage: データ変換エラー: $e, data: $data, data type: ${data.runtimeType}',
      );
    }

    return [];
  }

  /// グループ設定から権限をチェック
  void _checkEditPermissionFromSettings(
    GroupSettings groupSettings,
    GroupProvider groupProvider,
  ) {
    if (!mounted) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('AssignmentHistoryPage: ユーザーが認証されていません');
        setState(() {
          _canEditAssignmentHistory = false;
        });
        return;
      }

      final group = groupProvider.currentGroup;
      if (group == null) {
        print('AssignmentHistoryPage: グループが見つかりません');
        setState(() {
          _canEditAssignmentHistory = true;
        });
        return;
      }

      final userRole = group.getMemberRole(currentUser.uid);
      if (userRole == null) {
        print('AssignmentHistoryPage: ユーザーロールが取得できません');
        setState(() {
          _canEditAssignmentHistory = false;
        });
        return;
      }

      final canEdit = groupSettings.canEditDataType(
        'assignment_board',
        userRole,
      );
      print(
        'AssignmentHistoryPage: 設定変更による権限チェック - ユーザーロール: $userRole, 権限: $canEdit',
      );

      if (mounted && _canEditAssignmentHistory != canEdit) {
        setState(() {
          _canEditAssignmentHistory = canEdit;
        });
        print('AssignmentHistoryPage: 権限状態を更新 - canEdit: $canEdit');
      }
    } catch (e) {
      print('AssignmentHistoryPage: 設定変更による権限チェックエラー - $e');
      if (mounted) {
        setState(() {
          _canEditAssignmentHistory = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _groupAssignmentHistorySubscription?.cancel();
    _permissionSubscription?.cancel();
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
        body: const LoadingAnimationWidget(),
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
            FutureBuilder<Map<String, dynamic>?>(
              future: (() async {
                // まずUserSettingsFirestoreServiceから取得を試行
                final userSettingsResult =
                    await UserSettingsFirestoreService.getSetting(
                      'assignment_$dayKey',
                    );
                if (userSettingsResult != null) {
                  final assignments = _safeStringListFromDynamic(
                    userSettingsResult,
                  );
                  return {
                    'assignments': assignments,
                    'leftLabels': [],
                    'rightLabels': [],
                  };
                }

                // UserSettingsFirestoreServiceにない場合はAssignmentFirestoreServiceから取得
                try {
                  final firestoreResult =
                      await AssignmentFirestoreService.loadAssignmentHistoryWithLabels(
                        dayKey,
                      );
                  if (firestoreResult != null) {
                    // UserSettingsFirestoreServiceにも保存して次回から高速化
                    final assignments = _safeStringListFromDynamic(
                      firestoreResult['assignments'],
                    );
                    await UserSettingsFirestoreService.saveSetting(
                      'assignment_$dayKey',
                      assignments,
                    );
                    return {
                      'assignments': assignments,
                      'leftLabels': _safeStringListFromDynamic(
                        firestoreResult['leftLabels'],
                      ),
                      'rightLabels': _safeStringListFromDynamic(
                        firestoreResult['rightLabels'],
                      ),
                    };
                  }
                } catch (e) {
                  print(
                    'AssignmentHistoryPage: Firestoreからの履歴取得エラー ($dayKey): $e',
                  );
                }

                return null;
              })(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  final data = snapshot.data!;
                  final assignments = _safeStringListFromDynamic(
                    data['assignments'],
                  );
                  final leftLabels = _safeStringListFromDynamic(
                    data['leftLabels'],
                  );

                  if (assignments.isEmpty) {
                    return SizedBox.shrink(); // 空の履歴は表示しない
                  }

                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: themeSettings.cardBackgroundColor,
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
                              // 編集権限がある場合のみ編集・削除ボタンを表示
                              if (_canEditAssignmentHistory == true) ...[
                                IconButton(
                                  icon: Icon(
                                    Icons.edit,
                                    color: Provider.of<ThemeSettings>(
                                      context,
                                    ).iconColor,
                                  ),
                                  tooltip: '編集',
                                  onPressed: () =>
                                      _editAssignment(dayKey, assignments),
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
                          ...assignments.asMap().entries.map((entry) {
                            final index = entry.key;
                            final assignment = entry.value;
                            final label = leftLabels.length > index
                                ? leftLabels[index]
                                : '担当${index + 1}';
                            return _buildAssignmentRow(label, assignment);
                          }),
                        ],
                      ),
                    ),
                  );
                }
                // データが取得できない場合（null）も表示しない
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Provider.of<ThemeSettings>(
                          context,
                        ).iconColor.withOpacity(0.5),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '担当履歴がありません',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Provider.of<ThemeSettings>(context).fontColor1,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '担当表で記録した履歴がここに表示されます',
                        style: TextStyle(
                          fontSize: 14,
                          color: Provider.of<ThemeSettings>(
                            context,
                          ).fontColor1.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
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
