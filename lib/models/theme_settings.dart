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
      'appBarColor': Color(0xFF2C1810), // より深いコーヒー色
      'backgroundColor': Color(0xFFFFFBF5), // よりクリーンな背景
      'buttonColor': Color(0xFF8D6E63), // 洗練されたブラウン
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000), // 明るい背景なので黒文字
      'fontColor2': Color(0xFFFFFFFF),
      'timerCircleColor': Color(0xFF8D6E63),
      'bottomNavigationColor': Color(0xFF2C1810),
      'inputBackgroundColor': Color(0xFFF7F3F0),
      'iconColor': Color(0xFFE67E22), // 温かみのあるオレンジ
      'memberBackgroundColor': Color(0xFFF1F8E9),
      'appBarTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'inputTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'bottomNavigationSelectedColor': Color(0xFFE67E22),
    },
    'ダーク': {
      'appBarColor': Color(0xFF121212), // より深い黒
      'backgroundColor': Color(0xFF1E1E1E), // 目に優しいダークグレー
      'buttonColor': Color(0xFF2C2C2C), // コントラストを保った按钮色
      'backgroundColor2': Color(0xFF2A2A2A),
      'fontColor1': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'fontColor2': Color(0xFFE0E0E0),
      'timerCircleColor': Color(0xFF6C6C6C),
      'bottomNavigationColor': Color(0xFF121212),
      'inputBackgroundColor': Color(0xFF333333),
      'iconColor': Color(0xFF81C784), // アクセントのミントグリーン
      'memberBackgroundColor': Color(0xFF424242),
      'appBarTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'dialogBackgroundColor': Color(0xFF2A2A2A),
      'dialogTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'inputTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'bottomNavigationSelectedColor': Color(0xFF81C784),
    },
    'ライト': {
      'appBarColor': Color(0xFFFAFAFA), // より純粋な白
      'backgroundColor': Color(0xFFFFFFFF),
      'buttonColor': Color(0xFFE0E0E0), // より濃いグレーでコントラスト改善
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000), // 明るい背景なので黒文字
      'fontColor2': Color(0xFF424242), // ボタンテキストを濃いグレーに
      'timerCircleColor': Color(0xFF757575),
      'bottomNavigationColor': Color(0xFFFAFAFA),
      'inputBackgroundColor': Color(0xFFF8F8F8),
      'iconColor': Color(0xFF2196F3), // クリーンなブルー
      'memberBackgroundColor': Color(0xFFF0F4FF),
      'appBarTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'bottomNavigationTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'inputTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'bottomNavigationSelectedColor': Color(0xFF2196F3),
    },
    'ライトグレー': {
      'appBarColor': Color(0xFF37474F), // よりモダンなブルーグレー
      'backgroundColor': Color(0xFFF7F9FA),
      'buttonColor': Color(0xFF78909C), // より濃いグレーでコントラスト改善
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000), // 明るい背景なので黒文字
      'fontColor2': Color(0xFFFFFFFF), // 白色に変更してコントラスト確保
      'timerCircleColor': Color(0xFF78909C),
      'bottomNavigationColor': Color(0xFF37474F),
      'inputBackgroundColor': Color(0xFFF5F7F8),
      'iconColor': Color(0xFF607D8B),
      'memberBackgroundColor': Color(0xFFECEFF1),
      'appBarTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'inputTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'bottomNavigationSelectedColor': Color(0xFFFF7043),
    },
    // ブラウン系（コーヒーテーマ強化）
    'ブラウン': {
      'appBarColor': Color(0xFF3E2723),
      'backgroundColor': Color(0xFFFDF8F5), // より温かみのある背景
      'buttonColor': Color(0xFF6D4C41), // より濃いブラウンでコントラスト改善
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000), // 明るい背景なので黒文字
      'fontColor2': Color(0xFFFFFFFF), // 白色に変更してコントラスト確保
      'timerCircleColor': Color(0xFF6D4C41),
      'bottomNavigationColor': Color(0xFF3E2723),
      'inputBackgroundColor': Color(0xFFF9F5F1),
      'iconColor': Color(0xFFBCAAA4), // 洗練されたベージュ
      'memberBackgroundColor': Color(0xFFEFEBE9),
      'appBarTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'inputTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'bottomNavigationSelectedColor': Color(0xFFD7CCC8),
    },
    'ベージュ': {
      'appBarColor': Color(0xFF8D6E63), // より濃い色でコントラスト改善
      'backgroundColor': Color(0xFFFFFAF0),
      'buttonColor': Color(0xFFA1887F), // より濃いベージュでコントラスト改善
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000), // 明るい背景なので黒文字
      'fontColor2': Color(0xFFFFFFFF), // 白色に変更してコントラスト確保
      'timerCircleColor': Color(0xFFA1887F),
      'bottomNavigationColor': Color(0xFF8D6E63),
      'inputBackgroundColor': Color(0xFFFFF8F0),
      'iconColor': Color(0xFFE4C441), // 温かみのあるゴールド
      'memberBackgroundColor': Color(0xFFF3E5AB),
      'appBarTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'inputTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'bottomNavigationSelectedColor': Color(0xFFE4C441),
    },
    'エスプレッソ': {
      // 新追加
      'appBarColor': Color(0xFF1A0E0A),
      'backgroundColor': Color(0xFFFBF7F4),
      'buttonColor': Color(0xFF4A2C2A), // より濃い色でコントラスト改善
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000), // 明るい背景なので黒文字
      'fontColor2': Color(0xFFFFFFFF), // 白色に変更してコントラスト確保
      'timerCircleColor': Color(0xFF4A2C2A),
      'bottomNavigationColor': Color(0xFF1A0E0A),
      'inputBackgroundColor': Color(0xFFF7F1ED),
      'iconColor': Color(0xFFD4AF37), // ゴールデンクレマ色
      'memberBackgroundColor': Color(0xFFEDDDD4),
      'appBarTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'inputTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'bottomNavigationSelectedColor': Color(0xFFD4AF37),
    },
    'カプチーノ': {
      // 新追加
      'appBarColor': Color(0xFFA0764A),
      'backgroundColor': Color(0xFFFFF9F2),
      'buttonColor': Color(0xFF8D6E63), // より濃い色でコントラスト改善
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000), // 明るい背景なので黒文字
      'fontColor2': Color(0xFFFFFFFF), // 白色に変更してコントラスト確保
      'timerCircleColor': Color(0xFF8D6E63),
      'bottomNavigationColor': Color(0xFFA0764A),
      'inputBackgroundColor': Color(0xFFFFF7EC),
      'iconColor': Color(0xFFCD853F), // ミルクフォーム色
      'memberBackgroundColor': Color(0xFFF4E7D1),
      'appBarTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'inputTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'bottomNavigationSelectedColor': Color(0xFFCD853F),
    },
    // 赤・ピンク系（より洗練された色調）
    'サクラ': {
      // 新追加
      'appBarColor': Color(0xFFE91E63),
      'backgroundColor': Color(0xFFFFF0F5),
      'buttonColor': Color(0xFFD81B60), // より濃い色でコントラスト改善
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000), // 明るい背景なので黒文字
      'fontColor2': Color(0xFFFFFFFF), // 白色でコントラスト確保
      'timerCircleColor': Color(0xFFD81B60),
      'bottomNavigationColor': Color(0xFFE91E63),
      'inputBackgroundColor': Color(0xFFFDF2F8),
      'iconColor': Color(0xFFFF80AB), // 桜のピンク
      'memberBackgroundColor': Color(0xFFFCE4EC),
      'appBarTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'inputTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'bottomNavigationSelectedColor': Color(0xFFFF80AB),
    },
    // グリーン系（自然で現代的）
    'フォレスト': {
      // 新追加
      'appBarColor': Color(0xFF2E7D32),
      'backgroundColor': Color(0xFFF1F8E9),
      'buttonColor': Color(0xFF388E3C), // より濃い緑でコントラスト改善
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000), // 明るい背景なので黒文字
      'fontColor2': Color(0xFFFFFFFF), // 白色でコントラスト確保
      'timerCircleColor': Color(0xFF388E3C),
      'bottomNavigationColor': Color(0xFF2E7D32),
      'inputBackgroundColor': Color(0xFFF7FCF0),
      'iconColor': Color(0xFF81C784), // 森の緑
      'memberBackgroundColor': Color(0xFFE8F5E8),
      'appBarTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'inputTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'bottomNavigationSelectedColor': Color(0xFF81C784),
    },
    'ティール': {
      // 新追加
      'appBarColor': Color(0xFF00695C),
      'backgroundColor': Color(0xFFE0F2F1),
      'buttonColor': Color(0xFF00796B), // より濃い色でコントラスト改善
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000), // 明るい背景なので黒文字
      'fontColor2': Color(0xFFFFFFFF), // 白色でコントラスト確保
      'timerCircleColor': Color(0xFF00796B),
      'bottomNavigationColor': Color(0xFF00695C),
      'inputBackgroundColor': Color(0xFFF4FDF9),
      'iconColor': Color(0xFF80CBC4), // ティール系カラー
      'memberBackgroundColor': Color(0xFFB2DFDB),
      'appBarTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'inputTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'bottomNavigationSelectedColor': Color(0xFF80CBC4),
    },
    'ミントグリーン': {
      // 新追加
      'appBarColor': Color(0xFF00796B),
      'backgroundColor': Color(0xFFE8F5F2),
      'buttonColor': Color(0xFF26A69A), // より鮮やかなミントグリーンでコントラスト改善
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000), // 明るい背景なので黒文字
      'fontColor2': Color(0xFFFFFFFF), // 白色でコントラスト確保
      'timerCircleColor': Color(0xFF26A69A),
      'bottomNavigationColor': Color(0xFF00796B),
      'inputBackgroundColor': Color(0xFFF0FBF9),
      'iconColor': Color(0xFF4DB6AC), // 明るいミントグリーン
      'memberBackgroundColor': Color(0xFFB2DFDB),
      'appBarTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'inputTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'bottomNavigationSelectedColor': Color(0xFF4DB6AC),
    },
    // ブルー系（クリーンで現代的）
    'オーシャン': {
      // 新追加
      'appBarColor': Color(0xFF0277BD),
      'backgroundColor': Color(0xFFE1F5FE),
      'buttonColor': Color(0xFF0288D1), // より濃い青でコントラスト改善
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000), // 明るい背景なので黒文字
      'fontColor2': Color(0xFFFFFFFF), // 白色でコントラスト確保
      'timerCircleColor': Color(0xFF0288D1),
      'bottomNavigationColor': Color(0xFF0277BD),
      'inputBackgroundColor': Color(0xFFF0FBFF),
      'iconColor': Color(0xFF4FC3F7), // オーシャンブルー
      'memberBackgroundColor': Color(0xFFB3E5FC),
      'appBarTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'inputTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'bottomNavigationSelectedColor': Color(0xFF4FC3F7),
    },
    'ネイビー': {
      'appBarColor': Color(0xFF1A237E), // より深いネイビー
      'backgroundColor': Color(0xFFF3F7FF),
      'buttonColor': Color(0xFF303F9F), // より濃い色でコントラスト改善
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000), // 明るい背景なので黒文字
      'fontColor2': Color(0xFFFFFFFF), // 白色でコントラスト確保
      'timerCircleColor': Color(0xFF303F9F),
      'bottomNavigationColor': Color(0xFF1A237E),
      'inputBackgroundColor': Color(0xFFF5F8FF),
      'iconColor': Color(0xFF7986CB), // エレガントなブルー
      'memberBackgroundColor': Color(0xFFE8EAF6),
      'appBarTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'inputTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'bottomNavigationSelectedColor': Color(0xFF7986CB),
    },
    // パープル系（エレガント）
    'ラベンダー': {
      // 新追加
      'appBarColor': Color(0xFF7B1FA2),
      'backgroundColor': Color(0xFFFAF4FF),
      'buttonColor': Color(0xFF8E24AA), // より濃い色でコントラスト改善
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000), // 明るい背景なので黒文字
      'fontColor2': Color(0xFFFFFFFF), // 白色でコントラスト確保
      'timerCircleColor': Color(0xFF8E24AA),
      'bottomNavigationColor': Color(0xFF7B1FA2),
      'inputBackgroundColor': Color(0xFFF7F1FF),
      'iconColor': Color(0xFFCE93D8), // ラベンダー
      'memberBackgroundColor': Color(0xFFF3E5F5),
      'appBarTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'inputTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'bottomNavigationSelectedColor': Color(0xFFCE93D8),
    },
    // レッド・オレンジ系テーマ
    'レッド': {
      'appBarColor': Color(0xFFC62828), // 深いレッド
      'backgroundColor': Color(0xFFFFF5F5),
      'buttonColor': Color(0xFFD32F2F), // より濃いレッドでコントラスト改善
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000), // 明るい背景なので黒文字
      'fontColor2': Color(0xFFFFFFFF), // 白色でコントラスト確保
      'timerCircleColor': Color(0xFFD32F2F),
      'bottomNavigationColor': Color(0xFFC62828),
      'inputBackgroundColor': Color(0xFFFFF8F8),
      'iconColor': Color(0xFFEF5350), // 明るいレッド
      'memberBackgroundColor': Color(0xFFFFEBEE),
      'appBarTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'inputTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'bottomNavigationSelectedColor': Color(0xFFEF5350),
    },
    'オレンジ': {
      // 新追加
      'appBarColor': Color(0xFFE65100),
      'backgroundColor': Color(0xFFFFF8F0),
      'buttonColor': Color(0xFFF57C00), // より濃いオレンジでコントラスト改善
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000), // 明るい背景なので黒文字
      'fontColor2': Color(0xFFFFFFFF), // 白色でコントラスト確保
      'timerCircleColor': Color(0xFFF57C00),
      'bottomNavigationColor': Color(0xFFE65100),
      'inputBackgroundColor': Color(0xFFFFF9F4),
      'iconColor': Color(0xFFFFB74D), // 明るいオレンジ
      'memberBackgroundColor': Color(0xFFFFE0B2),
      'appBarTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'inputTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'bottomNavigationSelectedColor': Color(0xFFFFB74D),
    },
    'タンジェリン': {
      // 新追加
      'appBarColor': Color(0xFFFF6F00),
      'backgroundColor': Color(0xFFFFF7ED),
      'buttonColor': Color(0xFFFF8F00), // より濃い色でコントラスト改善
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000), // 明るい背景なので黒文字
      'fontColor2': Color(0xFFFFFFFF), // 白色でコントラスト確保
      'timerCircleColor': Color(0xFFFF8F00),
      'bottomNavigationColor': Color(0xFFFF6F00),
      'inputBackgroundColor': Color(0xFFFFFAF0),
      'iconColor': Color(0xFFFFCC02), // タンジェリンオレンジ
      'memberBackgroundColor': Color(0xFFFFE0B2),
      'appBarTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'inputTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'bottomNavigationSelectedColor': Color(0xFFFFCC02),
    },
    'アンバー': {
      // 新追加
      'appBarColor': Color(0xFFFF8F00),
      'backgroundColor': Color(0xFFFFF8E1),
      'buttonColor': Color(0xFFFFB300), // より濃い色でコントラスト改善
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000), // 明るい背景なので黒文字
      'fontColor2': Color(0xFF000000), // 明るいボタンなので黒文字
      'timerCircleColor': Color(0xFFFFB300),
      'bottomNavigationColor': Color(0xFFFF8F00),
      'inputBackgroundColor': Color(0xFFFFFBF0),
      'iconColor': Color(0xFFFDD835), // 琥珀色
      'memberBackgroundColor': Color(0xFFFFECB3),
      'appBarTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'inputTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'bottomNavigationSelectedColor': Color(0xFFFDD835),
    },
    'キャラメル': {
      // 新追加
      'appBarColor': Color(0xFFC17817),
      'backgroundColor': Color(0xFFFFF9F2),
      'buttonColor': Color(0xFFB8860B), // より濃い色でコントラスト改善
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000), // 明るい背景なので黒文字
      'fontColor2': Color(0xFFFFFFFF), // 白色でコントラスト確保
      'timerCircleColor': Color(0xFFB8860B),
      'bottomNavigationColor': Color(0xFFC17817),
      'inputBackgroundColor': Color(0xFFFFFCF7),
      'iconColor': Color(0xFFDAA520), // キャラメル色
      'memberBackgroundColor': Color(0xFFF3E5AB),
      'appBarTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'inputTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'bottomNavigationSelectedColor': Color(0xFFDAA520),
    },
    'パンプキン': {
      // 新追加
      'appBarColor': Color(0xFFD2691E),
      'backgroundColor': Color(0xFFFFF7F0),
      'buttonColor': Color(0xFFCD853F), // より濃い色でコントラスト改善
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000), // 明るい背景なので黒文字
      'fontColor2': Color(0xFFFFFFFF), // 白色でコントラスト確保
      'timerCircleColor': Color(0xFFCD853F),
      'bottomNavigationColor': Color(0xFFD2691E),
      'inputBackgroundColor': Color(0xFFFFFAF5),
      'iconColor': Color(0xFFFFB347), // パンプキンオレンジ
      'memberBackgroundColor': Color(0xFFFFD8B1),
      'appBarTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'inputTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'bottomNavigationSelectedColor': Color(0xFFFFB347),
    },
    // 新しいトレンドカラー
    'サンセット': {
      // 新追加
      'appBarColor': Color(0xFFFF5722),
      'backgroundColor': Color(0xFFFFF3E0),
      'buttonColor': Color(0xFFE64A19), // より濃い色でコントラスト改善
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000), // 明るい背景なので黒文字
      'fontColor2': Color(0xFFFFFFFF), // 白色でコントラスト確保
      'timerCircleColor': Color(0xFFE64A19),
      'bottomNavigationColor': Color(0xFFFF5722),
      'inputBackgroundColor': Color(0xFFFFF8F0),
      'iconColor': Color(0xFFFFAB91), // サンセットオレンジ
      'memberBackgroundColor': Color(0xFFFFE0B2),
      'appBarTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'inputTextColor': Color(0xFF000000), // 明るい背景なので黒文字
      'bottomNavigationSelectedColor': Color(0xFFFFAB91),
    },

    // 個性派
    // ... ここに今後追加する場合は記載 ...
  };

  // 利用可能なフォントのリスト
  static const List<String> availableFonts = [
    'Noto Sans JP',
    'ZenMaruGothic',
    'utsukushiFONT',
    'KiwiMaru',
    'HannariMincho',
    'Harenosora',
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

  // 利用可能なフォントかチェックして、なければデフォルトを返す
  static String _getValidFontFamily(String fontFamily) {
    if (availableFonts.contains(fontFamily)) {
      return fontFamily;
    }
    return 'Noto Sans JP'; // デフォルトフォント
  }

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
        fontFamily: _getValidFontFamily(
          prefs.getString(_fontFamilyKey) ?? 'Noto Sans JP',
        ),
        bottomNavigationSelectedColor:
            cloudTheme['bottomNavigationSelectedColor'],
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
        fontFamily: _getValidFontFamily(
          prefs.getString(_fontFamilyKey) ?? 'Noto Sans JP',
        ),
        bottomNavigationSelectedColor: preset?['bottomNavigationSelectedColor'],
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
