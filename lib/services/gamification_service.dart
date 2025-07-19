import 'package:flutter/material.dart';
import '../models/gamification_models.dart';

/// ゲーミフィケーション機能のサービスクラス
class GamificationService {
  static const String _keyUserProfile = 'gamification_user_profile';

  /// バッジ獲得条件の定義（6段階制）
  static final List<BadgeCondition> badgeConditions = [
    // 焙煎時間関連バッジ（6段階）
    BadgeCondition(
      badgeId: 'roast_1h',
      name: '新人ロースター',
      description: '焙煎時間1時間達成',
      icon: Icons.local_fire_department_outlined,
      color: Colors.orange.shade300,
      checkCondition: (profile) => profile.stats.totalRoastTimeHours >= 1,
    ),
    BadgeCondition(
      badgeId: 'roast_5h',
      name: '焙煎見習い',
      description: '焙煎時間5時間達成',
      icon: Icons.local_fire_department,
      color: Colors.orange.shade500,
      checkCondition: (profile) => profile.stats.totalRoastTimeHours >= 5,
    ),
    BadgeCondition(
      badgeId: 'roast_20h',
      name: '焙煎職人',
      description: '焙煎時間20時間達成',
      icon: Icons.whatshot,
      color: Colors.deepOrange.shade600,
      checkCondition: (profile) => profile.stats.totalRoastTimeHours >= 20,
    ),
    BadgeCondition(
      badgeId: 'roast_50h',
      name: '焙煎マスター',
      description: '焙煎時間50時間達成',
      icon: Icons.fireplace,
      color: Colors.red.shade700,
      checkCondition: (profile) => profile.stats.totalRoastTimeHours >= 50,
    ),
    BadgeCondition(
      badgeId: 'roast_150h',
      name: '焙煎クラフター',
      description: '焙煎時間150時間達成',
      icon: Icons.auto_awesome,
      color: Colors.purple.shade600,
      checkCondition: (profile) => profile.stats.totalRoastTimeHours >= 150,
    ),
    BadgeCondition(
      badgeId: 'roast_500h',
      name: '焙煎レジェンド',
      description: '焙煎時間500時間達成',
      icon: Icons.military_tech,
      color: Colors.amber.shade700,
      checkCondition: (profile) => profile.stats.totalRoastTimeHours >= 500,
    ),

    // ドリップパック作成数バッジ（6段階）
    BadgeCondition(
      badgeId: 'drip_300',
      name: 'パック組立員',
      description: '300個作成達成',
      icon: Icons.coffee_outlined,
      color: Colors.brown.shade300,
      checkCondition: (profile) => profile.stats.dripPackCount >= 300,
    ),
    BadgeCondition(
      badgeId: 'drip_1000',
      name: 'ドリップメーカー',
      description: '1000個作成達成',
      icon: Icons.coffee,
      color: Colors.brown.shade500,
      checkCondition: (profile) => profile.stats.dripPackCount >= 1000,
    ),
    BadgeCondition(
      badgeId: 'drip_5000',
      name: 'パック職人',
      description: '5000個作成達成',
      icon: Icons.local_cafe,
      color: Colors.brown.shade700,
      checkCondition: (profile) => profile.stats.dripPackCount >= 5000,
    ),
    BadgeCondition(
      badgeId: 'drip_15000',
      name: '生産ラインの王',
      description: '15000個作成達成',
      icon: Icons.emoji_food_beverage,
      color: Colors.indigo.shade600,
      checkCondition: (profile) => profile.stats.dripPackCount >= 15000,
    ),
    BadgeCondition(
      badgeId: 'drip_50000',
      name: 'ドリップマスター',
      description: '50000個作成達成',
      icon: Icons.local_drink,
      color: Colors.purple.shade700,
      checkCondition: (profile) => profile.stats.dripPackCount >= 50000,
    ),
    BadgeCondition(
      badgeId: 'drip_150000',
      name: '永久ドリッパー',
      description: '150000個作成達成',
      icon: Icons.stars,
      color: Colors.amber.shade800,
      checkCondition: (profile) => profile.stats.dripPackCount >= 150000,
    ),

    // 出勤バッジ（6段階）
    BadgeCondition(
      badgeId: 'work_5',
      name: '新入りスタッフ',
      description: '5日出勤達成',
      icon: Icons.person_add_outlined,
      color: Colors.green.shade300,
      checkCondition: (profile) => profile.stats.attendanceDays >= 5,
    ),
    BadgeCondition(
      badgeId: 'work_20',
      name: '月間皆勤賞',
      description: '20日出勤達成',
      icon: Icons.person,
      color: Colors.blue.shade400,
      checkCondition: (profile) => profile.stats.attendanceDays >= 20,
    ),
    BadgeCondition(
      badgeId: 'work_60',
      name: 'ロースター常連',
      description: '60日出勤達成',
      icon: Icons.star_border,
      color: Colors.cyan.shade600,
      checkCondition: (profile) => profile.stats.attendanceDays >= 60,
    ),
    BadgeCondition(
      badgeId: 'work_200',
      name: '出勤王',
      description: '200日出勤達成',
      icon: Icons.star,
      color: Colors.orange.shade600,
      checkCondition: (profile) => profile.stats.attendanceDays >= 200,
    ),
    BadgeCondition(
      badgeId: 'work_500',
      name: '勤務の化身',
      description: '500日出勤達成',
      icon: Icons.workspace_premium,
      color: Colors.purple.shade600,
      checkCondition: (profile) => profile.stats.attendanceDays >= 500,
    ),
    BadgeCondition(
      badgeId: 'work_2000',
      name: '出勤神',
      description: '2000日出勤達成',
      icon: Icons.emoji_events,
      color: Colors.amber.shade700,
      checkCondition: (profile) => profile.stats.attendanceDays >= 2000,
    ),

    // 総合バッジ（新設）
    BadgeCondition(
      badgeId: 'balanced_starter',
      name: 'バランス新人',
      description: '出勤20日、焙煎10時間、ドリップ500個を全て達成',
      icon: Icons.balance,
      color: Colors.teal.shade500,
      checkCondition: (profile) =>
          profile.stats.attendanceDays >= 20 &&
          profile.stats.totalRoastTimeHours >= 10 &&
          profile.stats.dripPackCount >= 500,
    ),
    BadgeCondition(
      badgeId: 'balanced_master',
      name: 'バランスマスター',
      description: '出勤100日、焙煎50時間、ドリップ5000個を全て達成',
      icon: Icons.all_inclusive,
      color: Colors.indigo.shade600,
      checkCondition: (profile) =>
          profile.stats.attendanceDays >= 100 &&
          profile.stats.totalRoastTimeHours >= 50 &&
          profile.stats.dripPackCount >= 5000,
    ),
    BadgeCondition(
      badgeId: 'coffee_legend',
      name: 'コーヒーレジェンド',
      description: '出勤500日、焙煎200時間、ドリップ25000個を全て達成',
      icon: Icons.auto_awesome,
      color: Colors.amber.shade800,
      checkCondition: (profile) =>
          profile.stats.attendanceDays >= 500 &&
          profile.stats.totalRoastTimeHours >= 200 &&
          profile.stats.dripPackCount >= 25000,
    ),

    // レベル関連バッジ（拡張）
    BadgeCondition(
      badgeId: 'level_5',
      name: 'レベル5到達',
      description: 'レベル5に到達',
      icon: Icons.trending_up,
      color: Colors.lightGreen,
      checkCondition: (profile) => profile.level >= 5,
    ),
    BadgeCondition(
      badgeId: 'level_10',
      name: 'レベル10到達',
      description: 'レベル10に到達',
      icon: Icons.trending_up,
      color: Colors.teal,
      checkCondition: (profile) => profile.level >= 10,
    ),
    BadgeCondition(
      badgeId: 'level_25',
      name: 'レベル25到達',
      description: 'レベル25に到達',
      icon: Icons.trending_up,
      color: Colors.cyan,
      checkCondition: (profile) => profile.level >= 25,
    ),
    BadgeCondition(
      badgeId: 'level_50',
      name: 'レベル50到達',
      description: 'レベル50に到達',
      icon: Icons.trending_up,
      color: Colors.pink,
      checkCondition: (profile) => profile.level >= 50,
    ),
    BadgeCondition(
      badgeId: 'level_100',
      name: 'レベル100到達',
      description: 'レベル100に到達',
      icon: Icons.trending_up,
      color: Colors.deepPurple,
      checkCondition: (profile) => profile.level >= 100,
    ),
    BadgeCondition(
      badgeId: 'level_200',
      name: 'レベル200到達',
      description: 'レベル200に到達',
      icon: Icons.trending_up,
      color: Colors.amber,
      checkCondition: (profile) => profile.level >= 200,
    ),

    // 特別バッジ（時間効率系）
    BadgeCondition(
      badgeId: 'early_bird',
      name: '早起きロースター',
      description: '朝の時間帯に多くの活動を実施',
      icon: Icons.wb_sunny,
      color: Colors.yellow.shade600,
      checkCondition: (profile) => profile.stats.attendanceDays >= 30,
    ),
    BadgeCondition(
      badgeId: 'consistent_worker',
      name: '継続の力',
      description: '連続30日間の活動記録',
      icon: Icons.repeat,
      color: Colors.blue.shade600,
      checkCondition: (profile) => profile.stats.attendanceDays >= 30,
    ),
  ];

  /// 経験値を追加し、レベルアップをチェック
  static UserProfile addExperience(
    UserProfile currentProfile,
    ActivityReward reward,
  ) {
    final newXP = currentProfile.experiencePoints + reward.experiencePoints;
    final newLevel = _calculateLevel(newXP);

    return currentProfile.copyWith(experiencePoints: newXP, level: newLevel);
  }

  /// 経験値からレベルを計算
  static int _calculateLevel(int totalXP) {
    int level = 1;
    while (_getRequiredXPForLevel(level + 1) <= totalXP) {
      level++;
    }
    return level;
  }

  /// 指定レベルに必要な経験値を計算
  static int _getRequiredXPForLevel(int level) {
    if (level <= 1) return 0;
    return (100 * (level - 1) * (level - 1) * 1.2).round();
  }

  /// 出勤を記録し、経験値を追加
  static UserProfile recordAttendance(UserProfile currentProfile) {
    final updatedStats = currentProfile.stats.copyWith(
      attendanceDays: currentProfile.stats.attendanceDays + 1,
      lastActivityDate: DateTime.now(),
    );

    final profileWithStats = currentProfile.copyWith(stats: updatedStats);
    return addExperience(profileWithStats, ActivityReward.attendance());
  }

  /// 焙煎を記録し、経験値を追加
  static UserProfile recordRoasting(
    UserProfile currentProfile,
    double minutes,
  ) {
    final updatedStats = currentProfile.stats.copyWith(
      totalRoastTimeMinutes:
          currentProfile.stats.totalRoastTimeMinutes + minutes,
      totalRoastSessions: currentProfile.stats.totalRoastSessions + 1,
      lastActivityDate: DateTime.now(),
    );

    final profileWithStats = currentProfile.copyWith(stats: updatedStats);
    return addExperience(profileWithStats, ActivityReward.roasting(minutes));
  }

  /// ドリップパックを記録し、経験値を追加
  static UserProfile recordDripPack(UserProfile currentProfile, int count) {
    final updatedStats = currentProfile.stats.copyWith(
      dripPackCount: currentProfile.stats.dripPackCount + count,
      lastActivityDate: DateTime.now(),
    );

    final profileWithStats = currentProfile.copyWith(stats: updatedStats);
    return addExperience(profileWithStats, ActivityReward.dripPack(count));
  }

  /// 新しく獲得したバッジをチェック
  static List<UserBadge> checkNewBadges(
    UserProfile oldProfile,
    UserProfile newProfile,
  ) {
    final newBadges = <UserBadge>[];
    final earnedBadgeIds = oldProfile.badges.map((b) => b.id).toSet();

    for (final condition in badgeConditions) {
      // まだ獲得していないバッジで、条件を満たしているかチェック
      if (!earnedBadgeIds.contains(condition.badgeId) &&
          condition.checkCondition(newProfile)) {
        newBadges.add(condition.createBadge());
      }
    }

    return newBadges;
  }

  /// バッジを追加したプロフィールを返す
  static UserProfile addBadges(UserProfile profile, List<UserBadge> newBadges) {
    if (newBadges.isEmpty) return profile;

    final allBadges = List<UserBadge>.from(profile.badges)..addAll(newBadges);
    return profile.copyWith(badges: allBadges);
  }

  /// レベルアップした場合のチェック
  static bool didLevelUp(UserProfile oldProfile, UserProfile newProfile) {
    return newProfile.level > oldProfile.level;
  }

  /// レベルタイトルを取得
  static String getLevelTitle(int level) {
    if (level < 5) return '見習いロースター';
    if (level < 10) return '駆け出しロースター';
    if (level < 20) return '一人前ロースター';
    if (level < 30) return '熟練ロースター';
    if (level < 50) return 'マスターロースター';
    if (level < 75) return 'レジェンドロースター';
    return 'グランドマスター';
  }

  /// 進捗に応じた色を取得
  static Color getLevelColor(int level) {
    if (level < 5) return Colors.grey;
    if (level < 10) return Colors.green;
    if (level < 20) return Colors.blue;
    if (level < 30) return Colors.purple;
    if (level < 50) return Colors.orange;
    if (level < 75) return Colors.red;
    return Colors.amber;
  }

  /// 次の獲得可能なバッジを取得（進捗表示用）
  static List<BadgeCondition> getUpcomingBadges(
    UserProfile profile, {
    int limit = 3,
  }) {
    final earnedBadgeIds = profile.badges.map((b) => b.id).toSet();

    return badgeConditions
        .where((condition) => !earnedBadgeIds.contains(condition.badgeId))
        .take(limit)
        .toList();
  }

  /// バッジ獲得の進捗率を計算（0.0 - 1.0）
  static double getBadgeProgress(
    BadgeCondition condition,
    UserProfile profile,
  ) {
    switch (condition.badgeId) {
      case 'newcomer':
        return (profile.stats.attendanceDays / 10).clamp(0.0, 1.0);
      case 'regular':
        return (profile.stats.attendanceDays / 30).clamp(0.0, 1.0);
      case 'veteran':
        return (profile.stats.attendanceDays / 100).clamp(0.0, 1.0);
      case 'master_attendee':
        return (profile.stats.attendanceDays / 200).clamp(0.0, 1.0);
      case 'time_keeper':
        return (profile.stats.totalRoastTimeHours / 10).clamp(0.0, 1.0);
      case 'roast_master':
        return (profile.stats.totalRoastTimeHours / 50).clamp(0.0, 1.0);
      case 'roast_legend':
        return (profile.stats.totalRoastTimeHours / 100).clamp(0.0, 1.0);
      case 'drip_starter':
        return (profile.stats.dripPackCount / 20).clamp(0.0, 1.0);
      case 'drip_master':
        return (profile.stats.dripPackCount / 50).clamp(0.0, 1.0);
      case 'drip_expert':
        return (profile.stats.dripPackCount / 200).clamp(0.0, 1.0);
      case 'level_10':
        return (profile.level / 10).clamp(0.0, 1.0);
      case 'level_25':
        return (profile.level / 25).clamp(0.0, 1.0);
      case 'level_50':
        return (profile.level / 50).clamp(0.0, 1.0);
      // 焙煎時間バッジ
      case 'roast_1h':
        return (profile.stats.totalRoastTimeHours / 1).clamp(0.0, 1.0);
      case 'roast_5h':
        return (profile.stats.totalRoastTimeHours / 5).clamp(0.0, 1.0);
      case 'roast_20h':
        return (profile.stats.totalRoastTimeHours / 20).clamp(0.0, 1.0);
      case 'roast_50h':
        return (profile.stats.totalRoastTimeHours / 50).clamp(0.0, 1.0);
      case 'roast_150h':
        return (profile.stats.totalRoastTimeHours / 150).clamp(0.0, 1.0);
      case 'roast_500h':
        return (profile.stats.totalRoastTimeHours / 500).clamp(0.0, 1.0);

      // ドリップパックバッジ
      case 'drip_300':
        return (profile.stats.dripPackCount / 300).clamp(0.0, 1.0);
      case 'drip_1000':
        return (profile.stats.dripPackCount / 1000).clamp(0.0, 1.0);
      case 'drip_5000':
        return (profile.stats.dripPackCount / 5000).clamp(0.0, 1.0);
      case 'drip_15000':
        return (profile.stats.dripPackCount / 15000).clamp(0.0, 1.0);
      case 'drip_50000':
        return (profile.stats.dripPackCount / 50000).clamp(0.0, 1.0);
      case 'drip_150000':
        return (profile.stats.dripPackCount / 150000).clamp(0.0, 1.0);

      // 出勤バッジ
      case 'work_5':
        return (profile.stats.attendanceDays / 5).clamp(0.0, 1.0);
      case 'work_20':
        return (profile.stats.attendanceDays / 20).clamp(0.0, 1.0);
      case 'work_60':
        return (profile.stats.attendanceDays / 60).clamp(0.0, 1.0);
      case 'work_200':
        return (profile.stats.attendanceDays / 200).clamp(0.0, 1.0);
      case 'work_500':
        return (profile.stats.attendanceDays / 500).clamp(0.0, 1.0);
      case 'work_2000':
        return (profile.stats.attendanceDays / 2000).clamp(0.0, 1.0);

      // レベルバッジ
      case 'level_5':
        return (profile.level / 5).clamp(0.0, 1.0);
      case 'level_100':
        return (profile.level / 100).clamp(0.0, 1.0);
      case 'level_200':
        return (profile.level / 200).clamp(0.0, 1.0);

      // 総合バッジ
      case 'balanced_starter':
        final attendanceProgress = (profile.stats.attendanceDays / 20).clamp(
          0.0,
          1.0,
        );
        final roastProgress = (profile.stats.totalRoastTimeHours / 10).clamp(
          0.0,
          1.0,
        );
        final dripProgress = (profile.stats.dripPackCount / 500).clamp(
          0.0,
          1.0,
        );
        return (attendanceProgress + roastProgress + dripProgress) / 3;
      case 'balanced_master':
        final attendanceProgress = (profile.stats.attendanceDays / 100).clamp(
          0.0,
          1.0,
        );
        final roastProgress = (profile.stats.totalRoastTimeHours / 50).clamp(
          0.0,
          1.0,
        );
        final dripProgress = (profile.stats.dripPackCount / 5000).clamp(
          0.0,
          1.0,
        );
        return (attendanceProgress + roastProgress + dripProgress) / 3;
      case 'coffee_legend':
        final attendanceProgress = (profile.stats.attendanceDays / 500).clamp(
          0.0,
          1.0,
        );
        final roastProgress = (profile.stats.totalRoastTimeHours / 200).clamp(
          0.0,
          1.0,
        );
        final dripProgress = (profile.stats.dripPackCount / 25000).clamp(
          0.0,
          1.0,
        );
        return (attendanceProgress + roastProgress + dripProgress) / 3;

      default:
        return condition.checkCondition(profile) ? 1.0 : 0.0;
    }
  }

  /// バッジの進捗詳細を取得
  static BadgeProgressInfo getBadgeProgressInfo(
    BadgeCondition condition,
    UserProfile profile,
  ) {
    switch (condition.badgeId) {
      // 焙煎時間バッジ
      case 'roast_1h':
        return BadgeProgressInfo(
          current: profile.stats.totalRoastTimeHours.round(),
          target: 1,
          unit: '時間',
          label: '焙煎時間',
        );
      case 'roast_5h':
        return BadgeProgressInfo(
          current: profile.stats.totalRoastTimeHours.round(),
          target: 5,
          unit: '時間',
          label: '焙煎時間',
        );
      case 'roast_20h':
        return BadgeProgressInfo(
          current: profile.stats.totalRoastTimeHours.round(),
          target: 20,
          unit: '時間',
          label: '焙煎時間',
        );
      case 'roast_50h':
        return BadgeProgressInfo(
          current: profile.stats.totalRoastTimeHours.round(),
          target: 50,
          unit: '時間',
          label: '焙煎時間',
        );
      case 'roast_150h':
        return BadgeProgressInfo(
          current: profile.stats.totalRoastTimeHours.round(),
          target: 150,
          unit: '時間',
          label: '焙煎時間',
        );
      case 'roast_500h':
        return BadgeProgressInfo(
          current: profile.stats.totalRoastTimeHours.round(),
          target: 500,
          unit: '時間',
          label: '焙煎時間',
        );

      // ドリップパックバッジ
      case 'drip_300':
        return BadgeProgressInfo(
          current: profile.stats.dripPackCount,
          target: 300,
          unit: '個',
          label: 'ドリップパック',
        );
      case 'drip_1000':
        return BadgeProgressInfo(
          current: profile.stats.dripPackCount,
          target: 1000,
          unit: '個',
          label: 'ドリップパック',
        );
      case 'drip_5000':
        return BadgeProgressInfo(
          current: profile.stats.dripPackCount,
          target: 5000,
          unit: '個',
          label: 'ドリップパック',
        );
      case 'drip_15000':
        return BadgeProgressInfo(
          current: profile.stats.dripPackCount,
          target: 15000,
          unit: '個',
          label: 'ドリップパック',
        );
      case 'drip_50000':
        return BadgeProgressInfo(
          current: profile.stats.dripPackCount,
          target: 50000,
          unit: '個',
          label: 'ドリップパック',
        );
      case 'drip_150000':
        return BadgeProgressInfo(
          current: profile.stats.dripPackCount,
          target: 150000,
          unit: '個',
          label: 'ドリップパック',
        );

      // 出勤バッジ
      case 'work_5':
        return BadgeProgressInfo(
          current: profile.stats.attendanceDays,
          target: 5,
          unit: '日',
          label: '出勤',
        );
      case 'work_20':
        return BadgeProgressInfo(
          current: profile.stats.attendanceDays,
          target: 20,
          unit: '日',
          label: '出勤',
        );
      case 'work_60':
        return BadgeProgressInfo(
          current: profile.stats.attendanceDays,
          target: 60,
          unit: '日',
          label: '出勤',
        );
      case 'work_200':
        return BadgeProgressInfo(
          current: profile.stats.attendanceDays,
          target: 200,
          unit: '日',
          label: '出勤',
        );
      case 'work_500':
        return BadgeProgressInfo(
          current: profile.stats.attendanceDays,
          target: 500,
          unit: '日',
          label: '出勤',
        );
      case 'work_2000':
        return BadgeProgressInfo(
          current: profile.stats.attendanceDays,
          target: 2000,
          unit: '日',
          label: '出勤',
        );

      // レベルバッジ
      case 'level_5':
        return BadgeProgressInfo(
          current: profile.level,
          target: 5,
          unit: '',
          label: 'レベル',
        );
      case 'level_10':
        return BadgeProgressInfo(
          current: profile.level,
          target: 10,
          unit: '',
          label: 'レベル',
        );
      case 'level_25':
        return BadgeProgressInfo(
          current: profile.level,
          target: 25,
          unit: '',
          label: 'レベル',
        );
      case 'level_50':
        return BadgeProgressInfo(
          current: profile.level,
          target: 50,
          unit: '',
          label: 'レベル',
        );
      case 'level_100':
        return BadgeProgressInfo(
          current: profile.level,
          target: 100,
          unit: '',
          label: 'レベル',
        );
      case 'level_200':
        return BadgeProgressInfo(
          current: profile.level,
          target: 200,
          unit: '',
          label: 'レベル',
        );

      // 総合バッジ（複合条件のため簡易表示）
      case 'balanced_starter':
        return _getCompositeProgress(profile, [
          ('出勤', profile.stats.attendanceDays, 20, '日'),
          ('焙煎', profile.stats.totalRoastTimeHours.round(), 10, '時間'),
          ('ドリップ', profile.stats.dripPackCount, 500, '個'),
        ]);
      case 'balanced_master':
        return _getCompositeProgress(profile, [
          ('出勤', profile.stats.attendanceDays, 100, '日'),
          ('焙煎', profile.stats.totalRoastTimeHours.round(), 50, '時間'),
          ('ドリップ', profile.stats.dripPackCount, 5000, '個'),
        ]);
      case 'coffee_legend':
        return _getCompositeProgress(profile, [
          ('出勤', profile.stats.attendanceDays, 500, '日'),
          ('焙煎', profile.stats.totalRoastTimeHours.round(), 200, '時間'),
          ('ドリップ', profile.stats.dripPackCount, 25000, '個'),
        ]);

      default:
        return BadgeProgressInfo(
          current: condition.checkCondition(profile) ? 1 : 0,
          target: 1,
          unit: '',
          label: '達成',
        );
    }
  }

  /// 複合条件バッジの進捗を計算
  static BadgeProgressInfo _getCompositeProgress(
    UserProfile profile,
    List<(String, int, int, String)> requirements,
  ) {
    final achievedCount = requirements.where((req) => req.$2 >= req.$3).length;
    return BadgeProgressInfo(
      current: achievedCount,
      target: requirements.length,
      unit: '条件',
      label: '達成',
    );
  }
}

/// バッジ進捗情報
class BadgeProgressInfo {
  final int current;
  final int target;
  final String unit;
  final String label;

  const BadgeProgressInfo({
    required this.current,
    required this.target,
    required this.unit,
    required this.label,
  });

  double get progress => (current / target).clamp(0.0, 1.0);

  String get progressText {
    if (unit.isEmpty) {
      return '$current / $target';
    }
    return '$current$unit / $target$unit';
  }
}
