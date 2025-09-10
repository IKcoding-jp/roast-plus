import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';

class RoastTimerSettingsPage extends StatelessWidget {
  const RoastTimerSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('タイマー設定'),
        backgroundColor: Provider.of<ThemeSettings>(context).appBarColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                ),
                title: Text(
                  'タイマー設定について',
                  style: TextStyle(
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '焙煎タイマーの設定に関する情報を表示します。',
                  style: TextStyle(
                    color: Provider.of<ThemeSettings>(context).fontColor2,
                  ),
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('タイマー設定について'),
                      content: Text(
                        '焙煎タイマーは、バックグラウンドでも正確にカウントダウンを続けます。\n\n'
                        'タイマーが動作中は、アプリを閉じても通知で完了をお知らせします。\n\n'
                        'より正確なタイマー動作のためには、通知権限の許可をお願いします。',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('閉じる'),
                        ),
                      ],
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
}
