import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/foundation.dart';
import '../../models/group_provider.dart';
import '../../models/theme_settings.dart';
import '../../services/qr_code_service.dart';
import '../../services/group_invitation_service.dart';

class GroupQRScannerPage extends StatefulWidget {
  const GroupQRScannerPage({super.key});

  @override
  State<GroupQRScannerPage> createState() => _GroupQRScannerPageState();
}

class _GroupQRScannerPageState extends State<GroupQRScannerPage> {
  MobileScannerController? controller;
  bool _isScanning = true;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    // Web版ではスキャナーを初期化しない
    if (!kIsWeb) {
      controller = MobileScannerController();
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanning && capture.barcodes.isNotEmpty) {
      final barcode = capture.barcodes.first;
      if (barcode.rawValue != null) {
        _processQRCode(barcode.rawValue!);
      }
    }
  }

  Future<void> _processQRCode(String qrData) async {
    setState(() {
      _isScanning = false;
    });

    final parsedData = QRCodeService.parseQRData(qrData);
    if (parsedData == null) {
      _showError('無効なQRコードです');
      return;
    }

    if (!QRCodeService.isQRCodeValid(parsedData)) {
      _showError('QRコードの有効期限が切れています');
      return;
    }

    final groupId = parsedData['groupId'] as String?;
    final groupName = parsedData['groupName'] as String?;
    final inviteCode = parsedData['inviteCode'] as String?;

    if (groupId == null || groupName == null || inviteCode == null) {
      _showError('QRコードの情報が不完全です');
      return;
    }

    // グループ参加の確認ダイアログを表示
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('グループ参加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('以下のグループに参加しますか？'),
            SizedBox(height: 16),
            Text(
              groupName,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('招待コード: $inviteCode'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('参加する'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      setState(() {
        _isScanning = true;
      });
      return;
    }

    // グループに参加
    await _joinGroup(groupId, inviteCode);
  }

  Future<void> _joinGroup(String groupId, String inviteCode) async {
    setState(() {
      _isJoining = true;
    });

    try {
      // GroupInvitationServiceを使用してグループに参加
      final success = await GroupInvitationService.joinGroupWithInvitationCode(
        inviteCode,
      );

      if (success && mounted) {
        // 成功メッセージを表示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('グループに参加しました'), backgroundColor: Colors.green),
        );

        // グループプロバイダーを更新
        final groupProvider = context.read<GroupProvider>();
        await groupProvider.loadUserGroups();

        if (mounted) {
          // 少し待ってからホームページに自動遷移（状態更新の確実性のため）
          await Future.delayed(Duration(milliseconds: 500));

          // ホームページに自動遷移
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/',
              (route) => false, // すべてのページをクリア
            );
          }
        }
      }
    } catch (e) {
      // グループ参加エラー
      if (mounted) {
        _showError('グループの参加に失敗しました: $e');
      }
    }

    if (mounted) {
      setState(() {
        _isJoining = false;
      });
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
      setState(() {
        _isScanning = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'QRコード読み取り',
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
      body: Stack(
        children: [
          // Web版ではスキャナーを表示せず、メッセージを表示
          if (kIsWeb)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    size: 64,
                    color: themeSettings.iconColor,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'QRコードスキャンは\nモバイルアプリでのみ利用可能です',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16 * themeSettings.fontSizeScale,
                      fontFamily: themeSettings.fontFamily,
                      color: themeSettings.fontColor1,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Web版では利用できません',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14 * themeSettings.fontSizeScale,
                      fontFamily: themeSettings.fontFamily,
                      color: themeSettings.fontColor1.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            )
          else
            MobileScanner(controller: controller, onDetect: _onDetect),
          if (_isJoining)
            Container(
              color: Colors.black54,
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
                      'グループに参加中...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16 * themeSettings.fontSizeScale,
                        fontFamily: themeSettings.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(16),
              color: Colors.black54,
              child: Column(
                children: [
                  Text(
                    'QRコードをカメラで読み取って\nグループに参加しましょう',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14 * themeSettings.fontSizeScale,
                      fontFamily: themeSettings.fontFamily,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '※ グループ参加用のQRコードのみ読み取り可能です',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12 * themeSettings.fontSizeScale,
                      fontFamily: themeSettings.fontFamily,
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
}
