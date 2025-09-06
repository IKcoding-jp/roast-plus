import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import '../../models/group_provider.dart';
import '../../models/theme_settings.dart';

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
        title: Text('ローストプラスについて'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.coffee, color: Colors.brown, size: 36),
                SizedBox(width: 12),
                Text(
                  'Roast Plus',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'ローストプラスは、全国のBYSNで働く皆さんのための非公式記録アプリです。\n\n'
              '実際にBYSNで働いている従業員が、仕事のモチベーション向上のために開発しました。\n\n'
              'ロースト記録、試飲感想、ドリップカウンター、スケジュール管理など、コーヒーに関する様々な機能を提供しています。\n\n'
              'グループ機能では、仲間とデータを共有して業務をより効率的にできます。',
              style: TextStyle(fontSize: 15),
            ),
          ],
        ),
        actions: [
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

    try {
      developer.log('グループ作成開始', name: 'GroupCreatePage');

      final success = await groupProvider.createGroup(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      developer.log('グループ作成結果: $success', name: 'GroupCreatePage');

      if (success && mounted) {
        developer.log('ホーム画面に遷移開始', name: 'GroupCreatePage');

        // 成功メッセージを先に表示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('グループを作成しました'), backgroundColor: Colors.green),
        );

        // Web版ではより長い待機時間を設けてFirestoreの同期を確実にする
        final waitTime = kIsWeb
            ? Duration(milliseconds: 2000)
            : Duration(milliseconds: 1000);
        await Future.delayed(waitTime);

        if (mounted) {
          developer.log('ホーム画面遷移開始', name: 'GroupCreatePage');

          try {
            // ホームページに自動遷移
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/',
              (route) => false, // すべてのページをクリア
            );
            developer.log('ホーム画面遷移完了', name: 'GroupCreatePage');
          } catch (e, st) {
            developer.log(
              '遷移エラー: $e',
              name: 'GroupCreatePage',
              error: e,
              stackTrace: st,
              level: 1000,
            );
            // エラーが発生した場合は前の画面に戻る
            if (mounted) {
              Navigator.of(context).pop();
            }
          }
        }
      } else if (mounted) {
        developer.log(
          'グループ作成失敗: ${groupProvider.error}',
          name: 'GroupCreatePage',
          level: 900,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(groupProvider.error ?? 'グループの作成に失敗しました'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, st) {
      developer.log(
        'グループ作成エラー: $e',
        name: 'GroupCreatePage',
        error: e,
        stackTrace: st,
        level: 1000,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 600;

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
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isWeb ? 40.0 : 16.0,
            vertical: 24.0,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isWeb ? 500 : double.infinity,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: isWeb ? 2 : 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isWeb ? 12 : 16),
                    ),
                    color: themeSettings.cardBackgroundColor,
                    child: Padding(
                      padding: EdgeInsets.all(isWeb ? 20 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'グループ情報',
                            style: TextStyle(
                              color: themeSettings.fontColor1,
                              fontSize:
                                  (isWeb ? 20 : 18) *
                                  themeSettings.fontSizeScale,
                              fontWeight: FontWeight.bold,
                              fontFamily: themeSettings.fontFamily,
                            ),
                          ),
                          SizedBox(height: isWeb ? 20 : 16),
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
                                  color: themeSettings.appButtonColor,
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
                          SizedBox(height: isWeb ? 20 : 16),
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
                                  color: themeSettings.appButtonColor,
                                  width: 2,
                                ),
                              ),
                            ),
                            style: TextStyle(
                              color: themeSettings.fontColor1,
                              fontFamily: themeSettings.fontFamily,
                            ),
                            maxLines: isWeb ? 4 : 3,
                            maxLength: 200,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  Card(
                    elevation: isWeb ? 2 : 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isWeb ? 12 : 16),
                    ),
                    color: themeSettings.cardBackgroundColor,
                    child: Padding(
                      padding: EdgeInsets.all(isWeb ? 20 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: themeSettings.iconColor,
                                size: isWeb ? 22 : 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'グループ作成について',
                                style: TextStyle(
                                  color: themeSettings.fontColor1,
                                  fontSize:
                                      (isWeb ? 18 : 16) *
                                      themeSettings.fontSizeScale,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: themeSettings.fontFamily,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isWeb ? 16 : 12),
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
                  SizedBox(height: isWeb ? 32 : 24),
                  ElevatedButton(
                    onPressed: _isCreating ? null : _createGroup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeSettings.appButtonColor,
                      foregroundColor: themeSettings.fontColor2,
                      textStyle: const TextStyle(fontSize: 16),
                      padding: EdgeInsets.symmetric(
                        vertical: isWeb ? 16 : 14,
                        horizontal: isWeb ? 24 : 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isWeb ? 10 : 12),
                      ),
                      elevation: isWeb ? 1 : 2,
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
        ),
      ),
    );
  }
}
