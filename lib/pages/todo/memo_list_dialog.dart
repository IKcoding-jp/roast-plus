import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/theme_settings.dart';
import '../../models/memo_models.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../services/memo_firestore_service.dart';

class MemoListDialog extends StatefulWidget {
  const MemoListDialog({super.key});

  @override
  State<MemoListDialog> createState() => _MemoListDialogState();
}

class _MemoListDialogState extends State<MemoListDialog> {
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

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // ヘッダー
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: themeSettings.appBarColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.note,
                    color: themeSettings.appBarTextColor,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '保存されたメモ',
                      style: TextStyle(
                        fontSize: 18 * themeSettings.fontSizeScale,
                        fontWeight: FontWeight.bold,
                        color: themeSettings.appBarTextColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: themeSettings.appBarTextColor,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // メモ一覧
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: themeSettings.iconColor,
                      ),
                    )
                  : _memos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.note_outlined,
                            size: 64,
                            color: themeSettings.todoColor,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'メモがありません',
                            style: TextStyle(
                              fontSize: 18 * themeSettings.fontSizeScale,
                              fontWeight: FontWeight.bold,
                              color: themeSettings.fontColor1,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '新しいメモを作成してください',
                            style: TextStyle(
                              color: themeSettings.fontColor1.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
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
                          child: ListTile(
                            contentPadding: EdgeInsets.all(16),
                            leading: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: memo.isPinned
                                    ? Colors.orange.withValues(alpha: 0.2)
                                    : themeSettings.iconColor.withValues(
                                        alpha: 0.1,
                                      ),
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
                            title: Text(
                              memo.title,
                              style: TextStyle(
                                fontSize: (16 * themeSettings.fontSizeScale)
                                    .clamp(12.0, 24.0),
                                fontWeight: FontWeight.bold,
                                color: themeSettings.fontColor1,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (memo.content.isNotEmpty) ...[
                                  SizedBox(height: 8),
                                  Text(
                                    memo.content,
                                    style: TextStyle(
                                      fontSize:
                                          14 * themeSettings.fontSizeScale,
                                      color: themeSettings.fontColor1
                                          .withValues(alpha: 0.8),
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                SizedBox(height: 8),
                                Text(
                                  '更新: ${_formatDate(memo.updatedAt)}',
                                  style: TextStyle(
                                    fontSize: 12 * themeSettings.fontSizeScale,
                                    color: themeSettings.fontColor1.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
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
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: _canEditMemos
                                      ? () => _deleteMemo(memo)
                                      : null,
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
