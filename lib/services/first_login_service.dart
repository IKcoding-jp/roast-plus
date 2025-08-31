import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

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

      // Firestoreからユーザー情報を取得
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        developer.log('ユーザードキュメントが存在しないため初回ログインと判定', name: _logName);
        return true;
      }

      final userData = userDoc.data();
      if (userData == null) {
        developer.log('ユーザーデータがnullのため初回ログインと判定', name: _logName);
        return true;
      }

      // カスタム表示名が設定されているかチェック
      final hasCustomDisplayName = userData['displayName'] != null && 
                                  userData['displayName'].toString().isNotEmpty &&
                                  userData['displayName'] != user.displayName;

      if (!hasCustomDisplayName) {
        developer.log('カスタム表示名が未設定のため初回ログインと判定', name: _logName);
        return true;
      }

      developer.log('初回ログインではないと判定', name: _logName);
      return false;
    } catch (e) {
      developer.log('初回ログイン判定でエラーが発生: $e', name: _logName);
      // エラーの場合は初回ログインとして扱う
      return true;
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

      // Firestoreにユーザー情報を保存
      await _firestore.collection('users').doc(user.uid).set({
        'displayName': displayName.trim(),
        'email': user.email,
        'photoUrl': user.photoURL,
        'lastLogin': FieldValue.serverTimestamp(),
        'loginProvider': 'Google',
        'displayNameSetAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      developer.log('表示名の設定が完了しました', name: _logName);
      return true;
    } catch (e) {
      developer.log('表示名設定でエラーが発生: $e', name: _logName);
      return false;
    }
  }

  /// 現在のユーザーの表示名を取得
  static Future<String?> getCurrentDisplayName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) return null;

      final userData = userDoc.data();
      if (userData == null) return null;

      return userData['displayName'] as String?;
    } catch (e) {
      developer.log('表示名取得でエラーが発生: $e', name: _logName);
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
      return false;
    }
  }
}
