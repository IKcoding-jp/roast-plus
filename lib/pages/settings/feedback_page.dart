import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/theme_settings.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  String _selectedCategory = '要望・改善案';
  bool _isLoading = false;

  final List<String> _categories = ['要望・改善案', 'バグ報告', 'その他'];

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendFeedback() async {
    if (_subjectController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('件名を入力してください')));
      return;
    }

    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('メッセージを入力してください')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final subject =
          '【BysnLog】$_selectedCategory: ${_subjectController.text.trim()}';
      final body =
          '''
カテゴリ: $_selectedCategory

メッセージ:
${_messageController.text.trim()}

---
このメッセージはBysnLogアプリのフィードバック機能から送信されました。
''';

      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: 'kensaku.ikeda04@gmail.com',
        queryParameters: {'subject': subject, 'body': body},
      );

      print('メールURI起動を試行中: $emailUri');

      if (await canLaunchUrl(emailUri)) {
        print('URL起動可能、起動を試行中...');
        final result = await launchUrl(
          emailUri,
          mode: LaunchMode.externalApplication,
        );
        print('起動結果: $result');

        if (result) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('メールアプリが開きました')));
          Navigator.pop(context);
        } else {
          throw Exception('メールアプリの起動に失敗しました');
        }
      } else {
        print('URL起動不可: $emailUri');
        throw Exception('メールアプリを開けませんでした。デバイスにメールアプリがインストールされているか確認してください。');
      }
    } catch (e) {
      print('フィードバック送信エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラーが発生しました: $e'),
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('フィードバック'),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
      ),
      body: Container(
        color: themeSettings.backgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: themeSettings.backgroundColor2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'フィードバックを送信',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: themeSettings.fontColor1,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '要望・改善案、バグ報告、その他のご意見をお聞かせください。',
                        style: TextStyle(
                          fontSize: 14,
                          color: themeSettings.fontColor1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: themeSettings.backgroundColor2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'カテゴリ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: themeSettings.fontColor1,
                        ),
                      ),
                      SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: themeSettings.inputBackgroundColor,
                        ),
                        items: _categories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(
                              category,
                              style: TextStyle(color: themeSettings.fontColor1),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedCategory = newValue!;
                          });
                        },
                      ),
                      SizedBox(height: 16),
                      Text(
                        '件名',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: themeSettings.fontColor1,
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _subjectController,
                        decoration: InputDecoration(
                          hintText: '件名を入力してください',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: themeSettings.inputBackgroundColor,
                          hintStyle: TextStyle(
                            color: themeSettings.fontColor1.withOpacity(0.6),
                          ),
                        ),
                        style: TextStyle(color: themeSettings.fontColor1),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'メッセージ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: themeSettings.fontColor1,
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _messageController,
                        maxLines: 8,
                        decoration: InputDecoration(
                          hintText: '詳細な内容を入力してください',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: themeSettings.inputBackgroundColor,
                          hintStyle: TextStyle(
                            color: themeSettings.fontColor1.withOpacity(0.6),
                          ),
                        ),
                        style: TextStyle(color: themeSettings.fontColor1),
                      ),
                      SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _sendFeedback,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeSettings.buttonColor,
                            foregroundColor: themeSettings.fontColor2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      themeSettings.fontColor2,
                                    ),
                                  ),
                                )
                              : Text(
                                  'フィードバックを送信',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
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
