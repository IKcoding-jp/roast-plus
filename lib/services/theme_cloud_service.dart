import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ThemeCloudService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ユーザーがログインしているかチェック
  static bool get isLoggedIn => _auth.currentUser != null;

  // 現在のユーザーIDを取得
  static String? get currentUserId => _auth.currentUser?.uid;

  // テーマ設定をクラウドに保存
  static Future<void> saveThemeToCloud(Map<String, Color> themeData) async {
    if (!isLoggedIn) {
      throw Exception('ユーザーがログインしていません');
    }

    final userId = currentUserId!;

    // Colorオブジェクトをint値に変換（toARGB32 を使用）
    final themeDataMap = themeData.map(
      (key, color) => MapEntry(key, color.toARGB32()),
    );

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('theme')
          .set({
            'themeData': themeDataMap,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw Exception('テーマ設定の保存に失敗しました: $e');
    }
  }

  // クラウドからテーマ設定を取得
  static Future<Map<String, Color>?> getThemeFromCloud() async {
    if (!isLoggedIn) {
      return null;
    }

    final userId = currentUserId!;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('theme')
          .get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      final themeDataMap = data['themeData'] as Map<String, dynamic>;

      // int値をColorオブジェクトに変換
      return themeDataMap.map(
        (key, value) => MapEntry(key, Color(value as int)),
      );
    } catch (e) {
      throw Exception('テーマ設定の取得に失敗しました: $e');
    }
  }

  // クラウドのテーマ設定を削除
  static Future<void> deleteThemeFromCloud() async {
    if (!isLoggedIn) {
      throw Exception('ユーザーがログインしていません');
    }

    final userId = currentUserId!;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('theme')
          .delete();
    } catch (e) {
      throw Exception('テーマ設定の削除に失敗しました: $e');
    }
  }

  // クラウドのテーマ設定が存在するかチェック
  static Future<bool> hasCloudTheme() async {
    if (!isLoggedIn) {
      return false;
    }

    final userId = currentUserId!;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('theme')
          .get();

      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // カスタムテーマをクラウドに保存
  static Future<void> saveCustomThemesToCloud(
    Map<String, Map<String, Color>> customThemes,
  ) async {
    if (!isLoggedIn) {
      throw Exception('ユーザーがログインしていません');
    }

    final userId = currentUserId!;

    // Colorオブジェクトをint値に変換（toARGB32 を使用）
    final customThemesMap = customThemes.map(
      (themeName, themeData) => MapEntry(
        themeName,
        themeData.map((key, color) => MapEntry(key, color.toARGB32())),
      ),
    );

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('custom_themes')
          .set({
            'customThemes': customThemesMap,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw Exception('カスタムテーマの保存に失敗しました: $e');
    }
  }

  // クラウドからカスタムテーマを取得
  static Future<Map<String, Map<String, Color>>>
  getCustomThemesFromCloud() async {
    if (!isLoggedIn) {
      return {};
    }

    final userId = currentUserId!;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('custom_themes')
          .get();

      if (!doc.exists) {
        return {};
      }

      final data = doc.data() as Map<String, dynamic>;
      final customThemesMap = data['customThemes'] as Map<String, dynamic>;

      // int値をColorオブジェクトに変換
      return customThemesMap.map(
        (themeName, themeData) => MapEntry(
          themeName,
          (themeData as Map<String, dynamic>).map(
            (key, value) => MapEntry(key, Color(value as int)),
          ),
        ),
      );
    } catch (e) {
      throw Exception('カスタムテーマの取得に失敗しました: $e');
    }
  }

  // クラウドのカスタムテーマを削除
  static Future<void> deleteCustomThemesFromCloud() async {
    if (!isLoggedIn) {
      throw Exception('ユーザーがログインしていません');
    }

    final userId = currentUserId!;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('custom_themes')
          .delete();
    } catch (e) {
      throw Exception('カスタムテーマの削除に失敗しました: $e');
    }
  }

  // クラウドのカスタムテーマが存在するかチェック
  static Future<bool> hasCloudCustomThemes() async {
    if (!isLoggedIn) {
      return false;
    }

    final userId = currentUserId!;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('custom_themes')
          .get();

      return doc.exists;
    } catch (e) {
      return false;
    }
  }
}
