import 'package:flutter/material.dart';

/// ユーザーの称号（バッジ）を表すクラス
class UserBadge {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final DateTime earnedAt;

  const UserBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.earnedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon.codePoint,
      'color': color.value,
      'earnedAt': earnedAt.toIso8601String(),
    };
  }

  factory UserBadge.fromJson(Map<String, dynamic> json) {
    return UserBadge(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
      color: Color(json['color']),
      earnedAt: DateTime.parse(json['earnedAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserBadge && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// バッジ獲得条件を表すクラス
class BadgeCondition {
  final String badgeId;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool Function(UserProfile profile) checkCondition;

  const BadgeCondition({
    required this.badgeId,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.checkCondition,
  });

  UserBadge createBadge() {
    return UserBadge(
      id: badgeId,
      name: name,
      description: description,
      icon: icon,
      color: color,
      earnedAt: DateTime.now(),
    );
  }
}

/// ユーザープロフィール（経験値、レベル、統計情報）
class UserProfile {
  final int experiencePoints;
  final int level;
  final List<UserBadge> badges;
  final UserStats stats;

  const UserProfile({
    required this.experiencePoints,
    required this.level,
    required this.badges,
    required this.stats,
  });

  /// 次のレベルまでに必要な経験値
  int get experienceToNextLevel {
    final nextLevelXP = _calculateRequiredXP(level + 1);
    final currentLevelXP = _calculateRequiredXP(level);
    return nextLevelXP - experiencePoints;
  }

  /// 現在のレベルでの進行度（0.0 - 1.0）
  double get levelProgress {
    final currentLevelXP = _calculateRequiredXP(level);
    final nextLevelXP = _calculateRequiredXP(level + 1);
    final progressXP = experiencePoints - currentLevelXP;
    final totalLevelXP = nextLevelXP - currentLevelXP;
    return (progressXP / totalLevelXP).clamp(0.0, 1.0);
  }

  /// 最新の称号を取得
  UserBadge? get latestBadge {
    if (badges.isEmpty) return null;
    return badges.reduce((a, b) => a.earnedAt.isAfter(b.earnedAt) ? a : b);
  }

  /// レベルに必要な経験値を計算（指数関数的増加）
  static int _calculateRequiredXP(int level) {
    if (level <= 1) return 0;
    return (100 * (level - 1) * (level - 1) * 1.2).round();
  }

  UserProfile copyWith({
    int? experiencePoints,
    int? level,
    List<UserBadge>? badges,
    UserStats? stats,
  }) {
    return UserProfile(
      experiencePoints: experiencePoints ?? this.experiencePoints,
      level: level ?? this.level,
      badges: badges ?? this.badges,
      stats: stats ?? this.stats,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'experiencePoints': experiencePoints,
      'level': level,
      'badges': badges.map((badge) => badge.toJson()).toList(),
      'stats': stats.toJson(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      experiencePoints: json['experiencePoints'] ?? 0,
      level: json['level'] ?? 1,
      badges:
          (json['badges'] as List<dynamic>?)
              ?.map((badgeJson) => UserBadge.fromJson(badgeJson))
              .toList() ??
          [],
      stats: UserStats.fromJson(json['stats'] ?? {}),
    );
  }

  factory UserProfile.initial() {
    return UserProfile(
      experiencePoints: 0,
      level: 1,
      badges: [],
      stats: UserStats.initial(),
    );
  }
}

/// ユーザーの活動統計
class UserStats {
  final int attendanceDays;
  final double totalRoastTimeMinutes;
  final int dripPackCount;
  final int totalRoastSessions;
  final DateTime firstActivityDate;
  final DateTime lastActivityDate;

  const UserStats({
    required this.attendanceDays,
    required this.totalRoastTimeMinutes,
    required this.dripPackCount,
    required this.totalRoastSessions,
    required this.firstActivityDate,
    required this.lastActivityDate,
  });

  /// 総焙煎時間（時間単位）
  double get totalRoastTimeHours => totalRoastTimeMinutes / 60;

  /// 活動開始からの日数
  int get daysSinceStart {
    return DateTime.now().difference(firstActivityDate).inDays + 1;
  }

  UserStats copyWith({
    int? attendanceDays,
    double? totalRoastTimeMinutes,
    int? dripPackCount,
    int? totalRoastSessions,
    DateTime? firstActivityDate,
    DateTime? lastActivityDate,
  }) {
    return UserStats(
      attendanceDays: attendanceDays ?? this.attendanceDays,
      totalRoastTimeMinutes:
          totalRoastTimeMinutes ?? this.totalRoastTimeMinutes,
      dripPackCount: dripPackCount ?? this.dripPackCount,
      totalRoastSessions: totalRoastSessions ?? this.totalRoastSessions,
      firstActivityDate: firstActivityDate ?? this.firstActivityDate,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attendanceDays': attendanceDays,
      'totalRoastTimeMinutes': totalRoastTimeMinutes,
      'dripPackCount': dripPackCount,
      'totalRoastSessions': totalRoastSessions,
      'firstActivityDate': firstActivityDate.toIso8601String(),
      'lastActivityDate': lastActivityDate.toIso8601String(),
    };
  }

  factory UserStats.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return UserStats(
      attendanceDays: json['attendanceDays'] ?? 0,
      totalRoastTimeMinutes: (json['totalRoastTimeMinutes'] ?? 0.0).toDouble(),
      dripPackCount: json['dripPackCount'] ?? 0,
      totalRoastSessions: json['totalRoastSessions'] ?? 0,
      firstActivityDate: json['firstActivityDate'] != null
          ? DateTime.parse(json['firstActivityDate'])
          : now,
      lastActivityDate: json['lastActivityDate'] != null
          ? DateTime.parse(json['lastActivityDate'])
          : now,
    );
  }

  factory UserStats.initial() {
    final now = DateTime.now();
    return UserStats(
      attendanceDays: 0,
      totalRoastTimeMinutes: 0.0,
      dripPackCount: 0,
      totalRoastSessions: 0,
      firstActivityDate: now,
      lastActivityDate: now,
    );
  }
}

/// 活動の種類
enum ActivityType { attendance, roasting, dripPack }

/// 活動による経験値獲得
class ActivityReward {
  final ActivityType type;
  final int experiencePoints;
  final String description;

  const ActivityReward({
    required this.type,
    required this.experiencePoints,
    required this.description,
  });

  /// 経験値計算のルール
  static const Map<ActivityType, int> baseRewards = {
    ActivityType.attendance: 10, // 出勤1日 = 10XP
    ActivityType.roasting: 40, // 焙煎30分 = 20XP（後で時間で調整）
    ActivityType.dripPack: 5, // ドリップパック1個 = 5XP
  };

  /// 焙煎時間に応じた経験値を計算
  static int calculateRoastingXP(double minutes) {
    return (minutes * baseRewards[ActivityType.roasting]! / 30).round();
  }

  /// 出勤による経験値
  static ActivityReward attendance() {
    return ActivityReward(
      type: ActivityType.attendance,
      experiencePoints: baseRewards[ActivityType.attendance]!,
      description: '出勤で${baseRewards[ActivityType.attendance]}XP獲得',
    );
  }

  /// 焙煎による経験値
  static ActivityReward roasting(double minutes) {
    final xp = calculateRoastingXP(minutes);
    return ActivityReward(
      type: ActivityType.roasting,
      experiencePoints: xp,
      description: '焙煎${minutes.toStringAsFixed(0)}分で${xp}XP獲得',
    );
  }

  /// ドリップパックによる経験値
  static ActivityReward dripPack(int count) {
    final xp = count * baseRewards[ActivityType.dripPack]!;
    return ActivityReward(
      type: ActivityType.dripPack,
      experiencePoints: xp,
      description: 'ドリップパック${count}個で${xp}XP獲得',
    );
  }
}
