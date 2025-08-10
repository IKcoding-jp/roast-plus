import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../models/theme_settings.dart';
import '../settings/account_info_page.dart';
import '../gamification/badge_list_page.dart';
import 'group_create_page.dart';
import 'group_info_page.dart';
import 'group_invitations_page.dart';
import '../../widgets/lottie_animation_widget.dart';

class GroupListPage extends StatefulWidget {
  const GroupListPage({super.key});

  @override
  State<GroupListPage> createState() => _GroupListPageState();
}

class _GroupListPageState extends State<GroupListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final groupProvider = context.read<GroupProvider>();
      await groupProvider.refresh();
      // 統計情報とゲーミフィケーション情報も読み込む
      await groupProvider.loadAllGroupStatistics();
      await groupProvider.loadAllGroupGamificationProfiles();

      // ゲーミフィケーション監視を開始
      for (final group in groupProvider.groups) {
        groupProvider.watchGroupGamificationProfile(group.id);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ページが表示されるたびに最新の情報を取得
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.groups.isNotEmpty) {
        await groupProvider.loadUserGroups();
        await groupProvider.loadAllGroupStatistics();
        await groupProvider.loadAllGroupGamificationProfiles();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'グループ管理',
          style: TextStyle(
            color: themeSettings.appBarTextColor,
            fontSize: 20 * themeSettings.fontSizeScale,
            fontWeight: FontWeight.bold,
            fontFamily: themeSettings.fontFamily,
          ),
        ),
        backgroundColor: themeSettings.appBarColor,
        iconTheme: IconThemeData(color: themeSettings.iconColor),
        actions: [],
      ),
      body: Consumer<GroupProvider>(
        builder: (context, groupProvider, child) {
          if (groupProvider.loading) {
            return Center(child: const LoadingAnimationWidget());
          }

          if (groupProvider.error != null) {
            final isLoginError = groupProvider.error!.contains('ログインすることで');

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isLoginError ? Icons.account_circle : Icons.error_outline,
                    size: 64,
                    color: themeSettings.iconColor,
                  ),
                  SizedBox(height: 16),
                  Text(
                    isLoginError ? 'ログインが必要です' : 'エラーが発生しました',
                    style: TextStyle(
                      color: themeSettings.fontColor1,
                      fontSize: 18 * themeSettings.fontSizeScale,
                      fontFamily: themeSettings.fontFamily,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    groupProvider.error!,
                    style: TextStyle(
                      color: themeSettings.fontColor1,
                      fontSize: 14 * themeSettings.fontSizeScale,
                      fontFamily: themeSettings.fontFamily,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  if (isLoginError)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AccountInfoPage(),
                          ),
                        );
                      },
                      icon: Image.asset('assets/google_logo.png', height: 20),
                      label: Text('Googleでログイン'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: themeSettings.fontColor1,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: themeSettings.fontColor1,
                            width: 1,
                          ),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: () {
                        groupProvider.clearError();
                        groupProvider.refresh();
                      },
                      child: Text('再試行'),
                    ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await groupProvider.refresh();
              await groupProvider.loadAllGroupStatistics();
              await groupProvider.loadAllGroupGamificationProfiles();
            },
            child: CustomScrollView(
              slivers: [
                // 招待通知
                if (groupProvider.invitations.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: EdgeInsets.all(16),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.mail_outline,
                            color: Colors.orange,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '新しい招待があります',
                                  style: TextStyle(
                                    color: themeSettings.fontColor1,
                                    fontSize: 16 * themeSettings.fontSizeScale,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: themeSettings.fontFamily,
                                  ),
                                ),
                                Text(
                                  '${groupProvider.invitations.length}件の招待を確認してください',
                                  style: TextStyle(
                                    color: themeSettings.fontColor1,
                                    fontSize: 14 * themeSettings.fontSizeScale,
                                    fontFamily: themeSettings.fontFamily,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => GroupInvitationsPage(),
                                ),
                              );
                            },
                            child: Text(
                              '確認',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // グループ一覧
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final group = groupProvider.groups[index];
                    final statistics = groupProvider.getGroupStatistics(
                      group.id,
                    );

                    developer.log(
                      'グループリスト表示 - インデックス: $index, グループ名: ${group.name}',
                      name: 'GroupListPage',
                    );
                    developer.log(
                      'グループ画像URL: ${group.imageUrl}',
                      name: 'GroupListPage',
                    );

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: themeSettings.cardBackgroundColor,
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16),
                        // leading: グループアイコン部分を削除
                        title: Text(
                          group.name,
                          style: TextStyle(
                            color: themeSettings.fontColor1,
                            fontSize: 18 * themeSettings.fontSizeScale,
                            fontWeight: FontWeight.bold,
                            fontFamily: themeSettings.fontFamily,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text(
                              group.description,
                              style: TextStyle(
                                color: themeSettings.fontColor1,
                                fontSize: 14 * themeSettings.fontSizeScale,
                                fontFamily: themeSettings.fontFamily,
                              ),
                            ),
                            SizedBox(height: 8),

                            // メンバー情報
                            Row(
                              children: [
                                // メンバーアバター（最大4人）
                                ...group.members
                                    .take(4)
                                    .map(
                                      (member) => Container(
                                        margin: EdgeInsets.only(right: 4),
                                        child: CircleAvatar(
                                          radius: 12,
                                          backgroundColor:
                                              member.role == GroupRole.leader ||
                                                  member.role == GroupRole.admin
                                              ? Colors.orange
                                              : themeSettings.iconColor,
                                          child: member.photoUrl != null
                                              ? ClipOval(
                                                  child: Image.network(
                                                    member.photoUrl!,
                                                    width: 24,
                                                    height: 24,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (
                                                          context,
                                                          error,
                                                          stackTrace,
                                                        ) {
                                                          return Icon(
                                                            member.role ==
                                                                    GroupRole
                                                                        .leader
                                                                ? Icons.star
                                                                : Icons.person,
                                                            color: Colors.white,
                                                            size: 14,
                                                          );
                                                        },
                                                  ),
                                                )
                                              : Icon(
                                                  member.role ==
                                                          GroupRole.leader
                                                      ? Icons.star
                                                      : Icons.person,
                                                  color: Colors.white,
                                                  size: 14,
                                                ),
                                        ),
                                      ),
                                    ),

                                // 残りのメンバー数
                                if (group.members.length > 4)
                                  Container(
                                    margin: EdgeInsets.only(right: 8),
                                    child: Text(
                                      '+${group.members.length - 4}',
                                      style: TextStyle(
                                        color: themeSettings.fontColor1,
                                        fontSize:
                                            10 * themeSettings.fontSizeScale,
                                        fontFamily: themeSettings.fontFamily,
                                      ),
                                    ),
                                  ),

                                // 役割分布
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: themeSettings.iconColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '管理者${group.members.where((m) => m.role == GroupRole.admin).length}人・リーダー${group.members.where((m) => m.role == GroupRole.leader).length}人・メンバー${group.members.where((m) => m.role == GroupRole.member).length}人',
                                    style: TextStyle(
                                      color: themeSettings.fontColor1,
                                      fontSize:
                                          10 * themeSettings.fontSizeScale,
                                      fontFamily: themeSettings.fontFamily,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 8),

                            // 統計情報
                            Row(
                              children: [
                                // 今日の焙煎記録数
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.coffee,
                                        size: 12,
                                        color: Colors.green,
                                      ),
                                      SizedBox(width: 2),
                                      Text(
                                        '今日: ${statistics?['todayRoastCount'] ?? 0}回',
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontSize:
                                              10 * themeSettings.fontSizeScale,
                                          fontFamily: themeSettings.fontFamily,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(width: 8),

                                // 今週の活動回数
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.trending_up,
                                        size: 12,
                                        color: Colors.blue,
                                      ),
                                      SizedBox(width: 2),
                                      Text(
                                        '今週: ${statistics?['thisWeekActivityCount'] ?? 0}回',
                                        style: TextStyle(
                                          color: Colors.blue[700],
                                          fontSize:
                                              10 * themeSettings.fontSizeScale,
                                          fontFamily: themeSettings.fontFamily,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(width: 8),

                                // 総焙煎時間
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.timer,
                                        size: 12,
                                        color: Colors.orange,
                                      ),
                                      SizedBox(width: 2),
                                      Text(
                                        '総時間: ${(statistics?['totalRoastTime'] ?? 0.0).toStringAsFixed(1)}h',
                                        style: TextStyle(
                                          color: Colors.orange[700],
                                          fontSize:
                                              10 * themeSettings.fontSizeScale,
                                          fontFamily: themeSettings.fontFamily,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 8),

                            // バッジ情報
                            _buildBadgeInfo(context, themeSettings, group.id),
                          ],
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: themeSettings.iconColor,
                        ),
                        onTap: () {
                          // GroupProviderの現在のグループを設定
                          final groupProvider = context.read<GroupProvider>();
                          groupProvider.setCurrentGroup(group);

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GroupInfoPage(),
                            ),
                          );
                        },
                      ),
                    );
                  }, childCount: groupProvider.groups.length),
                ),

                // グループがない場合のメッセージ
                if (groupProvider.groups.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.group_outlined,
                            size: 64,
                            color: themeSettings.iconColor,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'グループがありません',
                            style: TextStyle(
                              color: themeSettings.fontColor1,
                              fontSize: 18 * themeSettings.fontSizeScale,
                              fontWeight: FontWeight.bold,
                              fontFamily: themeSettings.fontFamily,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '新しいグループを作成するか、\n招待を受けてグループに参加しましょう',
                            style: TextStyle(
                              color: themeSettings.fontColor1,
                              fontSize: 14 * themeSettings.fontSizeScale,
                              fontFamily: themeSettings.fontFamily,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => GroupCreatePage()),
          );
        },
        backgroundColor: themeSettings.buttonColor,
        foregroundColor: themeSettings.fontColor2,
        child: Icon(Icons.add),
      ),
    );
  }

  /// バッジ情報を表示
  Widget _buildBadgeInfo(
    BuildContext context,
    ThemeSettings themeSettings,
    String groupId,
  ) {
    return Consumer<GroupProvider>(
      builder: (context, groupProvider, child) {
        final profile = groupProvider.getGroupGamificationProfile(groupId);

        if (profile == null) {
          return SizedBox(
            height: 20,
            child: Center(
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1),
              ),
            ),
          );
        }

        final badges = profile.badges;

        return Row(
          children: [
            // バッジアイコン
            Icon(Icons.emoji_events, size: 14, color: Colors.amber.shade600),
            SizedBox(width: 4),

            // バッジ数
            Text(
              '${badges.length}個のバッジ',
              style: TextStyle(
                color: themeSettings.fontColor2,
                fontSize: 12 * themeSettings.fontSizeScale,
                fontFamily: themeSettings.fontFamily,
              ),
            ),

            Spacer(),

            // 最新バッジ（最大3個）
            if (badges.isNotEmpty) ...[
              ...badges
                  .take(3)
                  .map(
                    (badge) => Container(
                      margin: EdgeInsets.only(left: 4),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: badge.color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.star, color: Colors.white, size: 10),
                    ),
                  ),

              // バッジ一覧ボタン
              Container(
                margin: EdgeInsets.only(left: 8),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => BadgeListPage()),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Text(
                      '詳細',
                      style: TextStyle(
                        color: Colors.amber.shade700,
                        fontSize: 10 * themeSettings.fontSizeScale,
                        fontWeight: FontWeight.w500,
                        fontFamily: themeSettings.fontFamily,
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // バッジがない場合
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  'バッジなし',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 10 * themeSettings.fontSizeScale,
                    fontFamily: themeSettings.fontFamily,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
