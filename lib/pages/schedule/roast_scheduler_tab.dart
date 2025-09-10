// ignore_for_file: unnecessary_null_comparison

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roastplus/models/roast_schedule_models.dart';
import 'package:roastplus/models/theme_settings.dart';
import 'package:roastplus/models/group_provider.dart';
import 'package:roastplus/services/roast_schedule_memo_service.dart';
import 'package:roastplus/widgets/roast_schedule_memo_dialog.dart';
import 'package:roastplus/utils/permission_utils.dart';
import 'dart:developer' as developer;
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
  bool _canEditRoastSchedule = true;
  StreamSubscription<List<RoastScheduleMemo>>? _memoSubscription;
  VoidCallback? _groupProviderListener;
  GroupProvider? _cachedGroupProvider;

  @override
  void initState() {
    super.initState();
    _memoProvider = RoastScheduleMemoProvider();

    // 次のフレームでメモを読み込む（Providerが安全に利用可能になるため）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadMemos();
        _setupGroupChangeListener();
        _checkEditPermission();
        _subscribeMemosForToday();
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
        // 今日の日付のメモを取得
        final today = DateTime.now();
        final memos = await RoastScheduleMemoService.getGroupMemosForDate(
          _groupId!,
          today,
        );
        if (mounted) {
          _memoProvider.setMemos(memos);
        }
      } else {
        _groupId = null;
        // 今日の日付のメモを取得
        final today = DateTime.now();
        final memos = await RoastScheduleMemoService.getUserMemosForDate(today);
        if (mounted) {
          _memoProvider.setMemos(memos);
        }
      }
    } catch (e) {
      developer.log('メモ読み込みエラー: $e', name: 'RoastSchedulerTab');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setupGroupChangeListener() {
    final groupProvider = context.read<GroupProvider>();
    _cachedGroupProvider = groupProvider;
    _groupProviderListener?.call(); // 既存があれば一度呼んで解除
    _groupProviderListener = () {
      if (!mounted) return;
      final newGroupId = groupProvider.groups.isNotEmpty
          ? groupProvider.groups.first.id
          : null;
      if (_groupId != newGroupId) {
        developer.log(
          'RoastSchedulerTab: グループ変更検知 - 旧: $_groupId, 新: $newGroupId',
          name: 'RoastSchedulerTab',
        );
        _groupId = newGroupId;
        _checkEditPermission();
        _subscribeMemosForToday();
      }
    };
    groupProvider.addListener(_groupProviderListener!);
  }

  Future<void> _checkEditPermission() async {
    try {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.groups.isEmpty) {
        // 個人メモは常に編集可
        setState(() {
          _canEditRoastSchedule = true;
        });
        return;
      }
      final groupId = groupProvider.groups.first.id;
      final canEdit = await PermissionUtils.canEditDataType(
        groupId: groupId,
        dataType: 'roast_schedule',
      );
      if (!mounted) return;
      setState(() {
        _canEditRoastSchedule = canEdit;
      });
      developer.log(
        'RoastSchedulerTab: 権限チェック - groupId=$groupId, canEdit=$canEdit',
        name: 'RoastSchedulerTab',
      );
    } catch (e, st) {
      developer.log(
        'RoastSchedulerTab: 権限チェックエラー: $e',
        name: 'RoastSchedulerTab',
        error: e,
        stackTrace: st,
      );
    }
  }

  void _subscribeMemosForToday() {
    _memoSubscription?.cancel();
    final today = DateTime.now();
    try {
      Stream<List<RoastScheduleMemo>> stream;
      if (_groupId != null && _groupId!.isNotEmpty) {
        stream = RoastScheduleMemoService.watchGroupMemosForDate(
          _groupId!,
          today,
        );
        developer.log(
          'RoastSchedulerTab: グループ購読開始: groupId=$_groupId, date=${today.toIso8601String().split('T')[0]}',
          name: 'RoastSchedulerTab',
        );
      } else {
        stream = RoastScheduleMemoService.watchUserMemosForDate(today);
        developer.log(
          'RoastSchedulerTab: 個人購読開始: date=${today.toIso8601String().split('T')[0]}',
          name: 'RoastSchedulerTab',
        );
      }

      _memoSubscription = stream.listen(
        (memos) {
          if (!mounted) return;
          _memoProvider.setMemos(memos);
          if (_isLoading) {
            setState(() {
              _isLoading = false;
            });
          }
        },
        onError: (e, st) {
          developer.log(
            'RoastSchedulerTab: メモ購読エラー: $e',
            name: 'RoastSchedulerTab',
            error: e,
            stackTrace: st,
          );
        },
      );
    } catch (e, st) {
      developer.log(
        'RoastSchedulerTab: 購読開始エラー: $e',
        name: 'RoastSchedulerTab',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _addMemo() async {
    if (!mounted) return;

    await showDialog<RoastScheduleMemo>(
      context: context,
      builder: (dialogContext) => RoastScheduleMemoDialog(
        onSave: (memo) async {
          try {
            await RoastScheduleMemoService.addMemo(memo, groupId: _groupId);
          } catch (e) {
            developer.log('メモ追加エラー: $e', name: 'RoastSchedulerTab');
            if (mounted && dialogContext.mounted) {
              ScaffoldMessenger.of(
                dialogContext,
              ).showSnackBar(SnackBar(content: Text('メモの追加に失敗しました')));
            }
          }
        },
      ),
    );
  }

  Future<void> _editMemo(RoastScheduleMemo memo) async {
    if (!mounted) return;

    await showDialog<RoastScheduleMemo>(
      context: context,
      builder: (dialogContext) => RoastScheduleMemoDialog(
        memo: memo,
        onSave: (updatedMemo) async {
          try {
            await RoastScheduleMemoService.updateMemo(
              updatedMemo,
              groupId: _groupId,
            );
          } catch (e) {
            developer.log('メモ更新エラー: $e', name: 'RoastSchedulerTab');
            if (mounted && dialogContext.mounted) {
              ScaffoldMessenger.of(
                dialogContext,
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
      builder: (dialogContext) => AlertDialog(
        title: Text('メモを削除'),
        content: Text('このメモを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await RoastScheduleMemoService.deleteMemo(memoId, groupId: _groupId);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('メモを削除しました')));
        }
      } catch (e) {
        developer.log('メモ削除エラー: $e', name: 'RoastSchedulerTab');
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
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: Colors.white,
      child: InkWell(
        onTap: _canEditRoastSchedule ? () => _editMemo(memo) : null,
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
                    color: themeSettings.iconColor.withValues(alpha: 0.1),
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
                    color: Colors.blue.withValues(alpha: 0.1),
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
                                child: BeanNameWithSticker(
                                  beanName: memo.beanName!,
                                  textStyle: TextStyle(
                                    color: Colors.brown,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  stickerSize: 14,
                                ),
                              ),
                              SizedBox(width: 12),
                            ],

                            // 重さと個数
                            if (memo.weight != null ||
                                memo.quantity != null) ...[
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: Text(
                                    [
                                      if (memo.weight != null)
                                        '${memo.weight}g',
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
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: _getRoastLevelColor(
                                        memo.roastLevel!,
                                      ).withValues(alpha: 0.3),
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
                onPressed: _canEditRoastSchedule
                    ? () => _deleteMemo(memo.id)
                    : null,
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
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: _canEditRoastSchedule ? _addMemo : null,
        backgroundColor: themeSettings.appButtonColor,
        foregroundColor: themeSettings.fontColor2,
        elevation: 6,
        child: Icon(Icons.add),
      ),
      body: Column(
        children: [
          // ヘッダー
          Container(
            padding: EdgeInsets.all(16),
            child: Row(children: []),
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
                                  color: themeSettings.fontColor1.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'メモがありません',
                                  style: TextStyle(
                                    color: themeSettings.fontColor1,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '右下の「+」ボタンから新しいメモを作成してください',
                                  style: TextStyle(
                                    color: themeSettings.fontColor1.withValues(
                                      alpha: 0.7,
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

  @override
  void dispose() {
    _memoSubscription?.cancel();
    if (_groupProviderListener != null && _cachedGroupProvider != null) {
      try {
        _cachedGroupProvider!.removeListener(_groupProviderListener!);
      } catch (_) {}
    }
    super.dispose();
  }
}
