import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../models/theme_settings.dart';
import '../../services/first_login_service.dart';
import '../../services/secure_auth_service.dart';
import 'dart:developer' as developer;

/// 初回ログイン時の表示名設定画面
class DisplayNameSetupPage extends StatefulWidget {
  const DisplayNameSetupPage({super.key});

  @override
  State<DisplayNameSetupPage> createState() => _DisplayNameSetupPageState();
}

class _DisplayNameSetupPageState extends State<DisplayNameSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Googleアカウントの名前を初期値として設定
    _loadGoogleAccountName();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  /// Googleアカウントの名前を初期値として設定
  void _loadGoogleAccountName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.displayName != null) {
      _displayNameController.text = user.displayName!;
    }
  }

  /// 表示名を設定して次に進む
  Future<void> _submitDisplayName() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      developer.log(
        '表示名設定を開始: ${_displayNameController.text.trim()}',
        name: 'DisplayNameSetup',
      );

      final success = await FirstLoginService.setDisplayName(
        _displayNameController.text.trim(),
      );

      if (success) {
        developer.log('表示名設定が完了しました', name: 'DisplayNameSetup');

        // セキュリティイベントを記録
        await SecureAuthService.logSecurityEvent(
          'display_name_setup_completed',
        );

        if (mounted) {
          // 成功メッセージを表示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('表示名を設定しました'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Web版ではより長い待機時間を設けてFirestoreの同期を確実にする
          final waitTime = kIsWeb
              ? Duration(milliseconds: 1000)
              : Duration(milliseconds: 500);
          await Future.delayed(waitTime);

          if (mounted) {
            // グループ参加チェック画面に遷移
            Navigator.of(context).pushReplacementNamed('/');
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _error = '表示名の設定に失敗しました。もう一度お試しください。';
          });
        }
      }
    } catch (e) {
      developer.log('表示名設定でエラーが発生: $e', name: 'DisplayNameSetup');
      if (mounted) {
        setState(() {
          // エラーメッセージをユーザーフレンドリーに調整
          if (e.toString().contains('TimeoutException')) {
            _error = '接続がタイムアウトしました。ネットワーク接続を確認してからもう一度お試しください。';
          } else if (e.toString().contains('INTERNAL ASSERTION FAILED')) {
            _error = 'システムエラーが発生しました。ページを再読み込みしてからもう一度お試しください。';
          } else if (e.toString().contains('network') ||
              e.toString().contains('timeout')) {
            _error = 'ネットワークエラーが発生しました。インターネット接続を確認してからもう一度お試しください。';
          } else {
            _error = '表示名の設定に失敗しました。もう一度お試しください。';
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
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
      backgroundColor: themeSettings.backgroundColor,
      appBar: AppBar(
        title: Text('表示名の設定'),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
        automaticallyImplyLeading: false, // 戻るボタンを無効化
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWeb ? 40.0 : 24.0,
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
                    const SizedBox(height: 40),

                    // アイコン
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: themeSettings.iconColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: themeSettings.iconColor.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.person_add,
                        size: 40,
                        color: themeSettings.iconColor,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // タイトル
                    Text(
                      '表示名を設定してください',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: themeSettings.fontColor1,
                        fontFamily: themeSettings.fontFamily,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // 説明文
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: themeSettings.cardBackgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: themeSettings.iconColor.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 28,
                            color: themeSettings.iconColor,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'グループ内で表示される名前を設定します。\nGoogleアカウント名から名字への変更を推奨します。',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: themeSettings.fontColor1,
                              height: 1.4,
                              fontFamily: themeSettings.fontFamily,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 表示名入力フィールド
                    TextFormField(
                      controller: _displayNameController,
                      decoration: InputDecoration(
                        labelText: '表示名（名字）',
                        hintText: '例: 田中、佐藤',
                        prefixIcon: Icon(
                          Icons.person,
                          color: themeSettings.iconColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: themeSettings.iconColor.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: themeSettings.iconColor,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: themeSettings.cardBackgroundColor,
                      ),
                      style: TextStyle(
                        fontSize: 16,
                        color: themeSettings.fontColor1,
                        fontFamily: themeSettings.fontFamily,
                      ),
                      maxLength: 30,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '表示名を入力してください';
                        }
                        if (value.trim().length < 2) {
                          return '表示名は2文字以上で入力してください';
                        }
                        if (value.trim().length > 30) {
                          return '表示名は30文字以内で入力してください';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // エラーメッセージ
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                  fontFamily: themeSettings.fontFamily,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 32),

                    // 設定ボタン
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitDisplayName,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeSettings.iconColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isSubmitting
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '設定中...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: themeSettings.fontFamily,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                '表示名を設定する',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: themeSettings.fontFamily,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 注意事項
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.security, color: Colors.orange, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '表示名は後から設定画面で変更できます',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 14,
                                fontFamily: themeSettings.fontFamily,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
