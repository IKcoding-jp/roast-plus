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
    _fadeController.dispose();
    _slideController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupData() async {
    final groupProvider = context.read<GroupProvider>();
    final gamificationProvider = context.read<GamificationProvider>();

    if (!groupProvider.hasGroup) {
      setState(() => _loading = false);
      return;
    }

    try {
      final group = groupProvider.currentGroup!;

      // グループ統計を取得
      final statisticsService = GroupStatisticsService();
      _groupStats = await statisticsService.getGroupStatistics(group.id);

      // グループメンバーのゲーミフィケーションデータを取得
      _memberProfiles =
          await GroupDataSyncService.getGroupMembersGamificationData(group.id);

      // グループ全体のプロファイルを計算
      _groupProfile = _calculateGroupProfile(_memberProfiles);

      // グループ設定を取得
      _groupSettings = await GroupFirestoreService.getGroupSettings(group.id);
      _groupSettings ??= GroupSettings.defaultSettings();

      setState(() => _loading = false);

      // アニメーション開始
      _fadeController.forward();
      await Future.delayed(Duration(milliseconds: 200));
      _slideController.forward();
    } catch (e) {
      print('グループデータ読み込みエラー: $e');
      setState(() => _loading = false);
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
      int requiredXP = (100 * level * level * 1.2).round();
      if (totalXP < requiredXP) break;
      level++;
    }
    return level;
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

    setState(() => _isSaving = true);

    try {
      final groupProvider = context.read<GroupProvider>();
      final currentGroup = groupProvider.currentGroup!;

      final updatedGroup = currentGroup.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        updatedAt: DateTime.now(),
      );

      final success = await groupProvider.updateGroup(updatedGroup);

      if (success && mounted) {
        await groupProvider.loadUserGroups();
        setState(() {
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('グループ情報を更新しました'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(groupProvider.error ?? '更新に失敗しました'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
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

    if (confirm != true) return;

    try {
      final success = await groupProvider.deleteGroup(currentGroup.id);
      if (success && mounted) {
        await groupProvider.loadUserGroups();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('グループを削除しました'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateGroupSettings(GroupSettings newSettings) async {
    try {
      await GroupFirestoreService.updateGroupSettings(
        groupId: context.read<GroupProvider>().currentGroup!.id,
        settings: newSettings,
      );

      setState(() {
        _groupSettings = newSettings;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('設定を更新しました'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('設定の更新に失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool get _isUserLeader {
    final user = FirebaseAuth.instance.currentUser;
    final groupProvider = context.read<GroupProvider>();
    final group = groupProvider.currentGroup;

    if (user == null || group == null) return false;

    return group.members.any(
      (m) =>
          m.uid == user.uid &&
          (m.role == GroupRole.leader || m.role == GroupRole.admin),
    );
  }

  void _showSettingsBottomSheet() {
    if (_groupSettings == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSettingsBottomSheet(),
    );
  }

  Widget _buildSettingsBottomSheet() {
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
                  _buildDataPermissionSettings(),
                  SizedBox(height: 20),
                  _buildMemberPermissionSettings(),
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
          if (groupProvider.hasGroup && _isUserLeader) ...[
            if (_isEditing) ...[
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
                onPressed: () => setState(() => _isEditing = false),
              ),
            ] else ...[
              IconButton(
                icon: Icon(Icons.edit, color: themeSettings.iconColor),
                onPressed: () => setState(() => _isEditing = true),
              ),
              IconButton(
                icon: Icon(Icons.qr_code, color: themeSettings.iconColor),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GroupQRGeneratePage(),
                    ),
                  );
                },
                tooltip: 'QRコード生成',
              ),
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
    return CustomScrollView(
      physics: BouncingScrollPhysics(),
      slivers: [
        // グループ基本情報セクション
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildGroupBasicInfo(themeSettings, group),
            ),
          ),
        ),

        // レベル・経験値セクション
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildLevelSection(themeSettings),
            ),
          ),
        ),

        // 統計情報セクション
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildStatsSection(themeSettings),
            ),
          ),
        ),

        // バッジセクション
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildBadgeSection(themeSettings),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupBasicInfo(ThemeSettings themeSettings, Group group) {
    return Container(
      margin: EdgeInsets.all(16),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: themeSettings.backgroundColor2,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                themeSettings.buttonColor.withOpacity(0.1),
                themeSettings.buttonColor.withOpacity(0.05),
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: themeSettings.buttonColor,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: themeSettings.buttonColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.groups,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isEditing) ...[
                              TextFormField(
                                controller: _nameController,
                                style: TextStyle(
                                  fontSize: 20 * themeSettings.fontSizeScale,
                                  fontWeight: FontWeight.bold,
                                  color: themeSettings.fontColor1,
                                  fontFamily: themeSettings.fontFamily,
                                ),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  labelText: 'グループ名',
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.8),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'グループ名を入力してください';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 8),
                              TextFormField(
                                controller: _descriptionController,
                                style: TextStyle(
                                  fontSize: 14 * themeSettings.fontSizeScale,
                                  color: themeSettings.fontColor1,
                                  fontFamily: themeSettings.fontFamily,
                                ),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  labelText: 'グループ説明',
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.8),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                maxLines: 2,
                              ),
                            ] else ...[
                              Text(
                                group.name,
                                style: TextStyle(
                                  fontSize: 24 * themeSettings.fontSizeScale,
                                  fontWeight: FontWeight.bold,
                                  color: themeSettings.fontColor1,
                                  fontFamily: themeSettings.fontFamily,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                group.description,
                                style: TextStyle(
                                  fontSize: 14 * themeSettings.fontSizeScale,
                                  color: themeSettings.fontColor1.withOpacity(
                                    0.7,
                                  ),
                                  fontFamily: themeSettings.fontFamily,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 20),

                  // グループ詳細情報
                  _buildInfoRow(
                    themeSettings,
                    Icons.fingerprint,
                    'グループID',
                    group.id,
                    onTap: () => _copyToClipboard(group.id, 'グループIDをコピーしました'),
                  ),
                  SizedBox(height: 12),
                  _buildInfoRow(
                    themeSettings,
                    Icons.people,
                    '所属人数',
                    '${group.members.length}人',
                  ),
                  SizedBox(height: 12),
                  _buildInfoRow(
                    themeSettings,
                    Icons.calendar_today,
                    '作成日',
                    '${group.createdAt.year}/${group.createdAt.month}/${group.createdAt.day}',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLevelSection(ThemeSettings themeSettings) {
    if (_groupProfile == null) return SizedBox.shrink();

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
                        'Lv.${_groupProfile!.level}',
                        style: TextStyle(
                          fontSize: 36 * themeSettings.fontSizeScale,
                          fontWeight: FontWeight.bold,
                          color: themeSettings.buttonColor,
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                      Text(
                        _getLevelTitle(_groupProfile!.level),
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
                        '${_groupProfile!.experiencePoints}XP',
                        style: TextStyle(
                          fontSize: 18 * themeSettings.fontSizeScale,
                          fontWeight: FontWeight.w600,
                          color: themeSettings.fontColor1,
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                      Text(
                        '次まで${_groupProfile!.experienceToNextLevel}XP',
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
                  widthFactor: _groupProfile!.levelProgress,
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
                '進行度: ${(_groupProfile!.levelProgress * 100).toStringAsFixed(1)}%',
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

  Widget _buildDataPermissionSettings() {
    final themeSettings = Provider.of<ThemeSettings>(context);
    final dataTypes = {
      'roast_records': '焙煎記録一覧',
      'drip_counter_records': 'ドリップカウンター',
      'assignment_board': '担当表',
      'assignment_history': '担当履歴',
      'today_schedule': '本日のスケジュール',
      'work_progress': '作業状況記録',
      'tasting_record': '試飲感想記録',
    };

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
        ...dataTypes.entries.map((entry) {
          final dataType = entry.key;
          final displayName = entry.value;
          final currentPermission = _groupSettings!.getPermissionForDataType(
            dataType,
          );

          return Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 16 * themeSettings.fontSizeScale,
                    fontWeight: FontWeight.w600,
                    color: themeSettings.fontColor1,
                    fontFamily: themeSettings.fontFamily,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    _buildPermissionChip(
                      '管理者のみ',
                      DataPermission.adminOnly,
                      currentPermission,
                      Colors.red,
                      () => _updateDataPermission(
                        dataType,
                        DataPermission.adminOnly,
                      ),
                    ),
                    SizedBox(width: 8),
                    _buildPermissionChip(
                      'リーダーまで',
                      DataPermission.leaderOnly,
                      currentPermission,
                      Colors.orange,
                      () => _updateDataPermission(
                        dataType,
                        DataPermission.leaderOnly,
                      ),
                    ),
                    SizedBox(width: 8),
                    _buildPermissionChip(
                      '全メンバー',
                      DataPermission.memberOnly,
                      currentPermission,
                      Colors.green,
                      () => _updateDataPermission(
                        dataType,
                        DataPermission.memberOnly,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMemberPermissionSettings() {
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
          description: 'メンバーが他のユーザーをグループに招待できる',
          value: _groupSettings!.allowMemberInvite,
          onChanged: (value) {
            final updatedSettings = _groupSettings!.copyWith(
              allowMemberInvite: value,
            );
            _updateGroupSettings(updatedSettings);
          },
        ),
        SizedBox(height: 16),
        _buildPermissionSwitch(
          title: 'メンバーがデータ同期できる',
          description: 'メンバーがグループとのデータ同期を実行できる',
          value: _groupSettings!.allowMemberDataSync,
          onChanged: (value) {
            final updatedSettings = _groupSettings!.copyWith(
              allowMemberDataSync: value,
            );
            _updateGroupSettings(updatedSettings);
          },
        ),
        SizedBox(height: 16),
        _buildPermissionSwitch(
          title: 'メンバーがメンバー一覧を見れる',
          description: 'メンバーがグループのメンバー一覧を閲覧できる',
          value: _groupSettings!.allowMemberViewMembers,
          onChanged: (value) {
            final updatedSettings = _groupSettings!.copyWith(
              allowMemberViewMembers: value,
            );
            _updateGroupSettings(updatedSettings);
          },
        ),
      ],
    );
  }

  Widget _buildPermissionChip(
    String label,
    DataPermission permission,
    DataPermission currentPermission,
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

    return Row(
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
          onChanged: onChanged,
          activeColor: themeSettings.buttonColor,
        ),
      ],
    );
  }

  void _updateDataPermission(String dataType, DataPermission permission) {
    if (_groupSettings == null) return;

    final updatedPermissions = Map<String, DataPermission>.from(
      _groupSettings!.dataPermissions,
    );
    updatedPermissions[dataType] = permission;

    final updatedSettings = _groupSettings!.copyWith(
      dataPermissions: updatedPermissions,
    );
    _updateGroupSettings(updatedSettings);
  }
}
 