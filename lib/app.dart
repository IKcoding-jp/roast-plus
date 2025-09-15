import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'pages/business/assignment_board_page.dart' show AssignmentBoard;
import 'package:roastplus/pages/roast/roast_timer_page.dart';
import 'package:roastplus/pages/todo/todo_page.dart';
import 'package:roastplus/pages/drip/drip_counter_page.dart';
import 'package:roastplus/pages/schedule/schedule_page.dart';
import 'pages/home/home_page.dart';
import 'pages/gamification/badge_list_page.dart';
import 'services/sync_firestore_all.dart';
import 'services/todo_notification_service.dart';
import 'services/secure_auth_service.dart';
import 'services/session_management_service.dart';
import 'package:provider/provider.dart';
import 'models/theme_settings.dart';
import 'models/group_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/data_sync_service.dart';
import 'services/assignment_firestore_service.dart';
import 'services/user_settings_firestore_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pages/group/group_required_page.dart';
import 'pages/tasting/tasting_record_page.dart';
import 'pages/calendar/calendar_page.dart';
import 'pages/roast/roast_record_list_page.dart';
import 'pages/roast/roast_record_page.dart';
import 'pages/roast/roast_analysis_page.dart';
import 'pages/calculator/calculator_page.dart';
import 'pages/work_progress/work_progress_page.dart';
import 'pages/group/group_list_page.dart';
import 'pages/group/group_info_page.dart';
import 'pages/help/usage_guide_page.dart';
import 'pages/settings/app_settings_page.dart';
import 'pages/group/group_qr_generate_page.dart';
import 'pages/group/group_qr_scanner_page.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:developer' as developer;
import 'utils/app_performance_config.dart';
import 'utils/web_ui_utils.dart';
import 'utils/web_compatibility.dart';
import 'widgets/lottie_animation_widget.dart';
import 'utils/font_optimizer.dart';
import 'pages/auth/display_name_setup_page.dart';
// navigatorKeyが定義されているファイルをimport

class WorkAssignmentApp extends StatefulWidget {
  const WorkAssignmentApp({super.key});

  @override
  State<WorkAssignmentApp> createState() => _WorkAssignmentAppState();
}

// Web互換性の初期化
void _initializeWebCompatibility() {
  if (WebCompatibility.isWeb) {
    developer.log('Web版互換性モードでアプリ初期化', name: 'WorkAssignmentApp');
  }
}

class _WorkAssignmentAppState extends State<WorkAssignmentApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Web版では通知サービスを初期化しない
    if (!kIsWeb) {
      TodoNotificationService().setNavigatorKey(_navigatorKey);
    }

    // 通知からアプリが起動された時の処理
    _handleNotificationLaunch();
  }

  // フォントファミリーを動的に設定する関数（最適化版）
  String _getFontFamilyWithFallback(String fontFamily) {
    return FontOptimizer.getFontFamilyWithFallback(fontFamily);
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
    // Web互換性の初期化
    _initializeWebCompatibility();

    return Consumer<ThemeSettings>(
      builder: (context, themeSettings, child) {
        return MaterialApp(
          // キーボードイベントのエラーを防ぐための設定
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                // キーボードイベントの処理を改善
                viewInsets: MediaQuery.of(context).viewInsets,
              ),
              child: GestureDetector(
                // キーボードイベントのエラーを防ぐため、タップでキーボードを閉じる
                onTap: () {
                  FocusScope.of(context).unfocus();
                  // Web版ではユーザーアクティビティ記録をスキップ
                  if (!kIsWeb) {
                    SessionManagementService.recordUserActivity();
                  }
                },
                child: child!,
              ),
            );
          },
          navigatorKey: _navigatorKey,
          title: 'ローストプラス',
          theme: ThemeData(
            fontFamily: _getFontFamilyWithFallback(themeSettings.fontFamily),
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
                fontFamily: _getFontFamilyWithFallback(
                  themeSettings.fontFamily,
                ),
              ),
            ),
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              backgroundColor: themeSettings.bottomNavigationColor,
              selectedItemColor: themeSettings.bottomNavigationSelectedColor
                  .withValues(
                    red: themeSettings.bottomNavigationSelectedColor.r,
                    green: themeSettings.bottomNavigationSelectedColor.g,
                    blue: themeSettings.bottomNavigationSelectedColor.b,
                    alpha: 0.7,
                  ),
              unselectedItemColor:
                  themeSettings.bottomNavigationColor.computeLuminance() > 0.5
                  ? Colors.black
                  : Colors.white,
              selectedLabelStyle: TextStyle(
                fontSize: (12 * themeSettings.fontSizeScale).clamp(8.0, 14.0),
                fontFamily: _getFontFamilyWithFallback(
                  themeSettings.fontFamily,
                ),
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: (12 * themeSettings.fontSizeScale).clamp(8.0, 14.0),
                fontFamily: _getFontFamilyWithFallback(
                  themeSettings.fontFamily,
                ),
              ),
              type: BottomNavigationBarType.fixed,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: themeSettings.appButtonColor,
                foregroundColor: themeSettings.fontColor2,
                textStyle: TextStyle(
                  fontSize: (18 * themeSettings.fontSizeScale).clamp(
                    14.0,
                    24.0,
                  ),
                  fontFamily: _getFontFamilyWithFallback(
                    themeSettings.fontFamily,
                  ),
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
                fontFamily: _getFontFamilyWithFallback(
                  themeSettings.fontFamily,
                ),
              ),
              bodyLarge: TextStyle(
                color: themeSettings.fontColor1,
                fontSize: 16 * themeSettings.fontSizeScale,
                fontFamily: _getFontFamilyWithFallback(
                  themeSettings.fontFamily,
                ),
              ),
              bodySmall: TextStyle(
                color: themeSettings.fontColor1,
                fontSize: 12 * themeSettings.fontSizeScale,
                fontFamily: _getFontFamilyWithFallback(
                  themeSettings.fontFamily,
                ),
              ),
              titleLarge: TextStyle(
                color: themeSettings.fontColor1,
                fontSize: 22 * themeSettings.fontSizeScale,
                fontFamily: _getFontFamilyWithFallback(
                  themeSettings.fontFamily,
                ),
              ),
              titleMedium: TextStyle(
                color: themeSettings.fontColor1,
                fontSize: 18 * themeSettings.fontSizeScale,
                fontFamily: _getFontFamilyWithFallback(
                  themeSettings.fontFamily,
                ),
              ),
              titleSmall: TextStyle(
                color: themeSettings.fontColor1,
                fontSize: 14 * themeSettings.fontSizeScale,
                fontFamily: _getFontFamilyWithFallback(
                  themeSettings.fontFamily,
                ),
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
                key: mainScaffoldKey,
                // ログイン直後に全データ同期
                // ここではなくAuthGateで呼ぶのがベスト
              ),
            ),
          ),
          routes: {
            // 必須のルート（即座に読み込み）
            '/group_required': (context) => const GroupRequiredPage(),
            '/display_name_setup': (context) => const DisplayNameSetupPage(),
            '/analytics': (context) => HomePage(),

            '/roast': (context) => RoastTimerPage(showBackButton: true),
            '/roast_record': (context) => RoastRecordPage(),
            '/roast_record_list': (context) => RoastRecordListPage(),
            '/roast_analysis': (context) => RoastAnalysisPage(),
            '/drip': (context) => DripCounterPage(),
            '/tasting': (context) => TastingRecordPage(),
            '/work_progress': (context) => WorkProgressPage(),
            '/calendar': (context) => CalendarPage(),
            '/group': (context) => GroupListPage(),
            '/group_info': (context) => GroupInfoPage(),
            '/badges': (context) => BadgeListPage(),
            '/help': (context) => UsageGuidePage(),
            '/settings': (context) => AppSettingsPage(),
            '/assignment_board': (context) => AssignmentBoard(),
            '/todo': (context) => TodoPage(),
            '/calculator': (context) => CalculatorPage(),
            '/group_qr_generate': (context) => const GroupQRGeneratePage(),
            '/group_qr_scanner': (context) => const GroupQRScannerPage(),
          },
        );
      },
    );
  }
}

/// Google認証必須ガード
class AuthGate extends StatefulWidget {
  final Widget child;
  const AuthGate({required this.child, super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isCheckingRedirect = false;
  bool _forceRefresh = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkRedirectResult();
    _checkCurrentUser();

    // 認証状態のリスナーを追加（エラーハンドリング付き）
    try {
      FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (mounted) {
          setState(() {
            _currentUser = user;
          });
          developer.log(
            'AuthGate: 認証状態リスナー - user: ${user?.email}',
            name: 'AuthGate',
          );
        }
      });
    } catch (e) {
      developer.log('AuthGate: 認証状態リスナーの設定でエラー: $e', name: 'AuthGate');
    }
  }

  // 現在のユーザーをチェック
  Future<void> _checkCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
        developer.log('AuthGate: 現在のユーザー: ${user?.email}', name: 'AuthGate');
      }
    } catch (e) {
      developer.log('AuthGate: ユーザーチェックエラー: $e', name: 'AuthGate');
    }
  }

  // 認証状態を強制的に更新するメソッド
  void forceAuthStateRefresh() {
    setState(() {
      _forceRefresh = !_forceRefresh;
    });
    _checkCurrentUser();
  }

  Future<void> _checkRedirectResult() async {
    if (kIsWeb) {
      setState(() {
        _isCheckingRedirect = true;
      });

      try {
        // リダイレクト結果をチェック
        await SecureAuthService.getRedirectResult();
        developer.log('AuthGate: リダイレクト結果チェック完了', name: 'AuthGate');
      } catch (e) {
        developer.log('AuthGate: リダイレクト結果チェックエラー: $e', name: 'AuthGate');
      } finally {
        if (mounted) {
          setState(() {
            _isCheckingRedirect = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // すべてのプラットフォームでFirebase Authの状態をチェック
    try {
      return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // デバッグログを追加
          developer.log(
            'AuthGate: 認証状態変化 - connectionState: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, user: ${snapshot.data?.email}, _currentUser: ${_currentUser?.email}',
            name: 'AuthGate',
          );

          // Web版でリダイレクト結果チェック中はローディング表示
          if (_isCheckingRedirect) {
            return const LoadingScreen(title: '認証を確認中...');
          }

          // 認証状態をより厳密にチェック
          final user = snapshot.data ?? _currentUser;

          // ユーザーが存在しない場合はログイン画面を表示
          if (user == null) {
            developer.log('AuthGate: ユーザーがnull - ログイン画面を表示', name: 'AuthGate');
            return GoogleSignInScreen();
          }

          // ユーザーが存在するが、メールアドレスが確認されていない場合はログイン画面を表示
          if (user.email == null || user.email!.isEmpty) {
            developer.log('AuthGate: メールアドレスが空 - ログイン画面を表示', name: 'AuthGate');
            return GoogleSignInScreen();
          }

          developer.log('AuthGate: 認証成功 - 初回ログインチェックに進む', name: 'AuthGate');
          // ログイン後は初回ログインチェックを行う
          return FirstLoginWrapper(child: widget.child);
        },
      );
    } catch (e) {
      // Firebase初期化エラーの場合はログイン画面を表示
      developer.log('Firebase Auth初期化エラー: $e', name: 'AuthGate');

      // Web版ではFirebaseExceptionの型エラーを特別に処理
      if (kIsWeb && e.toString().contains('JavaScriptObject')) {
        developer.log(
          'Web版: FirebaseException型エラーを検出、ログイン画面を表示',
          name: 'AuthGate',
        );
      }

      return GoogleSignInScreen();
    }
  }
}

/// 初回ログインチェックのラッパー
class FirstLoginWrapper extends StatefulWidget {
  final Widget child;

  const FirstLoginWrapper({super.key, required this.child});

  @override
  State<FirstLoginWrapper> createState() => _FirstLoginWrapperState();
}

class _FirstLoginWrapperState extends State<FirstLoginWrapper> {
  bool _isChecking = true;
  bool _isFirstLogin = false;

  @override
  void initState() {
    super.initState();
    _checkFirstLogin();
  }

  Future<void> _checkFirstLogin() async {
    try {
      debugPrint('FirstLoginWrapper: 初回ログインチェック開始');

      // 一時的に初回ログインチェックをスキップして、メイン画面を表示
      debugPrint('FirstLoginWrapper: 初回ログインチェックをスキップしてメイン画面を表示');

      if (mounted) {
        setState(() {
          _isFirstLogin = false; // 初回ログインではないとみなす
          _isChecking = false;
        });
      }
    } catch (e) {
      debugPrint('FirstLoginWrapper: 初回ログインチェックでエラーが発生: $e');

      if (mounted) {
        setState(() {
          _isFirstLogin = false; // エラーの場合は初回ログインではないと判定
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const LoadingScreen(title: 'Loading...');
    }

    if (_isFirstLogin) {
      return const DisplayNameSetupPage();
    }

    // 初回ログインでない場合はグループ参加チェックを行う
    return GroupRequiredWrapper(child: widget.child);
  }
}

/// グループ参加必須のラッパー
class GroupRequiredWrapper extends StatefulWidget {
  final Widget child;

  const GroupRequiredWrapper({super.key, required this.child});

  @override
  State<GroupRequiredWrapper> createState() => _GroupRequiredWrapperState();
}

class _GroupRequiredWrapperState extends State<GroupRequiredWrapper> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // GroupProviderの初期化を開始（一度だけ）
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);

      // Web版では初期化処理をより慎重に行う
      if (kIsWeb) {
        // Web版では少し待機してから初期化を開始
        await Future.delayed(Duration(milliseconds: 100));
      }

      // データがなく、読み込み中でもない場合のみ初期化
      if (groupProvider.groups.isEmpty &&
          !groupProvider.loading &&
          !groupProvider.initialized) {
        debugPrint('GroupRequiredWrapper: グループデータの初期化を開始');
        await groupProvider.loadUserGroups();
        debugPrint('GroupRequiredWrapper: グループデータの初期化完了');
      } else if (groupProvider.initialized) {
        debugPrint('GroupRequiredWrapper: グループデータは既に初期化済み');
      }

      // 初期化完了フラグを設定
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GroupProvider>(
      builder: (context, groupProvider, child) {
        // GroupProviderが初期化済みで、かつ読み込み中でない場合は初期化完了とみなす
        if (groupProvider.initialized && !groupProvider.loading) {
          _isInitialized = true;
        }

        // 初期化前またはデータ読み込み中の場合はローディング画面を表示
        if (!_isInitialized ||
            groupProvider.loading ||
            !groupProvider.initialized) {
          debugPrint(
            'GroupRequiredWrapper: ローディング画面を表示中 - initialized: ${groupProvider.initialized}, loading: ${groupProvider.loading}, hasGroup: ${groupProvider.hasGroup}',
          );
          return const LoadingScreen(title: 'Loading...');
        }

        // グループに参加していない場合はグループ参加ページを表示
        if (!groupProvider.hasGroup) {
          debugPrint('GroupRequiredWrapper: グループ未参加 - GroupRequiredPageを表示');
          return const GroupRequiredPage();
        }

        // グループに参加している場合はメイン画面を表示
        debugPrint('GroupRequiredWrapper: グループ参加済み - メイン画面を表示');
        // データ同期は後で自動的に実行されるため、ここでは実行しない
        return widget.child;
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
      UserCredential? userCredential;

      // Web版では一時的にポップアップ方式を使用（localhost開発用）
      if (kIsWeb) {
        if (!mounted) return;
        setState(() {
          _loading = true;
          _error = 'Googleログインを開始しています...';
        });

        // ポップアップ方式でログイン（localhost開発用）
        userCredential = await SecureAuthService.signInWithGoogle();
        developer.log('Web版: ポップアップ方式でログイン成功', name: 'GoogleSignInScreen');
      } else {
        userCredential =
            await SecureAuthService.signInWithGoogleForceAccountSelection();
      }

      if (userCredential == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Googleアカウントの選択がキャンセルされました';
        });
        return;
      }

      // ログイン成功のデバッグログ
      developer.log(
        'GoogleSignInScreen: ログイン成功 - user: ${userCredential.user?.email}, uid: ${userCredential.user?.uid}',
        name: 'GoogleSignInScreen',
      );

      // 認証状態を強制的に更新
      await SecureAuthService.forceAuthStateRefresh();

      // セキュリティイベントを記録
      await SecureAuthService.logSecurityEvent(
        kIsWeb ? 'secure_login_success_web_popup' : 'secure_login_success',
      );

      // ログイン成功後に認証状態の変化を強制的にトリガー
      developer.log(
        'GoogleSignInScreen: 認証状態の変化をトリガー',
        name: 'GoogleSignInScreen',
      );

      // 少し待機してから認証状態の変化を確認
      await Future.delayed(const Duration(milliseconds: 500));

      // 現在のユーザーを再確認
      final currentUser = FirebaseAuth.instance.currentUser;
      developer.log(
        'GoogleSignInScreen: 現在のユーザー: ${currentUser?.email}',
        name: 'GoogleSignInScreen',
      );

      // AuthGateの認証状態を強制的に更新
      if (mounted) {
        // 親のAuthGateの状態を更新
        final authGateState = context.findAncestorStateOfType<_AuthGateState>();
        if (authGateState != null) {
          authGateState.forceAuthStateRefresh();
          developer.log(
            'GoogleSignInScreen: AuthGateの認証状態を強制更新',
            name: 'GoogleSignInScreen',
          );
        }
      }
      // 追加: ログイン成功後にクラウド設定をダウンロード
      try {
        await DataSyncService.downloadAllData();
        // ダウンロードした設定でThemeSettingsを更新
        if (!mounted) return;
        final themeSettings = Provider.of<ThemeSettings>(
          context,
          listen: false,
        );

        // フォント設定を更新
        final fontSize = await UserSettingsFirestoreService.getSetting(
          'fontSize',
        );
        final fontFamily = await UserSettingsFirestoreService.getSetting(
          'fontFamily',
        );
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
            // mergeGroupDataWithLocalメソッドを使用してデータを更新
            assignmentBoardKey.currentState!.mergeGroupDataWithLocal(
              assignmentMembers,
            );
          }
        } catch (e) {
          // 担当表データの更新に失敗
        }

        // サウンド設定は既にSharedPreferencesに保存されているので、
        // 各画面で読み込まれる際に反映される
      } catch (e) {
        // クラウド設定のダウンロードに失敗
      }
    } catch (e) {
      if (!mounted) return;

      String errorMessage = 'Googleログインに失敗しました';

      // 特定のエラーの場合は分かりやすいメッセージを表示
      if (e.toString().contains('invalid-cert-hash')) {
        errorMessage =
            '署名証明書の検証に失敗しました。\nこれはGoogle Playからインストールしたアプリで発生する問題です。\n開発者に連絡してください。';
      } else if (e.toString().contains('network')) {
        errorMessage = 'ネットワーク接続に問題があります。\nインターネット接続を確認してください。';
      } else if (e.toString().contains('cancelled')) {
        errorMessage = 'ログインがキャンセルされました。';
      }

      setState(() {
        _error = errorMessage;
      });
      // Google Sign-In エラー
    } finally {
      // do nothing
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
    });
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
                  Container(
                    width: kIsWeb ? 400 : double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: _error!.contains('開始')
                          ? Colors.blue.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _error!.contains('開始')
                            ? Colors.blue
                            : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: kIsWeb && _error!.contains('開始')
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue,
                                size: 20,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Icon(
                                _error!.contains('開始')
                                    ? Icons.info_outline
                                    : Icons.error_outline,
                                color: _error!.contains('開始')
                                    ? Colors.blue
                                    : Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: _error!.contains('開始')
                                        ? Colors.blue
                                        : Colors.red,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                _loading
                    ? Column(
                        children: [
                          CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Googleログインを処理中...',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          ElevatedButton.icon(
                            icon: Image.asset(
                              'assets/google_logo.png',
                              width: 24,
                              height: 24,
                            ),
                            label: Text('Googleでログイン'),
                            onPressed: _signInWithGoogle,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPasscode();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Web版では通知サービスを停止しない
    if (!kIsWeb) {
      TodoNotificationService().stopNotificationService();
    }
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
    final code = await UserSettingsFirestoreService.getSetting('app_passcode');
    final isLockEnabled =
        await UserSettingsFirestoreService.getSetting(
          'passcode_lock_enabled',
        ) ??
        false;

    // パスコードが設定されているかチェック
    bool needsAuth = false;
    if (code != null && isLockEnabled) {
      needsAuth = true;
    }

    if (needsAuth && _unlocked) {
      if (mounted) {
        setState(() {
          _unlocked = false;
        });
      }
    }
  }

  Future<void> _checkPasscode() async {
    final code = await UserSettingsFirestoreService.getSetting('app_passcode');
    final isLockEnabled =
        await UserSettingsFirestoreService.getSetting(
          'passcode_lock_enabled',
        ) ??
        false;

    // パスコードが設定されているかチェック
    bool needsAuth = false;
    if (code != null && isLockEnabled) {
      needsAuth = true;
    }

    if (mounted) {
      setState(() {
        _passcode = code;
        _loading = false;
        _unlocked = !needsAuth;
      });
    }
  }

  void _onUnlock() {
    if (mounted) {
      setState(() {
        _unlocked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LoadingScreen(title: 'Loading...');
    }
    if (!_unlocked) {
      // パスコードが設定されている場合のみ認証画面を表示
      if (_passcode != null && _passcode!.isNotEmpty) {
        return PasscodeInputScreen(
          onUnlock: _onUnlock,
          correctPasscode: _passcode!,
        );
      } else {
        // パスコードが設定されていない場合は直接アプリを表示
        return widget.child;
      }
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
      if (mounted) {
        setState(() {
          _error = '4桁の数字で入力してください';
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _checking = true;
      });
    }
    Future.delayed(Duration(milliseconds: 300), () {
      if (input == widget.correctPasscode) {
        widget.onUnlock();
      } else {
        if (mounted) {
          setState(() {
            _error = 'パスコードが違います';
            _checking = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            color: Provider.of<ThemeSettings>(context).cardBackgroundColor,
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
                        backgroundColor: Provider.of<ThemeSettings>(
                          context,
                        ).appButtonColor,
                        foregroundColor: Provider.of<ThemeSettings>(
                          context,
                        ).fontColor2,
                        textStyle: const TextStyle(fontSize: 16),
                        padding: const EdgeInsets.symmetric(vertical: 14),
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

// MainScaffoldのグローバルキー
final GlobalKey<MainScaffoldState> mainScaffoldKey =
    GlobalKey<MainScaffoldState>();

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => MainScaffoldState();
}

class MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 2; // デフォルトでホーム画面を表示
  final PageController _pageController = PageController(initialPage: 2);

  InterstitialAd? _interstitialAd;

  // バナー広告用
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  static const double _bannerHeight = 50.0;

  // ページを遅延読み込みするためのリスト
  final List<Widget> _pages = [
    RoastTimerPage(showBackButton: false), // 焙煎タイマー
    DripCounterPage(key: dripCounterPageKey), // カウンター
    HomePage(), // ホーム（中央）
    SchedulePage(), // スケジュール
    AssignmentBoard(key: assignmentBoardKey), // 担当表
  ];

  @override
  void initState() {
    super.initState();
    // Web互換性の初期化
    _initializeWebCompatibility();
    // 自動同期サービスを初期化
    _initializeAutoSync();
    // Web版では広告を読み込まない
    if (!kIsWeb) {
      // 起動時のインタースティシャル広告を無効化
      // _loadInterstitialAd();
      _loadBannerAd();
    }
  }

  // フォントファミリーを動的に設定する関数（フォールバック付き）
  String _getFontFamilyWithFallback(String fontFamily) {
    try {
      switch (fontFamily) {
        case 'Noto Sans JP':
          return GoogleFonts.notoSans().fontFamily ?? 'Noto Sans JP';
        case 'ZenMaruGothic':
          return 'ZenMaruGothic';
        case 'utsukushiFONT':
          return 'utsukushiFONT';
        case 'KiwiMaru':
          return 'KiwiMaru';
        case 'HannariMincho':
          return 'HannariMincho';
        case 'Harenosora':
          return 'Harenosora';
        default:
          return GoogleFonts.notoSans().fontFamily ?? 'Noto Sans JP';
      }
    } catch (e) {
      // エラーが発生した場合はデフォルトフォントを返す
      return 'Noto Sans JP';
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
    // グループ作成直後はAutoSyncServiceの初期化をスキップ（クラッシュ防止のため）

    // GroupProviderを初期化（グループデータの監視は後で開始）
    if (mounted) {
      final groupProvider = context.read<GroupProvider>();
      await groupProvider.loadUserGroups();
      // グループデータの監視は後で開始（クラッシュ防止のため）
    }

    // GamificationProviderの初期化は後で実行（クラッシュ防止のため）
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
    // ユーザーアクティビティを記録
    SessionManagementService.recordUserActivity();
  }

  // 外部からタブ切り替えを可能にするpublicメソッド
  void switchToTab(int index) {
    _onItemTapped(index);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GroupProvider>(
      builder: (context, groupProvider, child) {
        // グループに参加していない場合はGroupRequiredPageを表示
        if (!groupProvider.hasGroup) {
          return const GroupRequiredPage();
        }

        // WEB版とモバイル版で異なるレイアウトを適用
        if (WebUIUtils.isWeb) {
          return _buildWebLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }

  /// WEB版用のレイアウトを構築
  Widget _buildWebLayout() {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: themeSettings.appBarColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.local_cafe,
                color: themeSettings.appBarTextColor,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'ローストプラス',
              style: TextStyle(
                color: themeSettings.appBarTextColor,
                fontSize: 22 * WebUIUtils.getFontSizeScale(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
        elevation: 0,
        toolbarHeight: 70,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: WebUIUtils.responsiveContainer(
        context: context,
        child: _pages[_selectedIndex],
      ),
    );
  }

  /// モバイル版用のレイアウトを構築（従来の実装）
  Widget _buildMobileLayout() {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SizedBox(width: 8),
            Text(
              'ローストプラス',
              style: TextStyle(
                color: themeSettings.appBarTextColor,
                fontSize: MediaQuery.of(context).size.height < 600 ? 16 : 18,
              ),
            ),
          ],
        ),
        toolbarHeight: MediaQuery.of(context).size.height < 600 ? 48 : 56,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Web版では寄付者チェックをスキップ
            FutureBuilder<bool>(
              future: kIsWeb ? Future.value(true) : isDonorUser(),
              builder: (context, snapshot) {
                // Web版では広告のパディングを適用しない
                // 寄付者や未判定の間は余計な余白を付けない
                // バナー広告が実際に読み込まれている場合のみ余白を確保
                final adPadding = kIsWeb
                    ? 0.0
                    : (snapshot.connectionState == ConnectionState.done &&
                              snapshot.data != true &&
                              _isBannerAdLoaded
                          ? _bannerHeight
                          : 0.0);

                // 下部広告分のみ余白を確保（ボトムナビ分はScaffoldが処理）
                final bottomPadding = adPadding;

                // 画面サイズに応じてパディングを調整
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
            // Web版では広告を表示しない
            if (!kIsWeb)
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
      ),
      bottomNavigationBar: Consumer<ThemeSettings>(
        builder: (context, themeSettings, child) {
          final fontSize = (12 * themeSettings.fontSizeScale).clamp(8.0, 14.0);

          // 画面サイズに応じてボトムナビゲーションの高さを調整
          final screenHeight = MediaQuery.of(context).size.height;
          final screenWidth = MediaQuery.of(context).size.width;

          // 小さい画面では高さを小さく、アイコンサイズも調整
          double barHeight;
          double iconSize;

          if (screenHeight < 600) {
            // 非常に小さい画面（iPhone SE等）
            barHeight = 48.0;
            iconSize = 20.0;
          } else if (screenHeight < 700) {
            // 小さい画面
            barHeight = 52.0;
            iconSize = 22.0;
          } else if (screenHeight < 800) {
            // 中程度の画面
            barHeight = 56.0;
            iconSize = 24.0;
          } else {
            // 大きい画面
            barHeight = (56 + (themeSettings.fontSizeScale - 1.0) * 20).clamp(
              56.0,
              80.0,
            );
            iconSize = 24.0;
          }

          // 幅が狭い場合はフォントサイズを小さく
          final adjustedFontSize = screenWidth < 360
              ? fontSize * 0.8
              : fontSize;

          return SafeArea(
            child: Container(
              height: barHeight,
              decoration: BoxDecoration(
                color: themeSettings.bottomNavigationColor,
                border: Border(
                  top: BorderSide(
                    color: themeSettings.fontColor1.withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                ),
              ),
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedItemColor: themeSettings.bottomNavigationSelectedColor,
                unselectedItemColor:
                    themeSettings.bottomNavigationUnselectedColor,
                selectedLabelStyle: TextStyle(
                  fontSize: adjustedFontSize,
                  fontFamily: _getFontFamilyWithFallback(
                    themeSettings.fontFamily,
                  ),
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: adjustedFontSize,
                  fontFamily: _getFontFamilyWithFallback(
                    themeSettings.fontFamily,
                  ),
                  fontWeight: FontWeight.w400,
                ),
                items: [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.local_fire_department, size: iconSize),
                    label: '焙煎タイマー',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.local_cafe, size: iconSize),
                    label: 'カウンター',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home, size: iconSize),
                    label: 'ホーム',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.pending_actions, size: iconSize),
                    label: 'スケジュール',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.group, size: iconSize),
                    label: '担当表',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
