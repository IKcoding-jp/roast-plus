import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../models/theme_settings.dart';

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
                  Icons.battery_charging_full,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                ),
                title: Text(
                  'バッテリー最適化ダイアログを再表示',
                  style: TextStyle(
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '次回焙煎タイマーを開いた時に、バッテリー最適化の設定ダイアログを再表示します',
                  style: TextStyle(
                    color: Provider.of<ThemeSettings>(context).fontColor2,
                  ),
                ),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('battery_optimization_dialog_shown');

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('バッテリー最適化ダイアログを再表示するように設定しました'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ),
            SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                ),
                title: Text(
                  'バッテリー最適化について',
                  style: TextStyle(
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '焙煎タイマーがバックグラウンドでも正確に動作するために必要な設定です。設定画面で「無制限」を選択してください。',
                  style: TextStyle(
                    color: Provider.of<ThemeSettings>(context).fontColor2,
                  ),
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('バッテリー最適化について'),
                      content: Text(
                        '焙煎タイマーがバックグラウンドでも正確に動作するために、'
                        'バッテリー最適化の除外設定が必要です。\n\n'
                        'この設定により、アプリがバックグラウンドに移行しても'
                        'タイマーが正確にカウントダウンを続けることができます。\n\n'
                        '設定方法：\n'
                        '1. 設定画面が開きます\n'
                        '2. 「バッテリー」または「バッテリー最適化」を選択\n'
                        '3. アプリ一覧から「bysnapp」を選択\n'
                        '4. 「無制限」を選択\n\n'
                        'この設定は一度行えば、アプリを再インストールするまで有効です。',
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
