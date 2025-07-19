import 'package:flutter/material.dart';
import 'package:bysnapp/pages/home/AssignmentBoard.dart';
import 'package:bysnapp/pages/roast/roast_timer_page.dart';
import 'package:bysnapp/pages/todo/todo_page.dart';
import 'package:bysnapp/pages/drip/drip_counter_page.dart';
import 'package:bysnapp/pages/schedule/schedule_page.dart';
import 'package:bysnapp/pages/dashboard/dashboard_page.dart';
import 'models/gamification_provider.dart';
import 'services/experience_manager.dart';
import 'pages/gamification/badge_list_page.dart';
import 'services/sync_firestore_all.dart';
import 'services/auto_sync_service.dart';
import 'services/todo_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'models/theme_settings.dart';
import 'models/group_provider.dart';
import 'models/dashboard_stats_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'services/data_sync_service.dart';
import 'services/assignment_firestore_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'utils/app_performance_config.dart';
// navigatorKeyが定義されているファイルをimport

class WorkAssignmentApp extends StatefulWidget {
  const WorkAssignmentApp({super.key});

  @override
  State<WorkAssignmentApp> createState() => _WorkAssignmentAppState();
}

class _WorkAssignmentAppState extends State<WorkAssignmentApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // TODO通知サービスにナビゲーションキーを設定
    TodoNotificationService().setNavigatorKey(_navigatorKey);

    // 通知からアプリが起動された時の処理
    _handleNotificationLaunch();
  }

  /// 通知からアプリが起動された時の処理
  void _handleNotificationLaunch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 通知ペイロードをチェックして適切な画面に遷移
      // この処理は必要に応じて実装
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeSettings>(
      builder: (context, themeSettings, child) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'BYSN業務アプリ',
          theme: ThemeData(
            fontFamily: themeSettings.fontFamily,
            scaffoldBackgroundColor: themeSettings.backgroundColor,
            primaryColor: themeSettings.appBarColor,
            appBarTheme: AppBarTheme(
              backgroundColor: themeSettings.appBarColor,
              foregroundColor: themeSettings.appBarTextColor,
              iconTheme: IconThemeData(
                color: themeSettings.iconColor,
                size: 24,
              ),
              titleTextStyle: TextStyle(
                color: themeSettings.appBarTextColor,
                fontSize: (20 * themeSettings.fontSizeScale).clamp(16.0, 28.0),
                fontWeight: FontWeight.bold,
                fontFamily: themeSettings.fontFamily,
              ),
            ),
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              backgroundColor: themeSettings.bottomNavigationColor,
              selectedItemColor: themeSettings.bottomNavigationSelectedColor
                  .withOpacity(0.7),
              unselectedItemColor:
                  themeSettings.bottomNavigationColor.computeLuminance() > 0.5
                  ? Colors.black
                  : Colors.white,
              selectedLabelStyle: TextStyle(
                fontSize: (12 * themeSettings.fontSizeScale).clamp(8.0, 14.0),
                fontFamily: themeSettings.fontFamily,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: (12 * themeSettings.fontSizeScale).clamp(8.0, 14.0),
                fontFamily: themeSettings.fontFamily,
              ),
              type: BottomNavigationBarType.fixed,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: themeSettings.buttonColor,
                foregroundColor: themeSettings.fontColor2,
                textStyle: TextStyle(
                  fontSize: (18 * themeSettings.fontSizeScale).clamp(
                    14.0,
                    24.0,
                  ),
                  fontFamily: themeSettings.fontFamily,
                  fontWeight: FontWeight.bold,
                  color: themeSettings.fontColor2,
                ),
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
              ),
            ),
            textTheme: TextTheme(
              bodyMedium: TextStyle(
                color: themeSettings.fontColor1,
                fontSize: 14 * themeSettings.fontSizeScale,
                fontFamily: themeSettings.fontFamily,
              ),
              bodyLarge: TextStyle(
                color: themeSettings.fontColor1,
                fontSize: 16 * themeSettings.fontSizeScale,
                fontFamily: themeSettings.fontFamily,
              ),
              bodySmall: TextStyle(
                color: themeSettings.fontColor1,
                fontSize: 12 * themeSettings.fontSizeScale,
                fontFamily: themeSettings.fontFamily,
              ),
              titleLarge: TextStyle(
                color: themeSettings.fontColor1,
                fontSize: 22 * themeSettings.fontSizeScale,
                fontFamily: themeSettings.fontFamily,
              ),
              titleMedium: TextStyle(
                color: themeSettings.fontColor1,
                fontSize: 18 * themeSettings.fontSizeScale,
                fontFamily: themeSettings.fontFamily,
              ),
              titleSmall: TextStyle(
                color: themeSettings.fontColor1,
                fontSize: 14 * themeSettings.fontSizeScale,
                fontFamily: themeSettings.fontFamily,
              ),
            ),
            iconTheme: IconThemeData(color: themeSettings.iconColor, size: 24),
            drawerTheme: DrawerThemeData(
              backgroundColor: themeSettings.backgroundColor,
            ),
            dividerColor: Colors.black26,
          ),
          home: AuthGate(
            child: PasscodeGate(
              child: MainScaffold(
                // ログイン直後に全データ同期
                // ここではなくAuthGateで呼ぶのがベスト
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Google認証必須ガード
class AuthGate extends StatelessWidget {
  final Widget child;
  const AuthGate({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData) {
          return GoogleSignInScreen();
        }
        // ★ ログイン直後に全データ同期を実行
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          // すでに同期済みなら何もしないようにしてもOK
          await syncAllFirestoreData(context);
        });
        return child;
      },
    );
  }
}

/// Googleログイン画面
class GoogleSignInScreen extends StatefulWidget {
  const GoogleSignInScreen({super.key});
  @override
  State<GoogleSignInScreen> createState() => _GoogleSignInScreenState();
}

class _GoogleSignInScreenState extends State<GoogleSignInScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Googleアカウントの選択がキャンセルされました';
        });
        return;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      // 追加: ログイン成功後にクラウド設定をダウンロード
      try {
        await DataSyncService.downloadAllData();
        // ダウンロードした設定でThemeSettingsを更新
        final themeSettings = Provider.of<ThemeSettings>(
          context,
          listen: false,
        );
        final prefs = await SharedPreferences.getInstance();

        // フォント設定を更新
        final fontSize = prefs.getDouble('fontSize');
        final fontFamily = prefs.getString('fontFamily');
        if (fontSize != null) {
          themeSettings.updateFontSizeScale(fontSize);
        }
        if (fontFamily != null) {
          themeSettings.updateFontFamily(fontFamily);
        }

        // 担当表データを更新
        try {
          final assignmentMembers =
              await AssignmentFirestoreService.loadAssignmentMembers();
          if (assignmentMembers != null &&
              assignmentBoardKey.currentState != null) {
            assignmentBoardKey.currentState!.setAssignmentMembersFromFirestore(
              assignmentMembers,
            );
          }
        } catch (e) {
          print('担当表データの更新に失敗しました: $e');
        }

        // サウンド設定は既にSharedPreferencesに保存されているので、
        // 各画面で読み込まれる際に反映される
      } catch (e) {
        print('クラウド設定のダウンロードに失敗しました: $e');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Googleログインに失敗しました: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/google_logo.png', width: 64, height: 64),
                SizedBox(height: 24),
                Text(
                  'アプリを利用するには、Googleアカウントのログインが必要です',
                  style: TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: TextStyle(color: Colors.red)),
                  ),
                _loading
                    ? CircularProgressIndicator()
                    : ElevatedButton.icon(
                        icon: Image.asset(
                          'assets/google_logo.png',
                          width: 24,
                          height: 24,
                        ),
                        label: Text('Googleでログイン'),
                        onPressed: _signInWithGoogle,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PasscodeGate extends StatefulWidget {
  final Widget child;
  const PasscodeGate({required this.child, super.key});

  @override
  State<PasscodeGate> createState() => _PasscodeGateState();
}

class _PasscodeGateState extends State<PasscodeGate>
    with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _loading = true;
  String? _passcode;
  bool _isLockEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPasscode();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // TODO通知サービスを停止
    TodoNotificationService().stopNotificationService();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // アプリが復帰した時にパスコードロックをチェック
      _checkPasscodeOnResume();
    }
  }

  Future<void> _checkPasscodeOnResume() async {
    final prefs = await SharedPreferences.getInstance();
    final isLockEnabled = prefs.getBool('passcode_lock_enabled') ?? false;

    if (isLockEnabled && _passcode != null && _unlocked) {
      setState(() {
        _unlocked = false;
      });
    }
  }

  Future<void> _checkPasscode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('app_passcode');
    final isLockEnabled = prefs.getBool('passcode_lock_enabled') ?? false;
    setState(() {
      _passcode = code;
      _isLockEnabled = isLockEnabled;
      _loading = false;
      // パスコードが設定されていて、ロックが有効な場合のみロックをかける
      _unlocked = code == null || !isLockEnabled;
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
            color:
                Provider.of<ThemeSettings>(context).backgroundColor2 ??
                Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: Provider.of<ThemeSettings>(context).iconColor,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'パスコードを入力してください',
                    style: TextStyle(
                      fontSize: 18,
                      color: Provider.of<ThemeSettings>(context).fontColor1,
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: false,
                      signed: false,
                    ),
                    maxLength: 4,
                    obscureText: true,
                    style: TextStyle(
                      fontSize: 18,
                      color: Provider.of<ThemeSettings>(context).fontColor1,
                    ),
                    decoration: InputDecoration(
                      labelText: 'パスコード',
                      labelStyle: TextStyle(
                        color: Provider.of<ThemeSettings>(context).fontColor1,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorText: _error,
                      filled: true,
                      fillColor: Provider.of<ThemeSettings>(
                        context,
                      ).inputBackgroundColor,
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: Provider.of<ThemeSettings>(context).iconColor,
                      ),
                    ),
                    onSubmitted: (_) => _check(),
                    enabled: !_checking,
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _checking ? null : _check,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _checking
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              '解除',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
  int _selectedIndex = 2; // デフォルトでホーム画面を表示
  final PageController _pageController = PageController(initialPage: 2);

  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;

  // バナー広告用
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  static const double _bannerHeight = 50.0;

  // ページを遅延読み込みするためのリスト
  final List<Widget> _pages = [
    RoastTimerPage(), // 予熱タイマー
    SchedulePage(), // スケジュール
    DashboardPage(), // ダッシュボード（中央）
    DripCounterPage(key: dripCounterPageKey), // ドリップ
    AssignmentBoard(key: assignmentBoardKey), // 担当表
  ];

  @override
  void initState() {
    super.initState();
    // 自動同期サービスを初期化
    _initializeAutoSync();
    _loadInterstitialAd();
    _loadBannerAd();
  }

  void _loadInterstitialAd() async {
    if (await isDonorUser()) return; // 寄付者は広告を表示しない
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712', // テスト用ID
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() {
            _interstitialAd = ad;
            _isAdLoaded = true;
          });
          // ロード完了後すぐ表示
          _showInterstitialAd();
        },
        onAdFailedToLoad: (error) {
          _isAdLoaded = false;
        },
      ),
    );
  }

  void _showInterstitialAd() {
    if (_isAdLoaded && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
        },
      );
      _interstitialAd!.show();
      setState(() {
        _isAdLoaded = false;
      });
    }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // テスト用バナーID
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          setState(() {
            _isBannerAdLoaded = false;
          });
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _interstitialAd?.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _initializeAutoSync() async {
    // 少し遅延を入れてから初期化（アプリの起動が完了してから）
    await Future.delayed(Duration(seconds: 2));
    await AutoSyncService.initialize();

    // ExperienceManagerを初期化
    try {
      await ExperienceManager.instance.initialize();
    } catch (e) {
      print('ExperienceManager初期化エラー: $e');
    }

    // GroupProviderを初期化してグループデータの監視を開始
    if (mounted) {
      final groupProvider = context.read<GroupProvider>();
      await groupProvider.loadUserGroups();
      if (groupProvider.hasGroup && mounted) {
        groupProvider.startWatchingGroupData();
      }
    }

    // GamificationProviderを初期化
    if (mounted) {
      final gamificationProvider = context.read<GamificationProvider>();
      await gamificationProvider.initialize();
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
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
      appBar: AppBar(
        title: Row(
          children: [
            SizedBox(width: 8),
            Text(
              'ローストプラス+',
              style: TextStyle(
                color: Provider.of<ThemeSettings>(context).appBarTextColor,
              ),
            ),
          ],
        ),
      ),

      body: Stack(
        children: [
          FutureBuilder<bool>(
            future: isDonorUser(),
            builder: (context, snapshot) {
              final isDonor = snapshot.data == true;
              final bottomPadding = isDonor
                  ? 0.0
                  : (_isBannerAdLoaded ? _bannerHeight : 0.0);
              return Padding(
                padding: EdgeInsets.only(bottom: bottomPadding),
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  children: _pages,
                ),
              );
            },
          ),
          FutureBuilder<bool>(
            future: isDonorUser(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return SizedBox.shrink();
              }
              if (snapshot.data == true) return SizedBox.shrink();
              if (_isBannerAdLoaded && _bannerAd != null) {
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
                );
              }
              return SizedBox.shrink();
            },
          ),
        ],
      ),
      bottomNavigationBar: Consumer<ThemeSettings>(
        builder: (context, themeSettings, child) {
          final fontSize = (12 * themeSettings.fontSizeScale).clamp(8.0, 14.0);
          final barHeight = (56 + (themeSettings.fontSizeScale - 1.0) * 20)
              .clamp(56.0, 80.0);

          return SizedBox(
            height: barHeight,
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              backgroundColor: themeSettings.bottomNavigationColor,
              selectedItemColor: themeSettings.bottomNavigationSelectedColor,
              unselectedItemColor: Colors.white,
              selectedLabelStyle: TextStyle(
                fontSize: fontSize,
                fontFamily: themeSettings.fontFamily,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: fontSize,
                fontFamily: themeSettings.fontFamily,
              ),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.local_fire_department),
                  label: '焙煎タイマー',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.schedule),
                  label: 'スケジュール',
                ),
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ホーム'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.local_cafe),
                  label: 'カウンター',
                ),
                BottomNavigationBarItem(icon: Icon(Icons.group), label: '担当表'),
              ],
            ),
          );
        },
      ),
    );
  }
}
