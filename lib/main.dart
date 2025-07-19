import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'models/roast_schedule_form_provider.dart';
import 'package:firebase_core/firebase_core.dart';
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
import 'package:google_mobile_ads/google_mobile_ads.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 画面を縦向きに固定
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
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
      print('キーボードイベントエラーを無視: ${details.exception}');
      return;
    }

    // オーバーフローエラーを非表示にする
    if (details.exception is FlutterError &&
        details.exception.toString().contains('overflowed')) {
      // オーバーフローエラーは無視
      return;
    }

    // その他のエラーは通常通り処理
    FlutterError.presentError(details);
  };

  await Firebase.initializeApp();
  await initializeDateFormatting('ja_JP', null);
  final themeSettings = await ThemeSettings.load();

  // 初期インストール時にデフォルトテーマを適用
  await themeSettings.initializeDefaultTheme();

  // 焙煎タイマー通知サービスを初期化
  await RoastTimerNotificationService.initialize();

  // 通知権限をリクエスト
  await RoastTimerNotificationService.requestPermissions();

  // 古い設定データの移行処理
  await _migrateOldSoundSettings();

  // グローバルナビゲーションキーを通知サービスにセット
  TodoNotificationService().setNavigatorKey(navigatorKey);

  // TODO通知サービスを開始
  TodoNotificationService().startNotificationService();

  // アプリ終了時のクリーンアップを設定
  WidgetsBinding.instance.addObserver(
    LifecycleEventHandler(
      detachedCallBack: () async {
        // アプリ終了時のリソース解放
        TodoNotificationService().stopNotificationService();
        AutoSyncService.dispose();
      },
    ),
  );

  await MobileAds.instance.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RoastScheduleFormProvider()),
        ChangeNotifierProvider<ThemeSettings>.value(value: themeSettings),
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

/// 古い音声設定データを新しい形式に移行
Future<void> _migrateOldSoundSettings() async {
  final prefs = await SharedPreferences.getInstance();

  // タイマー音の移行
  final oldTimerSound = prefs.getString('selected_timer_sound');
  if (oldTimerSound != null && !oldTimerSound.startsWith('sounds/')) {
    final newTimerSound = 'sounds/$oldTimerSound';
    await prefs.setString('selected_timer_sound', newTimerSound);
    print('タイマー音設定を移行しました: $oldTimerSound -> $newTimerSound');
  }

  // 通知音の移行
  final oldNotificationSound = prefs.getString('selected_notification_sound');
  if (oldNotificationSound != null &&
      !oldNotificationSound.startsWith('sounds/')) {
    final newNotificationSound = 'sounds/$oldNotificationSound';
    await prefs.setString('selected_notification_sound', newNotificationSound);
    print('通知音設定を移行しました: $oldNotificationSound -> $newNotificationSound');
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
          print('システムUI設定エラー: $e');
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
