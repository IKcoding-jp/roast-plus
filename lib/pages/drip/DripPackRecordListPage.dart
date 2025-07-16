import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../widgets/bean_name_with_sticker.dart';

class DripPackRecordListPage extends StatefulWidget {
  const DripPackRecordListPage({super.key});

  @override
  State<DripPackRecordListPage> createState() => _DripPackRecordListPageState();
}

class _DripPackRecordListPageState extends State<DripPackRecordListPage> {
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;

  // 削除処理を追加
  Future<void> _deleteRecord(int index) async {
    setState(() {
      _records.removeAt(index);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dripPackRecords', json.encode(_records));
  }

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
    final themeSettings = Provider.of<ThemeSettings>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('ドリップパック記録一覧'),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
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
                    '新しい記録を追加してください',
                    style: TextStyle(
                      color: themeSettings.fontColor1.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16),
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
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: themeSettings.backgroundColor2 ?? Colors.white,
                  margin: EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: EdgeInsets.all(16),
                    leading: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: themeSettings.iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.coffee,
                        color: themeSettings.iconColor,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      '${record['bean'] ?? ''}・${record['roast'] ?? ''}・${record['count'] ?? 0}袋',
                      style: TextStyle(
                        fontSize: (16 * themeSettings.fontSizeScale).clamp(
                          12.0,
                          24.0,
                        ),
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
                              color: themeSettings.fontColor1.withOpacity(0.8),
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
                            color: themeSettings.fontColor1.withOpacity(0.6),
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
                                onPressed: () => Navigator.pop(context, false),
                                child: Text('キャンセル'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
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
    );
  }
}
