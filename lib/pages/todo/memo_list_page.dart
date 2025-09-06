import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/theme_settings.dart';
import '../../models/memo_models.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../services/memo_firestore_service.dart';
import '../../utils/web_ui_utils.dart';

class MemoListPage extends StatefulWidget {
  const MemoListPage({super.key});

  @override
  State<MemoListPage> createState() => _MemoListPageState();
}

class _MemoListPageState extends State<MemoListPage> {
  List<MemoItem> _memos = [];
  bool _isLoading = true;
  bool _canEditMemos = true;

  @override
  void initState() {
    super.initState();
    _loadMemos();
    _checkEditPermissions();
  }

  Future<void> _loadMemos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 常に個人メモを読み込み
      final memos = await MemoFirestoreService.getMemos();

      setState(() {
        _memos = memos;
        _isLoading = false;
      });
    } catch (e) {
      // メモ読み込みエラー
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkEditPermissions() async {
    try {
      final groupProvider = context.read<GroupProvider>();

      if (groupProvider.groups.isNotEmpty) {
        final group = groupProvider.groups.first;
        final currentUser = FirebaseAuth.instance.currentUser;

        if (currentUser != null) {
          final userRole = group.getMemberRole(currentUser.uid);
          final groupSettings = groupProvider.getCurrentGroupSettings();

          if (groupSettings != null) {
            final canEditMemos = groupSettings.canEditDataType(
              'memos',
              userRole ?? GroupRole.member,
            );

            setState(() {
              _canEditMemos = canEditMemos;
            });
          }
        }
      }
    } catch (e) {
      // メモ編集権限チェックエラー
    }
  }

  Future<void> _deleteMemo(MemoItem memo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('メモを削除'),
        content: Text('このメモを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // 常に個人メモを削除
        await MemoFirestoreService.deleteMemo(memo.id);
        await _loadMemos();

        if (mounted) {
          final themeSettings = Provider.of<ThemeSettings>(
            context,
            listen: false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('メモを削除しました'),
              backgroundColor: themeSettings.appButtonColor,
            ),
          );
        }
      } catch (e) {
        // メモ削除エラー
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('メモの削除に失敗しました'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _togglePinMemo(MemoItem memo) async {
    try {
      await MemoFirestoreService.togglePinMemo(memo.id, !memo.isPinned);
      await _loadMemos();
    } catch (e) {
      debugPrint('メモピン留めエラー: $e');
    }
  }

  // 編集も個人メモのみ
  Future<void> _editMemo(
    MemoItem memo,
    String newTitle,
    String newContent,
  ) async {
    final updatedMemo = memo.copyWith(
      title: newTitle,
      content: newContent,
      updatedAt: DateTime.now(),
    );
    try {
      await MemoFirestoreService.updateMemo(updatedMemo);
      await _loadMemos();
      if (mounted) {
        final themeSettings = Provider.of<ThemeSettings>(
          context,
          listen: false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('メモを更新しました'),
            backgroundColor: themeSettings.appButtonColor,
          ),
        );
      }
    } catch (e) {
      debugPrint('メモ更新エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('メモの更新に失敗しました'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showEditMemoDialog(MemoItem memo) async {
    final titleController = TextEditingController(text: memo.title);
    final contentController = TextEditingController(text: memo.content);
    final themeSettings = Provider.of<ThemeSettings>(context, listen: false);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'メモを編集',
          style: TextStyle(
            fontSize: kIsWeb ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: themeSettings.fontColor1,
            fontFamily: themeSettings.fontFamily,
          ),
        ),
        contentPadding: EdgeInsets.all(kIsWeb ? 32 : 24),
        content: SizedBox(
          width: kIsWeb ? 600 : double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'タイトル',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: themeSettings.todoColor,
                        width: 2,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: kIsWeb ? 16 : 12,
                    ),
                  ),
                  style: TextStyle(
                    color: themeSettings.fontColor1,
                    fontFamily: themeSettings.fontFamily,
                    fontSize: kIsWeb ? 18 : 16,
                  ),
                ),
                SizedBox(height: kIsWeb ? 24 : 16),
                TextField(
                  controller: contentController,
                  decoration: InputDecoration(
                    labelText: '内容',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: themeSettings.todoColor,
                        width: 2,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: kIsWeb ? 16 : 12,
                    ),
                  ),
                  style: TextStyle(
                    color: themeSettings.fontColor1,
                    fontFamily: themeSettings.fontFamily,
                    fontSize: kIsWeb ? 16 : 14,
                  ),
                  maxLines: kIsWeb ? 12 : 8,
                  minLines: kIsWeb ? 8 : 5,
                ),
              ],
            ),
          ),
        ),
        actionsPadding: EdgeInsets.fromLTRB(
          kIsWeb ? 32 : 24,
          0,
          kIsWeb ? 32 : 24,
          kIsWeb ? 32 : 24,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: kIsWeb ? 24 : 16,
                vertical: kIsWeb ? 12 : 8,
              ),
            ),
            child: Text(
              'キャンセル',
              style: TextStyle(
                fontSize: kIsWeb ? 16 : 14,
                fontFamily: themeSettings.fontFamily,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop({
                'title': titleController.text.trim(),
                'content': contentController.text.trim(),
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: themeSettings.appButtonColor,
              foregroundColor: themeSettings.fontColor2,
              padding: EdgeInsets.symmetric(
                horizontal: kIsWeb ? 24 : 16,
                vertical: kIsWeb ? 12 : 8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              '保存',
              style: TextStyle(
                fontSize: kIsWeb ? 16 : 14,
                fontFamily: themeSettings.fontFamily,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      await _editMemo(memo, result['title']!, result['content']!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('保存されたメモ'),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
        iconTheme: IconThemeData(color: themeSettings.todoColor),
        actions: [IconButton(icon: Icon(Icons.refresh), onPressed: _loadMemos)],
      ),
      backgroundColor: themeSettings.backgroundColor,
      body: WebUIUtils.isWeb
          ? _buildWebLayout(themeSettings)
          : _buildMobileLayout(themeSettings),
    );
  }

  Widget _buildWebLayout(ThemeSettings themeSettings) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 800),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: _buildMemoContent(themeSettings),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(ThemeSettings themeSettings) {
    return _buildMemoContent(themeSettings);
  }

  Widget _buildMemoContent(ThemeSettings themeSettings) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: themeSettings.iconColor),
      );
    }

    if (_memos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_outlined, size: 64, color: themeSettings.todoColor),
            SizedBox(height: 16),
            Text(
              'メモがありません',
              style: TextStyle(
                fontSize: 18 * themeSettings.fontSizeScale,
                fontWeight: FontWeight.bold,
                color: themeSettings.fontColor1,
                fontFamily: themeSettings.fontFamily,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '新しいメモを作成してください',
              style: TextStyle(
                color: themeSettings.fontColor1.withValues(alpha: 0.7),
                fontFamily: themeSettings.fontFamily,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _memos.length,
      itemBuilder: (context, index) {
        final memo = _memos[index];
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: themeSettings.cardBackgroundColor,
          margin: EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: _canEditMemos ? () => _showEditMemoDialog(memo) : null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: memo.isPinned
                              ? Colors.orange.withValues(alpha: 0.2)
                              : themeSettings.iconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          memo.isPinned ? Icons.push_pin : Icons.note,
                          color: memo.isPinned
                              ? Colors.orange
                              : themeSettings.todoColor,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          memo.title,
                          style: TextStyle(
                            fontSize: (16 * themeSettings.fontSizeScale).clamp(
                              12.0,
                              24.0,
                            ),
                            fontWeight: FontWeight.bold,
                            color: themeSettings.fontColor1,
                            fontFamily: themeSettings.fontFamily,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.edit,
                              color: themeSettings.todoColor,
                            ),
                            onPressed: _canEditMemos
                                ? () => _showEditMemoDialog(memo)
                                : null,
                            tooltip: '編集',
                          ),
                          IconButton(
                            icon: Icon(
                              memo.isPinned
                                  ? Icons.push_pin
                                  : Icons.push_pin_outlined,
                              color: memo.isPinned
                                  ? Colors.orange
                                  : themeSettings.todoColor,
                            ),
                            onPressed: _canEditMemos
                                ? () => _togglePinMemo(memo)
                                : null,
                            tooltip: memo.isPinned ? 'ピン留め解除' : 'ピン留め',
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: _canEditMemos
                                ? () => _deleteMemo(memo)
                                : null,
                            tooltip: '削除',
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (memo.content.isNotEmpty) ...[
                    SizedBox(height: 12),
                    Text(
                      memo.content,
                      style: TextStyle(
                        fontSize: 14 * themeSettings.fontSizeScale,
                        color: themeSettings.fontColor1.withValues(alpha: 0.8),
                        fontFamily: themeSettings.fontFamily,
                      ),
                    ),
                  ],
                  SizedBox(height: 12),
                  Text(
                    '更新: ${_formatDate(memo.updatedAt)}',
                    style: TextStyle(
                      fontSize: 12 * themeSettings.fontSizeScale,
                      color: themeSettings.fontColor1.withValues(alpha: 0.6),
                      fontFamily: themeSettings.fontFamily,
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '今日';
    } else if (difference.inDays == 1) {
      return '昨日';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}日前';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}
