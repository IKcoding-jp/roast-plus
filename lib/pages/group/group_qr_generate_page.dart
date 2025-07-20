import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/group_provider.dart';
import '../../models/theme_settings.dart';
import '../../services/qr_code_service.dart';

class GroupQRGeneratePage extends StatefulWidget {
  const GroupQRGeneratePage({super.key});

  @override
  State<GroupQRGeneratePage> createState() => _GroupQRGeneratePageState();
}

class _GroupQRGeneratePageState extends State<GroupQRGeneratePage> {
  String? _qrData;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _generateQRCode();
  }

  Future<void> _generateQRCode() async {
    setState(() {
      _isGenerating = true;
    });

    final groupProvider = context.read<GroupProvider>();
    final group = groupProvider.currentGroup;

    if (group != null) {
      final qrData = QRCodeService.generateGroupJoinData(
        groupId: group.id,
        groupName: group.name,
        inviteCode: group.inviteCode,
      );

      setState(() {
        _qrData = qrData;
        _isGenerating = false;
      });
    } else {
      setState(() {
        _isGenerating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('グループ情報の取得に失敗しました'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);
    final groupProvider = Provider.of<GroupProvider>(context);
    final group = groupProvider.currentGroup;

    if (group == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'QRコード生成',
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
        body: Center(
          child: Text(
            'グループ情報が見つかりません',
            style: TextStyle(
              color: themeSettings.fontColor1,
              fontSize: 16 * themeSettings.fontSizeScale,
              fontFamily: themeSettings.fontFamily,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'QRコード生成',
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
            onPressed: _isGenerating ? null : _generateQRCode,
            icon: Icon(Icons.refresh),
            tooltip: '再生成',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // ヘッダーカード
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: themeSettings.backgroundColor2 ?? Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'グループ参加用QRコード',
                        style: TextStyle(
                          color: themeSettings.fontColor1,
                          fontSize: 18 * themeSettings.fontSizeScale,
                          fontWeight: FontWeight.bold,
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        group.name,
                        style: TextStyle(
                          color: themeSettings.fontColor2,
                          fontSize: 16 * themeSettings.fontSizeScale,
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // QRコード表示エリア
              if (_isGenerating)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            themeSettings.buttonColor,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'QRコードを生成中...',
                          style: TextStyle(
                            color: themeSettings.fontColor1,
                            fontSize: 16 * themeSettings.fontSizeScale,
                            fontFamily: themeSettings.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_qrData != null)
                Expanded(
                  child: SingleChildScrollView(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: QRCodeService.generateQRCode(
                              data: _qrData!,
                              size: 250,
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                            ),
                          ),
                          SizedBox(height: 24),
                          Text(
                            'このQRコードを他のメンバーに\n見せてグループに参加してもらいましょう',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: themeSettings.fontColor1,
                              fontSize: 14 * themeSettings.fontSizeScale,
                              fontFamily: themeSettings.fontFamily,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '※ QRコードは24時間で無効になります',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12 * themeSettings.fontSizeScale,
                              fontFamily: themeSettings.fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              SizedBox(height: 16),

              // 情報カード
              Card(
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
                            Icons.info_outline,
                            color: themeSettings.iconColor,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'QRコードについて',
                            style: TextStyle(
                              color: themeSettings.fontColor1,
                              fontSize: 16 * themeSettings.fontSizeScale,
                              fontWeight: FontWeight.bold,
                              fontFamily: themeSettings.fontFamily,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        '• QRコードを読み取ることでグループに参加できます\n'
                        '• 招待コードと同じ機能です\n'
                        '• 24時間で自動的に無効になります\n'
                        '• 再生成ボタンで新しいQRコードを作成できます\n'
                        '• 他のメンバーにQRコードを見せて参加してもらいましょう',
                        style: TextStyle(
                          color: themeSettings.fontColor1,
                          fontSize: 14 * themeSettings.fontSizeScale,
                          fontFamily: themeSettings.fontFamily,
                        ),
                      ),
                    ],
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
