import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as Math;
import '../models/group_gamification_models.dart';

/// グループ中心のゲーミフィケーション管理サービス
class GroupGamificationService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;
  static String? get _userDisplayName =>
      _auth.currentUser?.displayName ?? '匿名ユーザー';

  /// グループのゲーミフィケーションプロフィールを取得
  static Future<GroupGamificationProfile> getGroupProfile(
    String groupId,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final doc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('gamification')
          .doc('profile')
          .get();

      if (!doc.exists) {
        // 初回の場合は初期プロフィールを作成
        final initialProfile = GroupGamificationProfile.initial(groupId);
        await _saveGroupProfile(groupId, initialProfile);
        return initialProfile;
      }

      final data = doc.data()!;
      return GroupGamificationProfile.fromJson(data);
    } catch (e) {
      print('グループプロフィール取得エラー: $e');
      return GroupGamificationProfile.initial(groupId);
    }
  }

  /// グループのゲーミフィケーションプロフィールを保存
  static Future<void> _saveGroupProfile(
    String groupId,
    GroupGamificationProfile profile,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('gamification')
          .doc('profile')
          .set({
            ...profile.toJson(),
            'lastUpdatedBy': _uid,
            'lastUpdatedByName': _userDisplayName,
            'version': 1,
          });

      print(
        'グループプロフィールを保存しました: Level ${profile.level}, XP ${profile.experiencePoints}',
      );
    } catch (e) {
      print('グループプロフィール保存エラー: $e');
      rethrow;
    }
  }

  /// 出勤記録の経験値を追加
  static Future<GroupActivityResult> recordAttendance(String groupId) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      // 今日既に記録済みかチェック
      final today = DateTime.now();
      final dateKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final attendanceDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('daily_activities')
          .doc('attendance')
          .collection(dateKey)
          .doc(_uid)
          .get();

      if (attendanceDoc.exists) {
        return GroupActivityResult(
          success: false,
          message: '今日は既に出勤を記録済みです',
          levelUp: false,
          newBadges: [],
          experienceGained: 0,
          newLevel: 0,
        );
      }

      // 出勤記録を保存
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('daily_activities')
          .doc('attendance')
          .collection(dateKey)
          .doc(_uid)
          .set({
            'userId': _uid,
            'userName': _userDisplayName,
            'recordedAt': FieldValue.serverTimestamp(),
          });

      // 経験値を追加してプロフィールを更新
      final reward = GroupActivityReward.attendance();
      return await _addExperienceAndUpdateProfile(groupId, reward);
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
    }
  }

  /// 焙煎記録の経験値を追加
  static Future<GroupActivityResult> recordRoasting(
    String groupId,
    double minutes,
  ) async {
    if (_uid == null) throw Exception('未ログイン');
    if (minutes <= 0) {
      return GroupActivityResult(
        success: false,
        message: '焙煎時間が不正です',
        levelUp: false,
        newBadges: [],
        experienceGained: 0,
        newLevel: 0,
      );
    }

    try {
      final reward = GroupActivityReward.roasting(minutes);
      return await _addExperienceAndUpdateProfile(groupId, reward);
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
    }
  }

  /// ドリップパック記録の経験値を追加
  static Future<GroupActivityResult> recordDripPack(
    String groupId,
    int count,
  ) async {
    if (_uid == null) throw Exception('未ログイン');
    if (count <= 0) {
      return GroupActivityResult(
        success: false,
        message: 'ドリップパック数が不正です',
        levelUp: false,
        newBadges: [],
        experienceGained: 0,
        newLevel: 0,
      );
    }

    try {
      final reward = GroupActivityReward.dripPack(count);
      return await _addExperienceAndUpdateProfile(groupId, reward);
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
    }
  }

  /// テイスティング記録の経験値を追加
  static Future<GroupActivityResult> recordTasting(String groupId) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final reward = GroupActivityReward.tasting();
      return await _addExperienceAndUpdateProfile(groupId, reward);
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
    }
  }

  /// 作業進捗記録の経験値を追加
  static Future<GroupActivityResult> recordWorkProgress(String groupId) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final reward = GroupActivityReward.workProgress();
      return await _addExperienceAndUpdateProfile(groupId, reward);
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
    }
  }

  /// 経験値を追加してプロフィールを更新する共通メソッド
  static Future<GroupActivityResult> _addExperienceAndUpdateProfile(
    String groupId,
    GroupActivityReward reward,
  ) async {
    try {
      // 現在のプロフィールを取得
      final currentProfile = await getGroupProfile(groupId);

      // 新しい経験値を計算
      final newExperiencePoints =
          currentProfile.experiencePoints + reward.experiencePoints;

      // レベルアップチェック
      final newLevel = _calculateLevelFromExperience(newExperiencePoints);
      final levelUp = newLevel > currentProfile.level;

      // 統計情報を更新
      final updatedStats = await _updateGroupStats(
        groupId,
        currentProfile.stats,
        reward,
      );

      // 新しいバッジをチェック
      final newBadges = _checkNewBadges(currentProfile, updatedStats);

      // プロフィールを更新
      final updatedProfile = currentProfile.copyWith(
        experiencePoints: newExperiencePoints,
        level: newLevel,
        badges: [...currentProfile.badges, ...newBadges],
        stats: updatedStats,
        lastUpdated: DateTime.now(),
      );

      await _saveGroupProfile(groupId, updatedProfile);

      return GroupActivityResult(
        success: true,
        message: reward.description,
        levelUp: levelUp,
        newBadges: newBadges,
        experienceGained: reward.experiencePoints,
        newLevel: newLevel,
      );
    } catch (e) {
      print('経験値追加エラー: $e');
      rethrow;
    }
  }

  /// 経験値からレベルを計算
  static int _calculateLevelFromExperience(int experience) {
    int level = 1;
    while (level < 9999) {
      final requiredXP = _calculateRequiredXP(level + 1);
      if (experience < requiredXP) break;
      level++;
    }
    return level;
  }

  /// レベルに必要な経験値を計算（緩やかなスケーリング）
  static int _calculateRequiredXP(int level) {
    if (level <= 1) return 0;
    // 序盤はサクサク上がるように設計：基本XP * (レベル^1.5)
    return (50 * level * Math.pow(level, 0.5)).round();
  }

  /// グループ統計情報を更新
  static Future<GroupStats> _updateGroupStats(
    String groupId,
    GroupStats currentStats,
    GroupActivityReward reward,
  ) async {
    // 各種アクティビティのカウントを更新
    final now = DateTime.now();

    GroupStats updatedStats = currentStats.copyWith(lastActivityDate: now);

    // 報酬の種類に応じて統計を更新
    switch (reward.description) {
      case '出勤記録で+10XP獲得！':
        updatedStats = updatedStats.copyWith(
          totalAttendanceDays: updatedStats.totalAttendanceDays + 1,
        );
        break;
      case String description when description.contains('焙煎記録'):
        final minutes = reward.experiencePoints.toDouble(); // XP = 分数
        updatedStats = updatedStats.copyWith(
          totalRoastTimeMinutes: updatedStats.totalRoastTimeMinutes + minutes,
          totalRoastSessions: updatedStats.totalRoastSessions + 1,
        );
        break;
      case String description when description.contains('ドリップパック記録'):
        final count = (reward.experiencePoints / 0.5)
            .round(); // XP = count * 0.5
        updatedStats = updatedStats.copyWith(
          totalDripPackCount: updatedStats.totalDripPackCount + count,
        );
        break;
      case 'テイスティング記録で+5XP獲得！':
        updatedStats = updatedStats.copyWith(
          totalTastingRecords: updatedStats.totalTastingRecords + 1,
        );
        break;
      case '作業進捗更新で+3XP獲得！':
        updatedStats = updatedStats.copyWith(
          totalWorkProgressCompleted:
              updatedStats.totalWorkProgressCompleted + 1,
        );
        break;
    }

    // メンバー別貢献度を更新
    final updatedContributions = Map<String, int>.from(
      updatedStats.memberContributions,
    );
    final currentUserContribution = updatedContributions[_uid!] ?? 0;
    updatedContributions[_uid!] =
        currentUserContribution + reward.experiencePoints;

    return updatedStats.copyWith(memberContributions: updatedContributions);
  }

  /// 新しいバッジをチェック
  static List<GroupBadge> _checkNewBadges(
    GroupGamificationProfile currentProfile,
    GroupStats newStats,
  ) {
    final newBadges = <GroupBadge>[];
    final earnedBadgeIds = currentProfile.badges.map((b) => b.id).toSet();

    for (final condition in GroupBadgeConditions.conditions) {
      if (!earnedBadgeIds.contains(condition.badgeId) &&
          condition.checkCondition(newStats)) {
        newBadges.add(condition.createBadge(_uid!, _userDisplayName!));
      }
    }

    return newBadges;
  }

  /// グループプロフィールの変更を監視
  static Stream<GroupGamificationProfile> watchGroupProfile(String groupId) {
    if (_uid == null) {
      return Stream.value(GroupGamificationProfile.initial(groupId));
    }

    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('gamification')
        .doc('profile')
        .snapshots()
        .map((doc) {
          if (!doc.exists) return GroupGamificationProfile.initial(groupId);
          return GroupGamificationProfile.fromJson(doc.data()!);
        });
  }

  /// 次の獲得可能なバッジを取得
  static List<GroupBadgeCondition> getUpcomingBadges(
    GroupGamificationProfile profile, {
    int limit = 3,
  }) {
    final earnedBadgeIds = profile.badges.map((b) => b.id).toSet();

    return GroupBadgeConditions.conditions
        .where((condition) => !earnedBadgeIds.contains(condition.badgeId))
        .take(limit)
        .toList();
  }

  /// バッジ獲得の進捗率を計算
  static double getBadgeProgress(
    GroupBadgeCondition condition,
    GroupGamificationProfile profile,
  ) {
    final stats = profile.stats;

    switch (condition.badgeId) {
      case 'group_roast_50h':
        return (stats.totalRoastTimeHours / 50).clamp(0.0, 1.0);
      case 'group_roast_100h':
        return (stats.totalRoastTimeHours / 100).clamp(0.0, 1.0);
      case 'group_roast_500h':
        return (stats.totalRoastTimeHours / 500).clamp(0.0, 1.0);
      case 'group_attendance_100':
        return (stats.totalAttendanceDays / 100).clamp(0.0, 1.0);
      case 'group_attendance_300':
        return (stats.totalAttendanceDays / 300).clamp(0.0, 1.0);
      case 'group_drip_10000':
        return (stats.totalDripPackCount / 10000).clamp(0.0, 1.0);
      case 'group_drip_50000':
        return (stats.totalDripPackCount / 50000).clamp(0.0, 1.0);
      case 'group_active_30days':
        return (stats.daysSinceStart / 30).clamp(0.0, 1.0);
      case 'group_active_365days':
        return (stats.daysSinceStart / 365).clamp(0.0, 1.0);
      default:
        return 0.0;
    }
  }

  /// グループ統計の詳細情報を取得
  static Future<Map<String, dynamic>> getGroupDetailedStats(
    String groupId,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final profile = await getGroupProfile(groupId);
      final stats = profile.stats;

      return {
        'profile': profile,
        'totalMembers': stats.memberContributions.length,
        'averageContribution': stats.memberContributions.isEmpty
            ? 0.0
            : stats.memberContributions.values.reduce((a, b) => a + b) /
                  stats.memberContributions.length,
        'topContributor': _getTopContributor(stats.memberContributions),
        'badgeCount': profile.badges.length,
        'availableBadges': GroupBadgeConditions.conditions.length,
        'completionRate':
            profile.badges.length / GroupBadgeConditions.conditions.length,
      };
    } catch (e) {
      print('詳細統計取得エラー: $e');
      return {};
    }
  }

  /// 最大貢献者を取得
  static Map<String, dynamic> _getTopContributor(
    Map<String, int> contributions,
  ) {
    if (contributions.isEmpty) return {'userId': '', 'contribution': 0};

    final sorted = contributions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {'userId': sorted.first.key, 'contribution': sorted.first.value};
  }

  /// デバッグ用：グループプロフィール情報を表示
  static Future<void> debugPrintGroupProfile(String groupId) async {
    try {
      final profile = await getGroupProfile(groupId);
      print('=== グループゲーミフィケーションプロフィール ===');
      print('グループID: ${profile.groupId}');
      print('レベル: ${profile.level} (${profile.displayTitle})');
      print('経験値: ${profile.experiencePoints}');
      print('次のレベルまで: ${profile.experienceToNextLevel}XP');
      print('出勤累計: ${profile.stats.totalAttendanceDays}日');
      print('焙煎時間: ${profile.stats.totalRoastTimeHours.toStringAsFixed(1)}時間');
      print('ドリップパック: ${profile.stats.totalDripPackCount}個');
      print('バッジ数: ${profile.badges.length}');
      if (profile.badges.isNotEmpty) {
        print('獲得バッジ:');
        for (final badge in profile.badges) {
          print(
            '  - ${badge.name}: ${badge.description} (by ${badge.earnedByUserName})',
          );
        }
      }
      print('===============================');
    } catch (e) {
      print('デバッグ情報取得エラー: $e');
    }
  }
}
