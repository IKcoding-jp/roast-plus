import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roastplus/models/group_gamification_models.dart';
import 'package:roastplus/models/group_provider.dart';

class BadgeListController extends ChangeNotifier {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _selectedCategory = 'all';
  GroupGamificationProfile? _cachedProfile;
  String? _currentGroupId;

  final Map<String, String> _categories = {
    'all': 'すべて',
    'attendance': '出勤',
    'roasting': '焙煎',
    'dripPack': 'ドリップパック',
    'level': 'レベル',
    'special': '特別',
  };

  BuildContext? _context; // contextを保持

  String get selectedCategory => _selectedCategory;
  Map<String, String> get categories => _categories;
  GroupGamificationProfile? get cachedProfile => _cachedProfile;
  Animation<double> get fadeAnimation => _fadeAnimation;
  bool get hasGroup =>
      _context != null &&
      Provider.of<GroupProvider>(_context!, listen: false).hasGroup;

  void initialize(TickerProvider vsync, BuildContext context) {
    _context = context;
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: vsync,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadProfile();
    });
    _startPeriodicUpdate();
  }

  /// 定期的なプロフィール更新チェックを開始
  void _startPeriodicUpdate() {
    Future.delayed(Duration(seconds: 2), () {
      if (_context != null) {
        _checkProfileUpdate();
        _startPeriodicUpdate(); // 再帰的に次のチェックをスケジュール
      }
    });
  }

  /// プロフィールの更新をチェック
  void _checkProfileUpdate() {
    try {
      if (_context == null) return;
      final groupProvider = Provider.of<GroupProvider>(
        _context!,
        listen: false,
      );
      if (groupProvider.hasGroup) {
        final groupId = groupProvider.currentGroup!.id;
        final profile = groupProvider.getGroupGamificationProfile(groupId);

        if (profile != null && _cachedProfile != profile) {
          _cachedProfile = profile;
          print(
            'バッジ一覧: プロフィールが更新されました - レベル: ${profile.level}, バッジ数: ${profile.badges.length}',
          );
          notifyListeners();
        }
      }
    } catch (e) {
      print('バッジ一覧コントローラー: プロフィール更新チェックエラー: $e');
    }
  }

  void didChangeDependencies(BuildContext context) {
    _context = context;
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    if (groupProvider.hasGroup) {
      final groupId = groupProvider.currentGroup!.id;

      if (_currentGroupId != groupId) {
        _currentGroupId = groupId;
        groupProvider.watchGroupGamificationProfile(groupId);
        final profile = groupProvider.getGroupGamificationProfile(groupId);
        if (profile != null) {
          _cachedProfile = profile;
          notifyListeners();
        }
      } else {
        final profile = groupProvider.getGroupGamificationProfile(groupId);
        if (profile != null && _cachedProfile != profile) {
          _cachedProfile = profile;
          notifyListeners();
        }
      }
    }
  }

  /// プロフィールを事前読み込み
  Future<void> _preloadProfile() async {
    try {
      if (_context == null) return;
      final groupProvider = Provider.of<GroupProvider>(
        _context!,
        listen: false,
      );
      if (groupProvider.hasGroup) {
        final groupId = groupProvider.currentGroup!.id;
        groupProvider.watchGroupGamificationProfile(groupId);
        final profile = groupProvider.getGroupGamificationProfile(groupId);

        if (profile != null) {
          _cachedProfile = profile;
          notifyListeners();
        } else {
          notifyListeners();
        }
      } else {
        notifyListeners();
      }
    } catch (e) {
      print('バッジ一覧コントローラー: プロフィール事前読み込みエラー: $e');
      notifyListeners();
    }
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  /// バッジ進捗を計算
  double calculateBadgeProgress(GroupBadgeCondition condition) {
    if (_cachedProfile == null) return 0.0;
    final profile = _cachedProfile!;
    final stats = profile.stats;

    switch (condition.badgeId) {
      case 'group_attendance_10':
        return (stats.totalAttendanceDays / 10).clamp(0.0, 1.0);
      case 'group_attendance_25':
        return (stats.totalAttendanceDays / 25).clamp(0.0, 1.0);
      case 'group_attendance_50':
        return (stats.totalAttendanceDays / 50).clamp(0.0, 1.0);
      case 'group_attendance_100':
        return (stats.totalAttendanceDays / 100).clamp(0.0, 1.0);
      case 'group_attendance_200':
        return (stats.totalAttendanceDays / 200).clamp(0.0, 1.0);
      case 'group_attendance_300':
        return (stats.totalAttendanceDays / 300).clamp(0.0, 1.0);
      case 'group_attendance_500':
        return (stats.totalAttendanceDays / 500).clamp(0.0, 1.0);
      case 'group_attendance_800':
        return (stats.totalAttendanceDays / 800).clamp(0.0, 1.0);
      case 'group_attendance_1000':
        return (stats.totalAttendanceDays / 1000).clamp(0.0, 1.0);
      case 'group_attendance_2000':
        return (stats.totalAttendanceDays / 2000).clamp(0.0, 1.0);
      case 'group_attendance_3000':
        return (stats.totalAttendanceDays / 3000).clamp(0.0, 1.0);
      case 'group_attendance_5000':
        return (stats.totalAttendanceDays / 5000).clamp(0.0, 1.0);

      case 'roast_time_10min':
        return (stats.totalRoastTimeMinutes / 10).clamp(0.0, 1.0);
      case 'roast_time_30min':
        return (stats.totalRoastTimeMinutes / 30).clamp(0.0, 1.0);
      case 'roast_time_1h':
        return (stats.totalRoastTimeMinutes / 60).clamp(0.0, 1.0);
      case 'roast_time_3h':
        return (stats.totalRoastTimeMinutes / 180).clamp(0.0, 1.0);
      case 'roast_time_6h':
        return (stats.totalRoastTimeMinutes / 360).clamp(0.0, 1.0);
      case 'roast_time_12h':
        return (stats.totalRoastTimeMinutes / 720).clamp(0.0, 1.0);
      case 'roast_time_25h':
        return (stats.totalRoastTimeMinutes / 1500).clamp(0.0, 1.0);
      case 'roast_time_50h':
        return (stats.totalRoastTimeMinutes / 3000).clamp(0.0, 1.0);
      case 'roast_time_100h':
        return (stats.totalRoastTimeMinutes / 6000).clamp(0.0, 1.0);
      case 'roast_time_166h':
        return (stats.totalRoastTimeMinutes / 10000).clamp(0.0, 1.0);

      case 'drip_pack_50':
        return (stats.totalDripPackCount / 50).clamp(0.0, 1.0);
      case 'drip_pack_150':
        return (stats.totalDripPackCount / 150).clamp(0.0, 1.0);
      case 'drip_pack_500':
        return (stats.totalDripPackCount / 500).clamp(0.0, 1.0);
      case 'drip_pack_1000':
        return (stats.totalDripPackCount / 1000).clamp(0.0, 1.0);
      case 'drip_pack_2000':
        return (stats.totalDripPackCount / 2000).clamp(0.0, 1.0);
      case 'drip_pack_5000':
        return (stats.totalDripPackCount / 5000).clamp(0.0, 1.0);
      case 'drip_pack_8000':
        return (stats.totalDripPackCount / 8000).clamp(0.0, 1.0);
      case 'drip_pack_12000':
        return (stats.totalDripPackCount / 12000).clamp(0.0, 1.0);
      case 'drip_pack_16000':
        return (stats.totalDripPackCount / 16000).clamp(0.0, 1.0);
      case 'drip_pack_20000':
        return (stats.totalDripPackCount / 20000).clamp(0.0, 1.0);
      case 'drip_pack_25000':
        return (stats.totalDripPackCount / 25000).clamp(0.0, 1.0);
      case 'drip_pack_30000':
        return (stats.totalDripPackCount / 30000).clamp(0.0, 1.0);
      case 'drip_pack_50000':
        return (stats.totalDripPackCount / 50000).clamp(0.0, 1.0);

      case 'group_level_1':
      case 'group_level_5':
      case 'group_level_10':
      case 'group_level_20':
      case 'group_level_50':
      case 'group_level_100':
      case 'group_level_250':
      case 'group_level_500':
      case 'group_level_1000':
      case 'group_level_2000':
      case 'group_level_3000':
      case 'group_level_5000':
      case 'group_level_7500':
      case 'group_level_9999':
        return _calculateLevelBadgeProgress(condition, profile.stats);

      case 'group_tasting_100':
        return (profile.stats.totalTastingRecords / 100).clamp(0.0, 1.0);

      default:
        return 0.0;
    }
  }

  /// レベルバッジの進捗率を計算
  double _calculateLevelBadgeProgress(
    GroupBadgeCondition condition,
    GroupStats stats,
  ) {
    try {
      final levelMatch = RegExp(
        r'group_level_(\d+)',
      ).firstMatch(condition.badgeId);
      if (levelMatch == null) return 0.0;

      final requiredLevel = int.parse(levelMatch.group(1)!);

      if (_context == null) return 0.0;
      final groupProvider = Provider.of<GroupProvider>(
        _context!,
        listen: false,
      );
      if (groupProvider.hasGroup) {
        final groupId = groupProvider.currentGroup!.id;
        final profile = groupProvider.getGroupGamificationProfile(groupId);
        if (profile != null) {
          final progress = (profile.level / requiredLevel).clamp(0.0, 1.0);
          print(
            'バッジ一覧コントローラー: レベルバッジ進捗計算: ${condition.badgeId} - 現在レベル=${profile.level}, 必要レベル=$requiredLevel, 進捗=$progress',
          );
          return progress;
        }
      }
    } catch (e) {
      print('バッジ一覧コントローラー: レベル進捗計算エラー: $e');
    }

    final estimatedXP =
        (stats.totalAttendanceDays * 10) +
        (stats.totalRoastTimeMinutes.toInt() * 1) +
        (stats.totalDripPackCount * 5) +
        (stats.totalTastingRecords * 20);

    final estimatedLevel = _calculateLevelFromXP(estimatedXP);
    final levelMatch = RegExp(
      r'group_level_(\d+)',
    ).firstMatch(condition.badgeId);
    if (levelMatch != null) {
      final requiredLevel = int.parse(levelMatch.group(1)!);
      return (estimatedLevel / requiredLevel).clamp(0.0, 1.0);
    }

    return 0.0;
  }

  /// バッジの進捗テキストを取得
  String getBadgeProgressText(GroupBadgeCondition condition) {
    if (_cachedProfile == null) return '';
    if (condition.category == BadgeCategory.level) {
      return _getLevelBadgeProgressText(condition);
    }
    return '${(calculateBadgeProgress(condition) * 100).toInt()}%';
  }

  /// レベルバッジの進捗テキストを取得
  String _getLevelBadgeProgressText(GroupBadgeCondition condition) {
    try {
      final levelMatch = RegExp(
        r'group_level_(\d+)',
      ).firstMatch(condition.badgeId);
      if (levelMatch == null) return '';

      final requiredLevel = int.parse(levelMatch.group(1)!);

      if (_context == null) return '';
      final groupProvider = Provider.of<GroupProvider>(
        _context!,
        listen: false,
      );
      if (groupProvider.hasGroup) {
        final groupId = groupProvider.currentGroup!.id;
        final profile = groupProvider.getGroupGamificationProfile(groupId);
        if (profile != null) {
          final currentLevel = profile.level;
          final isEarned = currentLevel >= requiredLevel;

          if (isEarned) {
            return 'Lv.$currentLevel / Lv.$requiredLevel';
          } else {
            return 'Lv.$currentLevel / Lv.$requiredLevel';
          }
        }
      }

      return 'Lv.? / Lv.$requiredLevel';
    } catch (e) {
      print('バッジ一覧コントローラー: レベルバッジ進捗テキスト生成エラー: $e');
      return '';
    }
  }

  /// バッジの達成条件を取得
  String getBadgeDescription(GroupBadgeCondition condition) {
    if (condition.category == BadgeCategory.level) {
      return _getLevelBadgeDescription(condition);
    }
    return condition.description;
  }

  /// レベルバッジの達成条件を動的に生成
  String _getLevelBadgeDescription(GroupBadgeCondition condition) {
    try {
      final levelMatch = RegExp(
        r'group_level_(\d+)',
      ).firstMatch(condition.badgeId);
      if (levelMatch == null) return condition.description;

      final requiredLevel = int.parse(levelMatch.group(1)!);

      if (_context == null) return condition.description;
      final groupProvider = Provider.of<GroupProvider>(
        _context!,
        listen: false,
      );
      if (groupProvider.hasGroup) {
        final groupId = groupProvider.currentGroup!.id;
        final profile = groupProvider.getGroupGamificationProfile(groupId);
        if (profile != null) {
          final currentLevel = profile.level;
          final isEarned = currentLevel >= requiredLevel;

          if (isEarned) {
            return 'グループレベルがLv.$requiredLevelに到達しました！';
          } else {
            return 'グループレベルをLv.$requiredLevelまで上げる\n（現在: Lv.$currentLevel）';
          }
        }
      }

      return 'グループレベルをLv.$requiredLevelまで上げる';
    } catch (e) {
      print('バッジ一覧コントローラー: レベルバッジ説明生成エラー: $e');
      return condition.description;
    }
  }

  /// 経験値からレベルを計算
  int _calculateLevelFromXP(int experiencePoints) {
    int level = 1;
    while (experiencePoints >= _calculateRequiredXP(level + 1)) {
      level++;
    }
    return level;
  }

  /// レベルに必要な経験値を計算（GroupGamificationProfileと統一）
  int _calculateRequiredXP(int level) {
    if (level <= 1) return 0; // レベル1は0XPから開始
    if (level <= 20) return (level - 1) * 10; // レベル2-20: 10XPずつ増加
    if (level <= 100) return 190 + (level - 20) * 15; // レベル21-100: 15XPずつ増加
    if (level <= 1000) {
      return 1390 + (level - 100) * 20; // レベル101-1000: 20XPずつ増加
    }
    return 18190 + (level - 1000) * 25; // レベル1001以上: 25XPずつ増加
  }

  /// フィルタリングされたバッジリスト
  List<GroupBadgeCondition> getFilteredBadges() {
    final allBadges = GroupBadgeConditions.conditions;

    if (_selectedCategory == 'all') {
      return allBadges;
    }

    return allBadges.where((badge) {
      switch (_selectedCategory) {
        case 'attendance':
          return badge.category == BadgeCategory.attendance;
        case 'roasting':
          return badge.category == BadgeCategory.roasting;
        case 'dripPack':
          return badge.category == BadgeCategory.dripPack;
        case 'level':
          return badge.category == BadgeCategory.level;
        case 'special':
          return badge.category == BadgeCategory.special;
        default:
          return false;
      }
    }).toList();
  }

  /// レベルバッジの条件を満たしているかチェック
  bool checkLevelBadgeCondition(GroupBadgeCondition condition) {
    if (_cachedProfile == null) return false;
    final currentLevel = _cachedProfile!.level;
    try {
      final levelMatch = RegExp(
        r'group_level_(\d+)',
      ).firstMatch(condition.badgeId);
      if (levelMatch == null) return false;

      final requiredLevel = int.parse(levelMatch.group(1)!);
      return currentLevel >= requiredLevel;
    } catch (e) {
      print('バッジ一覧コントローラー: レベルバッジ条件チェックエラー: $e');
      return false;
    }
  }

  // 獲得済みバッジのIDセットを返す
  Set<String> getEarnedBadgeIds() {
    return _cachedProfile?.badges.map((b) => b.id).toSet() ?? {};
  }

  // 獲得済みバッジオブジェクトを返す
  GroupBadge? getEarnedBadge(String badgeId) {
    return _cachedProfile?.badges.firstWhere(
      (b) => b.id == badgeId,
      orElse: () => throw Exception('Badge not found'),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    // プロフィールの監視を停止
    try {
      if (_context != null) {
        final groupProvider = Provider.of<GroupProvider>(
          _context!,
          listen: false,
        );
        if (groupProvider.hasGroup) {
          final groupId = groupProvider.currentGroup!.id;
          groupProvider.unwatchGroupGamificationProfile(groupId);
        }
      }
    } catch (e) {
      print('バッジ一覧コントローラー: dispose中のエラー: $e');
    }
    _context = null; // contextをクリア
    super.dispose();
  }
}
