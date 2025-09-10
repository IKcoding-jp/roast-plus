import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'secure_auth_service.dart';

/// セッション管理サービス
/// セッションの有効期限管理、自動ログアウト、セッション統計を提供
class SessionManagementService {
  static const String _logName = 'SessionManagementService';
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // セッション設定
  static const Duration _sessionTimeout = Duration(hours: 24); // 24時間
  static const Duration _inactivityTimeout = Duration(
    hours: 8,
  ); // 8時間に延長（無操作タイムアウトを実質的に無効化）
  static const Duration _checkInterval = Duration(
    minutes: 30,
  ); // 30分間隔に変更（チェック頻度を下げる）

  static Timer? _sessionTimer;
  static Timer? _inactivityTimer;
  static DateTime? _lastActivityTime;
  static bool _isMonitoring = false;

  /// セッション管理を初期化
  static Future<void> initialize() async {
    try {
      developer.log('セッション管理サービスを初期化', name: _logName);

      // セッション監視を開始
      await _startSessionMonitoring();

      // 初期アクティビティ時間を設定
      _lastActivityTime = DateTime.now();

      developer.log('セッション管理サービス初期化完了', name: _logName);
    } catch (e) {
      developer.log('セッション管理サービス初期化エラー: $e', name: _logName);
      rethrow;
    }
  }

  /// セッション監視を開始
  static Future<void> _startSessionMonitoring() async {
    if (_isMonitoring) return;

    try {
      _isMonitoring = true;

      // セッション有効期限チェックのみ実行（無操作タイムアウトは無効化）
      _sessionTimer = Timer.periodic(_checkInterval, (timer) {
        _checkSessionValidity();
      });

      // 無操作タイムアウトチェックを無効化（勝手にログアウトする問題を修正）
      // _inactivityTimer = Timer.periodic(_checkInterval, (timer) {
      //   _checkInactivityTimeout();
      // });

      developer.log('セッション監視開始（無操作タイムアウト無効化）', name: _logName);
    } catch (e) {
      developer.log('セッション監視開始エラー: $e', name: _logName);
    }
  }

  /// セッション監視を停止
  static void stopMonitoring() {
    if (!_isMonitoring) return;

    developer.log('セッション監視を停止', name: _logName);
    _isMonitoring = false;
    _sessionTimer?.cancel();
    _inactivityTimer?.cancel();
    _sessionTimer = null;
    _inactivityTimer = null;
  }

  /// ユーザーアクティビティを記録
  static Future<void> recordUserActivity() async {
    try {
      _lastActivityTime = DateTime.now();

      // Firestoreにアクティビティを記録
      await _updateLastActivityTime();

      developer.log('ユーザーアクティビティを記録', name: _logName);
    } catch (e) {
      developer.log('ユーザーアクティビティ記録エラー: $e', name: _logName);
    }
  }

  /// セッション有効期限をチェック
  static Future<void> _checkSessionValidity() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // セッション開始時間を取得
      final sessionStartTime = await _getSessionStartTime();
      if (sessionStartTime == null) {
        await _setSessionStartTime();
        return;
      }

      // セッション有効期限をチェック
      final sessionAge = DateTime.now().difference(sessionStartTime);
      if (sessionAge > _sessionTimeout) {
        developer.log('セッション有効期限切れ', name: _logName);
        await _handleSessionExpiration('session_timeout');
      }
    } catch (e) {
      developer.log('セッション有効期限チェックエラー: $e', name: _logName);
    }
  }

  /// 無操作タイムアウトをチェック（未使用だが将来使用予定）
  // static Future<void> _checkInactivityTimeout() async {
  //   try {
  //     if (_lastActivityTime == null) return;

  //     final inactivityDuration = DateTime.now().difference(_lastActivityTime!);
  //     if (inactivityDuration > _inactivityTimeout) {
  //       developer.log('無操作タイムアウト', name: _logName);
  //       await _handleSessionExpiration('inactivity_timeout');
  //     }
  //   } catch (e) {
  //     developer.log('無操作タイムアウトチェックエラー: $e', name: _logName);
  //   }
  // }

  /// セッション期限切れの処理
  static Future<void> _handleSessionExpiration(String reason) async {
    try {
      // セキュリティログを記録
      await SecureAuthService.logSecurityEvent(
        'session_expired',
        details: {
          'reason': reason,
          'session_duration': _sessionTimeout.inHours,
          'inactivity_duration': _inactivityTimeout.inMinutes,
        },
      );

      // セッション統計を更新
      await _updateSessionStats(reason);

      // セキュアサインアウト
      await SecureAuthService.signOutSecurely();

      developer.log('セッション期限切れ処理完了: $reason', name: _logName);
    } catch (e) {
      developer.log('セッション期限切れ処理エラー: $e', name: _logName);
    }
  }

  /// セッション開始時間を取得
  static Future<DateTime?> _getSessionStartTime() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('session_data')
          .doc('current_session')
          .get();

      if (doc.exists && doc.data()?['startTime'] != null) {
        return (doc.data()!['startTime'] as Timestamp).toDate();
      }
      return null;
    } catch (e) {
      developer.log('セッション開始時間取得エラー: $e', name: _logName);
      return null;
    }
  }

  /// セッション開始時間を設定
  static Future<void> _setSessionStartTime() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('session_data')
          .doc('current_session')
          .set({
            'startTime': FieldValue.serverTimestamp(),
            'platform': defaultTargetPlatform.toString(),
            'sessionId': _generateSessionId(),
          });

      developer.log('セッション開始時間を設定', name: _logName);
    } catch (e) {
      developer.log('セッション開始時間設定エラー: $e', name: _logName);
    }
  }

  /// 最終アクティビティ時間を更新
  static Future<void> _updateLastActivityTime() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('session_data')
          .doc('current_session')
          .update({'lastActivityTime': FieldValue.serverTimestamp()});
    } catch (e) {
      developer.log('最終アクティビティ時間更新エラー: $e', name: _logName);
    }
  }

  /// セッション統計を更新
  static Future<void> _updateSessionStats(String expirationReason) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('session_stats')
          .doc('latest')
          .set({
            'lastSessionEnd': FieldValue.serverTimestamp(),
            'expirationReason': expirationReason,
            'totalSessions': FieldValue.increment(1),
            'platform': defaultTargetPlatform.toString(),
          }, SetOptions(merge: true));

      developer.log('セッション統計を更新', name: _logName);
    } catch (e) {
      developer.log('セッション統計更新エラー: $e', name: _logName);
    }
  }

  /// セッションIDを生成
  static String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return 'session_${timestamp}_$random';
  }

  /// セッションを延長
  static Future<void> extendSession() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // 新しいセッション開始時間を設定
      await _setSessionStartTime();

      // アクティビティを記録
      await recordUserActivity();

      // セキュリティログを記録
      await SecureAuthService.logSecurityEvent('session_extended');

      developer.log('セッションを延長', name: _logName);
    } catch (e) {
      developer.log('セッション延長エラー: $e', name: _logName);
    }
  }

  /// セッション情報を取得
  static Future<Map<String, dynamic>> getSessionInfo() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final sessionStartTime = await _getSessionStartTime();
      if (sessionStartTime == null) return {};

      final sessionAge = DateTime.now().difference(sessionStartTime);
      final remainingTime = _sessionTimeout - sessionAge;
      final inactivityDuration = _lastActivityTime != null
          ? DateTime.now().difference(_lastActivityTime!)
          : Duration.zero;
      final remainingInactivityTime = _inactivityTimeout - inactivityDuration;

      return {
        'sessionStartTime': sessionStartTime.toIso8601String(),
        'sessionAge': sessionAge.inMinutes,
        'remainingTime': remainingTime.inMinutes,
        'lastActivityTime': _lastActivityTime?.toIso8601String(),
        'inactivityDuration': inactivityDuration.inMinutes,
        'remainingInactivityTime': remainingInactivityTime.inMinutes,
        'isActive':
            remainingTime.isNegative == false &&
            remainingInactivityTime.isNegative == false,
      };
    } catch (e) {
      developer.log('セッション情報取得エラー: $e', name: _logName);
      return {};
    }
  }

  /// セッション統計を取得
  static Future<Map<String, dynamic>> getSessionStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('session_stats')
          .doc('latest')
          .get();

      return doc.data() ?? {};
    } catch (e) {
      developer.log('セッション統計取得エラー: $e', name: _logName);
      return {};
    }
  }

  /// セッション管理レポートを生成
  static Future<Map<String, dynamic>> generateSessionReport() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final sessionInfo = await getSessionInfo();
      final sessionStats = await getSessionStats();

      return {
        'timestamp': DateTime.now().toIso8601String(),
        'user_id': user.uid,
        'session_info': sessionInfo,
        'session_stats': sessionStats,
        'session_timeout_hours': _sessionTimeout.inHours,
        'inactivity_timeout_minutes': _inactivityTimeout.inMinutes,
        'platform': defaultTargetPlatform.toString(),
      };
    } catch (e) {
      developer.log('セッション管理レポート生成エラー: $e', name: _logName);
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// セッション設定を更新
  static Future<void> updateSessionSettings({
    Duration? sessionTimeout,
    Duration? inactivityTimeout,
  }) async {
    try {
      // 実際の実装では、設定をFirestoreに保存
      developer.log('セッション設定を更新', name: _logName);
    } catch (e) {
      developer.log('セッション設定更新エラー: $e', name: _logName);
    }
  }

  /// セッションを手動で終了
  static Future<void> terminateSession() async {
    try {
      // セキュリティログを記録
      await SecureAuthService.logSecurityEvent('session_terminated_manually');

      // セッション統計を更新
      await _updateSessionStats('manual_termination');

      // セキュアサインアウト
      await SecureAuthService.signOutSecurely();

      developer.log('セッションを手動で終了', name: _logName);
    } catch (e) {
      developer.log('セッション手動終了エラー: $e', name: _logName);
    }
  }
}
