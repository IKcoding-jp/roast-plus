import 'package:flutter/material.dart';

/// グループのバッジを表すクラス
class GroupBadge {
  final String id;
  final String name;
  final String description;
  final int iconCodePoint; // IconDataの代わりにcodePointを保存
  final Color color;
  final DateTime earnedAt;
  final String earnedByUserId; // バッジを取得したアクションを行ったユーザー
  final String earnedByUserName;
  final BadgeCategory category; // バッジカテゴリ

  const GroupBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.iconCodePoint,
    required this.color,
    required this.earnedAt,
    this.earnedByUserId = '',
    this.earnedByUserName = '',
    required this.category,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': iconCodePoint,
      'color': color.toARGB32(),
      'earnedAt': earnedAt.toIso8601String(),
      'earnedByUserId': earnedByUserId,
      'earnedByUserName': earnedByUserName,
      'category': category.name,
    };
  }

  factory GroupBadge.fromJson(Map<String, dynamic> json) {
    return GroupBadge(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      iconCodePoint: json['icon'] as int,
      color: Color(json['color'] as int),
      earnedAt: DateTime.parse(json['earnedAt']),
      earnedByUserId: json['earnedByUserId'] ?? '',
      earnedByUserName: json['earnedByUserName'] ?? '',
      category: BadgeCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => BadgeCategory.attendance,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupBadge && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// バッジカテゴリ
enum BadgeCategory {
  attendance, // 出勤系
  roasting, // 焙煎系
  dripPack, // ドリップパック系
  level, // レベル系
  special, // 特殊・イベント系
}

/// グループバッジの獲得条件を表すクラス
class GroupBadgeCondition {
  final String badgeId;
  final String name;
  final String description;
  final int iconCodePoint;
  final Color color;
  final BadgeCategory category;
  final bool Function(GroupStats stats) checkCondition;

  const GroupBadgeCondition({
    required this.badgeId,
    required this.name,
    required this.description,
    required this.iconCodePoint,
    required this.color,
    required this.category,
    required this.checkCondition,
  });

  GroupBadge createBadge(String userId, String userName) {
    return GroupBadge(
      id: badgeId,
      name: name,
      description: description,
      iconCodePoint: iconCodePoint,
      color: color,
      earnedAt: DateTime.now(),
      earnedByUserId: userId,
      earnedByUserName: userName,
      category: category,
    );
  }
}

/// グループの統計情報
class GroupStats {
  final int totalAttendanceDays; // 累計出勤日数（重複なし）
  final double totalRoastTimeMinutes; // 累計焙煎時間（分）
  final int totalRoastDays; // 累計焙煎日数（1日最大3回としてカウント）
  final int totalDripPackCount; // 累計ドリップパック数
  final int totalTastingRecords; // 累計テイスティング記録数
  final DateTime firstActivityDate; // 最初の活動日
  final DateTime lastActivityDate; // 最後の活動日
  final Map<String, int> memberContributions; // メンバー別貢献度
  final Set<String> allMemberAttendanceDays; // 全員出勤日（重複なし）

  const GroupStats({
    required this.totalAttendanceDays,
    required this.totalRoastTimeMinutes,
    required this.totalRoastDays,
    required this.totalDripPackCount,
    required this.totalTastingRecords,
    required this.firstActivityDate,
    required this.lastActivityDate,
    required this.memberContributions,
    required this.allMemberAttendanceDays,
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
    return (totalAttendanceDays + totalRoastDays + (totalDripPackCount / 100)) /
        days;
  }

  /// 全員出勤日数
  int get allMemberAttendanceCount => allMemberAttendanceDays.length;

  GroupStats copyWith({
    int? totalAttendanceDays,
    double? totalRoastTimeMinutes,
    int? totalRoastDays,
    int? totalDripPackCount,
    int? totalTastingRecords,
    DateTime? firstActivityDate,
    DateTime? lastActivityDate,
    Map<String, int>? memberContributions,
    Set<String>? allMemberAttendanceDays,
  }) {
    return GroupStats(
      totalAttendanceDays: totalAttendanceDays ?? this.totalAttendanceDays,
      totalRoastTimeMinutes:
          totalRoastTimeMinutes ?? this.totalRoastTimeMinutes,
      totalRoastDays: totalRoastDays ?? this.totalRoastDays,
      totalDripPackCount: totalDripPackCount ?? this.totalDripPackCount,
      totalTastingRecords: totalTastingRecords ?? this.totalTastingRecords,
      firstActivityDate: firstActivityDate ?? this.firstActivityDate,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      memberContributions: memberContributions ?? this.memberContributions,
      allMemberAttendanceDays:
          allMemberAttendanceDays ?? this.allMemberAttendanceDays,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalAttendanceDays': totalAttendanceDays,
      'totalRoastTimeMinutes': totalRoastTimeMinutes,
      'totalRoastDays': totalRoastDays,
      'totalDripPackCount': totalDripPackCount,
      'totalTastingRecords': totalTastingRecords,
      'firstActivityDate': firstActivityDate.toIso8601String(),
      'lastActivityDate': lastActivityDate.toIso8601String(),
      'memberContributions': memberContributions,
      'allMemberAttendanceDays': allMemberAttendanceDays.toList(),
    };
  }

  factory GroupStats.fromJson(Map<String, dynamic> json) {
    return GroupStats(
      totalAttendanceDays: json['totalAttendanceDays'] ?? 0,
      totalRoastTimeMinutes: (json['totalRoastTimeMinutes'] ?? 0).toDouble(),
      totalRoastDays: json['totalRoastDays'] ?? 0,
      totalDripPackCount: json['totalDripPackCount'] ?? 0,
      totalTastingRecords: json['totalTastingRecords'] ?? 0,
      firstActivityDate: DateTime.parse(
        json['firstActivityDate'] ?? DateTime.now().toIso8601String(),
      ),
      lastActivityDate: DateTime.parse(
        json['lastActivityDate'] ?? DateTime.now().toIso8601String(),
      ),
      memberContributions: Map<String, int>.from(
        json['memberContributions'] ?? {},
      ),
      allMemberAttendanceDays: Set<String>.from(
        json['allMemberAttendanceDays'] ?? [],
      ),
    );
  }

  factory GroupStats.initial() {
    final now = DateTime.now();
    return GroupStats(
      totalAttendanceDays: 0,
      totalRoastTimeMinutes: 0.0,
      totalRoastDays: 0,
      totalDripPackCount: 0,
      totalTastingRecords: 0,
      firstActivityDate: now,
      lastActivityDate: now,
      memberContributions: {},
      allMemberAttendanceDays: {},
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

  /// カテゴリ別バッジを取得
  List<GroupBadge> getBadgesByCategory(BadgeCategory category) {
    return badges.where((badge) => badge.category == category).toList();
  }

  /// レベルに必要な経験値を計算（大幅に増加）
  static int _calculateRequiredXP(int level) {
    if (level <= 1) return 0; // レベル1は0XPから開始

    // グループレベル9999に必要な総経験値: 約226,000XP
    // 3年間で獲得可能な経験値: 約226,000XP
    // 出勤: 780日 × 50XP = 39,000XP
    // 焙煎: 468回 × 200XP = 93,600XP
    // ドリップパック: 46,800個 × 2XP = 93,600XP（週300個 × 3年）
    // 合計: 226,200XP

    // 150パック1回（300XP）で適切なレベルアップになるよう調整
    if (level <= 1) return 0;

    // レベル1-5: 非常に簡単（50XP/レベル）
    if (level <= 5) {
      return (level - 1) * 50;
    }
    // レベル6-15: 簡単（80XP/レベル）
    else if (level <= 15) {
      return 200 + (level - 5) * 80;
    }
    // レベル16-30: 普通（120XP/レベル）
    else if (level <= 30) {
      return 1000 + (level - 15) * 120;
    }
    // レベル31-50: 少し難しい（180XP/レベル）
    else if (level <= 50) {
      return 2800 + (level - 30) * 180;
    }
    // レベル51-100: 難しい（250XP/レベル）
    else if (level <= 100) {
      return 6400 + (level - 50) * 250;
    }
    // レベル101-200: とても難しい（350XP/レベル）
    else if (level <= 200) {
      return 18900 + (level - 100) * 350;
    }
    // レベル201-500: 非常に難しい（500XP/レベル）
    else if (level <= 500) {
      return 53900 + (level - 200) * 500;
    }
    // レベル501-1000: 超難しい（750XP/レベル）
    else if (level <= 1000) {
      return 203900 + (level - 500) * 750;
    }
    // レベル1001-2000: 極めて難しい（1200XP/レベル）
    else if (level <= 2000) {
      return 579900 + (level - 1000) * 1200;
    }
    // レベル2001-4000: 伝説級（2000XP/レベル）
    else if (level <= 4000) {
      return 1779900 + (level - 2000) * 2000;
    }
    // レベル4001-7000: 神級（3500XP/レベル）
    else if (level <= 7000) {
      return 5779900 + (level - 4000) * 3500;
    }
    // レベル7001-9999: 超越級（6000XP/レベル）
    else if (level <= 9999) {
      return 16279900 + (level - 7000) * 6000;
    }
    // レベル9999以上
    else {
      return 34279900 + (level - 9999) * 10000;
    }
  }

  /// グループタイトルを取得
  String get displayTitle {
    if (level >= 9999) return '伝説のロースターズ';
    if (level >= 7500) return 'グランドマスターロースターズ';
    if (level >= 5000) return 'エリートマスターロースターズ';
    if (level >= 3000) return 'シニアマスターロースターズ';
    if (level >= 2000) return 'ジュニアマスターロースターズ';
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
    if (level >= 9999) return const Color(0xFFD4AF37); // 伝説のロースターズ (ゴールド)
    if (level >= 7500) {
      return const Color(0xFFB8860B); // グランドマスターロースターズ (ダークゴールデンロッド)
    }
    if (level >= 5000) return const Color(0xFFCD853F); // エリートマスターロースターズ (ペルー)
    if (level >= 3000) {
      return const Color(0xFF8B4513); // シニアマスターロースターズ (サドルブラウン)
    }
    if (level >= 2000) return const Color(0xFFA0522D); // ジュニアマスターロースターズ (シエナ)
    if (level >= 1000) {
      return const Color(0xFF4A2320); // マスターロースターズ (非常に濃いコーヒーブラウン)
    }
    if (level >= 500) {
      return const Color(0xFF6F4E37); // エキスパートロースターズ (ダークコーヒーブラウン)
    }
    if (level >= 200) return const Color(0xFF8B4513); // プロロースターズ (サドルブラウン)
    if (level >= 100) return const Color(0xFFA0522D); // スキルドロースターズ (シエナ)
    if (level >= 50) return const Color(0xFFD2691E); // アドバンスドロースターズ (チョコレート)
    if (level >= 20) return const Color(0xFFCD853F); // ベテランロースターズ (ペルー)
    if (level >= 10) return const Color(0xFFD2B48C); // ジュニアロースターズ (タン)
    if (level >= 5) return const Color(0xFFE6BE8A); // 見習いロースターズ (明るいタン)
    return const Color(0xFFF5DEB3); // ルーキーロースターズ (小麦色 - 生豆に近い色)
  }

  /// レベルアイコンを取得
  IconData get levelIcon {
    if (level >= 9999) return Icons.local_cafe; // コーヒー豆のアイコン (最高レベル)
    if (level >= 7500) {
      return Icons.workspace_premium; // プレミアムワークスペースアイコン (グランドマスター)
    }
    if (level >= 5000) return Icons.star; // 星のアイコン (エリート)
    if (level >= 3000) return Icons.auto_awesome; // 輝くアイコン (シニア)
    if (level >= 2000) {
      return Icons.workspace_premium; // プレミアムワークスペースアイコン (ジュニアマスター)
    }
    if (level >= 1000) return Icons.coffee; // コーヒーカップのアイコン
    if (level >= 500) return Icons.emoji_food_beverage; // 湯気の立つコーヒーのアイコン
    if (level >= 200) return Icons.whatshot; // 火のアイコン (焙煎)
    if (level >= 100) return Icons.filter_alt; // フィルターのアイコン (抽出)
    if (level >= 50) return Icons.grain; // 粒のアイコン (豆)
    if (level >= 20) return Icons.spa; // 葉のアイコン (植物としてのコーヒー)
    if (level >= 10) return Icons.scatter_plot; // 散らばった点のアイコン (生豆)
    if (level >= 5) return Icons.circle; // 小さな丸のアイコン (豆の成長)
    return Icons.eco; // 環境アイコン (初期段階)
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
      badges:
          (json['badges'] as List<dynamic>?)
              ?.map((badgeJson) => GroupBadge.fromJson(badgeJson))
              .toList() ??
          [],
      stats: GroupStats.fromJson(json['stats'] ?? {}),
      lastUpdated: DateTime.parse(
        json['lastUpdated'] ?? DateTime.now().toIso8601String(),
      ),
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
      experiencePoints: 50,
      description: '出勤記録で+50XP獲得！',
    );
  }

  factory GroupActivityReward.roasting(double minutes) {
    final xp = (minutes * 2).round(); // 1分あたり2XP
    return GroupActivityReward(
      experiencePoints: xp,
      description: '焙煎記録で+${xp}XP獲得！',
    );
  }

  factory GroupActivityReward.dripPack(int count) {
    final xp = (count * 2).round(); // 1個あたり2XP（週300個 × 3年 = 93,600XP）
    return GroupActivityReward(
      experiencePoints: xp,
      description: 'ドリップパック記録で+${xp}XP獲得！',
    );
  }

  factory GroupActivityReward.tasting() {
    return const GroupActivityReward(
      experiencePoints: 25,
      description: 'テイスティング記録で+25XP獲得！',
    );
  }

  factory GroupActivityReward.workProgress() {
    return const GroupActivityReward(
      experiencePoints: 15,
      description: '作業進捗更新で+15XP獲得！',
    );
  }
}

/// グループバッジの獲得条件定義（段階的達成システム）
class GroupBadgeConditions {
  static final List<GroupBadgeCondition> conditions = [
    // ① 🧑‍🏭 出勤日数（グループ合計）- 段階的バッジ
    GroupBadgeCondition(
      badgeId: 'group_attendance_10',
      name: 'はじめの一歩',
      description: 'グループで累計10日の出勤を達成',
      iconCodePoint: Icons.directions_walk.codePoint,
      color: Colors.green.shade400,
      category: BadgeCategory.attendance,
      checkCondition: (stats) => stats.totalAttendanceDays >= 10,
    ),
    GroupBadgeCondition(
      badgeId: 'group_attendance_25',
      name: '皆勤チーム',
      description: 'グループで累計25日の出勤を達成',
      iconCodePoint: Icons.work_outline.codePoint,
      color: Colors.green.shade500,
      category: BadgeCategory.attendance,
      checkCondition: (stats) => stats.totalAttendanceDays >= 25,
    ),
    GroupBadgeCondition(
      badgeId: 'group_attendance_50',
      name: '習慣化の兆し',
      description: 'グループで累計50日の出勤を達成',
      iconCodePoint: Icons.work.codePoint,
      color: Colors.green.shade600,
      category: BadgeCategory.attendance,
      checkCondition: (stats) => stats.totalAttendanceDays >= 50,
    ),
    GroupBadgeCondition(
      badgeId: 'group_attendance_100',
      name: 'チームの軌跡',
      description: 'グループで累計100日の出勤を達成',
      iconCodePoint: Icons.calendar_month.codePoint,
      color: Colors.blue.shade400,
      category: BadgeCategory.attendance,
      checkCondition: (stats) => stats.totalAttendanceDays >= 100,
    ),
    GroupBadgeCondition(
      badgeId: 'group_attendance_200',
      name: '出勤マイスター',
      description: 'グループで累計200日の出勤を達成',
      iconCodePoint: Icons.fitness_center.codePoint,
      color: Colors.blue.shade600,
      category: BadgeCategory.attendance,
      checkCondition: (stats) => stats.totalAttendanceDays >= 200,
    ),
    GroupBadgeCondition(
      badgeId: 'group_attendance_300',
      name: '継続の証',
      description: 'グループで累計300日の出勤を達成',
      iconCodePoint: Icons.emoji_events.codePoint,
      color: Colors.blue.shade800,
      category: BadgeCategory.attendance,
      checkCondition: (stats) => stats.totalAttendanceDays >= 300,
    ),
    GroupBadgeCondition(
      badgeId: 'group_attendance_500',
      name: '勤続の絆',
      description: 'グループで累計500日の出勤を達成',
      iconCodePoint: Icons.people.codePoint,
      color: Colors.indigo.shade500,
      category: BadgeCategory.attendance,
      checkCondition: (stats) => stats.totalAttendanceDays >= 500,
    ),
    GroupBadgeCondition(
      badgeId: 'group_attendance_800',
      name: '鉄壁のチーム',
      description: 'グループで累計800日の出勤を達成',
      iconCodePoint: Icons.security.codePoint,
      color: Colors.indigo.shade700,
      category: BadgeCategory.attendance,
      checkCondition: (stats) => stats.totalAttendanceDays >= 800,
    ),
    GroupBadgeCondition(
      badgeId: 'group_attendance_1000',
      name: '千日の道',
      description: 'グループで累計1000日の出勤を達成',
      iconCodePoint: Icons.star.codePoint,
      color: Colors.purple.shade500,
      category: BadgeCategory.attendance,
      checkCondition: (stats) => stats.totalAttendanceDays >= 1000,
    ),
    GroupBadgeCondition(
      badgeId: 'group_attendance_2000',
      name: '勤労の王者',
      description: 'グループで累計2000日の出勤を達成',
      iconCodePoint: Icons.emoji_events.codePoint,
      color: Colors.purple.shade700,
      category: BadgeCategory.attendance,
      checkCondition: (stats) => stats.totalAttendanceDays >= 2000,
    ),
    GroupBadgeCondition(
      badgeId: 'group_attendance_3000',
      name: '伝説の現場',
      description: 'グループで累計3000日の出勤を達成',
      iconCodePoint: Icons.auto_awesome.codePoint,
      color: Colors.amber.shade600,
      category: BadgeCategory.attendance,
      checkCondition: (stats) => stats.totalAttendanceDays >= 3000,
    ),
    GroupBadgeCondition(
      badgeId: 'group_attendance_5000',
      name: '焙煎殿堂入り',
      description: 'グループで累計5000日の出勤を達成',
      iconCodePoint: Icons.workspace_premium.codePoint,
      color: Colors.amber.shade700,
      category: BadgeCategory.attendance,
      checkCondition: (stats) => stats.totalAttendanceDays >= 5000,
    ),

    // ② 🔥 焙煎時間（グループ合計）- 段階的バッジ（新システム）
    ...RoastTimeBadgeConstants.roastTimeThresholds.entries.map((entry) {
      final badgeId = entry.key;
      final thresholdMinutes = entry.value;
      return GroupBadgeCondition(
        badgeId: badgeId,
        name: RoastTimeBadgeConstants.badgeNames[badgeId]!,
        description: RoastTimeBadgeConstants.badgeDescriptions[badgeId]!,
        iconCodePoint: RoastTimeBadgeConstants.badgeIcons[badgeId]!.codePoint,
        color: RoastTimeBadgeConstants.badgeColors[badgeId]!,
        category: BadgeCategory.roasting,
        checkCondition: (stats) =>
            stats.totalRoastTimeMinutes >= thresholdMinutes,
      );
    }),

    // ③ ☕ ドリップパック作成数（グループ合計）- 段階的バッジ
    ...DripPackBadgeConstants.dripPackThresholds.entries.map((entry) {
      final badgeId = entry.key;
      final thresholdCount = entry.value;
      return GroupBadgeCondition(
        badgeId: badgeId,
        name: DripPackBadgeConstants.badgeNames[badgeId]!,
        description: DripPackBadgeConstants.badgeDescriptions[badgeId]!,
        iconCodePoint: DripPackBadgeConstants.badgeIcons[badgeId]!.codePoint,
        color: DripPackBadgeConstants.badgeColors[badgeId]!,
        category: BadgeCategory.dripPack,
        checkCondition: (stats) => stats.totalDripPackCount >= thresholdCount,
      );
    }),

    // ④ 🏆 レベルバッジ（グループレベル）- 新しい仕様に基づく段階的バッジ
    ...levelBadgeConditions,

    // ⑤ 🏅 特殊・記録バッジ
    GroupBadgeCondition(
      badgeId: 'group_all_member_attendance',
      name: '全員出勤！',
      description: '同じ日に全メンバーが出勤',
      iconCodePoint: Icons.groups.codePoint,
      color: Colors.green.shade500,
      category: BadgeCategory.special,
      checkCondition: (stats) => stats.allMemberAttendanceCount >= 1,
    ),
    GroupBadgeCondition(
      badgeId: 'group_roast_triple',
      name: '焙煎3連チャン',
      description: '1日で3回の焙煎記録がある',
      iconCodePoint: Icons.local_fire_department.codePoint,
      color: Colors.orange.shade700,
      category: BadgeCategory.special,
      checkCondition: (stats) => _checkTripleRoastDay(stats),
    ),
    GroupBadgeCondition(
      badgeId: 'group_first_tasting',
      name: '初テイスティング',
      description: '最初の試飲感想を記録',
      iconCodePoint: Icons.restaurant.codePoint,
      color: Colors.pink.shade400,
      category: BadgeCategory.special,
      checkCondition: (stats) => stats.totalTastingRecords >= 1,
    ),

    GroupBadgeCondition(
      badgeId: 'group_continuous_week',
      name: '皆勤チーム',
      description: '一週間連続で誰かが必ず出勤',
      iconCodePoint: Icons.calendar_today.codePoint,
      color: Colors.green.shade600,
      category: BadgeCategory.special,
      checkCondition: (stats) => _checkContinuousWeekAttendance(stats),
    ),
    GroupBadgeCondition(
      badgeId: 'group_tasting_100',
      name: '味覚の達人',
      description: 'グループで累計100回のテイスティング記録',
      iconCodePoint: Icons.restaurant_menu.codePoint,
      color: Colors.pink.shade600,
      category: BadgeCategory.special,
      checkCondition: (stats) => stats.totalTastingRecords >= 100,
    ),
    GroupBadgeCondition(
      badgeId: 'group_recommended_timer',
      name: 'おすすめタイマー使い',
      description: 'おすすめ焙煎タイマーを使用して焙煎を記録',
      iconCodePoint: Icons.timer.codePoint,
      color: Colors.orange.shade500,
      category: BadgeCategory.special,
      checkCondition: (stats) => _checkRecommendedTimerUsage(stats),
    ),
  ];

  /// 一週間連続出勤チェック（簡易版）
  static bool _checkContinuousWeekAttendance(GroupStats stats) {
    // 実際の実装では、より詳細な日付チェックが必要
    // ここでは簡易的に活動日数で判定
    return stats.daysSinceStart >= 7 && stats.totalAttendanceDays >= 7;
  }

  /// 1日3回焙煎チェック（簡易版）
  static bool _checkTripleRoastDay(GroupStats stats) {
    // 実際の実装では、より詳細な日付チェックが必要
    // ここでは簡易的に焙煎日数で判定
    return stats.totalRoastDays >= 3;
  }

  /// おすすめタイマー使用チェック（簡易版）
  static bool _checkRecommendedTimerUsage(GroupStats stats) {
    // 実際の実装では、おすすめタイマー使用の記録をチェック
    // ここでは簡易的に焙煎日数で判定
    return stats.totalRoastDays >= 5;
  }

  /// グループレベルチェック（統計ベース - フォールバック用）
  static bool _checkGroupLevel(GroupStats stats, int requiredLevel) {
    // 統計から経験値を推定してレベルを計算
    // 簡易的な計算: 出勤1日=10XP, 焙煎1分=1XP, ドリップパック1個=5XP, テイスティング1回=20XP
    final estimatedXP =
        (stats.totalAttendanceDays * 10) +
        (stats.totalRoastTimeMinutes.toInt() * 1) +
        (stats.totalDripPackCount * 5) +
        (stats.totalTastingRecords * 20);

    final estimatedLevel = _calculateLevelFromXP(estimatedXP);
    return estimatedLevel >= requiredLevel;
  }

  /// 経験値からレベルを計算
  static int _calculateLevelFromXP(int experiencePoints) {
    int level = 1;
    while (experiencePoints >= _calculateRequiredXP(level + 1)) {
      level++;
    }
    return level;
  }

  /// レベルに必要な経験値を計算（3年でレベル9999到達を目指す）
  static int _calculateRequiredXP(int level) {
    if (level <= 1) return 0; // レベル1は0XPから開始

    // グループレベル9999に必要な総経験値: 約226,000XP
    // 3年間で獲得可能な経験値: 約226,000XP
    // 出勤: 780日 × 50XP = 39,000XP
    // 焙煎: 468回 × 200XP = 93,600XP
    // ドリップパック: 46,800個 × 2XP = 93,600XP（週300個 × 3年）
    // 合計: 226,200XP

    // 150パック1回（300XP）で適切なレベルアップになるよう調整
    if (level <= 1) return 0;

    // レベル1-5: 非常に簡単（50XP/レベル）
    if (level <= 5) {
      return (level - 1) * 50;
    }
    // レベル6-15: 簡単（80XP/レベル）
    else if (level <= 15) {
      return 200 + (level - 5) * 80;
    }
    // レベル16-30: 普通（120XP/レベル）
    else if (level <= 30) {
      return 1000 + (level - 15) * 120;
    }
    // レベル31-50: 少し難しい（180XP/レベル）
    else if (level <= 50) {
      return 2800 + (level - 30) * 180;
    }
    // レベル51-100: 難しい（250XP/レベル）
    else if (level <= 100) {
      return 6400 + (level - 50) * 250;
    }
    // レベル101-200: とても難しい（350XP/レベル）
    else if (level <= 200) {
      return 18900 + (level - 100) * 350;
    }
    // レベル201-500: 非常に難しい（500XP/レベル）
    else if (level <= 500) {
      return 53900 + (level - 200) * 500;
    }
    // レベル501-1000: 超難しい（750XP/レベル）
    else if (level <= 1000) {
      return 203900 + (level - 500) * 750;
    }
    // レベル1001-2000: 極めて難しい（1200XP/レベル）
    else if (level <= 2000) {
      return 579900 + (level - 1000) * 1200;
    }
    // レベル2001-4000: 伝説級（2000XP/レベル）
    else if (level <= 4000) {
      return 1779900 + (level - 2000) * 2000;
    }
    // レベル4001-7000: 神級（3500XP/レベル）
    else if (level <= 7000) {
      return 5779900 + (level - 4000) * 3500;
    }
    // レベル7001-9999: 超越級（6000XP/レベル）
    else if (level <= 9999) {
      return 16279900 + (level - 7000) * 6000;
    }
    // レベル9999以上
    else {
      return 34279900 + (level - 9999) * 10000;
    }
  }

  /// 新しい仕様に基づくレベルバッジを取得
  static List<GroupBadgeCondition> get levelBadgeConditions {
    return [
      GroupBadgeCondition(
        badgeId: 'group_level_5',
        name: '成長の芽',
        description: 'チュートリアル区間で達成',
        iconCodePoint: Icons.star_half.codePoint,
        color: Colors.green.shade500,
        category: BadgeCategory.level,
        checkCondition: (stats) => _checkGroupLevel(stats, 5),
      ),
      GroupBadgeCondition(
        badgeId: 'group_level_10',
        name: 'コーヒーの旅路',
        description: '最初の壁',
        iconCodePoint: Icons.star.codePoint,
        color: Colors.green.shade600,
        category: BadgeCategory.level,
        checkCondition: (stats) => _checkGroupLevel(stats, 10),
      ),
      GroupBadgeCondition(
        badgeId: 'group_level_20',
        name: 'チームの誇り',
        description: '頻繁に活動している証',
        iconCodePoint: Icons.workspace_premium_outlined.codePoint,
        color: Colors.blue.shade400,
        category: BadgeCategory.level,
        checkCondition: (stats) => _checkGroupLevel(stats, 20),
      ),
      GroupBadgeCondition(
        badgeId: 'group_level_50',
        name: '現場の主',
        description: '継続を実感',
        iconCodePoint: Icons.workspace_premium.codePoint,
        color: Colors.blue.shade600,
        category: BadgeCategory.level,
        checkCondition: (stats) => _checkGroupLevel(stats, 50),
      ),
      GroupBadgeCondition(
        badgeId: 'group_level_100',
        name: 'ベテランブリュワー',
        description: '長期運用へ',
        iconCodePoint: Icons.auto_awesome_outlined.codePoint,
        color: Colors.orange.shade600,
        category: BadgeCategory.level,
        checkCondition: (stats) => _checkGroupLevel(stats, 100),
      ),
      GroupBadgeCondition(
        badgeId: 'group_level_250',
        name: '伝説の焙煎士',
        description: '上位組へ',
        iconCodePoint: Icons.auto_awesome.codePoint,
        color: Colors.orange.shade700,
        category: BadgeCategory.level,
        checkCondition: (stats) => _checkGroupLevel(stats, 250),
      ),
      GroupBadgeCondition(
        badgeId: 'group_level_500',
        name: '百戦錬磨',
        description: '特別感ある称号',
        iconCodePoint: Icons.emoji_events_outlined.codePoint,
        color: Colors.purple.shade500,
        category: BadgeCategory.level,
        checkCondition: (stats) => _checkGroupLevel(stats, 500),
      ),
      GroupBadgeCondition(
        badgeId: 'group_level_1000',
        name: '殿堂入り',
        description: '初代達成のインパクト',
        iconCodePoint: Icons.emoji_events.codePoint,
        color: Colors.purple.shade700,
        category: BadgeCategory.level,
        checkCondition: (stats) => _checkGroupLevel(stats, 1000),
      ),
      GroupBadgeCondition(
        badgeId: 'group_level_2000',
        name: 'コーヒーの神話',
        description: '長期ユーザーに',
        iconCodePoint: Icons.workspace_premium.codePoint,
        color: Colors.indigo.shade600,
        category: BadgeCategory.level,
        checkCondition: (stats) => _checkGroupLevel(stats, 2000),
      ),
      GroupBadgeCondition(
        badgeId: 'group_level_3000',
        name: '焙煎の系譜',
        description: 'レア称号として魅力的',
        iconCodePoint: Icons.auto_awesome.codePoint,
        color: Colors.indigo.shade800,
        category: BadgeCategory.level,
        checkCondition: (stats) => _checkGroupLevel(stats, 3000),
      ),
      GroupBadgeCondition(
        badgeId: 'group_level_5000',
        name: '深煎の極み',
        description: '超高難度',
        iconCodePoint: Icons.workspace_premium.codePoint,
        color: Colors.red.shade600,
        category: BadgeCategory.level,
        checkCondition: (stats) => _checkGroupLevel(stats, 5000),
      ),
      GroupBadgeCondition(
        badgeId: 'group_level_7500',
        name: '究極の香り',
        description: '伝説級称号',
        iconCodePoint: Icons.auto_awesome.codePoint,
        color: Colors.red.shade800,
        category: BadgeCategory.level,
        checkCondition: (stats) => _checkGroupLevel(stats, 7500),
      ),
      GroupBadgeCondition(
        badgeId: 'group_level_9999',
        name: 'Lv.9999 到達',
        description: '最終到達記念称号（特別演出）',
        iconCodePoint: Icons.workspace_premium.codePoint,
        color: Colors.amber.shade700,
        category: BadgeCategory.level,
        checkCondition: (stats) => _checkGroupLevel(stats, 9999),
      ),
    ];
  }
}

/// 焙煎時間バッジの定数
class RoastTimeBadgeConstants {
  // バッジ獲得条件（累積焙煎時間・分単位）
  static const Map<String, int> roastTimeThresholds = {
    'roast_time_10min': 10, // 初火入れ
    'roast_time_30min': 30, // 火力調整中
    'roast_time_1h': 60, // 焙煎見習い
    'roast_time_3h': 180, // コーヒーの香り
    'roast_time_6h': 360, // 焙煎の手応え
    'roast_time_12h': 720, // 火入れ職人
    'roast_time_25h': 1500, // ロースター初級
    'roast_time_50h': 3000, // 焙煎マスター
    'roast_time_100h': 6000, // 高火力の覇者
    'roast_time_166h': 10000, // 炎の継承者
  };

  // バッジ名
  static const Map<String, String> badgeNames = {
    'roast_time_10min': '初火入れ',
    'roast_time_30min': '火力調整中',
    'roast_time_1h': '焙煎見習い',
    'roast_time_3h': 'コーヒーの香り',
    'roast_time_6h': '焙煎の手応え',
    'roast_time_12h': '火入れ職人',
    'roast_time_25h': 'ロースター初級',
    'roast_time_50h': '焙煎マスター',
    'roast_time_100h': '高火力の覇者',
    'roast_time_166h': '炎の継承者',
  };

  // バッジ説明
  static const Map<String, String> badgeDescriptions = {
    'roast_time_10min': 'グループで累計10分の焙煎を達成',
    'roast_time_30min': 'グループで累計30分の焙煎を達成',
    'roast_time_1h': 'グループで累計1時間の焙煎を達成',
    'roast_time_3h': 'グループで累計3時間の焙煎を達成',
    'roast_time_6h': 'グループで累計6時間の焙煎を達成',
    'roast_time_12h': 'グループで累計12時間の焙煎を達成',
    'roast_time_25h': 'グループで累計25時間の焙煎を達成',
    'roast_time_50h': 'グループで累計50時間の焙煎を達成',
    'roast_time_100h': 'グループで累計100時間の焙煎を達成',
    'roast_time_166h': 'グループで累計166時間の焙煎を達成',
  };

  // バッジアイコン
  static const Map<String, IconData> badgeIcons = {
    'roast_time_10min': Icons.local_fire_department_outlined,
    'roast_time_30min': Icons.local_fire_department,
    'roast_time_1h': Icons.whatshot_outlined,
    'roast_time_3h': Icons.whatshot,
    'roast_time_6h': Icons.timer_outlined,
    'roast_time_12h': Icons.timer,
    'roast_time_25h': Icons.workspace_premium_outlined,
    'roast_time_50h': Icons.workspace_premium,
    'roast_time_100h': Icons.auto_awesome_outlined,
    'roast_time_166h': Icons.auto_awesome,
  };

  // バッジ色（段階的に変化）
  static const Map<String, Color> badgeColors = {
    'roast_time_10min': Colors.orange,
    'roast_time_30min': Colors.deepOrange,
    'roast_time_1h': Colors.red,
    'roast_time_3h': Colors.pink,
    'roast_time_6h': Colors.purple,
    'roast_time_12h': Colors.indigo,
    'roast_time_25h': Colors.blue,
    'roast_time_50h': Colors.teal,
    'roast_time_100h': Colors.green,
    'roast_time_166h': Colors.amber,
  };
}

/// ドリップパックバッジの定数
class DripPackBadgeConstants {
  // バッジ獲得条件（累積ドリップパック作成数）
  static const Map<String, int> dripPackThresholds = {
    'drip_pack_50': 50, // 最初の一滴
    'drip_pack_150': 150, // はじめての箱詰め
    'drip_pack_500': 500, // 毎日の味方
    'drip_pack_1000': 1000, // ちいさな工場
    'drip_pack_2000': 2000, // 量産ライン始動
    'drip_pack_5000': 5000, // ドリップ職人
    'drip_pack_8000': 8000, // アロママスター
    'drip_pack_12000': 12000, // コーヒー供給者
    'drip_pack_16000': 16000, // 日常の焙煎者
    'drip_pack_20000': 20000, // 湯気の誇り
    'drip_pack_25000': 25000, // 伝説のドリッパー
    'drip_pack_30000': 30000, // 殿堂入りパッカー
    'drip_pack_50000': 50000, // 究極の一杯
  };

  // バッジ名
  static const Map<String, String> badgeNames = {
    'drip_pack_50': '最初の一滴',
    'drip_pack_150': 'はじめての箱詰め',
    'drip_pack_500': '毎日の味方',
    'drip_pack_1000': 'ちいさな工場',
    'drip_pack_2000': '量産ライン始動',
    'drip_pack_5000': 'ドリップ職人',
    'drip_pack_8000': 'アロママスター',
    'drip_pack_12000': 'コーヒー供給者',
    'drip_pack_16000': '日常の焙煎者',
    'drip_pack_20000': '湯気の誇り',
    'drip_pack_25000': '伝説のドリッパー',
    'drip_pack_30000': '殿堂入りパッカー',
    'drip_pack_50000': '究極の一杯',
  };

  // バッジ説明
  static const Map<String, String> badgeDescriptions = {
    'drip_pack_50': 'グループで累計50個のドリップパックを作成',
    'drip_pack_150': 'グループで累計150個のドリップパックを作成',
    'drip_pack_500': 'グループで累計500個のドリップパックを作成',
    'drip_pack_1000': 'グループで累計1000個のドリップパックを作成',
    'drip_pack_2000': 'グループで累計2000個のドリップパックを作成',
    'drip_pack_5000': 'グループで累計5000個のドリップパックを作成',
    'drip_pack_8000': 'グループで累計8000個のドリップパックを作成',
    'drip_pack_12000': 'グループで累計12000個のドリップパックを作成',
    'drip_pack_16000': 'グループで累計16000個のドリップパックを作成',
    'drip_pack_20000': 'グループで累計20000個のドリップパックを作成',
    'drip_pack_25000': 'グループで累計25000個のドリップパックを作成',
    'drip_pack_30000': 'グループで累計30000個のドリップパックを作成',
    'drip_pack_50000': 'グループで累計50000個のドリップパックを作成',
  };

  // バッジアイコン
  static const Map<String, IconData> badgeIcons = {
    'drip_pack_50': Icons.local_cafe_outlined,
    'drip_pack_150': Icons.local_cafe,
    'drip_pack_500': Icons.local_drink_outlined,
    'drip_pack_1000': Icons.local_drink,
    'drip_pack_2000': Icons.coffee_outlined,
    'drip_pack_5000': Icons.coffee,
    'drip_pack_8000': Icons.emoji_food_beverage_outlined,
    'drip_pack_12000': Icons.emoji_food_beverage,
    'drip_pack_16000': Icons.workspace_premium_outlined,
    'drip_pack_20000': Icons.workspace_premium,
    'drip_pack_25000': Icons.auto_awesome_outlined,
    'drip_pack_30000': Icons.auto_awesome,
    'drip_pack_50000': Icons.emoji_events,
  };

  // バッジ色（段階的に変化）
  static Map<String, Color> get badgeColors => {
    'drip_pack_50': Colors.brown,
    'drip_pack_150': Colors.brown.shade600,
    'drip_pack_500': Colors.brown.shade800,
    'drip_pack_1000': Colors.orange.shade400,
    'drip_pack_2000': Colors.orange.shade600,
    'drip_pack_5000': Colors.orange.shade800,
    'drip_pack_8000': Colors.red.shade400,
    'drip_pack_12000': Colors.red.shade600,
    'drip_pack_16000': Colors.red.shade800,
    'drip_pack_20000': Colors.purple.shade400,
    'drip_pack_25000': Colors.purple.shade600,
    'drip_pack_30000': Colors.purple.shade800,
    'drip_pack_50000': Colors.amber.shade600,
  };
}
