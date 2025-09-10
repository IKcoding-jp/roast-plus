import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/tasting_models.dart';
import '../../models/theme_settings.dart';
import '../../models/group_provider.dart';
import '../../widgets/lottie_animation_widget.dart';
import '../../widgets/bean_name_with_sticker.dart';
import 'tasting_session_detail_page.dart';
import 'tasting_record_edit_page.dart';

class TastingRecordPage extends StatefulWidget {
  const TastingRecordPage({super.key});

  @override
  State<TastingRecordPage> createState() => _TastingRecordPageState();
}

class _TastingRecordPageState extends State<TastingRecordPage> {
  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('試飲記録'),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
        actions: [
          Consumer<GroupProvider>(
            builder: (context, groupProvider, child) {
              if (!groupProvider.hasGroup) {
                return SizedBox.shrink();
              }
              return PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'group') {
                    // グループ設定画面に遷移
                    Navigator.pushNamed(context, '/group_settings');
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'group',
                    child: Row(
                      children: [
                        Icon(Icons.group),
                        SizedBox(width: 8),
                        Text('グループ設定'),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  margin: EdgeInsets.only(right: 16),
                  child: Icon(Icons.more_vert),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<TastingProvider>(
        builder: (context, tastingProvider, child) {
          if (tastingProvider.isLoading) {
            return const LoadingAnimationWidget();
          }
          final groupProvider = context.read<GroupProvider>();
          final hasGroup = groupProvider.hasGroup;
          if (hasGroup && tastingProvider.sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.coffee,
                    size: 64,
                    color: themeSettings.tastingColor.withValues(alpha: 0.5),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'セッションがありません',
                    style: TextStyle(
                      fontSize: 18,
                      color: themeSettings.fontColor1,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '右下のボタンからセッションを開始してください',
                    style: TextStyle(
                      fontSize: 14,
                      color: themeSettings.fontColor1.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            );
          }
          if (!hasGroup && tastingProvider.tastingRecords.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.coffee,
                    size: 64,
                    color: themeSettings.tastingColor.withValues(alpha: 0.5),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '試飲記録がありません',
                    style: TextStyle(
                      fontSize: 18,
                      color: themeSettings.fontColor1,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '右下のボタンから記録を追加してください',
                    style: TextStyle(
                      fontSize: 14,
                      color: themeSettings.fontColor1.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            );
          }

          if (hasGroup) {
            final sessions = tastingProvider.sessions;
            final memberCount = groupProvider.currentGroup?.members.length ?? 0;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width > 600
                      ? 600
                      : double.infinity,
                ),
                child: ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final s = sessions[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TastingSessionDetailPage(
                                sessionId: s.id,
                                beanName: s.beanName,
                                roastLevel: s.roastLevel,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: BeanNameWithSticker(
                                      beanName: s.beanName,
                                      textStyle: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: themeSettings.fontColor1,
                                      ),
                                      stickerSize: 18,
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getRoastLevelColor(s.roastLevel),
                                      border: Border.all(
                                        color: _getRoastLevelColor(
                                          s.roastLevel,
                                        ),
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      s.roastLevel,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _getRoastLevelTextColor(
                                          s.roastLevel,
                                        ),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.people,
                                    size: 16,
                                    color: themeSettings.fontColor1.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '${s.entriesCount}/$memberCount人が参加',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: themeSettings.fontColor1
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                  Spacer(),
                                  Text(
                                    _formatDate(s.createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: themeSettings.fontColor1
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                              if (s.entriesCount > 0) ...[
                                SizedBox(height: 8),
                                _buildAverageScores(s, themeSettings),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          } else {
            // 個人の試飲記録表示
            final records = tastingProvider.tastingRecords;
            return ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TastingRecordEditPage(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: BeanNameWithSticker(
                                  beanName: record.beanName,
                                  textStyle: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: themeSettings.fontColor1,
                                  ),
                                  stickerSize: 18.0,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getRoastLevelColor(record.roastLevel),
                                  border: Border.all(
                                    color: _getRoastLevelColor(
                                      record.roastLevel,
                                    ),
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  record.roastLevel,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _getRoastLevelTextColor(
                                      record.roastLevel,
                                    ),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: themeSettings.fontColor1.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              SizedBox(width: 4),
                              Text(
                                _formatDate(record.tastingDate),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: themeSettings.fontColor1.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                              Spacer(),
                              Text(
                                '総合: ${record.overallRating.toStringAsFixed(1)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: themeSettings.tastingColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final groupProvider = context.read<GroupProvider>();
          if (groupProvider.hasGroup) {
            // グループ: 詳細/新規で作るのは詳細画面の上部で行う
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TastingSessionDetailPage()),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => TastingRecordEditPage()),
            );
          }
        },
        backgroundColor: themeSettings.appButtonColor,
        foregroundColor: themeSettings.fontColor2,
        child: Icon(Icons.add),
      ),
    );
  }

  Color _getRoastLevelColor(String roastLevel) {
    switch (roastLevel) {
      case '浅煎り':
        return Colors.orange.shade200;
      case '中煎り':
        return Colors.brown.shade300;
      case '中深煎り':
        return Colors.brown.shade400;
      case '深煎り':
        return Colors.brown.shade600;
      default:
        return Colors.grey.shade300;
    }
  }

  Color _getRoastLevelTextColor(String roastLevel) {
    switch (roastLevel) {
      case '浅煎り':
        return Colors.orange.shade800;
      case '中煎り':
        return Colors.brown.shade800;
      case '中深煎り':
        return Colors.white;
      case '深煎り':
        return Colors.white;
      default:
        return Colors.grey.shade800;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildAverageScores(
    TastingSession session,
    ThemeSettings themeSettings,
  ) {
    return Row(
      children: [
        _buildScoreItem('苦味', session.avgBitterness, themeSettings),
        SizedBox(width: 8),
        _buildScoreItem('酸味', session.avgAcidity, themeSettings),
        SizedBox(width: 8),
        _buildScoreItem('ボディ', session.avgBody, themeSettings),
        SizedBox(width: 8),
        _buildScoreItem('甘味', session.avgSweetness, themeSettings),
        SizedBox(width: 8),
        _buildScoreItem('香り', session.avgAroma, themeSettings),
        Spacer(),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: themeSettings.tastingColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '総合: ${session.avgOverall.toStringAsFixed(1)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: themeSettings.tastingColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreItem(
    String label,
    double score,
    ThemeSettings themeSettings,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: themeSettings.fontColor1.withValues(alpha: 0.7),
          ),
        ),
        SizedBox(height: 2),
        Text(
          score.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: themeSettings.fontColor1,
          ),
        ),
      ],
    );
  }
}
