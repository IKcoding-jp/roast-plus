import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/theme_settings.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../models/group_gamification_models.dart';

import '../../services/group_statistics_service.dart';
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

  Map<String, dynamic> _groupStats = {};
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

      // 統計データの取得を確認
      print('GroupInfoPage: グループ統計データ取得完了');
      print('GroupInfoPage: 統計データ: $_groupStats');

      // ウィジェットが破棄されている場合は処理を中断
      if (!mounted) return;

      // グループのゲーミフィケーションプロファイルを取得
      await groupProvider.loadGroupGamificationProfile(group.id);

      // ウィジェットが破棄されている場合は処理を中断
      if (!mounted) return;

      // ゲーミフィケーションプロファイルの監視を開始
      groupProvider.watchGroupGamificationProfile(group.id);
      _currentGroupId = group.id;

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

  bool _isDarkTheme(ThemeSettings themeSettings) {
    // ダークテーマかどうかを判定（背景色の明度で判断）
    final backgroundColor = themeSettings.backgroundColor;
    final luminance = backgroundColor.computeLuminance();
    return luminance < 0.5;
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
        // グループの監視を確実に開始
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!groupProvider.isWatchingGroupData) {
            groupProvider.watchGroup(group.id);
          }
        });

        // プロフィールが読み込まれていない場合は読み込みを開始
        final groupGamificationProfile = groupProvider
            .getGroupGamificationProfile(group.id);

        // プロフィールが存在しない場合は読み込みを開始
        if (groupGamificationProfile == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            groupProvider.loadGroupGamificationProfile(group.id);
            groupProvider.watchGroupGamificationProfile(group.id);
          });
        }

        final stats = groupGamificationProfile?.stats;
        final badgeCount = groupGamificationProfile?.badges.length ?? 0;
        final allBadgeCount = 30; // グループバッジの総数（固定値）
        final currentLevel = groupGamificationProfile?.level ?? 1;
        final experiencePoints =
            groupGamificationProfile?.experiencePoints ?? 0;
        final levelProgress = groupGamificationProfile?.levelProgress ?? 0.0;
        final experienceToNextLevel =
            groupGamificationProfile?.experienceToNextLevel ?? 0;
        final memberCount = group.members.length;

        // デバッグ情報を出力
        print('GroupInfoPage: メンバー数: $memberCount');
        print(
          'GroupInfoPage: メンバー一覧: ${group.members.map((m) => '${m.displayName}(${m.email})').join(', ')}',
        );

        return Center(
          child: Container(
            width: size.width > 500 ? 500 : size.width * 0.95,
            constraints: BoxConstraints(
              maxHeight: size.height * 0.95, // 最大高さを増加
              minHeight: size.height * 0.6, // 最小高さを調整
            ),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              color: themeSettings.backgroundColor2,
              shadowColor: themeSettings.buttonColor.withOpacity(0.15),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: size.height * 0.9, // Card内の最大高さを設定
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(), // スクロール物理を明示的に設定
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // グループ名と説明
                        Row(
                          children: [
                            Icon(
                              Icons.groups,
                              color: themeSettings.iconColor,
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
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _isDarkTheme(themeSettings)
                                ? Colors.white.withOpacity(0.05)
                                : themeSettings.backgroundColor2.withOpacity(
                                    0.1,
                                  ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: themeSettings.buttonColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.analytics,
                                    color: themeSettings.iconColor,
                                    size: 24,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '活動統計',
                                    style: TextStyle(
                                      fontSize:
                                          18 * themeSettings.fontSizeScale,
                                      color: themeSettings.fontColor1,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: themeSettings.fontFamily,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
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
                            ],
                          ),
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
                              color: themeSettings.iconColor,
                              size: 32,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Lv.$currentLevel',
                              style: TextStyle(
                                fontSize: 22 * themeSettings.fontSizeScale,
                                fontWeight: FontWeight.bold,
                                color: themeSettings.fontColor1,
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
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _isDarkTheme(themeSettings)
                                ? Colors.white.withOpacity(0.05)
                                : themeSettings.backgroundColor2.withOpacity(
                                    0.1,
                                  ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: themeSettings.buttonColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.emoji_events,
                                    color: themeSettings.iconColor,
                                    size: 24,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '$badgeCount / $allBadgeCount バッジ獲得',
                                    style: TextStyle(
                                      fontSize:
                                          18 * themeSettings.fontSizeScale,
                                      color: themeSettings.fontColor1,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: themeSettings.fontFamily,
                                    ),
                                  ),
                                  Spacer(),
                                  Text(
                                    '${((badgeCount / allBadgeCount) * 100).toInt()}%',
                                    style: TextStyle(
                                      fontSize:
                                          16 * themeSettings.fontSizeScale,
                                      color: themeSettings.fontColor1
                                          .withOpacity(0.7),
                                      fontFamily: themeSettings.fontFamily,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              LinearProgressIndicator(
                                value: (badgeCount / allBadgeCount).clamp(
                                  0.0,
                                  1.0,
                                ),
                                minHeight: 8,
                                backgroundColor: themeSettings.fontColor1
                                    .withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  themeSettings.buttonColor,
                                ),
                              ),
                              SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: GroupBadgeConditions.conditions
                                    .take(8)
                                    .map((condition) {
                                      final isEarned =
                                          groupGamificationProfile?.badges.any(
                                            (b) => b.id == condition.badgeId,
                                          ) ??
                                          false;
                                      return Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isEarned
                                              ? condition.color.withOpacity(0.1)
                                              : themeSettings.fontColor1
                                                    .withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: isEarned
                                                ? condition.color.withOpacity(
                                                    0.3,
                                                  )
                                                : themeSettings.fontColor1
                                                      .withOpacity(0.1),
                                            width: 1,
                                          ),
                                        ),
                                        child: Icon(
                                          condition.icon,
                                          color: isEarned
                                              ? condition.color
                                              : themeSettings.fontColor1
                                                    .withOpacity(0.3),
                                          size: 28,
                                        ),
                                      );
                                    })
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),

                        // レベルタイトル
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            vertical: 16, // 縦のパディングを少し縮小
                            horizontal: 16, // 横のパディングを縮小
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isDarkTheme(themeSettings)
                                  ? [
                                      Colors.white.withOpacity(0.1),
                                      Colors.white.withOpacity(0.05),
                                    ]
                                  : [
                                      themeSettings.buttonColor.withOpacity(
                                        0.1,
                                      ),
                                      themeSettings.buttonColor.withOpacity(
                                        0.05,
                                      ),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _isDarkTheme(themeSettings)
                                  ? Colors.white.withOpacity(0.2)
                                  : themeSettings.buttonColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Builder(
                            builder: (context) {
                              final levelStyle = _getLevelStyle(currentLevel);
                              final specialEffect =
                                  levelStyle['specialEffect'] as String;

                              return Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildLevelIcon(
                                        themeSettings,
                                        levelStyle,
                                        specialEffect,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _getLevelTitle(currentLevel),
                                          style: TextStyle(
                                            fontSize:
                                                levelStyle['titleFontSize'] *
                                                themeSettings.fontSizeScale,
                                            fontWeight: FontWeight.bold,
                                            color: _getLevelTextColor(
                                              themeSettings,
                                              specialEffect,
                                            ),
                                            fontFamily:
                                                themeSettings.fontFamily,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'レベル $currentLevel',
                                    style: TextStyle(
                                      fontSize:
                                          16 * themeSettings.fontSizeScale,
                                      color: themeSettings.fontColor1
                                          .withOpacity(0.7),
                                      fontFamily: themeSettings.fontFamily,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 40), // 最後に十分なスペースを追加
                      ],
                    ),
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
        Icon(icon, color: themeSettings.iconColor, size: 36),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20 * themeSettings.fontSizeScale,
            fontWeight: FontWeight.bold,
            color: _isDarkTheme(themeSettings)
                ? Colors.white
                : themeSettings.fontColor1,
            fontFamily: themeSettings.fontFamily,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 18 * themeSettings.fontSizeScale,
            color: _isDarkTheme(themeSettings)
                ? Colors.white.withOpacity(0.8)
                : themeSettings.fontColor1.withOpacity(0.6),
            fontFamily: themeSettings.fontFamily,
          ),
        ),
      ],
    );
  }

  String _getLevelTitle(int level) {
    // コーヒー焙煎・加工業務に特化したグループ名システム（レベル9999まで対応）
    if (level < 5) return 'ローストスターティング';
    if (level < 10) return 'ローストビキナー';
    if (level < 25) return 'ローストアプレンティス';
    if (level < 50) return 'ローストジュニア';
    if (level < 100) return 'ローストベテラン';
    if (level < 200) return 'ローストエキスパート';
    if (level < 500) return 'ローストマスター';
    if (level < 1000) return 'ローストスペシャリスト';
    if (level < 2000) return 'ローストアーティスト';
    if (level < 3500) return 'ローストエグゼクティブ';
    if (level < 5000) return 'ローストレジェンド';
    if (level < 7000) return 'ローストパイオニア';
    if (level < 9000) return 'ローストエンペラー';
    if (level < 9999) return 'ローストマイスター';
    return 'レベル9999 ローストエターナル';
  }

  // レベルに応じたUIスタイルを取得
  Map<String, dynamic> _getLevelStyle(int level) {
    // 基本スタイル
    Map<String, dynamic> style = {
      'cardElevation': 4.0,
      'borderRadius': 12.0,
      'iconSize': 28.0,
      'titleFontSize': 18.0,
      'hasGradient': false,
      'hasGlow': false,
      'hasAnimation': false,
      'specialEffect': 'none',
    };

    // レベルに応じてスタイルをアップグレード
    if (level >= 100) {
      // ローストエキスパート以上
      style['cardElevation'] = 6.0;
      style['borderRadius'] = 16.0;
      style['iconSize'] = 32.0;
      style['titleFontSize'] = 20.0;
      style['hasGradient'] = true;
    }

    if (level >= 500) {
      // ローストマスター以上
      style['cardElevation'] = 8.0;
      style['borderRadius'] = 20.0;
      style['iconSize'] = 36.0;
      style['titleFontSize'] = 22.0;
      style['hasGlow'] = true;
    }

    if (level >= 1000) {
      // ローストスペシャリスト以上
      style['cardElevation'] = 10.0;
      style['borderRadius'] = 24.0;
      style['iconSize'] = 40.0;
      style['titleFontSize'] = 24.0;
      style['hasAnimation'] = true;
    }

    if (level >= 2000) {
      // ローストアーティスト以上
      style['cardElevation'] = 12.0;
      style['borderRadius'] = 28.0;
      style['iconSize'] = 44.0;
      style['titleFontSize'] = 26.0;
      style['specialEffect'] = 'rainbow';
    }

    if (level >= 3500) {
      // ローストエグゼクティブ以上
      style['cardElevation'] = 14.0;
      style['borderRadius'] = 32.0;
      style['iconSize'] = 48.0;
      style['titleFontSize'] = 28.0;
      style['specialEffect'] = 'golden';
    }

    if (level >= 5000) {
      // ローストレジェンド以上
      style['cardElevation'] = 16.0;
      style['borderRadius'] = 36.0;
      style['iconSize'] = 52.0;
      style['titleFontSize'] = 30.0;
      style['specialEffect'] = 'legendary';
    }

    if (level >= 7000) {
      // ローストパイオニア以上
      style['cardElevation'] = 18.0;
      style['borderRadius'] = 40.0;
      style['iconSize'] = 56.0;
      style['titleFontSize'] = 32.0;
      style['specialEffect'] = 'pioneer';
    }

    if (level >= 9000) {
      // ローストエンペラー以上
      style['cardElevation'] = 20.0;
      style['borderRadius'] = 44.0;
      style['iconSize'] = 60.0;
      style['titleFontSize'] = 34.0;
      style['specialEffect'] = 'emperor';
    }

    if (level >= 9999) {
      // ローストエターナル
      style['cardElevation'] = 25.0;
      style['borderRadius'] = 50.0;
      style['iconSize'] = 64.0;
      style['titleFontSize'] = 36.0;
      style['specialEffect'] = 'eternal';
    }

    return style;
  }

  // レベルに応じたアイコンを構築
  Widget _buildLevelIcon(
    ThemeSettings themeSettings,
    Map<String, dynamic> levelStyle,
    String specialEffect,
  ) {
    final iconSize = levelStyle['iconSize'] as double;
    final hasGlow = levelStyle['hasGlow'] as bool;

    IconData iconData = Icons.emoji_events;
    Color iconColor = themeSettings.iconColor; // 基本はテーマのアイコン色

    // 特殊効果に応じてアイコンと色を変更
    switch (specialEffect) {
      case 'rainbow':
        iconData = Icons.auto_awesome;
        iconColor = Colors.purple;
        break;
      case 'golden':
        iconData = Icons.star;
        iconColor = Colors.amber;
        break;
      case 'legendary':
        iconData = Icons.whatshot;
        iconColor = Colors.orange;
        break;
      case 'pioneer':
        iconData = Icons.explore;
        iconColor = Colors.blue;
        break;
      case 'emperor':
        iconData = Icons.workspace_premium;
        iconColor = Colors.yellow;
        break;
      case 'eternal':
        iconData = Icons.all_inclusive;
        iconColor = Colors.white;
        break;
      default:
        iconData = Icons.emoji_events;
        iconColor = themeSettings.iconColor;
    }

    Widget icon = Icon(iconData, color: iconColor, size: iconSize);

    // グロー効果を追加
    if (hasGlow) {
      return Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: iconColor.withOpacity(0.5),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: icon,
      );
    }

    return icon;
  }

  // レベルに応じたテキスト色を取得
  Color _getLevelTextColor(ThemeSettings themeSettings, String specialEffect) {
    switch (specialEffect) {
      case 'rainbow':
        return Colors.purple;
      case 'golden':
        return Colors.amber;
      case 'legendary':
        return Colors.orange;
      case 'pioneer':
        return Colors.blue;
      case 'emperor':
        return Colors.yellow;
      case 'eternal':
        return Colors.white;
      default:
        return themeSettings.fontColor1;
    }
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
    final user = FirebaseAuth.instance.currentUser;
    final isCurrentUserAdmin =
        user != null && group.getMemberRole(user.uid) == GroupRole.admin;

    // 管理者→リーダー→メンバーの順でソート
    final sortedMembers = List<GroupMember>.from(group.members);
    sortedMembers.sort((a, b) {
      int roleOrder(GroupRole? role) {
        if (role == GroupRole.admin) return 0;
        if (role == GroupRole.leader) return 1;
        return 2; // member
      }

      return roleOrder(
        group.getMemberRole(a.uid),
      ).compareTo(roleOrder(group.getMemberRole(b.uid)));
    });

    return Row(
      children: [
        ...sortedMembers.take(8).map((member) {
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
          return GestureDetector(
            onTap: isCurrentUserAdmin && member.uid != user.uid
                ? () => _showMemberRoleDialog(context, member, group)
                : null,
            child: Container(
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
            ),
          );
        }),
        if (sortedMembers.length > 8)
          Text(
            '+${sortedMembers.length - 8}',
            style: TextStyle(
              fontSize: 16,
              color: themeSettings.fontColor1.withOpacity(0.6),
            ),
          ),
      ],
    );
  }

  void _showMemberRoleDialog(
    BuildContext context,
    GroupMember member,
    Group group,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    final isCurrentUserAdmin =
        user != null && group.getMemberRole(user.uid) == GroupRole.admin;
    final isTargetAdmin = group.getMemberRole(member.uid) == GroupRole.admin;
    final isTargetLeader = group.getMemberRole(member.uid) == GroupRole.leader;
    final isTargetMember = group.getMemberRole(member.uid) == GroupRole.member;
    final roleColor = isTargetAdmin
        ? Colors.red
        : isTargetLeader
        ? Colors.orange
        : Colors.blue;
    final roleText = isTargetAdmin
        ? '管理者'
        : isTargetLeader
        ? 'リーダー'
        : 'メンバー';
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 8,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 上部に大きなアイコンと名前
                CircleAvatar(
                  radius: 32,
                  backgroundColor: roleColor.withOpacity(0.12),
                  backgroundImage: member.photoUrl != null
                      ? NetworkImage(member.photoUrl!)
                      : null,
                  child: member.photoUrl == null
                      ? Text(
                          member.displayName.isNotEmpty
                              ? member.displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: roleColor,
                          ),
                        )
                      : null,
                ),
                SizedBox(height: 12),
                Text(
                  member.displayName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                // 役割バッジ
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isTargetAdmin
                            ? Icons.admin_panel_settings
                            : isTargetLeader
                            ? Icons.star
                            : Icons.person,
                        color: roleColor,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        roleText,
                        style: TextStyle(
                          color: roleColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 18),
                // 説明文
                Text(
                  'このメンバーの役割を変更できます。\n管理者権限を渡すと、あなたはメンバーになります。',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 18),
                // ボタン群
                if (isCurrentUserAdmin && !isTargetAdmin)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _roleActionButton(
                          icon: Icons.admin_panel_settings,
                          label: '管理者権限を渡す',
                          color: Colors.red,
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _transferAdminRole(member, group);
                          },
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: 8),
                if (isCurrentUserAdmin && (!isTargetLeader || !isTargetMember))
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!isTargetLeader)
                        Expanded(
                          child: _roleActionButton(
                            icon: Icons.star,
                            label: 'リーダーにする',
                            color: Colors.orange,
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await _changeMemberRole(
                                member,
                                group,
                                GroupRole.leader,
                              );
                            },
                          ),
                        ),
                      if (!isTargetMember)
                        Expanded(
                          child: _roleActionButton(
                            icon: Icons.person,
                            label: 'メンバーにする',
                            color: Colors.blue,
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await _changeMemberRole(
                                member,
                                group,
                                GroupRole.member,
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                SizedBox(height: 16),
                // 注意書き
                if (isCurrentUserAdmin && !isTargetAdmin)
                  Text(
                    '※ この操作は元に戻せません',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    '閉じる',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _roleActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white, size: 20),
        label: Text(
          label,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 3,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        onPressed: onPressed,
      ),
    );
  }

  Future<void> _transferAdminRole(GroupMember member, Group group) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final provider = context.read<GroupProvider>();
    try {
      // 1. 対象をadminに
      await provider.changeMemberRole(
        groupId: group.id,
        memberUid: member.uid,
        newRole: GroupRole.admin,
      );
      // 2. 自分をmemberに
      await provider.changeMemberRole(
        groupId: group.id,
        memberUid: user.uid,
        newRole: GroupRole.member,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('管理者権限を${member.displayName}さんに渡しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('権限の譲渡に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _changeMemberRole(
    GroupMember member,
    Group group,
    GroupRole newRole,
  ) async {
    final provider = context.read<GroupProvider>();
    try {
      await provider.changeMemberRole(
        groupId: group.id,
        memberUid: member.uid,
        newRole: newRole,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${member.displayName}さんを${_roleText(newRole)}に変更しました',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('権限変更に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _roleText(GroupRole role) {
    switch (role) {
      case GroupRole.admin:
        return '管理者';
      case GroupRole.leader:
        return 'リーダー';
      case GroupRole.member:
        return 'メンバー';
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
