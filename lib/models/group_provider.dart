import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'group_models.dart';
import 'group_gamification_models.dart';
import '../services/group_firestore_service.dart';
import '../services/group_data_sync_service.dart';
import '../services/group_statistics_service.dart';
import '../services/group_gamification_service.dart';
import '../services/user_settings_firestore_service.dart';
import '../services/assignment_firestore_service.dart';
import '../widgets/group_celebration_helper.dart';

class GroupProvider extends ChangeNotifier {
  List<Group> _groups = [];
  List<GroupInvitation> _invitations = [];
  Group? _currentGroup;
  bool _loading = false;
  bool _initialized = false;
  String? _error;
  bool _isWatchingGroupData = false;
  final Map<String, Map<String, dynamic>> _groupStatistics = {};
  final GroupStatisticsService _statisticsService = GroupStatisticsService();
  final Map<String, StreamSubscription<DocumentSnapshot>> _groupWatchers = {};

  // ゲーミフィケーション関連
  final Map<String, GroupGamificationProfile> _groupGamificationProfiles = {};
  final Map<String, StreamSubscription<GroupGamificationProfile>>
  _gamificationWatchers = {};

  // グループ設定監視
  final Map<String, StreamSubscription<GroupSettings?>> _groupSettingsWatchers =
      {};

  // グループ作成フラグ
  bool _showGroupCreationCelebration = false;
  String? _newlyCreatedGroupId;

  // グループ削除ページ表示フラグ
  bool _showGroupDeletedPage = false;
  bool get showGroupDeletedPage => _showGroupDeletedPage;

  GroupProvider() {
    // 初期化状態をリセット
    _initialized = false;
  }

  // Getters
  List<Group> get groups => _groups;
  List<GroupInvitation> get invitations => _invitations;
  Group? get currentGroup => _currentGroup;
  bool get loading => _loading;
  bool get initialized => _initialized;
  bool get isWatchingGroupData => _isWatchingGroupData;
  String? get error => _error;
  Map<String, Map<String, dynamic>> get groupStatistics => _groupStatistics;

  // ゲーミフィケーション関連のgetter
  Map<String, GroupGamificationProfile> get groupGamificationProfiles =>
      _groupGamificationProfiles;

  // 単一グループ対応のための追加getter
  bool get hasGroup {
    final hasGroup = _currentGroup != null;
    return hasGroup;
  }

  Group? get singleGroup => _currentGroup;

  // グループ作成フラグのgetter
  bool get showGroupCreationCelebration => _showGroupCreationCelebration;
  String? get newlyCreatedGroupId => _newlyCreatedGroupId;

  /// ユーザーが参加しているグループを取得（単一グループ対応）
  Future<void> loadUserGroups() async {
    // 既に読み込み中またはデータがある場合はスキップ
    if (_loading) {
      return;
    }

    if (_groups.isNotEmpty && _initialized) {
      return;
    }

    _setLoading(true);
    _clearError();

    try {
      // グループ読み込み開始

      // タイムアウト付きでグループ読み込みを実行
      _groups = await GroupFirestoreService.getUserGroups().timeout(
        Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException('グループ読み込みがタイムアウトしました');
        },
      );

      // 単一グループ制限: 最初のグループのみをcurrentGroupに設定
      if (_groups.isNotEmpty) {
        _currentGroup = _groups.first;

        // グループの監視を開始
        watchGroup(_currentGroup!.id);
      } else {
        _currentGroup = null;
      }

      // 初期化完了フラグを設定
      _initialized = true;
      _safeNotifyListeners();

      // グループ読み込み完了
    } catch (e) {
      // グループ読み込みエラー
      if (e.toString().contains('未ログイン')) {
        _setError('ログインすることで、グループ機能を使うことができます');
      } else if (e.toString().contains('タイムアウト')) {
        _setError('ネットワーク接続が不安定です。しばらく待ってから再試行してください。');
      } else {
        _setError('グループの取得に失敗しました: $e');
      }
      // エラーが発生しても初期化完了フラグを設定
      _initialized = true;
      _safeNotifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// グループ作成成功後の処理
  void _postGroupCreationSuccess(String groupId) {
    // グループ作成成功後の処理開始
    // グループ作成直後は処理をスキップ（クラッシュ防止のため）
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
      // グループ作成開始
      developer.log('グループ作成開始', name: 'GroupProvider');

      // グループ削除フラグをリセット
      _showGroupDeletedPage = false;

      final newGroup = await GroupFirestoreService.createGroup(
        name: name,
        description: description,
      );

      // Firestoreでのグループ作成完了
      developer.log('Firestoreでのグループ作成完了', name: 'GroupProvider');

      _groups.clear(); // 他のグループがあれば削除
      _groups.add(newGroup);
      _currentGroup = newGroup; // 新しいグループをcurrentGroupに設定

      // 初期化完了フラグを設定（重要：Web版での永続化を確実にするため）
      _initialized = true;

      // ローカル状態の更新完了
      developer.log('ローカル状態の更新完了', name: 'GroupProvider');

      // グループ作成フラグを設定
      _showGroupCreationCelebration = true;
      _newlyCreatedGroupId = newGroup.id;

      _safeNotifyListeners();
      // グループ作成完了
      developer.log('グループ作成完了', name: 'GroupProvider');

      // Web版では追加の待機時間を設けてFirestoreの同期を確実にする
      if (kIsWeb) {
        developer.log('Web版: Firestore同期のため待機中', name: 'GroupProvider');
        await Future.delayed(Duration(milliseconds: 500));
        developer.log('Web版: 待機完了', name: 'GroupProvider');
      }

      // グループ作成成功後の処理を非同期で実行（軽量化）
      _postGroupCreationSuccess(newGroup.id);

      return true;
    } catch (e) {
      // グループ作成エラー
      developer.log('グループ作成エラー: $e', name: 'GroupProvider');
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
      }

      // 現在のグループが更新された場合、currentGroupも更新
      if (_currentGroup?.id == group.id) {
        _currentGroup = group;
      }

      _safeNotifyListeners();
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

        // グループ削除ページ表示フラグを設定
        _showGroupDeletedPage = true;
        // グループ削除フラグを設定
      }

      // ローカルデータをクリア
      await _clearLocalData();

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

  /// ローカルデータをクリア
  Future<void> _clearLocalData() async {
    try {
      // ドリップパック記録をクリア
      await UserSettingsFirestoreService.deleteSetting('dripPackRecords');

      // 本日のスケジュールをクリア
      await UserSettingsFirestoreService.deleteSetting('todaySchedule_labels');
      await UserSettingsFirestoreService.deleteSetting(
        'todaySchedule_contents',
      );

      // 担当表のメンバーデータをクリア
      await UserSettingsFirestoreService.deleteSetting('teams');
      await UserSettingsFirestoreService.deleteSetting('leftLabels');
      await UserSettingsFirestoreService.deleteSetting('rightLabels');
      await UserSettingsFirestoreService.deleteSetting('assignment_team_a');
      await UserSettingsFirestoreService.deleteSetting('assignment_team_b');

      // 担当表のFirestoreデータもクリア
      try {
        await AssignmentFirestoreService.clearAssignmentMembers();
      } catch (e) {
        // 担当表データのクリアに失敗しても続行
      }

      // その他のローカルデータも必要に応じてクリア
      // 例: 焙煎記録、試飲記録など

      // ローカルデータをクリア完了
    } catch (e) {
      // ローカルデータのクリアに失敗
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
      // グループ削除フラグをリセット
      _showGroupDeletedPage = false;

      await GroupFirestoreService.acceptInvitation(invitationId);

      // 招待リストから削除
      _invitations.removeWhere((inv) => inv.id == invitationId);

      // グループリストを再読み込み
      await loadUserGroups();

      // 現在のグループの監視を開始
      if (_currentGroup != null) {
        // 招待承諾後、グループ監視を開始
        watchGroup(_currentGroup!.id);

        // ゲーミフィケーションプロフィールの監視も開始
        watchGroupGamificationProfile(_currentGroup!.id);
      }

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
      // 招待コードでグループ参加開始

      await GroupFirestoreService.joinGroupByInviteCode(inviteCode);

      // Firestoreでのグループ参加完了、グループリストを再読み込み開始

      // グループリストを再読み込み
      await loadUserGroups();

      // グループリスト再読み込み完了

      // 現在のグループの監視を開始
      if (_currentGroup != null) {
        // 招待コード参加後、グループ監視を開始
        watchGroup(_currentGroup!.id);

        // ゲーミフィケーションプロフィールの監視も開始
        watchGroupGamificationProfile(_currentGroup!.id);
      }

      // 状態更新を確実に通知
      _safeNotifyListeners();

      // 招待コード参加処理完了
      return true;
    } catch (e) {
      // 招待コード参加エラー
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

    // グループ脱退開始

    try {
      await GroupFirestoreService.leaveGroup(groupId);

      // Firestore脱退処理完了

      // ローカルのグループリストから削除
      _groups.removeWhere((g) => g.id == groupId);
      // ローカルグループリストから削除完了

      // 現在のグループが脱退した場合、nullに設定
      if (_currentGroup?.id == groupId) {
        // 現在のグループを脱退中
        _currentGroup = null;

        // 監視を停止
        unwatchGroup(groupId);
        // グループ監視停止完了

        // ローカルデータをクリア
        await _clearLocalData();
        // ローカルデータクリア完了

        // グループ脱退処理完了
      } else {
        // 現在のグループではないため、currentGroupは変更なし
      }

      _safeNotifyListeners();
      // リスナー通知完了
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
    // グループが変更された場合、ローカルデータをクリア
    if (_currentGroup?.id != group?.id) {
      _clearLocalData();
    }
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

    // グループ監視開始

    final sub = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .snapshots()
        .listen(
          (doc) {
            if (doc.exists) {
              final updated = Group.fromJson(doc.data()!);
              final idx = _groups.indexWhere((g) => g.id == groupId);
              final currentUser = FirebaseAuth.instance.currentUser;

              // グループ更新検知

              // 現在のユーザーがメンバーから削除されたかチェック
              if (currentUser != null && !updated.isMember(currentUser.uid)) {
                // 現在のユーザーがメンバーから削除されました
                _handleMemberRemoval(groupId);
                return;
              }

              if (idx != -1) {
                _groups[idx] = updated;
                // 既存グループを更新
              } else {
                _groups.add(updated);
                // 新しいグループを追加
              }

              if (_currentGroup?.id == groupId) {
                _currentGroup = updated;
                // 現在のグループを更新
              }

              // notifyListeners呼び出し
              notifyListeners();
            } else {
              // グループが削除された場合の処理
              _handleGroupDeleted(groupId);
            }
          },
          onError: (error) {
            // グループ監視エラー
          },
        );

    _groupWatchers[groupId] = sub;

    // グループ設定の監視も開始
    watchGroupSettings(groupId);

    // メンバー脱退通知の監視も開始
    _watchMemberRemovals(groupId);
  }

  /// メンバー脱退通知を監視
  void _watchMemberRemovals(String groupId) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('memberRemovals')
        .doc(currentUser.uid)
        .snapshots()
        .listen(
          (doc) {
            if (doc.exists) {
              // メンバー脱退通知を検知

              // 脱退通知を削除
              doc.reference.delete();

              // グループから脱退処理
              _handleMemberRemoval(groupId);
            }
          },
          onError: (error) {
            // メンバー脱退通知監視エラー
          },
        );

    // 脱退通知の監視を保存（必要に応じて）
    // _memberRemovalWatchers[groupId] = sub;
  }

  /// メンバー脱退処理
  void _handleMemberRemoval(String groupId) {
    // メンバー脱退処理開始

    // ローカルのグループリストから削除
    _groups.removeWhere((g) => g.id == groupId);

    // 現在のグループが脱退した場合、nullに設定
    if (_currentGroup?.id == groupId) {
      _currentGroup = null;
    }

    // 監視を停止
    unwatchGroup(groupId);

    // ローカルデータをクリア
    _clearLocalData();

    // 通知
    notifyListeners();

    debugPrint('GroupProvider: メンバー脱退処理完了 - groupId: $groupId');
  }

  /// グループが削除された場合の処理
  void _handleGroupDeleted(String groupId) {
    debugPrint('GroupProvider: グループが削除されました: $groupId');

    // ローカルのグループリストから削除
    _groups.removeWhere((g) => g.id == groupId);

    // 現在のグループが削除された場合、nullに設定
    if (_currentGroup?.id == groupId) {
      _currentGroup = null;

      // グループ削除ページに遷移するためのフラグを設定
      _showGroupDeletedPage = true;
      debugPrint('GroupProvider: グループ削除フラグを設定しました（_handleGroupDeleted）');
    }

    // 監視を停止
    unwatchGroup(groupId);

    // ローカルデータをクリア
    _clearLocalData();

    // 通知
    notifyListeners();
  }

  /// グループ削除ページ表示フラグをリセット
  void resetGroupDeletedPageFlag() {
    _showGroupDeletedPage = false;
    notifyListeners();
  }

  /// グループ設定の変更をリアルタイム監視
  void watchGroupSettings(String groupId) {
    if (_groupSettingsWatchers.containsKey(groupId)) return;

    debugPrint('GroupProvider: グループ設定監視開始: $groupId');

    final sub = GroupFirestoreService.watchGroupSettings(groupId).listen(
      (settings) {
        if (settings != null) {
          debugPrint('GroupProvider: グループ設定更新検知 - ID: $groupId');
          debugPrint('GroupProvider: 新しい設定: $settings');

          // 現在のグループの設定を更新
          if (_currentGroup?.id == groupId) {
            _currentGroup = _currentGroup!.copyWith(
              settings: settings.toJson(),
            );
            debugPrint('GroupProvider: 現在のグループ設定を更新');
          }

          // グループリスト内の該当グループの設定も更新
          final idx = _groups.indexWhere((g) => g.id == groupId);
          if (idx != -1) {
            _groups[idx] = _groups[idx].copyWith(settings: settings.toJson());
            debugPrint('GroupProvider: グループリスト内の設定を更新');
          }

          notifyListeners();
        }
      },
      onError: (error) {
        debugPrint('GroupProvider: グループ設定監視エラー: $error');
      },
    );

    _groupSettingsWatchers[groupId] = sub;
  }

  /// Firestoreのグループ監視を解除
  void unwatchGroup(String groupId) {
    _groupWatchers[groupId]?.cancel();
    _groupWatchers.remove(groupId);

    // グループ設定の監視も解除
    _groupSettingsWatchers[groupId]?.cancel();
    _groupSettingsWatchers.remove(groupId);
  }

  @override
  void dispose() {
    // 既存の監視を停止
    for (final sub in _groupWatchers.values) {
      sub.cancel();
    }
    _groupWatchers.clear();

    // グループ設定監視を停止
    for (final watcher in _groupSettingsWatchers.values) {
      watcher.cancel();
    }
    _groupSettingsWatchers.clear();

    // ゲーミフィケーション監視を停止
    for (final watcher in _gamificationWatchers.values) {
      watcher.cancel();
    }
    _gamificationWatchers.clear();

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
      // ビルド中でないことを確認してからnotifyListenersを呼び出す
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          notifyListeners();
        } catch (e) {
          debugPrint('GroupProvider: notifyListenersエラー: $e');
        }
      });
    } catch (e) {
      debugPrint('GroupProvider: _safeNotifyListenersエラー: $e');
    }
  }

  /// 全データをリフレッシュ
  Future<void> refresh() async {
    // 初期化状態をリセット
    _initialized = false;
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
      debugPrint('GroupProvider: currentGroupがnullのため設定を取得できません');
      return null;
    }

    try {
      debugPrint('GroupProvider: グループ設定を取得中 - グループID: ${_currentGroup!.id}');
      debugPrint('GroupProvider: グループ設定データ: ${_currentGroup!.settings}');
      debugPrint(
        'GroupProvider: グループ設定データの型: ${_currentGroup!.settings.runtimeType}',
      );

      // 設定が存在しない場合はデフォルト設定を使用
      if (_currentGroup!.settings.isEmpty) {
        debugPrint('GroupProvider: 設定が空のためデフォルト設定を使用');
        return GroupSettings.defaultSettings();
      }

      final settings = GroupSettings.fromJson(_currentGroup!.settings);
      debugPrint('GroupProvider: グループ設定取得成功: $settings');
      debugPrint('GroupProvider: データ権限設定: ${settings.dataPermissions}');
      return settings;
    } catch (e) {
      debugPrint('GroupProvider: グループ設定の取得に失敗: $e');
      debugPrint('GroupProvider: エラーの詳細: ${e.toString()}');
      debugPrint('GroupProvider: デフォルト設定を使用');
      return GroupSettings.defaultSettings();
    }
  }

  /// グループ設定（settings）のみを更新し、リスナーに通知
  void updateCurrentGroupSettings(Map<String, dynamic> newSettings) {
    if (_currentGroup != null) {
      _currentGroup = _currentGroup!.copyWith(settings: newSettings);
      _safeNotifyListeners();
    }
  }

  // グループデータの監視を開始
  void startWatchingGroupData() {
    if (isWatchingGroupData) {
      debugPrint('GroupProvider: 既にグループデータを監視中です');
      return;
    }

    debugPrint('GroupProvider: グループデータ監視開始');
    _isWatchingGroupData = true;

    // 遅延してnotifyListenersを呼び出す
    Future.microtask(() {
      _safeNotifyListeners();
    });
  }

  // グループデータの監視を停止
  void stopWatchingGroupData() {
    if (!isWatchingGroupData) {
      debugPrint('GroupProvider: グループデータ監視は既に停止中です');
      return;
    }

    debugPrint('GroupProvider: グループデータ監視停止');
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
      debugPrint('GroupProvider: グループデータをローカルに適用開始');
      await GroupDataSyncService.applyGroupDataToLocal(_currentGroup!.id);
      debugPrint('GroupProvider: グループデータをローカルに適用完了');
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('GroupProvider: グループデータの適用に失敗: $e');
    }
  }

  /// グループの統計情報を取得
  Future<void> loadGroupStatistics(String groupId) async {
    try {
      final statistics = await _statisticsService.getGroupStatistics(groupId);
      _groupStatistics[groupId] = statistics;
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('GroupProvider: 統計情報の取得に失敗: $e');
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

  /// グループのゲーミフィケーションプロフィールを取得
  Future<void> loadGroupGamificationProfile(String groupId) async {
    // 既に読み込まれている場合はスキップ
    if (_groupGamificationProfiles.containsKey(groupId)) {
      return;
    }

    try {
      debugPrint('GroupProvider: ゲーミフィケーションプロフィールを読み込み中: $groupId');
      final profile = await GroupGamificationService.getGroupProfile(groupId);
      _groupGamificationProfiles[groupId] = profile;
      _safeNotifyListeners();
      debugPrint('GroupProvider: ゲーミフィケーションプロフィール読み込み完了: $groupId');
    } catch (e) {
      debugPrint('GroupProvider: ゲーミフィケーションプロフィールの取得に失敗: $e');
      // エラーの場合は初期プロフィールを設定
      _groupGamificationProfiles[groupId] = GroupGamificationProfile.initial(
        groupId,
      );
      _safeNotifyListeners();
    }
  }

  /// 特定のグループのゲーミフィケーションプロフィールを取得
  GroupGamificationProfile? getGroupGamificationProfile(String groupId) {
    return _groupGamificationProfiles[groupId];
  }

  /// すべてのグループのゲーミフィケーションプロフィールを取得
  Future<void> loadAllGroupGamificationProfiles() async {
    for (final group in _groups) {
      await loadGroupGamificationProfile(group.id);
    }
  }

  /// グループのゲーミフィケーションプロフィールを監視開始
  void watchGroupGamificationProfile(String groupId) {
    try {
      if (_gamificationWatchers.containsKey(groupId)) {
        return; // 既に監視中
      }

      debugPrint('GroupProvider: ゲーミフィケーションプロフィール監視開始: $groupId');

      final subscription = GroupGamificationService.watchGroupProfile(groupId)
          .listen(
            (profile) {
              try {
                _groupGamificationProfiles[groupId] = profile;
                _safeNotifyListeners();
              } catch (e) {
                debugPrint('GroupProvider: プロフィール更新エラー: $e');
              }
            },
            onError: (e) {
              debugPrint('GroupProvider: ゲーミフィケーションプロフィール監視エラー: $e');
              // エラーが発生した場合は監視を停止
              _gamificationWatchers.remove(groupId);
            },
          );

      _gamificationWatchers[groupId] = subscription;
      debugPrint('GroupProvider: ゲーミフィケーションプロフィール監視開始完了: $groupId');
    } catch (e) {
      debugPrint('GroupProvider: ゲーミフィケーションプロフィール監視開始エラー: $e');
    }
  }

  /// グループのゲーミフィケーションプロフィールの監視を停止
  void unwatchGroupGamificationProfile(String groupId) {
    final subscription = _gamificationWatchers[groupId];
    if (subscription != null) {
      subscription.cancel();
      _gamificationWatchers.remove(groupId);
    }
  }

  /// グループの出勤記録を処理（新しいバッジシステム対応）
  Future<void> processGroupAttendance(
    String groupId, {
    BuildContext? context,
  }) async {
    try {
      final result = await GroupGamificationService.recordAttendance(groupId);

      if (result.success) {
        // キャッシュをクリアして最新のプロフィールを取得
        GroupGamificationService.clearCache(groupId);
        final profile = await GroupGamificationService.getGroupProfile(groupId);
        _groupGamificationProfiles[groupId] = profile;
        _safeNotifyListeners();

        // 演出を表示（contextが提供されている場合）
        if (context != null && context.mounted) {
          await GroupCelebrationHelper.showCompleteCelebration(
            context,
            xpGained: result.experienceGained,
            newLevel: result.levelUp ? result.newLevel : null,
            newBadges: result.newBadges,
          );
        }

        if (result.newBadges.isNotEmpty) {
          debugPrint(
            'グループ出勤バッジ獲得: ${result.newBadges.map((b) => b.name).join(', ')}',
          );
        }
      }
    } catch (e) {
      debugPrint('グループ出勤処理エラー: $e');
    }
  }

  /// グループの焙煎記録を処理（新しいバッジシステム対応）
  Future<void> processGroupRoasting(
    String groupId,
    double minutes, {
    BuildContext? context,
  }) async {
    try {
      final result = await GroupGamificationService.recordRoasting(
        groupId,
        minutes,
      );

      if (result.success) {
        // キャッシュをクリアして最新のプロフィールを取得
        GroupGamificationService.clearCache(groupId);
        final profile = await GroupGamificationService.getGroupProfile(groupId);
        _groupGamificationProfiles[groupId] = profile;
        _safeNotifyListeners();

        // 演出を表示（contextが提供されている場合）
        if (context != null && context.mounted) {
          await GroupCelebrationHelper.showCompleteCelebration(
            context,
            xpGained: result.experienceGained,
            newLevel: result.levelUp ? result.newLevel : null,
            newBadges: result.newBadges,
          );
        }

        if (result.newBadges.isNotEmpty) {
          debugPrint(
            'グループ焙煎バッジ獲得: ${result.newBadges.map((b) => b.name).join(', ')}',
          );
        }
      }
    } catch (e) {
      debugPrint('グループ焙煎処理エラー: $e');
    }
  }

  /// 複数の焙煎記録をまとめて処理（新しいバッジシステム対応）
  Future<void> processMultipleGroupRoasting(
    String groupId,
    List<double> minutesList, {
    BuildContext? context,
  }) async {
    try {
      // すべての焙煎時間を合計
      final totalMinutes = minutesList.fold(
        0.0,
        (sumValue, minutes) => sumValue + minutes,
      );

      debugPrint(
        'GroupProvider: 複数焙煎記録の処理開始 - 合計時間: $totalMinutes分, 記録数: ${minutesList.length}',
      );

      final result = await GroupGamificationService.recordRoasting(
        groupId,
        totalMinutes,
      );

      if (result.success) {
        // キャッシュをクリアして最新のプロフィールを取得
        GroupGamificationService.clearCache(groupId);
        final profile = await GroupGamificationService.getGroupProfile(groupId);
        _groupGamificationProfiles[groupId] = profile;
        _safeNotifyListeners();

        // 演出を表示（contextが提供されている場合）
        if (context != null && context.mounted) {
          await GroupCelebrationHelper.showCompleteCelebration(
            context,
            xpGained: result.experienceGained,
            newLevel: result.levelUp ? result.newLevel : null,
            newBadges: result.newBadges,
          );
        }

        if (result.newBadges.isNotEmpty) {
          debugPrint(
            'グループ複数焙煎バッジ獲得: ${result.newBadges.map((b) => b.name).join(', ')}',
          );
        }
      }
    } catch (e) {
      debugPrint('グループ複数焙煎処理エラー: $e');
    }
  }

  /// グループのドリップパック記録を処理（新しいバッジシステム対応）
  Future<void> processGroupDripPack(
    String groupId,
    int count, {
    BuildContext? context,
  }) async {
    try {
      final result = await GroupGamificationService.recordDripPack(
        groupId,
        count,
      );

      if (result.success) {
        // キャッシュをクリアして最新のプロフィールを取得
        GroupGamificationService.clearCache(groupId);
        final profile = await GroupGamificationService.getGroupProfile(groupId);
        _groupGamificationProfiles[groupId] = profile;
        _safeNotifyListeners();

        // 演出を表示（contextが提供されている場合）
        if (context != null && context.mounted) {
          await GroupCelebrationHelper.showCompleteCelebration(
            context,
            xpGained: result.experienceGained,
            newLevel: result.levelUp ? result.newLevel : null,
            newBadges: result.newBadges,
          );
        }

        if (result.newBadges.isNotEmpty) {
          debugPrint(
            'グループドリップバッジ獲得: ${result.newBadges.map((b) => b.name).join(', ')}',
          );
        }
      }
    } catch (e) {
      debugPrint('グループドリップ処理エラー: $e');
    }
  }

  /// グループのテイスティング記録を処理（新しいバッジシステム対応）
  Future<void> processGroupTasting(
    String groupId, {
    BuildContext? context,
  }) async {
    try {
      final result = await GroupGamificationService.recordTasting(groupId);

      if (result.success) {
        // キャッシュをクリアして最新のプロフィールを取得
        GroupGamificationService.clearCache(groupId);
        final profile = await GroupGamificationService.getGroupProfile(groupId);
        _groupGamificationProfiles[groupId] = profile;
        _safeNotifyListeners();

        // 演出を表示（contextが提供されている場合）
        if (context != null && context.mounted) {
          await GroupCelebrationHelper.showCompleteCelebration(
            context,
            xpGained: result.experienceGained,
            newLevel: result.levelUp ? result.newLevel : null,
            newBadges: result.newBadges,
          );
        }

        if (result.newBadges.isNotEmpty) {
          debugPrint(
            'グループテイスティングバッジ獲得: ${result.newBadges.map((b) => b.name).join(', ')}',
          );
        }
      }
    } catch (e) {
      debugPrint('グループテイスティング処理エラー: $e');
    }
  }

  /// グループの作業進捗記録を処理（新しいバッジシステム対応）
  Future<void> processGroupWorkProgress(
    String groupId, {
    BuildContext? context,
  }) async {
    try {
      final result = await GroupGamificationService.recordWorkProgress(groupId);

      if (result.success) {
        // キャッシュをクリアして最新のプロフィールを取得
        GroupGamificationService.clearCache(groupId);
        final profile = await GroupGamificationService.getGroupProfile(groupId);
        _groupGamificationProfiles[groupId] = profile;
        _safeNotifyListeners();

        // 演出を表示（contextが提供されている場合）
        if (context != null && context.mounted) {
          await GroupCelebrationHelper.showCompleteCelebration(
            context,
            xpGained: result.experienceGained,
            newLevel: result.levelUp ? result.newLevel : null,
            newBadges: result.newBadges,
          );
        }

        if (result.newBadges.isNotEmpty) {
          debugPrint(
            'グループ作業進捗バッジ獲得: ${result.newBadges.map((b) => b.name).join(', ')}',
          );
        }
      }
    } catch (e) {
      debugPrint('グループ作業進捗処理エラー: $e');
    }
  }

  /// グループ作成フラグをリセット
  void resetGroupCreationCelebration() {
    _showGroupCreationCelebration = false;
    _newlyCreatedGroupId = null;
    _safeNotifyListeners();
    debugPrint('GroupProvider: グループ作成フラグをリセット');
  }

  /// ログアウト時にグループ情報をクリア
  void clearOnLogout() {
    debugPrint('GroupProvider: ログアウト時のグループ情報クリア開始');

    // グループ情報をクリア
    _groups.clear();
    _currentGroup = null;
    _invitations.clear();

    // 統計データをクリア
    _groupStatistics.clear();

    // ゲーミフィケーション情報をクリア
    _groupGamificationProfiles.clear();

    // グループ作成フラグをリセット
    _showGroupCreationCelebration = false;
    _newlyCreatedGroupId = null;

    // グループ削除ページ表示フラグをリセット
    _showGroupDeletedPage = false;

    // 監視状態をリセット
    _isWatchingGroupData = false;

    // エラーをクリア
    _error = null;

    // すべてのStreamSubscriptionをキャンセル
    for (final subscription in _groupWatchers.values) {
      subscription.cancel();
    }
    _groupWatchers.clear();

    for (final subscription in _gamificationWatchers.values) {
      subscription.cancel();
    }
    _gamificationWatchers.clear();

    debugPrint('GroupProvider: ログアウト時のグループ情報クリア完了');
    _safeNotifyListeners();
  }
}
