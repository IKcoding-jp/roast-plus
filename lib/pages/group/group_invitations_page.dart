import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../models/theme_settings.dart';
import 'group_qr_scanner_page.dart';

class GroupInvitationsPage extends StatefulWidget {
  const GroupInvitationsPage({super.key});

  @override
  State<GroupInvitationsPage> createState() => _GroupInvitationsPageState();
}

class _GroupInvitationsPageState extends State<GroupInvitationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupProvider>().loadInvitations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeSettings.iconColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '招待一覧',
          style: TextStyle(
            color: themeSettings.appBarTextColor,
            fontSize: 20 * themeSettings.fontSizeScale,
            fontWeight: FontWeight.bold,
            fontFamily: themeSettings.fontFamily,
          ),
        ),
        backgroundColor: themeSettings.appBarColor,
        iconTheme: IconThemeData(color: themeSettings.iconColor),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_scanner, color: themeSettings.iconColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GroupQRScannerPage(),
                ),
              );
            },
            tooltip: 'QRコード読み取り',
          ),
        ],
      ),
      body: Consumer<GroupProvider>(
        builder: (context, groupProvider, child) {
          if (groupProvider.loading) {
            return Center(
              child: CircularProgressIndicator(color: themeSettings.iconColor),
            );
          }

          if (groupProvider.invitations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mail_outline,
                    size: 64,
                    color: themeSettings.iconColor,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '招待がありません',
                    style: TextStyle(
                      color: themeSettings.fontColor1,
                      fontSize: 18 * themeSettings.fontSizeScale,
                      fontWeight: FontWeight.bold,
                      fontFamily: themeSettings.fontFamily,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '新しい招待が届くとここに表示されます\nまたは、QRコードを読み取ってグループに参加しましょう',
                    style: TextStyle(
                      color: themeSettings.fontColor1,
                      fontSize: 14 * themeSettings.fontSizeScale,
                      fontFamily: themeSettings.fontFamily,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: themeSettings.cardBackgroundColor,
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.qr_code_scanner,
                            size: 48,
                            color: themeSettings.buttonColor,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'QRコードでグループ参加',
                            style: TextStyle(
                              color: themeSettings.fontColor1,
                              fontSize: 16 * themeSettings.fontSizeScale,
                              fontWeight: FontWeight.bold,
                              fontFamily: themeSettings.fontFamily,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '他のメンバーからQRコードをもらって\nグループに参加できます',
                            style: TextStyle(
                              color: themeSettings.fontColor1,
                              fontSize: 14 * themeSettings.fontSizeScale,
                              fontFamily: themeSettings.fontFamily,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const GroupQRScannerPage(),
                                ),
                              );
                            },
                            icon: Icon(Icons.qr_code_scanner),
                            label: Text('QRコードを読み取る'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeSettings.buttonColor,
                              foregroundColor: themeSettings.fontColor2,
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => groupProvider.loadInvitations(),
            child: ListView(
              padding: EdgeInsets.all(16),
              children: [
                // 招待リスト
                ...List.generate(groupProvider.invitations.length, (index) {
                  final invitation = groupProvider.invitations[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 16),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: themeSettings.cardBackgroundColor,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.group_add,
                                color: Colors.orange,
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      invitation.groupName,
                                      style: TextStyle(
                                        color: themeSettings.fontColor1,
                                        fontSize:
                                            18 * themeSettings.fontSizeScale,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: themeSettings.fontFamily,
                                      ),
                                    ),
                                    Text(
                                      '${invitation.invitedByEmail} から招待',
                                      style: TextStyle(
                                        color: themeSettings.fontColor1,
                                        fontSize:
                                            14 * themeSettings.fontSizeScale,
                                        fontFamily: themeSettings.fontFamily,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 16,
                                color: themeSettings.iconColor,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '招待日: ${invitation.createdAt.year}/${invitation.createdAt.month}/${invitation.createdAt.day}',
                                style: TextStyle(
                                  color: themeSettings.fontColor1,
                                  fontSize: 12 * themeSettings.fontSizeScale,
                                  fontFamily: themeSettings.fontFamily,
                                ),
                              ),
                            ],
                          ),
                          if (invitation.expiresAt != null) ...[
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.timer,
                                  size: 16,
                                  color: invitation.isExpired
                                      ? Colors.red
                                      : Colors.orange,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '有効期限: ${invitation.expiresAt!.year}/${invitation.expiresAt!.month}/${invitation.expiresAt!.day}',
                                  style: TextStyle(
                                    color: invitation.isExpired
                                        ? Colors.red
                                        : themeSettings.fontColor1,
                                    fontSize: 12 * themeSettings.fontSizeScale,
                                    fontFamily: themeSettings.fontFamily,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (invitation.isExpired) ...[
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red),
                              ),
                              child: Text(
                                '期限切れ',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12 * themeSettings.fontSizeScale,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: themeSettings.fontFamily,
                                ),
                              ),
                            ),
                          ],
                          if (!invitation.isExpired) ...[
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        _declineInvitation(invitation),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: Colors.grey),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      '拒否',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: themeSettings.fontFamily,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _acceptInvitation(invitation),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      '参加',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontFamily: themeSettings.fontFamily,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
                // QRコード読み取りオプション
                SizedBox(height: 16),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: themeSettings.cardBackgroundColor,
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.qr_code_scanner,
                              size: 32,
                              color: themeSettings.buttonColor,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'QRコードでグループ参加',
                                    style: TextStyle(
                                      color: themeSettings.fontColor1,
                                      fontSize:
                                          16 * themeSettings.fontSizeScale,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: themeSettings.fontFamily,
                                    ),
                                  ),
                                  Text(
                                    '他のメンバーからQRコードをもらって参加',
                                    style: TextStyle(
                                      color: themeSettings.fontColor1,
                                      fontSize:
                                          14 * themeSettings.fontSizeScale,
                                      fontFamily: themeSettings.fontFamily,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const GroupQRScannerPage(),
                              ),
                            );
                          },
                          icon: Icon(Icons.qr_code_scanner),
                          label: Text('QRコードを読み取る'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeSettings.buttonColor,
                            foregroundColor: themeSettings.fontColor2,
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _acceptInvitation(GroupInvitation invitation) async {
    final groupProvider = context.read<GroupProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ご注意'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person, color: Colors.blue, size: 32),
                SizedBox(width: 12),
                Icon(Icons.arrow_forward, color: Colors.grey, size: 28),
                SizedBox(width: 12),
                Icon(Icons.groups, color: Colors.orange, size: 36),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'グループに参加すると、今後はグループ全体で共有されるデータが表示・保存されます。\n\nグループを脱退すれば、もとの個人データに自動で切り替わります。\n\nこのまま進めてもよろしいですか？\n\n※グループアイコンは、グループを識別するために様々な画面で表示されます',
              style: TextStyle(fontSize: 15),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('OK'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await groupProvider.acceptInvitation(invitation.id);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${invitation.groupName}に参加しました'),
          backgroundColor: Colors.green,
        ),
      );
      // ホームページに自動遷移
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/',
        (route) => false, // すべてのページをクリア
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(groupProvider.error ?? '招待の承諾に失敗しました'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _declineInvitation(GroupInvitation invitation) async {
    final groupProvider = context.read<GroupProvider>();
    final success = await groupProvider.declineInvitation(invitation.id);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('招待を拒否しました'), backgroundColor: Colors.orange),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(groupProvider.error ?? '招待の拒否に失敗しました'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
