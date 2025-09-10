import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../services/todo_notification_service.dart';
import '../../utils/web_ui_utils.dart';
import 'todo_list_tab.dart';
import 'memo_tab.dart';
import 'memo_list_page.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => TodoPageState();
}

class TodoPageState extends State<TodoPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<TodoListTabState> _todoListTabKey =
      GlobalKey<TodoListTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _tabController.addListener(() {
      // タブが切り替わった時にUIを更新
      setState(() {});
    });

    TodoNotificationService().startNotificationService();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Firestore同期用setter
  void setTodosFromFirestore(List<Map<String, dynamic>> todos) {
    if (_todoListTabKey.currentState != null) {
      _todoListTabKey.currentState!.setTodosFromFirestore(todos);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    // デバッグ用：現在のtodoColorの値をログ出力
    // テーマ設定を適用

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.check_circle_outline, color: themeSettings.todoColor),
            SizedBox(width: 8),
            Text(
              'メモ・TODO',
              style: TextStyle(
                color: themeSettings.appBarTextColor,
                fontSize: 20 * themeSettings.fontSizeScale,
                fontWeight: FontWeight.bold,
                fontFamily: themeSettings.fontFamily,
              ),
            ),
          ],
        ),
        backgroundColor: themeSettings.appBarColor,
        iconTheme: IconThemeData(color: themeSettings.todoColor),
        actions: [
          // メモタブが選択されている時のみメモ一覧アイコンを表示（モバイル版のみ）
          if (!WebUIUtils.isWeb && _tabController.index == 0)
            IconButton(
              icon: Icon(Icons.list),
              tooltip: '保存されたメモ一覧',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MemoListPage()),
                );
              },
            ),
        ],
        bottom: WebUIUtils.isWeb
            ? null
            : PreferredSize(
                preferredSize: Size.fromHeight(kToolbarHeight),
                child: Container(
                  decoration: BoxDecoration(
                    color: themeSettings.cardBackgroundColor,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: false,
                    labelPadding: EdgeInsets.symmetric(horizontal: 12),
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    indicatorPadding: EdgeInsets.symmetric(horizontal: 6),
                    tabs: [
                      Tab(
                        child: Text(
                          'メモ',
                          style: TextStyle(
                            fontSize: 16 * themeSettings.fontSizeScale,
                            fontWeight: FontWeight.w600,
                            fontFamily: themeSettings.fontFamily,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Tab(
                        child: Text(
                          'TODOリスト',
                          style: TextStyle(
                            fontSize: 16 * themeSettings.fontSizeScale,
                            fontWeight: FontWeight.w600,
                            fontFamily: themeSettings.fontFamily,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    labelColor: themeSettings.fontColor1,
                    unselectedLabelColor: themeSettings.fontColor1.withValues(
                      alpha: 0.7,
                    ),
                    indicatorColor: themeSettings.todoColor,
                    indicatorWeight: 3,
                  ),
                ),
              ),
      ),
      body: WebUIUtils.isWeb
          ? _buildWebLayout(themeSettings)
          : TabBarView(
              controller: _tabController,
              children: [
                MemoTab(),
                TodoListTab(key: _todoListTabKey),
              ],
            ),
    );
  }

  Widget _buildWebLayout(ThemeSettings themeSettings) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // メモセクション（左側）
              Expanded(
                child: Card(
                  elevation: 8,
                  color: themeSettings.cardBackgroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // メモセクションヘッダー
                        Row(
                          children: [
                            Icon(
                              Icons.note,
                              color: themeSettings.todoColor,
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'メモ',
                              style: TextStyle(
                                fontSize: 20 * themeSettings.fontSizeScale,
                                fontWeight: FontWeight.bold,
                                color: themeSettings.fontColor1,
                                fontFamily: themeSettings.fontFamily,
                              ),
                            ),
                            Spacer(),
                            IconButton(
                              icon: Icon(Icons.list),
                              tooltip: '保存されたメモ一覧',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MemoListPage(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        // メモタブの内容
                        Expanded(child: MemoTab()),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 24),

              Expanded(
                child: Card(
                  elevation: 8,
                  color: themeSettings.cardBackgroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: themeSettings.todoColor,
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'TODOリスト',
                              style: TextStyle(
                                fontSize: 20 * themeSettings.fontSizeScale,
                                fontWeight: FontWeight.bold,
                                color: themeSettings.fontColor1,
                                fontFamily: themeSettings.fontFamily,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Expanded(child: TodoListTab(key: _todoListTabKey)),
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
