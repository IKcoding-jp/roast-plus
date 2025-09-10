import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import '../../models/bean_sticker_models.dart';
import '../../models/theme_settings.dart';
import '../../models/group_provider.dart';

class BeanStickerSettingsPage extends StatefulWidget {
  const BeanStickerSettingsPage({super.key});

  @override
  State<BeanStickerSettingsPage> createState() =>
      _BeanStickerSettingsPageState();
}

class _BeanStickerSettingsPageState extends State<BeanStickerSettingsPage> {
  final TextEditingController _beanNameController = TextEditingController();
  BeanSticker? _editingSticker;
  List<BeanSticker> _beanStickers = [];
  bool _isLoading = true;

  final List<Color> _colorOptions = [
    // 1行目
    Color(0xFFFF0000), // 赤
    Color(0xFFFF8000), // オレンジ
    Color(0xFFFFFF00), // 黄
    Color(0xFF80FF00), // 黄緑
    Color(0xFF00FF00), // 緑
    Color(0xFF00FF80), // エメラルド
    // 2行目
    Color(0xFF00FFFF), // シアン
    Color(0xFF0080FF), // 水色
    Color(0xFF0000FF), // 青
    Color(0xFF8000FF), // 紫
    Color(0xFFFF00FF), // マゼンタ
    Color(0xFFFF0080), // ピンク
    // 3行目
    Color(0xFF800000), // ダークレッド
    Color(0xFFFFA040), // サーモン
    Color(0xFFFFFF80), // クリームイエロー
    Color(0xFFBFFF80), // ライトグリーン
    Color(0xFF40FF80), // ミント
    Color(0xFF80FFC0), // パステルグリーン
    // 4行目
    Color(0xFF80FFFF), // パステルシアン
    Color(0xFF80C0FF), // パステルブルー
    Color(0xFF8080FF), // ラベンダー
    Color(0xFFC080FF), // パステルパープル
    Color(0xFFFF80FF), // パステルピンク
    Color(0xFFFF80C0), // ローズ
    // 5行目
    Color(0xFFB0B0B0), // ライトグレー
    Color(0xFF808080), // グレー
    Color(0xFF404040), // ダークグレー
    Color(0xFF000000), // 黒
    Color(0xFFFFFFFF), // 白
    Color(0xFFFFE4B2), // ベージュ
    // 6行目
    Color(0xFFB5651D), // ブラウン
    Color(0xFF8B4513), // ダークブラウン
    Color(0xFF228B22), // フォレストグリーン
    Color(0xFF4682B4), // スチールブルー
    Color(0xFF4169E1), // ロイヤルブルー
    Color(0xFFDC143C), // クリムゾン
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.groups.isNotEmpty) {
        _loadBeanStickers(groupId: groupProvider.groups.first.id);
      } else {
        _loadBeanStickers();
      }
    });
  }

  Future<void> _loadBeanStickers({String? groupId}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final beanStickerProvider = context.read<BeanStickerProvider>();
      await beanStickerProvider.loadBeanStickers(groupId: groupId);
      if (!mounted) return;
      setState(() {
        _beanStickers = List.from(beanStickerProvider.beanStickers);
        _isLoading = false;
      });
    } catch (e) {
      // 豆ステッカー読み込みエラー
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _beanNameController.dispose();
    super.dispose();
  }

  void _showAddEditDialog({BeanSticker? sticker}) {
    _editingSticker = sticker;
    Color dialogSelectedColor = Colors.red;
    if (sticker != null) {
      _beanNameController.text = sticker.beanName;
      dialogSelectedColor = sticker.stickerColor;
    } else {
      _beanNameController.clear();
      dialogSelectedColor = Colors.red;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 500, // Web版での最大幅を制限
            ),
            child: AlertDialog(
              backgroundColor: Provider.of<ThemeSettings>(
                context,
              ).dialogBackgroundColor,
              titleTextStyle: TextStyle(
                color: Provider.of<ThemeSettings>(context).dialogTextColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              contentTextStyle: TextStyle(
                color: Provider.of<ThemeSettings>(context).dialogTextColor,
                fontSize: 16,
              ),
              title: Text(sticker == null ? '豆のシールを追加' : '豆のシールを編集'),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _beanNameController,
                        decoration: InputDecoration(
                          labelText: '豆の名前',
                          labelStyle: TextStyle(
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).dialogTextColor,
                          ),
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).iconColor,
                            ),
                          ),
                        ),
                        style: TextStyle(
                          color: Provider.of<ThemeSettings>(
                            context,
                          ).dialogTextColor,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'シールの色を選択',
                        style: TextStyle(
                          color: Provider.of<ThemeSettings>(
                            context,
                          ).dialogTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _colorOptions.map((color) {
                          final isSelected = color == dialogSelectedColor;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                dialogSelectedColor = color;
                              });
                            },
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Provider.of<ThemeSettings>(
                      context,
                    ).fontColor1,
                  ),
                  child: Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final beanName = _beanNameController.text.trim();
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
                    if (beanName.isNotEmpty) {
                      try {
                        final provider = context.read<BeanStickerProvider>();
                        final groupProvider = context.read<GroupProvider>();
                        final groupId = groupProvider.groups.isNotEmpty
                            ? groupProvider.groups.first.id
                            : null;

                        if (_editingSticker != null) {
                          // 編集
                          await provider.updateBeanSticker(
                            _editingSticker!.copyWith(
                              beanName: beanName,
                              stickerColor: dialogSelectedColor,
                            ),
                            groupId: groupId,
                          );
                        } else {
                          // 新規追加
                          await provider.addBeanSticker(
                            BeanSticker(
                              id: '',
                              beanName: beanName,
                              stickerColor: dialogSelectedColor,
                              createdAt: DateTime.now(),
                              updatedAt: DateTime.now(),
                            ),
                            groupId: groupId,
                          );
                        }
                        navigator.pop();
                        // データを再読み込み
                        if (!mounted) return;
                        developer.log(
                          '再読み込み開始 - グループ数: ${groupProvider.groups.length}',
                          name: 'BeanStickerSettings',
                        );
                        if (groupProvider.groups.isNotEmpty) {
                          developer.log(
                            'グループモードで再読み込み: ${groupProvider.groups.first.id}',
                            name: 'BeanStickerSettings',
                          );
                          await _loadBeanStickers(
                            groupId: groupProvider.groups.first.id,
                          );
                        } else {
                          developer.log(
                            '個人モードで再読み込み',
                            name: 'BeanStickerSettings',
                          );
                          await _loadBeanStickers();
                        }
                      } catch (e) {
                        // 豆ステッカー保存エラー
                        messenger.showSnackBar(
                          SnackBar(content: Text('保存に失敗しました: $e')),
                        );
                      }
                    } else {
                      messenger.showSnackBar(
                        SnackBar(content: Text('豆の名前を入力してください')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Provider.of<ThemeSettings>(
                      context,
                    ).buttonColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_editingSticker == null ? '追加' : '更新'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _deleteSticker(BeanSticker sticker) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Provider.of<ThemeSettings>(
          context,
        ).dialogBackgroundColor,
        titleTextStyle: TextStyle(
          color: Provider.of<ThemeSettings>(context).dialogTextColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: Provider.of<ThemeSettings>(context).dialogTextColor,
          fontSize: 16,
        ),
        title: Text('削除の確認'),
        content: Text('「${sticker.beanName}」のシール設定を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Provider.of<ThemeSettings>(context).fontColor1,
            ),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                final provider = context.read<BeanStickerProvider>();
                final groupProvider = context.read<GroupProvider>();
                final groupId = groupProvider.groups.isNotEmpty
                    ? groupProvider.groups.first.id
                    : null;
                await provider.deleteBeanSticker(sticker.id, groupId: groupId);
                navigator.pop();
                // データを再読み込み
                if (!mounted) return;
                developer.log(
                  '削除後再読み込み開始 - グループ数: ${groupProvider.groups.length}',
                  name: 'BeanStickerSettings',
                );
                if (groupProvider.groups.isNotEmpty) {
                  developer.log(
                    'グループモードで再読み込み: ${groupProvider.groups.first.id}',
                    name: 'BeanStickerSettings',
                  );
                  await _loadBeanStickers(
                    groupId: groupProvider.groups.first.id,
                  );
                } else {
                  developer.log('個人モードで再読み込み', name: 'BeanStickerSettings');
                  await _loadBeanStickers();
                }
              } catch (e) {
                // 豆ステッカー削除エラー
                messenger.showSnackBar(
                  SnackBar(content: Text('削除に失敗しました: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('削除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('豆のシール設定'),
            // グループ状態バッジを追加
            Consumer<GroupProvider>(
              builder: (context, groupProvider, _) {
                if (groupProvider.groups.isNotEmpty) {
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
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 600, // Web版での最大幅を制限
                ),
                child: Column(
                  children: [
                    // 説明文
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      color: Provider.of<ThemeSettings>(
                        context,
                      ).cardBackgroundColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '豆の種類ごとに色のついた丸シールを設定できます',
                            style: TextStyle(
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).fontColor1,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '設定したシールは、焙煎記録や作業状況記録などで豆の名前の横に表示されます',
                            style: TextStyle(
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).fontColor1.withValues(alpha: 0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // シール一覧
                    Expanded(
                      child: _beanStickers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.label_outline,
                                    size: 64,
                                    color: Provider.of<ThemeSettings>(
                                      context,
                                    ).fontColor1.withValues(alpha: 0.5),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'シール設定がありません',
                                    style: TextStyle(
                                      color: Provider.of<ThemeSettings>(
                                        context,
                                      ).fontColor1.withValues(alpha: 0.7),
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '下のボタンから豆のシールを追加してください',
                                    style: TextStyle(
                                      color: Provider.of<ThemeSettings>(
                                        context,
                                      ).fontColor1.withValues(alpha: 0.5),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.all(16),
                              itemCount: _beanStickers.length,
                              itemBuilder: (context, index) {
                                final sticker = _beanStickers[index];
                                return Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  color: Provider.of<ThemeSettings>(
                                    context,
                                  ).cardBackgroundColor,
                                  margin: EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: sticker.stickerColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    title: Text(
                                      sticker.beanName,
                                      style: TextStyle(
                                        color: Provider.of<ThemeSettings>(
                                          context,
                                        ).fontColor1,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    // subtitle: Text(
                                    //   '例：●${sticker.beanName}',
                                    //   style: TextStyle(
                                    //     color: Provider.of<ThemeSettings>(
                                    //       context,
                                    //     ).fontColor1.withOpacity(0.7),
                                    //     fontSize: 14,
                                    //   ),
                                    // ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.edit,
                                            color: Provider.of<ThemeSettings>(
                                              context,
                                            ).iconColor,
                                          ),
                                          onPressed: () => _showAddEditDialog(
                                            sticker: sticker,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              _deleteSticker(sticker),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: Provider.of<ThemeSettings>(context).buttonColor,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
