import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'consent_flow_service.dart';

/// 初回ログイン判定と表示名設定のサービス
class FirstLoginService {
  static const String _logName = 'FirstLoginService';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 初回ログインかどうかを判定
  static Future<bool> isFirstLogin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      developer.log('初回ログイン判定を開始: ${user.uid}', name: _logName);

      // Web版ではFirestoreの初期化を待つ（ネットワーク有効化はスキップ）
      if (!kIsWeb) {
        await _firestore.enableNetwork();
      }

      // Firestoreからユーザー情報を取得（タイムアウト付き）
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(Duration(seconds: 15));

      if (!userDoc.exists) {
        // フォールバック: Authプロフィールに表示名がある場合は初回ログインではないとみなす
        final profileName = user.displayName;
        if (profileName != null && profileName.trim().isNotEmpty) {
          developer.log(
            'Firestore未作成だがAuthに表示名あり → 初回ログインではないと判定',
            name: _logName,
          );
          return false;
        }
        developer.log('ユーザードキュメントが存在しないため初回ログインと判定', name: _logName);
        return true;
      }

      final userData = userDoc.data();
      if (userData == null) {
        final profileName = user.displayName;
        if (profileName != null && profileName.trim().isNotEmpty) {
          developer.log(
            'FirestoreデータnullだがAuthに表示名あり → 初回ログインではないと判定',
            name: _logName,
          );
          return false;
        }
        developer.log('ユーザーデータがnullのため初回ログインと判定', name: _logName);
        return true;
      }

      // 表示名が設定されているかチェック（Googleアカウントの表示名と同じでもOK）
      final hasDisplayName =
          userData['displayName'] != null &&
          userData['displayName'].toString().isNotEmpty;

      if (!hasDisplayName) {
        final profileName = user.displayName;
        if (profileName != null && profileName.trim().isNotEmpty) {
          developer.log(
            'Firestoreに表示名なしだがAuthに表示名あり → 初回ログインではないと判定',
            name: _logName,
          );
          return false;
        }
        developer.log('表示名が未設定のため初回ログインと判定', name: _logName);
        return true;
      }

      developer.log('初回ログインではないと判定', name: _logName);
      return false;
    } catch (e) {
      developer.log('初回ログイン判定でエラーが発生: $e', name: _logName);

      // Web版でのFirestore接続エラーの場合は、より詳細なログを出力
      if (e.toString().contains('network') ||
          e.toString().contains('timeout')) {
        developer.log('Web版: Firestore接続エラーのため初回ログインとして扱う', name: _logName);
      }

      // フォールバック: Authプロフィールに表示名があれば初回ログインではないと扱う
      try {
        final profileName = FirebaseAuth.instance.currentUser?.displayName;
        if (profileName != null && profileName.trim().isNotEmpty) {
          developer.log('フォールバック: Authに表示名ありのため初回ログインではないと扱う', name: _logName);
          return false;
        }
      } catch (_) {}

      // それ以外は初回ログインとして扱う
      return true;
    }
  }

  /// 初回ログイン時の同意取得と表示名設定
  static Future<bool> handleFirstLoginWithConsent(
    String displayName,
    BuildContext context,
  ) async {
    try {
      // 1. 表示名を設定
      final displayNameSet = await setDisplayName(displayName);
      if (!displayNameSet) {
        developer.log('表示名の設定に失敗', name: _logName);
        return false;
      }

      // 2. 同意取得フローを実行
      final consentGranted = await ConsentFlowService.handleFirstLoginConsent(
        context,
      );
      if (!consentGranted) {
        developer.log('初回ログイン時の同意取得に失敗', name: _logName);
        return false;
      }

      developer.log('初回ログイン処理が完了: 表示名設定と同意取得', name: _logName);
      return true;
    } catch (e, st) {
      developer.log(
        '初回ログイン処理でエラー: $e',
        name: _logName,
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// 表示名を設定
  static Future<bool> setDisplayName(String displayName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        developer.log('ユーザーが未ログインのため表示名設定をスキップ', name: _logName);
        return false;
      }

      if (displayName.trim().isEmpty) {
        developer.log('表示名が空のため設定をスキップ', name: _logName);
        return false;
      }

      developer.log('表示名を設定中: $displayName', name: _logName);

      // Web版ではFirestoreの初期化を待つ（ネットワーク有効化はスキップ）
      if (!kIsWeb) {
        await _firestore.enableNetwork();
      } else {
        // Web版ではFirestoreの接続状態を確認（より安全な方法）
        developer.log('Web版: Firestore接続状態を確認中', name: _logName);
        try {
          // Web版では接続確認をスキップして直接処理を実行
          // リトライ機能で接続問題に対応
          developer.log('Web版: 接続確認をスキップして直接処理を実行', name: _logName);
        } catch (e) {
          developer.log('Web版: Firestore接続確認でエラー: $e', name: _logName);
          // 接続確認に失敗しても処理を続行（リトライ機能で対応）
        }
      }

      // Web版ではより長いタイムアウトを設定し、リトライ機能を追加
      final timeoutDuration = kIsWeb
          ? Duration(seconds: 30)
          : Duration(seconds: 15);
      int retryCount = 0;
      const maxRetries = kIsWeb ? 3 : 1;

      // Web版ではFirestoreの初期化を待つ
      if (kIsWeb) {
        developer.log('Web版: Firestore初期化待機中', name: _logName);
        await Future.delayed(Duration(milliseconds: 1000));
        developer.log('Web版: Firestore初期化待機完了', name: _logName);
      }

      while (retryCount < maxRetries) {
        try {
          developer.log(
            '表示名設定試行 ${retryCount + 1}/$maxRetries',
            name: _logName,
          );

          // Firestoreにユーザー情報を保存（タイムアウト付き）
          await _firestore
              .collection('users')
              .doc(user.uid)
              .set({
                'displayName': displayName.trim(),
                'email': user.email,
                'photoUrl': user.photoURL,
                'lastLogin': FieldValue.serverTimestamp(),
                'loginProvider': 'Google',
                'displayNameSetAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true))
              .timeout(timeoutDuration);

          developer.log('表示名の設定が完了しました', name: _logName);

          // Web版では追加の待機時間を設けてFirestoreの同期を確実にする
          if (kIsWeb) {
            developer.log('Web版: Firestore同期のため待機中', name: _logName);
            await Future.delayed(Duration(milliseconds: 500));
            developer.log('Web版: 待機完了', name: _logName);
          }

          return true;
        } catch (e) {
          retryCount++;
          developer.log('表示名設定試行 $retryCountでエラー: $e', name: _logName);

          // Web版でのFirestore内部エラーの場合は特別な処理
          if (kIsWeb && e.toString().contains('INTERNAL ASSERTION FAILED')) {
            developer.log('Web版: Firestore内部アサーションエラーを検出', name: _logName);
            // 内部エラーの場合はFirestoreの再初期化を試行
            try {
              developer.log('Web版: Firestore再初期化を試行', name: _logName);
              await Future.delayed(Duration(milliseconds: 2000));
              developer.log('Web版: Firestore再初期化完了', name: _logName);
            } catch (reinitError) {
              developer.log(
                'Web版: Firestore再初期化エラー: $reinitError',
                name: _logName,
              );
            }
          }

          if (retryCount >= maxRetries) {
            rethrow; // 最後の試行でも失敗した場合はエラーを再スロー
          }

          // Web版ではリトライ前に待機時間を設ける
          if (kIsWeb) {
            final waitTime = e.toString().contains('INTERNAL ASSERTION FAILED')
                ? retryCount *
                      2000 // 内部エラーの場合はより長く待機
                : retryCount * 1000;
            developer.log('Web版: リトライ前に待機中 (${waitTime}ms)', name: _logName);
            await Future.delayed(Duration(milliseconds: waitTime));
          }
        }
      }

      return false;
    } catch (e) {
      developer.log('表示名設定でエラーが発生: $e', name: _logName);

      // Web版でのFirestore接続エラーの場合は、より詳細なログを出力
      if (e.toString().contains('network') ||
          e.toString().contains('timeout') ||
          e.toString().contains('TimeoutException')) {
        developer.log('Web版: Firestore接続エラーのため表示名設定に失敗', name: _logName);
      }

      // フォールバック: 認証プロファイルに表示名を設定して先に進める
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.updateDisplayName(displayName.trim());
          await user.reload();
          developer.log('フォールバック: Authプロフィールの表示名を更新', name: _logName);

          // バックグラウンドでFirestore書き込みを再試行
          Future(() async {
            try {
              await _firestore
                  .collection('users')
                  .doc(user.uid)
                  .set({
                    'displayName': displayName.trim(),
                    'email': user.email,
                    'photoUrl': user.photoURL,
                    'lastLogin': FieldValue.serverTimestamp(),
                    'loginProvider': 'Google',
                    'displayNameSetAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true))
                  .timeout(Duration(seconds: 60));
              developer.log('バックグラウンド: Firestore書き込みに成功', name: _logName);
            } catch (bgError) {
              developer.log(
                'バックグラウンド: Firestore書き込みに失敗: $bgError',
                name: _logName,
              );
            }
          });

          return true;
        }
      } catch (fallbackError) {
        developer.log('フォールバック処理でエラー: $fallbackError', name: _logName);
      }

      return false;
    }
  }

  /// 現在のユーザーの表示名を取得
  static Future<String?> getCurrentDisplayName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(Duration(seconds: 10));

      if (!userDoc.exists) return null;

      final userData = userDoc.data();
      if (userData == null) return null;

      return userData['displayName'] as String?;
    } catch (e) {
      developer.log('表示名取得でエラーが発生: $e', name: _logName);

      // Web版でのFirestore接続エラーの場合は、より詳細なログを出力
      if (e.toString().contains('network') ||
          e.toString().contains('timeout')) {
        developer.log('Web版: Firestore接続エラーのため表示名取得に失敗', name: _logName);
      }

      return null;
    }
  }

  /// 表示名が設定されているかチェック
  static Future<bool> hasDisplayNameSet() async {
    try {
      final displayName = await getCurrentDisplayName();
      return displayName != null && displayName.trim().isNotEmpty;
    } catch (e) {
      developer.log('表示名設定チェックでエラーが発生: $e', name: _logName);

      // Web版でのFirestore接続エラーの場合は、より詳細なログを出力
      if (e.toString().contains('network') ||
          e.toString().contains('timeout')) {
        developer.log('Web版: Firestore接続エラーのため表示名設定チェックに失敗', name: _logName);
      }

      return false;
    }
  }
}
