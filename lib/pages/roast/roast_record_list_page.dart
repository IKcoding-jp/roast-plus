import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:developer' as developer;
import 'package:intl/intl.dart';
import 'package:roastplus/models/roast_record.dart';
import 'package:roastplus/services/roast_record_firestore_service.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../widgets/bean_name_with_sticker.dart';
import 'package:roastplus/pages/roast/roast_edit_page.dart';
import '../../utils/permission_utils.dart';

class RoastRecordListPage extends StatefulWidget {
  const RoastRecordListPage({super.key});

  @override
  State<RoastRecordListPage> createState() => _RoastRecordListPageState();
}

class _RoastRecordListPageState extends State<RoastRecordListPage> {
  // Firestoreから取得した焙煎記録リスト
  List<RoastRecord> _records = [];
  final Set<int> _selectedIndexes = {};
  bool _selectionMode = false;

  // 検索・フィルター用の状態
  String _searchKeyword = '';
  String? _selectedBean;
  String? _selectedRoast;
  DateTime? _startDate;
  DateTime? _endDate;

  // フィルター折りたたみ状態
  bool _filterExpanded = false;

  // 豆リスト仮（本来はデータから動的取得）
  // final List<String> _beanList = ['全て', 'ブラジル', 'コロンビア', 'エチオピア', 'ペルー'];

  // 動的に焙煎記録一覧から豆リストを生成
  List<String> get _dynamicBeanList {
    final beans = _records
        .map((r) => r.bean)
        .where((b) => b.isNotEmpty)
        .toSet()
        .toList();
    beans.sort();
    // 最大50件までに制限
    final limitedBeans = beans.take(50).toList();
    return ['全て', ...limitedBeans];
  }

  Widget _buildRecordItem(RoastRecord record, bool selected, int index) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: kIsWeb ? 0 : 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: selected
            ? Provider.of<ThemeSettings>(
                context,
              ).buttonColor.withValues(alpha: 0.08)
            : Provider.of<ThemeSettings>(context).cardBackgroundColor,
        child: GestureDetector(
          onTap: null, // タップ機能を無効化
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // アイコン部分
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Provider.of<ThemeSettings>(
                      context,
                    ).iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.coffee,
                    color: Provider.of<ThemeSettings>(context).iconColor,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                // メインコンテンツ部分
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // タイトル部分
                      BeanNameWithSticker(
                        beanName: record.bean,
                        textStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Provider.of<ThemeSettings>(context).fontColor1,
                        ),
                        stickerSize: 16.0,
                      ),
                      Text(
                        '（${record.weight}g）',
                        style: TextStyle(
                          fontSize: 14,
                          color: Provider.of<ThemeSettings>(
                            context,
                          ).fontColor1.withValues(alpha: 0.7),
                        ),
                      ),
                      SizedBox(height: 8),
                      // 詳細情報
                      Row(
                        children: [
                          Icon(
                            Icons.timer,
                            size: 16,
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).iconColor,
                          ),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '焙煎時間: ${record.time}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            size: 16,
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).iconColor,
                          ),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '煎り度: ${record.roast}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (record.memo.trim().isNotEmpty) ...[
                        SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.note,
                              size: 16,
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).iconColor,
                            ),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                record.memo,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).iconColor,
                          ),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _formatTimestamp(record.timestamp),
                              style: TextStyle(
                                fontSize: 13,
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).fontColor1.withValues(alpha: 0.7),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // アクションボタン部分
                if (!_selectionMode)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 編集ボタン
                      if (_canEditRoastRecords)
                        IconButton(
                          icon: Icon(
                            Icons.edit,
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).iconColor,
                          ),
                          onPressed: () => _editRecord(record),
                          iconSize: 24,
                          padding: EdgeInsets.all(8),
                          tooltip: '編集',
                        ),
                      // 削除ボタン
                      if (_canDeleteRoastRecords(context) &&
                          _canDeleteRoastRecordsPermission)
                        IconButton(
                          icon: Icon(
                            Icons.delete,
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).iconColor,
                          ),
                          onPressed: () => _deleteRecords([index]),
                          iconSize: 24,
                          padding: EdgeInsets.all(8),
                          tooltip: '削除',
                        ),
                    ],
                  )
                else
                  Checkbox(
                    value: selected,
                    onChanged: (val) => _toggleSelection(index),
                    activeColor: Provider.of<ThemeSettings>(
                      context,
                    ).buttonColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 煎り度リスト仮
  final List<String> _roastList = ['全て', '浅煎り', '中煎り', '中深煎り', '深煎り'];

  // Firestoreストリーム購読用
  Stream<List<RoastRecord>>? _recordsStream;

  // グループ共有機能用の状態
  bool _canEditRoastRecords = true;
  bool _canDeleteRoastRecordsPermission = true;
  bool _isCheckingPermissions = true;

  // リスナー管理用
  GroupProvider? _groupProvider;
  VoidCallback? _groupProviderListener;

  @override
  void initState() {
    super.initState();
    _filterExpanded = false;

    // 初期ストリームをグループ状態で分岐
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    if (groupProvider.hasGroup) {
      _recordsStream = RoastRecordFirestoreService.getGroupRecordsStream(
        groupProvider.currentGroup!.id,
      );
    } else {
      _recordsStream = RoastRecordFirestoreService.getRecordsStream();
    }

    _setupGroupDataListener();
    _setupFirestoreListener();

    // GroupProviderのグループ読み込みを確認
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        final groupProvider = context.read<GroupProvider>();
        if (groupProvider.groups.isEmpty && !groupProvider.loading) {
          developer.log(
            'グループが読み込まれていないため、読み込みを開始します',
            name: 'RoastRecordListPage',
          );
          groupProvider.loadUserGroups();
        } else if (groupProvider.hasGroup) {
          developer.log(
            'グループが既に読み込まれています - グループデータ監視を開始',
            name: 'RoastRecordListPage',
          );
          _startGroupDataWatching(groupProvider);
          // グループが既に読み込まれている場合は権限チェックを実行
          _checkEditPermissions();
        } else {
          // グループに参加していない場合は権限チェックを実行
          _checkEditPermissions();
        }
      } catch (e) {
        developer.log(
          'グループ読み込み確認エラー: $e',
          name: 'RoastRecordListPage',
          error: e,
        );
        // エラーが発生した場合も権限チェックを実行
        _checkEditPermissions();
      }
    });
  }

  // グループデータの監視を開始
  void _startGroupDataWatching(GroupProvider groupProvider) {
    if (groupProvider.hasGroup && !groupProvider.isWatchingGroupData) {
      developer.log('グループデータ監視開始', name: 'RoastRecordListPage');
      groupProvider.startWatchingGroupData();
    }
  }

  // グループデータの監視を停止
  void _stopGroupDataWatching(GroupProvider groupProvider) {
    if (groupProvider.isWatchingGroupData) {
      developer.log('グループデータ監視停止', name: 'RoastRecordListPage');
      groupProvider.stopWatchingGroupData();
    }
  }

  @override
  void dispose() {
    // グループプロバイダーのリスナーを削除
    if (_groupProvider != null && _groupProviderListener != null) {
      try {
        _groupProvider!.removeListener(_groupProviderListener!);
      } catch (e) {
        developer.log('リスナー削除エラー: $e', name: 'RoastRecordListPage', error: e);
      }
    }

    // グループデータ監視を停止
    if (_groupProvider != null) {
      try {
        _stopGroupDataWatching(_groupProvider!);
      } catch (e) {
        developer.log(
          'グループデータ監視停止エラー: $e',
          name: 'RoastRecordListPage',
          error: e,
        );
      }
    }

    super.dispose();
  }

  // グループ権限チェック（削除）
  bool _canDeleteRoastRecords(BuildContext context) {
    return _canDeleteRoastRecordsPermission;
  }

  // 編集権限をチェック
  Future<void> _checkEditPermissions() async {
    try {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.hasGroup) {
        developer.log(
          'グループ権限チェック開始 - グループID: ${groupProvider.currentGroup!.id}',
          name: 'RoastRecordListPage',
        );

        final canEdit = await PermissionUtils.canEditDataType(
          groupId: groupProvider.currentGroup!.id,
          dataType: 'roastRecords',
        );
        final canDelete = await PermissionUtils.canDeleteDataType(
          groupId: groupProvider.currentGroup!.id,
          dataType: 'roastRecords',
        );

        developer.log(
          '権限チェック結果 - 編集: $canEdit, 削除: $canDelete',
          name: 'RoastRecordListPage',
        );

        setState(() {
          _canEditRoastRecords = canEdit;
          _canDeleteRoastRecordsPermission = canDelete;
          _isCheckingPermissions = false;
        });
      } else {
        developer.log(
          'グループに参加していないため、編集・削除権限を有効化',
          name: 'RoastRecordListPage',
        );
        setState(() {
          _canEditRoastRecords = true;
          _canDeleteRoastRecordsPermission = true;
          _isCheckingPermissions = false;
        });
      }
    } catch (e) {
      developer.log(
        '焙煎記録編集権限チェックエラー: $e',
        name: 'RoastRecordListPage',
        error: e,
      );
      setState(() {
        _canEditRoastRecords = false;
        _canDeleteRoastRecordsPermission = false;
        _isCheckingPermissions = false;
      });
    }
  }

  // 編集権限チェックメソッド（UI用）
  bool _canEditRoastRecordsMethod(BuildContext context) {
    return _canEditRoastRecords;
  }

  // グループデータの変更を監視
  void _setupGroupDataListener() {
    developer.log('グループデータリスナーを設定開始', name: 'RoastRecordListPage');

    // GroupProviderの変更を監視
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        final groupProvider = context.read<GroupProvider>();
        _groupProvider = groupProvider;

        // 初回のグループデータ監視開始
        _startGroupDataWatching(groupProvider);

        // 初回の権限チェックを実行
        if (groupProvider.hasGroup) {
          developer.log('初回権限チェックを実行', name: 'RoastRecordListPage');
          _checkEditPermissions();
        }

        // GroupProviderの変更を監視
        _groupProviderListener = () {
          if (!mounted) return;

          developer.log('GroupProviderの変更を検知', name: 'RoastRecordListPage');
          developer.log(
            'グループ数: ${groupProvider.groups.length}',
            name: 'RoastRecordListPage',
          );

          // グループが追加された場合、監視を開始
          _startGroupDataWatching(groupProvider);

          // グループ設定の変更を検知するため、常に権限チェックを実行
          _checkEditPermissions();
        };

        groupProvider.addListener(_groupProviderListener!);
      } catch (e) {
        developer.log(
          'グループデータリスナー設定エラー: $e',
          name: 'RoastRecordListPage',
          error: e,
        );
      }
    });

    developer.log('グループデータリスナー設定完了', name: 'RoastRecordListPage');
  }

  // Firestoreからのリアルタイム更新を監視
  void _setupFirestoreListener() {
    if (!mounted) return;

    developer.log('Firestoreリスナーを設定開始', name: 'RoastRecordListPage');
    try {
      final groupProvider = context.read<GroupProvider>();

      if (groupProvider.hasGroup) {
        final group = groupProvider.currentGroup!;

        // グループに参加している場合は、常にグループの焙煎記録を表示
        _recordsStream = RoastRecordFirestoreService.getGroupRecordsStream(
          group.id,
        );
      } else {
        // グループに参加していない場合は個人の記録を表示
        _recordsStream = RoastRecordFirestoreService.getRecordsStream();
      }

      developer.log('Firestoreリスナー設定完了', name: 'RoastRecordListPage');
    } catch (e) {
      developer.log(
        'Firestoreリスナー設定エラー: $e',
        name: 'RoastRecordListPage',
        error: e,
      );
      try {
        _recordsStream = RoastRecordFirestoreService.getRecordsStream();
      } catch (e2) {
        developer.log(
          'フォールバックストリーム設定エラー: $e2',
          name: 'RoastRecordListPage',
          error: e2,
        );
      }
    }
  }

  // 権限エラーメッセージを表示
  void _showPermissionError() {
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    final currentGroup = groupProvider.currentGroup;

    String message;
    if (currentGroup == null) {
      message = 'グループに参加していません';
    } else {
      final groupSettings = groupProvider.getCurrentGroupSettings();
      if (groupSettings?.getPermissionForDataType('roastRecords') ==
          AccessLevel.adminOnly) {
        message = '管理者のみ削除可能です';
      } else if (groupSettings?.getPermissionForDataType('roastRecords') ==
          AccessLevel.adminLeader) {
        message = '管理者・リーダーのみ削除可能です';
      } else {
        message = '権限がありません';
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 編集権限エラーメッセージを表示
  void _showEditPermissionError() {
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    final currentGroup = groupProvider.currentGroup;

    String message;
    if (currentGroup != null) {
      final groupSettings = groupProvider.getCurrentGroupSettings();
      if (groupSettings?.getPermissionForDataType('roastRecords') ==
          AccessLevel.adminOnly) {
        message = '管理者のみ編集可能です';
      } else if (groupSettings?.getPermissionForDataType('roastRecords') ==
          AccessLevel.adminLeader) {
        message = '管理者・リーダーのみ編集可能です';
      } else {
        message = '権限がありません';
      }
    } else {
      // グループに参加していない場合は編集可能なので、エラーメッセージを表示しない
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 焙煎記録を編集
  void _editRecord(RoastRecord record) {
    developer.log(
      '編集開始 - 権限状態: $_canEditRoastRecords',
      name: 'RoastRecordListPage',
    );

    // 権限チェック
    if (!_canEditRoastRecordsMethod(context)) {
      developer.log('編集権限なし - エラーメッセージを表示', name: 'RoastRecordListPage');
      _showEditPermissionError();
      return;
    }

    developer.log('編集権限あり - RoastEditPageに遷移', name: 'RoastRecordListPage');

    final initialData = {
      'bean': record.bean,
      'weight': record.weight.toString(),
      'time': record.time,
      'roast': record.roast,
      'memo': record.memo,
      'timestamp': record.timestamp.toIso8601String(),
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoastEditPage(initialData: initialData),
      ),
    ).then((updatedData) async {
      if (updatedData != null) {
        if (!mounted) return;
        developer.log('編集完了 - Firestoreを更新', name: 'RoastRecordListPage');
        // 更新されたデータでFirestoreを更新
        final updatedRecord = RoastRecord(
          id: record.id,
          bean: updatedData['bean'],
          weight: int.tryParse(updatedData['weight']) ?? 0,
          time: updatedData['time'],
          roast: updatedData['roast'],
          memo: updatedData['memo'] ?? '',
          timestamp: DateTime.parse(updatedData['timestamp']),
        );

        final groupProvider = context.read<GroupProvider>();
        if (groupProvider.hasGroup) {
          // グループに参加している場合はグループの記録を更新
          await RoastRecordFirestoreService.updateGroupRecord(
            groupProvider.currentGroup!.id,
            updatedRecord,
          );
        } else {
          // グループに参加していない場合は個人の記録を更新
          await RoastRecordFirestoreService.updateRecord(updatedRecord);
        }
      }
    });
  }

  List<RoastRecord> _getFilteredRecords() {
    if (_records.isEmpty) return [];
    return _records.where((record) {
      try {
        // 検索キーワード
        if (_searchKeyword.isNotEmpty) {
          final keyword = _searchKeyword.toLowerCase();
          final bean = record.bean.toLowerCase();
          final weight = record.weight.toString();
          final time = record.time.toLowerCase();
          final roast = record.roast.toLowerCase();
          if (!bean.contains(keyword) &&
              !weight.contains(keyword) &&
              !time.contains(keyword) &&
              !roast.contains(keyword)) {
            return false;
          }
        }
        // 豆フィルター
        if (_selectedBean != null &&
            _selectedBean != '全て' &&
            record.bean != _selectedBean) {
          return false;
        }
        // 煎り度フィルター
        if (_selectedRoast != null &&
            _selectedRoast != '全て' &&
            record.roast != _selectedRoast) {
          return false;
        }
        // 日付範囲フィルター
        if (_startDate != null || _endDate != null) {
          final date = record.timestamp;
          if (_startDate != null && date.isBefore(_startDate!)) return false;
          if (_endDate != null && date.isAfter(_endDate!)) return false;
        }
        return true;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  // Firestore削除
  Future<void> _deleteRecords(List<int> indexes) async {
    // 権限チェック
    if (!_canDeleteRoastRecords(context)) {
      _showPermissionError();
      return;
    }

    final toRemove = indexes.map((i) => _records[i]).toList();
    final groupProvider = context.read<GroupProvider>();

    for (final record in toRemove) {
      if (groupProvider.groups.isNotEmpty) {
        // グループに参加している場合はグループの記録を削除
        await RoastRecordFirestoreService.deleteGroupRecord(
          groupProvider.currentGroup!.id,
          record.id,
        );
      } else {
        // グループに参加していない場合は個人の記録を削除
        await RoastRecordFirestoreService.deleteRecord(record.id);
      }
    }
    setState(() {
      _selectedIndexes.clear();
      _selectionMode = false;
    });
  }

  String _formatTimestamp(DateTime timestamp) {
    return DateFormat('yyyy/MM/dd HH:mm').format(timestamp);
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndexes.contains(index)) {
        _selectedIndexes.remove(index);
      } else {
        _selectedIndexes.add(index);
      }
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedIndexes.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GroupProvider>(
      builder: (context, groupProvider, child) {
        return StreamBuilder<List<RoastRecord>>(
          stream: _recordsStream ?? Stream.value([]),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Scaffold(
                appBar: AppBar(
                  title: Row(
                    children: [
                      Icon(
                        Icons.list,
                        color: Provider.of<ThemeSettings>(context).iconColor,
                      ),
                      SizedBox(width: 8),
                      Text('焙煎記録一覧'),
                    ],
                  ),
                ),
                body: Center(child: Text('エラーが発生しました')),
              );
            }

            _records = snapshot.data ?? [];
            final filteredRecords = _getFilteredRecords();

            return Scaffold(
              appBar: AppBar(
                title: Row(
                  children: [
                    Icon(
                      Icons.list,
                      color: Provider.of<ThemeSettings>(context).iconColor,
                    ),
                    SizedBox(width: 8),
                    Text('焙煎記録一覧'),
                    // グループ状態バッジを追加
                    if (groupProvider.groups.isNotEmpty)
                      Container(
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
                      ),
                    // デバッグ用権限状態表示
                    if (!_isCheckingPermissions)
                      Container(
                        margin: EdgeInsets.only(left: 8),
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _canEditRoastRecords
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _canEditRoastRecords
                                ? Colors.green.shade400
                                : Colors.red.shade400,
                          ),
                        ),
                        child: Text(
                          _canEditRoastRecords ? '編集可' : '編集不可',
                          style: TextStyle(
                            fontSize: 10,
                            color: _canEditRoastRecords
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                actions: [
                  // 編集・削除権限がある場合のみ選択ボタンを表示
                  if (_canEditRoastRecords && _canDeleteRoastRecordsPermission)
                    IconButton(
                      icon: Icon(
                        _selectionMode ? Icons.close : Icons.select_all,
                      ),
                      onPressed: _toggleSelectionMode,
                    ),
                  if (_selectionMode &&
                      _selectedIndexes.isNotEmpty &&
                      _canDeleteRoastRecords(context))
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () =>
                          _deleteRecords(_selectedIndexes.toList()),
                    ),
                ],
              ),
              body: _isCheckingPermissions
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Provider.of<ThemeSettings>(context).buttonColor,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Loading...',
                            style: TextStyle(
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).fontColor1,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: kIsWeb ? 1200 : double.infinity,
                          ),
                          child: Column(
                            children: [
                              // 検索・フィルターカード
                              Card(
                                margin: EdgeInsets.all(16),
                                elevation: 6,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).cardBackgroundColor,
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // タイトル部分
                                      GestureDetector(
                                        onTap: () => setState(
                                          () => _filterExpanded =
                                              !_filterExpanded,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.search,
                                              color: Provider.of<ThemeSettings>(
                                                context,
                                              ).iconColor,
                                              size: 24,
                                            ),
                                            SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                '検索・フィルター',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      Provider.of<
                                                            ThemeSettings
                                                          >(context)
                                                          .fontColor1,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              _filterExpanded
                                                  ? Icons.expand_less
                                                  : Icons.expand_more,
                                              color: Provider.of<ThemeSettings>(
                                                context,
                                              ).iconColor,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (_filterExpanded) ...[
                                        SizedBox(height: 16),
                                        // 検索バー
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          child: TextField(
                                            decoration: InputDecoration(
                                              hintText: 'キーワード検索',
                                              prefixIcon: Icon(
                                                Icons.search,
                                                color:
                                                    Provider.of<ThemeSettings>(
                                                      context,
                                                    ).iconColor,
                                              ),
                                              border: InputBorder.none,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 12,
                                                  ),
                                            ),
                                            onChanged: (v) => setState(
                                              () => _searchKeyword = v,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 14),
                                        // フィルター行
                                        Row(
                                          children: [
                                            Flexible(
                                              flex: 3,
                                              child: _buildFilterDropdown(
                                                value: _selectedBean ?? '全て',
                                                items: _dynamicBeanList,
                                                label: '豆の種類',
                                                onChanged: (v) => setState(
                                                  () => _selectedBean = v,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 10),
                                            Flexible(
                                              flex: 2,
                                              child: _buildFilterDropdown(
                                                value: _selectedRoast ?? '全て',
                                                items: _roastList,
                                                label: '煎り度',
                                                onChanged: (v) => setState(
                                                  () => _selectedRoast = v,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 14),
                                        // 日付フィルター
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildDatePicker(
                                                label: '開始日',
                                                date: _startDate,
                                                onTap: () async {
                                                  final picked =
                                                      await showDatePicker(
                                                        context: context,
                                                        initialDate:
                                                            _startDate ??
                                                            DateTime.now(),
                                                        firstDate: DateTime(
                                                          2020,
                                                        ),
                                                        lastDate: DateTime(
                                                          2100,
                                                        ),
                                                      );
                                                  if (picked != null) {
                                                    setState(
                                                      () => _startDate = picked,
                                                    );
                                                  }
                                                },
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              '~',
                                              style: TextStyle(
                                                color:
                                                    Provider.of<ThemeSettings>(
                                                      context,
                                                    ).fontColor1,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: _buildDatePicker(
                                                label: '終了日',
                                                date: _endDate,
                                                onTap: () async {
                                                  final picked =
                                                      await showDatePicker(
                                                        context: context,
                                                        initialDate:
                                                            _endDate ??
                                                            DateTime.now(),
                                                        firstDate: DateTime(
                                                          2020,
                                                        ),
                                                        lastDate: DateTime(
                                                          2100,
                                                        ),
                                                      );
                                                  if (picked != null) {
                                                    setState(
                                                      () => _endDate = picked,
                                                    );
                                                  }
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 14),
                                        // リセットボタン
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: ElevatedButton.icon(
                                            icon: Icon(Icons.refresh, size: 18),
                                            label: Text('リセット'),
                                            onPressed: () {
                                              setState(() {
                                                _searchKeyword = '';
                                                _selectedBean = null;
                                                _selectedRoast = null;
                                                _startDate = null;
                                                _endDate = null;
                                              });
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Provider.of<ThemeSettings>(
                                                    context,
                                                  ).buttonColor,
                                              foregroundColor:
                                                  Provider.of<ThemeSettings>(
                                                    context,
                                                  ).fontColor2,
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              elevation: 4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),

                              // 記録リスト
                              Expanded(
                                child: _records.isEmpty
                                    ? Center(
                                        child: Card(
                                          elevation: 6,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          color: Provider.of<ThemeSettings>(
                                            context,
                                          ).cardBackgroundColor,
                                          child: Padding(
                                            padding: const EdgeInsets.all(40),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.list,
                                                  size: 64,
                                                  color:
                                                      Provider.of<
                                                            ThemeSettings
                                                          >(context)
                                                          .iconColor,
                                                ),
                                                SizedBox(height: 16),
                                                Text(
                                                  '記録がありません',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        Provider.of<
                                                              ThemeSettings
                                                            >(context)
                                                            .fontColor1,
                                                  ),
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  '焙煎記録を入力してからご利用ください',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      )
                                    : filteredRecords.isEmpty
                                    ? Center(
                                        child: Card(
                                          elevation: 6,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          color: Provider.of<ThemeSettings>(
                                            context,
                                          ).cardBackgroundColor,
                                          child: Padding(
                                            padding: const EdgeInsets.all(40),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.search_off,
                                                  size: 64,
                                                  color:
                                                      Provider.of<
                                                            ThemeSettings
                                                          >(context)
                                                          .iconColor,
                                                ),
                                                SizedBox(height: 16),
                                                Text(
                                                  '条件に合う記録がありません',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        Provider.of<
                                                              ThemeSettings
                                                            >(context)
                                                            .fontColor1,
                                                  ),
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  '検索条件を変更してください',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      )
                                    : (kIsWeb
                                          ? GridView.builder(
                                              padding: EdgeInsets.only(
                                                left: 8,
                                                right: 8,
                                                bottom:
                                                    MediaQuery.of(
                                                      context,
                                                    ).padding.bottom +
                                                    16,
                                              ),
                                              gridDelegate:
                                                  SliverGridDelegateWithFixedCrossAxisCount(
                                                    crossAxisCount: 3,
                                                    crossAxisSpacing: 12,
                                                    mainAxisSpacing: 12,
                                                    mainAxisExtent: 176,
                                                  ),
                                              itemCount: filteredRecords.length,
                                              itemBuilder: (context, index) {
                                                final record =
                                                    filteredRecords[index];
                                                final selected =
                                                    _selectedIndexes.contains(
                                                      index,
                                                    );
                                                return _buildRecordItem(
                                                  record,
                                                  selected,
                                                  index,
                                                );
                                              },
                                            )
                                          : ListView.builder(
                                              padding: EdgeInsets.only(
                                                left: 8,
                                                right: 8,
                                                bottom:
                                                    MediaQuery.of(
                                                      context,
                                                    ).padding.bottom +
                                                    16,
                                              ),
                                              itemCount: filteredRecords.length,
                                              physics:
                                                  AlwaysScrollableScrollPhysics(),
                                              itemBuilder: (context, index) {
                                                final record =
                                                    filteredRecords[index];
                                                final selected =
                                                    _selectedIndexes.contains(
                                                      index,
                                                    );
                                                return _buildRecordItem(
                                                  record,
                                                  selected,
                                                  index,
                                                );
                                              },
                                            )),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required String label,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF795548).withValues(alpha: 0.3)),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        items: items
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(
                  item.length > 20 ? '${item.substring(0, 20)}…' : item,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          labelStyle: TextStyle(color: Color(0xFF795548)),
        ),
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFF795548).withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF795548),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              date != null ? DateFormat('yyyy/MM/dd').format(date) : '',
              style: TextStyle(
                fontSize: 14,
                color: date != null ? Color(0xFF2C1D17) : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
