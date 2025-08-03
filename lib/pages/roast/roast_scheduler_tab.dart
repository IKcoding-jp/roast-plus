// ignore_for_file: unnecessary_null_comparison

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roastplus/models/roast_schedule_models.dart';
import 'package:roastplus/models/theme_settings.dart';
import 'package:roastplus/models/group_provider.dart';
import 'package:roastplus/services/roast_schedule_memo_service.dart';
import 'package:roastplus/widgets/roast_schedule_memo_dialog.dart';
import 'package:roastplus/widgets/bean_name_with_sticker.dart';

class RoastSchedulerTab extends StatefulWidget {
  final List<dynamic> breakTimes;
  const RoastSchedulerTab({super.key, this.breakTimes = const []});

  @override
  State<RoastSchedulerTab> createState() => RoastSchedulerTabState();
}

class RoastSchedulerTabState extends State<RoastSchedulerTab>
    with AutomaticKeepAliveClientMixin {
  late RoastScheduleMemoProvider _memoProvider;
  bool _isLoading = true;
  String? _groupId;

  @override
  void initState() {
    super.initState();
    _memoProvider = RoastScheduleMemoProvider();

    // 次のフレームでメモを読み込む（Providerが安全に利用可能になるため）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadMemos();
      }
    });
  }

  Future<void> _loadMemos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (!mounted) return;

      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.groups.isNotEmpty) {
        _groupId = groupProvider.groups.first.id;
        final memos = await RoastScheduleMemoService.getGroupMemos(_groupId!);
        if (mounted) {
          _memoProvider.setMemos(memos);
        }
      } else {
        _groupId = null;
        final memos = await RoastScheduleMemoService.getUserMemos();
        if (mounted) {
          _memoProvider.setMemos(memos);
        }
      }
    } catch (e) {
      print('メモ読み込みエラー: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addMemo() async {
    if (!mounted) return;

    final memo = await showDialog<RoastScheduleMemo>(
      context: context,
      builder: (context) => RoastScheduleMemoDialog(
        onSave: (memo) async {
          try {
            await RoastScheduleMemoService.addMemo(memo, groupId: _groupId);
            if (mounted) {
              await _loadMemos();
            }
          } catch (e) {
            print('メモ追加エラー: $e');
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('メモの追加に失敗しました')));
            }
          }
        },
      ),
    );
  }

  Future<void> _editMemo(RoastScheduleMemo memo) async {
    if (!mounted) return;

    final updatedMemo = await showDialog<RoastScheduleMemo>(
      context: context,
      builder: (context) => RoastScheduleMemoDialog(
        memo: memo,
        onSave: (updatedMemo) async {
          try {
            await RoastScheduleMemoService.updateMemo(
              updatedMemo,
              groupId: _groupId,
            );
            if (mounted) {
              await _loadMemos();
            }
          } catch (e) {
            print('メモ更新エラー: $e');
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('メモの更新に失敗しました')));
            }
          }
        },
      ),
    );
  }

  Future<void> _deleteMemo(String memoId) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('メモを削除'),
        content: Text('このメモを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('削除'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await RoastScheduleMemoService.deleteMemo(memoId, groupId: _groupId);
        if (mounted) {
          await _loadMemos();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('メモを削除しました')));
        }
      } catch (e) {
        print('メモ削除エラー: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('メモの削除に失敗しました')));
        }
      }
    }
  }

  Widget _buildMemoCard(RoastScheduleMemo memo) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => _editMemo(memo),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // 時間（アフターパージ以外の場合のみ表示）またはアフターパージのアイコン
              if (!memo.isAfterPurge) ...[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: themeSettings.iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    memo.time,
                    style: TextStyle(
                      color: themeSettings.iconColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ] else ...[
                // アフターパージの場合はアイコンを時間の位置に表示
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.ac_unit, color: Colors.blue, size: 18),
                ),
              ],
              SizedBox(width: 12),

              // メモ内容
              Expanded(
                child: Row(
                  children: [
                    if (memo.isAfterPurge) ...[
                      // アフターパージの場合
                      Expanded(
                        child: Text(
                          'アフターパージ',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ] else if (memo.isRoasterOn) ...[
                      // 焙煎機オンの場合
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              color: Colors.orange,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              '焙煎機オン',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // 通常の焙煎メモの場合
                      Expanded(
                        child: Row(
                          children: [
                            // 豆の名前
                            if (memo.beanName != null) ...[
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.coffee,
                                      color: Colors.brown,
                                      size: 16,
                                    ),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        memo.beanName!,
                                        style: TextStyle(
                                          color: Colors.brown,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 12),
                            ],

                            // 重さと個数
                            if (memo.weight != null ||
                                memo.quantity != null) ...[
                              Expanded(
                                flex: 2,
                                child: Text(
                                  [
                                    if (memo.weight != null) '${memo.weight}g',
                                    if (memo.weight != null &&
                                        memo.quantity != null)
                                      '×',
                                    if (memo.quantity != null)
                                      '${memo.quantity}袋',
                                  ].join(' '),
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(width: 12),
                            ],

                            // 焙煎度合い
                            if (memo.roastLevel != null) ...[
                              Expanded(
                                flex: 1,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getRoastLevelColor(
                                      memo.roastLevel!,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: _getRoastLevelColor(
                                        memo.roastLevel!,
                                      ).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    _getShortRoastLevel(memo.roastLevel!),
                                    style: TextStyle(
                                      color: _getRoastLevelColor(
                                        memo.roastLevel!,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 削除ボタン
              IconButton(
                onPressed: () => _deleteMemo(memo.id),
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.red[400],
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRoastLevelColor(String roastLevel) {
    switch (roastLevel) {
      case '浅煎り':
        return Color(0xFFD2B48C); // タン色（非常に明るい茶色）
      case '中浅煎り':
        return Color(0xFFBC8F8F); // ローズブラウン（明るい茶色）
      case '中煎り':
        return Color(0xFF8B4513); // サドルブラウン（中程度の茶色）
      case '中深煎り':
        return Color(0xFF654321); // ダークブラウン（濃い茶色、赤みがかった）
      case '深煎り':
        return Color(0xFF2F1B14); // ほぼ黒（非常に濃い茶色）
      default:
        return Colors.grey[700]!;
    }
  }

  String _getShortRoastLevel(String roastLevel) {
    switch (roastLevel) {
      case '浅煎り':
        return '浅';
      case '中浅煎り':
        return '中浅';
      case '中煎り':
        return '中';
      case '中深煎り':
        return '中深';
      case '深煎り':
        return '深';
      default:
        return roastLevel;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: _addMemo,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        child: Icon(Icons.add),
        elevation: 6,
      ),
      body: Column(
        children: [
          // ヘッダー
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.schedule, color: themeSettings.iconColor, size: 24),
                SizedBox(width: 8),
                Text(
                  'ローストスケジュールメモ',
                  style: TextStyle(
                    color: themeSettings.fontColor1,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // メモリスト
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : ChangeNotifierProvider.value(
                    value: _memoProvider,
                    child: Consumer<RoastScheduleMemoProvider>(
                      builder: (context, provider, child) {
                        if (provider.memos.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.note_add,
                                  size: 64,
                                  color: themeSettings.fontColor2.withOpacity(
                                    0.5,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'メモがありません',
                                  style: TextStyle(
                                    color: themeSettings.fontColor2,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '右下の「+」ボタンから新しいメモを作成してください',
                                  style: TextStyle(
                                    color: themeSettings.fontColor2.withOpacity(
                                      0.7,
                                    ),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          itemCount: provider.memos.length,
                          itemBuilder: (context, index) {
                            return _buildMemoCard(provider.memos[index]);
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
