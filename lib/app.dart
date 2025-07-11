import 'package:flutter/material.dart';
import 'package:bysnapp/pages/home/AssignmentBoard.dart';
import 'package:bysnapp/pages/roast/roast_record_list_page.dart';
import 'package:bysnapp/pages/roast/roast_timer_page.dart';
import 'package:bysnapp/pages/todo/todo_list_page.dart';
import 'package:bysnapp/pages/drip/drip_counter_page.dart';
import 'package:bysnapp/settings/app_settings_page.dart';
import 'package:bysnapp/pages/roast/roast_record_page.dart';
import 'package:bysnapp/pages/roast/roast_advisor_page.dart';
import 'services/sync_firestore_all.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'models/theme_settings.dart';

class WorkAssignmentApp extends StatelessWidget {
  const WorkAssignmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);
    return MaterialApp(
      title: 'BYSN業務アプリ',
      theme: ThemeData(
        fontFamily: 'HannariMincho',
        scaffoldBackgroundColor: themeSettings.backgroundColor,
        primaryColor: themeSettings.appBarColor,
        appBarTheme: AppBarTheme(
          backgroundColor: themeSettings.appBarColor,
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: themeSettings.appBarColor,
          selectedItemColor: Color(0xFFFF8225),
          unselectedItemColor: Colors.white70,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: themeSettings.buttonColor,
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
        textTheme: TextTheme(bodyMedium: TextStyle(color: Color(0xFF2C1D17))),
        drawerTheme: DrawerThemeData(
          backgroundColor: themeSettings.backgroundColor,
        ),
        dividerColor: Colors.black26,
      ),
      home: PasscodeGate(child: MainScaffold()),
    );
  }
}

class PasscodeGate extends StatefulWidget {
  final Widget child;
  const PasscodeGate({required this.child, super.key});

  @override
  State<PasscodeGate> createState() => _PasscodeGateState();
}

class _PasscodeGateState extends State<PasscodeGate> {
  bool _unlocked = false;
  bool _loading = true;
  String? _passcode;

  @override
  void initState() {
    super.initState();
    _checkPasscode();
  }

  Future<void> _checkPasscode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('app_passcode');
    setState(() {
      _passcode = code;
      _loading = false;
      _unlocked = code == null; // パスコード未設定ならロック解除
    });
  }

  void _onUnlock() {
    setState(() {
      _unlocked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_unlocked && _passcode != null) {
      return PasscodeInputScreen(
        onUnlock: _onUnlock,
        correctPasscode: _passcode!,
      );
    }
    return widget.child;
  }
}

class PasscodeInputScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  final String correctPasscode;
  const PasscodeInputScreen({
    required this.onUnlock,
    required this.correctPasscode,
    super.key,
  });

  @override
  State<PasscodeInputScreen> createState() => _PasscodeInputScreenState();
}

class _PasscodeInputScreenState extends State<PasscodeInputScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _error;
  bool _checking = false;

  void _check() {
    final input = _controller.text.trim();
    if (input.length != 4 || int.tryParse(input) == null) {
      setState(() {
        _error = '4桁の数字で入力してください';
      });
      return;
    }
    setState(() {
      _checking = true;
    });
    Future.delayed(Duration(milliseconds: 300), () {
      if (input == widget.correctPasscode) {
        widget.onUnlock();
      } else {
        setState(() {
          _error = 'パスコードが違います';
          _checking = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor ?? Colors.white,
        child: Center(
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 64, color: Color(0xFF795548)),
                  SizedBox(height: 24),
                  Text('パスコードを入力してください', style: TextStyle(fontSize: 18)),
                  SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'パスコード',
                      border: OutlineInputBorder(),
                      errorText: _error,
                    ),
                    onSubmitted: (_) => _check(),
                    enabled: !_checking,
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _checking ? null : _check,
                      child: _checking
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text('解除'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
    TodoListPage(key: todoListPageKey), // ToDo
    DripCounterPage(key: dripCounterPageKey), // ドリップ
    AssignmentBoard(key: assignmentBoardKey), // 担当表
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
              decoration: BoxDecoration(
                color: Provider.of<ThemeSettings>(context).appBarColor,
              ),
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
              leading: Icon(Icons.analytics), // 分析＝グラフ
              title: Text('焙煎分析'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RoastAdvisorPage()),
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
