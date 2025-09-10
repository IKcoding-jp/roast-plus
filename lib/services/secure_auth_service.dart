import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
// 'google_sign_in' は現在未使用のためインポートはコメントアウト（将来的に必要なら復活）
// import 'package:google_sign_in/google_sign_in.dart';
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

      // Web版でのFirebase初期化状態を確認
      if (kIsWeb) {
        developer.log('Web版: Firebase初期化状態を確認中', name: _logName);
        final apps = Firebase.apps;
        developer.log('Web版: Firebaseアプリ数: ${apps.length}', name: _logName);

        if (apps.isEmpty) {
          developer.log('Web版: Firebaseアプリが初期化されていません', name: _logName);
          // Web版ではFirebase初期化を試行
          try {
            developer.log('Web版: Firebase初期化を試行中', name: _logName);
            await Firebase.initializeApp(
              options: await DefaultFirebaseOptions.currentPlatform,
            );
            developer.log('Web版: Firebase初期化完了', name: _logName);
          } catch (initError) {
            developer.log('Web版: Firebase初期化に失敗: $initError', name: _logName);
            throw Exception('Firebaseが初期化されていません。ページを再読み込みしてください。');
          }
        }
      }

      final provider = GoogleAuthProvider();
      // 可能ならアカウント選択を促す
      provider.setCustomParameters({
        'prompt': 'select_account',
        'hd': '', // ドメイン制限を無効化
        'include_granted_scopes': 'true',
        'access_type': 'offline', // Chrome用の追加パラメータ
      });

      late final UserCredential userCredential;
      if (kIsWeb) {
        // Web版ではポップアップ方式を使用（localhost開発用）
        developer.log('Web版: ポップアップ方式でGoogleサインインを試行', name: _logName);
        developer.log('Web版: 現在のURL: ${Uri.base}', name: _logName);
        developer.log('Web版: プロバイダーID: ${provider.providerId}', name: _logName);
        userCredential = await _auth.signInWithPopup(provider);
        developer.log('Web版: ポップアップ方式でサインイン成功', name: _logName);
      } else {
        developer.log('ネイティブ版: signInWithProviderを実行', name: _logName);
        developer.log(
          'ネイティブ版: プロバイダー設定: ${provider.providerId}',
          name: _logName,
        );
        developer.log(
          'ネイティブ版: プロバイダーID: ${provider.providerId}',
          name: _logName,
        );

        try {
          userCredential = await _auth.signInWithProvider(provider);
          developer.log('ネイティブ版: signInWithProvider完了', name: _logName);
        } catch (e) {
          developer.log('ネイティブ版: signInWithProviderでエラー: $e', name: _logName);
          developer.log('ネイティブ版: エラータイプ: ${e.runtimeType}', name: _logName);
          rethrow;
        }
      }

      final user = userCredential.user;
      if (user == null) {
        developer.log('ユーザー情報が取得できませんでした', name: _logName);
        return userCredential;
      }

      developer.log('ユーザー情報取得成功: ${user.email}', name: _logName);

      // FirebaseのIDトークンを取得して保存
      final idToken = await user.getIdToken();
      await _saveIdTokenSecurely(idToken);

      // Firestoreにユーザー情報を保存
      await _saveUserToFirestore(user);

      developer.log('セキュアなGoogleサインインが完了しました', name: _logName);
      return userCredential;
    } catch (e) {
      developer.log('セキュアなGoogleサインインでエラーが発生: $e', name: _logName);

      // Web版特有のエラーハンドリング
      if (kIsWeb) {
        if (e.toString().contains('popup_blocked')) {
          developer.log('Web版: ポップアップがブロックされました', name: _logName);
          throw Exception('ポップアップがブロックされています。ブラウザの設定でポップアップを許可してください。');
        }

        if (e.toString().contains('auth/popup-closed-by-user')) {
          developer.log('Web版: ユーザーがポップアップを閉じました', name: _logName);
          throw Exception('ログインがキャンセルされました。');
        }

        if (e.toString().contains('auth/unauthorized-domain')) {
          developer.log('Web版: 未承認ドメインエラー', name: _logName);
          throw Exception(
            'このドメインは認証に使用できません。Firebase Consoleでlocalhostドメインを追加してください。',
          );
        }

        if (e.toString().contains('auth/operation-not-allowed')) {
          developer.log('Web版: Google認証が有効になっていません', name: _logName);
          throw Exception(
            'Google認証が有効になっていません。Firebase ConsoleでGoogle認証を有効にしてください。',
          );
        }

        if (e.toString().contains('frame-ancestors') ||
            e.toString().contains('CSP')) {
          developer.log('Web版: CSPエラーが検出されました', name: _logName);
          throw Exception('セキュリティポリシーの問題が発生しました。ページを再読み込みしてから再度お試しください。');
        }

        if (e.toString().contains('auth/network-request-failed')) {
          developer.log('Web版: ネットワークエラー', name: _logName);
          throw Exception('ネットワークエラーが発生しました。インターネット接続を確認してください。');
        }
      }

      // invalid-cert-hashエラーの詳細なログ記録
      if (e.toString().contains('invalid-cert-hash')) {
        developer.log(
          '署名証明書ハッシュエラーが発生しました。これはGoogle Playからインストールしたアプリでよく発生する問題です。',
          name: _logName,
        );
        developer.log(
          '解決方法: Firebase Consoleでリリース用の署名証明書ハッシュを追加してください。',
          name: _logName,
        );
        developer.log('現在のアプリID: com.ikcoding.roastplus', name: _logName);
        developer.log(
          'リリース用SHA1ハッシュ: DF:B6:AE:56:F6:B9:D0:6D:69:19:35:F2:75:63:10:CC:56:19:8A:1D',
          name: _logName,
        );
        await _logDetailedError('invalid_cert_hash_error', e.toString());
      }

      if (e.toString().contains('SSL') ||
          e.toString().contains('TLS') ||
          e.toString().contains('certificate') ||
          e.toString().contains('network')) {
        developer.log('SSL/TLS接続エラーを検出: $e', name: _logName);
        await _logDetailedError('ssl_tls_connection_error', e.toString());
      }

      // エラーの詳細をログに記録
      developer.log('エラーの詳細: ${e.runtimeType} - $e', name: _logName);
      await _logDetailedError('google_signin_error', e.toString());

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
      // 既存のカスタム表示名を保持するため、まず現在のデータを取得
      final existingDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      String? displayNameToSave = user.displayName;

      if (existingDoc.exists) {
        final existingData = existingDoc.data();
        // カスタム表示名が設定されている場合はそれを保持
        if (existingData != null &&
            existingData['displayName'] != null &&
            existingData['displayName'] != user.displayName) {
          displayNameToSave = existingData['displayName'];
        }
      }

      await _firestore.collection('users').doc(user.uid).set({
        'displayName': displayNameToSave,
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
      if (user == null) {
        developer.log('認証状態確認: ユーザーがnull', name: _logName);
        return false;
      }

      developer.log('認証状態確認: ユーザーが存在 - ${user.email}', name: _logName);

      // Web版ではセキュアストレージのチェックをスキップ
      if (kIsWeb) {
        developer.log('Web版: 認証状態確認完了', name: _logName);
        return true;
      }

      // ネイティブ版ではセキュアストレージにトークンが存在するか確認
      final idToken = await SecureStorageService.getIdToken();
      final hasToken = idToken != null;
      developer.log('ネイティブ版: トークン存在確認 - $hasToken', name: _logName);
      return hasToken;
    } catch (e) {
      developer.log('認証状態の確認に失敗: $e', name: _logName);
      return false;
    }
  }

  /// 認証状態を強制的に更新（デバッグ用）
  static Future<void> forceAuthStateRefresh() async {
    try {
      developer.log('認証状態の強制更新を開始', name: _logName);

      // 現在のユーザーを再取得
      await _auth.currentUser?.reload();
      final user = _auth.currentUser;

      developer.log('認証状態強制更新完了 - user: ${user?.email}', name: _logName);
    } catch (e) {
      developer.log('認証状態の強制更新でエラー: $e', name: _logName);
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
      // Web版ではFirebaseExceptionの型エラーを回避するため、エラーログ記録をスキップ
      if (kIsWeb) {
        developer.log('Web版: エラーログ記録をスキップ（型エラー回避）', name: _logName);
        developer.log('エラー詳細: $errorType - $errorMessage', name: _logName);
        return;
      }

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
              'platform': kIsWeb ? 'web' : 'android',
              'app_version': '1.0.0', // 実際のバージョンに置き換える
            });
      }
    } catch (e) {
      developer.log('エラーログの記録に失敗: $e', name: _logName);
      // Web版ではFirebaseExceptionの型エラーを特別に処理
      if (kIsWeb && e.toString().contains('JavaScriptObject')) {
        developer.log(
          'Web版: FirebaseException型エラーを検出、エラーログ記録をスキップ',
          name: _logName,
        );
      }
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
      provider.setCustomParameters({
        'prompt': 'select_account',
        'hd': '', // ドメイン制限を無効化
        'include_granted_scopes': 'true',
      });

      late final UserCredential userCredential;
      if (kIsWeb) {
        // Web版ではリダイレクト方式を優先使用（CSP問題を回避）
        try {
          await _auth.signInWithRedirect(provider);
          return null; // リダイレクトが開始されたので処理を終了
        } catch (redirectError) {
          // リダイレクトが失敗した場合はポップアップ方式にフォールバック
          userCredential = await _auth.signInWithPopup(provider);
        }
      } else {
        // Mobile: FirebaseAuth のプロバイダ経由でサインイン
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

  /// Web版でのGoogleサインイン（リダイレクト方式）
  /// ポップアップがブロックされた場合の代替手段
  static Future<void> signInWithGoogleRedirect() async {
    try {
      developer.log('Web版: Googleサインイン（リダイレクト方式）を開始', name: _logName);

      if (!kIsWeb) {
        throw Exception('リダイレクト方式はWeb版でのみ使用できます');
      }

      final provider = GoogleAuthProvider();
      provider.setCustomParameters({
        'prompt': 'select_account',
        'hd': '', // ドメイン制限を無効化
        'include_granted_scopes': 'true',
      });

      await _auth.signInWithRedirect(provider);
      developer.log('Web版: リダイレクトが開始されました', name: _logName);
    } catch (e) {
      developer.log('Web版: リダイレクト方式でエラー: $e', name: _logName);
      throw Exception('Googleサインイン（リダイレクト）エラー: $e');
    }
  }

  /// リダイレクト後の認証結果を取得
  static Future<UserCredential?> getRedirectResult() async {
    try {
      developer.log('Web版: リダイレクト結果を取得中', name: _logName);

      if (!kIsWeb) {
        return null;
      }

      // Web版でのFirebase初期化状態を確認
      final apps = Firebase.apps;
      if (apps.isEmpty) {
        developer.log('Web版: Firebaseアプリが初期化されていません', name: _logName);
        // Web版ではFirebase初期化を試行
        try {
          developer.log('Web版: Firebase初期化を試行中', name: _logName);
          await Firebase.initializeApp(
            options: await DefaultFirebaseOptions.currentPlatform,
          );
          developer.log('Web版: Firebase初期化完了', name: _logName);
        } catch (initError) {
          developer.log('Web版: Firebase初期化に失敗: $initError', name: _logName);
          return null;
        }
      }

      final userCredential = await _auth.getRedirectResult();

      if (userCredential.user != null) {
        final user = userCredential.user!;
        developer.log('Web版: リダイレクト認証成功: ${user.email}', name: _logName);

        final idToken = await user.getIdToken();
        await _saveIdTokenSecurely(idToken);
        await _saveUserToFirestore(user);

        // セキュリティイベントを記録
        await logSecurityEvent('web_redirect_login_success');

        developer.log('Web版: リダイレクト認証処理完了', name: _logName);
      } else {
        developer.log('Web版: リダイレクト認証結果なし', name: _logName);
      }

      return userCredential;
    } catch (e) {
      developer.log('Web版: リダイレクト結果取得エラー: $e', name: _logName);
      await _logDetailedError('web_redirect_result_error', e.toString());
      return null;
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
}
