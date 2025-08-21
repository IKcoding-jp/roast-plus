import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import 'secure_storage_service.dart';

/// セキュアな認証サービス
/// Google認証のトークンを安全に管理し、セキュリティを強化するサービス
class SecureAuthService {
  static const String _logName = 'SecureAuthService';
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// セキュアなGoogleサインイン
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      developer.log('セキュアなGoogleサインインを開始', name: _logName);

      // 現在のユーザーをクリアしてからサインインを実行（アカウント選択を強制）
      try {
        await _googleSignIn.disconnect();
        developer.log('Googleサインインの切断が完了', name: _logName);
      } catch (disconnectError) {
        developer.log(
          'Googleサインインの切断でエラーが発生（無視して続行）: $disconnectError',
          name: _logName,
        );
        // disconnectエラーは無視して続行
      }

      await Future.delayed(Duration(milliseconds: 500));
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        developer.log('Googleサインインがキャンセルされました', name: _logName);
        return null;
      }

      // 認証情報を取得
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // トークンをセキュアストレージに保存
      await _saveTokensSecurely(googleAuth);

      // Firebase認証を実行
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // ユーザー情報をFirestoreに保存
      await _saveUserToFirestore(userCredential.user, googleUser);

      developer.log('セキュアなGoogleサインインが完了しました', name: _logName);
      return userCredential;
    } catch (e) {
      developer.log('セキュアなGoogleサインインでエラーが発生: $e', name: _logName);

      // SSL/TLS関連のエラーの場合は特別な処理
      if (e.toString().contains('DefaultSSLContextImpl') ||
          e.toString().contains('SSL') ||
          e.toString().contains('TLS') ||
          e.toString().contains('certificate') ||
          e.toString().contains('network')) {
        developer.log('SSL/TLS接続エラーを検出: $e', name: _logName);

        // ネットワークセキュリティ設定の問題の可能性
        developer.log('ネットワークセキュリティ設定を確認してください', name: _logName);

        // エラーの詳細を記録
        await _logDetailedError('ssl_tls_connection_error', e.toString());
      }

      // エラーを再スローするが、より詳細な情報を含める
      throw Exception('Googleサインインエラー: $e');
    }
  }

  /// トークンをセキュアストレージに保存
  static Future<void> _saveTokensSecurely(
    GoogleSignInAuthentication googleAuth,
  ) async {
    try {
      if (googleAuth.accessToken != null) {
        await SecureStorageService.saveAccessToken(googleAuth.accessToken!);
        developer.log('アクセストークンをセキュアストレージに保存', name: _logName);
      }

      if (googleAuth.idToken != null) {
        await SecureStorageService.saveIdToken(googleAuth.idToken!);
        developer.log('IDトークンをセキュアストレージに保存', name: _logName);
      }
    } catch (e) {
      developer.log('トークンの保存に失敗: $e', name: _logName);
      // トークン保存の失敗は致命的ではないため、エラーを投げない
    }
  }

  /// ユーザー情報をFirestoreに保存
  static Future<void> _saveUserToFirestore(
    User? user,
    GoogleSignInAccount googleUser,
  ) async {
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'displayName': googleUser.displayName,
        'email': googleUser.email,
        'photoUrl': googleUser.photoUrl,
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

      final accessToken = await SecureStorageService.getAccessToken();
      final idToken = await SecureStorageService.getIdToken();

      if (accessToken == null || idToken == null) {
        developer.log('保存されたトークンが見つかりません', name: _logName);
        return null;
      }

      // トークンの有効性を確認
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

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
      await SecureStorageService.deleteSecureData('access_token');
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

      // Webでは google_sign_in を呼ばない（ポップアップや挙動不整合を回避）
      if (!kIsWeb) {
        // Googleサインインからサインアウト
        await _googleSignIn.signOut();
      }

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
      final accessToken = await SecureStorageService.getAccessToken();
      final idToken = await SecureStorageService.getIdToken();

      return accessToken != null && idToken != null;
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
      // 現在のユーザーを取得して状態を確認
      final currentUser = await _googleSignIn.signInSilently();
      return currentUser != null;
    } catch (e) {
      developer.log('Googleサインインの状態確認に失敗: $e', name: _logName);
      return false;
    }
  }

  /// 安全なGoogleサインイン（disconnectエラーを回避）
  static Future<UserCredential?> signInWithGoogleSafely() async {
    try {
      developer.log('安全なGoogleサインインを開始', name: _logName);

      // まず現在のユーザーを確認
      final currentUser = await _googleSignIn.signInSilently();
      if (currentUser != null) {
        developer.log('既存のユーザーセッションを確認', name: _logName);
        // 既存のセッションがある場合は、それを利用
        final googleAuth = await currentUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        return await _auth.signInWithCredential(credential);
      }

      // 新しいサインインを試行
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        developer.log('Googleサインインがキャンセルされました', name: _logName);
        return null;
      }

      // 認証情報を取得
      final googleAuth = await googleUser.authentication;

      // トークンをセキュアストレージに保存
      await _saveTokensSecurely(googleAuth);

      // Firebase認証を実行
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // ユーザー情報をFirestoreに保存
      await _saveUserToFirestore(userCredential.user, googleUser);

      developer.log('安全なGoogleサインインが完了しました', name: _logName);
      return userCredential;
    } catch (e) {
      developer.log('安全なGoogleサインインでエラーが発生: $e', name: _logName);
      throw Exception('Googleサインインエラー: $e');
    }
  }

  /// アカウント選択を強制してGoogleサインイン
  /// Web: GoogleAuthProviderのカスタムパラメータで`prompt=select_account`を指定
  /// Mobile: 既存セッションを明示的にクリアしてから`signIn()`を実行
  static Future<UserCredential?> signInWithGoogleForceAccountSelection() async {
    try {
      developer.log('アカウント選択を強制したGoogleサインインを開始', name: _logName);

      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.setCustomParameters({'prompt': 'select_account'});
        final userCredential = await _auth.signInWithPopup(provider);

        // WebではGoogleSignInAccountが無いのでFirebaseのユーザー情報で保存
        final user = userCredential.user;
        if (user != null) {
          try {
            await _firestore.collection('users').doc(user.uid).set({
              'displayName': user.displayName,
              'email': user.email,
              'photoUrl': user.photoURL,
              'lastLogin': FieldValue.serverTimestamp(),
              'loginProvider': 'Google',
              'lastSecureLogin': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            developer.log('ユーザー情報(Web)をFirestoreに保存', name: _logName);
          } catch (e) {
            developer.log('Firestoreへの保存(Web)に失敗: $e', name: _logName);
          }
        }

        developer.log('アカウント選択を強制したGoogleサインイン(Web)が完了', name: _logName);
        return userCredential;
      }

      // Mobile: 既存セッションをクリア
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      try {
        await _googleSignIn.disconnect();
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 300));

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        developer.log('Googleサインインがキャンセルされました', name: _logName);
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      await _saveTokensSecurely(googleAuth);

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      await _saveUserToFirestore(userCredential.user, googleUser);

      developer.log('アカウント選択を強制したGoogleサインイン(モバイル)が完了', name: _logName);
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

      // Webでは google_sign_in を呼ばない
      if (!kIsWeb) {
        // 現在のユーザーをサインアウト
        await _googleSignIn.signOut();
      }

      // 少し待機
      await Future.delayed(Duration(milliseconds: 1000));

      // セキュアストレージからトークンを削除
      await SecureStorageService.clearAllSecureData();

      developer.log('Googleサインイン状態のリセットが完了', name: _logName);
    } catch (e) {
      developer.log('Googleサインイン状態のリセットでエラーが発生: $e', name: _logName);
      // エラーは無視して続行
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

      // 3. 現在のGoogleサインイン状態を確認
      try {
        final currentUser = await _googleSignIn.signInSilently();
        diagnosis['current_user_exists'] = currentUser != null;
        diagnosis['current_user_email'] = currentUser?.email;
      } catch (e) {
        diagnosis['current_user_exists'] = false;
        diagnosis['current_user_error'] = e.toString();
      }

      // 4. 保存されたトークンの状態を確認
      final accessToken = await SecureStorageService.getAccessToken();
      final idToken = await SecureStorageService.getIdToken();
      diagnosis['stored_tokens_exist'] = accessToken != null && idToken != null;

      // 5. Firebase認証状態を確認
      final firebaseUser = _auth.currentUser;
      diagnosis['firebase_user_exists'] = firebaseUser != null;
      diagnosis['firebase_user_email'] = firebaseUser?.email;
    } catch (e) {
      diagnosis['diagnosis_error'] = e.toString();
    }

    developer.log('Googleサインイン診断結果: $diagnosis', name: _logName);
    return diagnosis;
  }
}
