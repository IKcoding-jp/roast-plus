import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../services/assignment_firestore_service.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';

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
        title: Text(
          '担当編集 ($dateKey)',
          style: TextStyle(
            color: Provider.of<ThemeSettings>(context).fontColor1,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(controllers.length, (i) {
            final label =
                '${leftLabels[i]}${rightLabels[i].isNotEmpty ? '・${rightLabels[i]}' : ''}';
            return TextFormField(
              controller: controllers[i],
              style: TextStyle(
                color: Provider.of<ThemeSettings>(context).fontColor1,
              ),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(
                  color: Provider.of<ThemeSettings>(context).fontColor1,
                ),
              ),
            );
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'キャンセル',
              style: TextStyle(
                color: Provider.of<ThemeSettings>(context).fontColor1,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = controllers.map((c) => c.text).toList();
              prefs.setStringList('assignment_$dateKey', updated);
              // Firestoreにも保存
              await AssignmentFirestoreService.saveAssignmentHistory(
                dateKey: dateKey,
                assignments: updated,
              );
              Navigator.pop(context);
              setState(() {});
            },
            child: Text(
              '保存',
              style: TextStyle(
                color: Provider.of<ThemeSettings>(context).fontColor2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAssignment(String dateKey) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          '削除の確認',
          style: TextStyle(
            color: Provider.of<ThemeSettings>(context).fontColor1,
          ),
        ),
        content: Text(
          'この日の担当を削除してもよろしいですか？\n($dateKey)',
          style: TextStyle(
            color: Provider.of<ThemeSettings>(context).fontColor1,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'キャンセル',
              style: TextStyle(
                color: Provider.of<ThemeSettings>(context).fontColor1,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '削除',
              style: TextStyle(
                color: Provider.of<ThemeSettings>(context).fontColor2,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await prefs.remove('assignment_$dateKey');
      // Firestoreからも削除
      await AssignmentFirestoreService.deleteAssignmentHistory(dateKey);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context, listen: true);
    if (!isReady) {
      return Scaffold(
        appBar: AppBar(
          title: Text('担当履歴'),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final now = DateTime.now();
    final List<Widget> items = [];

    for (int i = 0; i < 31; i++) {
      final date = now.subtract(Duration(days: i));
      final dayKey = formatter.format(date);
      final weekday = weekdayFormatter.format(date);
      final data = prefs.getStringList('assignment_$dayKey');
      if (data != null) {
        items.add(
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: themeSettings.backgroundColor2 ?? Colors.white,
            margin: EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Provider.of<ThemeSettings>(context).iconColor,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$dayKey（$weekday）',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).fontColor1,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.edit,
                          color: Provider.of<ThemeSettings>(context).iconColor,
                        ),
                        tooltip: '編集',
                        onPressed: () => _editAssignment(dayKey, data),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        tooltip: '削除',
                        onPressed: () => _deleteAssignment(dayKey),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  if (data.isNotEmpty) _buildAssignmentRow('掃除機', data[0]),
                  if (data.length > 1) _buildAssignmentRow('机・ロースト', data[1]),
                  if (data.length > 2) _buildAssignmentRow('洗い物', data[2]),
                ],
              ),
            ),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('担当履歴'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: items.isEmpty
          ? Center(
              child: Text(
                '履歴がまだありません',
                style: TextStyle(
                  color: Provider.of<ThemeSettings>(context).fontColor1,
                ),
              ),
            )
          : Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: ListView(padding: EdgeInsets.all(16), children: items),
            ),
    );
  }

  Widget _buildAssignmentRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            Icons.label_outline,
            size: 18,
            color: Provider.of<ThemeSettings>(context).iconColor,
          ),
          SizedBox(width: 6),
          Text(
            '$label：',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Provider.of<ThemeSettings>(context).fontColor1,
            ),
          ),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                color: Provider.of<ThemeSettings>(context).fontColor1,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
