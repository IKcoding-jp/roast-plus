import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../models/theme_settings.dart';

class GroupMemberInvitePage extends StatefulWidget {
  final Group group;

  const GroupMemberInvitePage({required this.group, super.key});

  @override
  State<GroupMemberInvitePage> createState() => _GroupMemberInvitePageState();
}

class _GroupMemberInvitePageState extends State<GroupMemberInvitePage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isInviting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _inviteMember() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isInviting = true;
    });

    final groupProvider = context.read<GroupProvider>();
    final success = await groupProvider.inviteMember(
      groupId: widget.group.id,
      email: _emailController.text.trim(),
    );

    if (success && mounted) {
      _emailController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_emailController.text.trim()}に招待を送信しました'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(groupProvider.error ?? '招待の送信に失敗しました'),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _isInviting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'メンバーを招待',
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
                color: themeSettings.cardBackgroundColor,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '招待情報',
                        style: TextStyle(
                          color: themeSettings.fontColor1,
                          fontSize: 18 * themeSettings.fontSizeScale,
                          fontWeight: FontWeight.bold,
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'メールアドレス *',
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
                          hintText: 'example@gmail.com',
                        ),
                        style: TextStyle(
                          color: themeSettings.fontColor1,
                          fontFamily: themeSettings.fontFamily,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'メールアドレスを入力してください';
                          }
                          final emailRegex = RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          );
                          if (!emailRegex.hasMatch(value.trim())) {
                            return '有効なメールアドレスを入力してください';
                          }
                          return null;
                        },
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
                color: themeSettings.cardBackgroundColor,
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
                            '招待について',
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
                        '• 招待されたユーザーは7日間以内に参加を選択できます\n'
                        '• 招待されたユーザーはメンバーとして参加します\n'
                        '• メンバーはデータの閲覧のみ可能です\n'
                        '• 管理者・リーダーは後からメンバーの権限を変更できます',
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
                onPressed: _isInviting ? null : _inviteMember,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeSettings.buttonColor,
                  foregroundColor: themeSettings.fontColor2,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isInviting
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
                            '招待中...',
                            style: TextStyle(
                              fontSize: 16 * themeSettings.fontSizeScale,
                              fontWeight: FontWeight.bold,
                              fontFamily: themeSettings.fontFamily,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        '招待を送信',
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
