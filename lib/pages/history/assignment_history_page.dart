import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class AssignmentHistoryPage extends StatefulWidget {
  const AssignmentHistoryPage({super.key});

  @override
  State<AssignmentHistoryPage> createState() => _AssignmentHistoryPageState();
}

class _AssignmentHistoryPageState extends State<AssignmentHistoryPage> {
  late SharedPreferences prefs;
  bool isReady = false;

  final formatter = DateFormat('yyyy-MM-dd');
  final weekdayFormatter = DateFormat('E', 'ja_JP');

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      isReady = true;
    });
  }

  Future<void> _editAssignment(String dateKey, List<String> original) async {
    List<TextEditingController> controllers = original
        .map((e) => TextEditingController(text: e))
        .toList();

    final leftLabels = prefs.getStringList('leftLabels') ?? ['掃除機', '机', '洗い物'];
    final rightLabels = prefs.getStringList('rightLabels') ?? ['', 'ロースト', ''];

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('担当編集 ($dateKey)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(controllers.length, (i) {
            final label =
                '${leftLabels[i]}${rightLabels[i].isNotEmpty ? '・${rightLabels[i]}' : ''}';
            return TextFormField(
              controller: controllers[i],
              decoration: InputDecoration(labelText: label),
            );
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              final updated = controllers.map((c) => c.text).toList();
              prefs.setStringList('assignment_$dateKey', updated);
              Navigator.pop(context);
              setState(() {});
            },
            child: Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAssignment(String dateKey) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('削除の確認'),
        content: Text('この日の担当を削除してもよろしいですか？\n($dateKey)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await prefs.remove('assignment_$dateKey');
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isReady) {
      return Scaffold(
        appBar: AppBar(title: Text('担当履歴')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final now = DateTime.now();
    final List<Widget> items = [];

    for (int i = 0; i < 31; i++) {
      final date = now.subtract(Duration(days: i));
      final dayKey = formatter.format(date);
      final weekday = weekdayFormatter.format(date);

      // ✅ 土日も表示する（continue削除済み！）
      final data = prefs.getStringList('assignment_$dayKey');
      if (data != null) {
        items.add(
          Card(
            margin: EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$dayKey（$weekday）',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit),
                        tooltip: '編集',
                        onPressed: () => _editAssignment(dayKey, data),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        tooltip: '削除',
                        onPressed: () => _deleteAssignment(dayKey),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  if (data.isNotEmpty) Text('掃除機：${data[0]}'),
                  if (data.length > 1) Text('机・ロースト：${data[1]}'),
                  if (data.length > 2) Text('洗い物：${data[2]}'),
                ],
              ),
            ),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text('担当履歴')),
      body: items.isEmpty
          ? Center(child: Text('履歴がまだありません'))
          : ListView(padding: EdgeInsets.all(16), children: items),
    );
  }
}