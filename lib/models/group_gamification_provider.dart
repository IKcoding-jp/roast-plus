import 'package:flutter/material.dart';
import '../models/group_gamification_models.dart';
import '../services/group_gamification_service.dart';
import '../services/group_firestore_service.dart';

/// グループ中心のゲーミフィケーション状態管理プロバイダー
class GroupGamificationProvider extends ChangeNotifier {
  GroupGamificationProfile _profile = GroupGamificationProfile.initial('');
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _currentGroupId;
  String? _error;

  // Getters
  GroupGamificationProfile get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get currentGroupId => _currentGroupId;
  String? get error => _error;
  bool get hasGroup => _currentGroupId != null && _currentGroupId!.isNotEmpty;

  /// 指定されたグループでプロバイダーを初期化
  Future<void> initializeWithGroup(String groupId) async {
    _setLoading(true);
    _clearError();

    try {
      _currentGroupId = groupId;
      _profile = await GroupGamificationService.getGroupProfile(groupId);
      _isInitialized = true;

      print('グループゲーミフィケーションプロバイダー初期化完了: グループ $groupId, レベル${_profile.level}');
    } catch (e) {
      print('グループゲーミフィケーション初期化エラー: $e');
      _setError('グループの初期化に失敗しました: $e');
      _profile = GroupGamificationProfile.initial(groupId);
    } finally {
      _setLoading(false);
    }
  }

  /// 現在のユーザーのグループを自動検出して初期化
  Future<void> autoInitialize() async {
    _setLoading(true);
    _clearError();

    try {
      // ユーザーが参加しているグループを取得
      final groups = await GroupFirestoreService.getUserGroups();
      
      if (groups.isEmpty) {
        // グループに参加していない
        _isInitialized = false;
        _currentGroupId = null;
        print('グループに参加していません');
        return;
      }

      // 最初のグループで初期化（将来的には最後に活動したグループなどで選択可能）
      final firstGroup = groups.first;
      await initializeWithGroup(firstGroup.id);
    } catch (e) {
      print('グループ自動初期化エラー: $e');
      _setError('グループの取得に失敗しました: $e');
      _isInitialized = false;
    } finally {
      _setLoading(false);
    }
  }

  /// 出勤を記録
  Future<GroupActivityResult> recordAttendance() async {
    if (!hasGroup) {
      return GroupActivityResult(
        success: false,
        message: 'グループに参加していません',
        levelUp: false,
        newBadges: [],
        experienceGained: 0,
        newLevel: 0,
      );
    }

    _setLoading(true);
    try {
      final result = await GroupGamificationService.recordAttendance(_currentGroupId!);
      
      if (result.success) {
        // プロフィールを更新
        await _refreshProfile();
        
        // UI効果を表示
        await _showActivityResult(result);
      }

      return result;
    } catch (e) {
      print('出勤記録エラー: $e');
      return GroupActivityResult(
        success: false,
        message: '出勤記録に失敗しました',
        levelUp: false,
        newBadges: [],
        experienceGained: 0,
        newLevel: 0,
      );
    } finally {
      _setLoading(false);
    }
  }

  /// 焙煎を記録
  Future<GroupActivityResult> recordRoasting(double minutes) async {
    if (!hasGroup) {
      return GroupActivityResult(
        success: false,
        message: 'グループに参加していません',
        levelUp: false,
        newBadges: [],
        experienceGained: 0,
        newLevel: 0,
      );
    }

    _setLoading(true);
    try {
      final result = await GroupGamificationService.recordRoasting(_currentGroupId!, minutes);
      
      if (result.success) {
        await _refreshProfile();
        await _showActivityResult(result);
      }

      return result;
    } catch (e) {
      print('焙煎記録エラー: $e');
      return GroupActivityResult(
        success: false,
        message: '焙煎記録に失敗しました',
        levelUp: false,
        newBadges: [],
        experienceGained: 0,
        newLevel: 0,
      );
    } finally {
      _setLoading(false);
    }
  }

  /// ドリップパックを記録
  Future<GroupActivityResult> recordDripPack(int count) async {
    if (!hasGroup) {
      return GroupActivityResult(
        success: false,
        message: 'グループに参加していません',
        levelUp: false,
        newBadges: [],
        experienceGained: 0,
        newLevel: 0,
      );
    }

    _setLoading(true);
    try {
      final result = await GroupGamificationService.recordDripPack(_currentGroupId!, count);
      
      if (result.success) {
        await _refreshProfile();
        await _showActivityResult(result);
      }

      return result;
    } catch (e) {
      print('ドリップパック記録エラー: $e');
      return GroupActivityResult(
        success: false,
        message: 'ドリップパック記録に失敗しました',
        levelUp: false,
        newBadges: [],
        experienceGained: 0,
        newLevel: 0,
      );
    } finally {
      _setLoading(false);
    }
  }

  /// テイスティングを記録
  Future<GroupActivityResult> recordTasting() async {
    if (!hasGroup) {
      return GroupActivityResult(
        success: false,
        message: 'グループに参加していません',
        levelUp: false,
        newBadges: [],
        experienceGained: 0,
        newLevel: 0,
      );
    }

    _setLoading(true);
    try {
      final result = await GroupGamificationService.recordTasting(_currentGroupId!);
      
      if (result.success) {
        await _refreshProfile();
        await _showActivityResult(result);
      }

      return result;
    } catch (e) {
      print('テイスティング記録エラー: $e');
      return GroupActivityResult(
        success: false,
        message: 'テイスティング記録に失敗しました',
        levelUp: false,
        newBadges: [],
        experienceGained: 0,
        newLevel: 0,
      );
    } finally {
      _setLoading(false);
    }
  }

  /// 作業進捗を記録
  Future<GroupActivityResult> recordWorkProgress() async {
    if (!hasGroup) {
      return GroupActivityResult(
        success: false,
        message: 'グループに参加していません',
        levelUp: false,
        newBadges: [],
        experienceGained: 0,
        newLevel: 0,
      );
    }

    _setLoading(true);
    try {
      final result = await GroupGamificationService.recordWorkProgress(_currentGroupId!);
      
      if (result.success) {
        await _refreshProfile();
        await _showActivityResult(result);
      }

      return result;
    } catch (e) {
      print('作業進捗記録エラー: $e');
      return GroupActivityResult(
        success: false,
        message: '作業進捗記録に失敗しました',
        levelUp: false,
        newBadges: [],
        experienceGained: 0,
        newLevel: 0,
      );
    } finally {
      _setLoading(false);
    }
  }

  /// プロフィールを最新の状態に更新
  Future<void> _refreshProfile() async {
    if (!hasGroup) return;

    try {
      _profile = await GroupGamificationService.getGroupProfile(_currentGroupId!);
      notifyListeners();
    } catch (e) {
      print('プロフィール更新エラー: $e');
    }
  }

  /// アクティビティ結果のUI効果を表示
  Future<void> _showActivityResult(GroupActivityResult result) async {
    // レベルアップアニメーション
    if (result.levelUp) {
      // TODO: レベルアップアニメーションを表示
      print('🎉 レベルアップ！ レベル ${result.newLevel} に上がりました！');
    }

    // バッジ獲得アニメーション
    if (result.newBadges.isNotEmpty) {
      for (final badge in result.newBadges) {
        // TODO: バッジ獲得アニメーションを表示
        print('🏆 新しいバッジを獲得しました: ${badge.name}');
      }
    }

    // 経験値獲得表示
    if (result.experienceGained > 0) {
      print('✨ +${result.experienceGained}XP 獲得！');
    }
  }

  /// 次の獲得可能なバッジを取得
  List<GroupBadgeCondition> getUpcomingBadges({int limit = 3}) {
    if (!hasGroup) return [];
    return GroupGamificationService.getUpcomingBadges(_profile, limit: limit);
  }

  /// バッジ獲得の進捗率を計算
  double getBadgeProgress(GroupBadgeCondition condition) {
    if (!hasGroup) return 0.0;
    return GroupGamificationService.getBadgeProgress(condition, _profile);
  }

  /// グループの詳細統計を取得
  Future<Map<String, dynamic>> getDetailedStats() async {
    if (!hasGroup) return {};
    
    try {
      return await GroupGamificationService.getGroupDetailedStats(_currentGroupId!);
    } catch (e) {
      print('詳細統計取得エラー: $e');
      return {};
    }
  }

  /// グループ変更（グループ切り替え時）
  Future<void> switchGroup(String newGroupId) async {
    if (_currentGroupId == newGroupId) return;

    _isInitialized = false;
    await initializeWithGroup(newGroupId);
  }

  /// プロフィールのリアルタイム監視を開始
  Stream<GroupGamificationProfile> watchProfile() {
    if (!hasGroup) return Stream.value(GroupGamificationProfile.initial(''));
    
    return GroupGamificationService.watchGroupProfile(_currentGroupId!)
      .map((profile) {
        _profile = profile;
        notifyListeners();
        return profile;
      });
  }

  /// ローディング状態を設定
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// エラーを設定
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  /// エラーをクリア
  void _clearError() {
    _error = null;
    notifyListeners();
  }

  /// プロバイダーをリセット（ログアウト時など）
  void reset() {
    _profile = GroupGamificationProfile.initial('');
    _isLoading = false;
    _isInitialized = false;
    _currentGroupId = null;
    _error = null;
    notifyListeners();
  }

  /// デバッグ情報を出力
  Future<void> debugPrint() async {
    if (!hasGroup) {
      print('=== グループゲーミフィケーション（未参加） ===');
      return;
    }
    
    await GroupGamificationService.debugPrintGroupProfile(_currentGroupId!);
  }

  /// 手動でプロフィールを更新
  Future<void> refreshProfile() async {
    await _refreshProfile();
  }

  /// グループが存在するかチェック
  bool get isGroupValid => hasGroup && _isInitialized;

  /// レベルタイトルを取得
  String get levelTitle => _profile.displayTitle;

  /// レベル色を取得
  Color get levelColor => _profile.levelColor;

  /// 次のレベルまでの進捗率を取得
  double get levelProgress => _profile.levelProgress;

  /// 次のレベルまでに必要な経験値を取得
  int get experienceToNextLevel => _profile.experienceToNextLevel;

  /// 最新のバッジを取得
  GroupBadge? get latestBadge => _profile.latestBadge;
} 