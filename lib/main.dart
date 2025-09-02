import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'models/roast_schedule_form_provider.dart';

import 'services/encrypted_firebase_config_service.dart';
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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Web互換性の初期化
  if (WebCompatibility.isWeb) {
    developer.log('Web版互換性モードで起動', name: 'Main');
  }

  // パフォーマンス監視開始
  PerformanceMonitor.startTimer('アプリ起動全体');

  // デバッグ情報を出力
  developer.log('アプリ起動開始', name: 'Main');

  // Firebase初期化を最初に実行（他の初期化処理が依存しているため）
  await PerformanceMonitor.measureAsync('Firebase初期化', _initializeFirebase);

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

  // パフォーマンス監視終了
  PerformanceMonitor.endTimer('アプリ起動全体');

  // 詳細パフォーマンスレポートを生成
  PerformanceMonitor.generateDetailedReport();
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

    // その他のエラーは通常通り処理
    FlutterError.presentError(details);
  };
}

// Firebase初期化
Future<void> _initializeFirebase() async {
  try {
    await EncryptedFirebaseConfigService.initializeFirebase();
    developer.log('Firebase初期化完了', name: 'Main');
  } catch (e) {
    // 重複初期化エラーの場合は警告として記録
    if (e.toString().contains('duplicate-app') ||
        e.toString().contains('already exists')) {
      developer.log('Firebase初期化警告: 既に初期化されています - $e', name: 'Main');
    } else {
      developer.log('Firebase初期化エラー: $e', name: 'Main');

      // TestFlight環境ではFirebase初期化エラーでもアプリを起動
      if (kDebugMode) {
        developer.log('デバッグモード: Firebase初期化エラーを無視してアプリを起動', name: 'Main');
      } else {
        // 本番環境ではFirebase初期化エラーを記録するが、アプリは起動
        developer.log('本番環境: Firebase初期化エラーを記録、アプリは起動を継続', name: 'Main');

        // クラッシュを防ぐため、Firebase関連の機能を無効化
        try {
          // 基本的なFirebase設定のみで初期化を試行
          await Firebase.initializeApp();
          developer.log('基本的なFirebase初期化が完了しました', name: 'Main');
        } catch (fallbackError) {
          developer.log('基本的なFirebase初期化も失敗: $fallbackError', name: 'Main');
          // 完全にFirebaseを無効化してアプリを起動
        }
      }
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
    final themeSettings = await ThemeSettings.load();

    // 初期化完了をログ出力
    developer.log('テーマ設定初期化完了（デフォルトテーマ）', name: 'Main');
  } catch (e) {
    developer.log('テーマ設定読み込みエラー: $e', name: 'Main');
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
