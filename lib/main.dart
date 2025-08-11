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
import 'services/biometric_auth_service.dart';
import 'services/encrypted_local_storage_service.dart'; // Added
import 'services/network_security_service.dart';
import 'services/session_management_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:developer' as developer;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // デバッグ情報を出力
  developer.log('アプリ起動開始', name: 'Main');
  developer.log('WEB版: $kIsWeb', name: 'Main');

  // Web版では画面の縦向き固定を解除
  if (!kIsWeb) {
    // 画面を縦向きに固定
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  //
  // システムUIの設定
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      // キーボードイベントの処理を改善
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // キーボードイベントの処理を改善
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
      developer.log('キーボードイベントエラーを無視: ${details.exception}', name: 'Main');
      return;
    }

    // オーバーフローエラーを非表示にする
    if (details.exception is FlutterError &&
        details.exception.toString().contains('overflowed')) {
      // オーバーフローエラーは無視
      return;
    }

    // その他のエラーは通常通り処理
    developer.log('エラー発生: ${details.exception}', name: 'Main');
    FlutterError.presentError(details);
  };

  try {
    developer.log('Firebase初期化開始', name: 'Main');
    // 暗号化されたFirebase設定で初期化
    await EncryptedFirebaseConfigService.initializeFirebase();
    developer.log('Firebase初期化完了', name: 'Main');
  } catch (e) {
    developer.log('Firebase初期化エラー: $e', name: 'Main');
  }

  try {
    developer.log('日付フォーマット初期化開始', name: 'Main');
    await initializeDateFormatting('ja_JP', null);
    developer.log('日付フォーマット初期化完了', name: 'Main');
  } catch (e) {
    developer.log('日付フォーマット初期化エラー: $e', name: 'Main');
  }

  try {
    developer.log('テーマ設定読み込み開始', name: 'Main');
    final themeSettings = await ThemeSettings.load();
    developer.log('テーマ設定読み込み完了', name: 'Main');

    // 初期インストール時にデフォルトテーマを適用
    await themeSettings.initializeDefaultTheme();
  } catch (e) {
    developer.log('テーマ設定読み込みエラー: $e', name: 'Main');
  }

  // Web版では通知サービスを初期化しない
  if (!kIsWeb) {
    try {
      developer.log('通知サービス初期化開始', name: 'Main');
      // 焙煎タイマー通知サービスを初期化
      await RoastTimerNotificationService.initialize();

      // 通知権限をリクエスト
      await RoastTimerNotificationService.requestPermissions();
      developer.log('通知サービス初期化完了', name: 'Main');
    } catch (e) {
      developer.log('通知サービス初期化エラー: $e', name: 'Main');
    }
  }

  // Web版では通知サービスを初期化しない
  if (!kIsWeb) {
    try {
      developer.log('TODO通知サービス初期化開始', name: 'Main');
      // グローバルナビゲーションキーを通知サービスにセット
      TodoNotificationService().setNavigatorKey(navigatorKey);
      TodoNotificationService().startNotificationService();
      developer.log('TODO通知サービス初期化完了', name: 'Main');
    } catch (e) {
      developer.log('TODO通知サービス初期化エラー: $e', name: 'Main');
    }
  }

  try {
    developer.log('AutoSyncService初期化開始', name: 'Main');
    // AutoSyncServiceを初期化
    await AutoSyncService.initialize();
    developer.log('AutoSyncService初期化完了', name: 'Main');
  } catch (e) {
    developer.log('AutoSyncService初期化エラー: $e', name: 'Main');
  }

  try {
    developer.log('セキュリティ監視サービス初期化開始', name: 'Main');
    // セキュリティ監視を開始
    await SecurityMonitorService.startMonitoring();
    developer.log('セキュリティ監視サービス初期化完了', name: 'Main');
  } catch (e) {
    developer.log('セキュリティ監視サービス初期化エラー: $e', name: 'Main');
  }

  try {
    developer.log('生体認証サービス初期化開始', name: 'Main');
    // 生体認証サービスを初期化
    await BiometricAuthService.initialize();
    developer.log('生体認証サービス初期化完了', name: 'Main');
  } catch (e) {
    developer.log('生体認証サービス初期化エラー: $e', name: 'Main');
  }

  try {
    developer.log('暗号化ローカルストレージサービス初期化開始', name: 'Main');
    // 暗号化ローカルストレージサービスを初期化
    await EncryptedLocalStorageService.initialize();
    developer.log('暗号化ローカルストレージサービス初期化完了', name: 'Main');
  } catch (e) {
    developer.log('暗号化ローカルストレージサービス初期化エラー: $e', name: 'Main');
  }

  try {
    developer.log('ネットワークセキュリティサービス初期化開始', name: 'Main');
    // ネットワークセキュリティサービスを初期化
    await NetworkSecurityService.initialize();
    developer.log('ネットワークセキュリティサービス初期化完了', name: 'Main');
  } catch (e) {
    developer.log('ネットワークセキュリティサービス初期化エラー: $e', name: 'Main');
  }

  try {
    developer.log('セッション管理サービス初期化開始', name: 'Main');
    // セッション管理サービスを初期化
    await SessionManagementService.initialize();
    developer.log('セッション管理サービス初期化完了', name: 'Main');
  } catch (e) {
    developer.log('セッション管理サービス初期化エラー: $e', name: 'Main');
  }

  // アプリ終了時のクリーンアップを設定
  WidgetsBinding.instance.addObserver(
    LifecycleEventHandler(
      detachedCallBack: () async {
        // アプリ終了時のリソース解放
        if (!kIsWeb) {
          TodoNotificationService().stopNotificationService();
        }
        AutoSyncService.dispose();
        SecurityMonitorService.stopMonitoring();
        SessionManagementService.stopMonitoring();
      },
    ),
  );

  // Web版では広告を初期化しない
  if (!kIsWeb) {
    try {
      developer.log('広告初期化開始', name: 'Main');
      await MobileAds.instance.initialize();
      developer.log('広告初期化完了', name: 'Main');
    } catch (e) {
      developer.log('広告初期化エラー: $e', name: 'Main');
    }
  }

  developer.log('アプリ起動準備完了', name: 'Main');

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
      child: WorkAssignmentApp(), // 下でMaterialAppにnavigatorKeyを渡す
    ),
  );
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
