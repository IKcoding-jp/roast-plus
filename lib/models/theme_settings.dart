import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/theme_cloud_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class ThemeSettings extends ChangeNotifier {
  Color appBarColor;
  Color backgroundColor;
  Color buttonColor;
  Color backgroundColor2;
  Color fontColor1; // 通常の文章の色
  Color fontColor2; // ボタンのフォントの色
  Color iconColor; // アイコンの色
  Color timerCircleColor; // 焙煎タイマーのサークルの色
  Color bottomNavigationColor; // ボトムナビゲーションバーの色
  Color inputBackgroundColor; // 入力欄の背景色
  Color memberBackgroundColor; // メンバーの背景色
  Color appBarTextColor; // 画面上部の文字色
  Color bottomNavigationTextColor; // 画面下部の文字色
  Color dialogBackgroundColor; // ダイアログの背景色
  Color dialogTextColor; // ダイアログの文字色
  Color inputTextColor; // 入力欄の文字色
  double fontSizeScale; // フォントサイズのスケール（1.0が標準）
  String fontFamily; // フォントファミリー
  Color? customBottomNavigationSelectedColor;

  // Firestoreリスナー用
  Stream<DocumentSnapshot>? _fontSettingsStream;
  StreamSubscription? _fontSettingsSubscription;
  StreamSubscription? _themeSettingsSubscription;

  // Firestoreからテーマ設定を一度だけ取得して反映
  Future<void> loadThemeFromFirestore() async {
    final themeData = await ThemeCloudService.getThemeFromCloud();
    if (themeData != null) {
      appBarColor = themeData['appBarColor'] ?? appBarColor;
      backgroundColor = themeData['backgroundColor'] ?? backgroundColor;
      buttonColor = themeData['buttonColor'] ?? buttonColor;
      backgroundColor2 = themeData['backgroundColor2'] ?? backgroundColor2;
      fontColor1 = themeData['fontColor1'] ?? fontColor1;
      fontColor2 = themeData['fontColor2'] ?? fontColor2;
      iconColor = themeData['iconColor'] ?? iconColor;
      timerCircleColor = themeData['timerCircleColor'] ?? timerCircleColor;
      bottomNavigationColor =
          themeData['bottomNavigationColor'] ?? bottomNavigationColor;
      inputBackgroundColor =
          themeData['inputBackgroundColor'] ?? inputBackgroundColor;
      memberBackgroundColor =
          themeData['memberBackgroundColor'] ?? memberBackgroundColor;
      appBarTextColor = themeData['appBarTextColor'] ?? appBarTextColor;
      bottomNavigationTextColor =
          themeData['bottomNavigationTextColor'] ?? bottomNavigationTextColor;
      dialogBackgroundColor =
          themeData['dialogBackgroundColor'] ?? dialogBackgroundColor;
      dialogTextColor = themeData['dialogTextColor'] ?? dialogTextColor;
      inputTextColor = themeData['inputTextColor'] ?? inputTextColor;
      notifyListeners();
    }
  }

  // Firestoreのテーマ設定をリアルタイム同期
  void startThemeSettingsListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _themeSettingsSubscription?.cancel();
    _themeSettingsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('theme')
        .snapshots()
        .listen((doc) {
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            if (data['themeData'] != null) {
              final themeData = Map<String, Color>.from(
                (data['themeData'] as Map<String, dynamic>).map(
                  (k, v) => MapEntry(k, Color(v as int)),
                ),
              );
              appBarColor = themeData['appBarColor'] ?? appBarColor;
              backgroundColor = themeData['backgroundColor'] ?? backgroundColor;
              buttonColor = themeData['buttonColor'] ?? buttonColor;
              backgroundColor2 =
                  themeData['backgroundColor2'] ?? backgroundColor2;
              fontColor1 = themeData['fontColor1'] ?? fontColor1;
              fontColor2 = themeData['fontColor2'] ?? fontColor2;
              iconColor = themeData['iconColor'] ?? iconColor;
              timerCircleColor =
                  themeData['timerCircleColor'] ?? timerCircleColor;
              bottomNavigationColor =
                  themeData['bottomNavigationColor'] ?? bottomNavigationColor;
              inputBackgroundColor =
                  themeData['inputBackgroundColor'] ?? inputBackgroundColor;
              memberBackgroundColor =
                  themeData['memberBackgroundColor'] ?? memberBackgroundColor;
              appBarTextColor = themeData['appBarTextColor'] ?? appBarTextColor;
              bottomNavigationTextColor =
                  themeData['bottomNavigationTextColor'] ??
                  bottomNavigationTextColor;
              dialogBackgroundColor =
                  themeData['dialogBackgroundColor'] ?? dialogBackgroundColor;
              dialogTextColor = themeData['dialogTextColor'] ?? dialogTextColor;
              inputTextColor = themeData['inputTextColor'] ?? inputTextColor;
              notifyListeners();
            }
          }
        });
  }

  void disposeThemeSettingsListener() {
    _themeSettingsSubscription?.cancel();
    _themeSettingsSubscription = null;
  }

  Color get bottomNavigationSelectedColor {
    if (customBottomNavigationSelectedColor != null) {
      return customBottomNavigationSelectedColor!;
    }
    return _bottomNavigationSelectedColor ?? Color(0xFFFF9800);
  }

  Color? _bottomNavigationSelectedColor;

  ThemeSettings({
    required this.appBarColor,
    required this.backgroundColor,
    required this.buttonColor,
    required this.backgroundColor2,
    required this.fontColor1,
    required this.fontColor2,
    required this.iconColor,
    required this.timerCircleColor,
    required this.bottomNavigationColor,
    required this.inputBackgroundColor,
    required this.memberBackgroundColor,
    required this.appBarTextColor,
    required this.bottomNavigationTextColor,
    required this.dialogBackgroundColor,
    required this.dialogTextColor,
    Color? inputTextColor,
    required this.fontSizeScale,
    required this.fontFamily,
    Color? bottomNavigationSelectedColor,
    this.customBottomNavigationSelectedColor,
  }) : inputTextColor = inputTextColor ?? fontColor1,
       _bottomNavigationSelectedColor = bottomNavigationSelectedColor;

  // プリセットテーマの定義（アイコン色は薄い色で設定）
  static const Map<String, Map<String, Color>> presets = {
    // 基本
    'デフォルト': {
      'appBarColor': Color(0xFF2C1D17),
      'backgroundColor': Color(0xFFFFF8E1),
      'buttonColor': Color(0xFF795548),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000),
      'fontColor2': Color(0xFFFFFFFF),
      'timerCircleColor': Color(0xFF795548),
      'bottomNavigationColor': Color(0xFF2C1D17),
      'inputBackgroundColor': Color(0xFFF5F5F5),
      'iconColor': Color(0xFFFF9800), // オレンジ
      'memberBackgroundColor': Color(0xFFC8E6C9),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // ダーク背景なので白
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000),
      'inputTextColor': Color(0xFF000000),
      'bottomNavigationSelectedColor': Color(0xFFFF9800), // オレンジ（アクセント）
    },
    'ダーク': {
      'appBarColor': Color(0xFF1A1A1A),
      'backgroundColor': Color(0xFF121212),
      'buttonColor': Color(0xFF000000),
      'backgroundColor2': Color(0xFF3A3A3A),
      'fontColor1': Color(0xFFFFFFFF),
      'fontColor2': Color(0xFFFFFFFF),
      'timerCircleColor': Color(0xFFFFFFFF),
      'bottomNavigationColor': Color(0xFF1A1A1A),
      'inputBackgroundColor': Color(0xFF2A2A2A),
      'iconColor': Color(0xFFFF9800), // アクセントのオレンジ
      'memberBackgroundColor': Color(0xFFFFFFFF),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // ダーク背景なので白
      'dialogBackgroundColor': Color(0xFF2D2D2D),
      'dialogTextColor': Color(0xFFFFFFFF),
      'inputTextColor': Color(0xFFFFFFFF),
      'bottomNavigationSelectedColor': Color(0xFFFF9800), // オレンジ（アクセント）
    },
    'ライト': {
      'appBarColor': Color(0xFFF5F5F5),
      'backgroundColor': Color(0xFFFFFFFF),
      'buttonColor': Color(0xFFFFFFFF),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000),
      'fontColor2': Color(0xFF000000), // ボタン等の文字色を黒に修正
      'timerCircleColor': Color(0xFF000000),
      'bottomNavigationColor': Color(0xFFF5F5F5),
      'inputBackgroundColor': Color(0xFFF5F5F5),
      'iconColor': Color(0xFF1976D2), // 濃いブルー
      'memberBackgroundColor': Color(0xFFF0F0F0),
      'appBarTextColor': Color(0xFF000000),
      'bottomNavigationTextColor': Color(0xFF000000), // 明るい背景なので黒
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000),
      'inputTextColor': Color(0xFF000000),
      'bottomNavigationSelectedColor': Color(0xFF1976D2), // 濃いブルー
    },
    'ライトグレー': {
      'appBarColor': Color(0xFF424242),
      'backgroundColor': Color(0xFFF5F5F5),
      'buttonColor': Color(0xFF757575),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000),
      'fontColor2': Color(0xFFFFFFFF),
      'timerCircleColor': Color(0xFF757575),
      'bottomNavigationColor': Color(0xFF424242),
      'inputBackgroundColor': Color(0xFFFAFAFA),
      'iconColor': Color(0xFF757575), // グレー
      'memberBackgroundColor': Color(0xFFE0E0E0),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // ダーク背景なので白
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000),
      'inputTextColor': Color(0xFF000000),
      'bottomNavigationSelectedColor': Color(0xFFFF9800), // オレンジ
    },
    // ブラウン系
    'ブラウン': {
      'appBarColor': Color(0xFF3E2723),
      'backgroundColor': Color(0xFFEFEBE9),
      'buttonColor': Color(0xFF795548),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000),
      'fontColor2': Color(0xFFFFFFFF),
      'timerCircleColor': Color(0xFF795548),
      'bottomNavigationColor': Color(0xFF3E2723),
      'inputBackgroundColor': Color(0xFFF8F5F0),
      'iconColor': Color(0xFF795548), // ブラウン
      'memberBackgroundColor': Color(0xFFD7CCC8),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // ダーク背景なので白
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000),
      'inputTextColor': Color(0xFF000000),
      'bottomNavigationSelectedColor': Color(0xFFFF9800), // オレンジ
    },
    'ベージュ': {
      'appBarColor': Color(0xFFD7B899),
      'backgroundColor': Color(0xFFFFF8E1),
      'buttonColor': Color(0xFFEED9C4),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF6D4C00),
      'fontColor2': Color(0xFF6D4C00), // 濃い茶色
      'timerCircleColor': Color(0xFFEED9C4),
      'bottomNavigationColor': Color(0xFFD7B899),
      'inputBackgroundColor': Color(0xFFFFF9E3),
      'iconColor': Color(0xFFEED9C4), // ベージュ
      'memberBackgroundColor': Color(0xFFFFE0B2),
      'appBarTextColor': Color(0xFF6D4C00),
      'bottomNavigationTextColor': Color(0xFF6D4C00), // 明るい背景なので濃い茶色
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF6D4C00),
      'inputTextColor': Color(0xFF6D4C00),
      'bottomNavigationSelectedColor': Color(0xFFB8860B), // ゴールデンブラウン
    },
    'サンド': {
      'appBarColor': Color(0xFFEED9B6),
      'backgroundColor': Color(0xFFFFF8E1),
      'buttonColor': Color(0xFFD7B899),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF6D4C00),
      'fontColor2': Color(0xFF6D4C00), // 濃い茶色
      'timerCircleColor': Color(0xFFD7B899),
      'bottomNavigationColor': Color(0xFFEED9B6),
      'inputBackgroundColor': Color(0xFFFFF9E3),
      'iconColor': Color(0xFFD7B899), // サンド
      'memberBackgroundColor': Color(0xFFFFE0B2),
      'appBarTextColor': Color(0xFF6D4C00),
      'bottomNavigationTextColor': Color(0xFF6D4C00), // 明るい背景なので濃い茶色
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF6D4C00),
      'inputTextColor': Color(0xFF6D4C00),
      'bottomNavigationSelectedColor': Color(0xFFB8860B), // ゴールデンブラウン
    },
    'ゴールド': {
      'appBarColor': Color(0xFFFFD700),
      'backgroundColor': Color(0xFFFFF8E1),
      'buttonColor': Color(0xFFFFC107),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF6D4C00),
      'fontColor2': Color(0xFF6D4C00), // 濃い茶色
      'timerCircleColor': Color(0xFFFFC107),
      'bottomNavigationColor': Color(0xFFFFD700),
      'inputBackgroundColor': Color(0xFFFFF9E3),
      'iconColor': Color(0xFFFFC107), // ゴールド
      'memberBackgroundColor': Color(0xFFFFECB3),
      'appBarTextColor': Color(0xFF6D4C00),
      'bottomNavigationTextColor': Color(0xFF6D4C00), // 明るい背景なので濃い茶色
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF6D4C00),
      'inputTextColor': Color(0xFF6D4C00),
      'bottomNavigationSelectedColor': Color(0xFFB8860B), // ゴールデンブラウン
    },
    // 赤・ピンク系
    'レッド': {
      'appBarColor': Color(0xFFB71C1C),
      'backgroundColor': Color(0xFFFFEBEE),
      'buttonColor': Color(0xFFF44336),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000),
      'fontColor2': Color(0xFFFFFFFF),
      'timerCircleColor': Color(0xFFF44336),
      'bottomNavigationColor': Color(0xFFB71C1C),
      'inputBackgroundColor': Color(0xFFFFF0F0),
      'iconColor': Color(0xFFF44336), // レッド
      'memberBackgroundColor': Color(0xFFFFCDD2),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // ダーク背景なので白
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000),
      'inputTextColor': Color(0xFF000000),
      'bottomNavigationSelectedColor': Color(0xFFFF9800), // オレンジ
    },
    'ワインレッド': {
      'appBarColor': Color(0xFF800000),
      'backgroundColor': Color(0xFFFDEAEA),
      'buttonColor': Color(0xFFB71C1C),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF800000),
      'fontColor2': Color(0xFFFFFFFF),
      'timerCircleColor': Color(0xFFB71C1C),
      'bottomNavigationColor': Color(0xFF800000),
      'inputBackgroundColor': Color(0xFFFDEAEA),
      'iconColor': Color(0xFFB71C1C), // ワインレッド
      'memberBackgroundColor': Color(0xFFFFCDD2),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // ダーク背景なので白
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF800000),
      'inputTextColor': Color(0xFF800000),
      'bottomNavigationSelectedColor': Color(0xFFFF9800), // オレンジ
    },
    'ピンク': {
      'appBarColor': Color(0xFFC2185B),
      'backgroundColor': Color(0xFFFCE4EC),
      'buttonColor': Color(0xFFE91E63),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000),
      'fontColor2': Color(0xFFFFFFFF),
      'timerCircleColor': Color(0xFFE91E63),
      'bottomNavigationColor': Color(0xFFC2185B),
      'inputBackgroundColor': Color(0xFFFEF0F5),
      'iconColor': Color(0xFFE91E63), // ピンク
      'memberBackgroundColor': Color(0xFFF8BBD9),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // ダーク背景なので白
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000),
      'inputTextColor': Color(0xFF000000),
      'bottomNavigationSelectedColor': Color(0xFFFF9800), // オレンジ
    },
    'サーモンピンク': {
      'appBarColor': Color(0xFFFF8C69),
      'backgroundColor': Color(0xFFFFF0F0),
      'buttonColor': Color(0xFFFFB6A5),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFFB71C1C),
      'fontColor2': Color(0xFFB71C1C), // 濃い赤
      'timerCircleColor': Color(0xFFFFB6A5),
      'bottomNavigationColor': Color(0xFFFF8C69),
      'inputBackgroundColor': Color(0xFFFFF0F0),
      'iconColor': Color(0xFFFFB6A5), // サーモンピンク
      'memberBackgroundColor': Color(0xFFFFCDD2),
      'appBarTextColor': Color(0xFFB71C1C),
      'bottomNavigationTextColor': Color(0xFFB71C1C), // 明るい背景なので濃い赤
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFFB71C1C),
      'inputTextColor': Color(0xFFB71C1C),
      'bottomNavigationSelectedColor': Color(0xFFD2691E), // チョコレート色
    },
    // オレンジ・イエロー系
    'オレンジ': {
      'appBarColor': Color(0xFFE65100),
      'backgroundColor': Color(0xFFFFF3E0),
      'buttonColor': Color(0xFFFF9800),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000),
      'fontColor2': Color(0xFFFFFFFF),
      'timerCircleColor': Color(0xFFFF9800),
      'bottomNavigationColor': Color(0xFFE65100),
      'inputBackgroundColor': Color(0xFFFFF8F0),
      'iconColor': Color(0xFFFF9800), // オレンジ
      'memberBackgroundColor': Color(0xFFFFCC80),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // ダーク背景なので白
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000),
      'inputTextColor': Color(0xFF000000),
      'bottomNavigationSelectedColor': Color(0xFFFFD700), // ゴールド
    },
    'ライム': {
      'appBarColor': Color(0xFF827717),
      'backgroundColor': Color(0xFFF9FBE7),
      'buttonColor': Color(0xFFCDDC39),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000),
      'fontColor2': Color(0xFF333300), // 濃いオリーブ
      'timerCircleColor': Color(0xFFCDDC39),
      'bottomNavigationColor': Color(0xFF827717),
      'inputBackgroundColor': Color(0xFFFDFFF0),
      'iconColor': Color(0xFFCDDC39), // ライム
      'memberBackgroundColor': Color(0xFFDCE775),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // ダーク背景なので白
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000),
      'inputTextColor': Color(0xFF000000),
      'bottomNavigationSelectedColor': Color(0xFFCDDC39), // ライム
    },
    // グリーン系
    'グリーン': {
      'appBarColor': Color(0xFF2E7D32),
      'backgroundColor': Color(0xFFE8F5E8),
      'buttonColor': Color(0xFF4CAF50),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000),
      'fontColor2': Color(0xFFFFFFFF),
      'timerCircleColor': Color(0xFF4CAF50),
      'bottomNavigationColor': Color(0xFF2E7D32),
      'inputBackgroundColor': Color(0xFFF0FFF0),
      'iconColor': Color(0xFF4CAF50), // グリーン
      'memberBackgroundColor': Color(0xFFC8E6C9),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // ダーク背景なので白
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000),
      'inputTextColor': Color(0xFF000000),
      'bottomNavigationSelectedColor': Color(0xFF81C784), // 明るいグリーン
    },
    'ミントグリーン': {
      'appBarColor': Color(0xFF98FF98),
      'backgroundColor': Color(0xFFE0F8E0),
      'buttonColor': Color(0xFFB2FFB2),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF006400),
      'fontColor2': Color(0xFF006400), // 濃いグリーン
      'timerCircleColor': Color(0xFFB2FFB2),
      'bottomNavigationColor': Color(0xFF98FF98),
      'inputBackgroundColor': Color(0xFFE0F8E0),
      'iconColor': Color(0xFFB2FFB2), // ミントグリーン
      'memberBackgroundColor': Color(0xFFC8E6C9),
      'appBarTextColor': Color(0xFF006400),
      'bottomNavigationTextColor': Color(0xFF006400), // 明るい背景なので濃いグリーン
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF006400),
      'inputTextColor': Color(0xFF006400),
      'bottomNavigationSelectedColor': Color(0xFF388E3C), // 濃いグリーン
    },
    'オリーブ': {
      'appBarColor': Color(0xFF808000),
      'backgroundColor': Color(0xFFF8FFF0),
      'buttonColor': Color(0xFFBDB76B),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF333300),
      'fontColor2': Color(0xFF333300), // 濃いオリーブ
      'timerCircleColor': Color(0xFFBDB76B),
      'bottomNavigationColor': Color(0xFF808000),
      'inputBackgroundColor': Color(0xFFF8FFF0),
      'iconColor': Color(0xFFBDB76B), // オリーブ
      'memberBackgroundColor': Color(0xFFDCE775),
      'appBarTextColor': Color(0xFF333300),
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // ダーク背景なので白
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF333300),
      'inputTextColor': Color(0xFF333300),
      'bottomNavigationSelectedColor': Color(0xFFBDB76B), // 明るいオリーブ
    },
    // ブルー系
    'ティール': {
      'appBarColor': Color(0xFF00695C),
      'backgroundColor': Color(0xFFE0F2F1),
      'buttonColor': Color(0xFF009688),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000),
      'fontColor2': Color(0xFFFFFFFF),
      'timerCircleColor': Color(0xFF009688),
      'bottomNavigationColor': Color(0xFF00695C),
      'inputBackgroundColor': Color(0xFFF0FFFF),
      'iconColor': Color(0xFF009688), // ティール
      'memberBackgroundColor': Color(0xFFB2DFDB),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // ダーク背景なので白
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000),
      'inputTextColor': Color(0xFF000000),
      'bottomNavigationSelectedColor': Color(0xFF1DE9B6), // ターコイズ
    },
    'ターコイズ': {
      'appBarColor': Color(0xFF1DE9B6),
      'backgroundColor': Color(0xFFE0F7FA),
      'buttonColor': Color(0xFF00BFAE),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF004D40),
      'fontColor2': Color(0xFF004D40), // 濃いターコイズ
      'timerCircleColor': Color(0xFF00BFAE),
      'bottomNavigationColor': Color(0xFF1DE9B6),
      'inputBackgroundColor': Color(0xFFE0F7FA),
      'iconColor': Color(0xFF00BFAE), // ターコイズ
      'memberBackgroundColor': Color(0xFFB2DFDB),
      'appBarTextColor': Color(0xFF004D40),
      'bottomNavigationTextColor': Color(0xFF004D40), // 明るい背景なので濃いターコイズ
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF004D40),
      'inputTextColor': Color(0xFF004D40),
      'bottomNavigationSelectedColor': Color(0xFF00BFAE), // ターコイズ
    },
    'ブルー': {
      'appBarColor': Color(0xFF1976D2),
      'backgroundColor': Color(0xFFE3F2FD),
      'buttonColor': Color(0xFF2196F3),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000),
      'fontColor2': Color(0xFFFFFFFF),
      'timerCircleColor': Color(0xFF2196F3),
      'bottomNavigationColor': Color(0xFF1976D2),
      'inputBackgroundColor': Color(0xFFF0F8FF),
      'iconColor': Color(0xFF2196F3), // ブルー
      'memberBackgroundColor': Color(0xFFBBDEFB),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // ダーク背景なので白
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000),
      'inputTextColor': Color(0xFF000000),
      'bottomNavigationSelectedColor': Color(0xFF1976D2), // 濃いブルー
    },
    'ネイビー': {
      'appBarColor': Color(0xFF001F54),
      'backgroundColor': Color(0xFFE3EAFD),
      'buttonColor': Color(0xFF003366),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF001F54),
      'fontColor2': Color(0xFFFFFFFF),
      'timerCircleColor': Color(0xFF003366),
      'bottomNavigationColor': Color(0xFF001F54),
      'inputBackgroundColor': Color(0xFFE3EAFD),
      'iconColor': Color(0xFF003366), // ネイビー
      'memberBackgroundColor': Color(0xFF90CAF9),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // ダーク背景なので白
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF001F54),
      'inputTextColor': Color(0xFF001F54),
      'bottomNavigationSelectedColor': Color(0xFF1976D2), // 濃いブルー
    },
    'ミッドナイトブルー': {
      'appBarColor': Color(0xFF191970),
      'backgroundColor': Color(0xFFE8EAF6),
      'buttonColor': Color(0xFF283593),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF191970),
      'fontColor2': Color(0xFFFFFFFF),
      'timerCircleColor': Color(0xFF283593),
      'bottomNavigationColor': Color(0xFF191970),
      'inputBackgroundColor': Color(0xFFE8EAF6),
      'iconColor': Color(0xFF283593), // ミッドナイトブルー
      'memberBackgroundColor': Color(0xFFC5CAE9),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // ダーク背景なので白
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF191970),
      'inputTextColor': Color(0xFF191970),
      'bottomNavigationSelectedColor': Color(0xFF1976D2), // 濃いブルー
    },
    // パープル系
    'パープル': {
      'appBarColor': Color(0xFF512DA8),
      'backgroundColor': Color(0xFFF3E5F5),
      'buttonColor': Color(0xFF9C27B0),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000),
      'fontColor2': Color(0xFFFFFFFF),
      'timerCircleColor': Color(0xFF9C27B0),
      'bottomNavigationColor': Color(0xFF512DA8),
      'inputBackgroundColor': Color(0xFFF8F0FF),
      'iconColor': Color(0xFF9C27B0), // パープル
      'memberBackgroundColor': Color(0xFFE1BEE7),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // ダーク背景なので白
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000),
      'inputTextColor': Color(0xFF000000),
      'bottomNavigationSelectedColor': Color(0xFF9C27B0), // パープル
    },
    // 個性派
    // ... ここに今後追加する場合は記載 ...
  };

  // 利用可能なフォントのリスト
  static const List<String> availableFonts = [
    'Noto Sans JP',
    'ZenMaruGothic',
    'ShipporiAntiqueB1',
    'KiwiMaru',
    'HannariMincho',
  ];

  static const _appBarKey = 'theme_appBarColor';
  static const _backgroundKey = 'theme_backgroundColor';
  static const _buttonKey = 'theme_buttonColor';
  static const _background2Key = 'theme_backgroundColor2';
  static const _font1Key = 'theme_fontColor1';
  static const _font2Key = 'theme_fontColor2';
  static const _iconKey = 'theme_iconColor';
  static const _timerCircleKey = 'theme_timerCircleColor';
  static const _bottomNavigationKey = 'theme_bottomNavigationColor';
  static const _inputBackgroundKey = 'theme_inputBackgroundColor';
  static const _fontSizeScaleKey = 'theme_fontSizeScale';
  static const _fontFamilyKey = 'theme_fontFamily';

  static Future<ThemeSettings> load() async {
    final prefs = await SharedPreferences.getInstance();

    // 主要なテーマキーが未保存ならデフォルトテーマを保存
    if (!prefs.containsKey(_appBarKey)) {
      final defaultTheme = presets['デフォルト']!;
      await prefs.setInt(_appBarKey, defaultTheme['appBarColor']!.value);
      await prefs.setInt(
        _backgroundKey,
        defaultTheme['backgroundColor']!.value,
      );
      await prefs.setInt(_buttonKey, defaultTheme['buttonColor']!.value);
      await prefs.setInt(
        _background2Key,
        defaultTheme['backgroundColor2']!.value,
      );
      await prefs.setInt(_font1Key, defaultTheme['fontColor1']!.value);
      await prefs.setInt(_font2Key, defaultTheme['fontColor2']!.value);
      await prefs.setInt(_iconKey, defaultTheme['iconColor']!.value);
      await prefs.setInt(
        _timerCircleKey,
        defaultTheme['timerCircleColor']!.value,
      );
      await prefs.setInt(
        _bottomNavigationKey,
        defaultTheme['bottomNavigationColor']!.value,
      );
      await prefs.setInt(
        _inputBackgroundKey,
        defaultTheme['inputBackgroundColor']!.value,
      );
      await prefs.setInt(
        'theme_memberBackgroundColor',
        defaultTheme['memberBackgroundColor']!.value,
      );
      await prefs.setInt(
        'theme_appBarTextColor',
        defaultTheme['appBarTextColor']!.value,
      );
      await prefs.setInt(
        'theme_bottomNavigationTextColor',
        defaultTheme['bottomNavigationTextColor']!.value,
      );
      await prefs.setInt(
        'theme_dialogBackgroundColor',
        defaultTheme['dialogBackgroundColor']!.value,
      );
      await prefs.setInt(
        'theme_dialogTextColor',
        defaultTheme['dialogTextColor']!.value,
      );
      await prefs.setInt(
        'theme_inputTextColor',
        defaultTheme['inputTextColor']!.value,
      );
      await prefs.setDouble(_fontSizeScaleKey, 1.0);
      await prefs.setString(_fontFamilyKey, 'Noto Sans JP');
    }

    // クラウドからテーマ設定を取得を試行
    Map<String, Color>? cloudTheme;
    try {
      cloudTheme = await ThemeCloudService.getThemeFromCloud();
    } catch (e) {
      print('クラウドからのテーマ取得に失敗しました: $e');
    }

    // クラウドの設定があれば使用、なければローカルの設定を使用
    if (cloudTheme != null) {
      return ThemeSettings(
        appBarColor:
            cloudTheme['appBarColor'] ??
            Color(prefs.getInt(_appBarKey) ?? 0xFF2C1D17),
        backgroundColor:
            cloudTheme['backgroundColor'] ??
            Color(prefs.getInt(_backgroundKey) ?? 0xFFFFF8E1),
        buttonColor:
            cloudTheme['buttonColor'] ??
            Color(prefs.getInt(_buttonKey) ?? 0xFF795548),
        backgroundColor2:
            cloudTheme['backgroundColor2'] ??
            Color(prefs.getInt(_background2Key) ?? 0xFFFFFFFF),
        fontColor1:
            cloudTheme['fontColor1'] ??
            Color(prefs.getInt(_font1Key) ?? 0xFF000000),
        fontColor2:
            cloudTheme['fontColor2'] ??
            Color(prefs.getInt(_font2Key) ?? 0xFFFFFFFF),
        iconColor:
            cloudTheme['iconColor'] ??
            Color(prefs.getInt(_iconKey) ?? 0xFFBDBDBD),
        timerCircleColor:
            cloudTheme['timerCircleColor'] ??
            Color(prefs.getInt(_timerCircleKey) ?? 0xFF795548),
        bottomNavigationColor:
            cloudTheme['bottomNavigationColor'] ??
            Color(prefs.getInt(_bottomNavigationKey) ?? 0xFF2C1D17),
        inputBackgroundColor:
            cloudTheme['inputBackgroundColor'] ??
            Color(prefs.getInt(_inputBackgroundKey) ?? 0xFFF5F5F5),
        memberBackgroundColor:
            cloudTheme['memberBackgroundColor'] ??
            Color(prefs.getInt('theme_memberBackgroundColor') ?? 0xFFFFFFFF),
        appBarTextColor:
            cloudTheme['appBarTextColor'] ??
            Color(prefs.getInt('theme_appBarTextColor') ?? 0xFF000000),
        bottomNavigationTextColor:
            cloudTheme['bottomNavigationTextColor'] ??
            Color(
              prefs.getInt('theme_bottomNavigationTextColor') ?? 0xFF000000,
            ),
        dialogBackgroundColor:
            cloudTheme['dialogBackgroundColor'] ??
            Color(prefs.getInt('theme_dialogBackgroundColor') ?? 0xFFFFFFFF),
        dialogTextColor:
            cloudTheme['dialogTextColor'] ??
            Color(prefs.getInt('theme_dialogTextColor') ?? 0xFF000000),
        inputTextColor:
            cloudTheme['inputTextColor'] ??
            Color(prefs.getInt('theme_inputTextColor') ?? 0xFF000000),
        fontSizeScale: prefs.getDouble(_fontSizeScaleKey) ?? 1.0,
        fontFamily: prefs.getString(_fontFamilyKey) ?? 'Noto Sans JP',
        bottomNavigationSelectedColor:
            cloudTheme['bottomNavigationSelectedColor'] ?? null,
      );
    } else {
      // ローカル設定
      // プリセット名を推定（デフォルトで"デフォルト"）
      String presetName = 'デフォルト';
      // 主要な色からプリセット名を推定するロジックを追加してもよい
      final preset = presets[presetName];
      return ThemeSettings(
        appBarColor: Color(prefs.getInt(_appBarKey) ?? 0xFF2C1D17),
        backgroundColor: Color(prefs.getInt(_backgroundKey) ?? 0xFFFFF8E1),
        buttonColor: Color(prefs.getInt(_buttonKey) ?? 0xFF795548),
        backgroundColor2: Color(prefs.getInt(_background2Key) ?? 0xFFFFFFFF),
        fontColor1: Color(prefs.getInt(_font1Key) ?? 0xFF000000),
        fontColor2: Color(prefs.getInt(_font2Key) ?? 0xFFFFFFFF),
        iconColor: Color(prefs.getInt(_iconKey) ?? 0xFFBDBDBD),
        timerCircleColor: Color(prefs.getInt(_timerCircleKey) ?? 0xFF795548),
        bottomNavigationColor: Color(
          prefs.getInt(_bottomNavigationKey) ?? 0xFF2C1D17,
        ),
        inputBackgroundColor: Color(
          prefs.getInt(_inputBackgroundKey) ?? 0xFFF5F5F5,
        ),
        memberBackgroundColor: Color(
          prefs.getInt('theme_memberBackgroundColor') ?? 0xFFFFFFFF,
        ),
        appBarTextColor: Color(
          prefs.getInt('theme_appBarTextColor') ?? 0xFF000000,
        ),
        bottomNavigationTextColor: Color(
          prefs.getInt('theme_bottomNavigationTextColor') ?? 0xFF000000,
        ),
        dialogBackgroundColor: Color(
          prefs.getInt('theme_dialogBackgroundColor') ?? 0xFFFFFFFF,
        ),
        dialogTextColor: Color(
          prefs.getInt('theme_dialogTextColor') ?? 0xFF000000,
        ),
        inputTextColor: Color(
          prefs.getInt('theme_inputTextColor') ?? 0xFF000000,
        ),
        fontSizeScale: prefs.getDouble(_fontSizeScaleKey) ?? 1.0,
        fontFamily: prefs.getString(_fontFamilyKey) ?? 'Noto Sans JP',
        bottomNavigationSelectedColor:
            preset?['bottomNavigationSelectedColor'] ?? null,
      );
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_appBarKey, appBarColor.value);
    await prefs.setInt(_backgroundKey, backgroundColor.value);
    await prefs.setInt(_buttonKey, buttonColor.value);
    await prefs.setInt(_background2Key, backgroundColor2.value);
    await prefs.setInt(_font1Key, fontColor1.value);
    await prefs.setInt(_font2Key, fontColor2.value);
    await prefs.setInt(_iconKey, iconColor.value);
    await prefs.setInt(_timerCircleKey, timerCircleColor.value);
    await prefs.setInt(_bottomNavigationKey, bottomNavigationColor.value);
    await prefs.setInt(_inputBackgroundKey, inputBackgroundColor.value);
    await prefs.setInt(
      'theme_memberBackgroundColor',
      memberBackgroundColor.value,
    );
    await prefs.setInt('theme_appBarTextColor', appBarTextColor.value);
    await prefs.setInt(
      'theme_bottomNavigationTextColor',
      bottomNavigationTextColor.value,
    );
    await prefs.setInt(
      'theme_dialogBackgroundColor',
      dialogBackgroundColor.value,
    );
    await prefs.setInt('theme_dialogTextColor', dialogTextColor.value);
    await prefs.setInt('theme_inputTextColor', inputTextColor.value);
    await prefs.setDouble(_fontSizeScaleKey, fontSizeScale);
    await prefs.setString(_fontFamilyKey, fontFamily);

    // クラウドにも保存
    try {
      final themeData = {
        'appBarColor': appBarColor,
        'backgroundColor': backgroundColor,
        'buttonColor': buttonColor,
        'backgroundColor2': backgroundColor2,
        'fontColor1': fontColor1,
        'fontColor2': fontColor2,
        'iconColor': iconColor,
        'timerCircleColor': timerCircleColor,
        'bottomNavigationColor': bottomNavigationColor,
        'inputBackgroundColor': inputBackgroundColor,
        'memberBackgroundColor': memberBackgroundColor,
        'appBarTextColor': appBarTextColor,
        'bottomNavigationTextColor': bottomNavigationTextColor,
        'dialogBackgroundColor': dialogBackgroundColor,
        'dialogTextColor': dialogTextColor,
        'inputTextColor': inputTextColor,
      };
      await ThemeCloudService.saveThemeToCloud(themeData);
    } catch (e) {
      // クラウド保存に失敗してもローカル保存は成功しているので、エラーを無視
      print('クラウド保存に失敗しました: $e');
    }
  }

  void updateAppBarColor(Color color) {
    appBarColor = color;
    notifyListeners();
    save();
  }

  // 背景色が変更された時にアイコン色を自動調整
  void updateBackgroundColor(Color color) {
    backgroundColor = color;
    // アイコン色の自動調整を削除（プリセットで設定された色を維持）
    notifyListeners();
    save();
  }

  void updateButtonColor(Color color) {
    buttonColor = color;
    notifyListeners();
    save();
  }

  void updateBackgroundColor2(Color color) {
    backgroundColor2 = color;
    notifyListeners();
    save();
  }

  void updateFontColor1(Color color) {
    fontColor1 = color;
    notifyListeners();
    save();
  }

  void updateFontColor2(Color color) {
    fontColor2 = color;
    notifyListeners();
    save();
  }

  void updateIconColor(Color color) {
    iconColor = color;
    notifyListeners();
    save();
  }

  void updateTimerCircleColor(Color color) {
    timerCircleColor = color;
    notifyListeners();
    save();
  }

  void updateBottomNavigationColor(Color color) {
    bottomNavigationColor = color;
    notifyListeners();
    save();
  }

  void updateInputBackgroundColor(Color color) {
    inputBackgroundColor = color;
    notifyListeners();
    save();
  }

  void updateMemberBackgroundColor(Color color) {
    memberBackgroundColor = color;
    notifyListeners();
    save();
  }

  void updateAppBarTextColor(Color color) {
    appBarTextColor = color;
    notifyListeners();
    save();
  }

  void updateBottomNavigationTextColor(Color color) {
    bottomNavigationTextColor = color;
    notifyListeners();
    save();
  }

  void updateDialogBackgroundColor(Color color) {
    dialogBackgroundColor = color;
    notifyListeners();
    save();
  }

  void updateDialogTextColor(Color color) {
    dialogTextColor = color;
    notifyListeners();
    save();
  }

  void updateInputTextColor(Color color) {
    inputTextColor = color;
    notifyListeners();
    save();
  }

  void updateFontSizeScale(double scale) {
    fontSizeScale = scale;
    notifyListeners();
    save();
  }

  void updateFontFamily(String family) {
    fontFamily = family;
    notifyListeners();
    save();
  }

  void resetToDefault() {
    appBarColor = Color(0xFF2C1D17);
    backgroundColor = Color(0xFFFFF8E1);
    buttonColor = Color(0xFF000000);
    backgroundColor2 = Color(0xFFFFFFFF);
    fontColor1 = Color(0xFF000000);
    fontColor2 = Color(0xFFFFFFFF);
    iconColor = Color(0xFFBDBDBD);
    timerCircleColor = Color(0xFF795548);
    bottomNavigationColor = Color(0xFF2C1D17);
    inputBackgroundColor = Color(0xFFF5F5F5);
    memberBackgroundColor = Color(0xFFFFFFFF);
    appBarTextColor = Color(0xFF000000);
    bottomNavigationTextColor = Color(0xFF000000);
    dialogBackgroundColor = Color(0xFFFFFFFF);
    dialogTextColor = Color(0xFF000000);
    inputTextColor = Color(0xFF000000);
    fontSizeScale = 1.0;
    fontFamily = 'Noto Sans JP';
    notifyListeners();
    save();
  }

  // プリセットを適用するメソッド
  void applyPreset(String presetName) {
    final preset = presets[presetName];
    if (preset != null) {
      appBarColor = preset['appBarColor']!;
      backgroundColor = preset['backgroundColor']!;
      buttonColor = preset['buttonColor']!;
      backgroundColor2 = preset['backgroundColor2']!;
      fontColor1 = preset['fontColor1']!;
      fontColor2 = preset['fontColor2']!;
      timerCircleColor = preset['timerCircleColor']!;
      bottomNavigationColor = preset['bottomNavigationColor']!;
      inputBackgroundColor = preset['inputBackgroundColor']!;
      iconColor = preset['iconColor']!;
      memberBackgroundColor = preset['memberBackgroundColor']!;
      appBarTextColor = preset['appBarTextColor']!;
      bottomNavigationTextColor = preset['bottomNavigationTextColor']!;
      dialogBackgroundColor = preset['dialogBackgroundColor']!;
      dialogTextColor = preset['dialogTextColor']!;
      inputTextColor = preset['inputTextColor']!;
      _bottomNavigationSelectedColor =
          preset['bottomNavigationSelectedColor'] ?? preset['buttonColor'];
      // ここで一度だけ通知
      notifyListeners();
      save();
    }
  }

  // プリセット名のリストを取得
  static List<String> getPresetNames() {
    return presets.keys.toList();
  }

  // カスタムテーマを保存
  static Future<void> saveCustomTheme(
    String name,
    Map<String, Color> themeData,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final customThemes = await getCustomThemes();
    customThemes[name] = themeData;

    final themeDataMap = customThemes.map(
      (key, value) => MapEntry(key, value.map((k, v) => MapEntry(k, v.value))),
    );
    await prefs.setString('custom_themes', json.encode(themeDataMap));

    // クラウドにも保存
    try {
      await ThemeCloudService.saveCustomThemesToCloud(customThemes);
    } catch (e) {
      print('カスタムテーマのクラウド保存に失敗しました: $e');
    }
  }

  // カスタムテーマを取得
  static Future<Map<String, Map<String, Color>>> getCustomThemes() async {
    final prefs = await SharedPreferences.getInstance();

    // クラウドからカスタムテーマを取得を試行
    Map<String, Map<String, Color>> cloudCustomThemes = {};
    try {
      cloudCustomThemes = await ThemeCloudService.getCustomThemesFromCloud();
    } catch (e) {
      print('クラウドからのカスタムテーマ取得に失敗しました: $e');
    }

    // クラウドのカスタムテーマがあれば使用、なければローカルの設定を使用
    if (cloudCustomThemes.isNotEmpty) {
      return cloudCustomThemes;
    }

    final customThemesJson = prefs.getString('custom_themes');
    if (customThemesJson == null) return {};

    try {
      final Map<String, dynamic> decoded = json.decode(customThemesJson);
      return decoded.map(
        (key, value) => MapEntry(
          key,
          (value as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, Color(v as int)),
          ),
        ),
      );
    } catch (e) {
      return {};
    }
  }

  // カスタムテーマを削除
  static Future<void> deleteCustomTheme(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final customThemes = await getCustomThemes();
    customThemes.remove(name);

    final themeDataMap = customThemes.map(
      (key, value) => MapEntry(key, value.map((k, v) => MapEntry(k, v.value))),
    );
    await prefs.setString('custom_themes', json.encode(themeDataMap));

    // クラウドからも削除
    try {
      await ThemeCloudService.saveCustomThemesToCloud(customThemes);
    } catch (e) {
      print('カスタムテーマのクラウド削除に失敗しました: $e');
    }
  }

  // カスタムテーマ名を変更
  static Future<void> renameCustomTheme(String oldName, String newName) async {
    final customThemes = await getCustomThemes();
    if (customThemes.containsKey(oldName)) {
      final themeData = customThemes[oldName]!;
      await deleteCustomTheme(oldName);
      await saveCustomTheme(newName, themeData);
    }
  }

  // 次のカスタムテーマ名を生成
  static Future<String> getNextCustomThemeName() async {
    final customThemes = await getCustomThemes();
    int number = 1;
    while (customThemes.containsKey('カスタム$number')) {
      number++;
    }
    return 'カスタム$number';
  }

  // 現在の設定をカスタムテーマとして保存
  Future<void> saveCurrentAsCustom() async {
    final themeData = {
      'appBarColor': appBarColor,
      'backgroundColor': backgroundColor,
      'buttonColor': buttonColor,
      'backgroundColor2': backgroundColor2,
      'fontColor1': fontColor1,
      'fontColor2': fontColor2,
      'iconColor': iconColor,
      'timerCircleColor': timerCircleColor,
      'bottomNavigationColor': bottomNavigationColor,
      'inputBackgroundColor': inputBackgroundColor,
      'memberBackgroundColor': memberBackgroundColor,
      'appBarTextColor': appBarTextColor,
      'bottomNavigationTextColor': bottomNavigationTextColor,
      'dialogBackgroundColor': dialogBackgroundColor,
      'dialogTextColor': dialogTextColor,
      'inputTextColor': inputTextColor,
    };

    final name = await getNextCustomThemeName();
    await saveCustomTheme(name, themeData);
  }

  // カスタムテーマを適用
  Future<void> applyCustomTheme(String name) async {
    final customThemes = await getCustomThemes();
    final themeData = customThemes[name];
    if (themeData != null) {
      appBarColor = themeData['appBarColor']!;
      backgroundColor = themeData['backgroundColor']!;
      buttonColor = themeData['buttonColor']!;
      backgroundColor2 = themeData['backgroundColor2']!;
      fontColor1 = themeData['fontColor1']!;
      fontColor2 = themeData['fontColor2']!;
      iconColor = themeData['iconColor']!;
      timerCircleColor = themeData['timerCircleColor']!;
      bottomNavigationColor = themeData['bottomNavigationColor']!;
      inputBackgroundColor = themeData['inputBackgroundColor']!;
      memberBackgroundColor = themeData['memberBackgroundColor']!;
      appBarTextColor = themeData['appBarTextColor']!;
      bottomNavigationTextColor = themeData['bottomNavigationTextColor']!;
      dialogBackgroundColor =
          themeData['dialogBackgroundColor'] ?? Color(0xFFFFFFFF);
      dialogTextColor = themeData['dialogTextColor'] ?? Color(0xFF000000);
      inputTextColor = themeData['inputTextColor'] ?? Color(0xFF000000);
      // ここで一度だけ通知
      notifyListeners();
      save();
    }
  }

  void startFontSettingsListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _fontSettingsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('font_size')
        .snapshots();
    _fontSettingsSubscription?.cancel();
    _fontSettingsSubscription = _fontSettingsStream!.listen((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['fontSize'] != null && data['fontFamily'] != null) {
          fontSizeScale = (data['fontSize'] as num).toDouble();
          fontFamily = data['fontFamily'] as String;
          notifyListeners();
        }
      }
    });
  }

  void disposeFontSettingsListener() {
    _fontSettingsSubscription?.cancel();
    _fontSettingsSubscription = null;
  }

  Future<void> loadFontSettingsFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('font_size')
        .get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      if (data['fontSize'] != null && data['fontFamily'] != null) {
        fontSizeScale = (data['fontSize'] as num).toDouble();
        fontFamily = data['fontFamily'] as String;
        notifyListeners();
      }
    }
  }
}
