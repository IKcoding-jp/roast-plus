import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/theme_settings.dart';
import '../../models/memo_models.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../services/memo_firestore_service.dart';
import '../../utils/web_ui_utils.dart';

class MemoTab extends StatefulWidget {
  const MemoTab({super.key});

  @override
  State<MemoTab> createState() => _MemoTabState();
}

class _MemoTabState extends State<MemoTab> {
  bool _canEditMemos = true;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkEditPermissions();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
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
      debugPrint('メモ編集権限チェックエラー: $e');
    }
  }

  Future<void> _saveMemo() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) return;

    try {
      final memoId = FirebaseFirestore.instance.collection('memos').doc().id;
      final now = DateTime.now();

      final memo = MemoItem(
        id: memoId,
        title: title.isEmpty ? '無題のメモ' : title,
        content: content,
        createdAt: now,
        updatedAt: now,
        isPinned: false,
      );

      // 常に個人のメモを保存
      await MemoFirestoreService.saveMemo(memo);

      _titleController.clear();
      _contentController.clear();

      if (mounted) {
        final themeSettings = Provider.of<ThemeSettings>(
          context,
          listen: false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('メモを保存しました'),
            backgroundColor: themeSettings.appButtonColor,
          ),
        );
      }
    } catch (e) {
      // メモ保存エラー
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('メモの保存に失敗しました'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    // WEB版ではScaffoldを使わず、直接Columnを返す
    if (WebUIUtils.isWeb) {
      return _buildMemoContent(themeSettings);
    }

    // モバイル版では従来通りScaffoldを使用
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildMemoContent(themeSettings),
            // キーボードが開いた時の余白
            SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoContent(ThemeSettings themeSettings) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: themeSettings.cardBackgroundColor,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note_add, color: themeSettings.todoColor, size: 24),
                SizedBox(width: 8),
                Text(
                  '新しいメモ',
                  style: TextStyle(
                    fontSize: 18 * themeSettings.fontSizeScale,
                    fontWeight: FontWeight.bold,
                    color: themeSettings.fontColor1,
                    fontFamily: themeSettings.fontFamily,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            TextField(
              controller: _titleController,
              enabled: _canEditMemos,
              decoration: InputDecoration(
                labelText: 'タイトル',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: themeSettings.todoColor,
                    width: 2,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: (12 * themeSettings.fontSizeScale).clamp(8.0, 20.0),
                ),
              ),
              style: TextStyle(
                color: themeSettings.fontColor1,
                fontSize: (16 * themeSettings.fontSizeScale).clamp(12.0, 24.0),
                fontFamily: themeSettings.fontFamily,
              ),
              maxLines: 1,
            ),
            SizedBox(height: 12),
            TextField(
              controller: _contentController,
              enabled: _canEditMemos,
              decoration: InputDecoration(
                labelText: '内容',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: themeSettings.todoColor,
                    width: 2,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: (12 * themeSettings.fontSizeScale).clamp(8.0, 20.0),
                ),
              ),
              style: TextStyle(
                color: themeSettings.fontColor1,
                fontSize: (16 * themeSettings.fontSizeScale).clamp(12.0, 24.0),
                fontFamily: themeSettings.fontFamily,
              ),
              maxLines: 6,
              minLines: 3,
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _canEditMemos ? _saveMemo : null,
                icon: Icon(Icons.save, size: 18),
                label: Text('保存'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeSettings.appButtonColor,
                  foregroundColor: themeSettings.fontColor2,
                  textStyle: const TextStyle(fontSize: 16),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
