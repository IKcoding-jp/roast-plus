import 'package:flutter/material.dart';
import 'dart:math' as Math;

/// グループのバッジを表すクラス
class GroupBadge {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final DateTime earnedAt;
  final String earnedByUserId; // バッジを取得したアクションを行ったユーザー
  final String earnedByUserName;

  const GroupBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.earnedAt,
    required this.earnedByUserId,
    required this.earnedByUserName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon.codePoint,
      'color': color.value,
      'earnedAt': earnedAt.toIso8601String(),
      'earnedByUserId': earnedByUserId,
      'earnedByUserName': earnedByUserName,
    };
  }

  factory GroupBadge.fromJson(Map<String, dynamic> json) {
    return GroupBadge(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
      color: Color(json['color']),
      earnedAt: DateTime.parse(json['earnedAt']),
      earnedByUserId: json['earnedByUserId'] ?? '',
      earnedByUserName: json['earnedByUserName'] ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupBadge && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// グループバッジの獲得条件を表すクラス
class GroupBadgeCondition {
  final String badgeId;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool Function(GroupStats stats) checkCondition;

  const GroupBadgeCondition({
    required this.badgeId,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.checkCondition,
  });

  GroupBadge createBadge(String userId, String userName) {
    return GroupBadge(
      id: badgeId,
      name: name,
      description: description,
      icon: icon,
      color: color,
      earnedAt: DateTime.now(),
      earnedByUserId: userId,
      earnedByUserName: userName,
    );
  }
}

/// グループの統計情報
class GroupStats {
  final int totalAttendanceDays;           // 累計出勤日数
  final double totalRoastTimeMinutes;      // 累計焙煎時間（分）
  final int totalDripPackCount;            // 累計ドリップパック数
  final int totalRoastSessions;            // 累計焙煎セッション数
  final int totalTastingRecords;           // 累計テイスティング記録数
  final int totalWorkProgressCompleted;    // 完了した作業進捗数
  final DateTime firstActivityDate;        // 最初の活動日
  final DateTime lastActivityDate;         // 最後の活動日
  final Map<String, int> memberContributions; // メンバー別貢献度

  const GroupStats({
    required this.totalAttendanceDays,
    required this.totalRoastTimeMinutes,
    required this.totalDripPackCount,
    required this.totalRoastSessions,
    required this.totalTastingRecords,
    required this.totalWorkProgressCompleted,
    required this.firstActivityDate,
    required this.lastActivityDate,
    required this.memberContributions,
  });

  /// 累計焙煎時間（時間単位）
  double get totalRoastTimeHours => totalRoastTimeMinutes / 60;

  /// グループ活動開始からの日数
  int get daysSinceStart {
    return DateTime.now().difference(firstActivityDate).inDays + 1;
  }

  /// 平均的な日次活動レベル
  double get averageDailyActivity {
    final days = daysSinceStart;
    if (days == 0) return 0.0;
    return (totalAttendanceDays + totalRoastSessions + (totalDripPackCount / 100)) / days;
  }

  GroupStats copyWith({
    int? totalAttendanceDays,
    double? totalRoastTimeMinutes,
    int? totalDripPackCount,
    int? totalRoastSessions,
    int? totalTastingRecords,
    int? totalWorkProgressCompleted,
    DateTime? firstActivityDate,
    DateTime? lastActivityDate,
    Map<String, int>? memberContributions,
  }) {
    return GroupStats(
      totalAttendanceDays: totalAttendanceDays ?? this.totalAttendanceDays,
      totalRoastTimeMinutes: totalRoastTimeMinutes ?? this.totalRoastTimeMinutes,
      totalDripPackCount: totalDripPackCount ?? this.totalDripPackCount,
      totalRoastSessions: totalRoastSessions ?? this.totalRoastSessions,
      totalTastingRecords: totalTastingRecords ?? this.totalTastingRecords,
      totalWorkProgressCompleted: totalWorkProgressCompleted ?? this.totalWorkProgressCompleted,
      firstActivityDate: firstActivityDate ?? this.firstActivityDate,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      memberContributions: memberContributions ?? this.memberContributions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalAttendanceDays': totalAttendanceDays,
      'totalRoastTimeMinutes': totalRoastTimeMinutes,
      'totalDripPackCount': totalDripPackCount,
      'totalRoastSessions': totalRoastSessions,
      'totalTastingRecords': totalTastingRecords,
      'totalWorkProgressCompleted': totalWorkProgressCompleted,
      'firstActivityDate': firstActivityDate.toIso8601String(),
      'lastActivityDate': lastActivityDate.toIso8601String(),
      'memberContributions': memberContributions,
    };
  }

  factory GroupStats.fromJson(Map<String, dynamic> json) {
    return GroupStats(
      totalAttendanceDays: json['totalAttendanceDays'] ?? 0,
      totalRoastTimeMinutes: (json['totalRoastTimeMinutes'] ?? 0).toDouble(),
      totalDripPackCount: json['totalDripPackCount'] ?? 0,
      totalRoastSessions: json['totalRoastSessions'] ?? 0,
      totalTastingRecords: json['totalTastingRecords'] ?? 0,
      totalWorkProgressCompleted: json['totalWorkProgressCompleted'] ?? 0,
      firstActivityDate: DateTime.parse(json['firstActivityDate'] ?? DateTime.now().toIso8601String()),
      lastActivityDate: DateTime.parse(json['lastActivityDate'] ?? DateTime.now().toIso8601String()),
      memberContributions: Map<String, int>.from(json['memberContributions'] ?? {}),
    );
  }

  factory GroupStats.initial() {
    final now = DateTime.now();
    return GroupStats(
      totalAttendanceDays: 0,
      totalRoastTimeMinutes: 0.0,
      totalDripPackCount: 0,
      totalRoastSessions: 0,
      totalTastingRecords: 0,
      totalWorkProgressCompleted: 0,
      firstActivityDate: now,
      lastActivityDate: now,
      memberContributions: {},
    );
  }
}

/// グループのゲーミフィケーションプロフィール
class GroupGamificationProfile {
  final String groupId;
  final int experiencePoints;
  final int level;
  final String groupTitle;
  final List<GroupBadge> badges;
  final GroupStats stats;
  final DateTime lastUpdated;

  const GroupGamificationProfile({
    required this.groupId,
    required this.experiencePoints,
    required this.level,
    required this.groupTitle,
    required this.badges,
    required this.stats,
    required this.lastUpdated,
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

  /// 最新のバッジを取得
  GroupBadge? get latestBadge {
    if (badges.isEmpty) return null;
    return badges.reduce((a, b) => a.earnedAt.isAfter(b.earnedAt) ? a : b);
  }

  /// レベルに必要な経験値を計算（緩やかなスケーリング）
  static int _calculateRequiredXP(int level) {
    if (level <= 1) return 0;
    // 序盤はサクサク上がるように設計：基本XP * (レベル^1.5)
    return (50 * level * Math.pow(level, 0.5)).round();
  }

  /// グループタイトルを取得
  String get displayTitle {
    if (level >= 9999) return '伝説のロースターズ';
    if (level >= 1000) return 'マスターロースターズ';
    if (level >= 500) return 'エキスパートロースターズ';
    if (level >= 200) return 'プロロースターズ';
    if (level >= 100) return 'スキルドロースターズ';
    if (level >= 50) return 'アドバンスドロースターズ';
    if (level >= 20) return 'ベテランロースターズ';
    if (level >= 10) return 'ジュニアロースターズ';
    if (level >= 5) return '見習いロースターズ';
    return 'ルーキーロースターズ';
  }

  /// レベル色を取得
  Color get levelColor {
    if (level >= 9999) return Colors.amber.shade700;      // 金色
    if (level >= 1000) return Colors.purple.shade600;     // 紫
    if (level >= 500) return Colors.red.shade600;         // 赤
    if (level >= 200) return Colors.orange.shade600;      // オレンジ
    if (level >= 100) return Colors.blue.shade600;        // 青
    if (level >= 50) return Colors.green.shade600;        // 緑
    if (level >= 20) return Colors.teal.shade600;         // ティール
    if (level >= 10) return Colors.indigo.shade400;       // インディゴ
    if (level >= 5) return Colors.brown.shade400;         // ブラウン
    return Colors.grey.shade600;                          // グレー
  }

  GroupGamificationProfile copyWith({
    String? groupId,
    int? experiencePoints,
    int? level,
    String? groupTitle,
    List<GroupBadge>? badges,
    GroupStats? stats,
    DateTime? lastUpdated,
  }) {
    return GroupGamificationProfile(
      groupId: groupId ?? this.groupId,
      experiencePoints: experiencePoints ?? this.experiencePoints,
      level: level ?? this.level,
      groupTitle: groupTitle ?? this.groupTitle,
      badges: badges ?? this.badges,
      stats: stats ?? this.stats,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'experiencePoints': experiencePoints,
      'level': level,
      'groupTitle': groupTitle,
      'badges': badges.map((badge) => badge.toJson()).toList(),
      'stats': stats.toJson(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory GroupGamificationProfile.fromJson(Map<String, dynamic> json) {
    return GroupGamificationProfile(
      groupId: json['groupId'] ?? '',
      experiencePoints: json['experiencePoints'] ?? 0,
      level: json['level'] ?? 1,
      groupTitle: json['groupTitle'] ?? '',
      badges: (json['badges'] as List<dynamic>?)
              ?.map((badgeJson) => GroupBadge.fromJson(badgeJson))
              .toList() ??
          [],
      stats: GroupStats.fromJson(json['stats'] ?? {}),
      lastUpdated: DateTime.parse(json['lastUpdated'] ?? DateTime.now().toIso8601String()),
    );
  }

  factory GroupGamificationProfile.initial(String groupId) {
    return GroupGamificationProfile(
      groupId: groupId,
      experiencePoints: 0,
      level: 1,
      groupTitle: '',
      badges: [],
      stats: GroupStats.initial(),
      lastUpdated: DateTime.now(),
    );
  }
}

/// グループアクティビティの結果
class GroupActivityResult {
  final bool success;
  final String message;
  final bool levelUp;
  final List<GroupBadge> newBadges;
  final int experienceGained;
  final int newLevel;

  const GroupActivityResult({
    required this.success,
    required this.message,
    required this.levelUp,
    required this.newBadges,
    required this.experienceGained,
    required this.newLevel,
  });
}

/// グループアクティビティの経験値報酬
class GroupActivityReward {
  final int experiencePoints;
  final String description;

  const GroupActivityReward({
    required this.experiencePoints,
    required this.description,
  });

  factory GroupActivityReward.attendance() {
    return const GroupActivityReward(
      experiencePoints: 10,
      description: '出勤記録で+10XP獲得！',
    );
  }

  factory GroupActivityReward.roasting(double minutes) {
    final xp = minutes.round();
    return GroupActivityReward(
      experiencePoints: xp,
      description: '焙煎記録で+${xp}XP獲得！',
    );
  }

  factory GroupActivityReward.dripPack(int count) {
    final xp = (count * 0.5).round();
    return GroupActivityReward(
      experiencePoints: xp,
      description: 'ドリップパック記録で+${xp}XP獲得！',
    );
  }

  factory GroupActivityReward.tasting() {
    return const GroupActivityReward(
      experiencePoints: 5,
      description: 'テイスティング記録で+5XP獲得！',
    );
  }

  factory GroupActivityReward.workProgress() {
    return const GroupActivityReward(
      experiencePoints: 3,
      description: '作業進捗更新で+3XP獲得！',
    );
  }
}

/// グループバッジの獲得条件定義
class GroupBadgeConditions {
  static final List<GroupBadgeCondition> conditions = [
    // 焙煎時間関連バッジ
    GroupBadgeCondition(
      badgeId: 'group_roast_50h',
      name: 'チーム焙煎50時間',
      description: 'グループで累計50時間の焙煎を達成',
      icon: Icons.local_fire_department_outlined,
      color: Colors.orange.shade400,
      checkCondition: (stats) => stats.totalRoastTimeHours >= 50,
    ),
    GroupBadgeCondition(
      badgeId: 'group_roast_100h',
      name: 'チーム焙煎100時間',
      description: 'グループで累計100時間の焙煎を達成',
      icon: Icons.local_fire_department,
      color: Colors.orange.shade600,
      checkCondition: (stats) => stats.totalRoastTimeHours >= 100,
    ),
    GroupBadgeCondition(
      badgeId: 'group_roast_500h',
      name: '火加減の達人',
      description: 'グループで累計500時間の焙煎を達成',
      icon: Icons.whatshot,
      color: Colors.deepOrange.shade600,
      checkCondition: (stats) => stats.totalRoastTimeHours >= 500,
    ),

    // 出勤関連バッジ
    GroupBadgeCondition(
      badgeId: 'group_attendance_100',
      name: 'チーム出勤100日',
      description: 'グループで累計100日の出勤を達成',
      icon: Icons.work_outline,
      color: Colors.blue.shade400,
      checkCondition: (stats) => stats.totalAttendanceDays >= 100,
    ),
    GroupBadgeCondition(
      badgeId: 'group_attendance_300',
      name: '鉄人チーム',
      description: 'グループで累計300日の出勤を達成',
      icon: Icons.work,
      color: Colors.blue.shade600,
      checkCondition: (stats) => stats.totalAttendanceDays >= 300,
    ),

    // ドリップパック関連バッジ
    GroupBadgeCondition(
      badgeId: 'group_drip_10000',
      name: '生産の鬼',
      description: 'グループで累計1万個のドリップパックを作成',
      icon: Icons.local_cafe,
      color: Colors.brown.shade600,
      checkCondition: (stats) => stats.totalDripPackCount >= 10000,
    ),
    GroupBadgeCondition(
      badgeId: 'group_drip_50000',
      name: '量産マスター',
      description: 'グループで累計5万個のドリップパックを作成',
      icon: Icons.local_drink,
      color: Colors.purple.shade600,
      checkCondition: (stats) => stats.totalDripPackCount >= 50000,
    ),

    // 継続性バッジ
    GroupBadgeCondition(
      badgeId: 'group_active_30days',
      name: '継続の力',
      description: 'グループ活動を30日間継続',
      icon: Icons.calendar_today,
      color: Colors.green.shade500,
      checkCondition: (stats) => stats.daysSinceStart >= 30,
    ),
    GroupBadgeCondition(
      badgeId: 'group_active_365days',
      name: '年間皆勤',
      description: 'グループ活動を365日間継続',
      icon: Icons.event_available,
      color: Colors.green.shade700,
      checkCondition: (stats) => stats.daysSinceStart >= 365,
    ),
  ];
} 