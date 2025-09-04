import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../models/theme_settings.dart';
import '../../models/group_provider.dart';
import '../../services/user_settings_firestore_service.dart';
import '../../services/group_data_sync_service.dart';

class DripPackRecordListPage extends StatefulWidget {
  const DripPackRecordListPage({super.key});

  @override
  State<DripPackRecordListPage> createState() => _DripPackRecordListPageState();
}

class _DripPackRecordListPageState extends State<DripPackRecordListPage> {
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;
  String? _currentGroupId;
  bool _isGroupMode = false;
  StreamSubscription<Map<String, dynamic>?>? _groupDataSubscription;

  // 削除処理を追加
  Future<void> _deleteRecord(int index) async {
    setState(() {
      _records.removeAt(index);
    });

    if (_isGroupMode) {
      // グループモードの場合はグループデータを更新
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      if (groupProvider.hasGroup) {
        final groupId = groupProvider.currentGroup!.id;
        try {
          await GroupDataSyncService.syncDripCounterRecords(groupId, {
            'records': _records,
          });
          // 記録削除をグループに同期完了
        } catch (e) {
          // グループ同期エラー
          // エラー時は元に戻す
          setState(() {
            _records.insert(index, _records[index]);
          });
        }
      }
    } else {
      // ローカルモードの場合はローカルデータを更新
      await UserSettingsFirestoreService.saveSetting(
        'dripPackRecords',
        _records,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _startGroupDataListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkGroupChange();
  }

  /// グループ変更をチェックして、必要に応じてデータをクリア
  void _checkGroupChange() {
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    final currentGroupId = groupProvider.hasGroup
        ? groupProvider.currentGroup!.id
        : null;

    // グループが変更された場合、データを再読み込み
    if (_currentGroupId != null && _currentGroupId != currentGroupId) {
      // グループ変更を検知

      // 1. 既存のリスナーを停止
      _groupDataSubscription?.cancel();
      _groupDataSubscription = null;

      // 2. データをクリア
      setState(() {
        _records = [];
        _isLoading = true;
        _isGroupMode = false;
      });

      // 3. ローカルデータをクリア
      _clearLocalData();

      // 4. 新しいグループのデータを読み込み
      _loadRecords();

      // 5. 新しいグループのリスナーを開始
      _startGroupDataListener();
    }

    _currentGroupId = currentGroupId;
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);

      if (groupProvider.hasGroup) {
        // グループモード：グループの共有データを取得
        final groupId = groupProvider.currentGroup!.id;
        // グループデータ読み込み開始

        final groupData = await GroupDataSyncService.getGroupDripCounterRecords(
          groupId,
        );

        if (mounted) {
          if (groupData != null && groupData['records'] != null) {
            setState(() {
              _records = List<Map<String, dynamic>>.from(groupData['records']);
              _isGroupMode = true;
              _isLoading = false;
            });
            // グループデータ読み込み完了
          } else {
            // グループデータがない場合は空の状態を設定
            setState(() {
              _records = [];
              _isGroupMode = true;
              _isLoading = false;
            });
            // グループデータが存在しません
          }
        }
      } else {
        // ローカルモード：ローカルデータを取得
        // ローカルデータ読み込み開始
        await _loadLocalRecords();
      }
    } catch (e) {
      // ドリップパック記録読み込みエラー
      // エラー時はローカルデータを取得
      if (mounted) {
        await _loadLocalRecords();
      }
    }
  }

  /// ローカル記録を読み込み
  Future<void> _loadLocalRecords() async {
    final saved = await UserSettingsFirestoreService.getSetting(
      'dripPackRecords',
    );
    if (saved != null) {
      setState(() {
        _records = List<Map<String, dynamic>>.from(saved);
        _isGroupMode = false;
        _isLoading = false;
      });
    } else {
      setState(() {
        _records = [];
        _isGroupMode = false;
        _isLoading = false;
      });
    }
  }

  /// ローカルデータをクリア
  Future<void> _clearLocalData() async {
    try {
      await UserSettingsFirestoreService.deleteSetting('dripPackRecords');
      // ローカルデータをクリア完了
    } catch (e) {
      // ローカルデータのクリアに失敗
    }
  }

  /// グループデータの変更を監視
  void _startGroupDataListener() {
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);

    if (groupProvider.hasGroup) {
      final groupId = groupProvider.currentGroup!.id;

      // グループデータリスナー開始

      // 既存のリスナーを停止
      _groupDataSubscription?.cancel();
      _groupDataSubscription = null;

      // 新しいリスナーを開始
      _groupDataSubscription =
          GroupDataSyncService.watchGroupDripCounterRecords(groupId).listen(
            (groupData) {
              if (mounted) {
                // グループデータ受信

                if (groupData != null && groupData['records'] != null) {
                  setState(() {
                    _records = List<Map<String, dynamic>>.from(
                      groupData['records'],
                    );
                    _isGroupMode = true;
                    _isLoading = false;
                  });
                  // グループデータの変更を検知
                } else {
                  // グループデータがない場合は空の状態を設定
                  setState(() {
                    _records = [];
                    _isGroupMode = true;
                    _isLoading = false;
                  });
                  // グループデータが空です
                }
              }
            },
            onError: (error) {
              // グループデータ監視エラー
            },
          );
    } else {
      // グループに参加していないため、リスナーを開始しません
    }
  }

  @override
  void dispose() {
    _groupDataSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('ドリップパック記録一覧'),
            const SizedBox(width: 8),
            Consumer<GroupProvider>(
              builder: (context, groupProvider, _) {
                if (groupProvider.groups.isNotEmpty) {
                  return Container(
                    margin: EdgeInsets.only(left: 4),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade400),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.groups,
                          size: 18,
                          color: Colors.blue.shade700,
                        ),
                      ],
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
        actions: [
          // グループ参加時のみ同期ボタンを表示
          Consumer<GroupProvider>(
            builder: (context, groupProvider, _) {
              if (groupProvider.hasGroup) {
                return IconButton(
                  icon: Icon(Icons.sync),
                  tooltip: 'グループデータと同期',
                  onPressed: () async {
                    setState(() {
                      _isLoading = true;
                    });
                    await _loadRecords();
                  },
                );
              }
              return SizedBox.shrink();
            },
          ),
        ],
      ),
      backgroundColor: themeSettings.backgroundColor,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: themeSettings.iconColor),
            )
          : _records.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.coffee, size: 64, color: themeSettings.iconColor),
                  SizedBox(height: 16),
                  Text(
                    '記録がありません',
                    style: TextStyle(
                      fontSize: 18 * themeSettings.fontSizeScale,
                      fontWeight: FontWeight.bold,
                      color: themeSettings.fontColor1,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _isGroupMode ? 'グループメンバーが記録を追加すると表示されます' : '新しい記録を追加してください',
                    style: TextStyle(
                      color: themeSettings.fontColor1.withValues(alpha: 0.7),
                    ),
                  ),
                  if (_isGroupMode) ...[
                    SizedBox(height: 16),
                    Text(
                      '※ グループ共有モードでは、メンバー全員の記録が表示されます',
                      style: TextStyle(
                        fontSize: 12 * themeSettings.fontSizeScale,
                        color: themeSettings.fontColor1.withValues(alpha: 0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            )
          : Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWeb ? 40.0 : 16.0,
                  vertical: 24.0,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWeb ? 600 : double.infinity,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _records.length,
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      final date =
                          DateTime.tryParse(record['timestamp'] ?? '') ??
                          DateTime.now();
                      final formattedDate = DateFormat(
                        'yyyy/MM/dd HH:mm',
                      ).format(date);
                      return Card(
                        elevation: isWeb ? 2 : 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(isWeb ? 12 : 16),
                        ),
                        color: themeSettings.cardBackgroundColor,
                        margin: EdgeInsets.only(bottom: isWeb ? 16 : 12),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(isWeb ? 20 : 16),
                          leading: Container(
                            padding: EdgeInsets.all(isWeb ? 10 : 8),
                            decoration: BoxDecoration(
                              color: themeSettings.iconColor.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(
                                isWeb ? 10 : 8,
                              ),
                            ),
                            child: Icon(
                              Icons.coffee,
                              color: themeSettings.iconColor,
                              size: isWeb ? 28 : 24,
                            ),
                          ),
                          title: Text(
                            '${record['bean'] ?? ''}・${record['roast'] ?? ''}・${record['count'] ?? 0}袋',
                            style: TextStyle(
                              fontSize: (16 * themeSettings.fontSizeScale)
                                  .clamp(12.0, 24.0),
                              fontWeight: FontWeight.bold,
                              color: themeSettings.fontColor1,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (record['memo'] != null &&
                                  record['memo'].toString().isNotEmpty) ...[
                                SizedBox(height: 8),
                                Text(
                                  record['memo'].toString(),
                                  style: TextStyle(
                                    fontSize: 14 * themeSettings.fontSizeScale,
                                    color: themeSettings.fontColor1.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              SizedBox(height: 8),
                              Text(
                                '記録日時: $formattedDate',
                                style: TextStyle(
                                  fontSize: 12 * themeSettings.fontSizeScale,
                                  color: themeSettings.fontColor1.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            tooltip: '削除',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('削除の確認'),
                                  content: Text('この記録を削除しますか？'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text('キャンセル'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(
                                        '削除',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _deleteRecord(index);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }
}
