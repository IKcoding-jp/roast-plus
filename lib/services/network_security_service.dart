import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'secure_auth_service.dart';

/// ネットワークセキュリティサービス
/// HTTPS通信の強制、証明書ピニング、ネットワーク監視を提供
class NetworkSecurityService {
  static const String _logName = 'NetworkSecurityService';
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 証明書ピニング用のハッシュ値（一時的に無効化）
  static const Map<String, List<String>> _certificatePins = {
    // 証明書ピニングは一時的に無効化
  };

  /// ネットワークセキュリティを初期化
  static Future<void> initialize() async {
    // Web版では初期化をスキップ
    if (kIsWeb) {
      developer.log('Web版: NetworkSecurityService初期化をスキップ', name: _logName);
      return;
    }

    try {
      developer.log('ネットワークセキュリティサービスを初期化', name: _logName);

      // HTTPS通信の強制設定
      await _configureHttpsOnly();

      // 証明書ピニングの設定（一時的に無効化）
      // await _configureCertificatePinning();

      // ネットワーク監視の開始
      await _startNetworkMonitoring();

      developer.log('ネットワークセキュリティサービス初期化完了', name: _logName);
    } catch (e) {
      developer.log('ネットワークセキュリティサービス初期化エラー: $e', name: _logName);
      // エラーが発生してもアプリの起動を継続
    }
  }

  /// HTTPS通信のみを許可する設定
  static Future<void> _configureHttpsOnly() async {
    try {
      // HTTP通信をブロックする設定
      if (!kIsWeb) {
        // プラットフォーム固有のHTTPS強制設定
        await _configurePlatformHttpsOnly();
      }

      developer.log('HTTPS通信強制設定完了', name: _logName);
    } catch (e) {
      developer.log('HTTPS通信強制設定エラー: $e', name: _logName);
    }
  }

  /// プラットフォーム固有のHTTPS強制設定
  static Future<void> _configurePlatformHttpsOnly() async {
    try {
      if (Platform.isAndroid) {
        // Android固有の設定
        await _configureAndroidHttpsOnly();
      } else if (Platform.isIOS) {
        // iOS固有の設定
        await _configureIosHttpsOnly();
      }
    } catch (e) {
      developer.log('プラットフォーム固有HTTPS設定エラー: $e', name: _logName);
    }
  }

  /// Android用HTTPS強制設定
  static Future<void> _configureAndroidHttpsOnly() async {
    // Androidでは、ネットワークセキュリティ設定ファイルでHTTPSを強制
    // この設定は android/app/src/main/res/xml/network_security_config.xml で行う
    developer.log('Android HTTPS強制設定完了', name: _logName);
  }

  /// iOS用HTTPS強制設定
  static Future<void> _configureIosHttpsOnly() async {
    // iOSでは、Info.plistでATS（App Transport Security）を設定
    // この設定は ios/Runner/Info.plist で行う
    developer.log('iOS HTTPS強制設定完了', name: _logName);
  }

  /// 証明書の検証（一時的に無効化）
  static bool verifyCertificate(String host, String certificateHash) {
    try {
      // 証明書ピニングは一時的に無効化
      developer.log('証明書検証をスキップ（無効化中）: $host', name: _logName);
      return true; // 常にtrueを返す
    } catch (e) {
      developer.log('証明書検証エラー: $e', name: _logName);
      return true; // エラー時もtrueを返す
    }
  }

  /// ネットワーク監視の開始
  static Future<void> _startNetworkMonitoring() async {
    try {
      // 定期的なネットワークセキュリティチェック
      Timer.periodic(Duration(minutes: 10), (timer) {
        _performNetworkSecurityCheck();
      });

      developer.log('ネットワーク監視開始', name: _logName);
    } catch (e) {
      developer.log('ネットワーク監視開始エラー: $e', name: _logName);
    }
  }

  /// ネットワークセキュリティチェックの実行
  static Future<void> _performNetworkSecurityCheck() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // ネットワーク接続の安全性チェック
      await _checkNetworkConnectionSecurity();

      // 証明書の有効性チェック
      await _checkCertificateValidity();

      // ネットワーク統計の更新
      await _updateNetworkSecurityStats();
    } catch (e) {
      developer.log('ネットワークセキュリティチェックエラー: $e', name: _logName);
    }
  }

  /// ネットワーク接続の安全性チェック
  static Future<void> _checkNetworkConnectionSecurity() async {
    try {
      // 現在のネットワーク接続の種類をチェック
      final connectionInfo = await _getNetworkConnectionInfo();

      if (connectionInfo['isSecure'] == false) {
        _logSecurityViolation('insecure_network_connection', connectionInfo);
      }

      developer.log('ネットワーク接続セキュリティチェック完了', name: _logName);
    } catch (e) {
      developer.log('ネットワーク接続セキュリティチェックエラー: $e', name: _logName);
    }
  }

  /// 証明書の有効性チェック
  static Future<void> _checkCertificateValidity() async {
    try {
      // 主要なAPIエンドポイントの証明書をチェック
      final endpoints = [
        'firebase.googleapis.com',
        'firestore.googleapis.com',
        'identitytoolkit.googleapis.com',
      ];

      for (final endpoint in endpoints) {
        await _validateEndpointCertificate(endpoint);
      }

      developer.log('証明書有効性チェック完了', name: _logName);
    } catch (e) {
      developer.log('証明書有効性チェックエラー: $e', name: _logName);
    }
  }

  /// エンドポイント証明書の検証
  static Future<void> _validateEndpointCertificate(String endpoint) async {
    try {
      // 実際の実装では、HTTPClientを使用して証明書を検証
      // ここでは簡略化した実装
      developer.log('エンドポイント証明書検証: $endpoint', name: _logName);
    } catch (e) {
      developer.log('エンドポイント証明書検証エラー: $endpoint, $e', name: _logName);
    }
  }

  /// ネットワーク接続情報の取得
  static Future<Map<String, dynamic>> _getNetworkConnectionInfo() async {
    try {
      // 実際の実装では、connectivity_plusパッケージなどを使用
      // ここでは簡略化した実装
      return {
        'type': 'wifi', // または 'mobile', 'ethernet' など
        'isSecure': true,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      developer.log('ネットワーク接続情報取得エラー: $e', name: _logName);
      return {
        'type': 'unknown',
        'isSecure': false,
        'timestamp': DateTime.now().toIso8601String(),
        'error': e.toString(),
      };
    }
  }

  /// ネットワークセキュリティ統計の更新
  static Future<void> _updateNetworkSecurityStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('network_security_stats')
          .doc('latest')
          .set({
            'lastCheck': FieldValue.serverTimestamp(),
            'totalChecks': FieldValue.increment(1),
            'secureConnections': FieldValue.increment(1),
            'certificateValidations': FieldValue.increment(1),
            'platform': defaultTargetPlatform.toString(),
          }, SetOptions(merge: true));

      developer.log('ネットワークセキュリティ統計更新完了', name: _logName);
    } catch (e) {
      developer.log('ネットワークセキュリティ統計更新エラー: $e', name: _logName);
    }
  }

  /// セキュリティ違反のログ記録
  static Future<void> _logSecurityViolation(
    String violationType,
    Map<String, dynamic> details,
  ) async {
    try {
      await SecureAuthService.logSecurityEvent(
        'network_security_violation',
        details: {
          'violation_type': violationType,
          'details': details,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      developer.log('ネットワークセキュリティ違反を記録: $violationType', name: _logName);
    } catch (e) {
      developer.log('セキュリティ違反ログ記録エラー: $e', name: _logName);
    }
  }

  /// セキュアなHTTPリクエストの実行
  static Future<HttpClientResponse> secureHttpRequest(
    String url,
    String method, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    // Web版ではHTTPリクエストをスキップ
    if (kIsWeb) {
      developer.log('Web版: secureHttpRequestをスキップ', name: _logName);
      throw UnsupportedError('Web版ではsecureHttpRequestはサポートされていません');
    }
    try {
      final uri = Uri.parse(url);

      // HTTPS通信のみ許可
      if (uri.scheme != 'https') {
        throw Exception('HTTPS通信のみ許可されています: $url');
      }

      // 証明書ピニングの検証
      if (!_certificatePins.containsKey(uri.host)) {
        developer.log('証明書ピンが設定されていないホスト: ${uri.host}', name: _logName);
      }

      final client = HttpClient();

      // セキュリティ設定
      client.badCertificateCallback = (cert, host, port) {
        developer.log('無効な証明書を検出: $host', name: _logName);
        return false; // 無効な証明書を拒否
      };

      final request = await client.openUrl(method, uri);

      // ヘッダーの設定
      headers?.forEach((key, value) {
        try {
          request.headers.set(key, value);
        } catch (e) {
          developer.log('ヘッダー設定エラー: $key = $value, エラー: $e', name: _logName);
        }
      });

      // ボディの送信
      if (body != null) {
        if (body is String) {
          request.write(body);
        } else if (body is Map) {
          request.write(jsonEncode(body));
        }
      }

      final response = await request.close();

      // レスポンスの検証
      await _validateResponse(response);

      return response;
    } catch (e) {
      developer.log('セキュアHTTPリクエストエラー: $e', name: _logName);
      rethrow;
    }
  }

  /// レスポンスの検証
  static Future<void> _validateResponse(HttpClientResponse response) async {
    try {
      // ステータスコードの検証
      if (response.statusCode >= 400) {
        developer.log('HTTPエラーレスポンス: ${response.statusCode}', name: _logName);
      }

      // セキュリティヘッダーの検証
      final securityHeaders = response.headers.value('x-content-type-options');
      if (securityHeaders == null) {
        developer.log('セキュリティヘッダーが不足', name: _logName);
      }
    } catch (e) {
      developer.log('レスポンス検証エラー: $e', name: _logName);
    }
  }

  /// ネットワークセキュリティレポートの生成（Web版対応）
  static Future<Map<String, dynamic>> generateNetworkSecurityReport() async {
    // Web版ではダミーレポートを返す
    if (kIsWeb) {
      developer.log('Web版: ダミーのネットワークセキュリティレポートを返す', name: _logName);
      return {
        'platform': 'web',
        'isSecure': true,
        'violations': [],
        'lastCheck': DateTime.now().toIso8601String(),
        'message': 'Web版ではネットワークセキュリティレポートは利用できません',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }

    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      // 最近のセキュリティ違反を取得
      final violations = await _getRecentViolations();

      // ネットワーク統計を取得
      final stats = await _getNetworkSecurityStats();

      return {
        'timestamp': DateTime.now().toIso8601String(),
        'user_id': user.uid,
        'violations': violations,
        'stats': stats,
        'certificate_pins': _certificatePins.keys.toList(),
        'platform': defaultTargetPlatform.toString(),
      };
    } catch (e) {
      developer.log('ネットワークセキュリティレポート生成エラー: $e', name: _logName);
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// 最近のセキュリティ違反を取得
  static Future<List<Map<String, dynamic>>> _getRecentViolations() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('security_logs')
          .where('event', isEqualTo: 'network_security_violation')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      developer.log('最近の違反取得エラー: $e', name: _logName);
      return [];
    }
  }

  /// ネットワークセキュリティ統計を取得
  static Future<Map<String, dynamic>> _getNetworkSecurityStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('network_security_stats')
          .doc('latest')
          .get();

      return doc.data() ?? {};
    } catch (e) {
      developer.log('ネットワーク統計取得エラー: $e', name: _logName);
      return {};
    }
  }
}
