import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AssignmentSettingsPage extends StatefulWidget {
  const AssignmentSettingsPage({super.key, this.onReset});
  final Future<void> Function()? onReset;

  @override
  State<AssignmentSettingsPage> createState() => _AssignmentSettingsPageState();
}

class _AssignmentSettingsPageState extends State<AssignmentSettingsPage> {
  bool _developerMode = false;

  @override
  void initState() {
    super.initState();
    _loadDeveloperMode();
  }

  Future<void> _loadDeveloperMode() async {
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getBool('developerMode') ?? false;
    setState(() {
      _developerMode = local;
    });
  }

  Future<void> _onDeveloperModeChanged(bool value) async {
    setState(() {
      _developerMode = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('developerMode', value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('担当者設定')),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text('開発者モード'),
            value: _developerMode,
            onChanged: _onDeveloperModeChanged,
          ),
          ListTile(title: Text('今日の担当をリセット'), onTap: widget.onReset),
        ],
      ),
    );
  }
}
