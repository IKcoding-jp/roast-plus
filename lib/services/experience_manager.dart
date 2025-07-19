import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gamification_models.dart';
import '../models/group_gamification_provider.dart';
import '../models/group_provider.dart';
import 'gamification_service.dart';
import 'group_gamification_service.dart';

/// 経験値管理の中核サービスクラス
/// 30年以上の継続利用を想定した設計
class ExperienceManager {
  static ExperienceManager? _instance;
  static ExperienceManager get instance => _instance ??= ExperienceManager._();

  ExperienceManager._();

  // キャッシュされたプロファイル
  UserProfile? _cachedProfile;

  // 出勤記録のキャッシュ（日付 -> bool）
  final Map<String, bool> _attendanceCache = {};

  // リスナー
  final List<VoidCallback> _listeners = [];

  // 保存のデバウンス用タイマー
  Timer? _saveTimer;

  // 設定値（調整可能）
  static const int _xpPerRoastMinute = 1; // 焙煎1分あたりのXP
  static const int _xpPerAttendance = 10; // 出勤1日あたりのXP
  static const int _maxLevel = 9999; // 最大レベル
  static const int _baseXpForLevel2 = 100; // レベル2に必要な基本XP
  static const double _levelExponent = 1.2; // レベル成長指数

  /// 初期化
  Future<void> initialize() async {
    await _loadProfile();
    await _loadAttendanceCache();
  }

  /// プロファイルを取得
  UserProfile get profile => _cachedProfile ?? UserProfile.initial();

  /// リスナーを追加
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// リスナーを削除
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// リスナーに変更を通知
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// 焙煎記録からXPを加算
  ///
  /// [roastTimeMinutes] 焙煎時間（分）
  /// [beanName] 豆の名前（ログ用）
  /// [roastDate] 焙煎日時
  Future<ExperienceGainResult> addRoastingExperience({
    required double roastTimeMinutes,
    required String beanName,
    required DateTime roastDate,
  }) async {
    if (roastTimeMinutes <= 0) {
      return ExperienceGainResult.noGain('焙煎時間が無効です');
    }

    final xpGained = (roastTimeMinutes * _xpPerRoastMinute).round();

    final result = await _addExperience(
      xpGained,
      ActivityType.roasting,
      '焙煎 ${roastTimeMinutes.toStringAsFixed(1)}分 ($beanName)',
      roastDate,
    );

    // 焙煎統計を更新
    await _updateRoastingStats(roastTimeMinutes, roastDate);

    return result;
  }

  /// 出勤記録からXPを加算
  ///
  /// [attendanceDate] 出勤日
  /// [isCheckIn] true: 出勤, false: 退勤
  Future<ExperienceGainResult> addAttendanceExperience({
    required DateTime attendanceDate,
    required bool isCheckIn,
  }) async {
    final dateKey = _getDateKey(attendanceDate);

    // 既に今日の出勤XPを獲得している場合はスキップ
    if (_attendanceCache[dateKey] == true) {
      return ExperienceGainResult.noGain('今日は既に出勤XPを獲得済みです');
    }

    // 出勤または退勤のいずれかでXP加算
    _attendanceCache[dateKey] = true;

    final result = await _addExperience(
      _xpPerAttendance,
      ActivityType.attendance,
      '出勤 ($dateKey)',
      attendanceDate,
    );

    // 出勤統計を更新
    await _updateAttendanceStats(attendanceDate);

    // 出勤キャッシュを保存
    await _saveAttendanceCache();

    return result;
  }

  /// ドリップパック作成からXPを加算
  Future<ExperienceGainResult> addDripPackExperience({
    required int packCount,
    required DateTime createDate,
  }) async {
    if (packCount <= 0) {
      return ExperienceGainResult.noGain('ドリップパック数が無効です');
    }

    final xpGained =
        packCount * ActivityReward.baseRewards[ActivityType.dripPack]!;

    final result = await _addExperience(
      xpGained,
      ActivityType.dripPack,
      'ドリップパック $packCount個作成',
      createDate,
    );

    // ドリップパック統計を更新
    await _updateDripPackStats(packCount, createDate);

    return result;
  }

  /// テイスティング記録からXPを加算
  Future<ExperienceGainResult> addTastingExperience({
    required DateTime tastingDate,
  }) async {
    final xpGained = ActivityReward.baseRewards[ActivityType.tasting] ?? 5;

    final result = await _addExperience(
      xpGained,
      ActivityType.tasting,
      'テイスティング記録',
      tastingDate,
    );

    // テイスティング統計を更新
    await _updateTastingStats(tastingDate);

    return result;
  }

  /// 作業進捗更新からXPを加算
  Future<ExperienceGainResult> addWorkProgressExperience({
    required DateTime workDate,
  }) async {
    final xpGained = ActivityReward.baseRewards[ActivityType.workProgress] ?? 3;

    final result = await _addExperience(
      xpGained,
      ActivityType.workProgress,
      '作業進捗更新',
      workDate,
    );

    // 作業進捗統計を更新
    await _updateWorkProgressStats(workDate);

    return result;
  }

  /// 経験値を加算する内部メソッド
  Future<ExperienceGainResult> _addExperience(
    int xpGained,
    ActivityType activityType,
    String description,
    DateTime activityDate,
  ) async {
    final oldProfile = profile;
    final newXp = oldProfile.experiencePoints + xpGained;
    final newLevel = _calculateLevel(newXp);
    final leveledUp = newLevel > oldProfile.level;

    // 新しいプロファイルを作成
    _cachedProfile = oldProfile.copyWith(
      experiencePoints: newXp,
      level: newLevel,
      stats: oldProfile.stats.copyWith(lastActivityDate: activityDate),
    );

    // バッジチェック
    final newBadges = await _checkForNewBadges(oldProfile, _cachedProfile!);
    if (newBadges.isNotEmpty) {
      _cachedProfile = _cachedProfile!.copyWith(
        badges: [..._cachedProfile!.badges, ...newBadges],
      );
    }

    // グループのゲーミフィケーションシステムにも通知
    await _notifyGroupGamification(activityType, xpGained, description);

    // 非同期保存
    _debouncedSave();

    // リスナーに通知
    _notifyListeners();

    return ExperienceGainResult(
      success: true,
      xpGained: xpGained,
      newLevel: newLevel,
      leveledUp: leveledUp,
      newBadges: newBadges,
      description: description,
      oldProfile: oldProfile,
      newProfile: _cachedProfile!,
    );
  }

  /// グループのゲーミフィケーションシステムに通知
  Future<void> _notifyGroupGamification(
    ActivityType activityType,
    int xpGained,
    String description,
  ) async {
    try {
      // 現在のグループIDを取得（GroupProviderから）
      final groupProvider = GroupProvider();
      await groupProvider.loadUserGroups();
      final groups = groupProvider.groups;

      if (groups.isEmpty) {
        // グループに参加していない場合は何もしない
        return;
      }

      final currentGroup = groups.first;

      // アクティビティタイプに応じてグループのゲーミフィケーションシステムに通知
      switch (activityType) {
        case ActivityType.attendance:
          await GroupGamificationService.recordAttendance(currentGroup.id);
          break;
        case ActivityType.roasting:
          // 焙煎時間をXPから逆算（XP = 分数）
          final roastMinutes = xpGained.toDouble();
          await GroupGamificationService.recordRoasting(
            currentGroup.id,
            roastMinutes,
          );
          break;
        case ActivityType.dripPack:
          // ドリップパック数をXPから逆算（XP = count * 0.5）
          final packCount = (xpGained / 0.5).round();
          await GroupGamificationService.recordDripPack(
            currentGroup.id,
            packCount,
          );
          break;
        case ActivityType.tasting:
          await GroupGamificationService.recordTasting(currentGroup.id);
          break;
        case ActivityType.workProgress:
          await GroupGamificationService.recordWorkProgress(currentGroup.id);
          break;
        default:
          // その他のアクティビティは無視
          break;
      }

      print('ExperienceManager: グループゲーミフィケーションに通知完了 - $description');
    } catch (e) {
      print('ExperienceManager: グループゲーミフィケーション通知エラー: $e');
      // エラーが発生しても個人の経験値獲得は継続
    }
  }

  /// レベル計算（対数的成長）
  int _calculateLevel(int totalXp) {
    if (totalXp < _baseXpForLevel2) return 1;

    // レベル L に必要な累積XP = baseXp * Σ(i^exponent) for i=1 to L-1
    // 近似計算で高速化
    double level = 1.0;
    double currentXp = 0.0;

    while (level < _maxLevel && currentXp < totalXp) {
      final xpForNextLevel = _baseXpForLevel2 * math.pow(level, _levelExponent);
      if (currentXp + xpForNextLevel > totalXp) break;
      currentXp += xpForNextLevel;
      level += 1.0;
    }

    return level.round().clamp(1, _maxLevel);
  }

  /// 指定レベルに必要な累積XPを計算
  int _calculateRequiredXp(int level) {
    if (level <= 1) return 0;

    double totalXp = 0.0;
    for (int i = 1; i < level; i++) {
      totalXp += _baseXpForLevel2 * math.pow(i, _levelExponent);
    }

    return totalXp.round();
  }

  /// 次のレベルまでに必要なXP
  int getXpToNextLevel() {
    final currentLevel = profile.level;
    if (currentLevel >= _maxLevel) return 0;

    final currentLevelXp = _calculateRequiredXp(currentLevel);
    final nextLevelXp = _calculateRequiredXp(currentLevel + 1);

    return nextLevelXp - profile.experiencePoints;
  }

  /// 現在レベルでの進捗率（0.0 - 1.0）
  double getLevelProgress() {
    final currentLevel = profile.level;
    if (currentLevel >= _maxLevel) return 1.0;

    final currentLevelXp = _calculateRequiredXp(currentLevel);
    final nextLevelXp = _calculateRequiredXp(currentLevel + 1);
    final progressXp = profile.experiencePoints - currentLevelXp;
    final totalLevelXp = nextLevelXp - currentLevelXp;

    return totalLevelXp > 0 ? (progressXp / totalLevelXp).clamp(0.0, 1.0) : 0.0;
  }

  /// 出勤記録チェック（重複防止用）
  bool hasAttendanceToday([DateTime? date]) {
    final dateKey = _getDateKey(date ?? DateTime.now());
    return _attendanceCache[dateKey] == true;
  }

  /// 焙煎統計を更新
  Future<void> _updateRoastingStats(double minutes, DateTime date) async {
    final stats = _cachedProfile!.stats;
    _cachedProfile = _cachedProfile!.copyWith(
      stats: stats.copyWith(
        totalRoastTimeMinutes: stats.totalRoastTimeMinutes + minutes,
        totalRoastSessions: stats.totalRoastSessions + 1,
        lastActivityDate: date,
      ),
    );
  }

  /// 出勤統計を更新
  Future<void> _updateAttendanceStats(DateTime date) async {
    final stats = _cachedProfile!.stats;
    _cachedProfile = _cachedProfile!.copyWith(
      stats: stats.copyWith(
        attendanceDays: stats.attendanceDays + 1,
        lastActivityDate: date,
      ),
    );
  }

  /// ドリップパック統計を更新
  Future<void> _updateDripPackStats(int count, DateTime date) async {
    final stats = _cachedProfile!.stats;
    _cachedProfile = _cachedProfile!.copyWith(
      stats: stats.copyWith(
        dripPackCount: stats.dripPackCount + count,
        lastActivityDate: date,
      ),
    );
  }

  /// テイスティング統計を更新
  Future<void> _updateTastingStats(DateTime date) async {
    final stats = _cachedProfile!.stats;
    _cachedProfile = _cachedProfile!.copyWith(
      stats: stats.copyWith(lastActivityDate: date),
    );
  }

  /// 作業進捗統計を更新
  Future<void> _updateWorkProgressStats(DateTime date) async {
    final stats = _cachedProfile!.stats;
    _cachedProfile = _cachedProfile!.copyWith(
      stats: stats.copyWith(lastActivityDate: date),
    );
  }

  /// 新しいバッジをチェック
  Future<List<UserBadge>> _checkForNewBadges(
    UserProfile oldProfile,
    UserProfile newProfile,
  ) async {
    final newBadges = <UserBadge>[];
    final existingBadgeIds = oldProfile.badges.map((b) => b.id).toSet();

    for (final condition in GamificationService.badgeConditions) {
      if (existingBadgeIds.contains(condition.badgeId)) continue;

      if (condition.checkCondition(newProfile)) {
        newBadges.add(condition.createBadge());
      }
    }

    return newBadges;
  }

  /// 日付キーを生成
  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// デバウンス付き保存
  void _debouncedSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(Duration(milliseconds: 500), () async {
      await _saveProfile();
    });
  }

  /// プロファイルをロード
  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('experience_profile');

      if (profileJson != null) {
        final data = jsonDecode(profileJson) as Map<String, dynamic>;
        _cachedProfile = UserProfile.fromJson(data);
      } else {
        _cachedProfile = UserProfile.initial();
      }
    } catch (e) {
      debugPrint('プロファイル読み込みエラー: $e');
      _cachedProfile = UserProfile.initial();
    }
  }

  /// プロファイルを保存
  Future<void> _saveProfile() async {
    if (_cachedProfile == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = jsonEncode(_cachedProfile!.toJson());
      await prefs.setString('experience_profile', profileJson);
    } catch (e) {
      debugPrint('プロファイル保存エラー: $e');
    }
  }

  /// 出勤キャッシュをロード
  Future<void> _loadAttendanceCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('attendance_'));

      for (final key in keys) {
        final dateKey = key.substring(11); // 'attendance_'を除去
        final hasAttendance = prefs.getBool(key) ?? false;
        if (hasAttendance) {
          _attendanceCache[dateKey] = true;
        }
      }
    } catch (e) {
      debugPrint('出勤キャッシュ読み込みエラー: $e');
    }
  }

  /// 出勤キャッシュを保存
  Future<void> _saveAttendanceCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      for (final entry in _attendanceCache.entries) {
        if (entry.value) {
          await prefs.setBool('attendance_${entry.key}', true);
        }
      }
    } catch (e) {
      debugPrint('出勤キャッシュ保存エラー: $e');
    }
  }

  /// 統計情報を取得
  ExperienceStats getStats() {
    final p = profile;
    return ExperienceStats(
      totalXp: p.experiencePoints,
      currentLevel: p.level,
      xpToNextLevel: getXpToNextLevel(),
      levelProgress: getLevelProgress(),
      totalAttendanceDays: p.stats.attendanceDays,
      totalRoastTimeHours: p.stats.totalRoastTimeHours,
      totalDripPacks: p.stats.dripPackCount,
      totalBadges: p.badges.length,
      daysSinceStart: p.stats.daysSinceStart,
    );
  }

  /// リソースクリーンアップ
  void dispose() {
    _saveTimer?.cancel();
    _listeners.clear();
    _attendanceCache.clear();
  }
}

/// 経験値獲得結果
class ExperienceGainResult {
  final bool success;
  final int xpGained;
  final int newLevel;
  final bool leveledUp;
  final List<UserBadge> newBadges;
  final String description;
  final UserProfile oldProfile;
  final UserProfile newProfile;

  const ExperienceGainResult({
    required this.success,
    required this.xpGained,
    required this.newLevel,
    required this.leveledUp,
    required this.newBadges,
    required this.description,
    required this.oldProfile,
    required this.newProfile,
  });

  factory ExperienceGainResult.noGain(String reason) {
    final profile = UserProfile.initial();
    return ExperienceGainResult(
      success: false,
      xpGained: 0,
      newLevel: profile.level,
      leveledUp: false,
      newBadges: [],
      description: reason,
      oldProfile: profile,
      newProfile: profile,
    );
  }

  bool get hasRewards => leveledUp || newBadges.isNotEmpty;
}

/// 経験値統計
class ExperienceStats {
  final int totalXp;
  final int currentLevel;
  final int xpToNextLevel;
  final double levelProgress;
  final int totalAttendanceDays;
  final double totalRoastTimeHours;
  final int totalDripPacks;
  final int totalBadges;
  final int daysSinceStart;

  const ExperienceStats({
    required this.totalXp,
    required this.currentLevel,
    required this.xpToNextLevel,
    required this.levelProgress,
    required this.totalAttendanceDays,
    required this.totalRoastTimeHours,
    required this.totalDripPacks,
    required this.totalBadges,
    required this.daysSinceStart,
  });
}
