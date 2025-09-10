import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'models/roast_schedule_form_provider.dart';

import 'services/encrypted_firebase_config_service.dart';
import 'services/secure_auth_service.dart';
import 'models/theme_settings.dart';
import 'models/group_provider.dart';
import 'models/work_progress_models.dart';
import 'models/tasting_models.dart';
import 'models/bean_sticker_models.dart';
import 'models/gamification_provider.dart';
import 'models/group_gamification_provider.dart';
import 'models/dashboard_stats_provider.dart';
import 'services/todo_notification_service.dart';
import 'services/auto_sync_service.dart';
import 'services/roast_timer_notification_service.dart';
import 'services/security_monitor_service.dart';
import 'services/encrypted_local_storage_service.dart';
import 'services/network_security_service.dart';
import 'services/session_management_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:developer' as developer;
import 'utils/performance_monitor.dart';
import 'utils/web_compatibility.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    developer.log('WidgetsFlutterBinding初期化完了', name: 'Main');

    // Web版でのデバッグサービスエラーを防ぐための保護
    if (kIsWeb) {
      developer.log('Web版: デバッグサービスエラー保護を有効化', name: 'Main');
    }

    // Web互換性の初期化
    if (WebCompatibility.isWeb) {
      developer.log('Web版互換性モードで起動', name: 'Main');
      developer.log('Web版: ブラウザ情報 - ${WebCompatibility.isWeb}', name: 'Main');
    }

    // パフォーマンス監視開始
    PerformanceMonitor.startTimer('アプリ起動全体');

    // デバッグ情報を出力
    developer.log('アプリ起動開始', name: 'Main');

    // Firebase初期化は起動体感に影響するため、runApp後に非同期で実行する
    // ただしWeb向けのリダイレクト処理等で事前初期化が必要な場合はスキップしない
    if (kIsWeb) {
      // Webでは既にindex.htmlで初期化されていることが多いため、従来通り同期的に処理
      await PerformanceMonitor.measureAsync('Firebase初期化', _initializeFirebase);
    } else {
      developer.log('ネイティブ版: Firebase初期化をrunApp後に非同期で実行します', name: 'Main');
    }

    // Web版ではリダイレクト結果をチェック
    if (kIsWeb) {
      try {
        // Firebase初期化を確実に完了してからリダイレクト結果をチェック
        await PerformanceMonitor.measureAsync(
          'Web版Firebase初期化確認',
          _ensureFirebaseInitialized,
        );

        await PerformanceMonitor.measureAsync(
          'Web版リダイレクト結果チェック',
          _checkWebRedirectResult,
        );
        // リダイレクト結果チェック後に現在のユーザーをログ
        try {
          final currentUser = fb_auth.FirebaseAuth.instance.currentUser;
          developer.log('Web版: 現在のユーザー: ${currentUser?.email}', name: 'Main');
        } catch (e) {
          developer.log('Web版: 現在ユーザー確認でエラー: $e', name: 'Main');
        }
      } catch (e) {
        developer.log('Web版: リダイレクト結果チェックでエラー: $e', name: 'Main');
        // Web版ではエラーがあってもアプリを継続
      }
    }

    // その他の初期化処理を並列実行
    final initializationTasks = <Future<void>>[
      PerformanceMonitor.measureAsync('日付フォーマット初期化', _initializeDateFormatting),
      PerformanceMonitor.measureAsync('テーマ設定初期化', _initializeThemeSettings),
    ];

    // Web版ではシステム設定初期化を除外
    if (!kIsWeb) {
      initializationTasks.add(
        PerformanceMonitor.measureAsync('システム設定初期化', _initializeSystemSettings),
      );
    }

    await Future.wait(initializationTasks);

    // アプリを即座に起動
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => RoastScheduleFormProvider()),
          ChangeNotifierProvider<ThemeSettings>.value(
            value: await ThemeSettings.load(),
          ),
          ChangeNotifierProvider(create: (_) => GroupProvider()),
          ChangeNotifierProvider(create: (_) => WorkProgressProvider()),
          ChangeNotifierProvider(create: (_) => TastingProvider()),
          ChangeNotifierProvider(create: (_) => BeanStickerProvider()),
          ChangeNotifierProvider(create: (_) => GamificationProvider()),
          ChangeNotifierProvider(create: (_) => GroupGamificationProvider()),
          ChangeNotifierProvider(create: (_) => DashboardStatsProvider()),
        ],
        child: WorkAssignmentApp(),
      ),
    );

    // 非必須の初期化処理をバックグラウンドで実行
    _initializeBackgroundServices();

    // ネイティブ向けFirebase初期化をバックグラウンドで実行（UI表示をブロックしない）
    if (!kIsWeb) {
      // unawaited を使わずに非同期で実行して警告を避ける
      PerformanceMonitor.measureAsync(
        'Firebase初期化',
        _initializeFirebase,
      ).catchError((e) {
        developer.log('バックグラウンドFirebase初期化エラー: $e', name: 'Main');
      });
    }

    // パフォーマンス監視終了
    PerformanceMonitor.endTimer('アプリ起動全体');

    // 詳細パフォーマンスレポートを生成
    PerformanceMonitor.generateDetailedReport();

    developer.log('アプリ起動処理完了', name: 'Main');
  } catch (e, stackTrace) {
    developer.log('アプリ起動時エラー: $e', name: 'Main');
    developer.log('スタックトレース: $stackTrace', name: 'Main');

    // Web版では詳細なエラー情報をコンソールに出力
    if (kIsWeb) {
      developer.log('Web版: ブラウザのコンソールでエラー詳細を確認してください', name: 'Main');
      developer.log('Flutter Web Error: $e', name: 'Main');
      developer.log('Stack Trace: $stackTrace', name: 'Main');
    }

    // エラーが発生してもアプリを起動
    try {
      runApp(
        MaterialApp(
          title: 'RoastPlus',
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('アプリの初期化中にエラーが発生しました'),
                  SizedBox(height: 8),
                  Text('$e', style: TextStyle(fontSize: 12)),
                  if (kIsWeb) ...[
                    SizedBox(height: 16),
                    Text(
                      'ブラウザのコンソールで詳細を確認してください',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    } catch (finalError) {
      developer.log('エラー画面表示も失敗: $finalError', name: 'Main');
      // 最後の手段として最小限のアプリを起動
      if (kIsWeb) {
        developer.log('Critical Error: $finalError', name: 'Main');
      }
    }
  }
}

// システム設定の初期化
Future<void> _initializeSystemSettings() async {
  // Web版ではシステム設定をスキップ
  if (kIsWeb) {
    return;
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // システムUIの設定
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );

  // エラーハンドリングを設定
  FlutterError.onError = (FlutterErrorDetails details) {
    // キーボードイベントのエラーを無視
    if (details.exception.toString().contains('KeyUpEvent') ||
        details.exception.toString().contains('physical key is not pressed') ||
        details.exception.toString().contains('_pressedKeys.containsKey') ||
        details.exception.toString().contains('HardwareKeyboard') ||
        details.exception.toString().contains('KeyUpEvent#') ||
        details.exception.toString().contains('PhysicalKeyboardKey#')) {
      return;
    }

    // オーバーフローエラーを非表示にする
    if (details.exception is FlutterError &&
        details.exception.toString().contains('overflowed')) {
      return;
    }

    // INTERNAL ASSERTION FAILEDエラーのログを強化
    if (details.exception.toString().contains('INTERNAL ASSERTION FAILED')) {
      developer.log(
        '重大なFirestoreエラー検出: INTERNAL ASSERTION FAILED',
        name: 'Main',
        error: details.exception,
        stackTrace: details.stack,
      );
      developer.log('Firestore接続のリセットを推奨します', name: 'Main');
    }

    // その他のエラーは通常通り処理
    FlutterError.presentError(details);
  };
}

// Firebase初期化
Future<void> _initializeFirebase() async {
  try {
    // Web版では既にindex.htmlで初期化されているため、スキップ
    if (kIsWeb) {
      developer.log('Web版: Firebaseは既にindex.htmlで初期化済みのためスキップ', name: 'Main');

      // Web版でもFirebaseアプリが利用可能かチェック
      try {
        final apps = Firebase.apps;
        if (apps.isEmpty) {
          developer.log('Web版: Firebaseアプリが見つからないため、初期化を試行', name: 'Main');
          await Firebase.initializeApp(
            options: await DefaultFirebaseOptions.currentPlatform,
          );
          developer.log('Web版: Firebase初期化完了', name: 'Main');
        } else {
          developer.log(
            'Web版: Firebaseアプリが既に存在します (${apps.length}個)',
            name: 'Main',
          );
        }

        // 重要: WebのAuth永続化をLOCALに固定（リダイレクト後にセッションが消える問題対策）
        try {
          await fb_auth.FirebaseAuth.instance.setPersistence(
            fb_auth.Persistence.LOCAL,
          );
          developer.log('Web版: FirebaseAuth永続化をLOCALに設定', name: 'Main');
        } catch (persistError) {
          developer.log('Web版: 永続化設定に失敗: $persistError', name: 'Main');
        }

        // Web版でFirestoreの初期化を確実に行う（ネットワーク有効化はスキップ）
        try {
          // Web版ではenableNetwork()をスキップ（デバッグサービスエラーの原因）
          developer.log(
            'Web版: Firestoreインスタンス取得完了（ネットワーク有効化はスキップ）',
            name: 'Main',
          );

          // Web版ではFirestoreの初期化を待つ
          developer.log('Web版: Firestore初期化待機中', name: 'Main');
          await Future.delayed(Duration(milliseconds: 500));
          developer.log('Web版: Firestore初期化待機完了', name: 'Main');
        } catch (firestoreError) {
          developer.log('Web版: Firestore初期化エラー: $firestoreError', name: 'Main');
        }
      } catch (e) {
        developer.log('Web版: Firebaseアプリチェックエラー: $e', name: 'Main');
        // Web版ではFirebaseエラーがあってもアプリを継続
        developer.log('Web版: Firebaseエラーを無視してアプリを継続', name: 'Main');
      }
      return;
    }

    // セキュリティ強化: 暗号化されたFirebase設定で初期化
    try {
      await EncryptedFirebaseConfigService.initializeFirebase();
      developer.log('暗号化されたFirebase設定で初期化完了', name: 'Main');
    } catch (e) {
      developer.log('暗号化Firebase設定エラー: $e', name: 'Main');
      // フォールバック: デフォルト設定で初期化
      await Firebase.initializeApp(
        options: await DefaultFirebaseOptions.currentPlatform,
      );
      developer.log('フォールバックFirebase初期化完了', name: 'Main');
    }
  } catch (e) {
    developer.log('Firebase初期化エラー: $e', name: 'Main');

    // エラーが発生してもアプリは起動を継続
    try {
      // 最後の手段として、デフォルト設定で初期化を試行
      await Firebase.initializeApp(
        options: await DefaultFirebaseOptions.currentPlatform,
      );
      developer.log('フォールバックFirebase初期化完了', name: 'Main');
    } catch (fallbackError) {
      developer.log('フォールバックFirebase初期化も失敗: $fallbackError', name: 'Main');
      // 完全にFirebaseを無効化してアプリを起動
    }
  }
}

// 日付フォーマット初期化
Future<void> _initializeDateFormatting() async {
  try {
    await initializeDateFormatting('ja_JP', null);
  } catch (e) {
    developer.log('日付フォーマット初期化エラー: $e', name: 'Main');
  }
}

// テーマ設定初期化
Future<void> _initializeThemeSettings() async {
  try {
    // デフォルトテーマのみで即座に初期化（Firebase設定は後で非同期取得）
    await ThemeSettings.load();

    // 初期化完了をログ出力
    developer.log('テーマ設定初期化完了（デフォルトテーマ）', name: 'Main');
  } catch (e) {
    developer.log('テーマ設定読み込みエラー: $e', name: 'Main');
  }
}

// Web版Firebase初期化確認
Future<void> _ensureFirebaseInitialized() async {
  try {
    developer.log('Web版: Firebase初期化状態を確認中', name: 'Main');
    final apps = Firebase.apps;
    developer.log('Web版: Firebaseアプリ数: ${apps.length}', name: 'Main');

    if (apps.isEmpty) {
      developer.log('Web版: Firebaseアプリが見つからないため、初期化を試行', name: 'Main');
      await Firebase.initializeApp(
        options: await DefaultFirebaseOptions.currentPlatform,
      );
      developer.log('Web版: Firebase初期化完了', name: 'Main');
    } else {
      developer.log(
        'Web版: Firebaseアプリが既に存在します (${apps.length}個)',
        name: 'Main',
      );
    }

    // 重要: WebのAuth永続化をLOCALに固定（リダイレクト後にセッションが消える問題対策）
    try {
      await fb_auth.FirebaseAuth.instance.setPersistence(
        fb_auth.Persistence.LOCAL,
      );
      developer.log('Web版: FirebaseAuth永続化をLOCALに設定', name: 'Main');
    } catch (persistError) {
      developer.log('Web版: 永続化設定に失敗: $persistError', name: 'Main');
    }
  } catch (e) {
    developer.log('Web版: Firebase初期化確認エラー: $e', name: 'Main');
    // Web版ではFirebaseエラーがあってもアプリを継続
    developer.log('Web版: Firebaseエラーを無視してアプリを継続', name: 'Main');
  }
}

// Web版リダイレクト結果チェック
Future<void> _checkWebRedirectResult() async {
  try {
    developer.log('Web版: リダイレクト結果をチェック中', name: 'Main');

    // Firebase認証の初期化を確認
    final apps = Firebase.apps;
    if (apps.isEmpty) {
      developer.log('Web版: Firebaseアプリが初期化されていません', name: 'Main');
      return;
    }

    // 現在のユーザー状態を確認
    final currentUser = fb_auth.FirebaseAuth.instance.currentUser;
    developer.log('Web版: リダイレクト前の現在ユーザー: ${currentUser?.email}', name: 'Main');

    // SecureAuthServiceをインポートして使用
    final redirectResult = await SecureAuthService.getRedirectResult();

    if (redirectResult?.user != null) {
      developer.log(
        'Web版: リダイレクト認証が成功しました: ${redirectResult!.user!.email}',
        name: 'Main',
      );

      // リダイレクト後のユーザー状態を再確認
      final newUser = fb_auth.FirebaseAuth.instance.currentUser;
      developer.log('Web版: リダイレクト後の現在ユーザー: ${newUser?.email}', name: 'Main');
    } else {
      developer.log('Web版: リダイレクト認証結果なし', name: 'Main');
    }
  } catch (e) {
    developer.log('Web版: リダイレクト結果チェックエラー: $e', name: 'Main');
  }
}

// バックグラウンドで非必須サービスを初期化
void _initializeBackgroundServices() async {
  // アプリ終了時のクリーンアップを設定
  WidgetsBinding.instance.addObserver(
    LifecycleEventHandler(
      detachedCallBack: () async {
        // Web版ではネイティブ機能のクリーンアップをスキップ
        if (!kIsWeb) {
          TodoNotificationService().stopNotificationService();
          SecurityMonitorService.stopMonitoring();
          SessionManagementService.stopMonitoring();
        }
        AutoSyncService.dispose();
      },
    ),
  );

  // 非必須サービスを並列で初期化
  final backgroundTasks = <Future<void>>[
    PerformanceMonitor.measureAsync('AutoSync初期化', _initializeAutoSync),
  ];

  // Web版ではネイティブ機能を除外
  if (!kIsWeb) {
    backgroundTasks.addAll([
      PerformanceMonitor.measureAsync(
        '通知サービス初期化',
        _initializeNotificationServices,
      ),
      PerformanceMonitor.measureAsync('広告初期化', _initializeAds),
      PerformanceMonitor.measureAsync(
        'セキュリティサービス初期化',
        _initializeSecurityServices,
      ),
      PerformanceMonitor.measureAsync(
        'ストレージサービス初期化',
        _initializeStorageServices,
      ),
    ]);
  }

  await Future.wait(backgroundTasks);
}

// 通知サービス初期化
Future<void> _initializeNotificationServices() async {
  // Web版では通知サービスをスキップ
  if (kIsWeb) {
    return;
  }

  try {
    await RoastTimerNotificationService.initialize();
    await RoastTimerNotificationService.requestPermissions();

    TodoNotificationService().setNavigatorKey(navigatorKey);
    TodoNotificationService().startNotificationService();
  } catch (e) {
    developer.log('通知サービス初期化エラー: $e', name: 'Main');
  }
}

// 広告初期化
Future<void> _initializeAds() async {
  // Web版では広告をスキップ
  if (kIsWeb) {
    return;
  }

  try {
    await MobileAds.instance.initialize();
  } catch (e) {
    developer.log('広告初期化エラー: $e', name: 'Main');
  }
}

// AutoSync初期化
Future<void> _initializeAutoSync() async {
  // Web版ではAutoSyncをスキップ
  if (kIsWeb) {
    developer.log('Web版: AutoSyncServiceをスキップ', name: 'Main');
    return;
  }

  try {
    await AutoSyncService.initialize();
  } catch (e) {
    developer.log('AutoSyncService初期化エラー: $e', name: 'Main');
  }
}

// セキュリティサービス初期化
Future<void> _initializeSecurityServices() async {
  // Web版ではセキュリティサービスをスキップ
  if (kIsWeb) {
    return;
  }

  try {
    await SecurityMonitorService.startMonitoring();
    await NetworkSecurityService.initialize();
    await SessionManagementService.initialize();
    await SessionManagementService.recordUserActivity();
  } catch (e) {
    developer.log('セキュリティサービス初期化エラー: $e', name: 'Main');
  }
}

// ストレージサービス初期化
Future<void> _initializeStorageServices() async {
  // Web版ではストレージサービスをスキップ
  if (kIsWeb) {
    return;
  }

  try {
    await EncryptedLocalStorageService.initialize();
  } catch (e) {
    developer.log('ストレージサービス初期化エラー: $e', name: 'Main');
  }
}

// ライフサイクルイベントハンドラー
class LifecycleEventHandler extends WidgetsBindingObserver {
  final Future<void> Function()? detachedCallBack;

  LifecycleEventHandler({this.detachedCallBack});

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        // アプリが再開された時にキーボード状態をリセット
        try {
          await SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.edgeToEdge,
            overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
          );
        } catch (e) {
          developer.log('システムUI設定エラー: $e', name: 'Main');
        }
        break;
      case AppLifecycleState.detached:
        if (detachedCallBack != null) {
          await detachedCallBack!();
        }
        break;
      default:
        break;
    }
  }
}
