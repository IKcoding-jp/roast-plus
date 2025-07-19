import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/group_provider.dart';
import '../../models/theme_settings.dart';
import '../../app.dart';

class GroupCreatePage extends StatefulWidget {
  const GroupCreatePage({super.key});

  @override
  State<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends State<GroupCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    final groupProvider = context.read<GroupProvider>();

    // 既にグループに参加している場合はエラーメッセージを表示
    if (groupProvider.hasGroup) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('既にグループに参加しています。1つのグループのみ参加可能です。'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ご注意'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person, color: Colors.blue, size: 32),
                SizedBox(width: 12),
                Icon(Icons.arrow_forward, color: Colors.grey, size: 28),
                SizedBox(width: 12),
                Icon(Icons.groups, color: Colors.orange, size: 36),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'グループに参加すると、今後はグループ全体で共有されるデータが表示・保存されます。\n\nグループを脱退すれば、もとの個人データに自動で切り替わります。\n\nこのまま進めてもよろしいですか？',
              style: TextStyle(fontSize: 15),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('OK'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _isCreating = true;
    });
    final success = await groupProvider.createGroup(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
    );

    if (success && mounted) {
      // ホーム画面に遷移（全ての画面をクリアしてメインアプリに戻る）
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WorkAssignmentApp()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('グループを作成しました'), backgroundColor: Colors.green),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(groupProvider.error ?? 'グループの作成に失敗しました'),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _isCreating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'グループ作成',
          style: TextStyle(
            color: themeSettings.appBarTextColor,
            fontSize: 20 * themeSettings.fontSizeScale,
            fontWeight: FontWeight.bold,
            fontFamily: themeSettings.fontFamily,
          ),
        ),
        backgroundColor: themeSettings.appBarColor,
        iconTheme: IconThemeData(color: themeSettings.iconColor),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: themeSettings.backgroundColor2 ?? Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'グループ情報',
                        style: TextStyle(
                          color: themeSettings.fontColor1,
                          fontSize: 18 * themeSettings.fontSizeScale,
                          fontWeight: FontWeight.bold,
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'グループ名 *',
                          labelStyle: TextStyle(
                            color: themeSettings.fontColor1,
                            fontFamily: themeSettings.fontFamily,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: themeSettings.buttonColor,
                              width: 2,
                            ),
                          ),
                        ),
                        style: TextStyle(
                          color: themeSettings.fontColor1,
                          fontFamily: themeSettings.fontFamily,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'グループ名を入力してください';
                          }
                          if (value.trim().length < 2) {
                            return 'グループ名は2文字以上で入力してください';
                          }
                          if (value.trim().length > 50) {
                            return 'グループ名は50文字以下で入力してください';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: '説明',
                          labelStyle: TextStyle(
                            color: themeSettings.fontColor1,
                            fontFamily: themeSettings.fontFamily,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: themeSettings.buttonColor,
                              width: 2,
                            ),
                          ),
                        ),
                        style: TextStyle(
                          color: themeSettings.fontColor1,
                          fontFamily: themeSettings.fontFamily,
                        ),
                        maxLines: 3,
                        maxLength: 200,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: themeSettings.backgroundColor2 ?? Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: themeSettings.iconColor,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'グループ作成について',
                            style: TextStyle(
                              color: themeSettings.fontColor1,
                              fontSize: 16 * themeSettings.fontSizeScale,
                              fontWeight: FontWeight.bold,
                              fontFamily: themeSettings.fontFamily,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        '• グループを作成すると、あなたが管理者になります\n'
                        '• 管理者・リーダーはメンバーの招待・削除・権限変更ができます\n'
                        '• メンバーはデータの閲覧のみ可能です\n'
                        '• グループ内でデータを共有・同期できます\n'
                        '• グループアイコンは、グループを識別するために様々な画面で表示されます',
                        style: TextStyle(
                          color: themeSettings.fontColor1,
                          fontSize: 14 * themeSettings.fontSizeScale,
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Spacer(),
              ElevatedButton(
                onPressed: _isCreating ? null : _createGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeSettings.buttonColor,
                  foregroundColor: themeSettings.fontColor2,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isCreating
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                themeSettings.fontColor2,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            '作成中...',
                            style: TextStyle(
                              fontSize: 16 * themeSettings.fontSizeScale,
                              fontWeight: FontWeight.bold,
                              fontFamily: themeSettings.fontFamily,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'グループを作成',
                        style: TextStyle(
                          fontSize: 16 * themeSettings.fontSizeScale,
                          fontWeight: FontWeight.bold,
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
