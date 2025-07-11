import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('dripPackRecords');
    if (saved != null) {
      setState(() {
        _records = List<Map<String, dynamic>>.from(json.decode(saved));
      });
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
