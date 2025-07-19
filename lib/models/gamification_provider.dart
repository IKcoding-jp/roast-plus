import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'gamification_models.dart';
import '../services/gamification_service.dart';
import '../services/gamification_storage.dart';
import '../widgets/badge_celebration_widget.dart';
import '../services/experience_manager.dart';
import 'theme_settings.dart';

/// ゲーミフィケーション機能の状態管理プロバイダー
class GamificationProvider extends ChangeNotifier {
  UserProfile _userProfile = UserProfile.initial();
  bool _isLoading = false;
  bool _isInitialized = false;

  // Getters
  UserProfile get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  /// 初期化
  Future<void> initialize() async {
    if (_isInitialized) return;

    _setLoading(true);
    try {
      await GamificationStorage.migrateDataIfNeeded();
      _userProfile = await GamificationStorage.loadUserProfile();
      _isInitialized = true;

      // 古い活動記録をクリーンアップ
      await GamificationStorage.cleanupOldActivities();

      print('ゲーミフィケーションプロバイダー初期化完了: レベル${_userProfile.level}');
    } catch (e) {
      print('ゲーミフィケーション初期化エラー: $e');
      _userProfile = UserProfile.initial();
    } finally {
      _setLoading(false);
    }
  }

  /// 出勤を記録
  Future<ActivityResult> recordAttendance() async {
    // 今日既に記録済みかチェック
    final isAlreadyRecorded = await GamificationStorage.isDailyActivityRecorded(
      ActivityType.attendance,
      'daily',
    );

    if (isAlreadyRecorded) {
      return ActivityResult(
        success: false,
        message: '今日は既に出勤を記録済みです',
        levelUp: false,
        newBadges: [],
        experienceGained: 0,
      );
    }

    final oldProfile = _userProfile;
    final newProfile = GamificationService.recordAttendance(_userProfile);
    final newBadges = GamificationService.checkNewBadges(
      oldProfile,
      newProfile,
    );
    final finalProfile = GamificationService.addBadges(newProfile, newBadges);
    final levelUp = GamificationService.didLevelUp(oldProfile, finalProfile);

    await _updateProfile(finalProfile);
    await GamificationStorage.saveDailyActivity(
      ActivityType.attendance,
      'daily',
    );

    final reward = ActivityReward.attendance();
    return ActivityResult(
      success: true,
      message: reward.description,
      levelUp: levelUp,
      newBadges: newBadges,
      experienceGained: reward.experiencePoints,
    );
  }

  /// 焙煎を記録
  Future<ActivityResult> recordRoasting(double minutes) async {
    if (minutes <= 0) {
      return ActivityResult(
        success: false,
        message: '焙煎時間が不正です',
        levelUp: false,
        newBadges: [],
        experienceGained: 0,
      );
    }

    final oldProfile = _userProfile;
    final newProfile = GamificationService.recordRoasting(
      _userProfile,
      minutes,
    );
    final newBadges = GamificationService.checkNewBadges(
      oldProfile,
      newProfile,
    );
    final finalProfile = GamificationService.addBadges(newProfile, newBadges);
    final levelUp = GamificationService.didLevelUp(oldProfile, finalProfile);

    await _updateProfile(finalProfile);

    final reward = ActivityReward.roasting(minutes);
    return ActivityResult(
      success: true,
      message: reward.description,
      levelUp: levelUp,
      newBadges: newBadges,
      experienceGained: reward.experiencePoints,
    );
  }

  /// ドリップパックを記録
  Future<ActivityResult> recordDripPack(int count) async {
    if (count <= 0) {
      return ActivityResult(
        success: false,
        message: 'ドリップパック数が不正です',
        levelUp: false,
        newBadges: [],
        experienceGained: 0,
      );
    }

    final oldProfile = _userProfile;
    final newProfile = GamificationService.recordDripPack(_userProfile, count);
    final newBadges = GamificationService.checkNewBadges(
      oldProfile,
      newProfile,
    );
    final finalProfile = GamificationService.addBadges(newProfile, newBadges);
    final levelUp = GamificationService.didLevelUp(oldProfile, finalProfile);

    await _updateProfile(finalProfile);

    final reward = ActivityReward.dripPack(count);
    return ActivityResult(
      success: true,
      message: reward.description,
      levelUp: levelUp,
      newBadges: newBadges,
      experienceGained: reward.experiencePoints,
    );
  }

  /// プロフィールを更新
  Future<void> _updateProfile(UserProfile newProfile) async {
    _userProfile = newProfile;
    await GamificationStorage.saveUserProfile(_userProfile);
    notifyListeners();
  }

  /// ローディング状態を設定
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// プロフィールをリセット（デバッグ用）
  Future<void> resetProfile() async {
    await GamificationStorage.resetUserProfile();
    _userProfile = UserProfile.initial();
    _isInitialized = false;
    notifyListeners();
    await initialize();
  }

  /// 次の獲得可能なバッジを取得
  List<BadgeCondition> getUpcomingBadges({int limit = 3}) {
    return GamificationService.getUpcomingBadges(_userProfile, limit: limit);
  }

  /// バッジ獲得の進捗率を計算
  double getBadgeProgress(BadgeCondition condition) {
    return GamificationService.getBadgeProgress(condition, _userProfile);
  }

  /// レベルタイトルを取得
  String get levelTitle =>
      GamificationService.getLevelTitle(_userProfile.level);

  /// レベル色を取得
  Color get levelColor => GamificationService.getLevelColor(_userProfile.level);

  /// デバッグ情報を出力
  Future<void> debugPrint() async {
    await GamificationStorage.debugPrintProfile();
  }

  /// データをエクスポート
  Future<String> exportData() async {
    return await GamificationStorage.exportUserData();
  }

  /// データをインポート
  Future<bool> importData(String jsonData) async {
    final success = await GamificationStorage.importUserData(jsonData);
    if (success) {
      _userProfile = await GamificationStorage.loadUserProfile();
      notifyListeners();
    }
    return success;
  }

  /// 活動結果通知のためのスナックバー表示
  void showActivityResult(BuildContext context, ActivityResult result) {
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.orange),
      );
      return;
    }

    // レベルアップした場合
    if (result.levelUp) {
      _showLevelUpDialog(context);
    }

    // 新しいバッジを獲得した場合
    if (result.newBadges.isNotEmpty) {
      _showBadgeCelebration(context, result.newBadges);
    }

    // 通常の経験値獲得通知
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.star, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(result.message)),
            Text('+${result.experienceGained}XP'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// レベルアップダイアログを表示
  void _showLevelUpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.celebration, color: Colors.amber, size: 32),
            SizedBox(width: 8),
            Text('レベルアップ！'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'レベル ${_userProfile.level} に到達しました！',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              levelTitle,
              style: TextStyle(
                fontSize: 16,
                color: levelColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('続ける'),
          ),
        ],
      ),
    );
  }

  /// バッジ獲得ダイアログを表示
  void _showBadgeDialog(BuildContext context, List<UserBadge> newBadges) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 32),
            SizedBox(width: 8),
            Text('新しい称号獲得！'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: newBadges
              .map(
                (badge) => ListTile(
                  leading: Icon(badge.icon, color: badge.color, size: 32),
                  title: Text(
                    badge.name,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(badge.description),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('おめでとうございます！'),
          ),
        ],
      ),
    );
  }

  /// バッジ獲得のお祝い表示
  void _showBadgeCelebration(BuildContext context, List<UserBadge> newBadges) {
    final themeSettings = Provider.of<ThemeSettings>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BadgeCelebrationWidget(
        newBadges: newBadges,
        themeSettings: themeSettings,
        onComplete: () => Navigator.of(context).pop(),
      ),
    );
  }

  /// ExperienceManagerからプロファイルを同期
  void refreshFromExperienceManager() {
    try {
      final profile = ExperienceManager.instance.profile;
      if (profile != _userProfile) {
        _userProfile = profile;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('ExperienceManagerからの同期エラー: $e');
      }
    }
  }
}

/// 活動結果を表すクラス
class ActivityResult {
  final bool success;
  final String message;
  final bool levelUp;
  final List<UserBadge> newBadges;
  final int experienceGained;

  const ActivityResult({
    required this.success,
    required this.message,
    required this.levelUp,
    required this.newBadges,
    required this.experienceGained,
  });
}
