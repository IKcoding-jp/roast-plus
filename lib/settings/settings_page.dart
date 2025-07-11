import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback onReset;
  const SettingsPage({super.key, required this.onReset});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool developerMode = false;
  late SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    _loadDevMode();
  }

  Future<void> _loadDevMode() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      developerMode = prefs.getBool('developerMode') ?? false;
    });
  }

  void _toggleDevMode(bool value) {
    setState(() {
      developerMode = value;
      prefs.setBool('developerMode', value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('設定')),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text('今日の担当リセット'),
              onPressed: () {
                widget.onReset();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('リセットしました')));
                Navigator.pop(context);
              },
            ),
            SizedBox(height: 30),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('開発者モード（土日でもシャッフル）', style: TextStyle(fontSize: 16)),
                Switch(value: developerMode, onChanged: _toggleDevMode),
              ],
            ),
          ],
        ),
      ),
    );
  }
}