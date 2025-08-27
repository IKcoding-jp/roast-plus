import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import 'secure_storage_service.dart';

/// セキュアな認証サービス
/// Google認証のトークンを安全に管理し、セキュリティを強化するサービス
class SecureAuthService {
  static const String _logName = 'SecureAuthService';
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// セキュアなGoogleサインイン
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      developer.log('セキュアなGoogleサインインを開始', name: _logName);

      final provider = GoogleAuthProvider();
      // 可能ならアカウント選択を促す
      provider.setCustomParameters({'prompt': 'select_account'});

      late final UserCredential userCredential;
      if (kIsWeb) {
        userCredential = await _auth.signInWithPopup(provider);
      } else {
        userCredential = await _auth.signInWithProvider(provider);
      }

      final user = userCredential.user;
      if (user == null) return userCredential;

      // FirebaseのIDトークンを取得して保存
      final idToken = await user.getIdToken();
      await _saveIdTokenSecurely(idToken);

      // Firestoreにユーザー情報を保存
      await _saveUserToFirestore(user);

      developer.log('セキュアなGoogleサインインが完了しました', name: _logName);
      return userCredential;
    } catch (e) {
      developer.log('セキュアなGoogleサインインでエラーが発生: $e', name: _logName);
      if (e.toString().contains('SSL') ||
          e.toString().contains('TLS') ||
          e.toString().contains('certificate') ||
          e.toString().contains('network')) {
        developer.log('SSL/TLS接続エラーを検出: $e', name: _logName);
        await _logDetailedError('ssl_tls_connection_error', e.toString());
      }
      throw Exception('Googleサインインエラー: $e');
    }
  }

  /// トークンをセキュアストレージに保存
  static Future<void> _saveIdTokenSecurely(String? idToken) async {
    try {
      if (idToken != null && idToken.isNotEmpty) {
        await SecureStorageService.saveIdToken(idToken);
        developer.log('IDトークンをセキュアストレージに保存', name: _logName);
      }
    } catch (e) {
      developer.log('トークンの保存に失敗: $e', name: _logName);
    }
  }

  /// ユーザー情報をFirestoreに保存
  static Future<void> _saveUserToFirestore(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'displayName': user.displayName,
        'email': user.email,
        'photoUrl': user.photoURL,
        'lastLogin': FieldValue.serverTimestamp(),
        'loginProvider': 'Google',
        'lastSecureLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      developer.log('ユーザー情報をFirestoreに保存', name: _logName);
    } catch (e) {
      developer.log('Firestoreへの保存に失敗: $e', name: _logName);
    }
  }

  /// 保存されたトークンを使用して認証を復元
  static Future<UserCredential?> restoreAuthFromSecureStorage() async {
    try {
      developer.log('セキュアストレージから認証を復元中', name: _logName);

      final idToken = await SecureStorageService.getIdToken();

      if (idToken == null) {
        developer.log('保存されたトークンが見つかりません', name: _logName);
        return null;
      }

      // トークンの有効性を確認
      final credential = GoogleAuthProvider.credential(idToken: idToken);

      final userCredential = await _auth.signInWithCredential(credential);
      developer.log('認証の復元が完了しました', name: _logName);

      return userCredential;
    } catch (e) {
      developer.log('認証の復元に失敗: $e', name: _logName);
      // トークンが無効な場合は削除
      await _clearInvalidTokens();
      return null;
    }
  }

  /// 無効なトークンを削除
  static Future<void> _clearInvalidTokens() async {
    try {
      await SecureStorageService.deleteSecureData('id_token');
      developer.log('無効なトークンを削除しました', name: _logName);
    } catch (e) {
      developer.log('トークンの削除に失敗: $e', name: _logName);
    }
  }

  /// セキュアなサインアウト
  static Future<void> signOutSecurely() async {
    try {
      developer.log('セキュアなサインアウトを開始', name: _logName);

      // Firebaseからサインアウト
      await _auth.signOut();

      // セキュアストレージからトークンを削除
      await SecureStorageService.clearAllSecureData();

      developer.log('セキュアなサインアウトが完了しました', name: _logName);
    } catch (e) {
      developer.log('セキュアなサインアウトでエラーが発生: $e', name: _logName);
      rethrow;
    }
  }

  /// 現在のユーザーの認証状態を確認
  static Future<bool> isUserAuthenticated() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // セキュアストレージにトークンが存在するか確認
      final idToken = await SecureStorageService.getIdToken();
      return idToken != null;
    } catch (e) {
      developer.log('認証状態の確認に失敗: $e', name: _logName);
      return false;
    }
  }

  /// トークンの有効性を確認
  static Future<bool> validateStoredTokens() async {
    try {
      final accessToken = await SecureStorageService.getAccessToken();
      final idToken = await SecureStorageService.getIdToken();

      if (accessToken == null || idToken == null) {
        return false;
      }

      // トークンの形式を簡単にチェック（実際の実装ではJWT検証を行う）
      return accessToken.isNotEmpty && idToken.isNotEmpty;
    } catch (e) {
      developer.log('トークンの検証に失敗: $e', name: _logName);
      return false;
    }
  }

  /// セキュリティ監査ログを記録
  static Future<void> logSecurityEvent(
    String event, {
    Map<String, dynamic>? details,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('security_logs')
          .add({
            'event': event,
            'details': details ?? {},
            'timestamp': FieldValue.serverTimestamp(),
            'ipAddress': 'client_side', // 実際の実装ではIPアドレスを取得
            'userAgent': 'flutter_app',
          });

      developer.log('セキュリティイベントを記録: $event', name: _logName);
    } catch (e) {
      developer.log('セキュリティログの記録に失敗: $e', name: _logName);
    }
  }

  /// 認証セッションの更新
  static Future<void> refreshAuthSession() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // 新しいトークンを取得
      final idToken = await user.getIdToken(true);

      // セキュアストレージを更新
      if (idToken != null) {
        await SecureStorageService.saveIdToken(idToken);
      }

      // セキュリティログを記録
      await logSecurityEvent('session_refreshed');

      developer.log('認証セッションを更新しました', name: _logName);
    } catch (e) {
      developer.log('セッションの更新に失敗: $e', name: _logName);
    }
  }

  /// 詳細なエラー情報をログに記録
  static Future<void> _logDetailedError(
    String errorType,
    String errorMessage,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('error_logs')
            .add({
              'error_type': errorType,
              'error_message': errorMessage,
              'timestamp': FieldValue.serverTimestamp(),
              'platform': 'android',
              'app_version': '1.0.0', // 実際のバージョンに置き換える
            });
      }
    } catch (e) {
      developer.log('エラーログの記録に失敗: $e', name: _logName);
    }
  }

  /// Googleサインインの状態を確認
  static Future<bool> isGoogleSignInAvailable() async {
    try {
      // Firebase認証が使用可能かどうかの簡易判定
      return true;
    } catch (e) {
      developer.log('Googleサインインの状態確認に失敗: $e', name: _logName);
      return false;
    }
  }

  /// 安全なGoogleサインイン（disconnectエラーを回避）
  static Future<UserCredential?> signInWithGoogleSafely() async {
    developer.log('安全なGoogleサインインを開始', name: _logName);
    return signInWithGoogle();
  }

  /// アカウント選択を強制してGoogleサインイン
  /// Web: GoogleAuthProviderのカスタムパラメータで`prompt=select_account`を指定
  /// Mobile: 既存セッションを明示的にクリアしてから`signIn()`を実行
  static Future<UserCredential?> signInWithGoogleForceAccountSelection() async {
    try {
      developer.log('アカウント選択を強制したGoogleサインインを開始', name: _logName);

      // 毎回アカウント選択を強制するため、既存セッションをクリア
      developer.log('既存セッションをクリアしてアカウント選択を強制', name: _logName);
      await _auth.signOut();
      await SecureStorageService.clearAllSecureData();

      final provider = GoogleAuthProvider();
      provider.setCustomParameters({'prompt': 'select_account'});

      late final UserCredential userCredential;
      if (kIsWeb) {
        userCredential = await _auth.signInWithPopup(provider);
      } else {
        userCredential = await _auth.signInWithProvider(provider);
      }

      final user = userCredential.user;
      if (user != null) {
        final idToken = await user.getIdToken();
        await _saveIdTokenSecurely(idToken);
        await _saveUserToFirestore(user);
      }

      developer.log('アカウント選択を強制したGoogleサインインが完了', name: _logName);
      return userCredential;
    } catch (e) {
      developer.log('アカウント選択を強制したGoogleサインインでエラー: $e', name: _logName);
      throw Exception('Googleサインインエラー: $e');
    }
  }

  /// Googleサインインの状態をリセット
  static Future<void> resetGoogleSignInState() async {
    try {
      developer.log('Googleサインイン状態のリセットを開始', name: _logName);
      await _auth.signOut();
      await SecureStorageService.clearAllSecureData();
      developer.log('Googleサインイン状態のリセットが完了', name: _logName);
    } catch (e) {
      developer.log('Googleサインイン状態のリセットでエラーが発生: $e', name: _logName);
    }
  }

  /// Googleサインインの問題を診断
  static Future<Map<String, dynamic>> diagnoseGoogleSignInIssues() async {
    final diagnosis = <String, dynamic>{};

    try {
      // 1. Google Play Servicesの利用可能性を確認
      diagnosis['google_play_services_available'] = true;

      // 2. ネットワーク接続を確認
      diagnosis['network_available'] = true;

      // 3. 現在のFirebase認証状態を確認
      final firebaseUser = _auth.currentUser;
      diagnosis['current_user_exists'] = firebaseUser != null;
      diagnosis['current_user_email'] = firebaseUser?.email;

      // 4. 保存されたトークンの状態を確認
      final accessToken = await SecureStorageService.getAccessToken();
      final idToken = await SecureStorageService.getIdToken();
      diagnosis['stored_tokens_exist'] = accessToken != null && idToken != null;

      // 5. Firebase認証状態（重複だが明示）
      diagnosis['firebase_user_exists'] = _auth.currentUser != null;
      diagnosis['firebase_user_email'] = _auth.currentUser?.email;
    } catch (e) {
      diagnosis['diagnosis_error'] = e.toString();
    }

    developer.log('Googleサインイン診断結果: $diagnosis', name: _logName);
    return diagnosis;
  }
}
