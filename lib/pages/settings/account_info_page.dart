import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/sync_firestore_all.dart';
import '../../services/data_sync_service.dart';
import '../../services/secure_auth_service.dart';
import '../../services/encrypted_local_storage_service.dart';
import '../../services/first_login_service.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../utils/app_performance_config.dart';
import '../../config/app_config.dart';
import '../../models/group_provider.dart';
import '../../models/gamification_provider.dart';
import '../../models/dashboard_stats_provider.dart';

// アカウント情報ページ
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
    // すべてのプラットフォームで FirebaseAuth から状態を読み込む
    _loadFromFirebaseUser();
  }

  // GoogleSignIn 依存を排し、FirebaseAuth ベースで統一

  Future<void> _loadFromFirebaseUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (!mounted) return;
        await _loadCustomDisplayName();
        setState(() {
          _userEmail = user.email;
          _loginProvider = (user.providerData.isNotEmpty)
              ? user.providerData.first.providerId
              : 'Firebase';
          _userPhotoUrl = user.photoURL;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadCustomDisplayName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // FirstLoginServiceを使用してカスタム表示名を取得
    final customDisplayName = await FirstLoginService.getCurrentDisplayName();
    if (customDisplayName != null && customDisplayName.isNotEmpty) {
      setState(() {
        _userName = customDisplayName;
      });
    } else {
      // カスタム表示名がなければGoogleアカウント名
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Googleアカウント名から名字への変更を推奨します。',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: '例: 田中、佐藤',
                labelText: '表示名（名字）',
              ),
              maxLength: 30,
            ),
          ],
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
        // FirstLoginServiceを使用して表示名を設定
        final success = await FirstLoginService.setDisplayName(result);
        if (success) {
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
                content: Text('表示名を変更しました（担当表にも反映されます）'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('表示名の変更に失敗しました'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (mounted) setState(() => _loading = true);
    try {
      final userCredential =
          await SecureAuthService.signInWithGoogleForceAccountSelection();
      if (userCredential == null) {
        // キャンセル時
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final user = userCredential.user;
      if (user != null) {
        // ユーザー情報を更新
        if (!mounted) return;
        setState(() {
          _userName = user.displayName ?? user.email;
          _userEmail = user.email;
          _loginProvider = 'Google';
          _userPhotoUrl = user.photoURL;
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

        // セキュリティイベントを記録
        await SecureAuthService.logSecurityEvent('account_info_login_success');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('セキュアなGoogleログイン失敗: $e')));
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
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600, // Web版での最大幅を制限
            ),
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
                          ).cardBackgroundColor,
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
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                color:
                                                    Provider.of<ThemeSettings>(
                                                      context,
                                                    ).fontColor1,
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            // バッジ類をログイン済みの下に配置
                                            Row(
                                              children: [
                                                if (AppConfig.isDeveloperEmail(
                                                  _userEmail ?? '',
                                                ))
                                                  Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
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
                                                if (AppConfig.isDeveloperEmail(
                                                  _userEmail ?? '',
                                                ))
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
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                        foregroundColor:
                                            Theme.of(context)
                                                .elevatedButtonTheme
                                                .style
                                                ?.foregroundColor
                                                ?.resolve({}) ??
                                            Colors.white,
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                      ),
                                      onPressed: _loading
                                          ? null
                                          : () async {
                                              // 非同期ギャップ後にBuildContextを使わないよう、先に取得
                                              final navigator = Navigator.of(
                                                context,
                                              );
                                              final scaffoldMessenger =
                                                  ScaffoldMessenger.of(context);
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

                                                // GoogleSignIn は使用しない（FirebaseAuth のみでサインアウト）
                                                await FirebaseAuth.instance
                                                    .signOut();
                                                if (!mounted) return;
                                                setState(() {
                                                  _userName = null;
                                                  _loginProvider = null;
                                                  _userPhotoUrl = null;
                                                });
                                                // 設定画面を閉じてホームに戻る（AuthGateが即座にログイン画面を表示）
                                                navigator.popUntil(
                                                  (route) => route.isFirst,
                                                );
                                              } catch (e) {
                                                scaffoldMessenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'ログアウト失敗: $e',
                                                    ),
                                                  ),
                                                );
                                              } finally {
                                                if (mounted) {
                                                  setState(
                                                    () => _loading = false,
                                                  );
                                                }
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
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        side: BorderSide(color: Colors.red),
                                        padding: EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                      ),
                                      onPressed: _loading
                                          ? null
                                          : () async {
                                              // 非同期ギャップ後にBuildContextを使わないよう、先に取得
                                              final navigator = Navigator.of(
                                                context,
                                              );
                                              final scaffoldMessenger =
                                                  ScaffoldMessenger.of(context);
                                              // 非同期前に利用するProviderも先に取得
                                              final groupProvider =
                                                  Provider.of<GroupProvider>(
                                                    context,
                                                    listen: false,
                                                  );
                                              final gamificationProvider =
                                                  Provider.of<
                                                    GamificationProvider
                                                  >(context, listen: false);
                                              final dashboardStatsProvider =
                                                  Provider.of<
                                                    DashboardStatsProvider
                                                  >(context, listen: false);
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
                                                groupProvider.clearOnLogout();

                                                gamificationProvider
                                                    .clearOnLogout();

                                                dashboardStatsProvider
                                                    .clearOnLogout();

                                                // Firestoreデータ削除
                                                await DataSyncService.deleteAllUserData();
                                                // ローカルデータ削除
                                                // 注: UserSettingsFirestoreServiceにはclearAllSettingsメソッドがないため、
                                                // 個別に削除するか、暗号化されたローカルストレージを使用
                                                await EncryptedLocalStorageService.clear();
                                                // サインアウト（FirebaseAuth のみ）
                                                await FirebaseAuth.instance
                                                    .signOut();
                                                if (!mounted) return;
                                                setState(() {
                                                  _userName = null;
                                                  _loginProvider = null;
                                                  _userPhotoUrl = null;
                                                });
                                                navigator.popUntil(
                                                  (route) => route.isFirst,
                                                );
                                                scaffoldMessenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'アカウントデータを削除しました',
                                                    ),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              } catch (e) {
                                                scaffoldMessenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      '削除に失敗しました: $e',
                                                    ),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              } finally {
                                                if (mounted) {
                                                  setState(
                                                    () => _loading = false,
                                                  );
                                                }
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
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
