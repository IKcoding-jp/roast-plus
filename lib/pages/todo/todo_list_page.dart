import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:bysnapp/main.dart';
import 'package:bysnapp/pages/labels/label_edit_page.dart';
import 'package:bysnapp/pages/home/AssignmentBoard.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';

import '../roast/roast_scheduler_tab.dart' show RoastSchedulerTab;
import '../schedule/schedule_time_label_edit_page.dart';
import 'package:bysnapp/models/roast_break_time.dart';
import '../../services/schedule_firestore_service.dart';
import '../../services/roast_break_time_firestore_service.dart';

class TodoListPage extends StatefulWidget {
  const TodoListPage({super.key});

  @override
  State<TodoListPage> createState() => TodoListPageState();
}

class TodoListPageState extends State<TodoListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TodoItem> _todos = [];
  late SharedPreferences prefs;
  final TextEditingController _controller = TextEditingController();
  TimeOfDay? _selectedTime;

  // 本日のスケジュール機能を追加
  List<String> _scheduleLabels = [''];
  Map<String, String> _scheduleContents = {};

  final String _storageKey = 'todoList';

  // 1. Stateに追加
  final Map<String, TextEditingController> _scheduleControllers = {};

  // 2. ラベル追加・削除・初期化時にコントローラを管理
  void _initScheduleControllers() {
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

  // --- 休憩時間設定用 ---
  List<RoastBreakTime> _roastBreakTimes = [];

  Future<void> _openRoastSettings() async {
    List<RoastBreakTime> tempBreaks = List.from(_roastBreakTimes);
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('休憩時間を設定'),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...tempBreaks.asMap().entries.map((entry) {
                      int i = entry.key;
                      RoastBreakTime b = entry.value;
                      return Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: b.start,
                                );
                                if (picked != null) {
                                  setState(() {
                                    tempBreaks[i] = RoastBreakTime(
                                      start: picked,
                                      end: b.end,
                                    );
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(labelText: '開始'),
                                child: Text(b.start.format(context)),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: b.end,
                                );
                                if (picked != null) {
                                  setState(() {
                                    tempBreaks[i] = RoastBreakTime(
                                      start: b.start,
                                      end: picked,
                                    );
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(labelText: '終了'),
                                child: Text(b.end.format(context)),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                tempBreaks.removeAt(i);
                              });
                            },
                          ),
                        ],
                      );
                    }),
                    SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: Icon(Icons.add),
                        label: Text('休憩時間を追加'),
                        onPressed: () {
                          setState(() {
                            tempBreaks.add(
                              RoastBreakTime(
                                start: TimeOfDay(hour: 12, minute: 0),
                                end: TimeOfDay(hour: 12, minute: 30),
                              ),
                            );
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('キャンセル'),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  child: Text('保存'),
                  onPressed: () async {
                    setState(() {
                      _roastBreakTimes = List.from(tempBreaks);
                    });
                    final prefs = await SharedPreferences.getInstance();
                    final jsonList = _roastBreakTimes
                        .map((b) => b.toJson())
                        .toList();
                    prefs.setString('roastBreakTimes', json.encode(jsonList));
                    // Firestoreにも保存
                    try {
                      await RoastBreakTimeFirestoreService.saveBreakTimes(
                        _roastBreakTimes,
                      );
                    } catch (_) {}
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _loadTodos();
    _loadSchedules();
    _initScheduleControllers();
    // 休憩時間リストの初期値をロード
    SharedPreferences.getInstance().then((prefs) {
      final jsonStr = prefs.getString('roastBreakTimes');
      if (jsonStr != null) {
        final list = (json.decode(jsonStr) as List)
            .map((e) => RoastBreakTime.fromJson(e))
            .toList();
        setState(() {
          _roastBreakTimes = list;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.dispose();
    for (final c in _scheduleControllers.values) {
      c.dispose();
    }
    super.dispose();
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
      _initScheduleControllers();
    } catch (_) {
      setState(() {
        _scheduleLabels = [];
        _scheduleContents = {};
      });
      _initScheduleControllers();
    }
  }

  // 3. ラベル編集後やスケジュールロード後にもコントローラを再初期化
  void _openLabelEdit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleTimeLabelEditPage(
          labels: _scheduleLabels,
          onLabelsChanged: (newLabels) {
            setState(() {
              _scheduleLabels = List.from(newLabels);
              // _scheduleContents からは値を消さずに残す（ラベルが復活したときに内容も復活するため）
              _initScheduleControllers();
            });
            _saveSchedules();
          },
        ),
      ),
    );
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
      // Firestoreにも自動保存
      try {
        await ScheduleFirestoreService.saveTodayTodoSchedule(
          labels: _scheduleLabels,
          contents: _scheduleContents,
        );
      } catch (_) {}
    } catch (_) {}
  }

  Future<void> _loadTodos() async {
    prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_storageKey) ?? [];
    // _sortByTime は常に true（設定読み込み不要）
    List<TodoItem> loaded = saved.map(TodoItem.fromString).toList();
    loaded.sort(_compareTodoByTime);
    setState(() {
      _todos = loaded;
    });
  }

  // 追加: 時間順比較関数
  int _compareTodoByTime(TodoItem a, TodoItem b) {
    final aHas = a.time.isNotEmpty;
    final bHas = b.time.isNotEmpty;
    if (aHas && bHas) {
      final aParts = a.time.split(':');
      final bParts = b.time.split(':');
      final aMinutes = int.parse(aParts[0]) * 60 + int.parse(aParts[1]);
      final bMinutes = int.parse(bParts[0]) * 60 + int.parse(bParts[1]);
      return aMinutes.compareTo(bMinutes);
    } else if (aHas && !bHas) {
      return -1;
    } else if (!aHas && bHas) {
      return 1;
    }
    return 0;
  }

  // 追加: ソート実行
  void _sortTodos() {
    _todos.sort(_compareTodoByTime);
  }

  Future<void> _saveTodos() async {
    final saved = _todos.map((e) => e.toStorageString()).toList();
    await prefs.setStringList(_storageKey, saved);
    // Firestoreにも自動保存
    try {
      await ScheduleFirestoreService.saveTodayTodoList(
        todos: _todos
            .map((e) => {'title': e.title, 'isDone': e.isDone, 'time': e.time})
            .toList(),
      );
    } catch (_) {}
    // ソート設定は固定のため保存不要
  }

  void _addTodo() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final time = _selectedTime != null ? _selectedTime!.format(context) : '';
    setState(() {
      _todos.add(TodoItem(title: text, isDone: false, time: time));
      _sortTodos();
      _controller.clear();
      _selectedTime = null;
    });
    _saveTodos();
  }

  void _toggleDone(int index) {
    setState(() {
      _todos[index].isDone = !_todos[index].isDone;
    });
    _saveTodos();
  }

  void _deleteTodo(int index) {
    setState(() {
      _todos.removeAt(index);
      _sortTodos();
    });
    _saveTodos();
  }

  // 追加: 全削除
  Future<void> _clearTodos() async {
    if (_todos.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('すべて削除'),
        content: Text('リストをすべて削除しますか？'),
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
      setState(() {
        _todos.clear();
        _sortTodos();
      });
      _saveTodos();
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // 追加: ToDoを編集するダイアログ
  Future<void> _editTodo(int index) async {
    final item = _todos[index];
    final titleController = TextEditingController(text: item.title);
    TimeOfDay? editedTime;

    // 既存の時刻をパース
    if (item.time.isNotEmpty) {
      final parts = item.time.split(':');
      if (parts.length == 2) {
        editedTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('ToDoを編集'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(labelText: 'タイトル'),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    editedTime != null
                        ? '時刻: ${editedTime!.format(context)}'
                        : '時刻: --:--',
                  ),
                ),
                TextButton(
                  child: Text('変更'),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: editedTime ?? TimeOfDay.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        editedTime = picked;
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('キャンセル'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text('保存'),
            onPressed: () {
              final newTitle = titleController.text.trim();
              setState(() {
                if (newTitle.isNotEmpty) _todos[index].title = newTitle;
                _todos[index].time = editedTime != null
                    ? editedTime!.format(context)
                    : '';
                _sortTodos();
              });
              _saveTodos();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  // Firestore同期用setter
  void setTodosFromFirestore(List<Map<String, dynamic>> todos) {
    setState(() {
      _todos = todos.map(TodoItem.fromMap).toList();
    });
  }

  void setScheduleFromFirestore(Map<String, dynamic> schedule) {
    setState(() {
      _scheduleLabels = List<String>.from(schedule['labels'] ?? []);
      _scheduleContents = Map<String, String>.from(schedule['contents'] ?? {});
      _initScheduleControllers();
    });
  }

  void setTimeLabelsFromFirestore(List<String> labels) {
    setState(() {
      _scheduleLabels = labels;
      _initScheduleControllers();
    });
  }

  void setRoastBreakTimesFromFirestore(List<RoastBreakTime> breaks) {
    setState(() {
      _roastBreakTimes = List<RoastBreakTime>.from(breaks);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // タブ数に合わせる
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(Icons.local_fire_department, color: Colors.white),
              SizedBox(width: 8),
              Text('スケジュール管理'),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(kToolbarHeight),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: Offset(-26, 0), // 必要に応じて微調整
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelPadding: EdgeInsets.only(left: 0, right: 24),
                  padding: EdgeInsets.zero,
                  indicatorPadding: EdgeInsets.zero,
                  tabs: [
                    Tab(text: '本日のスケジュール'),
                    Tab(text: 'ローストスケジュール'),
                    Tab(text: 'TODOリスト'),
                  ],
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Color(0xFF795548),
                ),
              ),
            ),
          ),
          actions: [
            // タブインデックスによるアクション切り替え
            Builder(
              builder: (context) {
                final tabIndex = _tabController.index;
                if (tabIndex == 0) {
                  return IconButton(
                    icon: Icon(Icons.today),
                    tooltip: '時間ラベル編集',
                    onPressed: _openLabelEdit,
                  );
                } else if (tabIndex == 1) {
                  // ローストスケジュール: 休憩時間設定
                  return IconButton(
                    icon: Icon(Icons.event_available),
                    tooltip: '休憩時間を設定',
                    onPressed: _openRoastSettings,
                  );
                } else if (tabIndex == 2) {
                  // TODOリスト: すべて削除
                  return Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.delete_sweep),
                        tooltip: 'すべて削除',
                        onPressed: _clearTodos,
                      ),
                    ],
                  );
                }
                return SizedBox.shrink();
              },
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // --- 本日のスケジュールタブ ---
            Padding(
              padding: EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color:
                      Provider.of<ThemeSettings>(context).backgroundColor2 ??
                      Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              color: Color(0xFF795548),
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '本日のスケジュール',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF795548),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        ..._scheduleLabels.map(
                          (label) => Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF795548).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF795548),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
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
                                    style: TextStyle(fontSize: 15),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: Color(0xFF795548),
                                          width: 2,
                                        ),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // --- ローストスケジュールタブ ---
            RoastSchedulerTab(breakTimes: _roastBreakTimes),
            // --- TODOリストタブ ---
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // 入力部分
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color:
                        Provider.of<ThemeSettings>(context).backgroundColor2 ??
                        Colors.white,
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.add_task,
                                color: Color(0xFF795548),
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '新しいタスクを追加',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF795548),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _controller,
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      hintText: 'やることを入力',
                                      hintStyle: TextStyle(
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color:
                                      Theme.of(context)
                                          .elevatedButtonTheme
                                          .style
                                          ?.backgroundColor
                                          ?.resolve({}) ??
                                      Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.access_time,
                                    color:
                                        Theme.of(context)
                                            .elevatedButtonTheme
                                            .style
                                            ?.foregroundColor
                                            ?.resolve({}) ??
                                        Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: _pickTime,
                                  tooltip: '時刻を設定',
                                  padding: EdgeInsets.all(12),
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color:
                                      Theme.of(context)
                                          .elevatedButtonTheme
                                          .style
                                          ?.backgroundColor
                                          ?.resolve({}) ??
                                      Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.add,
                                    color:
                                        Theme.of(context)
                                            .elevatedButtonTheme
                                            .style
                                            ?.foregroundColor
                                            ?.resolve({}) ??
                                        Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: _addTodo,
                                  tooltip: '追加',
                                  padding: EdgeInsets.all(12),
                                ),
                              ),
                            ],
                          ),
                          if (_selectedTime != null)
                            Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: Color(0xFF795548),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '選択した時刻: ${_selectedTime!.format(context)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF795548),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  // タスク一覧
                  Expanded(
                    child: _todos.isEmpty
                        ? Align(
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: double.infinity,
                              child: Card(
                                elevation: 6,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                color:
                                    Provider.of<ThemeSettings>(
                                      context,
                                    ).backgroundColor2 ??
                                    Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.checklist,
                                        size: 64,
                                        color: Color(0xFF795548),
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'タスクがありません',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2C1D17),
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        '新しいタスクを追加してください',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _todos.length,
                            itemBuilder: (_, i) {
                              final item = _todos[i];
                              return Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                color:
                                    Provider.of<ThemeSettings>(
                                      context,
                                    ).backgroundColor2 ??
                                    Colors.white,
                                margin: EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  contentPadding: EdgeInsets.all(16),
                                  leading: GestureDetector(
                                    onTap: () => _toggleDone(i),
                                    child: Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: item.isDone
                                            ? Color(0xFF4CAF50).withOpacity(0.2)
                                            : Color(
                                                0xFF795548,
                                              ).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        item.isDone
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
                                        color: item.isDone
                                            ? Color(0xFF4CAF50)
                                            : Color(0xFF795548),
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    item.title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2C1D17),
                                      decoration: item.isDone
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                    ),
                                  ),
                                  subtitle: item.time.isNotEmpty
                                      ? Padding(
                                          padding: EdgeInsets.only(top: 8),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 16,
                                                color: Color(0xFF795548),
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                '予定時刻: ${item.time}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Color(0xFF795548),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : null,
                                  trailing: Container(
                                    decoration: BoxDecoration(
                                      color: Color(0xFFE57373).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.delete,
                                        color: Color(0xFFE57373),
                                        size: 20,
                                      ),
                                      onPressed: () => _deleteTodo(i),
                                      padding: EdgeInsets.all(8),
                                    ),
                                  ),
                                  onTap: () => _editTodo(i),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TodoItem {
  String title;
  bool isDone;
  String time;

  TodoItem({required this.title, required this.isDone, required this.time});

  String toStorageString() => '$title|$isDone|$time';

  static TodoItem fromString(String str) {
    final parts = str.split('|');
    return TodoItem(
      title: parts[0],
      isDone: parts.length > 1 && parts[1] == 'true',
      time: parts.length > 2 ? parts[2] : '',
    );
  }

  static TodoItem fromMap(Map<String, dynamic> map) {
    return TodoItem(
      title: map['title'] as String,
      isDone: map['isDone'] as bool,
      time: map['time'] as String,
    );
  }
}
