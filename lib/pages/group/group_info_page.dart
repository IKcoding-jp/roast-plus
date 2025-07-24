import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/group_models.dart';
import '../../models/theme_settings.dart';
import '../../models/group_provider.dart';

class GroupInfoPage extends StatefulWidget {
  final Group group;
  const GroupInfoPage({super.key, required this.group});

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);
    final groupProvider = Provider.of<GroupProvider>(context);
    final group = widget.group;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'グループ情報',
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // グループ名と説明
              Text(
                group.name,
                style: TextStyle(
                  color: themeSettings.fontColor1,
                  fontSize: 24 * themeSettings.fontSizeScale,
                  fontWeight: FontWeight.bold,
                  fontFamily: themeSettings.fontFamily,
                ),
              ),
              SizedBox(height: 8),
              Text(
                group.description,
                style: TextStyle(
                  color: themeSettings.fontColor1.withOpacity(0.7),
                  fontSize: 16 * themeSettings.fontSizeScale,
                  fontFamily: themeSettings.fontFamily,
                ),
              ),
              SizedBox(height: 24),

              // メンバー情報
              _buildSectionHeader('メンバー', Icons.people, themeSettings),
              SizedBox(height: 12),
              // ここにメンバーリストなどを表示するウィジェットを追加予定
              Card(
                color: themeSettings.backgroundColor2,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '総メンバー数: ${group.members.length}人',
                        style: TextStyle(
                          color: themeSettings.fontColor1,
                          fontSize: 16 * themeSettings.fontSizeScale,
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '管理者: ${group.members.where((m) => m.role == GroupRole.admin).length}人',
                        style: TextStyle(
                          color: themeSettings.fontColor1,
                          fontSize: 14 * themeSettings.fontSizeScale,
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                      Text(
                        'リーダー: ${group.members.where((m) => m.role == GroupRole.leader).length}人',
                        style: TextStyle(
                          color: themeSettings.fontColor1,
                          fontSize: 14 * themeSettings.fontSizeScale,
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                      Text(
                        'メンバー: ${group.members.where((m) => m.role == GroupRole.member).length}人',
                        style: TextStyle(
                          color: themeSettings.fontColor1,
                          fontSize: 14 * themeSettings.fontSizeScale,
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // 統計情報 (GroupCardPageから移動)
              _buildSectionHeader('グループ統計', Icons.analytics, themeSettings),
              SizedBox(height: 12),
              if (groupProvider.getGroupStatistics(group.id) != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        '今日の焙煎',
                        '${groupProvider.getGroupStatistics(group.id)!['todayRoastCount'] ?? 0}回',
                        Icons.local_fire_department,
                        Colors.orange,
                        themeSettings,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildStatItem(
                        '今週の活動',
                        '${groupProvider.getGroupStatistics(group.id)!['thisWeekActivityCount'] ?? 0}回',
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
                  '${(groupProvider.getGroupStatistics(group.id)!['totalRoastTime'] ?? 0.0).toStringAsFixed(1)}分',
                  Icons.timer,
                  Colors.green,
                  themeSettings,
                ),
              ],
              SizedBox(height: 24),

              // その他の情報やアクションボタン
              // 例: グループ設定ページへのリンク、グループ脱退など
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    ThemeSettings themeSettings,
  ) {
    return Row(
      children: [
        Icon(icon, size: 24, color: themeSettings.iconColor),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: themeSettings.fontColor1,
            fontSize: 20 * themeSettings.fontSizeScale,
            fontWeight: FontWeight.bold,
            fontFamily: themeSettings.fontFamily,
          ),
        ),
      ],
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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
                    color: themeSettings.fontColor1.withOpacity(0.7),
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
}
