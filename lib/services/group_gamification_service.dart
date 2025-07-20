import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as Math;
import '../models/group_gamification_models.dart';
import '../widgets/group_celebration_helper.dart';
import 'roast_record_firestore_service.dart';
import 'drip_counter_firestore_service.dart';
import 'auto_sync_service.dart';

/// グループ中心のゲーミフィケーション管理サービス
class GroupGamificationService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // キャッシュ機能
  static final Map<String, GroupGamificationProfile> _profileCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiration = Duration(minutes: 15); // 15分間キャッシュ

  static String? get _uid => _auth.currentUser?.uid;
  static String? get _userDisplayName =>
      _auth.currentUser?.displayName ?? '匿名ユーザー';

  /// グループのゲーミフィケーションプロフィールを取得
  static Future<GroupGamificationProfile> getGroupProfile(
    String groupId,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    // キャッシュをチェック
    if (_profileCache.containsKey(groupId)) {
      final timestamp = _cacheTimestamps[groupId];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _cacheExpiration) {
        print('GroupGamificationService: キャッシュからプロフィールを取得: $groupId');
        return _profileCache[groupId]!;
      }
    }

    try {
      print('GroupGamificationService: Firestoreからプロフィールを取得: $groupId');
      final doc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('gamification')
          .doc('profile')
          .get();

      GroupGamificationProfile profile;
      if (!doc.exists) {
        // 初回の場合は初期プロフィールを作成
        profile = GroupGamificationProfile.initial(groupId);
        await _saveGroupProfile(groupId, profile);
      } else {
        final data = doc.data()!;
        profile = GroupGamificationProfile.fromJson(data);
      }

      // キャッシュに保存
      _profileCache[groupId] = profile;
      _cacheTimestamps[groupId] = DateTime.now();

      print('GroupGamificationService: プロフィール取得完了: $groupId');
      return profile;
    } catch (e) {
      print('グループプロフィール取得エラー: $e');
      final fallbackProfile = GroupGamificationProfile.initial(groupId);

      // エラー時もキャッシュに保存（短時間）
      _profileCache[groupId] = fallbackProfile;
      _cacheTimestamps[groupId] = DateTime.now();

      return fallbackProfile;
    }
  }

  /// グループのゲーミフィケーションプロフィールを保存
  static Future<void> _saveGroupProfile(
    String groupId,
    GroupGamificationProfile profile,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      // バッジの重複を除去
      final uniqueBadges = <GroupBadge>[];
      final seenBadgeIds = <String>{};

      for (final badge in profile.badges) {
        if (!seenBadgeIds.contains(badge.id)) {
          uniqueBadges.add(badge);
          seenBadgeIds.add(badge.id);
        } else {
          print('⚠️ プロフィール保存時にバッジ重複を検知、除外: ${badge.id} (${badge.name})');
        }
      }

      if (uniqueBadges.length != profile.badges.length) {
        print(
          '⚠️ プロフィール保存時に${profile.badges.length - uniqueBadges.length}個の重複バッジを除外しました',
        );
      }

      // 重複除去後のプロフィールを作成
      final cleanProfile = profile.copyWith(badges: uniqueBadges);

      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('gamification')
          .doc('profile')
          .set({
            ...cleanProfile.toJson(),
            'lastUpdatedBy': _uid,
            'lastUpdatedByName': _userDisplayName,
            'version': 1,
          });

      print(
        'グループプロフィールを保存しました: Level ${cleanProfile.level}, XP ${cleanProfile.experiencePoints}, バッジ数 ${cleanProfile.badges.length}',
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
      // ドリップパック記録をグループに保存
      await _saveDripPackRecord(groupId, count);

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

  /// ドリップパック記録をグループに保存
  static Future<void> _saveDripPackRecord(String groupId, int count) async {
    try {
      final now = DateTime.now();
      final recordId = '${now.millisecondsSinceEpoch}_${_uid}';

      print(
        'ドリップパック記録保存開始: groupId=$groupId, count=$count, recordId=$recordId',
      );

      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('drip_pack_records')
          .doc(recordId)
          .set({
            'count': count,
            'timestamp': now.toIso8601String(),
            'userId': _uid,
            'userName': _userDisplayName,
            'recordId': recordId,
          });

      print('ドリップパック記録をグループに保存完了: $count個');
    } catch (e) {
      print('ドリップパック記録保存エラー: $e');
      rethrow;
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

      // 新しいレベルを計算
      final newLevel = _calculateLevel(newExperiencePoints);
      final levelUp = newLevel > currentProfile.level;

      // デバッグ情報を出力
      print('=== レベルアップ計算デバッグ ===');
      print('現在の経験値: ${currentProfile.experiencePoints}');
      print('獲得経験値: ${reward.experiencePoints}');
      print('新しい経験値: $newExperiencePoints');
      print('現在のレベル: ${currentProfile.level}');
      print('新しいレベル: $newLevel');
      print('レベルアップ: $levelUp');

      // レベル2に必要な経験値を確認
      final requiredForLevel2 = _calculateRequiredXP(2);
      print('レベル2に必要な経験値: $requiredForLevel2');
      print('レベル2達成可能: ${newExperiencePoints >= requiredForLevel2}');
      print('==============================');

      // 統計情報を更新
      final updatedStats = await _updateGroupStats(
        groupId,
        currentProfile.stats,
      );

      // 新しいバッジをチェック
      print('バッジチェック前の状態:');
      print('  現在のレベル: ${currentProfile.level}');
      print('  新しいレベル: $newLevel');
      print('  現在のバッジ数: ${currentProfile.badges.length}');
      print('  現在のバッジID: ${currentProfile.badges.map((b) => b.id).toList()}');

      final newBadges = await _checkNewBadges(groupId, updatedStats);

      // レベルアップした場合は、レベルバッジを特別にチェック
      List<GroupBadge> levelUpBadges = [];
      if (levelUp) {
        print('🎉 レベルアップ検知！ レベル${currentProfile.level} → $newLevel');
        print('レベルバッジの特別チェックを実行...');

        // 新しいレベルで獲得可能なレベルバッジをチェック
        levelUpBadges = await _checkLevelUpBadges(
          groupId,
          newLevel,
          currentProfile.badges,
        );

        if (levelUpBadges.isNotEmpty) {
          print('🎊 レベルアップで新しいレベルバッジを獲得: ${levelUpBadges.length}個');
          for (final badge in levelUpBadges) {
            print('   - ${badge.name} (${badge.id})');
          }
        }
      }

      // すべての新しいバッジを結合
      final allNewBadges = [...newBadges, ...levelUpBadges];

      // バッジの重複を除去
      final Set<String> existingBadgeIds = currentProfile.badges
          .map((b) => b.id)
          .toSet();
      final uniqueNewBadges = allNewBadges
          .where((badge) => !existingBadgeIds.contains(badge.id))
          .toList();

      if (uniqueNewBadges.length != allNewBadges.length) {
        print(
          '⚠️ バッジ重複を検知し、${allNewBadges.length - uniqueNewBadges.length}個のバッジを除外しました',
        );
        print(
          '   除外されたバッジID: ${allNewBadges.where((badge) => existingBadgeIds.contains(badge.id)).map((b) => b.id).toList()}',
        );
      }

      // プロフィールを更新
      final updatedProfile = currentProfile.copyWith(
        experiencePoints: newExperiencePoints,
        level: newLevel,
        stats: updatedStats,
        badges: [...currentProfile.badges, ...uniqueNewBadges],
        lastUpdated: DateTime.now(),
      );

      // プロフィールを保存
      await _saveGroupProfile(groupId, updatedProfile);

      return GroupActivityResult(
        success: true,
        message: reward.description,
        levelUp: levelUp,
        newBadges: allNewBadges,
        experienceGained: reward.experiencePoints,
        newLevel: newLevel,
      );
    } catch (e) {
      print('経験値追加エラー: $e');
      return GroupActivityResult(
        success: false,
        message: '経験値の追加に失敗しました',
        levelUp: false,
        newBadges: [],
        experienceGained: 0,
        newLevel: 0,
      );
    }
  }

  /// グループ統計情報を更新
  static Future<GroupStats> _updateGroupStats(
    String groupId,
    GroupStats currentStats,
  ) async {
    try {
      print('グループ統計更新開始: groupId=$groupId');
      print('現在の統計: ドリップパック=${currentStats.totalDripPackCount}');

      // 出勤統計を計算
      final attendanceStats = await _calculateAttendanceStats(groupId);

      // 焙煎統計を計算
      final roastingStats = await _calculateRoastingStats(groupId);

      // ドリップパック統計を計算
      final dripPackStats = await _calculateDripPackStats(groupId);

      // テイスティング統計を計算
      final tastingStats = await _calculateTastingStats(groupId);

      // 全員出勤日をチェック
      final allMemberAttendanceDays = await _checkAllMemberAttendance(groupId);

      final updatedStats = currentStats.copyWith(
        totalAttendanceDays: attendanceStats['totalDays'] ?? 0,
        totalRoastTimeMinutes: roastingStats['totalMinutes'] ?? 0.0,
        totalRoastDays: roastingStats['totalDays'] ?? 0,
        totalDripPackCount: dripPackStats['totalCount'] ?? 0,
        totalTastingRecords: tastingStats['totalRecords'] ?? 0,
        allMemberAttendanceDays: allMemberAttendanceDays,
        lastActivityDate: DateTime.now(),
      );

      print(
        '統計更新完了: ドリップパック=${updatedStats.totalDripPackCount} (変更: ${updatedStats.totalDripPackCount - currentStats.totalDripPackCount})',
      );

      return updatedStats;
    } catch (e) {
      print('統計情報更新エラー: $e');
      return currentStats;
    }
  }

  /// 出勤統計を計算
  static Future<Map<String, int>> _calculateAttendanceStats(
    String groupId,
  ) async {
    try {
      // グループの出勤記録を取得
      final attendanceSnapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('attendance')
          .get();

      final Set<String> uniqueDays = {};
      final Map<String, Set<String>> dailyMembers = {};

      for (final doc in attendanceSnapshot.docs) {
        final data = doc.data();
        final recordsList = data['records'] as List<dynamic>?;

        if (recordsList != null) {
          for (final recordData in recordsList) {
            try {
              final status = recordData['status'] as String?;
              if (status == 'present') {
                final dateKey = recordData['dateKey'] as String?;
                final memberName = recordData['memberName'] as String?;

                if (dateKey != null && memberName != null) {
                  uniqueDays.add(dateKey);

                  if (!dailyMembers.containsKey(dateKey)) {
                    dailyMembers[dateKey] = {};
                  }
                  dailyMembers[dateKey]!.add(memberName);
                }
              }
            } catch (e) {
              print('出勤記録のパースエラー: $e');
            }
          }
        }
      }

      return {'totalDays': uniqueDays.length};
    } catch (e) {
      print('出勤統計計算エラー: $e');
      return {'totalDays': 0};
    }
  }

  /// 焙煎統計を計算
  static Future<Map<String, dynamic>> _calculateRoastingStats(
    String groupId,
  ) async {
    try {
      // 新しい焙煎記録サービスを使用して統計を計算
      final roastStats =
          await RoastRecordFirestoreService.recalculateGroupRoastStats(groupId);

      return {
        'totalMinutes': roastStats['totalRoastTimeMinutes'] ?? 0.0,
        'totalDays': roastStats['totalRoastDays'] ?? 0,
        'totalSessions': roastStats['totalRoastSessions'] ?? 0,
      };
    } catch (e) {
      print('焙煎統計計算エラー: $e');
      return {'totalMinutes': 0.0, 'totalDays': 0, 'totalSessions': 0};
    }
  }

  /// ドリップパック統計を計算
  static Future<Map<String, int>> _calculateDripPackStats(
    String groupId,
  ) async {
    try {
      print('ドリップパック統計計算開始: groupId=$groupId');

      final dripPackSnapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('drip_pack_records')
          .get();

      print('ドリップパック記録数: ${dripPackSnapshot.docs.length}');

      int totalCount = 0;
      final Set<String> uniqueDays = {};

      for (final doc in dripPackSnapshot.docs) {
        final data = doc.data();
        final count = data['count'] ?? 0;
        final timestamp = DateTime.parse(
          data['timestamp'] ?? DateTime.now().toIso8601String(),
        );
        final dateKey =
            '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';

        final intCount = (count is int)
            ? count
            : (count is num)
            ? count.toInt()
            : 0;

        totalCount += intCount;
        uniqueDays.add(dateKey);

        print('ドリップパック記録: count=$count, intCount=$intCount, dateKey=$dateKey');
      }

      print('ドリップパック統計計算完了: 総数=$totalCount, 記録日数=${uniqueDays.length}');
      return {'totalCount': totalCount, 'totalDays': uniqueDays.length};
    } catch (e) {
      print('ドリップパック統計計算エラー: $e');
      return {'totalCount': 0, 'totalDays': 0};
    }
  }

  /// テイスティング統計を計算
  static Future<Map<String, int>> _calculateTastingStats(String groupId) async {
    try {
      final tastingSnapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('tasting_records')
          .get();

      return {'totalRecords': tastingSnapshot.docs.length};
    } catch (e) {
      print('テイスティング統計計算エラー: $e');
      return {'totalRecords': 0};
    }
  }

  /// 全員出勤日をチェック
  static Future<Set<String>> _checkAllMemberAttendance(String groupId) async {
    try {
      // グループメンバー数を取得
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      final groupData = groupDoc.data();
      final memberList = groupData?['members'] as List<dynamic>?;
      final num memberCountNum = memberList?.length ?? 0;
      final int memberCount = memberCountNum.toInt();

      if (memberCount == 0) return {};

      // 各日の出勤者数をチェック
      final attendanceSnapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('daily_activities')
          .doc('attendance')
          .collection('attendance')
          .get();

      final Map<String, int> dailyAttendanceCount = {};
      for (final doc in attendanceSnapshot.docs) {
        final dateKey = doc.id;
        dailyAttendanceCount[dateKey] =
            (dailyAttendanceCount[dateKey] ?? 0) + 1;
      }

      // 全員出勤した日を特定
      final Set<String> allMemberDays = {};
      dailyAttendanceCount.forEach((dateKey, count) {
        if (count >= memberCount) {
          allMemberDays.add(dateKey);
        }
      });

      return allMemberDays;
    } catch (e) {
      print('全員出勤チェックエラー: $e');
      return {};
    }
  }

  /// 新しいバッジをチェック
  static Future<List<GroupBadge>> _checkNewBadges(
    String groupId,
    GroupStats stats,
  ) async {
    final List<GroupBadge> newBadges = [];

    // 現在のグループプロフィールを取得して実際のレベルを使用
    final currentProfile = await getGroupProfile(groupId);
    final currentLevel = currentProfile.level;

    print(
      'バッジチェック開始: ドリップパック総数=${stats.totalDripPackCount}, 現在のレベル=$currentLevel',
    );
    print('バッジチェック詳細:');
    print('  プロフィールレベル: ${currentProfile.level}');
    print('  プロフィールバッジ数: ${currentProfile.badges.length}');
    print('  プロフィールバッジID: ${currentProfile.badges.map((b) => b.id).toList()}');

    // プロフィールのバッジを使用
    final Set<String> profileBadgeIds = currentProfile.badges
        .map((b) => b.id)
        .toSet();

    // レベルバッジを優先的にチェック
    final levelConditions = GroupBadgeConditions.conditions
        .where((condition) => condition.category == BadgeCategory.level)
        .toList();

    print('レベルバッジチェック開始: ${levelConditions.length}個のレベルバッジをチェック');

    for (final condition in levelConditions) {
      final isEarned = profileBadgeIds.contains(condition.badgeId);
      final conditionMet = _checkLevelBadgeCondition(condition, currentLevel);

      print('レベルバッジ詳細チェック:');
      print('  バッジID: ${condition.badgeId}');
      print('  バッジ名: ${condition.name}');
      print('  獲得済み: $isEarned');
      print('  条件達成: $conditionMet');
      print('  現在レベル: $currentLevel');

      if (!isEarned && conditionMet) {
        final newBadge = condition.createBadge(_uid!, _userDisplayName!);
        newBadges.add(newBadge);

        print('🎉 新しいレベルバッジを獲得: ${newBadge.name} (${newBadge.id})');
        print('  カテゴリ: ${condition.category}');
        print('  現在レベル: $currentLevel');

        // バッジ獲得を即座にプロフィールに反映
        await _addBadgeToProfile(groupId, newBadge);
      } else if (isEarned) {
        print('⏭️ レベルバッジスキップ（既に獲得済み）: ${condition.badgeId}');
      }
    }

    // その他のバッジをチェック
    final otherConditions = GroupBadgeConditions.conditions
        .where((condition) => condition.category != BadgeCategory.level)
        .toList();

    print('その他バッジチェック開始: ${otherConditions.length}個のバッジをチェック');

    for (final condition in otherConditions) {
      final isEarned = profileBadgeIds.contains(condition.badgeId);
      final conditionMet = condition.checkCondition(stats);

      // ドリップパックバッジのみ詳細ログ
      if (condition.category == BadgeCategory.dripPack) {
        print(
          'ドリップパックバッジチェック: ${condition.badgeId} - 獲得済み=$isEarned, 条件達成=$conditionMet',
        );
      }

      if (!isEarned && conditionMet) {
        final newBadge = condition.createBadge(_uid!, _userDisplayName!);
        newBadges.add(newBadge);

        print('🏆 新しいバッジを獲得: ${newBadge.name} (${newBadge.id})');
        print('  カテゴリ: ${condition.category}');

        // バッジ獲得を即座にプロフィールに反映
        await _addBadgeToProfile(groupId, newBadge);
      } else if (isEarned) {
        print('⏭️ バッジスキップ（既に獲得済み）: ${condition.badgeId}');
      }
    }

    print('バッジチェック完了: 新規獲得数=${newBadges.length}');
    return newBadges;
  }

  /// レベルアップ時に獲得可能なレベルバッジをチェック
  static Future<List<GroupBadge>> _checkLevelUpBadges(
    String groupId,
    int newLevel,
    List<GroupBadge> currentBadges,
  ) async {
    final List<GroupBadge> levelUpBadges = [];
    final Set<String> currentBadgeIds = currentBadges.map((b) => b.id).toSet();

    print('レベルアップ時のレベルバッジチェック開始: 新レベル=$newLevel');
    print('現在のバッジID: ${currentBadgeIds.toList()}');

    for (final condition in GroupBadgeConditions.conditions) {
      if (condition.category == BadgeCategory.level) {
        final isEarned = currentBadgeIds.contains(condition.badgeId);
        final conditionMet = _checkLevelBadgeCondition(condition, newLevel);

        print('レベルアップ時のレベルバッジ詳細チェック:');
        print('  バッジID: ${condition.badgeId}');
        print('  バッジ名: ${condition.name}');
        print('  獲得済み: $isEarned');
        print('  条件達成: $conditionMet');
        print('  新レベル: $newLevel');

        if (!isEarned && conditionMet) {
          final newBadge = condition.createBadge(_uid!, _userDisplayName!);
          levelUpBadges.add(newBadge);
          print('🎉 レベルアップで新しいレベルバッジを獲得: ${newBadge.name} (${newBadge.id})');
        } else if (isEarned) {
          print('⏭️ レベルアップ時のレベルバッジスキップ（既に獲得済み）: ${condition.badgeId}');
        }
      }
    }

    print('レベルアップ時のレベルバッジチェック完了: 新規獲得数=${levelUpBadges.length}');
    return levelUpBadges;
  }

  /// バッジをプロフィールに即座に追加
  static Future<void> _addBadgeToProfile(
    String groupId,
    GroupBadge badge,
  ) async {
    try {
      final profileRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('gamification')
          .doc('profile');

      // 現在のプロフィールを取得して重複チェック
      final currentDoc = await profileRef.get();
      if (currentDoc.exists) {
        final currentData = currentDoc.data()!;
        final currentBadges = currentData['badges'] as List<dynamic>? ?? [];
        final currentBadgeIds = currentBadges
            .map((b) => b['id'] as String)
            .toSet();

        // すでにバッジが存在する場合はスキップ
        if (currentBadgeIds.contains(badge.id)) {
          print('⚠️ バッジ重複検知、スキップ: ${badge.id} (${badge.name})');
          return;
        }
      }

      // バッジを追加
      await profileRef.update({
        'badges': FieldValue.arrayUnion([badge.toJson()]),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print('✅ バッジをプロフィールに即座に追加: ${badge.name}');
      print('   バッジID: ${badge.id}');
      print('   カテゴリ: ${badge.category}');
      print('   獲得者: ${badge.earnedByUserName}');

      // 自動同期を実行
      await AutoSyncService.triggerAutoSyncForDataType('gamification');
    } catch (e) {
      print('❌ バッジプロフィール追加エラー: $e');
      print('   バッジID: ${badge.id}');
      print('   バッジ名: ${badge.name}');
    }
  }

  /// レベルを計算
  static int _calculateLevel(int experiencePoints) {
    int level = 1;
    while (experiencePoints >= _calculateRequiredXP(level + 1)) {
      level++;
    }
    return level;
  }

  /// レベルに必要な経験値を計算（GroupGamificationProfileと統一）
  static int _calculateRequiredXP(int level) {
    if (level <= 1) return 0; // レベル1は0XPから開始
    if (level <= 20) return (level - 1) * 10; // レベル2-20: 10XPずつ増加
    if (level <= 100) return 190 + (level - 20) * 15; // レベル21-100: 15XPずつ増加
    if (level <= 1000)
      return 1390 + (level - 100) * 20; // レベル101-1000: 20XPずつ増加
    return 18190 + (level - 1000) * 25; // レベル1001以上: 25XPずつ増加
  }

  /// レベルバッジの条件をチェック
  static bool _checkLevelBadgeCondition(
    GroupBadgeCondition condition,
    int currentLevel,
  ) {
    // バッジIDから必要なレベルを抽出
    final levelMatch = RegExp(
      r'group_level_(\d+)',
    ).firstMatch(condition.badgeId);
    if (levelMatch == null) {
      print('レベルバッジID解析エラー: ${condition.badgeId}');
      return false;
    }

    final requiredLevel = int.parse(levelMatch.group(1)!);
    final conditionMet = currentLevel >= requiredLevel;

    print('レベルバッジ条件チェック詳細:');
    print('  バッジID: ${condition.badgeId}');
    print('  現在レベル: $currentLevel');
    print('  必要レベル: $requiredLevel');
    print('  条件達成: $conditionMet');

    // 条件を満たしている場合は即座にログ出力
    if (conditionMet) {
      print(
        '🎉 レベルバッジ条件達成: ${condition.badgeId} (レベル$currentLevel >= $requiredLevel)',
      );
    }

    return conditionMet;
  }

  /// グループの統計情報を取得
  static Future<GroupStats> getGroupStats(String groupId) async {
    try {
      final profile = await getGroupProfile(groupId);
      return profile.stats;
    } catch (e) {
      print('グループ統計取得エラー: $e');
      return GroupStats.initial();
    }
  }

  /// グループのバッジ一覧を取得
  static Future<List<GroupBadge>> getGroupBadges(String groupId) async {
    try {
      final profile = await getGroupProfile(groupId);
      return profile.badges;
    } catch (e) {
      print('グループバッジ取得エラー: $e');
      return [];
    }
  }

  /// カテゴリ別バッジを取得
  static Future<List<GroupBadge>> getGroupBadgesByCategory(
    String groupId,
    BadgeCategory category,
  ) async {
    try {
      final badges = await getGroupBadges(groupId);
      return badges.where((badge) => badge.category == category).toList();
    } catch (e) {
      print('カテゴリ別バッジ取得エラー: $e');
      return [];
    }
  }

  /// グループプロフィールの変更を監視
  static Stream<GroupGamificationProfile> watchGroupProfile(String groupId) {
    try {
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
            try {
              if (!doc.exists) return GroupGamificationProfile.initial(groupId);
              return GroupGamificationProfile.fromJson(doc.data()!);
            } catch (e) {
              print('GroupGamificationService: プロフィールJSON解析エラー: $e');
              return GroupGamificationProfile.initial(groupId);
            }
          })
          .handleError((error) {
            print('GroupGamificationService: プロフィール監視エラー: $error');
            return GroupGamificationProfile.initial(groupId);
          });
    } catch (e) {
      print('GroupGamificationService: プロフィール監視開始エラー: $e');
      return Stream.value(GroupGamificationProfile.initial(groupId));
    }
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
      // 出勤バッジの進捗率
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

      // 焙煎時間バッジの進捗率（新システム）
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

      // ドリップパックバッジの進捗率（新システム）
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

      // レベルバッジの進捗率
      case 'group_level_1':
        return (profile.level / 1).clamp(0.0, 1.0);
      case 'group_level_5':
        return (profile.level / 5).clamp(0.0, 1.0);
      case 'group_level_10':
        return (profile.level / 10).clamp(0.0, 1.0);
      case 'group_level_20':
        return (profile.level / 20).clamp(0.0, 1.0);
      case 'group_level_50':
        return (profile.level / 50).clamp(0.0, 1.0);
      case 'group_level_100':
        return (profile.level / 100).clamp(0.0, 1.0);
      case 'group_level_250':
        return (profile.level / 250).clamp(0.0, 1.0);
      case 'group_level_500':
        return (profile.level / 500).clamp(0.0, 1.0);
      case 'group_level_1000':
        return (profile.level / 1000).clamp(0.0, 1.0);
      case 'group_level_2000':
        return (profile.level / 2000).clamp(0.0, 1.0);
      case 'group_level_3000':
        return (profile.level / 3000).clamp(0.0, 1.0);
      case 'group_level_5000':
        return (profile.level / 5000).clamp(0.0, 1.0);
      case 'group_level_7500':
        return (profile.level / 7500).clamp(0.0, 1.0);
      case 'group_level_9999':
        return (profile.level / 9999).clamp(0.0, 1.0);

      // 特殊バッジの進捗率
      case 'group_tasting_100':
        return (stats.totalTastingRecords / 100).clamp(0.0, 1.0);

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

  /// キャッシュをクリア
  static void clearCache([String? groupId]) {
    if (groupId != null) {
      _profileCache.remove(groupId);
      _cacheTimestamps.remove(groupId);
      print('GroupGamificationService: キャッシュをクリア: $groupId');
    } else {
      _profileCache.clear();
      _cacheTimestamps.clear();
      print('GroupGamificationService: 全キャッシュをクリア');
    }
  }

  /// キャッシュの有効期限をチェックして古いキャッシュを削除
  static void _cleanupExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = _cacheTimestamps.entries
        .where((entry) => now.difference(entry.value) >= _cacheExpiration)
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredKeys) {
      _profileCache.remove(key);
      _cacheTimestamps.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      print('GroupGamificationService: 期限切れキャッシュを削除: ${expiredKeys.length}件');
    }
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

  /// 既存の焙煎記録から累積焙煎時間を再計算し、初期状態に反映
  static Future<void> recalculateRoastTimeFromExistingRecords(
    String groupId,
  ) async {
    try {
      print('焙煎記録の再計算開始: groupId=$groupId');

      // 既存の焙煎記録を取得
      final records = await RoastRecordFirestoreService.getGroupRecords(
        groupId,
      );
      double totalMinutes = 0.0;
      Set<String> roastDays = {};

      print('取得した焙煎記録数: ${records.length}');

      for (final record in records) {
        final minutes = RoastRecordFirestoreService.parseRoastTimeToMinutes(
          record.time,
        );
        totalMinutes += minutes;

        // 焙煎日を記録
        final dateKey =
            '${record.timestamp.year}-${record.timestamp.month.toString().padLeft(2, '0')}-${record.timestamp.day.toString().padLeft(2, '0')}';
        roastDays.add(dateKey);

        print('記録: ${record.bean} - ${record.time} (${minutes}分)');
      }

      print(
        '再計算結果: 総時間=${totalMinutes.toStringAsFixed(1)}分, 焙煎日数=${roastDays.length}日',
      );

      // 現在のプロフィールを取得
      final currentProfile = await getGroupProfile(groupId);

      // 統計情報を更新
      final updatedStats = currentProfile.stats.copyWith(
        totalRoastTimeMinutes: totalMinutes,
        totalRoastDays: roastDays.length,
      );

      // 新しいバッジをチェック
      final newBadges = await _checkNewBadges(groupId, updatedStats);

      // プロフィールを更新
      final updatedProfile = currentProfile.copyWith(
        stats: updatedStats,
        badges: [...currentProfile.badges, ...newBadges],
        lastUpdated: DateTime.now(),
      );

      // プロフィールを保存
      await _saveGroupProfile(groupId, updatedProfile);

      print('焙煎記録の再計算完了');
      print('新しいバッジ獲得数: ${newBadges.length}');
      if (newBadges.isNotEmpty) {
        for (final badge in newBadges) {
          print('  - ${badge.name}: ${badge.description}');
        }
      }
    } catch (e) {
      print('焙煎記録の再計算エラー: $e');
      rethrow;
    }
  }

  /// 既存のドリップパック記録から累積数を再計算し、初期状態に反映
  static Future<void> recalculateDripPackFromExistingRecords(
    String groupId,
  ) async {
    try {
      print('ドリップパック記録の再計算開始: groupId=$groupId');

      // 既存のドリップパック記録を取得
      final dripPackStats =
          await DripCounterFirestoreService.recalculateGroupDripPackStats(
            groupId,
          );
      final totalCount = dripPackStats['totalDripPackCount'] ?? 0;
      final totalRecords = dripPackStats['totalRecords'] ?? 0;

      print('取得したドリップパック記録数: $totalRecords');
      print('再計算結果: 累積数=$totalCount個');

      // 現在のプロフィールを取得
      final currentProfile = await getGroupProfile(groupId);

      // 統計情報を更新
      final updatedStats = currentProfile.stats.copyWith(
        totalDripPackCount: totalCount,
      );

      // 新しいバッジをチェック
      final newBadges = await _checkNewBadges(groupId, updatedStats);

      // プロフィールを更新
      final updatedProfile = currentProfile.copyWith(
        stats: updatedStats,
        badges: [...currentProfile.badges, ...newBadges],
        lastUpdated: DateTime.now(),
      );

      // プロフィールを保存
      await _saveGroupProfile(groupId, updatedProfile);

      print('ドリップパック記録の再計算完了');
      print('新しいバッジ獲得数: ${newBadges.length}');
      if (newBadges.isNotEmpty) {
        for (final badge in newBadges) {
          print('  - ${badge.name}: ${badge.description}');
        }
      }
    } catch (e) {
      print('ドリップパック記録の再計算エラー: $e');
      rethrow;
    }
  }

  /// 既存のプロフィールから重複バッジを除去（修復用）
  static Future<void> removeDuplicateBadges(String groupId) async {
    try {
      print('重複バッジ除去開始: groupId=$groupId');

      final profile = await getGroupProfile(groupId);
      final originalCount = profile.badges.length;

      // バッジの重複を除去
      final uniqueBadges = <GroupBadge>[];
      final seenBadgeIds = <String>{};

      for (final badge in profile.badges) {
        if (!seenBadgeIds.contains(badge.id)) {
          uniqueBadges.add(badge);
          seenBadgeIds.add(badge.id);
        } else {
          print('重複バッジを除去: ${badge.id} (${badge.name})');
        }
      }

      if (uniqueBadges.length != originalCount) {
        print(
          '重複バッジ除去完了: ${originalCount}個 → ${uniqueBadges.length}個 (${originalCount - uniqueBadges.length}個除去)',
        );

        // プロフィールを更新
        final updatedProfile = profile.copyWith(
          badges: uniqueBadges,
          lastUpdated: DateTime.now(),
        );

        await _saveGroupProfile(groupId, updatedProfile);
        print('プロフィールを更新しました');
      } else {
        print('重複バッジは見つかりませんでした');
      }
    } catch (e) {
      print('重複バッジ除去エラー: $e');
      rethrow;
    }
  }
}
