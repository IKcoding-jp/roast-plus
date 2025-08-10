import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QRCodeService {
  // グループ参加用のQRコードデータを生成
  static String generateGroupJoinData({
    required String groupId,
    required String groupName,
    required String inviteCode,
  }) {
    final data = {
      'type': 'group_join',
      'groupId': groupId,
      'groupName': groupName,
      'inviteCode': inviteCode,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(data);
  }

  // QRコードデータを解析
  static Map<String, dynamic>? parseQRData(String data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded['type'] == 'group_join') {
        return decoded;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // QRコードウィジェットを生成
  static Widget generateQRCode({
    required String data,
    required double size,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    final fg = foregroundColor ?? Colors.black;
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: size,
      backgroundColor: backgroundColor ?? Colors.white,
      eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: fg),
      dataModuleStyle: QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: fg,
      ),
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );
  }

  // QRコードが有効かチェック（24時間以内）
  static bool isQRCodeValid(Map<String, dynamic> qrData) {
    final timestamp = qrData['timestamp'] as int?;
    if (timestamp == null) return false;

    final qrTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(qrTime);

    // 24時間以内のQRコードのみ有効
    return difference.inHours < 24;
  }
}
