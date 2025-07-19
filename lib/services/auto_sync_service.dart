import 'package:firebase_auth/firebase_auth.dart';
import 'group_data_sync_service.dart';
import 'group_firestore_service.dart';
import 'gamification_firestore_service.dart';
import '../models/group_models.dart';
import 'dart:async'; // Timerを追加

class AutoSyncService {
  static Timer? _syncTimer;
  static bool _isInitialized = false;
  static bool _isSyncing = false;
  static DateTime? _lastSyncTime;
  static const Duration _syncCooldown = Duration(minutes: 1); // 1分間のクールダウン

  /// 自動同期サービスを初期化
  static Future<void> initialize() async {
    if (_isInitialized) {
      print('AutoSyncService: 既に初期化済みです');
      return;
    }

    print('AutoSyncService: 初期化開始');
    _isInitialized = true;

    // 初回同期はスキップ（グループ作成直後は重すぎるため）
    // 代わりに定期的な同期のみ開始
    _syncTimer = Timer.periodic(Duration(minutes: 5), (timer) async {
      await _performSync();
    });

    print('AutoSyncService: 初期化完了（初回同期はスキップ）');
  }

  static Future<void> _performSync() async {
    if (_isSyncing) {
      print('AutoSyncService: 既に同期中です');
      return;
    }

    _isSyncing = true;
    try {
      print('AutoSyncService: 同期開始');

      // タイムアウト付きで同期を実行
      await _performSyncInternal().timeout(
        Duration(seconds: 30),
        onTimeout: () {
          print('AutoSyncService: 同期がタイムアウトしました');
          throw TimeoutException('同期がタイムアウトしました');
        },
      );

      _lastSyncTime = DateTime.now();
      print('AutoSyncService: 自動同期が完了しました');
    } catch (e) {
      print('AutoSyncService: 同期エラー: $e');
    } finally {
      _isSyncing = false;
    }
  }

  static Future<void> _performSyncInternal() async {
    // ユーザーがログインしているかチェック
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('AutoSyncService: ユーザーがログインしていません');
      return;
    }
    print('AutoSyncService: ユーザーID: ${user.uid}');

    // グループに参加しているかチェック
    final groups = await GroupFirestoreService.getUserGroups();
    if (groups.isEmpty) {
      print('AutoSyncService: グループに参加していません');
      return;
    }
    print('AutoSyncService: 参加グループ数: ${groups.length}');

    // 現在のグループを取得
    final currentGroup = groups.first; // 最初のグループを使用（複数グループ対応は後で実装）
    print(
      'AutoSyncService: 現在のグループ: ${currentGroup.name} (${currentGroup.id})',
    );

    // グループ設定を取得して同期権限をチェック
    final groupSettings = await GroupFirestoreService.getGroupSettings(
      currentGroup.id,
    );
    if (groupSettings != null && !groupSettings.allowMemberDataSync) {
      final memberRole = currentGroup.getMemberRole(user.uid);
      if (memberRole != GroupRole.leader && memberRole != GroupRole.admin) {
        print('AutoSyncService: データ同期の権限がありません - メンバーは同期できません');
        return;
      }
    }
    print('AutoSyncService: 同期権限チェック完了 - 同期可能');

    // データ同期を実行
    print('AutoSyncService: グループへのデータ同期を開始');
    await GroupDataSyncService.syncAllDataToGroup(currentGroup.id);
    print('AutoSyncService: ローカルへのデータ同期を開始');
    await GroupDataSyncService.applyGroupDataToLocal(currentGroup.id);
  }

  /// 特定のデータタイプの変更時に自動同期を実行
  static Future<void> triggerAutoSyncForDataType(String dataType) async {
    print('AutoSyncService: triggerAutoSyncForDataType が呼び出されました: $dataType');
    print('AutoSyncService: _isInitialized: $_isInitialized');
    print('AutoSyncService: _isSyncing: $_isSyncing');

    if (!_isInitialized) {
      print('AutoSyncService: 初期化されていません - 早期リターン');
      return;
    }
    if (_isSyncing) {
      print('AutoSyncService: 既に同期中です - 早期リターン');
      return;
    }

    // クールダウンチェック
    if (_lastSyncTime != null) {
      final timeSinceLastSync = DateTime.now().difference(_lastSyncTime!);
      if (timeSinceLastSync < _syncCooldown) {
        print(
          'AutoSyncService: クールダウン中です (${_syncCooldown.inSeconds - timeSinceLastSync.inSeconds}秒後)',
        );
        return;
      }
    }

    _isSyncing = true;
    print('AutoSyncService: $dataType の自動同期を開始します');

    try {
      // ユーザーがログインしているかチェック
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('AutoSyncService: ユーザーがログインしていません');
        return;
      }

      // グループに参加しているかチェック
      final groups = await GroupFirestoreService.getUserGroups();
      if (groups.isEmpty) {
        print('AutoSyncService: グループに参加していません');
        return;
      }

      // 現在のグループを取得
      final currentGroup = groups.first;

      // グループ設定を取得して同期権限をチェック
      final groupSettings = await GroupFirestoreService.getGroupSettings(
        currentGroup.id,
      );
      if (groupSettings != null && !groupSettings.allowMemberDataSync) {
        final memberRole = currentGroup.getMemberRole(user.uid);
        if (memberRole != GroupRole.leader && memberRole != GroupRole.admin) {
          print('AutoSyncService: データ同期の権限がありません - メンバーは同期できません');
          return;
        }
      }

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
      print('AutoSyncService: $dataType の自動同期が完了しました');
    } catch (e) {
      print('AutoSyncService: $dataType の自動同期に失敗しました: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// 自動同期サービスを停止
  static void dispose() {
    print('AutoSyncService: リソース解放開始');
    _syncTimer?.cancel();
    _syncTimer = null;
    _isInitialized = false;
    _isSyncing = false;
    print('AutoSyncService: リソース解放完了');
  }

  /// ゲーミフィケーション専用の軽量同期
  static Future<void> triggerGamificationSync() async {
    if (!_isInitialized) {
      print('AutoSyncService: 初期化されていません');
      return;
    }

    // ユーザーがログインしているかチェック
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('AutoSyncService: ユーザーがログインしていません');
      return;
    }

    try {
      print('AutoSyncService: ゲーミフィケーション同期を開始します');
      await GamificationFirestoreService.syncGamificationData();
      print('AutoSyncService: ゲーミフィケーション同期が完了しました');
    } catch (e) {
      print('AutoSyncService: ゲーミフィケーション同期に失敗しました: $e');
    }
  }

  /// 同期状態を取得
  static bool get isSyncing => _isSyncing;
  static DateTime? get lastSyncTime => _lastSyncTime;
  static bool get isInitialized => _isInitialized;
}
