import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../models/theme_settings.dart';
import '../../services/group_data_sync_service.dart';
import 'group_member_invite_page.dart';
import 'group_settings_page.dart';
import 'group_edit_page.dart';

class GroupDetailPage extends StatefulWidget {
  final Group group;

  const GroupDetailPage({required this.group, super.key});

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    final isLeader = context.read<GroupProvider>().isCurrentUserLeader(
      widget.group.id,
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
        actions: [
        ],
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
                          ...widget.group.members.map((member) {
                            final isCurrentUser =
                                currentUser?.uid == member.uid;
                            final canManage = isLeader && !isCurrentUser;

                            return ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 0,
                                vertical: 4,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: member.role == GroupRole.leader
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
                                                          GroupRole.leader
                                                      ? Icons.star
                                                      : Icons.person,
                                                  color: Colors.white,
                                                );
                                              },
                                        ),
                                      )
                                    : Icon(
                                        member.role == GroupRole.leader
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
                                    member.email,
                                    style: TextStyle(
                                      color: themeSettings.fontColor1,
                                      fontSize:
                                          12 * themeSettings.fontSizeScale,
                                      fontFamily: themeSettings.fontFamily,
                                    ),
                                  ),
                                  Text(
                                    member.role == GroupRole.leader
                                        ? 'リーダー'
                                        : 'メンバー',
                                    style: TextStyle(
                                      color: member.role == GroupRole.leader
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

                // 脱退ボタン
                if (!isLeader)
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
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('グループを削除しました'),
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

  Future<void> _showLeaveDialog() async {
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
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('グループから脱退しました'),
                    backgroundColor: Colors.green,
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

  Widget _getGroupIcon(String? iconName) {
    final themeSettings = Provider.of<ThemeSettings>(context, listen: false);
    final groupProvider = context.read<GroupProvider>();

    // 最新のグループ情報を取得
    final currentGroup =
        groupProvider.getGroupById(widget.group.id) ?? widget.group;

    // 画像URLがある場合は画像を表示
    if (currentGroup.imageUrl != null) {
      return Container(
        width: 40,
        height: 40,
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
            width: 40,
            height: 40,
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
              return _getIconWidget(currentGroup.iconName, themeSettings);
            },
          ),
        ),
      );
    }

    // 画像URLがない場合はアイコンを表示
    return _getIconWidget(currentGroup.iconName, themeSettings);
  }

  Widget _getIconWidget(String? iconName, ThemeSettings themeSettings) {
    // シンプルにグループアイコンを表示
    return Icon(Icons.group, color: themeSettings.iconColor, size: 24);
  }
}
