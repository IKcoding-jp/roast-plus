import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class DripPackRecordListPage extends StatefulWidget {
  const DripPackRecordListPage({super.key});

  @override
  State<DripPackRecordListPage> createState() => _DripPackRecordListPageState();
}

class _DripPackRecordListPageState extends State<DripPackRecordListPage> {
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;

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
        _isLoading = false;
      });
    } else {
      setState(() {
        _records = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ドリップパック記録一覧'),
        backgroundColor: Color(0xFF795548),
      ),
      backgroundColor: Color(0xFFFFF8E1),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _records.isEmpty
          ? Center(child: Text('記録がありません'))
          : ListView.builder(
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
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Color(0xFF795548), width: 1),
                  ),
                  color: Color(0xFFFFF8E1),
                  child: ListTile(
                    leading: Icon(Icons.coffee, color: Color(0xFF795548)),
                    title: Text('${record['bean']}（${record['roast']}）'),
                    subtitle: Text(
                      '数: ${record['count']}   日時: $formattedDate',
                    ),
                  ),
                );
              },
            ),
    );
  }
}
