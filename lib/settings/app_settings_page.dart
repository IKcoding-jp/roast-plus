import 'package:bysnapp/pages/schedule/schedule_time_label_edit_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/sync_firestore_all.dart';
import '../pages/settings/theme_settings_page.dart';
import 'package:provider/provider.dart';
import '../models/theme_settings.dart';

class AppSettingsPage extends StatelessWidget {
  const AppSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('アプリ設定')),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '設定',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Provider.of<ThemeSettings>(context).fontColor1,
                ),
              ),
            ),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color:
                  Provider.of<ThemeSettings>(context).backgroundColor2 ??
                  Colors.white,
              child: ListTile(
                leading: Icon(
                  Icons.person_outline,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                ),
                title: Text(
                  'アカウント情報',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AccountInfoPage()),
                  );
                },
              ),
            ),
            // ▼ここから追加：パスコードロック設定
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color:
                  Provider.of<ThemeSettings>(context).backgroundColor2 ??
                  Colors.white,
              child: ListTile(
                leading: Icon(
                  Icons.lock_outline,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                ),
                title: Text(
                  'パスコードロック設定',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PasscodeLockSettingsPage(),
                    ),
                  );
                },
              ),
            ),
            // ▲ここまで追加
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color:
                  Provider.of<ThemeSettings>(context).backgroundColor2 ??
                  Colors.white,
              child: ListTile(
                leading: Icon(
                  Icons.color_lens_outlined,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                ),
                title: Text(
                  'テーマを変更する',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ThemeSettingsPage(),
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

// ダミーのアカウント情報ページ
class AccountInfoPage extends StatefulWidget {
  const AccountInfoPage({super.key});

  @override
  State<AccountInfoPage> createState() => _AccountInfoPageState();
}

class _AccountInfoPageState extends State<AccountInfoPage> {
  String? _userName;
  String? _loginProvider;
  String? _userPhotoUrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loading = true;
    final googleSignIn = GoogleSignIn();
    googleSignIn.onCurrentUserChanged.listen((account) async {
      if (account != null) {
        if (!mounted) return;
        setState(() {
          _userName = account.displayName ?? account.email;
          _loginProvider = 'Google';
          _userPhotoUrl = account.photoUrl;
          _loading = false;
        });
        // ログイン時にFirestore同期
        await syncAllFirestoreData(context);
        if (!mounted) return;
        setState(() {});
      }
    });
    _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    final googleSignIn = GoogleSignIn();
    final account =
        googleSignIn.currentUser ?? await googleSignIn.signInSilently();
    if (account != null) {
      if (!mounted) return;
      setState(() {
        _userName = account.displayName ?? account.email;
        _loginProvider = 'Google';
        _userPhotoUrl = account.photoUrl;
      });
      // 既にログイン済みならFirestore同期
      await syncAllFirestoreData(context);
      if (!mounted) return;
      setState(() {});
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  Future<void> _signInWithGoogle() async {
    if (mounted) setState(() => _loading = true);
    try {
      final googleSignIn = GoogleSignIn();
      final account = await googleSignIn.signIn();
      if (account == null) {
        // キャンセル時
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }
      final googleAuth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user?.uid)
          .set({
            'displayName': account.displayName,
            'email': account.email,
            'photoUrl': account.photoUrl,
            'lastLogin': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      if (mounted) {
        if (!mounted) return;
        setState(() {
          _userName = account.displayName ?? account.email;
          _loginProvider = 'Google';
          _userPhotoUrl = account.photoUrl;
          _loading = false;
        });
        // サインイン直後にFirestore同期
        await syncAllFirestoreData(context);
        if (!mounted) return;
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {});
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Googleログイン失敗: $e')));
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('アカウント情報')),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _loading
                ? Center(child: CircularProgressIndicator())
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        color:
                            Provider.of<ThemeSettings>(
                              context,
                            ).backgroundColor2 ??
                            Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_userName != null &&
                                  _loginProvider != null) ...[
                                Row(
                                  children: [
                                    _userPhotoUrl != null
                                        ? CircleAvatar(
                                            radius: 32,
                                            backgroundImage: NetworkImage(
                                              _userPhotoUrl!,
                                            ),
                                          )
                                        : Icon(
                                            Icons.account_circle,
                                            size: 64,
                                            color: Provider.of<ThemeSettings>(
                                              context,
                                            ).iconColor,
                                          ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'ログイン済み',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Provider.of<ThemeSettings>(
                                                context,
                                              ).fontColor1,
                                              fontSize: 16,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            '$_userName（$_loginProvider）',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Provider.of<ThemeSettings>(
                                                context,
                                              ).fontColor1,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: Icon(
                                      Icons.logout,
                                      color:
                                          Theme.of(context)
                                              .elevatedButtonTheme
                                              .style
                                              ?.foregroundColor
                                              ?.resolve({}) ??
                                          Colors.white,
                                    ),
                                    label: Text('ログアウト'),
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
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    onPressed: _loading
                                        ? null
                                        : () async {
                                            setState(() => _loading = true);
                                            try {
                                              await GoogleSignIn().signOut();
                                              await FirebaseAuth.instance
                                                  .signOut();
                                              if (!mounted) return;
                                              setState(() {
                                                _userName = null;
                                                _loginProvider = null;
                                                _userPhotoUrl = null;
                                              });
                                            } catch (e) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text('ログアウト失敗: $e'),
                                                ),
                                              );
                                            } finally {
                                              if (!mounted) return;
                                              setState(() => _loading = false);
                                            }
                                          },
                                  ),
                                ),
                              ],
                              if (_userName == null) ...[
                                Row(
                                  children: [
                                    Icon(
                                      Icons.account_circle,
                                      size: 48,
                                      color: Provider.of<ThemeSettings>(
                                        context,
                                      ).iconColor,
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        '未ログイン',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Provider.of<ThemeSettings>(
                                            context,
                                          ).fontColor1,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: Image.asset(
                                      'assets/google_logo.png',
                                      height: 24,
                                    ),
                                    label: Text('Googleでログイン'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor:
                                          Provider.of<ThemeSettings>(
                                            context,
                                          ).fontColor1,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: Provider.of<ThemeSettings>(
                                            context,
                                          ).fontColor1,
                                          width: 1,
                                        ),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    onPressed: _loading
                                        ? null
                                        : _signInWithGoogle,
                                  ),
                                ),
                              ],
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

// 記録リストからユニークな豆名リストを抽出
List<String> getBeanListFromRecords(List<Map<String, dynamic>> records) {
  final set = <String>{};
  for (final r in records) {
    final b = (r['bean'] ?? '').toString();
    if (b.isNotEmpty) set.add(b);
  }
  final list = set.toList();
  list.sort();
  return list;
}

class RoastTimerSettingsPage extends StatelessWidget {
  const RoastTimerSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('タイマー設定')),
      body: Center(child: Text('ここに個別設定を追加できます')),
    );
  }
}

class TodaySchedulePage extends StatefulWidget {
  const TodaySchedulePage({super.key});

  @override
  State<TodaySchedulePage> createState() => _TodaySchedulePageState();
}

class _TodaySchedulePageState extends State<TodaySchedulePage>
    with AutomaticKeepAliveClientMixin {
  List<String> _scheduleLabels = [];
  Map<String, String> _scheduleContents = {};
  final Map<String, TextEditingController> _scheduleControllers = {};
  // ...他の変数...

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
    _initControllers();
  }

  void _initControllers() {
    // 新規ラベルのみcontroller生成
    for (final label in _scheduleLabels) {
      if (!_scheduleControllers.containsKey(label)) {
        _scheduleControllers[label] = TextEditingController(
          text: _scheduleContents[label] ?? '',
        );
      }
    }
    // 不要なコントローラを破棄
    final toRemove = _scheduleControllers.keys
        .where((k) => !_scheduleLabels.contains(k))
        .toList();
    for (final k in toRemove) {
      _scheduleControllers[k]?.dispose();
      _scheduleControllers.remove(k);
    }
  }

  Future<void> _saveSchedules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'todaySchedule_labels',
        json.encode(_scheduleLabels),
      );
      await prefs.setString(
        'todaySchedule_contents',
        json.encode(_scheduleContents),
      );
    } catch (_) {}
  }

  Future<void> _loadSchedules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final labelsStr = prefs.getString('todaySchedule_labels');
      final contentsStr = prefs.getString('todaySchedule_contents');
      List<String> loadedLabels = [];
      Map<String, String> loadedContents = {};
      if (labelsStr != null) {
        loadedLabels = List<String>.from(json.decode(labelsStr));
      }
      if (contentsStr != null) {
        loadedContents = Map<String, String>.from(json.decode(contentsStr));
      }
      setState(() {
        _scheduleLabels = loadedLabels;
        _scheduleContents = loadedContents;
      });
      _initControllers();
    } catch (_) {
      setState(() {
        _scheduleLabels = [];
        _scheduleContents = {};
      });
      _initControllers();
    }
  }

  void _openLabelEdit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleTimeLabelEditPage(
          labels: _scheduleLabels,
          onLabelsChanged: (newLabels) {
            setState(() {
              _scheduleLabels = List.from(newLabels);
              _scheduleContents.removeWhere(
                (k, v) => !_scheduleLabels.contains(k),
              );
              _initControllers();
            });
            _saveSchedules();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _scheduleControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ← 必ず呼ぶ
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.schedule,
              color: Provider.of<ThemeSettings>(context).iconColor,
            ),
            SizedBox(width: 8),
            Text(
              '本日のスケジュール',
              style: TextStyle(
                color: Provider.of<ThemeSettings>(context).fontColor1,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            tooltip: '時間ラベル編集',
            onPressed: _openLabelEdit,
          ),
        ],
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Provider.of<ThemeSettings>(context).iconColor,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              ..._scheduleLabels.map(
                (label) => Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: Theme.of(context).scaffoldBackgroundColor,
                  margin: EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 2,
                      horizontal: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFF795548).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).fontColor1,
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _scheduleControllers[label],
                            keyboardType: TextInputType.text,
                            enableSuggestions: true,
                            autocorrect: true,
                            onChanged: (v) {
                              setState(() {
                                _scheduleContents[label] = v;
                              });
                              _saveSchedules();
                            },
                            maxLines: null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPasscode();
  }

  Future<void> _loadPasscode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPasscode = prefs.getString('app_passcode');
      _isLoading = false;
    });
  }

  Future<void> _savePasscode() async {
    final passcode = _passcodeController.text.trim();
    final confirm = _confirmController.text.trim();
    if (passcode.length != 4 || int.tryParse(passcode) == null) {
      setState(() {
        _error = '4桁の数字で入力してください';
      });
      return;
    }
    if (passcode != confirm) {
      setState(() {
        _error = '2回の入力が一致しません';
      });
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_passcode', passcode);
    setState(() {
      _savedPasscode = passcode;
      _isSaving = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('パスコードを保存しました')));
    _passcodeController.clear();
    _confirmController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('パスコードロック設定')),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'セキュリティ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Provider.of<ThemeSettings>(context).fontColor1,
                        ),
                      ),
                    ),
                    if (_savedPasscode != null) ...[
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        color:
                            Provider.of<ThemeSettings>(
                              context,
                            ).backgroundColor2 ??
                            Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 24,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'パスコードは設定済みです',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: Icon(Icons.refresh),
                                  label: Text('パスワードをリセットする'),
                                  onPressed: _showResetDialog,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_savedPasscode == null) ...[
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        color:
                            Provider.of<ThemeSettings>(
                              context,
                            ).backgroundColor2 ??
                            Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.lock_outline,
                                    color: Provider.of<ThemeSettings>(
                                      context,
                                    ).iconColor,
                                    size: 24,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    '4桁のパスコードを設定してください',
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
                              SizedBox(height: 16),
                              TextField(
                                controller: _passcodeController,
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                obscureText: true,
                                style: TextStyle(
                                  color: Provider.of<ThemeSettings>(
                                    context,
                                  ).fontColor1,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'パスコード',
                                  labelStyle: TextStyle(
                                    color: Provider.of<ThemeSettings>(
                                      context,
                                    ).fontColor1,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.lock_outline,
                                    color: Provider.of<ThemeSettings>(
                                      context,
                                    ).iconColor,
                                  ),
                                  filled: true,
                                  fillColor: Provider.of<ThemeSettings>(
                                    context,
                                  ).inputBackgroundColor,
                                ),
                              ),
                              SizedBox(height: 12),
                              TextField(
                                controller: _confirmController,
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                obscureText: true,
                                style: TextStyle(
                                  color: Provider.of<ThemeSettings>(
                                    context,
                                  ).fontColor1,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'パスコード（確認）',
                                  labelStyle: TextStyle(
                                    color: Provider.of<ThemeSettings>(
                                      context,
                                    ).fontColor1,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.lock_outline,
                                    color: Provider.of<ThemeSettings>(
                                      context,
                                    ).iconColor,
                                  ),
                                  filled: true,
                                  fillColor: Provider.of<ThemeSettings>(
                                    context,
                                  ).inputBackgroundColor,
                                  errorText: _error,
                                ),
                              ),
                              SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: _isSaving
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Icon(Icons.save),
                                  label: Text(_isSaving ? '保存中...' : '保存'),
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
    );
  }

  void _showResetDialog() {
    final TextEditingController _currentController = TextEditingController();
    String? errorText;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor:
                  Provider.of<ThemeSettings>(context).backgroundColor2 ??
                  Colors.white,
              title: Text(
                'パスコードのリセット',
                style: TextStyle(
                  color: Provider.of<ThemeSettings>(context).fontColor1,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '現在のパスコードを入力してください',
                    style: TextStyle(
                      color: Provider.of<ThemeSettings>(context).fontColor1,
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _currentController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    style: TextStyle(
                      color: Provider.of<ThemeSettings>(context).fontColor1,
                    ),
                    decoration: InputDecoration(
                      labelText: '現在のパスコード',
                      labelStyle: TextStyle(
                        color: Provider.of<ThemeSettings>(context).fontColor1,
                      ),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Provider.of<ThemeSettings>(
                        context,
                      ).inputBackgroundColor,
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'キャンセル',
                    style: TextStyle(
                      color: Provider.of<ThemeSettings>(context).fontColor1,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final input = _currentController.text.trim();
                    if (input != _savedPasscode) {
                      setState(() {
                        errorText = 'パスコードが違います';
                      });
                      return;
                    }
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('app_passcode');
                    Navigator.pop(context);
                    this.setState(() {
                      _savedPasscode = null;
                      _error = null;
                      _passcodeController.clear();
                      _confirmController.clear();
                    });
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('パスコードをリセットしました')));
                  },
                  child: Text(
                    'リセット',
                    style: TextStyle(
                      color: Provider.of<ThemeSettings>(context).fontColor2,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _passcodeController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
}

// lib/pages/settings/theme_settings_page.dart でThemeSettingsPageを実装
