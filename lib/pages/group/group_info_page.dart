import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/theme_settings.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../models/gamification_models.dart';
import '../../models/gamification_provider.dart';
import '../../services/gamification_service.dart';
import '../../services/group_statistics_service.dart';
import '../../services/group_data_sync_service.dart';
import '../../services/group_firestore_service.dart';
import '../../services/group_gamification_service.dart';
import 'group_qr_generate_page.dart';

class GroupInfoPage extends StatefulWidget {
  const GroupInfoPage({super.key});

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  Map<String, dynamic> _groupStats = {};
  List<UserProfile> _memberProfiles = [];
  UserProfile? _groupProfile;
  GroupSettings? _groupSettings;
  bool _loading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _currentGroupId;
  GroupProvider? _groupProvider;

  // 編集用フォームコントローラー
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _initializeControllers();

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _loadGroupData();
  }

  void _initializeControllers() {
    final groupProvider = context.read<GroupProvider>();
    final group = groupProvider.currentGroup;

    _nameController = TextEditingController(text: group?.name ?? '');
    _descriptionController = TextEditingController(
      text: group?.description ?? '',
    );
  }

  @override
  void dispose() {
    // アニメーションコントローラーを安全に破棄
    try {
      if (_fadeController.isAnimating) {
        _fadeController.stop();
      }
      _fadeController.dispose();
    } catch (e) {
      print('FadeController破棄エラー: $e');
    }

    try {
      if (_slideController.isAnimating) {
        _slideController.stop();
      }
      _slideController.dispose();
    } catch (e) {
      print('SlideController破棄エラー: $e');
    }

    // テキストコントローラーを安全に破棄
    try {
      _nameController.dispose();
      _descriptionController.dispose();
    } catch (e) {
      print('TextController破棄エラー: $e');
    }

    // ゲーミフィケーションプロファイルの監視を停止
    try {
      if (_currentGroupId != null && _groupProvider != null) {
        _groupProvider!.unwatchGroupGamificationProfile(_currentGroupId!);
      }
    } catch (e) {
      print('ゲーミフィケーション監視停止エラー: $e');
    }

    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // GroupProviderの参照を保存
    _groupProvider = context.read<GroupProvider>();

    _checkGroupChange();
  }

  /// グループ変更をチェックして、必要に応じてゲーミフィケーションプロファイルの監視を開始
  void _checkGroupChange() {
    if (_groupProvider == null || !mounted) return;

    final currentGroupId = _groupProvider!.hasGroup
        ? _groupProvider!.currentGroup!.id
        : null;

    // グループが変更された場合、監視を開始
    if (_currentGroupId != currentGroupId) {
      // 前のグループの監視を停止
      if (_currentGroupId != null) {
        try {
          _groupProvider!.unwatchGroupGamificationProfile(_currentGroupId!);
        } catch (e) {
          print('前のグループの監視停止エラー: $e');
        }
      }

      // 新しいグループの監視を開始
      if (currentGroupId != null && mounted) {
        try {
          _groupProvider!.watchGroupGamificationProfile(currentGroupId);
          print('GroupInfoPage: ゲーミフィケーションプロファイルの監視を開始: $currentGroupId');
        } catch (e) {
          print('新しいグループの監視開始エラー: $e');
        }
      }

      _currentGroupId = currentGroupId;
    }
  }

  Future<void> _loadGroupData() async {
    final groupProvider = context.read<GroupProvider>();
    final gamificationProvider = context.read<GamificationProvider>();

    if (!groupProvider.hasGroup) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final group = groupProvider.currentGroup!;

      // グループ統計を取得
      final statisticsService = GroupStatisticsService();
      _groupStats = await statisticsService.getGroupStatistics(group.id);

      // ウィジェットが破棄されている場合は処理を中断
      if (!mounted) return;

      // グループのゲーミフィケーションプロファイルを取得
      await groupProvider.loadGroupGamificationProfile(group.id);

      // ウィジェットが破棄されている場合は処理を中断
      if (!mounted) return;

      // ゲーミフィケーションプロファイルの監視を開始
      groupProvider.watchGroupGamificationProfile(group.id);
      _currentGroupId = group.id;

      final groupGamificationProfile = groupProvider
          .getGroupGamificationProfile(group.id);

      // グループ全体のプロファイルを設定
      if (groupGamificationProfile != null) {
        _groupProfile = UserProfile(
          experiencePoints: groupGamificationProfile.experiencePoints,
          level: groupGamificationProfile.level,
          badges: groupGamificationProfile.badges
              .map(
                (b) => UserBadge(
                  id: b.id,
                  name: b.name,
                  description: b.description,
                  icon: b.icon,
                  color: b.color,
                  earnedAt: b.earnedAt,
                ),
              )
              .toList(),
          stats: UserStats(
            attendanceDays: groupGamificationProfile.stats.totalAttendanceDays,
            totalRoastTimeMinutes:
                groupGamificationProfile.stats.totalRoastTimeMinutes,
            dripPackCount: groupGamificationProfile.stats.totalDripPackCount,
            totalRoastSessions: groupGamificationProfile.stats.totalRoastDays,
            firstActivityDate: groupGamificationProfile.stats.firstActivityDate,
            lastActivityDate: groupGamificationProfile.stats.lastActivityDate,
          ),
        );
      } else {
        // フォールバック: メンバーのゲーミフィケーションデータを取得
        _memberProfiles =
            await GroupDataSyncService.getGroupMembersGamificationData(
              group.id,
            );

        // ウィジェットが破棄されている場合は処理を中断
        if (!mounted) return;

        _groupProfile = _calculateGroupProfile(_memberProfiles);
      }

      // グループ設定を取得
      _groupSettings = await GroupFirestoreService.getGroupSettings(group.id);
      _groupSettings ??= GroupSettings.defaultSettings();

      // ウィジェットが破棄されている場合は処理を中断
      if (!mounted) return;

      setState(() => _loading = false);

      // アニメーション開始（mountedチェック付き）
      if (mounted) {
        _fadeController.forward();
        await Future.delayed(Duration(milliseconds: 200));
        if (mounted) {
          _slideController.forward();
        }
      }
    } catch (e) {
      print('グループデータ読み込みエラー: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  UserProfile _calculateGroupProfile(List<UserProfile> profiles) {
    if (profiles.isEmpty) return UserProfile.initial();

    int totalXP = 0;
    int totalAttendance = 0;
    double totalRoastTime = 0;
    int totalDripPacks = 0;
    Set<String> allBadgeIds = {};

    for (final profile in profiles) {
      totalXP += profile.experiencePoints;
      totalAttendance += profile.stats.attendanceDays;
      totalRoastTime += profile.stats.totalRoastTimeMinutes;
      totalDripPacks += profile.stats.dripPackCount;
      allBadgeIds.addAll(profile.badges.map((b) => b.id));
    }

    // グループレベルを計算（総経験値から）
    int groupLevel = _calculateLevelFromXP(totalXP);

    final stats = UserStats(
      attendanceDays: totalAttendance,
      totalRoastTimeMinutes: totalRoastTime,
      dripPackCount: totalDripPacks,
      totalRoastSessions: 0,
      firstActivityDate: DateTime.now(),
      lastActivityDate: DateTime.now(),
    );

    // グループ全体で獲得したバッジを計算
    final groupBadges = _calculateGroupBadges(stats, groupLevel);

    return UserProfile(
      experiencePoints: totalXP,
      level: groupLevel,
      badges: groupBadges,
      stats: stats,
    );
  }

  int _calculateLevelFromXP(int totalXP) {
    int level = 1;
    while (level < 9999) {
      int requiredXP = _calculateRequiredXP(level + 1);
      if (totalXP < requiredXP) break;
      level++;
    }
    return level;
  }

  int _calculateRequiredXP(int level) {
    if (level <= 1) return 0; // レベル1は0XPから開始
    if (level <= 20) return (level - 1) * 10; // レベル2-20: 10XPずつ増加
    if (level <= 100) return 190 + (level - 20) * 15; // レベル21-100: 15XPずつ増加
    if (level <= 1000)
      return 1390 + (level - 100) * 20; // レベル101-1000: 20XPずつ増加
    return 18190 + (level - 1000) * 25; // レベル1001以上: 25XPずつ増加
  }

  List<UserBadge> _calculateGroupBadges(UserStats stats, int level) {
    final earnedBadges = <UserBadge>[];
    final tempProfile = UserProfile(
      experiencePoints: 0,
      level: level,
      badges: [],
      stats: stats,
    );

    for (final condition in GamificationService.badgeConditions) {
      if (condition.checkCondition(tempProfile)) {
        earnedBadges.add(condition.createBadge());
      }
    }

    return earnedBadges;
  }

  // グループ編集関連メソッド
  Future<void> _saveGroupChanges() async {
    if (!_formKey.currentState!.validate()) return;

    if (mounted) {
      setState(() => _isSaving = true);
    }

    try {
      final groupProvider = context.read<GroupProvider>();
      final currentGroup = groupProvider.currentGroup!;

      print('GroupInfoPage: グループ更新開始');
      print('GroupInfoPage: 現在の名前: ${currentGroup.name}');
      print('GroupInfoPage: 新しい名前: ${_nameController.text.trim()}');
      print('GroupInfoPage: 現在の説明: ${currentGroup.description}');
      print('GroupInfoPage: 新しい説明: ${_descriptionController.text.trim()}');

      final updatedGroup = currentGroup.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        updatedAt: DateTime.now(),
      );

      final success = await groupProvider.updateGroup(updatedGroup);

      print('GroupInfoPage: 更新結果: $success');

      if (success && mounted) {
        await groupProvider.loadUserGroups();
        if (mounted) {
          setState(() {
            _isEditing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('グループ情報を更新しました'),
              backgroundColor: Colors.green,
            ),
          );
        }
        print('GroupInfoPage: グループ更新完了');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(groupProvider.error ?? '更新に失敗しました'),
            backgroundColor: Colors.red,
          ),
        );
        print('GroupInfoPage: グループ更新失敗: ${groupProvider.error}');
      }
    } catch (e) {
      print('GroupInfoPage: グループ更新エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteGroup() async {
    final groupProvider = context.read<GroupProvider>();
    final currentGroup = groupProvider.currentGroup!;

    // 確認ダイアログ
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('グループを削除'),
        content: Text('本当にこのグループを削除しますか？\nこの操作は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('削除'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final success = await groupProvider.deleteGroup(currentGroup.id);
      if (success && mounted) {
        await groupProvider.loadUserGroups();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('グループを削除しました'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateGroupSettings(
    GroupSettings newSettings, [
    StateSetter? setModalState,
  ]) async {
    try {
      print('GroupInfoPage: 設定更新開始');
      print('GroupInfoPage: 現在の設定: $_groupSettings');
      print('GroupInfoPage: 新しい設定: $newSettings');
      print(
        'GroupInfoPage: 新しい設定のdataPermissions: ${newSettings.dataPermissions}',
      );

      if (_groupSettings != null) {
        print(
          'GroupInfoPage: 現在のallowMemberInvite: ${_groupSettings!.allowMemberInvite}',
        );
        print(
          'GroupInfoPage: 新しいallowMemberInvite: ${newSettings.allowMemberInvite}',
        );
        print(
          'GroupInfoPage: 現在のallowMemberViewMembers: ${_groupSettings!.allowMemberViewMembers}',
        );
        print(
          'GroupInfoPage: 新しいallowMemberViewMembers: ${newSettings.allowMemberViewMembers}',
        );
        print(
          'GroupInfoPage: 現在のallowMemberViewMembers: ${_groupSettings!.allowMemberViewMembers}',
        );
        print(
          'GroupInfoPage: 新しいallowMemberViewMembers: ${newSettings.allowMemberViewMembers}',
        );
      }

      await GroupFirestoreService.updateGroupSettings(
        groupId: context.read<GroupProvider>().currentGroup!.id,
        settings: newSettings,
      );

      print('GroupFirestoreService: Firestore更新完了');

      if (mounted) {
        print('GroupInfoPage: setState前の_groupSettings: $_groupSettings');
        setState(() {
          _groupSettings = newSettings;
        });
        print('GroupInfoPage: setState後の_groupSettings: $_groupSettings');

        // ボトムシート内でも状態更新
        if (setModalState != null) {
          setModalState(() {
            // ボトムシート内の状態を更新
          });
        }

        // 強制的に再描画を促す
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              // 空のsetStateで強制再描画
            });
          }
        });

        print('GroupInfoPage: ローカル状態更新完了');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('設定を更新しました'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print('GroupInfoPage: 設定更新エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('設定の更新に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool get _isUserLeader {
    final user = FirebaseAuth.instance.currentUser;
    final groupProvider = context.read<GroupProvider>();
    final group = groupProvider.currentGroup;

    if (user == null || group == null) return false;

    // 管理者またはリーダーの場合に編集可能
    final memberRole = group.getMemberRole(user.uid);
    return memberRole == GroupRole.admin || memberRole == GroupRole.leader;
  }

  bool get _canShowQRCode {
    final user = FirebaseAuth.instance.currentUser;
    final groupProvider = context.read<GroupProvider>();
    final group = groupProvider.currentGroup;

    if (user == null || group == null) return false;

    // 管理者またはリーダーは常に表示
    final memberRole = group.getMemberRole(user.uid);
    if (memberRole == GroupRole.admin || memberRole == GroupRole.leader) {
      return true;
    }

    // メンバーの場合も常に表示（設定に関係なく）
    return true;
  }

  void _showSettingsBottomSheet() {
    if (_groupSettings == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) =>
            _buildSettingsBottomSheet(setModalState),
      ),
    );
  }

  Widget _buildSettingsBottomSheet([StateSetter? setModalState]) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: themeSettings.backgroundColor2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ハンドル
          Container(
            margin: EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ヘッダー
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.settings, color: themeSettings.iconColor),
                SizedBox(width: 12),
                Text(
                  'グループ権限設定',
                  style: TextStyle(
                    fontSize: 20 * themeSettings.fontSizeScale,
                    fontWeight: FontWeight.bold,
                    color: themeSettings.fontColor1,
                    fontFamily: themeSettings.fontFamily,
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Divider(),

          // 設定内容
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildDataPermissionSettings(setModalState),
                  SizedBox(height: 20),
                  _buildMemberPermissionSettings(setModalState),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);
    final groupProvider = Provider.of<GroupProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.group, color: themeSettings.iconColor),
            SizedBox(width: 8),
            Text(
              'グループ情報',
              style: TextStyle(
                color: themeSettings.appBarTextColor,
                fontSize: 20 * themeSettings.fontSizeScale,
                fontWeight: FontWeight.bold,
                fontFamily: themeSettings.fontFamily,
              ),
            ),
          ],
        ),
        backgroundColor: themeSettings.appBarColor,
        iconTheme: IconThemeData(color: themeSettings.iconColor),
        actions: [
          if (groupProvider.hasGroup) ...[
            if (_isEditing && _isUserLeader) ...[
              if (_isSaving)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: themeSettings.iconColor,
                  ),
                )
              else
                IconButton(
                  icon: Icon(Icons.save, color: themeSettings.iconColor),
                  onPressed: _saveGroupChanges,
                ),
              IconButton(
                icon: Icon(Icons.close, color: themeSettings.iconColor),
                onPressed: () {
                  if (mounted) {
                    setState(() => _isEditing = false);
                  }
                },
              ),
            ] else ...[
              if (_isUserLeader)
                IconButton(
                  icon: Icon(Icons.edit, color: themeSettings.iconColor),
                  onPressed: () {
                    if (mounted) {
                      setState(() => _isEditing = true);
                    }
                  },
                ),
              if (_canShowQRCode)
                IconButton(
                  icon: Icon(Icons.qr_code, color: themeSettings.iconColor),
                  onPressed: () async {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GroupQRGeneratePage(),
                      ),
                    );
                  },
                  tooltip: 'QRコード生成',
                ),
              if (_isUserLeader)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: themeSettings.iconColor),
                  onSelected: (value) {
                    switch (value) {
                      case 'settings':
                        _showSettingsBottomSheet();
                        break;
                      case 'delete':
                        _deleteGroup();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'settings',
                      child: Row(
                        children: [
                          Icon(Icons.settings, size: 20),
                          SizedBox(width: 8),
                          Text('権限設定'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('グループ削除', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: themeSettings.buttonColor,
              ),
            )
          : !groupProvider.hasGroup
          ? _buildNoGroupView(themeSettings)
          : _buildGroupInfoView(themeSettings, groupProvider.currentGroup!),
    );
  }

  Widget _buildNoGroupView(ThemeSettings themeSettings) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_off,
            size: 80,
            color: themeSettings.fontColor1.withOpacity(0.5),
          ),
          SizedBox(height: 16),
          Text(
            'グループに参加していません',
            style: TextStyle(
              fontSize: 18 * themeSettings.fontSizeScale,
              color: themeSettings.fontColor1,
              fontFamily: themeSettings.fontFamily,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'グループに参加してチームの成長を確認しましょう',
            style: TextStyle(
              fontSize: 14 * themeSettings.fontSizeScale,
              color: themeSettings.fontColor1.withOpacity(0.7),
              fontFamily: themeSettings.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGroupInfoView(ThemeSettings themeSettings, Group group) {
    final size = MediaQuery.of(context).size;
    return Consumer<GroupProvider>(
      builder: (context, groupProvider, child) {
        final groupGamificationProfile = groupProvider
            .getGroupGamificationProfile(group.id);
        final stats = groupGamificationProfile?.stats;
        final badgeCount = groupGamificationProfile?.badges.length ?? 0;
        final allBadgeCount = GamificationService.badgeConditions.length;
        final currentLevel = groupGamificationProfile?.level ?? 1;
        final experiencePoints =
            groupGamificationProfile?.experiencePoints ?? 0;
        final levelProgress = groupGamificationProfile?.levelProgress ?? 0.0;
        final experienceToNextLevel =
            groupGamificationProfile?.experienceToNextLevel ?? 0;
        final memberCount = group.members.length;

        return Center(
          child: Container(
            width: size.width > 500 ? 500 : size.width * 0.95,
            constraints: BoxConstraints(
              maxHeight: size.height * 0.9,
              minHeight: size.height * 0.7,
            ),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              color: themeSettings.backgroundColor2,
              shadowColor: themeSettings.buttonColor.withOpacity(0.15),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // グループ名と説明
                      Row(
                        children: [
                          Icon(
                            Icons.groups,
                            color: themeSettings.buttonColor,
                            size: 40,
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _isEditing
                                ? _buildEditForm(themeSettings, group)
                                : _buildGroupInfo(themeSettings, group),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),

                      // メンバーと権限
                      Text(
                        'メンバーと権限',
                        style: TextStyle(
                          fontSize: 22 * themeSettings.fontSizeScale,
                          fontWeight: FontWeight.bold,
                          color: themeSettings.fontColor1,
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                      SizedBox(height: 12),
                      _buildMembersSection(themeSettings, group),

                      // 統計情報
                      Text(
                        'グループ統計',
                        style: TextStyle(
                          fontSize: 22 * themeSettings.fontSizeScale,
                          fontWeight: FontWeight.bold,
                          color: themeSettings.fontColor1,
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatItem(
                            themeSettings,
                            Icons.work,
                            '出勤',
                            '${stats?.totalAttendanceDays ?? 0}日',
                          ),
                          _buildStatItem(
                            themeSettings,
                            Icons.local_fire_department,
                            '焙煎',
                            '${stats?.totalRoastTimeHours.toStringAsFixed(1) ?? '0.0'}h',
                          ),
                          _buildStatItem(
                            themeSettings,
                            Icons.local_cafe,
                            'パック',
                            '${stats?.totalDripPackCount ?? 0}個',
                          ),
                          _buildStatItem(
                            themeSettings,
                            Icons.emoji_events,
                            'バッジ',
                            '$badgeCount',
                          ),
                        ],
                      ),
                      SizedBox(height: 24),

                      // レベルと経験値
                      Text(
                        'グループレベル',
                        style: TextStyle(
                          fontSize: 22 * themeSettings.fontSizeScale,
                          fontWeight: FontWeight.bold,
                          color: themeSettings.fontColor1,
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.trending_up,
                            color: themeSettings.buttonColor,
                            size: 32,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Lv.$currentLevel',
                            style: TextStyle(
                              fontSize: 22 * themeSettings.fontSizeScale,
                              fontWeight: FontWeight.bold,
                              color: themeSettings.buttonColor,
                              fontFamily: themeSettings.fontFamily,
                            ),
                          ),
                          Spacer(),
                          Text(
                            '${experiencePoints}XP',
                            style: TextStyle(
                              fontSize: 20 * themeSettings.fontSizeScale,
                              color: themeSettings.fontColor1,
                              fontFamily: themeSettings.fontFamily,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: levelProgress.clamp(0.0, 1.0),
                        minHeight: 12,
                        backgroundColor: themeSettings.fontColor1.withOpacity(
                          0.1,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          themeSettings.buttonColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '次まで${experienceToNextLevel}XP',
                        style: TextStyle(
                          fontSize: 18 * themeSettings.fontSizeScale,
                          color: themeSettings.fontColor1.withOpacity(0.6),
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                      SizedBox(height: 24),

                      // バッジ進捗
                      Text(
                        'バッジ進捗',
                        style: TextStyle(
                          fontSize: 22 * themeSettings.fontSizeScale,
                          fontWeight: FontWeight.bold,
                          color: themeSettings.fontColor1,
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            '$badgeCount / $allBadgeCount',
                            style: TextStyle(
                              fontSize: 20 * themeSettings.fontSizeScale,
                              color: themeSettings.buttonColor,
                              fontWeight: FontWeight.bold,
                              fontFamily: themeSettings.fontFamily,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Row(
                              children: GamificationService.badgeConditions
                                  .take(5)
                                  .map((condition) {
                                    final isEarned =
                                        groupGamificationProfile?.badges.any(
                                          (b) => b.id == condition.badgeId,
                                        ) ??
                                        false;
                                    return Padding(
                                      padding: EdgeInsets.only(right: 8),
                                      child: Icon(
                                        condition.icon,
                                        color: isEarned
                                            ? condition.color
                                            : themeSettings.fontColor1
                                                  .withOpacity(0.2),
                                        size: 32,
                                      ),
                                    );
                                  })
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),

                      // レベルタイトル
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: themeSettings.buttonColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.emoji_events,
                              color: themeSettings.buttonColor,
                              size: 32,
                            ),
                            SizedBox(width: 12),
                            Text(
                              _getLevelTitle(currentLevel),
                              style: TextStyle(
                                fontSize: 20 * themeSettings.fontSizeScale,
                                fontWeight: FontWeight.bold,
                                color: themeSettings.buttonColor,
                                fontFamily: themeSettings.fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    ThemeSettings themeSettings,
    IconData icon,
    String label,
    String value,
  ) {
    return Column(
      children: [
        Icon(icon, color: themeSettings.buttonColor, size: 36),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20 * themeSettings.fontSizeScale,
            fontWeight: FontWeight.bold,
            color: themeSettings.fontColor1,
            fontFamily: themeSettings.fontFamily,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 18 * themeSettings.fontSizeScale,
            color: themeSettings.fontColor1.withOpacity(0.6),
            fontFamily: themeSettings.fontFamily,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailStatItem(
    ThemeSettings themeSettings,
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: themeSettings.backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: themeSettings.buttonColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: themeSettings.buttonColor, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14 * themeSettings.fontSizeScale,
              fontWeight: FontWeight.bold,
              color: themeSettings.fontColor1,
              fontFamily: themeSettings.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12 * themeSettings.fontSizeScale,
              color: themeSettings.fontColor1.withOpacity(0.6),
              fontFamily: themeSettings.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    ThemeSettings themeSettings,
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: themeSettings.backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: themeSettings.fontColor1.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: themeSettings.fontColor1.withOpacity(0.7),
            size: 20,
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14 * themeSettings.fontSizeScale,
              fontWeight: FontWeight.bold,
              color: themeSettings.fontColor1,
              fontFamily: themeSettings.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12 * themeSettings.fontSizeScale,
              color: themeSettings.fontColor1.withOpacity(0.6),
              fontFamily: themeSettings.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _miniStat(
    ThemeSettings theme,
    IconData icon,
    String label,
    String value, {
    bool big = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: big ? 38 : 28,
          height: big ? 38 : 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.buttonColor.withOpacity(0.13),
          ),
          child: Icon(icon, color: theme.buttonColor, size: big ? 22 : 16),
        ),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: big ? 18 : 13,
            color: theme.fontColor1,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: big ? 13 : 11,
            color: theme.fontColor1.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelSection(
    ThemeSettings themeSettings,
    int currentLevel,
    int experiencePoints,
    double levelProgress,
    int experienceToNextLevel,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: themeSettings.backgroundColor2,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.trending_up,
                    color: themeSettings.buttonColor,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'グループレベル',
                    style: TextStyle(
                      fontSize: 20 * themeSettings.fontSizeScale,
                      fontWeight: FontWeight.bold,
                      color: themeSettings.fontColor1,
                      fontFamily: themeSettings.fontFamily,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16),

              // レベル表示
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lv.$currentLevel',
                        style: TextStyle(
                          fontSize: 36 * themeSettings.fontSizeScale,
                          fontWeight: FontWeight.bold,
                          color: themeSettings.buttonColor,
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                      Text(
                        _getLevelTitle(currentLevel),
                        style: TextStyle(
                          fontSize: 14 * themeSettings.fontSizeScale,
                          color: themeSettings.fontColor1.withOpacity(0.7),
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${experiencePoints}XP',
                        style: TextStyle(
                          fontSize: 18 * themeSettings.fontSizeScale,
                          fontWeight: FontWeight.w600,
                          color: themeSettings.fontColor1,
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                      Text(
                        '次まで${experienceToNextLevel}XP',
                        style: TextStyle(
                          fontSize: 12 * themeSettings.fontSizeScale,
                          color: themeSettings.fontColor1.withOpacity(0.6),
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 16),

              // 経験値バー
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: themeSettings.fontColor1.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: FractionallySizedBox(
                  widthFactor: levelProgress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          themeSettings.buttonColor,
                          themeSettings.buttonColor.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 8),

              Text(
                '進行度: ${(levelProgress * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12 * themeSettings.fontSizeScale,
                  color: themeSettings.fontColor1.withOpacity(0.6),
                  fontFamily: themeSettings.fontFamily,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(ThemeSettings themeSettings) {
    if (_groupProfile == null) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.all(16),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: themeSettings.backgroundColor2,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bar_chart,
                    color: themeSettings.buttonColor,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    '累計実績',
                    style: TextStyle(
                      fontSize: 20 * themeSettings.fontSizeScale,
                      fontWeight: FontWeight.bold,
                      color: themeSettings.fontColor1,
                      fontFamily: themeSettings.fontFamily,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // 統計グリッド
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  _buildStatCard(
                    themeSettings,
                    Icons.local_fire_department,
                    '総焙煎時間',
                    '${_groupProfile!.stats.totalRoastTimeHours.toStringAsFixed(1)}時間',
                    Colors.orange,
                  ),
                  _buildStatCard(
                    themeSettings,
                    Icons.work,
                    '総出勤日数',
                    '${_groupProfile!.stats.attendanceDays}日',
                    Colors.blue,
                  ),
                  _buildStatCard(
                    themeSettings,
                    Icons.local_cafe,
                    'ドリップパック',
                    '${_groupProfile!.stats.dripPackCount}個',
                    Colors.brown,
                  ),
                  _buildStatCard(
                    themeSettings,
                    Icons.emoji_events,
                    '獲得バッジ',
                    '${_groupProfile!.badges.length}個',
                    Colors.amber,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeSection(ThemeSettings themeSettings) {
    if (_groupProfile == null) return SizedBox.shrink();

    final earnedBadges = _groupProfile!.badges;
    final allBadges = GamificationService.badgeConditions;

    return Container(
      margin: EdgeInsets.all(16),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: themeSettings.backgroundColor2,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: themeSettings.buttonColor,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'バッジ一覧',
                    style: TextStyle(
                      fontSize: 20 * themeSettings.fontSizeScale,
                      fontWeight: FontWeight.bold,
                      color: themeSettings.fontColor1,
                      fontFamily: themeSettings.fontFamily,
                    ),
                  ),
                  Spacer(),
                  Text(
                    '${earnedBadges.length}/${allBadges.length}',
                    style: TextStyle(
                      fontSize: 16 * themeSettings.fontSizeScale,
                      fontWeight: FontWeight.w600,
                      color: themeSettings.buttonColor,
                      fontFamily: themeSettings.fontFamily,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // バッジグリッド
              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: allBadges.length,
                itemBuilder: (context, index) {
                  final condition = allBadges[index];
                  final isEarned = earnedBadges.any(
                    (b) => b.id == condition.badgeId,
                  );
                  final earnedBadge = isEarned
                      ? earnedBadges.firstWhere(
                          (b) => b.id == condition.badgeId,
                        )
                      : null;

                  return _buildBadgeCard(
                    themeSettings,
                    condition,
                    isEarned,
                    earnedBadge?.earnedAt,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    ThemeSettings themeSettings,
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: themeSettings.buttonColor, size: 20),
            SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14 * themeSettings.fontSizeScale,
                color: themeSettings.fontColor1.withOpacity(0.7),
                fontFamily: themeSettings.fontFamily,
              ),
            ),
            Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 14 * themeSettings.fontSizeScale,
                fontWeight: FontWeight.w600,
                color: themeSettings.fontColor1,
                fontFamily: themeSettings.fontFamily,
              ),
            ),
            if (onTap != null) ...[
              SizedBox(width: 8),
              Icon(Icons.copy, color: themeSettings.buttonColor, size: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    ThemeSettings themeSettings,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18 * themeSettings.fontSizeScale,
              fontWeight: FontWeight.bold,
              color: themeSettings.fontColor1,
              fontFamily: themeSettings.fontFamily,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11 * themeSettings.fontSizeScale,
              color: themeSettings.fontColor1.withOpacity(0.7),
              fontFamily: themeSettings.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(
    ThemeSettings themeSettings,
    BadgeCondition condition,
    bool isEarned,
    DateTime? earnedAt,
  ) {
    return GestureDetector(
      onTap: () => _showBadgeDetail(condition, isEarned, earnedAt),
      child: Container(
        decoration: BoxDecoration(
          color: isEarned
              ? condition.color.withOpacity(0.1)
              : themeSettings.fontColor1.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEarned
                ? condition.color.withOpacity(0.3)
                : themeSettings.fontColor1.withOpacity(0.1),
          ),
          boxShadow: isEarned
              ? [
                  BoxShadow(
                    color: condition.color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                Icon(
                  condition.icon,
                  color: isEarned
                      ? condition.color
                      : themeSettings.fontColor1.withOpacity(0.3),
                  size: 32,
                ),
                if (!isEarned)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Icon(
                      Icons.lock,
                      color: themeSettings.fontColor1.withOpacity(0.5),
                      size: 16,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              condition.name,
              style: TextStyle(
                fontSize: 10 * themeSettings.fontSizeScale,
                fontWeight: FontWeight.w600,
                color: isEarned
                    ? themeSettings.fontColor1
                    : themeSettings.fontColor1.withOpacity(0.5),
                fontFamily: themeSettings.fontFamily,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (isEarned && earnedAt != null) ...[
              SizedBox(height: 4),
              Text(
                '${earnedAt.year}/${earnedAt.month}/${earnedAt.day}',
                style: TextStyle(
                  fontSize: 8 * themeSettings.fontSizeScale,
                  color: condition.color,
                  fontFamily: themeSettings.fontFamily,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getLevelTitle(int level) {
    if (level < 5) return 'ビギナーチーム';
    if (level < 10) return 'スタンダードチーム';
    if (level < 25) return 'エキスパートチーム';
    if (level < 50) return 'プロフェッショナルチーム';
    if (level < 100) return 'マスターチーム';
    return 'レジェンダリーチーム';
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
        backgroundColor: Provider.of<ThemeSettings>(
          context,
          listen: false,
        ).buttonColor,
      ),
    );
  }

  void _showBadgeDetail(
    BadgeCondition condition,
    bool isEarned,
    DateTime? earnedAt,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              condition.icon,
              color: isEarned ? condition.color : Colors.grey,
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                condition.name,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(condition.description, style: TextStyle(fontSize: 16)),
            if (isEarned && earnedAt != null) ...[
              SizedBox(height: 16),
              Text(
                '達成日: ${earnedAt.year}年${earnedAt.month}月${earnedAt.day}日',
                style: TextStyle(
                  fontSize: 14,
                  color: condition.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (!isEarned) ...[
              SizedBox(height: 16),
              Text(
                'まだ獲得していません',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Widget _buildDataPermissionSettings([StateSetter? setModalState]) {
    print('GroupInfoPage: _buildDataPermissionSettings開始');
    print('GroupInfoPage: 現在の_groupSettings: $_groupSettings');
    if (_groupSettings != null) {
      print(
        'GroupInfoPage: 現在のdataPermissions: ${_groupSettings!.dataPermissions}',
      );
    }

    final themeSettings = Provider.of<ThemeSettings>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'データ権限設定',
          style: TextStyle(
            fontSize: 18 * themeSettings.fontSizeScale,
            fontWeight: FontWeight.bold,
            color: themeSettings.fontColor1,
            fontFamily: themeSettings.fontFamily,
          ),
        ),
        SizedBox(height: 16),
        _buildDataPermissionToggle(
          title: '焙煎記録入力',
          description: '焙煎記録入力の作成権限',
          dataType: 'roastRecordInput',
          currentLevel: _groupSettings!.getPermissionForDataType(
            'roastRecordInput',
          ),
          onChanged: (AccessLevel level) {
            print('GroupInfoPage: 焙煎記録入力権限変更 - 新しい権限: $level');
            if (setModalState != null) {
              setModalState(() {
                final newPermissions = Map<String, AccessLevel>.from(
                  _groupSettings!.dataPermissions,
                );
                newPermissions['roastRecordInput'] = level;
                _groupSettings = _groupSettings!.copyWith(
                  dataPermissions: newPermissions,
                );
              });
            } else {
              setState(() {
                final newPermissions = Map<String, AccessLevel>.from(
                  _groupSettings!.dataPermissions,
                );
                newPermissions['roastRecordInput'] = level;
                _groupSettings = _groupSettings!.copyWith(
                  dataPermissions: newPermissions,
                );
              });
            }
            print(
              'GroupInfoPage: setState完了 - 新しい設定: ${_groupSettings!.dataPermissions}',
            );
            _updateGroupSettings(_groupSettings!);
          },
        ),
        SizedBox(height: 16),
        _buildDataPermissionToggle(
          title: '焙煎記録一覧',
          description: '焙煎記録一覧の編集・削除権限',
          dataType: 'roastRecords',
          currentLevel: _groupSettings!.getPermissionForDataType(
            'roastRecords',
          ),
          onChanged: (AccessLevel level) {
            print('GroupInfoPage: 焙煎記録一覧権限変更 - 新しい権限: $level');
            if (setModalState != null) {
              setModalState(() {
                final newPermissions = Map<String, AccessLevel>.from(
                  _groupSettings!.dataPermissions,
                );
                newPermissions['roastRecords'] = level;
                _groupSettings = _groupSettings!.copyWith(
                  dataPermissions: newPermissions,
                );
              });
            } else {
              setState(() {
                final newPermissions = Map<String, AccessLevel>.from(
                  _groupSettings!.dataPermissions,
                );
                newPermissions['roastRecords'] = level;
                _groupSettings = _groupSettings!.copyWith(
                  dataPermissions: newPermissions,
                );
              });
            }
            print(
              'GroupInfoPage: setState完了 - 新しい設定: ${_groupSettings!.dataPermissions}',
            );
            _updateGroupSettings(_groupSettings!);
          },
        ),
        SizedBox(height: 16),
        _buildDataPermissionToggle(
          title: 'ドリップパックカウンター',
          description: 'ドリップパックカウンターの記録・編集・削除権限',
          dataType: 'dripCounter',
          currentLevel: _groupSettings!.getPermissionForDataType('dripCounter'),
          onChanged: (AccessLevel level) {
            if (setModalState != null) {
              setModalState(() {
                final newPermissions = Map<String, AccessLevel>.from(
                  _groupSettings!.dataPermissions,
                );
                newPermissions['dripCounter'] = level;
                _groupSettings = _groupSettings!.copyWith(
                  dataPermissions: newPermissions,
                );
              });
            } else {
              setState(() {
                final newPermissions = Map<String, AccessLevel>.from(
                  _groupSettings!.dataPermissions,
                );
                newPermissions['dripCounter'] = level;
                _groupSettings = _groupSettings!.copyWith(
                  dataPermissions: newPermissions,
                );
              });
            }
            _updateGroupSettings(_groupSettings!);
          },
        ),
        SizedBox(height: 16),
        _buildDataPermissionToggle(
          title: '担当表',
          description: '担当表の編集・削除権限',
          dataType: 'assignment_board',
          currentLevel: _groupSettings!.getPermissionForDataType(
            'assignment_board',
          ),
          onChanged: (AccessLevel level) {
            print('GroupInfoPage: 担当表権限変更 - 新しいレベル: $level');
            print('GroupInfoPage: 変更前の設定: ${_groupSettings!.dataPermissions}');

            if (setModalState != null) {
              setModalState(() {
                final newPermissions = Map<String, AccessLevel>.from(
                  _groupSettings!.dataPermissions,
                );
                newPermissions['assignment_board'] = level;
                _groupSettings = _groupSettings!.copyWith(
                  dataPermissions: newPermissions,
                );
              });
            } else {
              setState(() {
                final newPermissions = Map<String, AccessLevel>.from(
                  _groupSettings!.dataPermissions,
                );
                newPermissions['assignment_board'] = level;
                _groupSettings = _groupSettings!.copyWith(
                  dataPermissions: newPermissions,
                );
              });
            }

            print('GroupInfoPage: 変更後の設定: ${_groupSettings!.dataPermissions}');
            _updateGroupSettings(_groupSettings!);
          },
        ),
        SizedBox(height: 16),
        _buildDataPermissionToggle(
          title: '本日のスケジュール',
          description: '本日のスケジュールの編集・削除権限',
          dataType: 'todaySchedule',
          currentLevel: _groupSettings!.getPermissionForDataType(
            'todaySchedule',
          ),
          onChanged: (AccessLevel level) {
            if (setModalState != null) {
              setModalState(() {
                final newPermissions = Map<String, AccessLevel>.from(
                  _groupSettings!.dataPermissions,
                );
                newPermissions['todaySchedule'] = level;
                _groupSettings = _groupSettings!.copyWith(
                  dataPermissions: newPermissions,
                );
              });
            } else {
              setState(() {
                final newPermissions = Map<String, AccessLevel>.from(
                  _groupSettings!.dataPermissions,
                );
                newPermissions['todaySchedule'] = level;
                _groupSettings = _groupSettings!.copyWith(
                  dataPermissions: newPermissions,
                );
              });
            }
            _updateGroupSettings(_groupSettings!);
          },
        ),
        SizedBox(height: 16),
        _buildDataPermissionToggle(
          title: '作業状況記録',
          description: '作業状況記録の編集・削除権限',
          dataType: 'taskStatus',
          currentLevel: _groupSettings!.getPermissionForDataType('taskStatus'),
          onChanged: (AccessLevel level) {
            if (setModalState != null) {
              setModalState(() {
                final newPermissions = Map<String, AccessLevel>.from(
                  _groupSettings!.dataPermissions,
                );
                newPermissions['taskStatus'] = level;
                _groupSettings = _groupSettings!.copyWith(
                  dataPermissions: newPermissions,
                );
              });
            } else {
              setState(() {
                final newPermissions = Map<String, AccessLevel>.from(
                  _groupSettings!.dataPermissions,
                );
                newPermissions['taskStatus'] = level;
                _groupSettings = _groupSettings!.copyWith(
                  dataPermissions: newPermissions,
                );
              });
            }
            _updateGroupSettings(_groupSettings!);
          },
        ),
        SizedBox(height: 16),
        _buildDataPermissionToggle(
          title: '試飲感想記録',
          description: '試飲感想記録の編集・削除権限',
          dataType: 'cuppingNotes',
          currentLevel: _groupSettings!.getPermissionForDataType(
            'cuppingNotes',
          ),
          onChanged: (AccessLevel level) {
            if (setModalState != null) {
              setModalState(() {
                final newPermissions = Map<String, AccessLevel>.from(
                  _groupSettings!.dataPermissions,
                );
                newPermissions['cuppingNotes'] = level;
                _groupSettings = _groupSettings!.copyWith(
                  dataPermissions: newPermissions,
                );
              });
            } else {
              setState(() {
                final newPermissions = Map<String, AccessLevel>.from(
                  _groupSettings!.dataPermissions,
                );
                newPermissions['cuppingNotes'] = level;
                _groupSettings = _groupSettings!.copyWith(
                  dataPermissions: newPermissions,
                );
              });
            }
            _updateGroupSettings(_groupSettings!);
          },
        ),
        SizedBox(height: 16),
        _buildDataPermissionToggle(
          title: '丸シール設定',
          description: '丸シール設定の編集・削除権限',
          dataType: 'circleStamps',
          currentLevel: _groupSettings!.getPermissionForDataType(
            'circleStamps',
          ),
          onChanged: (AccessLevel level) {
            if (setModalState != null) {
              setModalState(() {
                final newPermissions = Map<String, AccessLevel>.from(
                  _groupSettings!.dataPermissions,
                );
                newPermissions['circleStamps'] = level;
                _groupSettings = _groupSettings!.copyWith(
                  dataPermissions: newPermissions,
                );
              });
            } else {
              setState(() {
                final newPermissions = Map<String, AccessLevel>.from(
                  _groupSettings!.dataPermissions,
                );
                newPermissions['circleStamps'] = level;
                _groupSettings = _groupSettings!.copyWith(
                  dataPermissions: newPermissions,
                );
              });
            }
            _updateGroupSettings(_groupSettings!);
          },
        ),
      ],
    );
  }

  Widget _buildDataPermissionToggle({
    required String title,
    required String description,
    required String dataType,
    required AccessLevel currentLevel,
    required Function(AccessLevel) onChanged,
  }) {
    print('GroupInfoPage: $dataType の現在の権限: $currentLevel');

    final themeSettings = Provider.of<ThemeSettings>(context);
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeSettings.backgroundColor2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeSettings.fontColor1.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16 * themeSettings.fontSizeScale,
                        fontWeight: FontWeight.bold,
                        color: themeSettings.fontColor1,
                        fontFamily: themeSettings.fontFamily,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14 * themeSettings.fontSizeScale,
                        color: themeSettings.fontColor1.withOpacity(0.7),
                        fontFamily: themeSettings.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getAccessLevelColor(currentLevel).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _getAccessLevelColor(currentLevel).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  _getAccessLevelDisplayName(currentLevel),
                  style: TextStyle(
                    fontSize: 12 * themeSettings.fontSizeScale,
                    color: _getAccessLevelColor(currentLevel),
                    fontWeight: FontWeight.bold,
                    fontFamily: themeSettings.fontFamily,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              // 管理者ボタン
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(AccessLevel.admin_only),
                  child: Container(
                    margin: EdgeInsets.only(right: 8),
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color:
                          _isLevelSelected(currentLevel, AccessLevel.admin_only)
                          ? _getAccessLevelColor(AccessLevel.admin_only)
                          : themeSettings.fontColor1.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            _isLevelSelected(
                              currentLevel,
                              AccessLevel.admin_only,
                            )
                            ? _getAccessLevelColor(AccessLevel.admin_only)
                            : themeSettings.fontColor1.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      '管理者',
                      style: TextStyle(
                        fontSize: 12 * themeSettings.fontSizeScale,
                        color:
                            _isLevelSelected(
                              currentLevel,
                              AccessLevel.admin_only,
                            )
                            ? Colors.white
                            : themeSettings.fontColor1,
                        fontWeight:
                            _isLevelSelected(
                              currentLevel,
                              AccessLevel.admin_only,
                            )
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontFamily: themeSettings.fontFamily,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              // リーダーボタン
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(AccessLevel.admin_leader),
                  child: Container(
                    margin: EdgeInsets.only(right: 8),
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color:
                          _isLevelSelected(
                            currentLevel,
                            AccessLevel.admin_leader,
                          )
                          ? _getAccessLevelColor(AccessLevel.admin_leader)
                          : themeSettings.fontColor1.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            _isLevelSelected(
                              currentLevel,
                              AccessLevel.admin_leader,
                            )
                            ? _getAccessLevelColor(AccessLevel.admin_leader)
                            : themeSettings.fontColor1.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      'リーダー',
                      style: TextStyle(
                        fontSize: 12 * themeSettings.fontSizeScale,
                        color:
                            _isLevelSelected(
                              currentLevel,
                              AccessLevel.admin_leader,
                            )
                            ? Colors.white
                            : themeSettings.fontColor1,
                        fontWeight:
                            _isLevelSelected(
                              currentLevel,
                              AccessLevel.admin_leader,
                            )
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontFamily: themeSettings.fontFamily,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              // メンバーボタン
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(AccessLevel.all_members),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color:
                          _isLevelSelected(
                            currentLevel,
                            AccessLevel.all_members,
                          )
                          ? _getAccessLevelColor(AccessLevel.all_members)
                          : themeSettings.fontColor1.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            _isLevelSelected(
                              currentLevel,
                              AccessLevel.all_members,
                            )
                            ? _getAccessLevelColor(AccessLevel.all_members)
                            : themeSettings.fontColor1.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      'メンバー',
                      style: TextStyle(
                        fontSize: 12 * themeSettings.fontSizeScale,
                        color:
                            _isLevelSelected(
                              currentLevel,
                              AccessLevel.all_members,
                            )
                            ? Colors.white
                            : themeSettings.fontColor1,
                        fontWeight:
                            _isLevelSelected(
                              currentLevel,
                              AccessLevel.all_members,
                            )
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontFamily: themeSettings.fontFamily,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getAccessLevelColor(AccessLevel level) {
    switch (level) {
      case AccessLevel.admin_only:
        return Colors.red;
      case AccessLevel.admin_leader:
        return Colors.orange;
      case AccessLevel.all_members:
        return Colors.blue;
    }
  }

  String _getAccessLevelDisplayName(AccessLevel level) {
    switch (level) {
      case AccessLevel.admin_only:
        return '管理者のみ';
      case AccessLevel.admin_leader:
        return '管理者とリーダー';
      case AccessLevel.all_members:
        return '全メンバー';
    }
  }

  /// 階層的な選択状態を判定する
  /// 管理者をタップ: 管理者のみ選択
  /// リーダーをタップ: 管理者とリーダーが選択
  /// メンバーをタップ: 管理者とリーダーとメンバーが選択
  bool _isLevelSelected(AccessLevel currentLevel, AccessLevel buttonLevel) {
    switch (buttonLevel) {
      case AccessLevel.admin_only:
        // 管理者ボタンは、現在の権限が管理者のみ、管理者・リーダー、全メンバーの場合に選択
        return currentLevel == AccessLevel.admin_only ||
            currentLevel == AccessLevel.admin_leader ||
            currentLevel == AccessLevel.all_members;
      case AccessLevel.admin_leader:
        // リーダーボタンは、現在の権限が管理者・リーダーまたは全メンバーの場合に選択
        return currentLevel == AccessLevel.admin_leader ||
            currentLevel == AccessLevel.all_members;
      case AccessLevel.all_members:
        // メンバーボタンは、現在の権限が全メンバーの場合のみ選択
        return currentLevel == AccessLevel.all_members;
    }
  }

  Widget _buildMemberPermissionSettings([StateSetter? setModalState]) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'メンバー権限設定',
          style: TextStyle(
            fontSize: 18 * themeSettings.fontSizeScale,
            fontWeight: FontWeight.bold,
            color: themeSettings.fontColor1,
            fontFamily: themeSettings.fontFamily,
          ),
        ),
        SizedBox(height: 16),
        _buildPermissionSwitch(
          title: 'メンバーが招待できる',
          description: 'メンバーがQRコードを生成して他のユーザーを招待できる',
          value: _groupSettings!.allowMemberInvite,
          onChanged: (value) {
            print('GroupInfoPage: メンバーが招待できる onChanged: $value');
            if (setModalState != null) {
              setModalState(() {
                _groupSettings = _groupSettings!.copyWith(
                  allowMemberInvite: value,
                );
              });
            } else {
              setState(() {
                _groupSettings = _groupSettings!.copyWith(
                  allowMemberInvite: value,
                );
              });
            }
            _updateGroupSettings(_groupSettings!);
          },
        ),
        SizedBox(height: 16),
        _buildPermissionSwitch(
          title: 'メンバーがメンバー一覧を見れる',
          description: 'メンバーがグループのメンバー一覧を表示できる',
          value: _groupSettings!.allowMemberViewMembers,
          onChanged: (value) {
            print('GroupInfoPage: メンバーがメンバー一覧を見れる onChanged: $value');
            if (setModalState != null) {
              setModalState(() {
                _groupSettings = _groupSettings!.copyWith(
                  allowMemberViewMembers: value,
                );
              });
            } else {
              setState(() {
                _groupSettings = _groupSettings!.copyWith(
                  allowMemberViewMembers: value,
                );
              });
            }
            _updateGroupSettings(_groupSettings!);
          },
        ),
      ],
    );
  }

  Widget _buildPermissionChip(
    String label,
    AccessLevel permission,
    AccessLevel currentPermission,
    Color color,
    VoidCallback onTap,
  ) {
    final themeSettings = Provider.of<ThemeSettings>(context);
    final isSelected = currentPermission == permission;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            border: Border.all(color: isSelected ? color : Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : themeSettings.fontColor1,
              fontSize: 12 * themeSettings.fontSizeScale,
              fontWeight: FontWeight.bold,
              fontFamily: themeSettings.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionSwitch({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return GestureDetector(
      onTap: () {
        print('GestureDetector tapped: $title');
        print('Current value: $value');
        print('Toggling to: ${!value}');
        onChanged(!value);
      },
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16 * themeSettings.fontSizeScale,
                    fontWeight: FontWeight.bold,
                    color: themeSettings.fontColor1,
                    fontFamily: themeSettings.fontFamily,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12 * themeSettings.fontSizeScale,
                    color: themeSettings.fontColor1.withOpacity(0.7),
                    fontFamily: themeSettings.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (newValue) {
              print('Switch onChanged called: $title');
              print('Current value: $value');
              print('New value: $newValue');
              onChanged(newValue);
            },
            activeColor: themeSettings.buttonColor,
          ),
        ],
      ),
    );
  }

  void _updateDataPermission(String dataType, AccessLevel permission) {
    if (_groupSettings == null) return;

    final updatedPermissions = Map<String, AccessLevel>.from(
      _groupSettings!.dataPermissions,
    );
    updatedPermissions[dataType] = permission;

    final updatedSettings = _groupSettings!.copyWith(
      dataPermissions: updatedPermissions,
    );
    _updateGroupSettings(updatedSettings);
  }

  Widget _infoChip(
    ThemeSettings theme,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.buttonColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.buttonColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: theme.buttonColor, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: theme.fontColor1,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.fontColor1.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(ThemeSettings theme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.fontColor1.withOpacity(0.6),
          ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.fontColor1,
          ),
        ),
      ],
    );
  }

  String _calculateGrowthRate() {
    // 簡易的な成長率計算（実際の実装では過去データと比較）
    final stats = _groupProfile?.stats;
    if (stats == null) return '0.0';

    final totalActivity =
        stats.attendanceDays +
        stats.dripPackCount +
        (stats.totalRoastTimeHours / 10).round();
    if (totalActivity == 0) return '0.0';

    // 仮の成長率計算
    return (totalActivity * 0.5).clamp(0.0, 100.0).toStringAsFixed(1);
  }

  Widget _buildMembersSection(ThemeSettings themeSettings, Group group) {
    // 権限チェック
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRole = group.getMemberRole(user.uid);

      // 管理者またはリーダーは常に表示
      if (userRole == GroupRole.admin || userRole == GroupRole.leader) {
        return _buildMembersList(themeSettings, group);
      }

      // メンバーの場合は設定をチェック
      if (_groupSettings != null && _groupSettings!.allowMemberViewMembers) {
        return _buildMembersList(themeSettings, group);
      } else {
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: themeSettings.fontColor1.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: themeSettings.fontColor1.withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lock,
                color: themeSettings.fontColor1.withOpacity(0.5),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'メンバー一覧の表示権限がありません',
                style: TextStyle(
                  color: themeSettings.fontColor1.withOpacity(0.7),
                  fontSize: 14 * themeSettings.fontSizeScale,
                  fontFamily: themeSettings.fontFamily,
                ),
              ),
            ],
          ),
        );
      }
    }

    return _buildMembersList(themeSettings, group);
  }

  Widget _buildMembersList(ThemeSettings themeSettings, Group group) {
    return Row(
      children: [
        ...group.members.take(8).map((member) {
          final role = group.getMemberRole(member.uid);
          Color roleColor;
          IconData roleIcon;
          String roleText;
          if (role == GroupRole.admin) {
            roleColor = Colors.red;
            roleIcon = Icons.admin_panel_settings;
            roleText = '管理者';
          } else if (role == GroupRole.leader) {
            roleColor = Colors.orange;
            roleIcon = Icons.star;
            roleText = 'リーダー';
          } else {
            roleColor = Colors.blue;
            roleIcon = Icons.person;
            roleText = 'メンバー';
          }
          return Container(
            margin: EdgeInsets.only(right: 8),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: roleColor.withOpacity(0.1),
                  backgroundImage: member.photoUrl != null
                      ? NetworkImage(member.photoUrl!)
                      : null,
                  child: member.photoUrl == null
                      ? Text(
                          member.displayName.isNotEmpty
                              ? member.displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: roleColor,
                          ),
                        )
                      : null,
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(roleIcon, color: roleColor, size: 12),
                    SizedBox(width: 2),
                    Text(
                      roleText,
                      style: TextStyle(
                        fontSize: 10,
                        color: roleColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        if (group.members.length > 8)
          Text(
            '+${group.members.length - 8}',
            style: TextStyle(
              fontSize: 16,
              color: themeSettings.fontColor1.withOpacity(0.6),
            ),
          ),
      ],
    );
  }

  Widget _buildMemberCard(
    ThemeSettings themeSettings,
    GroupMember member,
    Group group,
  ) {
    final isCurrentUser = member.uid == FirebaseAuth.instance.currentUser?.uid;
    final role = group.getMemberRole(member.uid);
    final isLeader = group.isLeader(member.uid);
    final isAdmin = role == GroupRole.admin;

    // 役割に応じた色とアイコンを設定
    Color roleColor;
    IconData roleIcon;
    String roleText;

    if (isAdmin) {
      roleColor = Colors.red;
      roleIcon = Icons.admin_panel_settings;
      roleText = '管理者';
    } else if (isLeader) {
      roleColor = Colors.orange;
      roleIcon = Icons.star;
      roleText = 'リーダー';
    } else {
      roleColor = Colors.blue;
      roleIcon = Icons.person;
      roleText = 'メンバー';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeSettings.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser
              ? themeSettings.buttonColor.withOpacity(0.3)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          // プロフィール画像
          CircleAvatar(
            radius: 24,
            backgroundColor: roleColor.withOpacity(0.1),
            backgroundImage: member.photoUrl != null
                ? NetworkImage(member.photoUrl!)
                : null,
            child: member.photoUrl == null
                ? Text(
                    member.displayName.isNotEmpty
                        ? member.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: roleColor,
                    ),
                  )
                : null,
          ),
          SizedBox(width: 16),

          // メンバー情報
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      member.displayName,
                      style: TextStyle(
                        fontSize: 16 * themeSettings.fontSizeScale,
                        fontWeight: FontWeight.bold,
                        color: themeSettings.fontColor1,
                        fontFamily: themeSettings.fontFamily,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: themeSettings.buttonColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'あなた',
                          style: TextStyle(
                            fontSize: 10,
                            color: themeSettings.buttonColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(roleIcon, size: 16, color: roleColor),
                    SizedBox(width: 4),
                    Text(
                      roleText,
                      style: TextStyle(
                        fontSize: 14 * themeSettings.fontSizeScale,
                        color: roleColor,
                        fontWeight: FontWeight.w600,
                        fontFamily: themeSettings.fontFamily,
                      ),
                    ),
                    if (member.email.isNotEmpty) ...[
                      SizedBox(width: 8),
                      Text(
                        '•',
                        style: TextStyle(color: themeSettings.fontColor2),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          member.email,
                          style: TextStyle(
                            fontSize: 12 * themeSettings.fontSizeScale,
                            color: themeSettings.fontColor2,
                            fontFamily: themeSettings.fontFamily,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // 権限変更ボタン（管理者のみ表示）
          if (_groupProvider?.isCurrentUserLeaderOfCurrentGroup() == true &&
              !isCurrentUser)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: themeSettings.fontColor2),
              onSelected: (value) => _handleMemberAction(value, member),
              itemBuilder: (context) => [
                if (isAdmin) ...[
                  PopupMenuItem(
                    value: 'remove_admin',
                    child: Row(
                      children: [
                        Icon(Icons.person, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('管理者を解除'),
                      ],
                    ),
                  ),
                ] else ...[
                  PopupMenuItem(
                    value: 'make_admin',
                    child: Row(
                      children: [
                        Icon(Icons.admin_panel_settings, color: Colors.red),
                        SizedBox(width: 8),
                        Text('管理者に設定'),
                      ],
                    ),
                  ),
                ],
                if (isLeader) ...[
                  PopupMenuItem(
                    value: 'remove_leader',
                    child: Row(
                      children: [
                        Icon(Icons.person, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('リーダーを解除'),
                      ],
                    ),
                  ),
                ] else ...[
                  PopupMenuItem(
                    value: 'make_leader',
                    child: Row(
                      children: [
                        Icon(Icons.star, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('リーダーに設定'),
                      ],
                    ),
                  ),
                ],
                PopupMenuItem(
                  value: 'remove_member',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove, color: Colors.red),
                      SizedBox(width: 8),
                      Text('メンバーを削除'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _handleMemberAction(String action, GroupMember member) async {
    final group = _groupProvider?.currentGroup;
    if (group == null) return;

    try {
      switch (action) {
        case 'make_admin':
          await _groupProvider?.changeMemberRole(
            groupId: group.id,
            memberUid: member.uid,
            newRole: GroupRole.admin,
          );
          break;
        case 'remove_admin':
          await _groupProvider?.changeMemberRole(
            groupId: group.id,
            memberUid: member.uid,
            newRole: GroupRole.member,
          );
          break;
        case 'make_leader':
          await _groupProvider?.changeMemberRole(
            groupId: group.id,
            memberUid: member.uid,
            newRole: GroupRole.leader,
          );
          break;
        case 'remove_leader':
          await _groupProvider?.changeMemberRole(
            groupId: group.id,
            memberUid: member.uid,
            newRole: GroupRole.member,
          );
          break;
        case 'remove_member':
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('メンバーを削除'),
              content: Text('${member.displayName}をグループから削除しますか？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text('削除'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await _groupProvider?.removeMember(
              groupId: group.id,
              memberUid: member.uid,
            );
          }
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作に失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildGroupInfo(ThemeSettings themeSettings, Group group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.name,
          style: TextStyle(
            fontSize: 24 * themeSettings.fontSizeScale,
            fontWeight: FontWeight.bold,
            color: themeSettings.fontColor1,
            fontFamily: themeSettings.fontFamily,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        if (group.description.isNotEmpty)
          Text(
            group.description,
            style: TextStyle(
              fontSize: 18 * themeSettings.fontSizeScale,
              color: themeSettings.fontColor1.withOpacity(0.7),
              fontFamily: themeSettings.fontFamily,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _buildEditForm(ThemeSettings themeSettings, Group group) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameController,
            style: TextStyle(
              fontSize: 24 * themeSettings.fontSizeScale,
              fontWeight: FontWeight.bold,
              color: themeSettings.fontColor1,
              fontFamily: themeSettings.fontFamily,
            ),
            decoration: InputDecoration(
              hintText: 'グループ名',
              hintStyle: TextStyle(
                fontSize: 24 * themeSettings.fontSizeScale,
                color: themeSettings.fontColor1.withOpacity(0.5),
                fontFamily: themeSettings.fontFamily,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: themeSettings.buttonColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: themeSettings.buttonColor,
                  width: 2,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'グループ名を入力してください';
              }
              if (value.trim().length > 50) {
                return 'グループ名は50文字以内で入力してください';
              }
              return null;
            },
          ),
          SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            style: TextStyle(
              fontSize: 18 * themeSettings.fontSizeScale,
              color: themeSettings.fontColor1,
              fontFamily: themeSettings.fontFamily,
            ),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'グループの説明（任意）',
              hintStyle: TextStyle(
                fontSize: 18 * themeSettings.fontSizeScale,
                color: themeSettings.fontColor1.withOpacity(0.5),
                fontFamily: themeSettings.fontFamily,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: themeSettings.fontColor1.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: themeSettings.buttonColor,
                  width: 2,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            validator: (value) {
              if (value != null && value.trim().length > 200) {
                return '説明は200文字以内で入力してください';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
