import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/roast_timer_settings_firestore_service.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';

class RoastTimerSettingsPage extends StatefulWidget {
  const RoastTimerSettingsPage({super.key});

  @override
  State<RoastTimerSettingsPage> createState() => RoastTimerSettingsPageState();
}

class RoastTimerSettingsPageState extends State<RoastTimerSettingsPage> {
  final TextEditingController _preheatController = TextEditingController();
  int _preheatMinutes = 30;
  bool _loading = true;

  // Firestore同期用setter
  void setPreheatMinutesFromFirestore(int minutes) {
    setState(() {
      _preheatMinutes = minutes;
      _preheatController.text = minutes.toString();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadPreheat();
  }

  Future<void> _loadPreheat() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _preheatMinutes = prefs.getInt('preheatMinutes') ?? 30;
      _preheatController.text = _preheatMinutes.toString();
      _loading = false;
    });
  }

  Future<void> _savePreheat() async {
    final prefs = await SharedPreferences.getInstance();
    final value = int.tryParse(_preheatController.text) ?? 30;
    await prefs.setInt('preheatMinutes', value);
    // Firestoreにも保存
    try {
      await RoastTimerSettingsFirestoreService.saveRoastTimerSettings(
        preheatMinutes: value,
      );
    } catch (_) {}
    setState(() {
      _preheatMinutes = value;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('予熱時間を$value分に保存しました')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('焙煎タイマー設定')),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color:
                      Provider.of<ThemeSettings>(context).backgroundColor2 ??
                      Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.timer,
                              color: Color(0xFF795548),
                              size: 24,
                            ),
                            SizedBox(width: 10),
                            Text(
                              '予熱時間（分）',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color(0xFF795548),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 18),
                        Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller: _preheatController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(fontSize: 16),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: Color(0xFF795548),
                                      width: 2,
                                    ),
                                  ),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: _savePreheat,
                              icon: Icon(Icons.save, size: 20),
                              label: Text(
                                '保存',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context)
                                        .elevatedButtonTheme
                                        .style
                                        ?.backgroundColor
                                        ?.resolve({}) ??
                                    Theme.of(context).colorScheme.primary,
                                foregroundColor:
                                    Theme.of(context)
                                        .elevatedButtonTheme
                                        .style
                                        ?.foregroundColor
                                        ?.resolve({}) ??
                                    Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 4,
                              ),
                            ),
                          ],
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
