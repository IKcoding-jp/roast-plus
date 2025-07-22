import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/sync_firestore_all.dart';
import '../services/data_sync_service.dart';
import 'package:provider/provider.dart';
import '../models/theme_settings.dart';
import '../utils/app_performance_config.dart';
import '../models/group_provider.dart';
import '../models/gamification_provider.dart';
import '../models/dashboard_stats_provider.dart';

// ダミーのアカウント情報ページ
class AccountInfoPage extends StatefulWidget {
  const AccountInfoPage({super.key});

  @override
  State<AccountInfoPage> createState() => _AccountInfoPageState();
}

class _AccountInfoPageState extends State<AccountInfoPage> {
  String? _userName;
  String? _userEmail;
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
        await _loadCustomDisplayName();
        setState(() {
          _userEmail = account.email;
          _loginProvider = 'Google';
          _userPhotoUrl = account.photoUrl;
          _loading = false;
        });
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
      await _loadCustomDisplayName();
      setState(() {
        _userEmail = account.email;
        _loginProvider = 'Google';
        _userPhotoUrl = account.photoUrl;
      });
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  Future<void> _loadCustomDisplayName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.exists &&
        doc.data() != null &&
        doc.data()!['displayName'] != null) {
      setState(() {
        _userName = doc.data()!['displayName'];
      });
    } else {
      // Firestoreにカスタム名がなければGoogleアカウント名
      setState(() {
        _userName = user.displayName ?? user.email;
      });
    }
  }

  Future<void> _editDisplayName() async {
    final controller = TextEditingController(text: _userName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('表示名を編集'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: '新しい表示名'),
          maxLength: 30,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('保存'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'displayName': result,
        }, SetOptions(merge: true));
        setState(() {
          _userName = result;
        });
        // 参加中の全グループのmembers配列も更新
        final groupsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('userGroups')
            .get();
        for (final doc in groupsSnapshot.docs) {
          final groupId = doc.data()['groupId'] as String?;
          if (groupId == null) continue;
          final groupDoc = await FirebaseFirestore.instance
              .collection('groups')
              .doc(groupId)
              .get();
          if (!groupDoc.exists) continue;
          final groupData = groupDoc.data();
          if (groupData == null || groupData['members'] == null) continue;
          final membersRaw = groupData['members'];
          if (membersRaw is! List) continue;
          final updatedMembers = membersRaw
              .map((m) {
                if (m is Map<String, dynamic> && m['uid'] == user.uid) {
                  return {...m, 'displayName': result};
                }
                return m;
              })
              .where((m) => m != null)
              .toList();
          await FirebaseFirestore.instance
              .collection('groups')
              .doc(groupId)
              .update({
                'members': updatedMembers,
                'updatedAt': FieldValue.serverTimestamp(),
              });
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('表示名を変更しました（グループにも反映）'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
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
          _userEmail = account.email;
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
                        color: Provider.of<ThemeSettings>(
                          context,
                        ).backgroundColor2,
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
                                          // ユーザー名と編集ボタン
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _userName!,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                    color:
                                                        Provider.of<
                                                              ThemeSettings
                                                            >(context)
                                                            .fontColor1,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              SizedBox(width: 4),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.edit,
                                                  size: 18,
                                                  color:
                                                      Provider.of<
                                                            ThemeSettings
                                                          >(context)
                                                          .iconColor,
                                                ),
                                                tooltip: '表示名を編集',
                                                onPressed: _editDisplayName,
                                              ),
                                            ],
                                          ),
                                          Text(
                                            'ログイン済み',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Provider.of<ThemeSettings>(
                                                context,
                                              ).fontColor1,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          // バッジ類をログイン済みの下に配置
                                          Row(
                                            children: [
                                              if (_userEmail ==
                                                  'kensaku.ikeda04@gmail.com')
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '開発者',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              if (_userEmail ==
                                                  'kensaku.ikeda04@gmail.com')
                                                SizedBox(width: 8),
                                              FutureBuilder<bool>(
                                                future: isDonorUser(),
                                                builder: (context, snapshot) {
                                                  if (_userEmail ==
                                                      'kensaku.ikeda04@gmail.com') {
                                                    return SizedBox.shrink();
                                                  }
                                                  if (snapshot.connectionState !=
                                                          ConnectionState
                                                              .done ||
                                                      snapshot.data != true) {
                                                    return SizedBox.shrink();
                                                  }
                                                  return Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '寄付者',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
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
                                              // GroupProviderの情報をクリア
                                              final groupProvider =
                                                  Provider.of<GroupProvider>(
                                                    context,
                                                    listen: false,
                                                  );
                                              groupProvider.clearOnLogout();

                                              final gamificationProvider =
                                                  Provider.of<
                                                    GamificationProvider
                                                  >(context, listen: false);
                                              gamificationProvider
                                                  .clearOnLogout();

                                              final dashboardStatsProvider =
                                                  Provider.of<
                                                    DashboardStatsProvider
                                                  >(context, listen: false);
                                              dashboardStatsProvider
                                                  .clearOnLogout();

                                              await GoogleSignIn().signOut();
                                              await FirebaseAuth.instance
                                                  .signOut();
                                              if (!mounted) return;
                                              setState(() {
                                                _userName = null;
                                                _loginProvider = null;
                                                _userPhotoUrl = null;
                                              });
                                              // 設定画面を閉じてホームに戻る（AuthGateが即座にログイン画面を表示）
                                              Navigator.of(context).popUntil(
                                                (route) => route.isFirst,
                                              );
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
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: Icon(
                                      Icons.delete_forever,
                                      color: Colors.red,
                                    ),
                                    label: Text('アカウントデータ全削除'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.red,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      side: BorderSide(color: Colors.red),
                                      padding: EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    onPressed: _loading
                                        ? null
                                        : () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: Text('本当に削除しますか？'),
                                                content: Text(
                                                  'アカウントに保存された全てのデータ（グループデータを除く）を完全に削除します。\nこの操作は元に戻せません。',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          false,
                                                        ),
                                                    child: Text('キャンセル'),
                                                  ),
                                                  ElevatedButton(
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.red,
                                                          foregroundColor:
                                                              Colors.white,
                                                        ),
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          true,
                                                        ),
                                                    child: Text('削除する'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm != true) return;
                                            setState(() => _loading = true);
                                            try {
                                              // GroupProviderの情報をクリア
                                              final groupProvider =
                                                  Provider.of<GroupProvider>(
                                                    context,
                                                    listen: false,
                                                  );
                                              groupProvider.clearOnLogout();

                                              final gamificationProvider =
                                                  Provider.of<
                                                    GamificationProvider
                                                  >(context, listen: false);
                                              gamificationProvider
                                                  .clearOnLogout();

                                              final dashboardStatsProvider =
                                                  Provider.of<
                                                    DashboardStatsProvider
                                                  >(context, listen: false);
                                              dashboardStatsProvider
                                                  .clearOnLogout();

                                              // Firestoreデータ削除
                                              await DataSyncService.deleteAllUserData();
                                              // ローカルデータ削除
                                              // 注: UserSettingsFirestoreServiceにはclearAllSettingsメソッドがないため、
                                              // 個別に削除するか、SharedPreferencesを直接使用
                                              final prefs =
                                                  await SharedPreferences.getInstance();
                                              await prefs.clear();
                                              // サインアウト
                                              await GoogleSignIn().signOut();
                                              await FirebaseAuth.instance
                                                  .signOut();
                                              if (!mounted) return;
                                              setState(() {
                                                _userName = null;
                                                _loginProvider = null;
                                                _userPhotoUrl = null;
                                              });
                                              Navigator.of(context).popUntil(
                                                (route) => route.isFirst,
                                              );
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'アカウントデータを削除しました',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            } catch (e) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    '削除に失敗しました: $e',
                                                  ),
                                                  backgroundColor: Colors.red,
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
