import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../models/group_provider.dart';
import '../../services/drip_counter_firestore_service.dart';
import '../../services/group_data_sync_service.dart';

class DripCounterHistoryPage extends StatefulWidget {
  const DripCounterHistoryPage({super.key});

  @override
  State<DripCounterHistoryPage> createState() => _DripCounterHistoryPageState();
}

class _DripCounterHistoryPageState extends State<DripCounterHistoryPage> {
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.groups.isNotEmpty) {
        _loadGroupRecords();
      } else {
        _loadRecords();
      }
      groupProvider.addListener(() {
        if (groupProvider.groups.isNotEmpty) {
          _loadGroupRecords();
        } else {
          _loadRecords();
        }
      });
    });
  }

  Future<void> _loadRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('dripPackRecords');
      if (saved != null && mounted) {
        setState(() {
          _records = List<Map<String, dynamic>>.from(json.decode(saved));
        });
      }
    } catch (e) {
      print('ドリップパック記録の読み込みエラー: $e');
    }
  }

  Future<void> _loadGroupRecords() async {
    try {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.groups.isNotEmpty) {
        final group = groupProvider.groups.first;
        final data = await GroupDataSyncService.getGroupDripCounterRecords(
          group.id,
        );
        if (data != null && data['records'] != null) {
          setState(() {
            _records = List<Map<String, dynamic>>.from(data['records']);
          });
        } else {
          setState(() {
            _records = [];
          });
        }
      }
    } catch (e) {
      print('グループドリップパック記録の読み込みエラー: $e');
    }
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dripPackRecords', json.encode(_records));
  }

  void _deleteRecord(int index) {
    setState(() {
      _records.removeAt(index);
    });
    _saveRecords();
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
