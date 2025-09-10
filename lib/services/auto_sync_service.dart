import 'package:firebase_auth/firebase_auth.dart';
import 'group_data_sync_service.dart';
import 'group_firestore_service.dart';
import 'gamification_firestore_service.dart';
import 'dart:async'; // Timerを追加
import 'dart:developer' as developer;

class AutoSyncService {
  static Timer? _syncTimer;
  static bool _isInitialized = false;
  static bool _isSyncing = false;
  static bool _isDisabled = false; // 同期を一時的に無効化するフラグ
  static DateTime? _lastSyncTime;
  static const Duration _syncCooldown = Duration(minutes: 1); // 1分間のクールダウン
  static const String _logName = 'AutoSyncService';
  static void _logInfo(String message) =>
      developer.log(message, name: _logName);
  static void _logWarn(String message) =>
      developer.log(message, name: _logName);
  static void _logError(
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) => developer.log(
    message,
    name: _logName,
    error: error,
    stackTrace: stackTrace,
  );

  /// 自動同期サービスを初期化
  static Future<void> initialize() async {
    if (_isInitialized) {
      _logInfo('既に初期化済みです');
      return;
    }

    _logInfo('初期化開始');
    _isInitialized = true;

    // 初回同期はスキップ（グループ作成直後は重すぎるため）
    // 代わりに定期的な同期のみ開始
    _syncTimer = Timer.periodic(Duration(minutes: 5), (timer) async {
      await _performSync();
    });

    _logInfo('初期化完了（初回同期はスキップ）');
  }

  static Future<void> _performSync() async {
    if (_isSyncing) {
      _logInfo('既に同期中です');
      return;
    }

    if (_isDisabled) {
      _logInfo('同期が一時的に無効化されています');
      return;
    }

    _isSyncing = true;
    try {
      _logInfo('同期開始');

      // タイムアウト付きで同期を実行
      await _performSyncInternal().timeout(
        Duration(seconds: 30),
        onTimeout: () {
          _logWarn('同期がタイムアウトしました');
          throw TimeoutException('同期がタイムアウトしました');
        },
      );

      _lastSyncTime = DateTime.now();
      _logInfo('自動同期が完了しました');
    } catch (e, st) {
      _logError('同期エラー', e, st);
    } finally {
      _isSyncing = false;
    }
  }

  static Future<void> _performSyncInternal() async {
    // ユーザーがログインしているかチェック
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _logInfo('ユーザーがログインしていません');
      return;
    }
    _logInfo('ユーザーID: ${user.uid}');

    // グループに参加しているかチェック
    final groups = await GroupFirestoreService.getUserGroups();
    if (groups.isEmpty) {
      _logInfo('グループに参加していません');
      return;
    }
    _logInfo('参加グループ数: ${groups.length}');

    // 現在のグループを取得
    final currentGroup = groups.first; // 最初のグループを使用（複数グループ対応は後で実装）
    _logInfo('現在のグループ: ${currentGroup.name} (${currentGroup.id})');

    _logInfo('データ同期は全メンバーで可能です');

    // データ同期を実行（新しいデータを優先）
    _logInfo('グループへのデータ同期を開始（新しいデータを優先）');
    await GroupDataSyncService.syncAllDataToGroup(currentGroup.id);
    _logInfo('ローカルへのデータ同期を開始（新しいデータを優先）');
    await GroupDataSyncService.applyGroupDataToLocal(currentGroup.id);
  }

  /// 同期を一時的に無効化
  static void disableSync() {
    _isDisabled = true;
    _logInfo('同期を一時的に無効化しました');
  }

  /// 同期を有効化
  static void enableSync() {
    _isDisabled = false;
    _logInfo('同期を有効化しました');
  }

  /// 特定のデータタイプの変更時に自動同期を実行
  static Future<void> triggerAutoSyncForDataType(String dataType) async {
    _logInfo('triggerAutoSyncForDataType が呼び出されました: $dataType');
    _logInfo('_isInitialized: $_isInitialized');
    _logInfo('_isSyncing: $_isSyncing');

    if (!_isInitialized) {
      _logInfo('初期化されていません - 早期リターン');
      return;
    }
    if (_isSyncing) {
      _logInfo('既に同期中です - 早期リターン');
      return;
    }

    // クールダウンチェック
    if (_lastSyncTime != null) {
      final timeSinceLastSync = DateTime.now().difference(_lastSyncTime!);
      if (timeSinceLastSync < _syncCooldown) {
        _logInfo(
          'クールダウン中です (${_syncCooldown.inSeconds - timeSinceLastSync.inSeconds}秒後)',
        );
        return;
      }
    }

    _isSyncing = true;
    _logInfo('$dataType の自動同期を開始します');

    try {
      // ユーザーがログインしているかチェック
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _logInfo('ユーザーがログインしていません');
        return;
      }

      // グループに参加しているかチェック
      final groups = await GroupFirestoreService.getUserGroups();
      if (groups.isEmpty) {
        _logInfo('グループに参加していません');
        return;
      }

      // 現在のグループを取得
      final currentGroup = groups.first;

      _logInfo('データ同期は全メンバーで可能です (triggerAutoSyncForDataType)');

      // データタイプに応じた同期を実行
      if (dataType == 'gamification') {
        // ゲーミフィケーション専用同期
        await GamificationFirestoreService.syncGamificationData();
      } else {
        // 全データ同期を実行
        await GroupDataSyncService.syncAllDataToGroup(currentGroup.id);
        await GroupDataSyncService.applyGroupDataToLocal(currentGroup.id);
      }

      _lastSyncTime = DateTime.now();
      _logInfo('$dataType の自動同期が完了しました');
    } catch (e, st) {
      _logError('$dataType の自動同期に失敗しました', e, st);
    } finally {
      _isSyncing = false;
    }
  }

  /// 自動同期サービスを停止
  static void dispose() {
    _logInfo('リソース解放開始');
    _syncTimer?.cancel();
    _syncTimer = null;
    _isInitialized = false;
    _isSyncing = false;
    _logInfo('リソース解放完了');
  }

  /// ゲーミフィケーション専用の軽量同期
  static Future<void> triggerGamificationSync() async {
    if (!_isInitialized) {
      _logInfo('初期化されていません');
      return;
    }

    // ユーザーがログインしているかチェック
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _logInfo('ユーザーがログインしていません');
      return;
    }

    try {
      _logInfo('ゲーミフィケーション同期を開始します');
      await GamificationFirestoreService.syncGamificationData();
      _logInfo('ゲーミフィケーション同期が完了しました');
    } catch (e, st) {
      _logError('ゲーミフィケーション同期に失敗しました', e, st);
    }
  }

  /// 同期状態を取得
  static bool get isSyncing => _isSyncing;
  static DateTime? get lastSyncTime => _lastSyncTime;
  static bool get isInitialized => _isInitialized;
}
