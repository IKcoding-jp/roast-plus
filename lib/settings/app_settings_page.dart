import 'package:bysnapp/pages/schedule/schedule_time_label_edit_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:bysnapp/main.dart';

class AppSettingsPage extends StatelessWidget {
  const AppSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('アプリ設定')),
      body: const Center(child: Text('アプリ全体の設定項目をここに追加していきます。')),
    );
  }
}

// 記録リストからユニークな豆名リストを抽出
List<String> getBeanListFromRecords(List<Map<String, dynamic>> records) {
  final set = <String>{};
  for (final r in records) {
    final b = (r['bean'] ?? '').toString();
    if (b.isNotEmpty) set.add(b);
  }
  final list = set.toList();
  list.sort();
  return list;
}

class RoastTimerSettingsPage extends StatelessWidget {
  const RoastTimerSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('タイマー設定')),
      body: Center(child: Text('ここに個別設定を追加できます')),
    );
  }
}

class TodaySchedulePage extends StatefulWidget {
  const TodaySchedulePage({super.key});

  @override
  State<TodaySchedulePage> createState() => _TodaySchedulePageState();
}

class _TodaySchedulePageState extends State<TodaySchedulePage>
    with AutomaticKeepAliveClientMixin {
  List<String> _scheduleLabels = [];
  Map<String, String> _scheduleContents = {};
  final Map<String, TextEditingController> _scheduleControllers = {};
  // ...他の変数...

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
    _initControllers();
  }

  void _initControllers() {
    // 新規ラベルのみcontroller生成
    for (final label in _scheduleLabels) {
      if (!_scheduleControllers.containsKey(label)) {
        _scheduleControllers[label] = TextEditingController(
          text: _scheduleContents[label] ?? '',
        );
      }
    }
    // 不要なコントローラを破棄
    final toRemove = _scheduleControllers.keys
        .where((k) => !_scheduleLabels.contains(k))
        .toList();
    for (final k in toRemove) {
      _scheduleControllers[k]?.dispose();
      _scheduleControllers.remove(k);
    }
  }

  Future<void> _saveSchedules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'todaySchedule_labels',
        json.encode(_scheduleLabels),
      );
      await prefs.setString(
        'todaySchedule_contents',
        json.encode(_scheduleContents),
      );
    } catch (_) {}
  }

  Future<void> _loadSchedules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final labelsStr = prefs.getString('todaySchedule_labels');
      final contentsStr = prefs.getString('todaySchedule_contents');
      List<String> loadedLabels = [];
      Map<String, String> loadedContents = {};
      if (labelsStr != null) {
        loadedLabels = List<String>.from(json.decode(labelsStr));
      }
      if (contentsStr != null) {
        loadedContents = Map<String, String>.from(json.decode(contentsStr));
      }
      setState(() {
        _scheduleLabels = loadedLabels;
        _scheduleContents = loadedContents;
      });
      _initControllers();
    } catch (_) {
      setState(() {
        _scheduleLabels = [];
        _scheduleContents = {};
      });
      _initControllers();
    }
  }

  void _openLabelEdit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleTimeLabelEditPage(
          labels: _scheduleLabels,
          onLabelsChanged: (newLabels) {
            setState(() {
              _scheduleLabels = List.from(newLabels);
              _scheduleContents.removeWhere(
                (k, v) => !_scheduleLabels.contains(k),
              );
              _initControllers();
            });
            _saveSchedules();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _scheduleControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ← 必ず呼ぶ
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.schedule, color: Color(0xFF795548)),
            SizedBox(width: 8),
            Text(
              '本日のスケジュール',
              style: TextStyle(
                color: Color(0xFF2C1D17),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            tooltip: '時間ラベル編集',
            onPressed: _openLabelEdit,
          ),
        ],
        backgroundColor: Color(0xFFFFF8E1),
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF795548)),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF8E1), Color(0xFFFFF8E1)],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              ..._scheduleLabels.map(
                (label) => Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: Color(0xFFFFF8E1),
                  margin: EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 2,
                      horizontal: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFF795548).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF795548),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _scheduleControllers[label],
                            keyboardType: TextInputType.text,
                            enableSuggestions: true,
                            autocorrect: true,
                            onChanged: (v) {
                              setState(() {
                                _scheduleContents[label] = v;
                              });
                              _saveSchedules();
                            },
                            maxLines: null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
