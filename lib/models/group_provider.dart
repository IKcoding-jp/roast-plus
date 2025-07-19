import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'group_models.dart';
import '../services/group_firestore_service.dart';
import '../services/group_data_sync_service.dart';
import '../services/auto_sync_service.dart';
import '../services/group_statistics_service.dart';

class GroupProvider extends ChangeNotifier {
  List<Group> _groups = [];
  List<GroupInvitation> _invitations = [];
  Group? _currentGroup;
  bool _loading = false;
  String? _error;
  bool _isWatchingGroupData = false;
  final Map<String, Map<String, dynamic>> _groupStatistics = {};
  final GroupStatisticsService _statisticsService = GroupStatisticsService();
  final Map<String, StreamSubscription<DocumentSnapshot>> _groupWatchers = {};

  // Getters
  List<Group> get groups => _groups;
  List<GroupInvitation> get invitations => _invitations;
  Group? get currentGroup => _currentGroup;
  bool get loading => _loading;
  bool get isWatchingGroupData => _isWatchingGroupData;
  String? get error => _error;
  Map<String, Map<String, dynamic>> get groupStatistics => _groupStatistics;

  // 単一グループ対応のための追加getter
  bool get hasGroup => _currentGroup != null;
  Group? get singleGroup => _currentGroup;

  /// ユーザーが参加しているグループを取得（単一グループ対応）
  Future<void> loadUserGroups() async {
    _setLoading(true);
    _clearError();

    try {
      _groups = await GroupFirestoreService.getUserGroups();
      print('GroupProvider: グループ読み込み完了 - グループ数: ${_groups.length}');

      // 単一グループ制限: 最初のグループのみをcurrentGroupに設定
      if (_groups.isNotEmpty) {
        _currentGroup = _groups.first;
        print('GroupProvider: currentGroupを設定: ${_currentGroup!.name}');

        // AutoSyncServiceの初期化
        print('GroupProvider: AutoSyncServiceの初期化を開始');
        await _initializeAutoSyncService();
      } else {
        _currentGroup = null;
      }

      _safeNotifyListeners();
    } catch (e) {
      if (e.toString().contains('未ログイン')) {
        _setError('ログインすることで、グループ機能を使うことができます');
      } else {
        _setError('グループの取得に失敗しました: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  /// AutoSyncServiceを初期化
  Future<void> _initializeAutoSyncService() async {
    try {
      // AutoSyncServiceをインポートして初期化
      await _initializeAutoSync();
      print('GroupProvider: AutoSyncServiceの初期化完了');
    } catch (e) {
      print('GroupProvider: AutoSyncServiceの初期化に失敗: $e');
    }
  }

  /// AutoSyncServiceの初期化
  Future<void> _initializeAutoSync() async {
    // AutoSyncServiceを初期化
    await AutoSyncService.initialize();
  }

  /// 招待一覧を取得
  Future<void> loadInvitations() async {
    _setLoading(true);
    _clearError();

    try {
      _invitations = await GroupFirestoreService.getUserInvitations();
      _safeNotifyListeners();
    } catch (e) {
      if (e.toString().contains('未ログイン')) {
        _setError('ログインすることで、グループ機能を使うことができます');
      } else {
        _setError('招待の取得に失敗しました: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  /// グループを作成（単一グループ制限）
  Future<bool> createGroup({
    required String name,
    required String description,
  }) async {
    // 既にグループに参加している場合は作成を拒否
    if (_currentGroup != null) {
      _setError('既にグループに参加しています。1つのグループのみ参加可能です。');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      final newGroup = await GroupFirestoreService.createGroup(
        name: name,
        description: description,
      );
      _groups.clear(); // 他のグループがあれば削除
      _groups.add(newGroup);
      _currentGroup = newGroup; // 新しいグループをcurrentGroupに設定
      _safeNotifyListeners();
      return true;
    } catch (e) {
      if (e.toString().contains('未ログイン')) {
        _setError('ログインすることで、グループ機能を使うことができます');
      } else {
        _setError('グループの作成に失敗しました: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// グループを更新
  Future<bool> updateGroup(Group group) async {
    _setLoading(true);
    _clearError();

    try {
      await GroupFirestoreService.updateGroup(group);

      // ローカルのグループリストを更新
      final index = _groups.indexWhere((g) => g.id == group.id);
      if (index != -1) {
        _groups[index] = group;
        _safeNotifyListeners();
      }

      return true;
    } catch (e) {
      if (e.toString().contains('未ログイン')) {
        _setError('ログインすることで、グループ機能を使うことができます');
      } else {
        _setError('グループの更新に失敗しました: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// グループを削除
  Future<bool> deleteGroup(String groupId) async {
    _setLoading(true);
    _clearError();

    try {
      await GroupFirestoreService.deleteGroup(groupId);

      // ローカルのグループリストから削除
      _groups.removeWhere((g) => g.id == groupId);

      // 現在のグループが削除された場合、nullに設定
      if (_currentGroup?.id == groupId) {
        _currentGroup = null;
      }

      _safeNotifyListeners();
      return true;
    } catch (e) {
      if (e.toString().contains('未ログイン')) {
        _setError('ログインすることで、グループ機能を使うことができます');
      } else {
        _setError('グループの削除に失敗しました: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// メンバーを招待
  Future<bool> inviteMember({
    required String groupId,
    required String email,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await GroupFirestoreService.inviteMember(
        groupId: groupId,
        invitedEmail: email,
      );
      return true;
    } catch (e) {
      if (e.toString().contains('未ログイン')) {
        _setError('ログインすることで、グループ機能を使うことができます');
      } else {
        _setError('メンバーの招待に失敗しました: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 招待を承諾（単一グループ制限）
  Future<bool> acceptInvitation(String invitationId) async {
    // 既にグループに参加している場合は承諾を拒否
    if (_currentGroup != null) {
      _setError('既にグループに参加しています。1つのグループのみ参加可能です。');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      await GroupFirestoreService.acceptInvitation(invitationId);

      // 招待リストから削除
      _invitations.removeWhere((inv) => inv.id == invitationId);

      // グループリストを再読み込み
      await loadUserGroups();

      _safeNotifyListeners();
      return true;
    } catch (e) {
      if (e.toString().contains('未ログイン')) {
        _setError('ログインすることで、グループ機能を使うことができます');
      } else {
        _setError('招待の承諾に失敗しました: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 招待コードでグループに参加（単一グループ制限）
  Future<bool> joinGroupByInviteCode(String inviteCode) async {
    // 既にグループに参加している場合は参加を拒否
    if (_currentGroup != null) {
      _setError('既にグループに参加しています。1つのグループのみ参加可能です。');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      await GroupFirestoreService.joinGroupByInviteCode(inviteCode);

      // グループリストを再読み込み
      await loadUserGroups();

      _safeNotifyListeners();
      return true;
    } catch (e) {
      if (e.toString().contains('未ログイン')) {
        _setError('ログインすることで、グループ機能を使うことができます');
      } else {
        _setError('グループの参加に失敗しました: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 招待を拒否
  Future<bool> declineInvitation(String invitationId) async {
    _setLoading(true);
    _clearError();

    try {
      await GroupFirestoreService.declineInvitation(invitationId);

      // 招待リストから削除
      _invitations.removeWhere((inv) => inv.id == invitationId);
      _safeNotifyListeners();

      return true;
    } catch (e) {
      if (e.toString().contains('未ログイン')) {
        _setError('ログインすることで、グループ機能を使うことができます');
      } else {
        _setError('招待の拒否に失敗しました: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// メンバーを削除
  Future<bool> removeMember({
    required String groupId,
    required String memberUid,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await GroupFirestoreService.removeMember(
        groupId: groupId,
        memberUid: memberUid,
      );

      // グループ情報を再読み込み
      await loadUserGroups();

      return true;
    } catch (e) {
      if (e.toString().contains('未ログイン')) {
        _setError('ログインすることで、グループ機能を使うことができます');
      } else {
        _setError('メンバーの削除に失敗しました: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// メンバーの権限を変更
  Future<bool> changeMemberRole({
    required String groupId,
    required String memberUid,
    required GroupRole newRole,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await GroupFirestoreService.changeMemberRole(
        groupId: groupId,
        memberUid: memberUid,
        newRole: newRole,
      );

      // グループ情報を再読み込み
      await loadUserGroups();

      return true;
    } catch (e) {
      if (e.toString().contains('未ログイン')) {
        _setError('ログインすることで、グループ機能を使うことができます');
      } else {
        _setError('権限の変更に失敗しました: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// グループから脱退（単一グループ対応）
  Future<bool> leaveGroup(String groupId) async {
    _setLoading(true);
    _clearError();

    try {
      await GroupFirestoreService.leaveGroup(groupId);

      // ローカルのグループリストから削除
      _groups.removeWhere((g) => g.id == groupId);

      // 現在のグループが脱退した場合、nullに設定
      if (_currentGroup?.id == groupId) {
        _currentGroup = null;
      }

      _safeNotifyListeners();
      return true;
    } catch (e) {
      if (e.toString().contains('未ログイン')) {
        _setError('ログインすることで、グループ機能を使うことができます');
      } else {
        _setError('グループからの脱退に失敗しました: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 現在のグループを設定
  void setCurrentGroup(Group? group) {
    _currentGroup = group;
    _safeNotifyListeners();
  }

  /// 指定されたグループを取得
  Group? getGroupById(String groupId) {
    try {
      return _groups.firstWhere((g) => g.id == groupId);
    } catch (e) {
      return null;
    }
  }

  /// 現在のユーザーが指定されたグループのリーダーかどうかをチェック
  bool isCurrentUserLeader(String groupId) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    final group = getGroupById(groupId);
    if (group == null) return false;

    return group.isLeader(currentUser.uid);
  }

  /// 現在のユーザーがcurrentGroupのリーダーかどうかをチェック（単一グループ対応）
  bool isCurrentUserLeaderOfCurrentGroup() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _currentGroup == null) return false;

    return _currentGroup!.isLeader(currentUser.uid);
  }

  /// 現在のユーザーが指定されたグループのメンバーかどうかをチェック
  bool isCurrentUserMember(String groupId) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    final group = getGroupById(groupId);
    if (group == null) return false;

    return group.isMember(currentUser.uid);
  }

  /// 現在のユーザーがcurrentGroupのメンバーかどうかをチェック（単一グループ対応）
  bool isCurrentUserMemberOfCurrentGroup() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _currentGroup == null) return false;

    return _currentGroup!.isMember(currentUser.uid);
  }

  /// グループのデータを同期
  Future<bool> syncGroupData({
    required String groupId,
    required String dataType,
    required Map<String, dynamic> data,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await GroupFirestoreService.syncGroupData(
        groupId: groupId,
        dataType: dataType,
        data: data,
      );
      return true;
    } catch (e) {
      if (e.toString().contains('未ログイン')) {
        _setError('ログインすることで、グループ機能を使うことができます');
      } else {
        _setError('データの同期に失敗しました: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// グループの共有データを取得
  Future<Map<String, dynamic>?> getGroupData({
    required String groupId,
    required String dataType,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      return await GroupFirestoreService.getGroupData(
        groupId: groupId,
        dataType: dataType,
      );
    } catch (e) {
      if (e.toString().contains('未ログイン')) {
        _setError('ログインすることで、グループ機能を使うことができます');
      } else {
        _setError('データの取得に失敗しました: $e');
      }
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// グループの共有データの変更を監視
  Stream<Map<String, dynamic>?> watchGroupData({
    required String groupId,
    required String dataType,
  }) {
    return GroupFirestoreService.watchGroupData(
      groupId: groupId,
      dataType: dataType,
    );
  }

  /// Firestoreのグループドキュメントをリアルタイム監視し、変更があれば即時反映
  void watchGroup(String groupId) {
    if (_groupWatchers.containsKey(groupId)) return;
    final sub = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .snapshots()
        .listen((doc) {
          if (doc.exists) {
            final updated = Group.fromJson(doc.data()!);
            final idx = _groups.indexWhere((g) => g.id == groupId);
            if (idx != -1) {
              _groups[idx] = updated;
            } else {
              _groups.add(updated);
            }
            if (_currentGroup?.id == groupId) {
              _currentGroup = updated;
            }
            notifyListeners();
          }
        });
    _groupWatchers[groupId] = sub;
  }

  /// Firestoreのグループ監視を解除
  void unwatchGroup(String groupId) {
    _groupWatchers[groupId]?.cancel();
    _groupWatchers.remove(groupId);
  }

  @override
  void dispose() {
    for (final sub in _groupWatchers.values) {
      sub.cancel();
    }
    _groupWatchers.clear();
    super.dispose();
  }

  // Private methods
  void _setLoading(bool loading) {
    _loading = loading;
    _safeNotifyListeners();
  }

  void _setError(String error) {
    _error = error;
    _safeNotifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  /// エラーをクリア
  void clearError() {
    _clearError();
  }

  /// 安全にnotifyListenersを呼び出す
  void _safeNotifyListeners() {
    try {
      notifyListeners();
    } catch (e) {
      // ウィジェットツリーがロックされている場合は無視
      if (e.toString().contains('widget tree was locked') ||
          e.toString().contains(
            'markNeedsBuild() called when widget tree was locked',
          )) {
        print('GroupProvider: ウィジェットツリーがロックされているため、notifyListenersをスキップしました');
        return;
      }
      // その他のエラーの場合は再スロー
      rethrow;
    }
  }

  /// 全データをリフレッシュ
  Future<void> refresh() async {
    await Future.wait([loadUserGroups(), loadInvitations()]);
  }

  /// 現在のユーザーの権限を取得
  GroupRole? getCurrentUserRole() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    if (_currentGroup == null) return null;

    return _currentGroup!.getMemberRole(currentUser.uid);
  }

  /// 現在のグループの設定を取得（単一グループ対応）
  GroupSettings? getCurrentGroupSettings() {
    if (_currentGroup == null) {
      print('GroupProvider: currentGroupがnullのため設定を取得できません');
      return null;
    }

    try {
      print('GroupProvider: グループ設定を取得中 - グループID: ${_currentGroup!.id}');
      print('GroupProvider: グループ設定データ: ${_currentGroup!.settings}');
      print(
        'GroupProvider: グループ設定データの型: ${_currentGroup!.settings.runtimeType}',
      );

      // 設定が存在しない場合はデフォルト設定を使用
      if (_currentGroup!.settings.isEmpty) {
        print('GroupProvider: 設定が空のためデフォルト設定を使用');
        return GroupSettings.defaultSettings();
      }

      final settings = GroupSettings.fromJson(_currentGroup!.settings);
      print('GroupProvider: グループ設定取得成功: $settings');
      print('GroupProvider: データ権限設定: ${settings.dataPermissions}');
      return settings;
    } catch (e) {
      print('GroupProvider: グループ設定の取得に失敗: $e');
      print('GroupProvider: エラーの詳細: ${e.toString()}');
      print('GroupProvider: デフォルト設定を使用');
      return GroupSettings.defaultSettings();
    }
  }

  // グループデータの監視を開始
  void startWatchingGroupData() {
    if (isWatchingGroupData) {
      print('GroupProvider: 既にグループデータを監視中です');
      return;
    }

    print('GroupProvider: グループデータ監視開始');
    _isWatchingGroupData = true;

    // 遅延してnotifyListenersを呼び出す
    Future.microtask(() {
      _safeNotifyListeners();
    });
  }

  // グループデータの監視を停止
  void stopWatchingGroupData() {
    if (!isWatchingGroupData) {
      print('GroupProvider: グループデータ監視は既に停止中です');
      return;
    }

    print('GroupProvider: グループデータ監視停止');
    _isWatchingGroupData = false;

    // 遅延してnotifyListenersを呼び出す
    Future.microtask(() {
      _safeNotifyListeners();
    });
  }

  /// グループデータをローカルに適用（単一グループ対応）
  Future<void> applyGroupDataToLocal() async {
    if (_currentGroup == null) return;

    try {
      print('GroupProvider: グループデータをローカルに適用開始');
      await GroupDataSyncService.applyGroupDataToLocal(_currentGroup!.id);
      print('GroupProvider: グループデータをローカルに適用完了');
      _safeNotifyListeners();
    } catch (e) {
      print('GroupProvider: グループデータの適用に失敗: $e');
    }
  }

  /// 本日のスケジュールをローカルに適用
  void _applyTodayScheduleToLocal(Map<String, dynamic> data) {
    try {
      print('GroupProvider: 本日のスケジュールをローカルに適用: $data');

      // Firestoreに直接保存してローカルデータを更新
      final labels = data['labels'] as List<dynamic>?;
      final contents = data['contents'] as Map<String, dynamic>?;
      final currentUser = FirebaseAuth.instance.currentUser;
      if (labels != null && currentUser != null) {
        final today = DateTime.now();
        final docId =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

        FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('todaySchedule')
            .doc(docId)
            .set({
              'labels': labels,
              'contents': contents ?? {},
              'savedAt': DateTime.now().toIso8601String(),
            });
        print('GroupProvider: 本日のスケジュールをFirestoreに保存しました');
      }
    } catch (e) {
      print('GroupProvider: 本日のスケジュール適用エラー: $e');
    }
  }

  /// 時間ラベルをローカルに適用
  void _applyTimeLabelsToLocal(Map<String, dynamic> data) {
    try {
      print('GroupProvider: 時間ラベルをローカルに適用: $data');

      // Firestoreに直接保存してローカルデータを更新
      final labels = data['labels'] as List<dynamic>?;
      final currentUser = FirebaseAuth.instance.currentUser;
      if (labels != null && currentUser != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('labels')
            .doc('timeLabels')
            .set({
              'labels': labels,
              'savedAt': DateTime.now().toIso8601String(),
            });
        print('GroupProvider: 時間ラベルをFirestoreに保存しました');
      }
    } catch (e) {
      print('GroupProvider: 時間ラベル適用エラー: $e');
    }
  }

  /// TODOリストをローカルに適用
  void _applyTodoListToLocal(Map<String, dynamic> data) {
    try {
      print('GroupProvider: TODOリストをローカルに適用: $data');
      // ここでローカルデータを更新する処理を実装
      // 実際の実装は各ページで行うため、通知のみ
    } catch (e) {
      print('GroupProvider: TODOリスト適用エラー: $e');
    }
  }

  /// グループの統計情報を取得
  Future<void> loadGroupStatistics(String groupId) async {
    try {
      final statistics = await _statisticsService.getGroupStatistics(groupId);
      _groupStatistics[groupId] = statistics;
      _safeNotifyListeners();
    } catch (e) {
      print('GroupProvider: 統計情報の取得に失敗: $e');
      // エラーの場合はデフォルト値を設定
      _groupStatistics[groupId] = {
        'todayRoastCount': 0,
        'thisWeekActivityCount': 0,
        'totalRoastTime': 0.0,
      };
      _safeNotifyListeners();
    }
  }

  /// 特定のグループの統計情報を取得
  Map<String, dynamic>? getGroupStatistics(String groupId) {
    return _groupStatistics[groupId];
  }

  /// すべてのグループの統計情報を取得（単一グループ対応）
  Future<void> loadAllGroupStatistics() async {
    if (_currentGroup != null) {
      await loadGroupStatistics(_currentGroup!.id);
    }
  }
}
