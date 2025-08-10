import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../models/theme_settings.dart';
import '../settings/account_info_page.dart';
import 'group_create_page.dart';
import 'group_info_page.dart';
import 'group_invitations_page.dart';

class GroupCardPage extends StatefulWidget {
  const GroupCardPage({super.key});

  @override
  State<GroupCardPage> createState() => _GroupCardPageState();
}

class _GroupCardPageState extends State<GroupCardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final groupProvider = context.read<GroupProvider>();
      await groupProvider.refresh();
      // 統計情報も読み込む
      await groupProvider.loadAllGroupStatistics();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ページが表示されるたびに最新の情報を取得
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.hasGroup) {
        await groupProvider.loadUserGroups();
        await groupProvider.loadAllGroupStatistics();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'グループ',
          style: TextStyle(
            color: themeSettings.appBarTextColor,
            fontSize: 20 * themeSettings.fontSizeScale,
            fontWeight: FontWeight.bold,
            fontFamily: themeSettings.fontFamily,
          ),
        ),
        backgroundColor: themeSettings.appBarColor,
        iconTheme: IconThemeData(color: themeSettings.iconColor),
      ),
      body: Consumer<GroupProvider>(
        builder: (context, groupProvider, child) {
          if (groupProvider.loading) {
            return Center(
              child: CircularProgressIndicator(color: themeSettings.iconColor),
            );
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
                                  'グループ招待',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 16 * themeSettings.fontSizeScale,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: themeSettings.fontFamily,
                                  ),
                                ),
                                Text(
                                  '${groupProvider.invitations.length}件の招待があります',
                                  style: TextStyle(
                                    color: Colors.orange,
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

                // グループカード
                if (groupProvider.hasGroup)
                  SliverToBoxAdapter(
                    child: _buildGroupCard(groupProvider, themeSettings),
                  ),

                // グループがない場合のメッセージ
                if (!groupProvider.hasGroup)
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
                            'グループに参加していません',
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
                          SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => GroupCreatePage(),
                                ),
                              );
                            },
                            icon: Icon(Icons.add),
                            label: Text('グループを作成'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeSettings.appButtonColor,
                              foregroundColor: themeSettings.fontColor2,
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
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
      floatingActionButton: Consumer<GroupProvider>(
        builder: (context, groupProvider, child) {
          // グループに参加していない場合のみグループ作成ボタンを表示
          if (!groupProvider.hasGroup) {
            return FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GroupCreatePage()),
                );
              },
              backgroundColor: themeSettings.appButtonColor,
              foregroundColor: themeSettings.fontColor2,
              child: Icon(Icons.add),
            );
          }
          return SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildGroupCard(
    GroupProvider groupProvider,
    ThemeSettings themeSettings,
  ) {
    final group = groupProvider.currentGroup!;
    final isLeader = groupProvider.isCurrentUserLeaderOfCurrentGroup();
    final statistics = groupProvider.getGroupStatistics(group.id);

    return Card(
      margin: EdgeInsets.all(16),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: themeSettings.cardBackgroundColor,
      child: InkWell(
        onTap: () {
          // GroupProviderの現在のグループを設定
          final groupProvider = context.read<GroupProvider>();
          groupProvider.setCurrentGroup(group);

          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => GroupInfoPage()),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // グループ名とアイコン
              Row(
                children: [
                  _getGroupIcon(group, isLeader, themeSettings),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: TextStyle(
                            color: themeSettings.fontColor1,
                            fontSize: 22 * themeSettings.fontSizeScale,
                            fontWeight: FontWeight.bold,
                            fontFamily: themeSettings.fontFamily,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          group.description,
                          style: TextStyle(
                            color: themeSettings.fontColor1.withValues(
                              alpha: 0.7,
                            ),
                            fontSize: 14 * themeSettings.fontSizeScale,
                            fontFamily: themeSettings.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isLeader)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.amber[700]),
                          SizedBox(width: 4),
                          Text(
                            'リーダー',
                            style: TextStyle(
                              color: Colors.amber[700],
                              fontSize: 12 * themeSettings.fontSizeScale,
                              fontWeight: FontWeight.bold,
                              fontFamily: themeSettings.fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              SizedBox(height: 20),

              // メンバー情報
              Row(
                children: [
                  Icon(Icons.people, size: 20, color: themeSettings.iconColor),
                  SizedBox(width: 8),
                  Text(
                    'メンバー ${group.members.length}人',
                    style: TextStyle(
                      color: themeSettings.fontColor1,
                      fontSize: 16 * themeSettings.fontSizeScale,
                      fontWeight: FontWeight.w600,
                      fontFamily: themeSettings.fontFamily,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 8),

              // 役割別メンバー数
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: themeSettings.iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '管理者${group.members.where((m) => m.role == GroupRole.admin).length}人・'
                  'リーダー${group.members.where((m) => m.role == GroupRole.leader).length}人・'
                  'メンバー${group.members.where((m) => m.role == GroupRole.member).length}人',
                  style: TextStyle(
                    color: themeSettings.fontColor1,
                    fontSize: 12 * themeSettings.fontSizeScale,
                    fontFamily: themeSettings.fontFamily,
                  ),
                ),
              ),

              SizedBox(height: 20),

              // 統計情報
              if (statistics != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.analytics,
                      size: 20,
                      color: themeSettings.iconColor,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'グループ統計',
                      style: TextStyle(
                        color: themeSettings.fontColor1,
                        fontSize: 16 * themeSettings.fontSizeScale,
                        fontWeight: FontWeight.w600,
                        fontFamily: themeSettings.fontFamily,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        '今日の焙煎',
                        '${statistics['todayRoastCount'] ?? 0}回',
                        Icons.local_fire_department,
                        Colors.orange,
                        themeSettings,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildStatItem(
                        '今週の活動',
                        '${statistics['thisWeekActivityCount'] ?? 0}回',
                        Icons.trending_up,
                        Colors.blue,
                        themeSettings,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                _buildStatItem(
                  '総焙煎時間',
                  '${(statistics['totalRoastTime'] ?? 0.0).toStringAsFixed(1)}分',
                  Icons.timer,
                  Colors.green,
                  themeSettings,
                ),
              ],

              SizedBox(height: 20),

              // アクションボタン
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
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
                      icon: Icon(Icons.info_outline),
                      label: Text('詳細を見る'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeSettings.appButtonColor,
                        foregroundColor: themeSettings.fontColor2,
                        textStyle: const TextStyle(fontSize: 16),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
    ThemeSettings themeSettings,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: color),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: themeSettings.fontColor1.withValues(alpha: 0.7),
                    fontSize: 12 * themeSettings.fontSizeScale,
                    fontFamily: themeSettings.fontFamily,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: themeSettings.fontColor1,
                    fontSize: 16 * themeSettings.fontSizeScale,
                    fontWeight: FontWeight.bold,
                    fontFamily: themeSettings.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _getGroupIcon(
    Group group,
    bool isLeader,
    ThemeSettings themeSettings,
  ) {
    // 画像URLがある場合は画像を表示
    if (group.imageUrl != null && group.imageUrl!.isNotEmpty) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Image.network(
            '${group.imageUrl}?t=${DateTime.now().millisecondsSinceEpoch}',
            fit: BoxFit.cover,
            width: 60,
            height: 60,
            cacheWidth: 120,
            cacheHeight: 120,
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
              return _getIconWidget(group.iconName, isLeader, themeSettings);
            },
          ),
        ),
      );
    }

    // 画像URLがない場合はアイコンを表示
    return _getIconWidget(group.iconName, isLeader, themeSettings);
  }

  Widget _getIconWidget(
    String? iconName,
    bool isLeader,
    ThemeSettings themeSettings,
  ) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          colors: isLeader
              ? [Colors.amber.shade300, Colors.amber.shade600]
              : [
                  themeSettings.iconColor.withValues(alpha: 0.7),
                  themeSettings.iconColor,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        isLeader ? Icons.star : Icons.group,
        color: Colors.white,
        size: 30,
      ),
    );
  }
}
