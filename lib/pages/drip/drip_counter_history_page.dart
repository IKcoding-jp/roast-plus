import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/group_provider.dart';
import '../../services/group_data_sync_service.dart';
import '../../services/user_settings_firestore_service.dart';
import 'dart:developer' as developer;

class DripCounterHistoryPage extends StatefulWidget {
  const DripCounterHistoryPage({super.key});

  @override
  State<DripCounterHistoryPage> createState() => _DripCounterHistoryPageState();
}

class _DripCounterHistoryPageState extends State<DripCounterHistoryPage> {
  List<Map<String, dynamic>> _records = [];

  String? _currentGroupId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkGroupChange();
      final groupProvider = context.read<GroupProvider>();
      groupProvider.addListener(_checkGroupChange);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkGroupChange();
  }

  /// グループ変更をチェックして、必要に応じてデータをクリア
  void _checkGroupChange() {
    final groupProvider = context.read<GroupProvider>();
    final currentGroupId = groupProvider.hasGroup
        ? groupProvider.currentGroup!.id
        : null;

    // グループが変更された場合、データを再読み込み
    if (_currentGroupId != null && _currentGroupId != currentGroupId) {
      // グループ変更を検知

      setState(() {
        _records = [];
      });

      // グループ移行時にローカルデータもクリア
      _clearLocalData();

      if (groupProvider.hasGroup) {
        _loadGroupRecords();
      } else {
        _loadRecords();
      }
    } else if (_currentGroupId == null && currentGroupId != null) {
      // 初回グループ参加時
      // 初回グループ参加
      _loadGroupRecords();
    } else if (_currentGroupId != null && currentGroupId == null) {
      // グループ脱退時
      // グループ脱退
      _loadRecords();
    }

    _currentGroupId = currentGroupId;
  }

  Future<void> _loadRecords() async {
    try {
      final saved = await UserSettingsFirestoreService.getSetting(
        'dripPackRecords',
      );
      if (saved != null && mounted) {
        setState(() {
          _records = List<Map<String, dynamic>>.from(saved);
        });
      }
    } catch (e, st) {
      developer.log(
        'ドリップパック記録の読み込みエラー',
        name: 'DripCounterHistoryPage',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _loadGroupRecords() async {
    try {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.hasGroup) {
        final groupId = groupProvider.currentGroup!.id;
        // グループデータ読み込み開始

        final data = await GroupDataSyncService.getGroupDripCounterRecords(
          groupId,
        );

        if (mounted) {
          if (data != null && data['records'] != null) {
            setState(() {
              _records = List<Map<String, dynamic>>.from(data['records']);
            });
            // グループデータ読み込み完了
          } else {
            setState(() {
              _records = [];
            });
            // グループデータが存在しません
          }
        }
      }
    } catch (e) {
      // グループドリップパック記録の読み込みエラー
    }
  }

  Future<void> _saveRecords() async {
    try {
      await UserSettingsFirestoreService.saveSetting(
        'dripPackRecords',
        _records,
      );
    } catch (e, st) {
      developer.log(
        'ドリップパック記録の保存エラー',
        name: 'DripCounterHistoryPage',
        error: e,
        stackTrace: st,
      );
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

  void _deleteRecord(int index) {
    setState(() {
      _records.removeAt(index);
    });
    _saveRecords();
  }

  @override
  void dispose() {
    final groupProvider = context.read<GroupProvider>();
    groupProvider.removeListener(_checkGroupChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ドリップパック履歴'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: _records.isEmpty
          ? Center(child: Text('記録がありません'))
          : ListView.builder(
              itemCount: _records.length,
              itemExtent: 80.0, // 固定高さを設定してパフォーマンスを向上
              itemBuilder: (context, index) {
                final record = _records[index];
                return Card(
                  child: ListTile(
                    title: Text(
                      '${record['bean']}・${record['roast']}・${record['count']}袋',
                    ),
                    subtitle: Text(
                      '記録日時: ${record['timestamp'].toString().substring(0, 16).replaceFirst('T', ' ')}',
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _deleteRecord(index),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
