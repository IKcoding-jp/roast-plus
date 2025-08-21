import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/tasting_models.dart';
import '../../models/theme_settings.dart';
import '../../widgets/bean_name_with_sticker.dart';
import 'tasting_record_edit_page.dart';
import 'tasting_session_detail_page.dart';
// import 'package:intl/intl.dart';
import '../../models/group_provider.dart';
import '../../widgets/lottie_animation_widget.dart';

class TastingRecordPage extends StatefulWidget {
  const TastingRecordPage({super.key});

  @override
  State<TastingRecordPage> createState() => _TastingRecordPageState();
}

class _TastingRecordPageState extends State<TastingRecordPage>
    with WidgetsBindingObserver {
  String? _lastGroupId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupProvider = context.read<GroupProvider>();
      final groupId = groupProvider.hasGroup
          ? groupProvider.currentGroup!.id
          : null;
      _lastGroupId = groupId;
      if (groupId != null) {
        context.read<TastingProvider>().subscribeGroupTastingSessions(groupId);
      } else {
        context.read<TastingProvider>().subscribeTastingRecords(groupId: null);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupProvider = context.read<GroupProvider>();
      final groupId = groupProvider.hasGroup
          ? groupProvider.currentGroup!.id
          : null;
      if (_lastGroupId != groupId) {
        _lastGroupId = groupId;
        if (groupId != null) {
          context.read<TastingProvider>().subscribeGroupTastingSessions(
            groupId,
          );
        } else {
        context.read<TastingProvider>().subscribeTastingRecords(
            groupId: null,
        );
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      final groupProvider = context.read<GroupProvider>();
      final groupId = groupProvider.hasGroup
          ? groupProvider.currentGroup!.id
          : null;
      context.read<TastingProvider>().subscribeTastingRecords(groupId: groupId);
    }
  }

  // String _getRatingText(double rating) {
  //   if (rating >= 4.5) return '★★★★★';
  //   if (rating >= 3.5) return '★★★★☆';
  //   if (rating >= 2.5) return '★★★☆☆';
  //   if (rating >= 1.5) return '★★☆☆☆';
  //   return '★☆☆☆☆';
  // }

  Color _getRatingColor(double rating) {
    if (rating >= 4.0) return Colors.green;
    if (rating >= 3.0) return Colors.blue;
    if (rating >= 2.0) return Colors.orange;
    return Colors.grey;
  }

  Widget _buildStarIcons(double rating) {
    const color = Color(0xFFFFD700); // Gold
    final clamped = rating.clamp(0.0, 5.0);
    final full = clamped.floor();
    final hasHalf = (clamped - full) >= 0.5;
    final empty = 5 - full - (hasHalf ? 1 : 0);
    return Row(
      children: [
        for (int i = 0; i < full; i++) Icon(Icons.star, size: 16, color: color),
        if (hasHalf) Icon(Icons.star_half, size: 16, color: color),
        for (int i = 0; i < empty; i++)
          Icon(Icons.star_border, size: 16, color: color),
      ],
    );
  }

  // 煎り度ごとの色
  Color _getRoastLevelColor(String roastLevel) {
    switch (roastLevel) {
      case '浅煎り':
        return const Color(0xFFF5E2B8); // 明るいベージュ
      case '中煎り':
        return const Color(0xFFD2A86A); // キャラメル
      case '中深煎り':
        return const Color(0xFF8B5C2A); // ダークブラウン
      case '深煎り':
        return const Color(0xFF6B4F3F); // 明るめのダークブラウン
      default:
        return Colors.brown;
    }
  }

  // 煎り度ごとの文字色（明るい背景は黒、暗い背景は白）
  Color _getRoastLevelTextColor(String roastLevel) {
    switch (roastLevel) {
      case '浅煎り':
      case '中煎り':
        return Colors.black87;
      case '中深煎り':
      case '深煎り':
        return Colors.white;
      default:
        return Colors.brown;
    }
  }

  Widget _buildRatingRow(
    String label,
    double rating,
    ThemeSettings themeSettings,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: themeSettings.fontColor1.withValues(alpha: 0.7),
            ),
          ),
          Row(
            children: [
              Text(
                rating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _getRatingColor(rating),
                ),
              ),
              SizedBox(width: 4),
              Container(
                width: 60,
                height: 6,
                decoration: BoxDecoration(
                  color: themeSettings.fontColor1.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: rating / 5.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _getRatingColor(rating),
                      borderRadius: BorderRadius.circular(3),
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

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    // ページが表示されるたびにデータを読み込む
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   final groupProvider = context.read<GroupProvider>();
    //   if (!tastingProvider.isLoading &&
    //       tastingProvider.tastingRecords.isEmpty) {
    //     if (groupProvider.hasGroup) {
    //       tastingProvider.loadTastingRecords(
    //         groupId: groupProvider.currentGroup!.id,
    //       );
    //     } else {
    //       tastingProvider.loadTastingRecords();
    //     }
    //   }
    // });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('試飲感想記録'),
            // グループ状態バッジを追加
            Consumer<GroupProvider>(
              builder: (context, groupProvider, _) {
                if (groupProvider.hasGroup) {
                  // グループ名のテキストを削除し、アイコンのみ表示
                  return Container(
                    margin: EdgeInsets.only(left: 12),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade400),
                    ),
                    child: Icon(
                      Icons.groups,
                      size: 18,
                      color: Colors.blue.shade700,
                    ),
                  );
                } else {
                  return SizedBox.shrink();
                }
              },
            ),
          ],
        ),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
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
                    '試飲感想記録がありません',
                    style: TextStyle(
                      fontSize: 18,
                      color: themeSettings.fontColor1,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '右下のボタンから新しい記録を作成してください',
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
            return ListView.builder(
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
                                    color: _getRoastLevelColor(s.roastLevel),
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
                              Text('件数: ${s.entriesCount}/$memberCount'),
                              SizedBox(width: 12),
                              Text('平均総合: '),
                              _buildStarIcons(s.avgOverall),
                            ],
                          ),
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: themeSettings.fontColor1.withValues(
                                alpha: 0.05,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                _buildRatingRow(
                                  '苦味',
                                  s.avgBitterness,
                                  themeSettings,
                                ),
                                _buildRatingRow(
                                  '酸味',
                                  s.avgAcidity,
                                  themeSettings,
                                ),
                                _buildRatingRow(
                                  'ボディ',
                                  s.avgBody,
                                  themeSettings,
                                ),
                                _buildRatingRow(
                                  '甘み',
                                  s.avgSweetness,
                                  themeSettings,
                                ),
                                _buildRatingRow(
                                  '香り',
                                  s.avgAroma,
                                  themeSettings,
                                ),
                                _buildRatingRow(
                                  '総合',
                                  s.avgOverall,
                                  themeSettings,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }

          // 非グループ時は従来の個人記録の一覧
          final tastingGroups = tastingProvider.getTastingGroups();
          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: tastingGroups.length,
            itemBuilder: (context, index) {
              final tastingGroup = tastingGroups[index];
              final latestRecord = tastingGroup.latestRecord;
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
                        builder: (context) =>
                            TastingRecordEditPage(tastingRecord: latestRecord),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BeanNameWithSticker(
                                    beanName: tastingGroup.beanName,
                                    textStyle: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: themeSettings.fontColor1,
                                    ),
                                    stickerSize: 18.0,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '${tastingGroup.totalRecords}件の評価',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: themeSettings.fontColor1
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
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
}
