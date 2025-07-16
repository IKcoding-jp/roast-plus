import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../models/theme_settings.dart';

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
                    '新しい招待が届くとここに表示されます',
                    style: TextStyle(
                      color: themeSettings.fontColor1,
                      fontSize: 14 * themeSettings.fontSizeScale,
                      fontFamily: themeSettings.fontFamily,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => groupProvider.loadInvitations(),
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: groupProvider.invitations.length,
              itemBuilder: (context, index) {
                final invitation = groupProvider.invitations[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 16),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: themeSettings.backgroundColor2 ?? Colors.white,
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
                              color: Colors.red.withOpacity(0.1),
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
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _acceptInvitation(GroupInvitation invitation) async {
    final groupProvider = context.read<GroupProvider>();
    final success = await groupProvider.acceptInvitation(invitation.id);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${invitation.groupName}に参加しました'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
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
