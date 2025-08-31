import 'dart:async';
import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'secure_auth_service.dart';
import 'secure_storage_service.dart';

/// セキュリティ監視サービス
/// リアルタイムでセキュリティ状態を監視し、異常を検出するサービス
class SecurityMonitorService {
  static const String _logName = 'SecurityMonitorService';
  static Timer? _monitoringTimer;
  static bool _isMonitoring = false;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// セキュリティ監視を開始
  static Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    try {
      developer.log('セキュリティ監視を開始', name: _logName);
      _isMonitoring = true;

      // 定期的なセキュリティチェック（30分間隔に変更）
      _monitoringTimer = Timer.periodic(Duration(minutes: 30), (timer) {
        _performSecurityCheck();
      });

      // 初回チェック
      await _performSecurityCheck();

      // 認証状態の変更を監視（無効化）
      // _auth.authStateChanges().listen((User? user) {
      //   _handleAuthStateChange(user);
      // });
    } catch (e) {
      developer.log('セキュリティ監視の開始に失敗: $e', name: _logName);
    }
  }

  /// セキュリティ監視を停止
  static void stopMonitoring() {
    if (!_isMonitoring) return;

    developer.log('セキュリティ監視を停止', name: _logName);
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }

  /// セキュリティチェックを実行
  static Future<void> _performSecurityCheck() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // 1. トークンの有効性チェック
      final isTokenValid = await SecureAuthService.validateStoredTokens();
      if (!isTokenValid) {
        await _handleSecurityViolation('invalid_tokens', 'トークンが無効です');
      }

      // 2. セキュアストレージの可用性チェック
      final isSecureStorageAvailable =
          await SecureStorageService.isSecureStorageAvailable();
      if (!isSecureStorageAvailable) {
        await _handleSecurityViolation(
          'secure_storage_unavailable',
          'セキュアストレージが利用できません',
        );
      }

      // 3. 認証状態の整合性チェック
      final isAuthenticated = await SecureAuthService.isUserAuthenticated();
      if (!isAuthenticated) {
        await _handleSecurityViolation(
          'authentication_mismatch',
          '認証状態に不整合があります',
        );
      }

      // 4. セッションの有効期限チェック（無効化）
      // await _checkSessionExpiration();

      developer.log('セキュリティチェック完了', name: _logName);
    } catch (e) {
      developer.log('セキュリティチェックでエラーが発生: $e', name: _logName);
    }
  }

  /// セッションの有効期限をチェック（未使用だが将来使用予定）
  // static Future<void> _checkSessionExpiration() async {
  //   try {
  //     final user = _auth.currentUser;
  //     if (user == null) return;

  //     // 最後のアクティビティ時間を取得
  //     final lastActivity = await _getLastActivityTime(user.uid);
  //     if (lastActivity != null) {
  //       final now = DateTime.now();
  //       final timeDifference = now.difference(lastActivity);
  // 
  //       // 30分以上アクティビティがない場合は警告
  //       if (timeDifference.inMinutes > 30) {
  //         await _handleSecurityViolation(
  //           'session_timeout',
  //           'セッションが長時間非アクティブです',
  //         );
  //       }
  //     }
  //   } catch (e) {
  //     developer.log('セッション有効期限チェックでエラー: $e', name: _logName);
  //   }
  // }

  /// 最後のアクティビティ時間を取得
  static Future<DateTime?> _getLastActivityTime(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('security_logs')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (doc.docs.isNotEmpty) {
        final data = doc.docs.first.data();
        final timestamp = data['timestamp'] as Timestamp?;
        return timestamp?.toDate();
      }
      return null;
    } catch (e) {
      developer.log('アクティビティ時間の取得に失敗: $e', name: _logName);
      return null;
    }
  }

  /// 認証状態の変更を処理（未使用だが将来使用予定）
  // static Future<void> _handleAuthStateChange(User? user) async {
  //   try {
  //     if (user != null) {
  //       // ログイン
  //       await SecureAuthService.logSecurityEvent(
  //         'auth_state_login',
  //         details: {'userId': user.uid, 'email': user.email},
  //       );

  //       // アクティビティ時間を更新
  //       await _updateLastActivityTime(user.uid);
  //     } else {
  //       // ログアウト
  //       await SecureAuthService.logSecurityEvent('auth_state_logout');

  //       // セキュアストレージをクリア
  //       await SecureStorageService.clearAllSecureData();
  //     }
  //   } catch (e) {
  //     developer.log('認証状態変更の処理に失敗: $e', name: _logName);
  //   }
  // }



  /// セキュリティ違反を処理
  static Future<void> _handleSecurityViolation(
    String violationType,
    String description,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // セキュリティ違反をログに記録
      await SecureAuthService.logSecurityEvent(
        'security_violation',
        details: {
          'type': violationType,
          'description': description,
          'severity': 'high',
        },
      );

      // 必要に応じて自動的な対応を実行
      await _handleViolationResponse(violationType);

      developer.log(
        'セキュリティ違反を検出: $violationType - $description',
        name: _logName,
      );
    } catch (e) {
      developer.log('セキュリティ違反の処理に失敗: $e', name: _logName);
    }
  }

  /// 違反に対する対応を実行
  static Future<void> _handleViolationResponse(String violationType) async {
    switch (violationType) {
      case 'invalid_tokens':
        // 無効なトークンを削除（ログアウトは行わない）
        await SecureStorageService.deleteSecureData('access_token');
        await SecureStorageService.deleteSecureData('id_token');
        break;

      case 'authentication_mismatch':
        // 認証状態のリセットを無効化（勝手にログアウトする問題を修正）
        // await _auth.signOut();
        developer.log('認証状態の不整合を検出しましたが、ログアウトは行いません', name: _logName);
        break;

      case 'session_timeout':
        // セッションを更新
        await SecureAuthService.refreshAuthSession();
        break;

      default:
        // その他の違反はログのみ
        break;
    }
  }

  /// セキュリティレポートを生成
  static Future<Map<String, dynamic>> generateSecurityReport() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'error': 'ユーザーが認証されていません'};
      }

      final report = {
        'userId': user.uid,
        'email': user.email,
        'generatedAt': DateTime.now().toIso8601String(),
        'securityStatus': {
          'isMonitoring': _isMonitoring,
          'isTokenValid': await SecureAuthService.validateStoredTokens(),
          'isSecureStorageAvailable':
              await SecureStorageService.isSecureStorageAvailable(),
          'isAuthenticated': await SecureAuthService.isUserAuthenticated(),
        },
        'recentViolations': await _getRecentViolations(user.uid),
        'lastActivity': await _getLastActivityTime(user.uid),
      };

      return report;
    } catch (e) {
      developer.log('セキュリティレポートの生成に失敗: $e', name: _logName);
      return {'error': 'レポートの生成に失敗しました: $e'};
    }
  }

  /// 最近のセキュリティ違反を取得
  static Future<List<Map<String, dynamic>>> _getRecentViolations(
    String userId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('security_logs')
          .where('event', isEqualTo: 'security_violation')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      developer.log('最近の違反の取得に失敗: $e', name: _logName);
      return [];
    }
  }

  /// セキュリティ監視の状態を取得
  static bool get isMonitoring => _isMonitoring;
}
