import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/tasting_models.dart';
import '../../models/theme_settings.dart';
import '../../widgets/bean_name_with_sticker.dart';
import 'tasting_record_edit_page.dart';
import 'package:intl/intl.dart';
import '../../models/group_provider.dart';

class TastingRecordPage extends StatefulWidget {
  const TastingRecordPage({super.key});

  @override
  State<TastingRecordPage> createState() => _TastingRecordPageState();
}

class _TastingRecordPageState extends State<TastingRecordPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.hasGroup) {
        context.read<TastingProvider>().loadTastingRecords(
          groupId: groupProvider.currentGroup!.id,
        );
      } else {
        context.read<TastingProvider>().loadTastingRecords();
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
      // アプリが復帰した時にデータを再読み込み
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.hasGroup) {
        context.read<TastingProvider>().loadTastingRecords(
          groupId: groupProvider.currentGroup!.id,
        );
      } else {
        context.read<TastingProvider>().loadTastingRecords();
      }
    }
  }

  String _getRatingText(double rating) {
    if (rating >= 4.5) return '★★★★★';
    if (rating >= 3.5) return '★★★★☆';
    if (rating >= 2.5) return '★★★☆☆';
    if (rating >= 1.5) return '★★☆☆☆';
    return '★☆☆☆☆';
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4.0) return Colors.green;
    if (rating >= 3.0) return Colors.blue;
    if (rating >= 2.0) return Colors.orange;
    return Colors.grey;
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
              color: themeSettings.fontColor1.withOpacity(0.7),
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
                  color: themeSettings.fontColor1.withOpacity(0.1),
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
    final tastingProvider = context.read<TastingProvider>();

    // ページが表示されるたびにデータを読み込む
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupProvider = context.read<GroupProvider>();
      if (!tastingProvider.isLoading &&
          tastingProvider.tastingRecords.isEmpty) {
        if (groupProvider.hasGroup) {
          tastingProvider.loadTastingRecords(
            groupId: groupProvider.currentGroup!.id,
          );
        } else {
          tastingProvider.loadTastingRecords();
        }
      }
    });

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
            return Center(
              child: CircularProgressIndicator(color: themeSettings.iconColor),
            );
          }

          if (tastingProvider.tastingRecords.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.coffee,
                    size: 64,
                    color: themeSettings.iconColor.withOpacity(0.5),
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
                      color: themeSettings.fontColor1.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            );
          }

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
                        // 上部: 豆の名前と評価件数
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
                                          .withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 焙煎度合いを表示
                            Row(
                              children: [
                                for (final roast in tastingGroup.roastLevels)
                                  Container(
                                    margin: EdgeInsets.only(right: 4),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getRoastLevelColor(roast),
                                      border: Border.all(
                                        color: _getRoastLevelColor(roast),
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      roast,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _getRoastLevelTextColor(roast),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(width: 8),
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          TastingRecordEditPage(
                                            tastingRecord: latestRecord,
                                          ),
                                    ),
                                  );
                                } else if (value == 'delete') {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('削除確認'),
                                      content: Text('この試飲感想記録を削除しますか？'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: Text('キャンセル'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: Text('削除'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed == true) {
                                    try {
                                      await tastingProvider.deleteTastingRecord(
                                        latestRecord.id,
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text('削除しました')),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text('削除に失敗しました')),
                                      );
                                    }
                                  }
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 20),
                                      SizedBox(width: 8),
                                      Text('編集'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        size: 20,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        '削除',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              child: Icon(
                                Icons.more_vert,
                                color: themeSettings.iconColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        // 中部: 最新の試飲日
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: themeSettings.fontColor1.withOpacity(0.6),
                            ),
                            SizedBox(width: 4),
                            Text(
                              '最新試飲日: ${DateFormat('yyyy/MM/dd').format(latestRecord.tastingDate)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: themeSettings.fontColor1.withOpacity(
                                  0.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        // 平均評価スコア
                        Row(
                          children: [
                            Text(
                              '平均評価: ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: themeSettings.fontColor1,
                              ),
                            ),
                            Text(
                              _getRatingText(tastingGroup.averageRating),
                              style: TextStyle(
                                fontSize: 16,
                                color: _getRatingColor(
                                  tastingGroup.averageRating,
                                ),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '(${tastingGroup.averageRating.toStringAsFixed(1)})',
                              style: TextStyle(
                                fontSize: 14,
                                color: themeSettings.fontColor1.withOpacity(
                                  0.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),

                        // 評価項目の詳細
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: themeSettings.fontColor1.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '評価項目',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: themeSettings.fontColor1.withOpacity(
                                    0.8,
                                  ),
                                ),
                              ),
                              SizedBox(height: 8),
                              _buildRatingRow(
                                '酸味',
                                tastingGroup.averageAcidity,
                                themeSettings,
                              ),
                              _buildRatingRow(
                                '苦味',
                                tastingGroup.averageBitterness,
                                themeSettings,
                              ),
                              _buildRatingRow(
                                '香り',
                                tastingGroup.averageAroma,
                                themeSettings,
                              ),
                              _buildRatingRow(
                                'おいしさ',
                                tastingGroup.averageOverallRating,
                                themeSettings,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 8),

                        // 全体的な印象（存在する場合のみ）
                        if (tastingGroup.allOverallImpressions.isNotEmpty) ...[
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: themeSettings.fontColor1.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.rate_review,
                                  size: 16,
                                  color: themeSettings.fontColor1.withOpacity(
                                    0.6,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '全体的な印象',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: themeSettings.fontColor1
                                              .withOpacity(0.8),
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        tastingGroup.allOverallImpressions.join(
                                          '\n',
                                        ),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: themeSettings.fontColor1
                                              .withOpacity(0.8),
                                        ),
                                        softWrap: true,
                                        maxLines: null,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TastingRecordEditPage()),
          );
        },
        backgroundColor: themeSettings.buttonColor,
        foregroundColor: themeSettings.fontColor2,
        child: Icon(Icons.add),
      ),
    );
  }
}
