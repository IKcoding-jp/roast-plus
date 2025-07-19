import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';

class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  List<Map<String, dynamic>> _trashedRecords = [];

  @override
  void initState() {
    super.initState();
    _loadTrashedRecords();
  }

  Future<void> _loadTrashedRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trashed = prefs.getStringList('trashedRecords') ?? [];

      if (mounted) {
        setState(() {
          _trashedRecords =
              trashed
                  .map((e) => Map<String, dynamic>.from(json.decode(e)))
                  .toList()
                ..sort(
                  (a, b) =>
                      (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''),
                );
        });
      }
    } catch (e) {
      print('ゴミ箱記録の読み込みエラー: $e');
    }
  }

  Future<void> _saveTrashedRecords() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(
      'trashedRecords',
      _trashedRecords.map((e) => json.encode(e)).toList(),
    );
  }

  Future<void> _restoreRecord(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final record = _trashedRecords[index];

    final saved = prefs.getString('roastRecords');
    List<Map<String, dynamic>> roastRecords = [];
    if (saved != null) {
      roastRecords = (json.decode(saved) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    roastRecords.add(record);
    prefs.setString('roastRecords', json.encode(roastRecords));

    setState(() {
      _trashedRecords.removeAt(index);
    });
    await _saveTrashedRecords();

    Navigator.pop(context, true);
  }

  Future<void> _deleteRecord(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Provider.of<ThemeSettings>(
          context,
        ).dialogBackgroundColor,
        titleTextStyle: TextStyle(
          color: Provider.of<ThemeSettings>(context).dialogTextColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: Provider.of<ThemeSettings>(context).dialogTextColor,
          fontSize: 16,
        ),
        title: Text('完全に削除しますか？'),
        content: Text('この記録は元に戻せません。'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Provider.of<ThemeSettings>(context).fontColor1,
            ),
            child: Text('キャンセル'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('削除'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _trashedRecords.removeAt(index);
      });
      await _saveTrashedRecords();
      setState(() {}); // 強制再描画
    }
  }

  Future<void> _deleteAllRecords() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Provider.of<ThemeSettings>(
          context,
        ).dialogBackgroundColor,
        titleTextStyle: TextStyle(
          color: Provider.of<ThemeSettings>(context).dialogTextColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: Provider.of<ThemeSettings>(context).dialogTextColor,
          fontSize: 16,
        ),
        title: Text('ゴミ箱を空にしますか？'),
        content: Text('すべての記録が完全に削除され、元に戻せません。'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Provider.of<ThemeSettings>(context).fontColor1,
            ),
            child: Text('キャンセル'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('すべて削除'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _trashedRecords.clear();
      });
      await _saveTrashedRecords();
      setState(() {}); // 強制再描画
    }
  }

  String _formatTimestamp(String timestamp) {
    final dateTime = DateTime.tryParse(timestamp);
    if (dateTime == null) return '';
    return DateFormat('yyyy/MM/dd HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ゴミ箱'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_forever),
            tooltip: 'すべて完全削除',
            onPressed: _trashedRecords.isEmpty ? null : _deleteAllRecords,
          ),
        ],
      ),
      body: _trashedRecords.isEmpty
          ? const Center(child: Text('ゴミ箱は空です'))
          : ListView.builder(
              itemCount: _trashedRecords.length,
              itemBuilder: (context, index) {
                final record = _trashedRecords[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(
                        '${record['bean']}（${record['weight']}g）',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('焙煎時間: ${record['time']}'),
                          Text('煎り度: ${record['roast']}'),
                          Text(
                            '記録日時: ${_formatTimestamp(record['timestamp'] ?? '')}',
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.restore_from_trash),
                            tooltip: '復元',
                            onPressed: () async {
                              await _restoreRecord(index);
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete),
                            tooltip: '完全削除',
                            onPressed: () async {
                              await _deleteRecord(index);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
