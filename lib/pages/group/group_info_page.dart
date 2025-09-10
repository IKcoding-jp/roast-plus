import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/theme_settings.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../models/group_gamification_models.dart';
import 'dart:developer' as developer;

import '../../services/group_statistics_service.dart';
import '../../services/group_firestore_service.dart';
import '../../services/group_data_sync_service.dart';
import '../../widgets/group_level_display_widget.dart';

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
  int _dripPackTotalCount = 0; // ドリップパック記録の合計数

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

    // GroupProviderの変更を監視
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupProvider = context.read<GroupProvider>();
      _groupProvider = groupProvider;
      _currentGroupId = groupProvider.currentGroup?.id;

      // グループ設定の変更を監視
      groupProvider.addListener(_onGroupProviderChanged);
    });
  }

  void _initializeControllers() {
    final groupProvider = context.read<GroupProvider>();
    final group = groupProvider.currentGroup;

    _nameController = TextEditingController(text: group?.name ?? '');
    _descriptionController = TextEditingController(
      text: group?.description ?? '',
    );
  }

  /// GroupProviderの変更を監視するコールバック
  void _onGroupProviderChanged() {
    if (!mounted) return;

    final groupProvider = context.read<GroupProvider>();
    final currentGroup = groupProvider.currentGroup;

    // グループが変更された場合
    if (currentGroup?.id != _currentGroupId) {
      _currentGroupId = currentGroup?.id;
      _loadGroupData();
      return;
    }

    // グループ設定が変更された場合
    if (currentGroup != null && _groupSettings != null) {
      final newSettings = GroupSettings.fromJson(currentGroup.settings);
      if (_groupSettings!.allowLeaderManageGroup !=
          newSettings.allowLeaderManageGroup) {
        developer.log('リーダー管理権限が変更されました', name: 'GroupInfoPage');
        developer.log(
          '古い設定: ${_groupSettings!.allowLeaderManageGroup}',
          name: 'GroupInfoPage',
        );
        developer.log(
          '新しい設定: ${newSettings.allowLeaderManageGroup}',
          name: 'GroupInfoPage',
        );

        setState(() {
          _groupSettings = newSettings;
        });
      }
    }
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
      developer.log('FadeController破棄エラー: $e', name: 'GroupInfoPage', error: e);
    }

    try {
      if (_slideController.isAnimating) {
        _slideController.stop();
      }
      _slideController.dispose();
    } catch (e) {
      developer.log(
        'SlideController破棄エラー: $e',
        name: 'GroupInfoPage',
        error: e,
      );
    }

    // テキストコントローラーを安全に破棄
    try {
      _nameController.dispose();
      _descriptionController.dispose();
    } catch (e) {
      developer.log('TextController破棄エラー: $e', name: 'GroupInfoPage', error: e);
    }

    // ゲーミフィケーションプロファイルの監視を停止
    try {
      if (_currentGroupId != null && _groupProvider != null) {
        _groupProvider!.unwatchGroupGamificationProfile(_currentGroupId!);
      }
    } catch (e) {
      developer.log('ゲーミフィケーション監視停止エラー: $e', name: 'GroupInfoPage', error: e);
    }

    // GroupProviderのリスナーを削除
    try {
      if (_groupProvider != null) {
        _groupProvider!.removeListener(_onGroupProviderChanged);
      }
    } catch (e) {
      developer.log(
        'GroupProviderリスナー削除エラー: $e',
        name: 'GroupInfoPage',
        error: e,
      );
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
          developer.log('前のグループの監視停止エラー: $e', name: 'GroupInfoPage', error: e);
        }
      }

      // 新しいグループの監視を開始
      if (currentGroupId != null && mounted) {
        try {
          _groupProvider!.watchGroupGamificationProfile(currentGroupId);
          developer.log(
            'ゲーミフィケーションプロファイルの監視を開始: $currentGroupId',
            name: 'GroupInfoPage',
          );
        } catch (e) {
          developer.log('新しいグループの監視開始エラー: $e', name: 'GroupInfoPage', error: e);
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

      // ドリップパック記録の合計数を取得
      _dripPackTotalCount =
          await GroupDataSyncService.getGroupDripPackTotalCount(group.id);

      // 統計データの取得を確認
      developer.log('グループ統計データ取得完了', name: 'GroupInfoPage');
      developer.log('統計データ: $_groupStats', name: 'GroupInfoPage');
      developer.log('ドリップパック合計数: $_dripPackTotalCount', name: 'GroupInfoPage');

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
      developer.log('グループデータ読み込みエラー: $e', name: 'GroupInfoPage', error: e);
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

      developer.log('グループ更新開始', name: 'GroupInfoPage');
      developer.log('現在の名前: ${currentGroup.name}', name: 'GroupInfoPage');
      developer.log(
        '新しい名前: ${_nameController.text.trim()}',
        name: 'GroupInfoPage',
      );
      developer.log(
        '現在の説明: ${currentGroup.description}',
        name: 'GroupInfoPage',
      );
      developer.log(
        '新しい説明: ${_descriptionController.text.trim()}',
        name: 'GroupInfoPage',
      );

      final updatedGroup = currentGroup.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        updatedAt: DateTime.now(),
      );

      final success = await groupProvider.updateGroup(updatedGroup);

      developer.log('更新結果: $success', name: 'GroupInfoPage');

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
        developer.log('グループ更新完了', name: 'GroupInfoPage');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(groupProvider.error ?? '更新に失敗しました'),
            backgroundColor: Colors.red,
          ),
        );
        developer.log(
          'グループ更新失敗: ${groupProvider.error}',
          name: 'GroupInfoPage',
        );
      }
    } catch (e) {
      developer.log('グループ更新エラー: $e', name: 'GroupInfoPage', error: e);
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
      developer.log('設定更新開始', name: 'GroupInfoPage');
      developer.log('現在の設定: $_groupSettings', name: 'GroupInfoPage');
      developer.log('新しい設定: $newSettings', name: 'GroupInfoPage');
      developer.log(
        '新しい設定のdataPermissions: ${newSettings.dataPermissions}',
        name: 'GroupInfoPage',
      );

      if (_groupSettings != null) {
        developer.log(
          '現在のallowMemberInvite: ${_groupSettings!.allowMemberInvite}',
          name: 'GroupInfoPage',
        );
        developer.log(
          '新しいallowMemberInvite: ${newSettings.allowMemberInvite}',
          name: 'GroupInfoPage',
        );
        developer.log(
          '現在のallowMemberViewMembers: ${_groupSettings!.allowMemberViewMembers}',
          name: 'GroupInfoPage',
        );
        developer.log(
          '新しいallowMemberViewMembers: ${newSettings.allowMemberViewMembers}',
          name: 'GroupInfoPage',
        );
      }

      await GroupFirestoreService.updateGroupSettings(
        groupId: context.read<GroupProvider>().currentGroup!.id,
        settings: newSettings,
      );

      developer.log(
        'GroupFirestoreService: Firestore更新完了',
        name: 'GroupInfoPage',
      );

      if (mounted) {
        developer.log(
          'setState前の_groupSettings: $_groupSettings',
          name: 'GroupInfoPage',
        );
        setState(() {
          _groupSettings = newSettings;
        });
        developer.log(
          'setState後の_groupSettings: $_groupSettings',
          name: 'GroupInfoPage',
        );

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

        developer.log('ローカル状態更新完了', name: 'GroupInfoPage');
      }
    } catch (e) {
      developer.log('設定更新エラー: $e', name: 'GroupInfoPage', error: e);
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

    // 管理者は常に編集可能
    final memberRole = group.getMemberRole(user.uid);
    if (memberRole == GroupRole.admin) return true;

    // リーダーの場合は設定を確認
    if (memberRole == GroupRole.leader) {
      return _groupSettings?.allowLeaderManageGroup ?? false;
    }

    return false;
  }

  bool get _isUserAdmin {
    final user = FirebaseAuth.instance.currentUser;
    final groupProvider = context.read<GroupProvider>();
    final group = groupProvider.currentGroup;

    if (user == null || group == null) return false;
    final memberRole = group.getMemberRole(user.uid);
    return memberRole == GroupRole.admin;
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
      enableDrag: true,
      isDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) =>
            _buildSettingsBottomSheet(setModalState),
      ),
    );
  }

  Widget _buildSettingsBottomSheet([StateSetter? setModalState]) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: themeSettings.cardBackgroundColor,
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
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: 40, // 下部に余白を追加
              ),
              child: Column(
                children: [
                  _buildDataPermissionSettings(setModalState),
                  SizedBox(height: 20),
                  _buildMemberPermissionSettings(setModalState),
                  SizedBox(height: 20), // 最後に余白を追加
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
                    if (_isUserAdmin)
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
                color: themeSettings.appButtonColor,
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
            color: themeSettings.fontColor1.withValues(alpha: 0.5),
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
              color: themeSettings.fontColor1.withValues(alpha: 0.7),
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
    return Selector<GroupProvider, Group?>(
      selector: (context, groupProvider) => groupProvider.currentGroup,
      builder: (context, currentGroup, child) {
        // 最新のグループ情報を使用
        final groupToUse = currentGroup ?? group;
        // グループの監視を確実に開始
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final groupProvider = context.read<GroupProvider>();
          if (!groupProvider.isWatchingGroupData) {
            groupProvider.watchGroup(groupToUse.id);
          }
        });

        // プロフィールが読み込まれていない場合は読み込みを開始
        final groupProvider = context.read<GroupProvider>();
        final groupGamificationProfile = groupProvider
            .getGroupGamificationProfile(groupToUse.id);

        // プロフィールが存在しない場合は読み込みを開始
        if (groupGamificationProfile == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            groupProvider.loadGroupGamificationProfile(groupToUse.id);
            groupProvider.watchGroupGamificationProfile(groupToUse.id);
          });
        }

        final stats = groupGamificationProfile?.stats;
        final badgeCount = groupGamificationProfile?.badges.length ?? 0;
        final allBadgeCount =
            GroupBadgeConditions.conditions.length; // グループバッジの総数（動的）
        final currentLevel = groupGamificationProfile?.level ?? 1;
        final experiencePoints =
            groupGamificationProfile?.experiencePoints ?? 0;

        final memberCount = groupToUse.members.length;

        // デバッグ情報を出力
        developer.log('メンバー数: $memberCount', name: 'GroupInfoPage');
        developer.log(
          'メンバー一覧: ${groupToUse.members.map((m) => '${m.displayName}(${m.email})').join(', ')}',
          name: 'GroupInfoPage',
        );
        developer.log(
          'グループゲーミフィケーションプロファイル: $groupGamificationProfile',
          name: 'GroupInfoPage',
        );
        developer.log(
          'バッジ数: $badgeCount / $allBadgeCount',
          name: 'GroupInfoPage',
        );
        developer.log(
          '利用可能なバッジID: ${GroupBadgeConditions.conditions.map((c) => c.badgeId).toList()}',
          name: 'GroupInfoPage',
        );
        if (groupGamificationProfile?.badges.isNotEmpty == true) {
          developer.log(
            '獲得済みバッジ: ${groupGamificationProfile!.badges.map((b) => '${b.name}(${b.id})').join(', ')}',
            name: 'GroupInfoPage',
          );
        }

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
              color: themeSettings.cardBackgroundColor,
              shadowColor: themeSettings.buttonColor.withValues(alpha: 0.15),
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
                        SizedBox(height: 16),

                        // 現在のユーザーのプロフィール情報
                        _buildCurrentUserProfile(themeSettings, group),
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
                        _buildMembersSection(themeSettings, groupToUse),

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
                                ? Colors.white.withValues(alpha: 0.05)
                                : themeSettings.cardBackgroundColor.withValues(
                                    alpha: 0.1,
                                  ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: themeSettings.buttonColor.withValues(
                                alpha: 0.2,
                              ),
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
                                    '$_dripPackTotalCount個',
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

                        // レベルタイトル
                        GroupLevelDisplayWidget(
                          profile:
                              GroupGamificationProfile.initial(
                                _currentGroupId ?? 'group',
                              ).copyWith(
                                level: currentLevel,
                                experiencePoints: experiencePoints,
                                groupTitle: _getLevelTitle(currentLevel),
                              ),
                          showProgressBar: true,
                          showNextLevelInfo: true,
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
                                ? Colors.white.withValues(alpha: 0.05)
                                : themeSettings.cardBackgroundColor.withValues(
                                    alpha: 0.1,
                                  ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: themeSettings.buttonColor.withValues(
                                alpha: 0.2,
                              ),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              // ヘッダー部分
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
                                          .withValues(alpha: 0.7),
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
                                    .withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  themeSettings.buttonColor,
                                ),
                              ),
                              SizedBox(height: 16),

                              // 詳細なバッジ一覧
                              Column(
                                children: GroupBadgeConditions.conditions.map((
                                  condition,
                                ) {
                                  final isEarned =
                                      groupGamificationProfile?.badges.any(
                                        (b) => b.id == condition.badgeId,
                                      ) ??
                                      false;

                                  // デバッグ情報
                                  if (condition.badgeId ==
                                      'group_attendance_10') {
                                    developer.log(
                                      'バッジチェック - ${condition.name}: $isEarned',
                                      name: 'GroupInfoPage',
                                    );
                                    developer.log(
                                      '全バッジID: ${groupGamificationProfile?.badges.map((b) => b.id).toList()}',
                                      name: 'GroupInfoPage',
                                    );
                                  }
                                  final earnedBadge = groupGamificationProfile
                                      ?.badges
                                      .firstWhere(
                                        (b) => b.id == condition.badgeId,
                                        orElse: () => GroupBadge(
                                          id: condition.badgeId,
                                          name: condition.name,
                                          description: condition.description,
                                          iconCodePoint:
                                              condition.iconCodePoint,
                                          color: condition.color,
                                          earnedAt: DateTime.now(),
                                          earnedByUserId: '',
                                          earnedByUserName: '',
                                          category: BadgeCategory.special,
                                        ),
                                      );

                                  return Container(
                                    margin: EdgeInsets.only(bottom: 12),
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isEarned
                                          ? condition.color.withValues(
                                              alpha: 0.1,
                                            )
                                          : themeSettings.fontColor1.withValues(
                                              alpha: 0.05,
                                            ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isEarned
                                            ? condition.color.withValues(
                                                alpha: 0.3,
                                              )
                                            : themeSettings.fontColor1
                                                  .withValues(alpha: 0.1),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // バッジアイコン
                                        Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isEarned
                                                ? condition.color.withValues(
                                                    alpha: 0.2,
                                                  )
                                                : themeSettings.fontColor1
                                                      .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.star, // デフォルトアイコンを使用
                                            color: isEarned
                                                ? condition.color
                                                : themeSettings.fontColor1
                                                      .withValues(alpha: 0.3),
                                            size: 24,
                                          ),
                                        ),
                                        SizedBox(width: 12),

                                        // バッジ情報
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                condition.name,
                                                style: TextStyle(
                                                  fontSize:
                                                      16 *
                                                      themeSettings
                                                          .fontSizeScale,
                                                  fontWeight: FontWeight.bold,
                                                  color: isEarned
                                                      ? condition.color
                                                      : themeSettings
                                                            .fontColor1,
                                                  fontFamily:
                                                      themeSettings.fontFamily,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              // レベル系バッジ以外の場合のみ説明文を表示
                                              if (condition.category !=
                                                  BadgeCategory.level) ...[
                                                Text(
                                                  condition.description,
                                                  style: TextStyle(
                                                    fontSize:
                                                        14 *
                                                        themeSettings
                                                            .fontSizeScale,
                                                    color: themeSettings
                                                        .fontColor1
                                                        .withValues(alpha: 0.7),
                                                    fontFamily: themeSettings
                                                        .fontFamily,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                              // レベル系バッジの場合、達成条件を表示
                                              if (condition.category ==
                                                  BadgeCategory.level) ...[
                                                SizedBox(height: 4),
                                                Builder(
                                                  builder: (context) {
                                                    final requirement =
                                                        _getLevelRequirement(
                                                          condition.badgeId,
                                                        );
                                                    final requiredLevel =
                                                        _getRequiredLevel(
                                                          condition.badgeId,
                                                        );
                                                    final isAchievable =
                                                        currentLevel >=
                                                        requiredLevel;

                                                    return Text(
                                                      '$requirement${!isEarned && isAchievable ? ' ✓' : ''}',
                                                      style: TextStyle(
                                                        fontSize:
                                                            14 *
                                                            themeSettings
                                                                .fontSizeScale,
                                                        color: isEarned
                                                            ? condition.color
                                                                  .withValues(
                                                                    alpha: 0.8,
                                                                  )
                                                            : isAchievable
                                                            ? Colors.green
                                                                  .withValues(
                                                                    alpha: 0.8,
                                                                  )
                                                            : themeSettings
                                                                  .fontColor1
                                                                  .withValues(
                                                                    alpha: 0.7,
                                                                  ),
                                                        fontFamily:
                                                            themeSettings
                                                                .fontFamily,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ],
                                              if (isEarned &&
                                                  earnedBadge?.earnedAt !=
                                                      null) ...[
                                                SizedBox(height: 4),
                                                Text(
                                                  '獲得日: ${DateFormat('yyyy/MM/dd').format(earnedBadge?.earnedAt ?? DateTime.now())}',
                                                  style: TextStyle(
                                                    fontSize:
                                                        12 *
                                                        themeSettings
                                                            .fontSizeScale,
                                                    color: condition.color
                                                        .withValues(alpha: 0.8),
                                                    fontFamily: themeSettings
                                                        .fontFamily,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),

                                        // 獲得状況アイコン
                                        Icon(
                                          isEarned
                                              ? Icons.check_circle
                                              : Icons.radio_button_unchecked,
                                          color: isEarned
                                              ? condition.color
                                              : themeSettings.fontColor1
                                                    .withValues(alpha: 0.3),
                                          size: 24,
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),

                        // グループ脱退ボタン（リーダー以外のメンバーのみ表示）
                        if (!_isUserLeader) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: Icon(
                                Icons.exit_to_app,
                                color: Colors.white,
                              ),
                              label: Text(
                                'グループから脱退',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16 * themeSettings.fontSizeScale,
                                  fontFamily: themeSettings.fontFamily,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 3,
                              ),
                              onPressed: () => _leaveGroup(group),
                            ),
                          ),
                          SizedBox(height: 16),
                        ],
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

  /// レベル系バッジの達成条件を取得
  String _getLevelRequirement(String badgeId) {
    // バッジIDからレベルを抽出
    final levelMatch = RegExp(r'group_level_(\d+)').firstMatch(badgeId);
    if (levelMatch != null) {
      final level = int.parse(levelMatch.group(1)!);
      return 'グループレベル $level に到達';
    }
    return 'レベル達成';
  }

  /// レベル系バッジの必要レベルを取得
  int _getRequiredLevel(String badgeId) {
    // バッジIDからレベルを抽出
    final levelMatch = RegExp(r'group_level_(\d+)').firstMatch(badgeId);
    if (levelMatch != null) {
      return int.parse(levelMatch.group(1)!);
    }
    return 0;
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
                ? Colors.white.withValues(alpha: 0.8)
                : themeSettings.fontColor1.withValues(alpha: 0.6),
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

  Widget _buildDataPermissionSettings([StateSetter? setModalState]) {
    developer.log('_buildDataPermissionSettings開始', name: 'GroupInfoPage');
    developer.log('現在の_groupSettings: $_groupSettings', name: 'GroupInfoPage');
    if (_groupSettings != null) {
      developer.log(
        '現在のdataPermissions: ${_groupSettings!.dataPermissions}',
        name: 'GroupInfoPage',
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
            developer.log('焙煎記録入力権限変更 - 新しい権限: $level', name: 'GroupInfoPage');
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
            developer.log(
              'setState完了 - 新しい設定: ${_groupSettings!.dataPermissions}',
              name: 'GroupInfoPage',
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
            developer.log('焙煎記録一覧権限変更 - 新しい権限: $level', name: 'GroupInfoPage');
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
            developer.log(
              'setState完了 - 新しい設定: ${_groupSettings!.dataPermissions}',
              name: 'GroupInfoPage',
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
            developer.log('担当表権限変更 - 新しいレベル: $level', name: 'GroupInfoPage');
            developer.log(
              '変更前の設定: ${_groupSettings!.dataPermissions}',
              name: 'GroupInfoPage',
            );

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

            developer.log(
              '変更後の設定: ${_groupSettings!.dataPermissions}',
              name: 'GroupInfoPage',
            );
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
    developer.log('$dataType の現在の権限: $currentLevel', name: 'GroupInfoPage');

    final themeSettings = Provider.of<ThemeSettings>(context);
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeSettings.cardBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: themeSettings.fontColor1.withValues(alpha: 0.1),
        ),
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
                        color: themeSettings.fontColor1.withValues(alpha: 0.7),
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
                  color: _getAccessLevelColor(
                    currentLevel,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _getAccessLevelColor(
                      currentLevel,
                    ).withValues(alpha: 0.3),
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
                  onTap: () => onChanged(AccessLevel.adminOnly),
                  child: Container(
                    margin: EdgeInsets.only(right: 8),
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color:
                          _isLevelSelected(currentLevel, AccessLevel.adminOnly)
                          ? _getAccessLevelColor(AccessLevel.adminOnly)
                          : themeSettings.fontColor1.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            _isLevelSelected(
                              currentLevel,
                              AccessLevel.adminOnly,
                            )
                            ? _getAccessLevelColor(AccessLevel.adminOnly)
                            : themeSettings.fontColor1.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      '管理者',
                      style: TextStyle(
                        fontSize: 12 * themeSettings.fontSizeScale,
                        color:
                            _isLevelSelected(
                              currentLevel,
                              AccessLevel.adminOnly,
                            )
                            ? Colors.white
                            : themeSettings.fontColor1,
                        fontWeight:
                            _isLevelSelected(
                              currentLevel,
                              AccessLevel.adminOnly,
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
                  onTap: () => onChanged(AccessLevel.adminLeader),
                  child: Container(
                    margin: EdgeInsets.only(right: 8),
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color:
                          _isLevelSelected(
                            currentLevel,
                            AccessLevel.adminLeader,
                          )
                          ? _getAccessLevelColor(AccessLevel.adminLeader)
                          : themeSettings.fontColor1.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            _isLevelSelected(
                              currentLevel,
                              AccessLevel.adminLeader,
                            )
                            ? _getAccessLevelColor(AccessLevel.adminLeader)
                            : themeSettings.fontColor1.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      'リーダー',
                      style: TextStyle(
                        fontSize: 12 * themeSettings.fontSizeScale,
                        color:
                            _isLevelSelected(
                              currentLevel,
                              AccessLevel.adminLeader,
                            )
                            ? Colors.white
                            : themeSettings.fontColor1,
                        fontWeight:
                            _isLevelSelected(
                              currentLevel,
                              AccessLevel.adminLeader,
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
                  onTap: () => onChanged(AccessLevel.allMembers),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color:
                          _isLevelSelected(currentLevel, AccessLevel.allMembers)
                          ? _getAccessLevelColor(AccessLevel.allMembers)
                          : themeSettings.fontColor1.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            _isLevelSelected(
                              currentLevel,
                              AccessLevel.allMembers,
                            )
                            ? _getAccessLevelColor(AccessLevel.allMembers)
                            : themeSettings.fontColor1.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      'メンバー',
                      style: TextStyle(
                        fontSize: 12 * themeSettings.fontSizeScale,
                        color:
                            _isLevelSelected(
                              currentLevel,
                              AccessLevel.allMembers,
                            )
                            ? Colors.white
                            : themeSettings.fontColor1,
                        fontWeight:
                            _isLevelSelected(
                              currentLevel,
                              AccessLevel.allMembers,
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
      case AccessLevel.adminOnly:
        return Colors.red;
      case AccessLevel.adminLeader:
        return Colors.orange;
      case AccessLevel.allMembers:
        return Colors.blue;
    }
  }

  String _getAccessLevelDisplayName(AccessLevel level) {
    switch (level) {
      case AccessLevel.adminOnly:
        return '管理者のみ';
      case AccessLevel.adminLeader:
        return '管理者とリーダー';
      case AccessLevel.allMembers:
        return '全メンバー';
    }
  }

  /// 階層的な選択状態を判定する
  /// 管理者をタップ: 管理者のみ選択
  /// リーダーをタップ: 管理者とリーダーが選択
  /// メンバーをタップ: 管理者とリーダーとメンバーが選択
  bool _isLevelSelected(AccessLevel currentLevel, AccessLevel buttonLevel) {
    switch (buttonLevel) {
      case AccessLevel.adminOnly:
        // 管理者ボタンは、現在の権限が管理者のみ、管理者・リーダー、全メンバーの場合に選択
        return currentLevel == AccessLevel.adminOnly ||
            currentLevel == AccessLevel.adminLeader ||
            currentLevel == AccessLevel.allMembers;
      case AccessLevel.adminLeader:
        // リーダーボタンは、現在の権限が管理者・リーダーまたは全メンバーの場合に選択
        return currentLevel == AccessLevel.adminLeader ||
            currentLevel == AccessLevel.allMembers;
      case AccessLevel.allMembers:
        // メンバーボタンは、現在の権限が全メンバーの場合のみ選択
        return currentLevel == AccessLevel.allMembers;
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
            developer.log(
              'メンバーが招待できる onChanged: $value',
              name: 'GroupInfoPage',
            );
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
            developer.log(
              'メンバーがメンバー一覧を見れる onChanged: $value',
              name: 'GroupInfoPage',
            );
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
        SizedBox(height: 16),
        _buildPermissionSwitch(
          title: 'リーダーがグループ管理できる',
          description: 'リーダーが権限設定・グループ名変更・グループ削除を実行できる',
          value: _groupSettings!.allowLeaderManageGroup,
          onChanged: (value) {
            developer.log(
              'リーダーがグループ管理できる onChanged: $value',
              name: 'GroupInfoPage',
            );
            if (setModalState != null) {
              setModalState(() {
                _groupSettings = _groupSettings!.copyWith(
                  allowLeaderManageGroup: value,
                );
              });
            } else {
              setState(() {
                _groupSettings = _groupSettings!.copyWith(
                  allowLeaderManageGroup: value,
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
        developer.log('GestureDetector tapped: $title', name: 'GroupInfoPage');
        developer.log('Current value: $value', name: 'GroupInfoPage');
        developer.log('Toggling to: ${!value}', name: 'GroupInfoPage');
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
                    color: themeSettings.fontColor1.withValues(alpha: 0.7),
                    fontFamily: themeSettings.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (newValue) {
              developer.log(
                'Switch onChanged called: $title',
                name: 'GroupInfoPage',
              );
              developer.log('Current value: $value', name: 'GroupInfoPage');
              developer.log('New value: $newValue', name: 'GroupInfoPage');
              onChanged(newValue);
            },
            activeThumbColor: themeSettings.buttonColor,
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
            color: themeSettings.fontColor1.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: themeSettings.fontColor1.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lock,
                color: themeSettings.fontColor1.withValues(alpha: 0.5),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'メンバー一覧の表示権限がありません',
                style: TextStyle(
                  color: themeSettings.fontColor1.withValues(alpha: 0.7),
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

          // プロフィール画像の取得
          String? profileImageUrl;

          // メンバーのphotoUrlを確認
          if (member.photoUrl != null && member.photoUrl!.isNotEmpty) {
            profileImageUrl = member.photoUrl;
          }
          // 現在のユーザーの場合はFirebase Authから取得
          else if (member.uid == user?.uid &&
              user?.photoURL != null &&
              user!.photoURL!.isNotEmpty) {
            profileImageUrl = user.photoURL;
          }
          // 他のメンバーの場合は、photoUrlが保存されていない場合はデフォルトアイコンを使用
          // Googleプロフィール画像のURLは動的に生成できないため、保存されたphotoUrlのみを使用

          // デバッグログを追加
          developer.log(
            'プロフィール画像デバッグ - メンバー: ${member.displayName}(${member.email})',
            name: 'GroupInfoPage',
          );
          developer.log(
            '  - member.photoUrl: ${member.photoUrl}',
            name: 'GroupInfoPage',
          );
          developer.log(
            '  - user?.photoURL: ${user?.photoURL}',
            name: 'GroupInfoPage',
          );
          developer.log(
            '  - 最終的なprofileImageUrl: $profileImageUrl',
            name: 'GroupInfoPage',
          );

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
                    backgroundColor: roleColor.withValues(alpha: 0.1),
                    child: profileImageUrl != null
                        ? ClipOval(
                            child: Image.network(
                              profileImageUrl,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                // 画像読み込みエラー時はデフォルトアイコンを表示
                                return Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: roleColor.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      member.displayName.isNotEmpty
                                          ? member.displayName[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: roleColor,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : Text(
                            member.displayName.isNotEmpty
                                ? member.displayName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: roleColor,
                            ),
                          ),
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
              color: themeSettings.fontColor1.withValues(alpha: 0.6),
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

    // プロフィール画像の取得
    String? profileImageUrl;

    // メンバーのphotoUrlを確認
    if (member.photoUrl != null && member.photoUrl!.isNotEmpty) {
      profileImageUrl = member.photoUrl;
    }
    // 現在のユーザーの場合はFirebase Authから取得
    else if (member.uid == user?.uid &&
        user?.photoURL != null &&
        user!.photoURL!.isNotEmpty) {
      profileImageUrl = user.photoURL;
    }
    // 他のメンバーの場合、Googleプロフィール画像のURLを推測
    else if (member.email.contains('@gmail.com') ||
        member.email.contains('@googlemail.com')) {
      // Gmailアカウントの場合、Googleプロフィール画像のURLを構築
      final emailHash = member.email.toLowerCase().trim();
      // 複数のプロフィール画像ソースを試す
      final gravatarUrl =
          'https://www.gravatar.com/avatar/${emailHash.hashCode.toRadixString(16)}?d=404&s=200';
      final googleUrl =
          'https://lh3.googleusercontent.com/-${emailHash.hashCode.toRadixString(16)}/photo?sz=200';
      profileImageUrl = gravatarUrl; // まずGravatarを試す
    }
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 500, // Web版での最大幅を制限
            ),
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 8,
              backgroundColor: Provider.of<ThemeSettings>(
                context,
              ).dialogBackgroundColor,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 上部に大きなアイコンと名前
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: roleColor.withValues(alpha: 0.12),
                      child: profileImageUrl != null
                          ? ClipOval(
                              child: Image.network(
                                profileImageUrl,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  // 画像読み込みエラー時、Gmailアカウントの場合はGoogleプロフィール画像を試す
                                  if (member.email.contains('@gmail.com') ||
                                      member.email.contains(
                                        '@googlemail.com',
                                      )) {
                                    final emailHash = member.email
                                        .toLowerCase()
                                        .trim();
                                    final googleUrl =
                                        'https://lh3.googleusercontent.com/-${emailHash.hashCode.toRadixString(16)}/photo?sz=200';
                                    return ClipOval(
                                      child: Image.network(
                                        googleUrl,
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error2, stackTrace2) {
                                              // Googleプロフィール画像も失敗した場合はデフォルトアイコンを表示
                                              return Container(
                                                width: 64,
                                                height: 64,
                                                decoration: BoxDecoration(
                                                  color: roleColor.withValues(
                                                    alpha: 0.12,
                                                  ),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    member
                                                            .displayName
                                                            .isNotEmpty
                                                        ? member.displayName[0]
                                                              .toUpperCase()
                                                        : '?',
                                                    style: TextStyle(
                                                      fontSize: 28,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: roleColor,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                      ),
                                    );
                                  }
                                  // Gmailアカウントでない場合はデフォルトアイコンを表示
                                  return Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: roleColor.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        member.displayName.isNotEmpty
                                            ? member.displayName[0]
                                                  .toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: roleColor,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          : Text(
                              member.displayName.isNotEmpty
                                  ? member.displayName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: roleColor,
                              ),
                            ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      member.displayName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Provider.of<ThemeSettings>(
                          context,
                        ).dialogTextColor,
                      ),
                    ),
                    SizedBox(height: 8),
                    // 役割バッジ
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.15),
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
                      style: TextStyle(
                        fontSize: 13,
                        color: Provider.of<ThemeSettings>(
                          context,
                        ).dialogTextColor.withValues(alpha: 0.7),
                      ),
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
                    if (isCurrentUserAdmin &&
                        (!isTargetLeader || !isTargetMember))
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
                    // 脱退させるボタン（管理者のみ表示、自分以外のメンバーに対して）
                    if (isCurrentUserAdmin && member.uid != user.uid)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _roleActionButton(
                              icon: Icons.person_remove,
                              label: '脱退させる',
                              color: Colors.red,
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await _removeMember(member, group);
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
                          color: Provider.of<ThemeSettings>(
                            context,
                          ).dialogTextColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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

  Future<void> _removeMember(GroupMember member, Group group) async {
    final provider = context.read<GroupProvider>();

    // 確認ダイアログを表示
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('メンバーを脱退させますか？'),
        content: Text(
          '${member.displayName}さんをグループから脱退させます。\nこの操作は取り消すことができません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('脱退させる'),
          ),
        ],
      ),
    );

    // キャンセルされた場合は処理を中断
    if (confirmed != true) return;
    try {
      await provider.removeMember(groupId: group.id, memberUid: member.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${member.displayName}さんをグループから脱退させました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('メンバーの脱退処理に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// グループから脱退
  Future<void> _leaveGroup(Group group) async {
    final provider = context.read<GroupProvider>();

    // 確認ダイアログを表示
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('グループから脱退しますか？'),
        content: Text('このグループから脱退します。\nこの操作は取り消すことができません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('脱退する'),
          ),
        ],
      ),
    );

    // キャンセルされた場合は処理を中断
    if (confirmed != true) return;
    try {
      await provider.leaveGroup(group.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('グループから脱退しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('グループ脱退に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
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
              color: themeSettings.fontColor1.withValues(alpha: 0.7),
              fontFamily: themeSettings.fontFamily,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  /// 現在のユーザーのプロフィール情報を表示
  Widget _buildCurrentUserProfile(ThemeSettings themeSettings, Group group) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return SizedBox.shrink();

    // 現在のユーザーのメンバー情報を取得
    final currentMember = group.members.firstWhere(
      (member) => member.uid == user.uid,
      orElse: () => GroupMember(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? 'Unknown User',
        photoUrl: user.photoURL,
        role: GroupRole.member,
        joinedAt: DateTime.now(),
      ),
    );

    final role = group.getMemberRole(currentMember.uid);
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

    // プロフィール画像の取得
    String? profileImageUrl;

    // メンバーのphotoUrlを確認
    if (currentMember.photoUrl != null && currentMember.photoUrl!.isNotEmpty) {
      profileImageUrl = currentMember.photoUrl;
    }
    // Firebase Authから取得
    else if (user.photoURL != null && user.photoURL!.isNotEmpty) {
      profileImageUrl = user.photoURL;
    }
    // Gmailアカウントの場合、Googleプロフィール画像のURLを推測
    else if (currentMember.email.contains('@gmail.com') ||
        currentMember.email.contains('@googlemail.com')) {
      final emailHash = currentMember.email.toLowerCase().trim();
      // 複数のプロフィール画像ソースを試す
      final gravatarUrl =
          'https://www.gravatar.com/avatar/${emailHash.hashCode.toRadixString(16)}?d=404&s=200';
      final googleUrl =
          'https://lh3.googleusercontent.com/-${emailHash.hashCode.toRadixString(16)}/photo?sz=200';
      profileImageUrl = gravatarUrl; // まずGravatarを試す
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeSettings.cardBackgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: themeSettings.iconColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // プロフィール画像
          CircleAvatar(
            radius: 24,
            backgroundColor: roleColor.withValues(alpha: 0.1),
            child: profileImageUrl != null
                ? ClipOval(
                    child: Image.network(
                      profileImageUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // 画像読み込みエラー時、Gmailアカウントの場合はGoogleプロフィール画像を試す
                        if (currentMember.email.contains('@gmail.com') ||
                            currentMember.email.contains('@googlemail.com')) {
                          final emailHash = currentMember.email
                              .toLowerCase()
                              .trim();
                          final googleUrl =
                              'https://lh3.googleusercontent.com/-${emailHash.hashCode.toRadixString(16)}/photo?sz=200';
                          return ClipOval(
                            child: Image.network(
                              googleUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error2, stackTrace2) {
                                // Googleプロフィール画像も失敗した場合はデフォルトアイコンを表示
                                return Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: roleColor.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      currentMember.displayName.isNotEmpty
                                          ? currentMember.displayName[0]
                                                .toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: roleColor,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        }
                        // Gmailアカウントでない場合はデフォルトアイコンを表示
                        return Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              currentMember.displayName.isNotEmpty
                                  ? currentMember.displayName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: roleColor,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Text(
                    currentMember.displayName.isNotEmpty
                        ? currentMember.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: roleColor,
                    ),
                  ),
          ),
          SizedBox(width: 12),
          // ユーザー情報
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentMember.displayName,
                  style: TextStyle(
                    fontSize: 16 * themeSettings.fontSizeScale,
                    fontWeight: FontWeight.bold,
                    color: themeSettings.fontColor1,
                    fontFamily: themeSettings.fontFamily,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(roleIcon, color: roleColor, size: 14),
                    SizedBox(width: 4),
                    Text(
                      roleText,
                      style: TextStyle(
                        fontSize: 12 * themeSettings.fontSizeScale,
                        color: roleColor,
                        fontWeight: FontWeight.bold,
                        fontFamily: themeSettings.fontFamily,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
                color: themeSettings.fontColor1.withValues(alpha: 0.5),
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
                color: themeSettings.fontColor1.withValues(alpha: 0.5),
                fontFamily: themeSettings.fontFamily,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: themeSettings.fontColor1.withValues(alpha: 0.3),
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
