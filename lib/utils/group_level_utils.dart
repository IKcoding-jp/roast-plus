
/// グループレベルシステムのユーティリティ関数
class GroupLevelUtils {
  /// 新しい仕様に基づくレベルに必要な経験値を計算
  static int getRequiredXpForLevel(int level) {
    if (level <= 20) return 10; // 最初はサクサク
    if (level <= 100) return 10 + (level - 20); // 緩やかに上昇
    if (level <= 1000) return 30 + ((level - 100) ~/ 10); // 徐々に増える
    return 50 + ((level - 1000) ~/ 100); // 高Lv帯でも急激に伸びない
  }

  /// 経験値からレベルを計算
  static int calculateLevelFromXp(int experiencePoints) {
    int level = 1;
    int totalRequiredXp = 0;

    while (level <= 9999) {
      final requiredXp = getRequiredXpForLevel(level);
      if (experiencePoints < totalRequiredXp + requiredXp) {
        break;
      }
      totalRequiredXp += requiredXp;
      level++;
    }

    return level;
  }

  /// 指定レベルまでの累積必要経験値を計算
  static int calculateTotalRequiredXp(int level) {
    int totalXp = 0;
    for (int i = 1; i <= level; i++) {
      totalXp += getRequiredXpForLevel(i);
    }
    return totalXp;
  }

  /// 現在の経験値でのレベル進行度を計算（0.0 - 1.0）
  static double calculateLevelProgress(int experiencePoints, int currentLevel) {
    final currentLevelXp = calculateTotalRequiredXp(currentLevel);
    final nextLevelXp = calculateTotalRequiredXp(currentLevel + 1);
    final progressXp = experiencePoints - currentLevelXp;
    final totalLevelXp = nextLevelXp - currentLevelXp;
    return (progressXp / totalLevelXp).clamp(0.0, 1.0);
  }

  /// 次のレベルまでに必要な経験値を計算
  static int calculateXpToNextLevel(int experiencePoints, int currentLevel) {
    final nextLevelXp = calculateTotalRequiredXp(currentLevel + 1);
    return nextLevelXp - experiencePoints;
  }

  /// 3年間でLv.9999に到達するための1日あたりの必要経験値を計算
  static int calculateDailyXpForMaxLevel() {
    const int targetLevel = 9999;
    const int daysIn3Years = 3 * 365;

    final totalRequiredXp = calculateTotalRequiredXp(targetLevel);
    return (totalRequiredXp / daysIn3Years).ceil();
  }

  /// レベルバッジの獲得条件をチェック
  static List<int> getLevelBadgeThresholds() {
    return [
      1,
      5,
      10,
      20,
      50,
      100,
      250,
      500,
      1000,
      2000,
      3000,
      5000,
      7500,
      9999,
    ];
  }

  /// 指定レベルで獲得できるバッジを取得
  static List<int> getEarnedBadges(int level) {
    final thresholds = getLevelBadgeThresholds();
    return thresholds.where((threshold) => level >= threshold).toList();
  }

  /// 次のバッジ獲得レベルを取得
  static int? getNextBadgeLevel(int level) {
    final thresholds = getLevelBadgeThresholds();
    for (final threshold in thresholds) {
      if (level < threshold) {
        return threshold;
      }
    }
    return null; // 全てのバッジを獲得済み
  }

  /// レベルアップ時の経験値増加をシミュレート
  static Map<String, dynamic> simulateLevelUp(
    int currentLevel,
    int additionalXp,
  ) {
    final currentTotalXp = calculateTotalRequiredXp(currentLevel);
    final newTotalXp = currentTotalXp + additionalXp;
    final newLevel = calculateLevelFromXp(newTotalXp);

    return {
      'currentLevel': currentLevel,
      'newLevel': newLevel,
      'levelUp': newLevel > currentLevel,
      'currentXp': currentTotalXp,
      'newXp': newTotalXp,
      'additionalXp': additionalXp,
      'earnedBadges': getEarnedBadges(newLevel),
      'nextBadgeLevel': getNextBadgeLevel(newLevel),
    };
  }

  /// 3年間のレベル進行シミュレーション
  static List<Map<String, dynamic>> simulate3YearProgress() {
    const int daysIn3Years = 3 * 365;
    const int dailyXp = 64; // 1日64XPで約3年間でLv.9999到達

    List<Map<String, dynamic>> progress = [];
    int totalXp = 0;

    for (int day = 1; day <= daysIn3Years; day++) {
      totalXp += dailyXp;
      final level = calculateLevelFromXp(totalXp);

      // 月次レポート（30日ごと）
      if (day % 30 == 0) {
        progress.add({
          'day': day,
          'month': (day / 30).ceil(),
          'level': level,
          'totalXp': totalXp,
          'dailyXp': dailyXp,
          'earnedBadges': getEarnedBadges(level),
        });
      }

      // 年次レポート
      if (day % 365 == 0) {
        progress.add({
          'day': day,
          'year': (day / 365).ceil(),
          'level': level,
          'totalXp': totalXp,
          'dailyXp': dailyXp,
          'earnedBadges': getEarnedBadges(level),
        });
      }
    }

    return progress;
  }

  /// レベルバッジ名を取得
  static String getLevelBadgeName(int level) {
    final badgeNames = {
      1: 'Lv.1 達成！',
      5: '成長の芽',
      10: 'コーヒーの旅路',
      20: 'チームの誇り',
      50: '現場の主',
      100: 'ベテランブリュワー',
      250: '伝説の焙煎士',
      500: '百戦錬磨',
      1000: '殿堂入り',
      2000: 'コーヒーの神話',
      3000: '焙煎の系譜',
      5000: '深煎の極み',
      7500: '究極の香り',
      9999: 'Lv.9999 到達',
    };

    return badgeNames[level] ?? '不明なバッジ';
  }

  /// レベルに応じた色を取得
  static String getLevelColor(int level) {
    if (level >= 9999) return 'gold';
    if (level >= 1000) return 'purple';
    if (level >= 500) return 'red';
    if (level >= 200) return 'orange';
    if (level >= 100) return 'blue';
    if (level >= 50) return 'green';
    if (level >= 20) return 'teal';
    if (level >= 10) return 'indigo';
    if (level >= 5) return 'brown';
    return 'grey';
  }
}
