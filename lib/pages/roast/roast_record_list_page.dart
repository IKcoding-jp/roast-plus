import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bysnapp/models/roast_record.dart';
import 'package:bysnapp/services/roast_record_firestore_service.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../widgets/bean_name_with_sticker.dart';
import 'package:bysnapp/pages/roast/roast_edit_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // 煎り度リスト仮
  final List<String> _roastList = ['全て', '浅煎り', '中煎り', '中深煎り', '深煎り'];

  // Firestoreストリーム購読用
  Stream<List<RoastRecord>>? _recordsStream;

  // グループ共有機能用の状態
  bool _canEditRoastRecords = true;
  bool _canDeleteRoastRecordsPermission = true;

  // リスナー管理用
  GroupProvider? _groupProvider;
  VoidCallback? _groupProviderListener;

  @override
  void initState() {
    super.initState();
    _filterExpanded = false;

    // 初期ストリームをグループ状態で分岐
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    if (groupProvider.groups.isNotEmpty) {
      _recordsStream = RoastRecordFirestoreService.getGroupRecordsStream(
        groupProvider.groups.first.id,
      );
    } else {
      _recordsStream = RoastRecordFirestoreService.getRecordsStream();
    }

    _setupGroupDataListener();
    _checkEditPermissions();
    _setupFirestoreListener();

    // GroupProviderのグループ読み込みを確認
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        final groupProvider = context.read<GroupProvider>();
        if (groupProvider.groups.isEmpty && !groupProvider.loading) {
          print('RoastRecordListPage: グループが読み込まれていないため、読み込みを開始します');
          groupProvider.loadUserGroups();
        } else if (groupProvider.groups.isNotEmpty) {
          print('RoastRecordListPage: グループが既に読み込まれています - グループデータ監視を開始');
          _startGroupDataWatching(groupProvider);
        }
      } catch (e) {
        print('RoastRecordListPage: グループ読み込み確認エラー: $e');
      }
    });
  }

  // グループデータの監視を開始
  void _startGroupDataWatching(GroupProvider groupProvider) {
    if (groupProvider.groups.isNotEmpty && !groupProvider.isWatchingGroupData) {
      print('RoastRecordListPage: グループデータ監視開始');
      groupProvider.startWatchingGroupData();
    }
  }

  // グループデータの監視を停止
  void _stopGroupDataWatching(GroupProvider groupProvider) {
    if (groupProvider.isWatchingGroupData) {
      print('RoastRecordListPage: グループデータ監視停止');
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
        print('RoastRecordListPage: リスナー削除エラー: $e');
      }
    }

    // グループデータ監視を停止
    if (_groupProvider != null) {
      try {
        _stopGroupDataWatching(_groupProvider!);
      } catch (e) {
        print('RoastRecordListPage: グループデータ監視停止エラー: $e');
      }
    }

    super.dispose();
  }

  // グループ権限チェック（削除）
  bool _canDeleteRoastRecords(BuildContext context) {
    return _canDeleteRoastRecordsPermission;
  }

  // グループ権限チェック（編集）
  bool _canEditRoastRecordsMethod(BuildContext context) {
    return _canEditRoastRecords;
  }

  // グループデータの変更を監視
  void _setupGroupDataListener() {
    print('RoastRecordListPage: グループデータリスナーを設定開始');

    // GroupProviderの変更を監視
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        final groupProvider = context.read<GroupProvider>();
        _groupProvider = groupProvider;

        // 初回のグループデータ監視開始
        _startGroupDataWatching(groupProvider);

        // GroupProviderの変更を監視
        _groupProviderListener = () {
          if (!mounted) return;

          print('RoastRecordListPage: GroupProviderの変更を検知');
          print('RoastRecordListPage: グループ数: ${groupProvider.groups.length}');

          // グループが追加された場合、監視を開始
          _startGroupDataWatching(groupProvider);

          // グループ設定の変更を検知するため、常に権限チェックを実行
          _checkEditPermissions();
        };

        groupProvider.addListener(_groupProviderListener!);
      } catch (e) {
        print('RoastRecordListPage: グループデータリスナー設定エラー: $e');
      }
    });

    print('RoastRecordListPage: グループデータリスナー設定完了');
  }

  // 編集権限をチェック
  Future<void> _checkEditPermissions() async {
    if (!mounted) return;

    try {
      print('RoastRecordListPage: 編集権限チェック開始');
      final groupProvider = context.read<GroupProvider>();
      print('RoastRecordListPage: グループ数: ${groupProvider.groups.length}');

      if (groupProvider.groups.isNotEmpty) {
        final group = groupProvider.groups.first;
        final currentUser = FirebaseAuth.instance.currentUser;
        print('RoastRecordListPage: 現在のユーザー: ${currentUser?.uid}');

        if (currentUser != null) {
          final userRole = group.getMemberRole(currentUser.uid);
          print('RoastRecordListPage: ユーザーロール: $userRole');
          final groupSettings = groupProvider.getCurrentGroupSettings();
          print('RoastRecordListPage: グループ設定: $groupSettings');

          if (groupSettings != null) {
            // 焙煎記録の編集権限をチェック
            final canEditRoastRecords = groupSettings.canEditDataType(
              'roast_records',
              userRole ?? GroupRole.member,
            );
            // 焙煎記録の削除権限をチェック（リーダーのみ）
            final canDeleteRoastRecords =
                userRole == GroupRole.leader || userRole == GroupRole.admin;

            print('RoastRecordListPage: 権限チェック結果:');
            print(
              'RoastRecordListPage: - roast_records編集: $canEditRoastRecords',
            );
            print(
              'RoastRecordListPage: - roast_records削除: $canDeleteRoastRecords',
            );

            // 現在の権限と比較して変更があったかチェック
            final hasChanged =
                _canEditRoastRecords != canEditRoastRecords ||
                _canDeleteRoastRecordsPermission != canDeleteRoastRecords;

            if (hasChanged) {
              print('RoastRecordListPage: 権限に変更を検知しました！');
              print(
                'RoastRecordListPage: 変更前 - 編集: $_canEditRoastRecords, 削除: $_canDeleteRoastRecordsPermission',
              );
              print(
                'RoastRecordListPage: 変更後 - 編集: $canEditRoastRecords, 削除: $canDeleteRoastRecords',
              );
            }

            if (mounted) {
              try {
                setState(() {
                  _canEditRoastRecords = canEditRoastRecords;
                  _canDeleteRoastRecordsPermission = canDeleteRoastRecords;
                });

                // 権限が変更された場合はストリームを再設定
                _setupFirestoreListener();
              } catch (e) {
                print('RoastRecordListPage: setStateエラー: $e');
              }
            }

            print('RoastRecordListPage: 編集権限チェック完了');
            print('RoastRecordListPage: 焙煎記録編集可能: $_canEditRoastRecords');
            print(
              'RoastRecordListPage: 焙煎記録削除可能: $_canDeleteRoastRecordsPermission',
            );
          } else {
            print('RoastRecordListPage: グループ設定がnullです');
          }
        } else {
          print('RoastRecordListPage: 現在のユーザーがnullです');
        }
      } else {
        // グループに参加していない場合は編集・削除可能
        if (mounted) {
          try {
            setState(() {
              _canEditRoastRecords = true;
              _canDeleteRoastRecordsPermission = true;
            });

            // 権限が変更された場合はストリームを再設定
            _setupFirestoreListener();
          } catch (e) {
            print('RoastRecordListPage: setStateエラー（グループなし）: $e');
          }
        }
        print('RoastRecordListPage: グループがありません - 編集・削除可能に設定');
      }
    } catch (e) {
      print('RoastRecordListPage: 編集権限チェックエラー: $e');
      print('RoastRecordListPage: エラーの詳細: ${e.toString()}');
    }
  }

  // Firestoreからのリアルタイム更新を監視
  void _setupFirestoreListener() {
    if (!mounted) return;

    print('RoastRecordListPage: Firestoreリスナーを設定開始');
    try {
      final groupProvider = context.read<GroupProvider>();

      if (groupProvider.groups.isNotEmpty) {
        final group = groupProvider.groups.first;

        // グループに参加している場合は、常にグループの焙煎記録を表示
        _recordsStream = RoastRecordFirestoreService.getGroupRecordsStream(
          group.id,
        );
      } else {
        // グループに参加していない場合は個人の記録を表示
        _recordsStream = RoastRecordFirestoreService.getRecordsStream();
      }

      print('RoastRecordListPage: Firestoreリスナー設定完了');
    } catch (e) {
      print('RoastRecordListPage: Firestoreリスナー設定エラー: $e');
      try {
        _recordsStream = RoastRecordFirestoreService.getRecordsStream();
      } catch (e2) {
        print('RoastRecordListPage: フォールバックストリーム設定エラー: $e2');
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
      if (groupSettings?.getPermissionForDataType('roast_records') ==
          DataPermission.adminOnly) {
        message = '管理者のみ削除可能です';
      } else if (groupSettings?.getPermissionForDataType('roast_records') ==
          DataPermission.leaderOnly) {
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
      if (groupSettings?.getPermissionForDataType('roast_records') ==
          DataPermission.adminOnly) {
        message = '管理者のみ編集可能です';
      } else if (groupSettings?.getPermissionForDataType('roast_records') ==
          DataPermission.leaderOnly) {
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
    // 権限チェック
    if (!_canEditRoastRecordsMethod(context)) {
      _showEditPermissionError();
      return;
    }

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
        if (groupProvider.groups.isNotEmpty) {
          // グループに参加している場合はグループの記録を更新
          await RoastRecordFirestoreService.updateGroupRecord(
            groupProvider.groups.first.id,
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
          groupProvider.groups.first.id,
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
              return Center(child: Text('エラーが発生しました')); // エラー表示
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
                    icon: Icon(_selectionMode ? Icons.close : Icons.select_all),
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
              body: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Column(
                  children: [
                    // 検索・フィルターカード
                    Card(
                      margin: EdgeInsets.all(16),
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color:
                          Provider.of<ThemeSettings>(
                            context,
                          ).backgroundColor2 ??
                          Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // タイトル部分
                            GestureDetector(
                              onTap: () => setState(
                                () => _filterExpanded = !_filterExpanded,
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
                                        color: Provider.of<ThemeSettings>(
                                          context,
                                        ).fontColor1,
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
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'キーワード検索',
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: Provider.of<ThemeSettings>(
                                        context,
                                      ).iconColor,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                  ),
                                  onChanged: (v) =>
                                      setState(() => _searchKeyword = v),
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
                                      onChanged: (v) =>
                                          setState(() => _selectedBean = v),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Flexible(
                                    flex: 2,
                                    child: _buildFilterDropdown(
                                      value: _selectedRoast ?? '全て',
                                      items: _roastList,
                                      label: '煎り度',
                                      onChanged: (v) =>
                                          setState(() => _selectedRoast = v),
                                      // ここで20文字制限＋省略を適用
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
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate:
                                              _startDate ?? DateTime.now(),
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2100),
                                        );
                                        if (picked != null) {
                                          setState(() => _startDate = picked);
                                        }
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '~',
                                    style: TextStyle(
                                      color: Provider.of<ThemeSettings>(
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
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate:
                                              _endDate ?? DateTime.now(),
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2100),
                                        );
                                        if (picked != null) {
                                          setState(() => _endDate = picked);
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
                                    backgroundColor: Provider.of<ThemeSettings>(
                                      context,
                                    ).buttonColor,
                                    foregroundColor: Provider.of<ThemeSettings>(
                                      context,
                                    ).fontColor2,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
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
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                color:
                                    Provider.of<ThemeSettings>(
                                      context,
                                    ).backgroundColor2 ??
                                    Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.list,
                                        size: 64,
                                        color: Provider.of<ThemeSettings>(
                                          context,
                                        ).iconColor,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        '記録がありません',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Provider.of<ThemeSettings>(
                                            context,
                                          ).fontColor1,
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
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                color:
                                    Provider.of<ThemeSettings>(
                                      context,
                                    ).backgroundColor2 ??
                                    Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        size: 64,
                                        color: Provider.of<ThemeSettings>(
                                          context,
                                        ).iconColor,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        '条件に合う記録がありません',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Provider.of<ThemeSettings>(
                                            context,
                                          ).fontColor1,
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
                          : ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              itemCount: filteredRecords.length,
                              // itemExtent: 120.0, // 固定高さを削除
                              itemBuilder: (context, index) {
                                final record = filteredRecords[index];
                                final selected = _selectedIndexes.contains(
                                  index,
                                );
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Card(
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    color: selected
                                        ? Provider.of<ThemeSettings>(
                                            context,
                                          ).buttonColor.withOpacity(0.08)
                                        : Provider.of<ThemeSettings>(
                                                context,
                                              ).backgroundColor2 ??
                                              Colors.white,
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(16),
                                      onTap: () => _editRecord(record),
                                      leading: Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Provider.of<ThemeSettings>(
                                            context,
                                          ).iconColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.coffee,
                                          color: Provider.of<ThemeSettings>(
                                            context,
                                          ).iconColor,
                                          size: 24,
                                        ),
                                      ),
                                      title: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          BeanNameWithSticker(
                                            beanName: record.bean,
                                            textStyle: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Provider.of<ThemeSettings>(
                                                context,
                                              ).fontColor1,
                                            ),
                                            stickerSize: 16.0,
                                          ),
                                          Text(
                                            '（${record.weight}g）',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Provider.of<ThemeSettings>(
                                                context,
                                              ).fontColor1.withOpacity(0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.timer,
                                                size: 16,
                                                color:
                                                    Provider.of<ThemeSettings>(
                                                      context,
                                                    ).iconColor,
                                              ),
                                              SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  '焙煎時間: ${record.time}',
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                                color:
                                                    Provider.of<ThemeSettings>(
                                                      context,
                                                    ).iconColor,
                                              ),
                                              SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  '煎り度: ${record.roast}',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (record.memo
                                              .trim()
                                              .isNotEmpty) ...[
                                            SizedBox(height: 4),
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Icon(
                                                  Icons.note,
                                                  size: 16,
                                                  color:
                                                      Provider.of<
                                                            ThemeSettings
                                                          >(context)
                                                          .iconColor,
                                                ),
                                                SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    record.memo,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                    ),
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
                                                color:
                                                    Provider.of<ThemeSettings>(
                                                      context,
                                                    ).iconColor,
                                              ),
                                              SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  _formatTimestamp(
                                                    record.timestamp,
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color:
                                                        Provider.of<
                                                              ThemeSettings
                                                            >(context)
                                                            .fontColor1
                                                            .withOpacity(0.7),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      trailing: !_selectionMode
                                          ? (_canDeleteRoastRecords(context)
                                                ? IconButton(
                                                    icon: Icon(
                                                      Icons.delete,
                                                      color:
                                                          Provider.of<
                                                                ThemeSettings
                                                              >(context)
                                                              .iconColor,
                                                    ),
                                                    onPressed: () =>
                                                        _deleteRecords([index]),
                                                    iconSize: 24,
                                                    padding: EdgeInsets.all(8),
                                                  )
                                                : null)
                                          : Checkbox(
                                              value: selected,
                                              onChanged: (val) =>
                                                  _toggleSelection(index),
                                              activeColor:
                                                  Provider.of<ThemeSettings>(
                                                    context,
                                                  ).buttonColor,
                                            ),
                                    ),
                                  ),
                                );
                              }, // itemBuilder
                            ),
                    ),
                  ],
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
        border: Border.all(color: Color(0xFF795548).withOpacity(0.3)),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
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
          border: Border.all(color: Color(0xFF795548).withOpacity(0.3)),
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
