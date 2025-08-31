import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
      debugPrint('開発者モード読み込みエラー: $e');
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
      debugPrint('開発者モード保存エラー: $e');
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
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: kIsWeb ? 800 : double.infinity,
            ),
            child: ListView(
              padding: EdgeInsets.all(kIsWeb ? 24 : 20),
              children: [
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Provider.of<ThemeSettings>(
                    context,
                  ).cardBackgroundColor,
                  child: Padding(
                    padding: EdgeInsets.all(kIsWeb ? 28 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(kIsWeb ? 10 : 8),
                              decoration: BoxDecoration(
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).iconColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.developer_mode,
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).iconColor,
                                size: kIsWeb ? 28 : 24,
                              ),
                            ),
                            SizedBox(width: kIsWeb ? 16 : 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '開発者モード',
                                    style: TextStyle(
                                      fontSize: kIsWeb ? 20 : 18,
                                      fontWeight: FontWeight.bold,
                                      color: Provider.of<ThemeSettings>(
                                        context,
                                      ).fontColor1,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    '開発者向けの機能を有効にします',
                                    style: TextStyle(
                                      fontSize: kIsWeb ? 16 : 14,
                                      color: Provider.of<ThemeSettings>(
                                        context,
                                      ).fontColor1.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: developerMode,
                              onChanged: _toggleDevMode,
                              activeThumbColor: Provider.of<ThemeSettings>(
                                context,
                              ).buttonColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: kIsWeb ? 28 : 24),
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Provider.of<ThemeSettings>(
                    context,
                  ).cardBackgroundColor,
                  child: Padding(
                    padding: EdgeInsets.all(kIsWeb ? 28 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(kIsWeb ? 10 : 8),
                              decoration: BoxDecoration(
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).iconColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.refresh,
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).iconColor,
                                size: kIsWeb ? 28 : 24,
                              ),
                            ),
                            SizedBox(width: kIsWeb ? 16 : 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '担当リセット',
                                    style: TextStyle(
                                      fontSize: kIsWeb ? 20 : 18,
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
                                      fontSize: kIsWeb ? 16 : 14,
                                      color: Provider.of<ThemeSettings>(
                                        context,
                                      ).fontColor1.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: kIsWeb ? 20 : 18),
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
                              padding: EdgeInsets.symmetric(
                                vertical: kIsWeb ? 16 : 14,
                              ),
                            ),
                            onPressed: () {
                              widget.onReset();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('リセットしました')),
                              );
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
        ),
      ),
    );
  }
}
