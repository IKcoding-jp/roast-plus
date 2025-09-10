import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../services/user_settings_firestore_service.dart';
import '../../services/app_settings_firestore_service.dart';

class PasscodeLockSettingsPage extends StatefulWidget {
  const PasscodeLockSettingsPage({super.key});

  @override
  State<PasscodeLockSettingsPage> createState() =>
      _PasscodeLockSettingsPageState();
}

class _PasscodeLockSettingsPageState extends State<PasscodeLockSettingsPage> {
  final TextEditingController _passcodeController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  String? _savedPasscode;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLockEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPasscode();
  }

  Future<void> _loadPasscode() async {
    try {
      final settings = await UserSettingsFirestoreService.getMultipleSettings([
        'passcode',
        'isLockEnabled',
      ]);
      setState(() {
        _savedPasscode = settings['passcode'];
        _isLockEnabled = settings['isLockEnabled'] ?? false;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('パスコード設定読み込みエラー: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _savePasscode() async {
    if (_passcodeController.text != _confirmController.text) {
      setState(() {
        _error = 'パスコードが一致しません';
      });
      return;
    }

    if (_passcodeController.text.length != 4) {
      setState(() {
        _error = 'パスコードは4桁で入力してください';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await UserSettingsFirestoreService.saveMultipleSettings({
        'passcode': _passcodeController.text,
        'isLockEnabled': true,
      });

      // Firestoreにも保存
      await AppSettingsFirestoreService.savePasscodeSettings(
        passcodeEnabled: true,
        passcode: _passcodeController.text,
      );

      setState(() {
        _savedPasscode = _passcodeController.text;
        _isLockEnabled = true;
        _isSaving = false;
      });

      _passcodeController.clear();
      _confirmController.clear();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('パスコードを設定しました')));
      }
    } catch (e) {
      setState(() {
        _error = '保存に失敗しました: $e';
        _isSaving = false;
      });
    }
  }

  Future<void> _disableLock() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await UserSettingsFirestoreService.saveMultipleSettings({
        'passcode': null,
        'isLockEnabled': false,
      });

      // Firestoreも無効化
      await AppSettingsFirestoreService.savePasscodeSettings(
        passcodeEnabled: false,
        passcode: null,
      );

      setState(() {
        _savedPasscode = null;
        _isLockEnabled = false;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('パスコードロックを無効にしました')));
      }
    } catch (e) {
      setState(() {
        _error = '無効化に失敗しました: $e';
        _isSaving = false;
      });
    }
  }

  // パスコード入力ダイアログ
  Future<bool> _showPasscodeInputDialog() async {
    String input = '';
    String? error;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: Text('パスコード確認'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('パスコードを入力してください'),
                      SizedBox(height: 12),
                      TextField(
                        autofocus: true,
                        obscureText: true,
                        maxLength: 4,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: false,
                          signed: false,
                        ),
                        onChanged: (v) {
                          setState(() => input = v);
                        },
                        decoration: InputDecoration(
                          labelText: 'パスコード',
                          errorText: error,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('キャンセル'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (input == (_savedPasscode ?? '')) {
                          Navigator.pop(context, true);
                        } else {
                          setState(() => error = 'パスコードが違います');
                        }
                      },
                      child: Text('OK'),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;
  }

  Future<void> _requestDisableLock() async {
    final ok = await _showPasscodeInputDialog();
    if (ok) {
      await _disableLock();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('パスコードが正しくありません')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('パスコードロック設定')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('パスコードロック設定')),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600, // Web版での最大幅を制限
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLockEnabled) ...[
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: Provider.of<ThemeSettings>(
                        context,
                      ).cardBackgroundColor,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lock, color: Colors.green, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  'パスコードロックが有効です',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Provider.of<ThemeSettings>(
                                      context,
                                    ).fontColor1,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Text(
                              'アプリを開く際にパスコードの入力が必要です',
                              style: TextStyle(
                                fontSize: 14,
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).fontColor1,
                              ),
                            ),
                            SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.lock_open),
                                label: Text('パスコードロックを無効にする'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _isSaving
                                    ? null
                                    : _requestDisableLock,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: Provider.of<ThemeSettings>(
                        context,
                      ).cardBackgroundColor,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'パスコードを設定',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).fontColor1,
                              ),
                            ),
                            SizedBox(height: 16),
                            TextField(
                              controller: _passcodeController,
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: false,
                                signed: false,
                              ),
                              decoration: InputDecoration(
                                labelText: 'パスコード（4桁）',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              maxLength: 4,
                            ),
                            SizedBox(height: 12),
                            TextField(
                              controller: _confirmController,
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: false,
                                signed: false,
                              ),
                              decoration: InputDecoration(
                                labelText: 'パスコード確認',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              maxLength: 4,
                            ),
                            if (_error != null) ...[
                              SizedBox(height: 8),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                            SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.lock),
                                label: Text('パスコードを設定'),
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _isSaving ? null : _savePasscode,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
