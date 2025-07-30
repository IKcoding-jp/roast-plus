import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../services/user_settings_firestore_service.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback onReset;
  const SettingsPage({super.key, required this.onReset});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool developerMode = false;
  bool _prefsLoaded = false;
  SharedPreferences? prefs;

  @override
  void initState() {
    super.initState();
    _loadDevMode();
  }

  Future<void> _loadDevMode() async {
    try {
      final devMode =
          await UserSettingsFirestoreService.getSetting('developerMode') ??
          false;
      if (mounted) {
        setState(() {
          developerMode = devMode;
          _prefsLoaded = true;
        });
      }
    } catch (e) {
      print('開発者モード読み込みエラー: $e');
      if (mounted) {
        setState(() {
          developerMode = false;
          _prefsLoaded = true;
        });
      }
    }
  }

  void _toggleDevMode(bool value) async {
    setState(() {
      developerMode = value;
    });
    try {
      await UserSettingsFirestoreService.saveSetting('developerMode', value);
    } catch (e) {
      print('開発者モード保存エラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_prefsLoaded) {
      return Scaffold(
        appBar: AppBar(title: Text('設定')),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.settings,
              color: Provider.of<ThemeSettings>(context).iconColor,
            ),
            SizedBox(width: 8),
            Text('担当表設定'),
          ],
        ),
        backgroundColor: Provider.of<ThemeSettings>(context).appBarColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          padding: EdgeInsets.all(20),
          children: [
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Provider.of<ThemeSettings>(context).cardBackgroundColor,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).iconColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.developer_mode,
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).iconColor,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '開発者モード',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Provider.of<ThemeSettings>(
                                    context,
                                  ).fontColor1,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '土日でも担当シャッフルが可能になります',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Provider.of<ThemeSettings>(
                                    context,
                                  ).fontColor1.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: developerMode,
                          onChanged: _toggleDevMode,
                          activeColor: Provider.of<ThemeSettings>(
                            context,
                          ).buttonColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Provider.of<ThemeSettings>(context).cardBackgroundColor,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).iconColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.refresh,
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).iconColor,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '担当リセット',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Provider.of<ThemeSettings>(
                                    context,
                                  ).fontColor1,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'すでに決定した今日の担当をリセットします',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Provider.of<ThemeSettings>(
                                    context,
                                  ).fontColor1.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.refresh),
                        label: Text('今日の担当リセット'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Provider.of<ThemeSettings>(
                            context,
                          ).buttonColor,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          widget.onReset();
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('リセットしました')));
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
