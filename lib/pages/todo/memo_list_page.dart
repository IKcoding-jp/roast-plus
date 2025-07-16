import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/theme_settings.dart';
import '../../models/memo_models.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../services/memo_firestore_service.dart';

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
      final groupProvider = context.read<GroupProvider>();
      List<MemoItem> memos;

      if (groupProvider.groups.isNotEmpty) {
        // グループのメモを読み込み
        print('グループメモを読み込み中...');
        memos = await MemoFirestoreService.getGroupMemos(
          groupProvider.groups.first.id,
        );
        print('グループメモ読み込み完了: ${memos.length}件');
      } else {
        // 個人のメモを読み込み
        print('個人メモを読み込み中...');
        memos = await MemoFirestoreService.getMemos();
        print('個人メモ読み込み完了: ${memos.length}件');
      }

      setState(() {
        _memos = memos;
        _isLoading = false;
      });
    } catch (e) {
      print('メモ読み込みエラー: $e');
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
      print('メモ編集権限チェックエラー: $e');
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
        final groupProvider = context.read<GroupProvider>();

        if (groupProvider.groups.isNotEmpty) {
          await MemoFirestoreService.deleteGroupMemo(
            groupProvider.groups.first.id,
            memo.id,
          );
        } else {
          await MemoFirestoreService.deleteMemo(memo.id);
        }

        await _loadMemos();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('メモを削除しました'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        print('メモ削除エラー: $e');
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
      print('メモピン留めエラー: $e');
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
        actions: [IconButton(icon: Icon(Icons.refresh), onPressed: _loadMemos)],
      ),
      backgroundColor: themeSettings.backgroundColor,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: themeSettings.iconColor),
            )
          : _memos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.note_outlined,
                    size: 64,
                    color: themeSettings.iconColor,
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
                      color: themeSettings.fontColor1.withOpacity(0.7),
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
                  color: themeSettings.backgroundColor2 ?? Colors.white,
                  margin: EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: EdgeInsets.all(16),
                    leading: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: memo.isPinned
                            ? Colors.orange.withOpacity(0.2)
                            : themeSettings.iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        memo.isPinned ? Icons.push_pin : Icons.note,
                        color: memo.isPinned
                            ? Colors.orange
                            : themeSettings.iconColor,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      memo.title,
                      style: TextStyle(
                        fontSize: (16 * themeSettings.fontSizeScale).clamp(
                          12.0,
                          24.0,
                        ),
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
                              fontSize: 14 * themeSettings.fontSizeScale,
                              color: themeSettings.fontColor1.withOpacity(0.8),
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
                            color: themeSettings.fontColor1.withOpacity(0.6),
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
                                : themeSettings.iconColor,
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
