import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../models/theme_settings.dart';
import '../../models/group_gamification_provider.dart';
import '../../models/group_gamification_models.dart';
import '../../services/group_gamification_service.dart';
import '../../services/group_data_sync_service.dart';
import '../gamification/badge_list_page.dart';
import 'group_member_invite_page.dart';
import 'group_settings_page.dart';
import 'group_edit_page.dart';
import 'group_leave_complete_page.dart';
import 'group_list_page.dart';
import 'group_delete_complete_page.dart';
import '../../widgets/group_level_display_widget.dart';

class GroupDetailPage extends StatefulWidget {
  final Group group;

  const GroupDetailPage({required this.group, super.key});

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupProvider = context.read<GroupProvider>();
      groupProvider.watchGroup(widget.group.id);
      groupProvider.watchGroupGamificationProfile(widget.group.id);
    });
  }

  @override
  void dispose() {
    final groupProvider = context.read<GroupProvider>();
    groupProvider.unwatchGroup(widget.group.id);
    groupProvider.unwatchGroupGamificationProfile(widget.group.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    final groupProvider = context.watch<GroupProvider>();
    final currentGroup =
        groupProvider.getGroupById(widget.group.id) ?? widget.group;
    final isLeader = groupProvider.isCurrentUserLeader(widget.group.id);
    final isAdmin = currentGroup.members.any(
      (m) => m.uid == currentUser?.uid && m.role == GroupRole.admin,
    );

    return Scaffold(
      appBar: AppBar(
        title: Consumer<GroupProvider>(
          builder: (context, groupProvider, child) {
            final currentGroup =
                groupProvider.getGroupById(widget.group.id) ?? widget.group;
            return Text(
              currentGroup.name,
              style: TextStyle(
                color: themeSettings.appBarTextColor,
                fontSize: 20 * themeSettings.fontSizeScale,
                fontWeight: FontWeight.bold,
                fontFamily: themeSettings.fontFamily,
              ),
            );
          },
        ),
        backgroundColor: themeSettings.appBarColor,
        iconTheme: IconThemeData(color: themeSettings.iconColor),
        actions: [],
      ),
      body: Consumer<GroupProvider>(
        builder: (context, groupProvider, child) {
          if (groupProvider.loading) {
            return Center(
              child: CircularProgressIndicator(color: themeSettings.iconColor),
            );
          }

          return RefreshIndicator(
            onRefresh: () => groupProvider.refresh(),
            child: CustomScrollView(
              slivers: [
                // メンバー一覧
                SliverToBoxAdapter(
                  child: Card(
                    margin: EdgeInsets.all(12),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: themeSettings.backgroundColor2 ?? Colors.white,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    color: themeSettings.iconColor,
                                    size: 24,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'メンバー',
                                    style: TextStyle(
                                      color: themeSettings.fontColor1,
                                      fontSize:
                                          18 * themeSettings.fontSizeScale,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: themeSettings.fontFamily,
                                    ),
                                  ),
                                ],
                              ),
                              if (isLeader)
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            GroupMemberInvitePage(
                                              group: widget.group,
                                            ),
                                      ),
                                    );
                                  },
                                  icon: Icon(
                                    Icons.person_add,
                                    color: themeSettings.buttonColor,
                                  ),
                                  label: Text(
                                    '招待',
                                    style: TextStyle(
                                      color: themeSettings.buttonColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 16),
                          ...currentGroup.members.map((member) {
                            final isCurrentUser =
                                currentUser?.uid == member.uid;
                            final canManage = isLeader && !isCurrentUser;

                            return ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 0,
                                vertical: 4,
                              ),
                              leading: CircleAvatar(
                                backgroundColor:
                                    member.role == GroupRole.leader ||
                                        member.role == GroupRole.admin
                                    ? Colors.orange
                                    : themeSettings.iconColor,
                                child: member.photoUrl != null
                                    ? ClipOval(
                                        child: Image.network(
                                          member.photoUrl!,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Icon(
                                                  member.role ==
                                                              GroupRole
                                                                  .leader ||
                                                          member.role ==
                                                              GroupRole.admin
                                                      ? Icons.star
                                                      : Icons.person,
                                                  color: Colors.white,
                                                );
                                              },
                                        ),
                                      )
                                    : Icon(
                                        member.role == GroupRole.leader ||
                                                member.role == GroupRole.admin
                                            ? Icons.star
                                            : Icons.person,
                                        color: Colors.white,
                                      ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    member.displayName,
                                    style: TextStyle(
                                      color: themeSettings.fontColor1,
                                      fontSize:
                                          16 * themeSettings.fontSizeScale,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: themeSettings.fontFamily,
                                    ),
                                  ),
                                  if (isCurrentUser)
                                    Container(
                                      margin: EdgeInsets.only(left: 8),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: themeSettings.buttonColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'あなた',
                                        style: TextStyle(
                                          color: themeSettings.fontColor2,
                                          fontSize:
                                              10 * themeSettings.fontSizeScale,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: themeSettings.fontFamily,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member.role == GroupRole.admin
                                        ? '管理者'
                                        : member.role == GroupRole.leader
                                        ? 'リーダー'
                                        : 'メンバー',
                                    style: TextStyle(
                                      color: member.role == GroupRole.admin
                                          ? Colors.red
                                          : member.role == GroupRole.leader
                                          ? Colors.orange
                                          : themeSettings.fontColor1,
                                      fontSize:
                                          12 * themeSettings.fontSizeScale,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: themeSettings.fontFamily,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: canManage
                                  ? PopupMenuButton<String>(
                                      icon: Icon(
                                        Icons.more_vert,
                                        color: themeSettings.iconColor,
                                      ),
                                      onSelected: (value) async {
                                        switch (value) {
                                          case 'promote':
                                            await _promoteMember(member);
                                            break;
                                          case 'demote':
                                            await _demoteMember(member);
                                            break;
                                          case 'remove':
                                            await _removeMember(member);
                                            break;
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        if (member.role == GroupRole.member)
                                          PopupMenuItem(
                                            value: 'promote',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.star,
                                                  color: Colors.orange,
                                                ),
                                                SizedBox(width: 8),
                                                Text('リーダーに昇格'),
                                              ],
                                            ),
                                          ),
                                        if (member.role == GroupRole.leader)
                                          PopupMenuItem(
                                            value: 'demote',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.person,
                                                  color:
                                                      themeSettings.iconColor,
                                                ),
                                                SizedBox(width: 8),
                                                Text('メンバーに降格'),
                                              ],
                                            ),
                                          ),
                                        PopupMenuItem(
                                          value: 'remove',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.remove_circle,
                                                color: Colors.red,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                '削除',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : null,
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),

                // グループレベル表示
                SliverToBoxAdapter(
                  child: Consumer<GroupProvider>(
                    builder: (context, groupProvider, child) {
                      final gamificationProfile = groupProvider.getGroupGamificationProfile(widget.group.id);
                      if (gamificationProfile == null) {
                        return Card(
                          margin: EdgeInsets.all(12),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          color: themeSettings.backgroundColor2 ?? Colors.white,
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: themeSettings.iconColor,
                              ),
                            ),
                          ),
                        );
                      }

                      return GroupLevelDisplayWidget(
                        profile: gamificationProfile,
                        width: double.infinity,
                      );
                    },
                  ),
                ),

                // グループ設定ボタン（リーダーのみ）
                if (isLeader)
                  SliverToBoxAdapter(
                    child: Card(
                      margin: EdgeInsets.all(12),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: themeSettings.backgroundColor2 ?? Colors.white,
                      child: ListTile(
                        leading: Icon(
                          Icons.settings,
                          color: themeSettings.iconColor,
                          size: 24,
                        ),
                        title: Text(
                          'データ権限設定',
                          style: TextStyle(
                            color: themeSettings.fontColor1,
                            fontSize: 16 * themeSettings.fontSizeScale,
                            fontWeight: FontWeight.bold,
                            fontFamily: themeSettings.fontFamily,
                          ),
                        ),
                        subtitle: Text(
                          'データ権限やメンバー権限を管理',
                          style: TextStyle(
                            color: themeSettings.fontColor1,
                            fontSize: 12 * themeSettings.fontSizeScale,
                            fontFamily: themeSettings.fontFamily,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          color: themeSettings.iconColor,
                          size: 16,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  GroupSettingsPage(group: widget.group),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // グループ設定ボタン（リーダーのみ）
                if (isLeader)
                  SliverToBoxAdapter(
                    child: Card(
                      margin: EdgeInsets.all(12),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: themeSettings.backgroundColor2 ?? Colors.white,
                      child: ListTile(
                        leading: _getGroupIcon(widget.group.iconName),
                        title: Text(
                          'グループ設定',
                          style: TextStyle(
                            color: themeSettings.fontColor1,
                            fontSize: 16 * themeSettings.fontSizeScale,
                            fontWeight: FontWeight.bold,
                            fontFamily: themeSettings.fontFamily,
                          ),
                        ),
                        subtitle: Text(
                          'グループ名や説明を編集',
                          style: TextStyle(
                            color: themeSettings.fontColor1,
                            fontSize: 12 * themeSettings.fontSizeScale,
                            fontFamily: themeSettings.fontFamily,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          color: themeSettings.iconColor,
                          size: 16,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  GroupEditPage(group: widget.group),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // グループレベルバッジ表示
                SliverToBoxAdapter(
                  child: Consumer<GroupProvider>(
                    builder: (context, groupProvider, child) {
                      final gamificationProfile = groupProvider.getGroupGamificationProfile(widget.group.id);
                      if (gamificationProfile == null) {
                        return SizedBox.shrink();
                      }

                      final levelBadges = gamificationProfile.badges
                          .where((badge) => badge.category == BadgeCategory.level)
                          .toList();

                      return GroupLevelBadgeWidget(
                        levelBadges: levelBadges,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BadgeListPage(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // バッジセクション
                SliverToBoxAdapter(
                  child: _buildBadgeSection(context, themeSettings),
                ),

                // データ同期セクション
                SliverToBoxAdapter(
                  child: Card(
                    margin: EdgeInsets.all(12),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: themeSettings.backgroundColor2 ?? Colors.white,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.sync,
                                color: themeSettings.iconColor,
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'データ同期',
                                style: TextStyle(
                                  color: themeSettings.fontColor1,
                                  fontSize: 18 * themeSettings.fontSizeScale,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: themeSettings.fontFamily,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'グループメンバー間でデータを同期します\n自分のデータをアップロードし、グループのデータをダウンロードします',
                            style: TextStyle(
                              color: themeSettings.fontColor1,
                              fontSize: 14 * themeSettings.fontSizeScale,
                              fontFamily: themeSettings.fontFamily,
                            ),
                          ),
                          SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.sync, color: Colors.blue, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'データは自動で同期されます',
                                    style: TextStyle(
                                      color: Colors.blue[800],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
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
                // グループアイコン説明カード
                SliverToBoxAdapter(
                  child: Card(
                    margin: EdgeInsets.all(12),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: themeSettings.backgroundColor2 ?? Colors.white,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.lightBlueAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.groups,
                              color: Colors.lightBlue,
                              size: 36,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'グループアイコンについて',
                                  style: TextStyle(
                                    color: themeSettings.fontColor1,
                                    fontSize: 16 * themeSettings.fontSizeScale,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: themeSettings.fontFamily,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'このグループアイコンは、表示されているページでグループのデータがメンバーと共有されていることを示します。個人利用時は表示されません。',
                                  style: TextStyle(
                                    color: themeSettings.fontColor1,
                                    fontSize: 14 * themeSettings.fontSizeScale,
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

                // 脱退ボタン
                if (!isLeader || isAdmin)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: ElevatedButton(
                        onPressed: () => _showLeaveDialog(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'グループから脱退',
                          style: TextStyle(
                            fontSize: 16 * themeSettings.fontSizeScale,
                            fontWeight: FontWeight.bold,
                            fontFamily: themeSettings.fontFamily,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showEditDialog() async {
    final themeSettings = Provider.of<ThemeSettings>(context, listen: false);
    final nameController = TextEditingController(text: widget.group.name);
    final descriptionController = TextEditingController(
      text: widget.group.description,
    );

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'グループを編集',
          style: TextStyle(
            color: themeSettings.fontColor1,
            fontFamily: themeSettings.fontFamily,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'グループ名',
                labelStyle: TextStyle(
                  color: themeSettings.fontColor1,
                  fontFamily: themeSettings.fontFamily,
                ),
              ),
              style: TextStyle(
                color: themeSettings.fontColor1,
                fontFamily: themeSettings.fontFamily,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: '説明',
                labelStyle: TextStyle(
                  color: themeSettings.fontColor1,
                  fontFamily: themeSettings.fontFamily,
                ),
              ),
              style: TextStyle(
                color: themeSettings.fontColor1,
                fontFamily: themeSettings.fontFamily,
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedGroup = widget.group.copyWith(
                name: nameController.text.trim(),
                description: descriptionController.text.trim(),
              );

              final success = await context.read<GroupProvider>().updateGroup(
                updatedGroup,
              );
              if (success && mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('グループを更新しました'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: Text('更新'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('グループを削除'),
        content: Text('このグループを削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await context.read<GroupProvider>().deleteGroup(
                widget.group.id,
              );
              if (success && mounted) {
                Navigator.pop(context); // ダイアログを閉じる
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GroupDeleteCompletePage(),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('削除'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLeaveDialog() async {
    final groupProvider = context.read<GroupProvider>();
    final currentGroup =
        groupProvider.getGroupById(widget.group.id) ?? widget.group;
    final currentUser = FirebaseAuth.instance.currentUser;
    final isAdmin = currentGroup.members.any(
      (m) => m.uid == currentUser?.uid && m.role == GroupRole.admin,
    );

    if (isAdmin) {
      // 管理者が脱退する場合、他のメンバーに管理者権限を譲渡するダイアログを表示
      final candidates = currentGroup.members
          .where((m) => m.uid != currentUser?.uid)
          .toList();
      if (candidates.isEmpty) {
        // 他にメンバーがいない場合は脱退不可
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('脱退できません'),
            content: Text('他にメンバーがいないため、管理者は脱退できません。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      GroupMember? selected;
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('管理者権限の譲渡'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('管理者がグループを脱退する場合、残りのメンバーの中から新しい管理者を選択してください。'),
                SizedBox(height: 16),
                ...candidates.map(
                  (m) => RadioListTile<GroupMember>(
                    title: Text(m.displayName),
                    value: m,
                    groupValue: selected,
                    onChanged: (val) => setState(() => selected = val),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: selected == null
                    ? null
                    : () async {
                        // 1. 選択したメンバーを管理者に昇格
                        await groupProvider.changeMemberRole(
                          groupId: widget.group.id,
                          memberUid: selected!.uid,
                          newRole: GroupRole.admin,
                        );
                        // 2. 自分を脱退
                        final success = await groupProvider.leaveGroup(
                          widget.group.id,
                        );
                        if (success && mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GroupLeaveCompletePage(),
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('管理者権限を譲渡して脱退'),
              ),
            ],
          ),
        ),
      );
      return;
    }
    // 通常の脱退ダイアログ
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('グループから脱退'),
        content: Text('このグループから脱退しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await context.read<GroupProvider>().leaveGroup(
                widget.group.id,
              );
              if (success && mounted) {
                await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    title: Text('脱退完了'),
                    content: Text('グループから脱退しました'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const GroupListPage(),
                            ),
                            (route) => false,
                          );
                        },
                        child: Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('脱退'),
          ),
        ],
      ),
    );
  }

  Future<void> _promoteMember(GroupMember member) async {
    final success = await context.read<GroupProvider>().changeMemberRole(
      groupId: widget.group.id,
      memberUid: member.uid,
      newRole: GroupRole.leader,
    );

    if (success && mounted) {
      await context.read<GroupProvider>().refresh();
      setState(() {
        final groupProvider = context.read<GroupProvider>();
        final updated = groupProvider.getGroupById(widget.group.id);
        if (updated != null) {
          widget.group.members.clear();
          widget.group.members.addAll(updated.members);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${member.displayName}をリーダーに昇格しました'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _demoteMember(GroupMember member) async {
    final success = await context.read<GroupProvider>().changeMemberRole(
      groupId: widget.group.id,
      memberUid: member.uid,
      newRole: GroupRole.member,
    );

    if (success && mounted) {
      await context.read<GroupProvider>().refresh();
      setState(() {
        final groupProvider = context.read<GroupProvider>();
        final updated = groupProvider.getGroupById(widget.group.id);
        if (updated != null) {
          widget.group.members.clear();
          widget.group.members.addAll(updated.members);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${member.displayName}をメンバーに降格しました'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _removeMember(GroupMember member) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('メンバーを削除'),
        content: Text('${member.displayName}をグループから削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await context.read<GroupProvider>().removeMember(
                groupId: widget.group.id,
                memberUid: member.uid,
              );

              if (success && mounted) {
                await context.read<GroupProvider>().refresh();
                setState(() {
                  final groupProvider = context.read<GroupProvider>();
                  final updated = groupProvider.getGroupById(widget.group.id);
                  if (updated != null) {
                    widget.group.members.clear();
                    widget.group.members.addAll(updated.members);
                  }
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${member.displayName}を削除しました'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('削除'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncDataWithGroup() async {
    try {
      // まず自分のデータをグループにアップロード
      await GroupDataSyncService.syncAllDataToGroup(widget.group.id);

      // 次にグループのデータをダウンロード
      await GroupDataSyncService.applyGroupDataToLocal(widget.group.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('データの同期が完了しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('データの同期に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _getGroupIcon(String? iconName, {double size = 24}) {
    final themeSettings = Provider.of<ThemeSettings>(context, listen: false);
    final groupProvider = context.read<GroupProvider>();

    // 最新のグループ情報を取得
    final currentGroup =
        groupProvider.getGroupById(widget.group.id) ?? widget.group;

    // 画像URLがある場合は画像を表示
    if (currentGroup.imageUrl != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: themeSettings.iconColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Image.network(
            '${currentGroup.imageUrl}?t=${DateTime.now().millisecondsSinceEpoch}',
            fit: BoxFit.cover,
            width: size,
            height: size,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Colors.grey.shade100,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                    strokeWidth: 2,
                    color: themeSettings.iconColor,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return _getIconWidget(
                currentGroup.iconName,
                themeSettings,
                size: size,
              );
            },
          ),
        ),
      );
    }

    // 画像URLがない場合はアイコンを表示
    return _getIconWidget(currentGroup.iconName, themeSettings, size: size);
  }

  Widget _getIconWidget(
    String? iconName,
    ThemeSettings themeSettings, {
    double size = 24,
  }) {
    // シンプルにグループアイコンを表示
    return Icon(Icons.group, color: themeSettings.iconColor, size: size);
  }

  /// バッジセクションを表示
  Widget _buildBadgeSection(BuildContext context, ThemeSettings themeSettings) {
    return Consumer<GroupProvider>(
      builder: (context, groupProvider, child) {
        final profile = groupProvider.getGroupGamificationProfile(
          widget.group.id,
        );

        if (profile == null) {
          return Card(
            margin: EdgeInsets.all(12),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: themeSettings.backgroundColor2 ?? Colors.white,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(
                  color: themeSettings.iconColor,
                ),
              ),
            ),
          );
        }

        final badges = profile.badges;

        return Card(
          margin: EdgeInsets.all(12),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: themeSettings.backgroundColor2 ?? Colors.white,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.emoji_events,
                          color: Colors.amber.shade600,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'グループバッジ',
                          style: TextStyle(
                            color: themeSettings.fontColor1,
                            fontSize: 18 * themeSettings.fontSizeScale,
                            fontWeight: FontWeight.bold,
                            fontFamily: themeSettings.fontFamily,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${badges.length}個獲得',
                      style: TextStyle(
                        color: themeSettings.fontColor2,
                        fontSize: 14 * themeSettings.fontSizeScale,
                        fontFamily: themeSettings.fontFamily,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // グループレベル情報
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: profile.levelColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: profile.levelColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.trending_up,
                        color: profile.levelColor,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.displayTitle,
                              style: TextStyle(
                                color: profile.levelColor,
                                fontSize: 14 * themeSettings.fontSizeScale,
                                fontWeight: FontWeight.bold,
                                fontFamily: themeSettings.fontFamily,
                              ),
                            ),
                            Text(
                              'レベル ${profile.level} (${profile.experiencePoints} XP)',
                              style: TextStyle(
                                color: themeSettings.fontColor2,
                                fontSize: 12 * themeSettings.fontSizeScale,
                                fontFamily: themeSettings.fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // 最新バッジ（最大3個）
                if (badges.isNotEmpty) ...[
                  Text(
                    '最新獲得バッジ',
                    style: TextStyle(
                      color: themeSettings.fontColor1,
                      fontSize: 14 * themeSettings.fontSizeScale,
                      fontWeight: FontWeight.w500,
                      fontFamily: themeSettings.fontFamily,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      ...badges
                          .take(3)
                          .map(
                            (badge) => Container(
                              margin: EdgeInsets.only(right: 8),
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: badge.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: badge.color.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    badge.icon,
                                    color: badge.color,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    badge.name,
                                    style: TextStyle(
                                      color: badge.color,
                                      fontSize:
                                          12 * themeSettings.fontSizeScale,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: themeSettings.fontFamily,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                  SizedBox(height: 16),
                ] else ...[
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.emoji_events_outlined,
                          color: Colors.grey.shade400,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'まだバッジを獲得していません\n活動を続けてバッジを獲得しましょう！',
                            style: TextStyle(
                              color: themeSettings.fontColor2,
                              fontSize: 14 * themeSettings.fontSizeScale,
                              fontFamily: themeSettings.fontFamily,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                ],

                // バッジ一覧ボタン
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => BadgeListPage()),
                    );
                  },
                  icon: Icon(Icons.list),
                  label: Text('バッジ一覧を見る'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade600,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
}
