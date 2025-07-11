import 'package:flutter/material.dart';
import 'package:bysnapp/pages/drip/DripPackRecordListPage.dart';
import 'package:bysnapp/pages/home/AssignmentBoard.dart';
import 'package:bysnapp/pages/roast/roast_record_list_page.dart';
import 'package:bysnapp/pages/roast/roast_timer_page.dart';
import 'package:bysnapp/pages/todo/todo_list_page.dart';
import 'package:bysnapp/pages/drip/drip_counter_page.dart';
import 'package:bysnapp/settings/app_settings_page.dart';
import 'package:bysnapp/pages/roast/roast_record_page.dart';
import 'package:bysnapp/pages/roast/roast_analysis_page.dart';

class WorkAssignmentApp extends StatelessWidget {
  const WorkAssignmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BYSN業務アプリ',
      theme: ThemeData(
        fontFamily: 'HannariMincho',
        scaffoldBackgroundColor: Color(0xFFFFF8E1),
        primaryColor: Color(0xFF2C1D17),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF2C1D17),
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF2C1D17),
          selectedItemColor: Color(0xFFFF8225), // オレンジ色（#FF8225）
          unselectedItemColor: Colors.white70,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF795548), // カフェラテブラウン
            foregroundColor: Colors.white,
            textStyle: TextStyle(
              fontSize: 18,
              fontFamily: 'HannariMincho',
              fontWeight: FontWeight.bold,
            ),
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
          ),
        ),
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF2C1D17)), // 文字色＝濃ブラウン
        ),
        drawerTheme: DrawerThemeData(backgroundColor: Color(0xFFFFF8E1)),
        dividerColor: Colors.black26,
      ),
      home: MainScaffold(), // あなたのホーム画面に合わせてね
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    RoastTimerPage(), // 焙煎タイマー
    TodoListPage(), // ToDo
    DripCounterPage(), // ドリップ
    AssignmentBoard(), // 担当表
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onDrawerItemSelected(int index) {
    Navigator.pop(context);
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Row(children: [SizedBox(width: 8), Text('焙煎ログ+')])),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero, // ← これで余白防止
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF2C1D17)),
              child: Text(
                'メニュー',
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),

            ListTile(
              leading: Icon(Icons.edit), // 入力＝鉛筆
              title: Text('焙煎記録を入力する'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RoastRecordPage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.list), // 一覧＝リスト
              title: Text('焙煎記録の一覧を見る'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RoastRecordListPage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.bar_chart), // 分析＝グラフ
              title: Text('焙煎分析'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RoastAnalysisPage()),
                );
              },
            ),

            const Divider(),

            ListTile(
              title: Text('設定'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AppSettingsPage()),
                );
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.local_fire_department),
            label: '焙煎タイマー',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            label: 'スケジュール',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.local_cafe), label: 'カウンター'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: '担当表'),
        ],
      ),
    );
  }
}
