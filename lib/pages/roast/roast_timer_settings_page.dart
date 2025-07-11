import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RoastTimerSettingsPage extends StatefulWidget {
  const RoastTimerSettingsPage({super.key});

  @override
  State<RoastTimerSettingsPage> createState() => _RoastTimerSettingsPageState();
}

class _RoastTimerSettingsPageState extends State<RoastTimerSettingsPage> {
  final TextEditingController _preheatController = TextEditingController();
  int _preheatMinutes = 30;
  bool _loading = true;

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
    setState(() {
      _preheatMinutes = value;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('予熱時間を${value}分に保存しました')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('焙煎タイマー設定')),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '予熱時間（分）',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _preheatController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _savePreheat,
                        child: Text('保存'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
