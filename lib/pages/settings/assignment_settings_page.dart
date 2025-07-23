import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../services/user_settings_firestore_service.dart';

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
    final local =
        await UserSettingsFirestoreService.getSetting('developerMode') ?? false;
    setState(() {
      _developerMode = local;
    });
  }

  Future<void> _onDeveloperModeChanged(bool value) async {
    setState(() {
      _developerMode = value;
    });
    await UserSettingsFirestoreService.saveSetting('developerMode', value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('担当者設定')),
      body: ListView(
        children: [
          // 開発者モードはデバッグ時のみ表示
          if (kDebugMode) ...[
            SwitchListTile(
              title: Text('開発者モード'),
              value: _developerMode,
              onChanged: _onDeveloperModeChanged,
            ),
          ],
          ListTile(title: Text('今日の担当をリセット'), onTap: widget.onReset),
        ],
      ),
    );
  }
}
