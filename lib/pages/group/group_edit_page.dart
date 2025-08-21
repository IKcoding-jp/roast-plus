import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../models/theme_settings.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupEditPage extends StatefulWidget {
  final Group group;

  const GroupEditPage({required this.group, super.key});

  @override
  State<GroupEditPage> createState() => _GroupEditPageState();
}

class _GroupEditPageState extends State<GroupEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _descriptionController = TextEditingController(
      text: widget.group.description,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);

      final updatedGroup = widget.group.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        updatedAt: DateTime.now(),
      );

      final groupProvider = context.read<GroupProvider>();
      final success = await groupProvider.updateGroup(updatedGroup);

      if (success) {
        // グループリストを再読み込みして最新の情報を取得
        await groupProvider.loadUserGroups();
        await groupProvider.loadAllGroupStatistics();
        if (!mounted) return;
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text('グループ設定を更新しました'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(groupProvider.error ?? '更新に失敗しました'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteGroup() async {
    final groupProvider = context.read<GroupProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // 1回目の確認
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('グループを削除'),
        content: Text('本当にこのグループを削除しますか？\nこの操作は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(false),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => navigator.pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('削除'),
          ),
        ],
      ),
    );
    if (confirm1 != true) return;
    // 2回目の確認
    if (!mounted) return;
    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('最終確認'),
        content: Text('本当に本当に削除してもよろしいですか？\nこの操作は完全に取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(false),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => navigator.pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('完全に削除'),
          ),
        ],
      ),
    );
    if (confirm2 != true) return;

    try {
      final success = await groupProvider.deleteGroup(widget.group.id);
      if (success) {
        // HomePage側の削除ページ遷移フラグは使わないためリセット
        groupProvider.resetGroupDeletedPageFlag();
        await groupProvider.loadUserGroups(); // グループリスト再取得
        if (!mounted) return;
        // 参加/招待画面へ即遷移（スタックを全てクリア）
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/group_required', (route) => false);
      } else {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(groupProvider.error ?? '削除に失敗しました'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool get _isLeader {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return widget.group.members.any(
      (m) =>
          m.uid == user.uid &&
          (m.role == GroupRole.leader || m.role == GroupRole.admin),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'グループ設定',
          style: TextStyle(
            color: themeSettings.appBarTextColor,
            fontSize: 20 * themeSettings.fontSizeScale,
            fontWeight: FontWeight.bold,
            fontFamily: themeSettings.fontFamily,
          ),
        ),
        backgroundColor: themeSettings.appBarColor,
        iconTheme: IconThemeData(color: themeSettings.iconColor),
        actions: [
          if (!_isSaving)
            IconButton(
              icon: Icon(Icons.save, color: themeSettings.iconColor),
              onPressed: _saveChanges,
            ),
        ],
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // グループ名
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: themeSettings.cardBackgroundColor,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: themeSettings.iconColor.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.edit,
                                color: themeSettings.iconColor,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'グループ名',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: themeSettings.fontColor1,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'グループ名',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'グループ名を入力してください';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // グループ説明
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: themeSettings.cardBackgroundColor,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: themeSettings.iconColor.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.description,
                                color: themeSettings.iconColor,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'グループ説明',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: themeSettings.fontColor1,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: 'グループの説明',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isLeader) ...[
                  SizedBox(height: 16),
                  // グループ管理
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: themeSettings.cardBackgroundColor,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: themeSettings.iconColor.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.admin_panel_settings,
                                  color: themeSettings.iconColor,
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'グループ管理',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: themeSettings.fontColor1,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.delete, color: Colors.white),
                              label: Text('グループを削除'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 32,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _deleteGroup,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
