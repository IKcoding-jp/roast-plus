import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../utils/performance_utils.dart';

import '../../services/schedule_firestore_service.dart';
import '../../services/todo_notification_service.dart';
import '../../services/user_settings_firestore_service.dart';

class TodoListPage extends StatefulWidget {
  const TodoListPage({super.key});

  @override
  State<TodoListPage> createState() => TodoListPageState();
}

class TodoListPageState extends State<TodoListPage>
    with SingleTickerProviderStateMixin {
  List<TodoItem> _todos = [];
  late SharedPreferences prefs;
  final TextEditingController _controller = TextEditingController();
  TimeOfDay? _selectedTime;
  bool _canEditTodoList = true;

  final String _storageKey = 'todoList';

  StreamSubscription? _todoListSubscription;
  void _startTodoListListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final today = DateTime.now();
    final docId =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    _todoListSubscription?.cancel();
    _todoListSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('todoList')
        .doc(docId)
        .snapshots()
        .listen((doc) {
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            if (data['todos'] != null) {
              setState(() {
                _todos = List<Map<String, dynamic>>.from(data['todos'])
                    .map(
                      (e) => TodoItem(
                        title: e['title'] as String,
                        isDone: e['isDone'] as bool,
                        time: e['time'] as String,
                      ),
                    )
                    .toList();
              });
              _sortTodos();
            }
          }
        });
  }

  @override
  void initState() {
    super.initState();
    _loadTodos();
    _setupGroupDataListener();
    _checkEditPermissions();
    _loadTodosFromFirestore();
    _startTodoListListener();

    // GroupProviderのグループ読み込みを確認
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupProvider = context.read<GroupProvider>();
      if (!groupProvider.hasGroup && !groupProvider.loading) {
        developer.log('TodoListPage: グループが読み込まれていないため、読み込みを開始します');
        groupProvider.loadUserGroups();
      } else if (groupProvider.hasGroup) {
        developer.log('TodoListPage: グループが既に読み込まれています - グループデータ監視を開始');
        _startGroupDataWatching(groupProvider);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _todoListSubscription?.cancel();
    super.dispose();
  }

  // グループデータの変更を監視
  void _setupGroupDataListener() {
    developer.log('TodoListPage: グループデータリスナーを設定開始');

    // GroupProviderの変更を監視
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupProvider = context.read<GroupProvider>();

      // 初回のグループデータ監視開始
      _startGroupDataWatching(groupProvider);

      // GroupProviderの変更を監視
      groupProvider.addListener(() {
        developer.log('TodoListPage: GroupProviderの変更を検知');
        developer.log('TodoListPage: グループ数: ${groupProvider.groups.length}');

        // グループが追加された場合、監視を開始
        _startGroupDataWatching(groupProvider);

        // グループ設定の変更を検知するため、常に権限チェックを実行
        _checkEditPermissions();

        if (groupProvider.isWatchingGroupData) {
          // グループデータが更新されたら、ローカルデータを再読み込み
          _loadTodosFromFirestore();
        }
      });
    });

    developer.log('TodoListPage: グループデータリスナー設定完了');
  }

  // グループデータの監視を開始
  void _startGroupDataWatching(GroupProvider groupProvider) {
    if (groupProvider.hasGroup && !groupProvider.isWatchingGroupData) {
      developer.log('TodoListPage: グループデータ監視を開始します');
      groupProvider.startWatchingGroupData();
    }
  }

  // 編集権限をチェック
  Future<void> _checkEditPermissions() async {
    try {
      developer.log('TodoListPage: 編集権限チェック開始');
      final groupProvider = context.read<GroupProvider>();
      developer.log('TodoListPage: グループあり: ${groupProvider.hasGroup}');

      if (groupProvider.hasGroup) {
        final group = groupProvider.currentGroup!;
        final currentUser = FirebaseAuth.instance.currentUser;
        developer.log('TodoListPage: 現在のユーザー: ${currentUser?.uid}');

        if (currentUser != null) {
          final userRole = group.getMemberRole(currentUser.uid);
          developer.log('TodoListPage: ユーザーロール: $userRole');
          final groupSettings = groupProvider.getCurrentGroupSettings();
          developer.log('TodoListPage: グループ設定: $groupSettings');

          if (groupSettings != null) {
            // タスクリストの編集権限をチェック
            final canEditTodoList = groupSettings.canEditDataType(
              'todo_list',
              userRole ?? GroupRole.member,
            );

            developer.log('TodoListPage: 権限チェック結果:');
            developer.log('TodoListPage: - todo_list: $canEditTodoList');

            // 現在の権限と比較して変更があったかチェック
            final hasChanged = _canEditTodoList != canEditTodoList;

            if (hasChanged) {
              developer.log('TodoListPage: 権限に変更を検知しました！');
              developer.log('TodoListPage: 変更前 - todo_list: $_canEditTodoList');
              developer.log('TodoListPage: 変更後 - todo_list: $canEditTodoList');
            }

            setState(() {
              _canEditTodoList = canEditTodoList;
            });

            developer.log('TodoListPage: 編集権限チェック完了');
            developer.log('TodoListPage: TODOリスト編集可能: $_canEditTodoList');
          } else {
            developer.log('TodoListPage: グループ設定がnullです');
          }
        } else {
          developer.log('TodoListPage: 現在のユーザーがnullです');
        }
      } else {
        developer.log('TodoListPage: グループがありません');
      }
    } catch (e) {
      developer.log('TodoListPage: 編集権限チェックエラー: $e');
      developer.log('TodoListPage: エラーの詳細: ${e.toString()}');
    }
  }

  // Firestoreからタスクリストを読み込み
  Future<void> _loadTodosFromFirestore() async {
    developer.log('TodoListPage: FirestoreからTODOリストを読み込み開始');
    try {
      final today = DateTime.now();
      final docId =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('todoList')
          .doc(docId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final todos = data['todos'] as List<dynamic>?;
        if (todos != null) {
          developer.log('TodoListPage: Firestoreから読み込んだTODOリスト: $todos');
          if (mounted) {
            setState(() {
              _todos = todos
                  .map(
                    (todo) => TodoItem(
                      title: todo['title'] as String,
                      isDone: todo['isDone'] as bool,
                      time: todo['time'] as String,
                    ),
                  )
                  .toList();
            });
            _sortTodos();
            developer.log('TodoListPage: TODOリストを更新しました');
            // ここでローカルにも保存する
            final saved = _todos.map((e) => e.toStorageString()).toList();
            await UserSettingsFirestoreService.saveSetting(_storageKey, saved);
          }
        }
      }
    } catch (e) {
      developer.log('TodoListPage: FirestoreからのTODOリスト読み込みエラー: $e');
    }
  }

  Future<void> _loadTodos() async {
    try {
      final saved =
          await UserSettingsFirestoreService.getSetting(_storageKey) ?? [];
      // _sortByTime は常に true（設定読み込み不要）
      List<TodoItem> loaded = saved.map(TodoItem.fromString).toList();
      loaded.sort(_compareTodoByTime);
      setState(() {
        _todos = loaded;
      });
    } catch (e) {
      developer.log('TODO読み込みエラー: $e');
      setState(() {
        _todos = [];
      });
    }
  }

  // 追加: 時間順比較関数
  int _compareTodoByTime(TodoItem a, TodoItem b) {
    final aHas = a.time.isNotEmpty;
    final bHas = b.time.isNotEmpty;
    if (aHas && bHas) {
      final aMinutes = _parseTimeToMinutes(a.time);
      final bMinutes = _parseTimeToMinutes(b.time);
      return aMinutes.compareTo(bMinutes);
    } else if (aHas && !bHas) {
      return -1;
    } else if (!aHas && bHas) {
      return 1;
    }
    return 0;
  }

  // 時間文字列を分に変換するヘルパー関数
  int _parseTimeToMinutes(String time) {
    if (time.contains('AM') || time.contains('PM')) {
      // 12時間形式の場合
      final timeParts = time.split(' ');
      if (timeParts.length == 2) {
        final timeStr = timeParts[0];
        final period = timeParts[1];
        final timeComponents = timeStr.split(':');
        if (timeComponents.length == 2) {
          int hour = int.tryParse(timeComponents[0]) ?? 0;
          int minute = int.tryParse(timeComponents[1]) ?? 0;

          // AM/PMを24時間形式に変換
          if (period == 'PM' && hour != 12) {
            hour += 12;
          } else if (period == 'AM' && hour == 12) {
            hour = 0;
          }

          return hour * 60 + minute;
        }
      }
    } else {
      // 24時間形式の場合
      final parts = time.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        return hour * 60 + minute;
      }
    }
    return 0; // 無効な形式の場合は0を返す
  }

  // 追加: ソート実行
  void _sortTodos() {
    _todos.sort(_compareTodoByTime);
  }

  Future<void> _saveTodos() async {
    try {
      final saved = _todos.map((e) => e.toStorageString()).toList();
      await UserSettingsFirestoreService.saveSetting(_storageKey, saved);
      // Firestoreにも自動保存
      try {
        await ScheduleFirestoreService.saveTodayTodoList(
          todos: _todos
              .map(
                (e) => {'title': e.title, 'isDone': e.isDone, 'time': e.time},
              )
              .toList(),
        );
        // グループ同期は行わない
      } catch (e) {
        developer.log('TodoListPage: TODOリスト保存エラー: $e');
      }
      // ソート設定は固定のため保存不要
    } catch (e) {
      developer.log('TODO保存エラー: $e');
    }
  }

  void _addTodo() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final time = _selectedTime != null
        ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
        : '';
    setState(() {
      _todos.add(TodoItem(title: text, isDone: false, time: time));
      _sortTodos();
      _controller.clear();
      _selectedTime = null;
    });
    _saveTodos();
  }

  void _toggleDone(int index) {
    final todo = _todos[index];
    setState(() {
      todo.isDone = !todo.isDone;
    });

    // タスクが完了した場合、通知履歴をクリア
    if (todo.isDone && todo.time.isNotEmpty) {
      TodoNotificationService().clearTodoNotification(todo.title, todo.time);
    }

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
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
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
      // 12時間形式（例: "12 AM"）または24時間形式（例: "12:00"）を処理
      if (item.time.contains('AM') || item.time.contains('PM')) {
        // 12時間形式の場合
        final timeParts = item.time.split(' ');
        if (timeParts.length == 2) {
          final timeStr = timeParts[0];
          final period = timeParts[1];
          final timeComponents = timeStr.split(':');
          if (timeComponents.length == 2) {
            int hour = int.tryParse(timeComponents[0]) ?? 0;
            int minute = int.tryParse(timeComponents[1]) ?? 0;

            // AM/PMを24時間形式に変換
            if (period == 'PM' && hour != 12) {
              hour += 12;
            } else if (period == 'AM' && hour == 12) {
              hour = 0;
            }

            editedTime = TimeOfDay(hour: hour, minute: minute);
          }
        }
      } else {
        // 24時間形式の場合
        final parts = item.time.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]) ?? 0;
          final minute = int.tryParse(parts[1]) ?? 0;
          editedTime = TimeOfDay(hour: hour, minute: minute);
        }
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
                        ? '時刻: ${editedTime!.hour.toString().padLeft(2, '0')}:${editedTime!.minute.toString().padLeft(2, '0')}'
                        : '時刻: --:--',
                  ),
                ),
                TextButton(
                  child: Text('変更'),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: editedTime ?? TimeOfDay.now(),
                      builder: (context, child) {
                        return MediaQuery(
                          data: MediaQuery.of(
                            context,
                          ).copyWith(alwaysUse24HourFormat: true),
                          child: child!,
                        );
                      },
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
                // 修正: 時刻を変更しなかった場合は元の時刻を保持
                _todos[index].time = editedTime != null
                    ? '${editedTime!.hour.toString().padLeft(2, '0')}:${editedTime!.minute.toString().padLeft(2, '0')}'
                    : _todos[index].time;
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

  @override
  Widget build(BuildContext context) {
    return Consumer<GroupProvider>(
      builder: (context, groupProvider, child) {
        // グループデータの監視状態を確認
        if (groupProvider.hasGroup && !groupProvider.isWatchingGroupData) {
          // グループデータの監視を開始
          WidgetsBinding.instance.addPostFrameCallback((_) {
            groupProvider.startWatchingGroupData();
          });
        }

        // 権限チェックを実行
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkEditPermissions();
        });

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Icon(
                  Icons.edit_note,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                ),
                SizedBox(width: 8),
                Text('メモ・TODO'),
              ],
            ),
            backgroundColor: Provider.of<ThemeSettings>(context).appBarColor,
            iconTheme: IconThemeData(
              color: Provider.of<ThemeSettings>(context).iconColor,
            ),
            actions: [
              // グループアイコンをAppBarに追加
              Consumer<GroupProvider>(
                builder: (context, groupProvider, child) {
                  if (groupProvider.groups.isNotEmpty) {
                    return Container(
                      margin: EdgeInsets.only(right: 8),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade400),
                      ),
                      child: Icon(
                        Icons.groups,
                        size: 18,
                        color: Colors.blue.shade700,
                      ),
                    );
                  }
                  return SizedBox.shrink();
                },
              ),
              // すべて削除ボタン
              IconButton(
                icon: Icon(Icons.delete_sweep),
                tooltip: 'すべて削除',
                onPressed: _clearTodos,
              ),
            ],
          ),
          body: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // 入力部分
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Provider.of<ThemeSettings>(
                    context,
                  ).cardBackgroundColor,
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.add_task,
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).iconColor,
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '新しいタスクを追加',
                              style: TextStyle(
                                fontSize:
                                    18 *
                                    Provider.of<ThemeSettings>(
                                      context,
                                    ).fontSizeScale,
                                fontWeight: FontWeight.bold,
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).fontColor1,
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
                                  color: Provider.of<ThemeSettings>(
                                    context,
                                  ).inputBackgroundColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: TextField(
                                  controller: _controller,
                                  enabled: _canEditTodoList,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    hintText: _canEditTodoList
                                        ? 'やることを入力'
                                        : 'リーダーのみが編集できます',
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
                                onPressed: _canEditTodoList ? _addTodo : null,
                                tooltip: _canEditTodoList
                                    ? '追加'
                                    : 'リーダーのみが編集できます',
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
                                  color: Provider.of<ThemeSettings>(
                                    context,
                                  ).iconColor,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '選択した時刻: ${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize:
                                        16 *
                                        Provider.of<ThemeSettings>(
                                          context,
                                        ).fontSizeScale,
                                    color: Provider.of<ThemeSettings>(
                                      context,
                                    ).fontColor1,
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
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).cardBackgroundColor,
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.checklist,
                                      size: 64,
                                      color: Provider.of<ThemeSettings>(
                                        context,
                                      ).iconColor,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'タスクがありません',
                                      style: TextStyle(
                                        fontSize:
                                            18 *
                                            Provider.of<ThemeSettings>(
                                              context,
                                            ).fontSizeScale,
                                        fontWeight: FontWeight.bold,
                                        color: Provider.of<ThemeSettings>(
                                          context,
                                        ).fontColor1,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '新しいタスクを追加してください',
                                      style: TextStyle(
                                        color: Provider.of<ThemeSettings>(
                                          context,
                                        ).fontColor1.withValues(alpha: 0.7),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : PerformanceUtils.optimizedListViewBuilder(
                          itemCount: _todos.length,
                          itemExtent: 80.0, // 固定高さを設定してパフォーマンスを向上
                          itemBuilder: (_, i) {
                            final item = _todos[i];
                            return PerformanceUtils.optimizedCard(
                              color:
                                  PerformanceUtils.optimizedProviderOf<
                                        ThemeSettings
                                      >(context)
                                      .cardBackgroundColor,
                              margin: EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                contentPadding: EdgeInsets.all(16),
                                leading: GestureDetector(
                                  onTap: _canEditTodoList
                                      ? () => _toggleDone(i)
                                      : null,
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: item.isDone
                                          ? PerformanceUtils.optimizedProviderOf<
                                                  ThemeSettings
                                                >(context)
                                                .iconColor
                                                .withValues(alpha: 0.2)
                                          : const Color(
                                              0xFF795548,
                                            ).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      item.isDone
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      color: item.isDone
                                          ? PerformanceUtils.optimizedProviderOf<
                                                  ThemeSettings
                                                >(context)
                                                .iconColor
                                          : PerformanceUtils.optimizedProviderOf<
                                                  ThemeSettings
                                                >(context)
                                                .iconColor,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize:
                                        16 *
                                        PerformanceUtils.optimizedProviderOf<
                                              ThemeSettings
                                            >(context)
                                            .fontSizeScale,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        PerformanceUtils.optimizedProviderOf<
                                              ThemeSettings
                                            >(context)
                                            .fontColor1,
                                    decoration: item.isDone
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                                subtitle: item.time.isNotEmpty
                                    ? Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              size: 16,
                                              color:
                                                  PerformanceUtils.optimizedProviderOf<
                                                        ThemeSettings
                                                      >(context)
                                                      .iconColor,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              '予定時刻: ${item.time}',
                                              style: TextStyle(
                                                fontSize:
                                                    15 *
                                                    PerformanceUtils.optimizedProviderOf<
                                                          ThemeSettings
                                                        >(context)
                                                        .fontSizeScale,
                                                color:
                                                    PerformanceUtils.optimizedProviderOf<
                                                          ThemeSettings
                                                        >(context)
                                                        .fontColor1
                                                        .withValues(alpha: 0.7),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : null,
                                trailing: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFE57373,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                      color: Color(0xFFE57373),
                                      size: 20,
                                    ),
                                    onPressed: _canEditTodoList
                                        ? () => _deleteTodo(i)
                                        : null,
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
        );
      },
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
