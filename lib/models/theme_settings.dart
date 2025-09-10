import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/theme_cloud_service.dart';
import '../services/user_settings_firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../services/encrypted_local_storage_service.dart';

class ThemeSettings extends ChangeNotifier {
  Color appBarColor; // アプリバーの背景色
  Color backgroundColor; // 画面全体の背景色
  Color buttonColor; // プリセット選択ボタンの色
  Color appButtonColor; // アプリ全体のボタンの色
  Color cardBackgroundColor; // カード・パネルの背景色
  Color fontColor1; // メインの文字色（タイトル、本文など）
  Color fontColor2; // ボタンやアクセント要素の文字色
  Color iconColor; // アイコンの色
  Color timerCircleColor; // 焙煎タイマーの円の色
  Color bottomNavigationColor; // ボトムナビゲーションバーの背景色
  Color inputBackgroundColor; // テキスト入力欄の背景色
  Color memberBackgroundColor; // メンバー表示の背景色
  Color appBarTextColor; // アプリバーの文字色
  Color bottomNavigationTextColor; // ボトムナビゲーションの文字色
  Color dialogBackgroundColor; // ダイアログの背景色
  Color dialogTextColor; // ダイアログの文字色
  Color inputTextColor; // テキスト入力欄の文字色
  Color borderColor; // 境界線の色
  double fontSizeScale; // フォントサイズの倍率（1.0が標準）
  String fontFamily; // フォントファミリー
  Color? customBottomNavigationSelectedColor; // カスタムボトムナビゲーション選択時の色
  Color? customBottomNavigationUnselectedColor; // カスタムボトムナビゲーション非選択時の色

  // 機能別の色設定
  Color calculatorColor; // 計算機機能のアクセント色
  Color settingsColor; // 設定機能のアクセント色
  Color todoColor;
  Color tastingColor; // テイスティング機能のアクセント色

  // Firestoreリスナー用
  Stream<DocumentSnapshot>? _fontSettingsStream;
  StreamSubscription? _fontSettingsSubscription;
  StreamSubscription? _themeSettingsSubscription;

  // 初期インストール時にデフォルトテーマを適用
  Future<void> initializeDefaultTheme() async {
    // 未ログインの場合はFirestoreにアクセスしない
    if (FirebaseAuth.instance.currentUser == null) {
      final defaultTheme = presets['デフォルト']!;
      appBarColor = defaultTheme['appBarColor']!;
      backgroundColor = defaultTheme['backgroundColor']!;
      buttonColor = defaultTheme['buttonColor']!;
      cardBackgroundColor = defaultTheme['cardBackgroundColor']!;
      fontColor1 = defaultTheme['fontColor1']!;
      fontColor2 = defaultTheme['fontColor2']!;
      iconColor = defaultTheme['iconColor']!;
      timerCircleColor = defaultTheme['timerCircleColor']!;
      bottomNavigationColor = defaultTheme['bottomNavigationColor']!;
      inputBackgroundColor = defaultTheme['inputBackgroundColor']!;
      memberBackgroundColor = defaultTheme['memberBackgroundColor']!;
      appBarTextColor = defaultTheme['appBarTextColor']!;
      bottomNavigationTextColor = defaultTheme['bottomNavigationTextColor']!;
      dialogBackgroundColor = defaultTheme['dialogBackgroundColor']!;
      dialogTextColor = defaultTheme['dialogTextColor']!;
      inputTextColor = defaultTheme['inputTextColor']!;
      borderColor = defaultTheme['borderColor']!;
      _bottomNavigationSelectedColor =
          defaultTheme['bottomNavigationSelectedColor'];
      _bottomNavigationUnselectedColor =
          defaultTheme['bottomNavigationUnselectedColor'];
      customBottomNavigationSelectedColor = null;
      customBottomNavigationUnselectedColor = null;
      settingsColor = defaultTheme['settingsColor']!;
      todoColor = defaultTheme['iconColor']!;
      calculatorColor = defaultTheme['iconColor']!; // アイコンの色と同じ値に設定
      fontSizeScale = 1.0;
      fontFamily = 'Noto Sans JP';
      notifyListeners();
      return;
    }

    final isFirstInstall =
        await UserSettingsFirestoreService.getSetting('isFirstInstall') ?? true;

    if (isFirstInstall) {
      // デフォルトテーマを適用
      final defaultTheme = presets['デフォルト']!;
      appBarColor = defaultTheme['appBarColor']!;
      backgroundColor = defaultTheme['backgroundColor']!;
      buttonColor = defaultTheme['buttonColor']!;
      cardBackgroundColor = defaultTheme['cardBackgroundColor']!;
      fontColor1 = defaultTheme['fontColor1']!;
      fontColor2 = defaultTheme['fontColor2']!;
      iconColor = defaultTheme['iconColor']!; // オレンジ色
      timerCircleColor = defaultTheme['timerCircleColor']!;
      bottomNavigationColor = defaultTheme['bottomNavigationColor']!;
      inputBackgroundColor = defaultTheme['inputBackgroundColor']!;
      memberBackgroundColor = defaultTheme['memberBackgroundColor']!;
      appBarTextColor = defaultTheme['appBarTextColor']!;
      bottomNavigationTextColor = defaultTheme['bottomNavigationTextColor']!;
      dialogBackgroundColor = defaultTheme['dialogBackgroundColor']!;
      dialogTextColor = defaultTheme['dialogTextColor']!;
      inputTextColor = defaultTheme['inputTextColor']!;
      borderColor = defaultTheme['borderColor']!;
      _bottomNavigationSelectedColor =
          defaultTheme['bottomNavigationSelectedColor'];
      _bottomNavigationUnselectedColor =
          defaultTheme['bottomNavigationUnselectedColor'];
      customBottomNavigationSelectedColor = null;
      customBottomNavigationUnselectedColor = null;
      settingsColor = defaultTheme['settingsColor']!; // デフォルトテーマの設定色を使用
      todoColor = defaultTheme['iconColor']!;
      calculatorColor = defaultTheme['iconColor']!; // アイコンの色と同じ値に設定
      fontSizeScale = 1.0;
      fontFamily = 'Noto Sans JP';

      // 設定を保存
      save();

      // 初回インストールフラグを設定
      await UserSettingsFirestoreService.saveSetting('isFirstInstall', false);

      notifyListeners();
    }
  }

  // Firestoreからテーマ設定を一度だけ取得して反映
  Future<void> loadThemeFromFirestore() async {
    final themeData = await ThemeCloudService.getThemeFromCloud();
    if (themeData != null) {
      appBarColor = themeData['appBarColor'] ?? appBarColor;
      backgroundColor = themeData['backgroundColor'] ?? backgroundColor;
      buttonColor = themeData['buttonColor'] ?? buttonColor;
      appButtonColor = themeData['appButtonColor'] ?? appButtonColor;
      cardBackgroundColor =
          themeData['cardBackgroundColor'] ?? cardBackgroundColor;
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
      customBottomNavigationSelectedColor =
          themeData['customBottomNavigationSelectedColor'];
      customBottomNavigationUnselectedColor =
          themeData['customBottomNavigationUnselectedColor'];
      settingsColor = themeData['settingsColor'] ?? settingsColor;
      todoColor = themeData['todoColor'] ?? todoColor;
      calculatorColor = themeData['calculatorColor'] ?? calculatorColor;
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
              appButtonColor = themeData['appButtonColor'] ?? appButtonColor;
              cardBackgroundColor =
                  themeData['cardBackgroundColor'] ?? cardBackgroundColor;
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
              _bottomNavigationSelectedColor =
                  themeData['bottomNavigationSelectedColor'] ??
                  _bottomNavigationSelectedColor;
              _bottomNavigationUnselectedColor =
                  themeData['bottomNavigationUnselectedColor'] ??
                  _bottomNavigationUnselectedColor;
              customBottomNavigationSelectedColor =
                  themeData['customBottomNavigationSelectedColor'];
              customBottomNavigationUnselectedColor =
                  themeData['customBottomNavigationUnselectedColor'];
              settingsColor = themeData['settingsColor'] ?? settingsColor;
              todoColor = themeData['todoColor'] ?? todoColor;
              calculatorColor = themeData['calculatorColor'] ?? calculatorColor;
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
    return _bottomNavigationSelectedColor ?? iconColor;
  }

  Color get bottomNavigationUnselectedColor {
    if (customBottomNavigationUnselectedColor != null) {
      return customBottomNavigationUnselectedColor!;
    }
    return _bottomNavigationUnselectedColor ?? Color(0xFF9E9E9E);
  }

  Color? _bottomNavigationSelectedColor;
  Color? _bottomNavigationUnselectedColor;

  ThemeSettings({
    required this.appBarColor,
    required this.backgroundColor,
    required this.buttonColor,
    required this.appButtonColor,
    required this.cardBackgroundColor,
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
    required this.inputTextColor,
    required this.borderColor,
    required this.fontSizeScale,
    required this.fontFamily,
    Color? bottomNavigationSelectedColor,
    Color? bottomNavigationUnselectedColor,
    this.customBottomNavigationSelectedColor,
    this.customBottomNavigationUnselectedColor,
    required this.calculatorColor,
    required this.settingsColor,
    required this.todoColor,
    required this.tastingColor,
  }) : _bottomNavigationSelectedColor = bottomNavigationSelectedColor,
       _bottomNavigationUnselectedColor = bottomNavigationUnselectedColor;

  // プリセットテーマの定義（アイコン色は薄い色で設定）
  static const Map<String, Map<String, Color>> presets = {
    // 基本
    'デフォルト': {
      'appBarColor': Color(0xFF2C1810), // アプリバーの背景色
      'backgroundColor': Color(0xFFFFFBF0), // 画面全体の背景色
      'buttonColor': Color(0xFF8B4513), // プリセット選択ボタンの色
      'appButtonColor': Color(0xFF8B4513), // アプリ全体のボタンの色
      'cardBackgroundColor': Color(0xFFFFFFFF), // カード・パネルの背景色
      'fontColor1': Color(0xFF2C1810), // メインの文字色
      'fontColor2': Color(0xFFFFFFFF), // ボタンやアクセント要素の文字色
      'timerCircleColor': Color(0xFF8B4513), // 焙煎タイマーの円の色
      'bottomNavigationColor': Color(0xFF2C1810), // ボトムナビゲーションバーの背景色
      'inputBackgroundColor': Color(0xFFFFF8F0), // テキスト入力欄の背景色
      'iconColor': Color(0xFFD2691E), // アイコンの色
      'memberBackgroundColor': Color(0xFFFFF5E6), // メンバー表示の背景色
      'appBarTextColor': Color(0xFFFFFFFF), // アプリバーの文字色
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // ボトムナビゲーションの文字色
      'dialogBackgroundColor': Color(0xFFFFFFFF), // ダイアログの背景色
      'dialogTextColor': Color(0xFF2C1810), // ダイアログの文字色
      'inputTextColor': Color(0xFF2C1810), // テキスト入力欄の文字色
      'borderColor': Color(0xFFE6D7C3), // 境界線の色
      'bottomNavigationSelectedColor': Color(0xFFD2691E), // ボトムナビゲーション選択時の色
      'bottomNavigationUnselectedColor': Color(0xFF8B7355), // ボトムナビゲーション非選択時の色
      'settingsColor': Color(0xFF8B4513), // 設定機能のアクセント色
      'calculatorColor': Color(0xFFD2691E), // 計算機機能のアクセント色
      'todoColor': Color(0xFFD2691E), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    'ダーク': {
      'appBarColor': Color(0xFF121212), // アプリバーの背景色
      'backgroundColor': Color(0xFF1E1E1E), // 画面全体の背景色
      'buttonColor': Color(0xFF303030), // プリセット選択ボタンの色
      'appButtonColor': Color.fromRGBO(97, 97, 97, 1), // アプリ全体のボタンの色
      'cardBackgroundColor': Color(0xFF2A2A2A), // カード・パネルの背景色
      'fontColor1': Color(0xFFFFFFFF), // メインの文字色
      'fontColor2': Color(0xFFE0E0E0), // ボタンやアクセント要素の文字色
      'timerCircleColor': Color(0xFF6C6C6C), // 焙煎タイマーの円の色
      'bottomNavigationColor': Color(0xFF121212), // ボトムナビゲーションバーの背景色
      'inputBackgroundColor': Color(0xFF333333), // テキスト入力欄の背景色
      'iconColor': Color(0xFF81C784), // アイコンの色
      'memberBackgroundColor': Color(0xFF424242), // メンバー表示の背景色
      'appBarTextColor': Color(0xFFFFFFFF), // アプリバーの文字色
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // ボトムナビゲーションの文字色
      'dialogBackgroundColor': Color(0xFF2A2A2A), // ダイアログの背景色
      'dialogTextColor': Color(0xFFFFFFFF), // ダイアログの文字色
      'inputTextColor': Color(0xFF000000), // テキスト入力欄の文字色
      'borderColor': Color(0xFF424242), // 境界線の色
      'bottomNavigationSelectedColor': Color(0xFF81C784), // ボトムナビゲーション選択時の色
      'bottomNavigationUnselectedColor': Color(0xFF424242), // ボトムナビゲーション非選択時の色
      'settingsColor': Color(0xFF2E7D32), // 設定機能のアクセント色
      'calculatorColor': Color(0xFF81C784), // 計算機機能のアクセント色
      'todoColor': Color(0xFF81C784), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    'ライト': {
      'appBarColor': Color(0xFFFAFAFA), // アプリバーの背景色
      'backgroundColor': Color(0xFFFFFFFF), // 画面全体の背景色
      'buttonColor': Color(0xFF2196F3), // プリセット選択ボタンの色
      'appButtonColor': Color(0xFF2196F3), // アプリ全体のボタンの色
      'cardBackgroundColor': Color(0xFFFFFFFF), // カード・パネルの背景色
      'fontColor1': Color(0xFF000000), // メインの文字色
      'fontColor2': Color(0xFFFFFFFF), // ボタンやアクセント要素の文字色
      'timerCircleColor': Color(0xFF2196F3), // 焙煎タイマーの円の色
      'bottomNavigationColor': Color(0xFFF5F5F5), // ボトムナビゲーションバーの背景色
      'inputBackgroundColor': Color(0xFFF8F8F8), // テキスト入力欄の背景色
      'iconColor': Color(0xFF2196F3), // アイコンの色
      'memberBackgroundColor': Color(0xFFF0F4FF), // メンバー表示の背景色
      'appBarTextColor': Color(0xFF000000), // アプリバーの文字色
      'bottomNavigationTextColor': Color(0xFF000000), // ボトムナビゲーションの文字色
      'dialogBackgroundColor': Color(0xFFFFFFFF), // ダイアログの背景色
      'dialogTextColor': Color(0xFF000000), // ダイアログの文字色
      'inputTextColor': Color(0xFF000000), // テキスト入力欄の文字色
      'borderColor': Color(0xFFE0E0E0), // 境界線の色
      'bottomNavigationSelectedColor': Color(0xFF2196F3), // ボトムナビゲーション選択時の色
      'bottomNavigationUnselectedColor': Color(0xFF757575), // ボトムナビゲーション非選択時の色
      'settingsColor': Color(0xFF1976D2), // 設定機能のアクセント色
      'calculatorColor': Color(0xFF2196F3), // 計算機機能のアクセント色
      'todoColor': Color(0xFF2196F3), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },

    // ブラウン系（コーヒーテーマ強化）
    'ブラウン': {
      'appBarColor': Color(0xFF3E2723), // アプリバーの背景色
      'backgroundColor': Color(0xFFFDF8F5), // 画面全体の背景色
      'buttonColor': Color(0xFF6D4C41), // プリセット選択ボタンの色
      'appButtonColor': Color(0xFF6D4C41), // アプリ全体のボタンの色
      'cardBackgroundColor': Color(0xFFFFFFFF), // カード・パネルの背景色
      'fontColor1': Color(0xFF000000), // メインの文字色
      'fontColor2': Color(0xFFFFFFFF), // ボタンやアクセント要素の文字色
      'timerCircleColor': Color(0xFF6D4C41), // 焙煎タイマーの円の色
      'bottomNavigationColor': Color(0xFF3E2723), // ボトムナビゲーションバーの背景色
      'inputBackgroundColor': Color(0xFFF9F5F1), // テキスト入力欄の背景色
      'iconColor': Color(0xFFBCAAA4), // アイコンの色
      'memberBackgroundColor': Color(0xFFEFEBE9), // メンバー表示の背景色
      'appBarTextColor': Color(0xFFFFFFFF), // アプリバーの文字色
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // ボトムナビゲーションの文字色
      'dialogBackgroundColor': Color(0xFFFFFFFF), // ダイアログの背景色
      'dialogTextColor': Color(0xFF000000), // ダイアログの文字色
      'inputTextColor': Color(0xFF000000), // テキスト入力欄の文字色
      'borderColor': Color(0xFFE0E0E0), // 境界線の色
      'bottomNavigationSelectedColor': Color(0xFFD7CCC8), // ボトムナビゲーション選択時の色
      'bottomNavigationUnselectedColor': Color(0xFF8B7355), // ボトムナビゲーション非選択時の色
      'settingsColor': Color(0xFF5D4037), // 設定機能のアクセント色
      'calculatorColor': Color(0xFFBCAAA4), // 計算機機能のアクセント色
      'todoColor': Color(0xFFBCAAA4), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    'ベージュ': {
      'appBarColor': Color(0xFF8D6E63), // アプリバーの背景色
      'backgroundColor': Color(0xFFFFFAF0), // 画面全体の背景色
      'buttonColor': Color(0xFFA1887F), // プリセット選択ボタンの色
      'appButtonColor': Color(0xFFA1887F), // アプリ全体のボタンの色
      'cardBackgroundColor': Color(0xFFFFFFFF), // カード・パネルの背景色
      'fontColor1': Color(0xFF000000), // メインの文字色
      'fontColor2': Color(0xFFFFFFFF), // ボタンやアクセント要素の文字色
      'timerCircleColor': Color(0xFFA1887F), // 焙煎タイマーの円の色
      'bottomNavigationColor': Color(0xFF8D6E63), // ボトムナビゲーションバーの背景色
      'inputBackgroundColor': Color(0xFFFFF8F0), // テキスト入力欄の背景色
      'iconColor': Color(0xFFE4C441), // アイコンの色
      'memberBackgroundColor': Color(0xFFF3E5AB), // メンバー表示の背景色
      'appBarTextColor': Color(0xFFFFFFFF), // アプリバーの文字色
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // ボトムナビゲーションの文字色
      'dialogBackgroundColor': Color(0xFFFFFFFF), // ダイアログの背景色
      'dialogTextColor': Color(0xFF000000), // ダイアログの文字色
      'inputTextColor': Color(0xFF000000), // テキスト入力欄の文字色
      'borderColor': Color(0xFFE0E0E0), // 境界線の色
      'bottomNavigationSelectedColor': Color(0xFFE4C441), // ボトムナビゲーション選択時の色
      'bottomNavigationUnselectedColor': Color(0xFF8B7355), // ボトムナビゲーション非選択時の色
      'settingsColor': Color(0xFF8D6E63), // 設定機能のアクセント色
      'calculatorColor': Color(0xFFE4C441), // 計算機機能のアクセント色
      'todoColor': Color(0xFFE4C441), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    'エスプレッソ': {
      'appBarColor': Color(0xFF1A0E0A), // アプリバーの背景色
      'backgroundColor': Color(0xFFFBF7F4), // 画面全体の背景色
      'buttonColor': Color(0xFF4A2C2A), // プリセット選択ボタンの色
      'appButtonColor': Color(0xFF4A2C2A), // アプリ全体のボタンの色
      'cardBackgroundColor': Color(0xFFFFFFFF), // カード・パネルの背景色
      'fontColor1': Color(0xFF000000), // メインの文字色
      'fontColor2': Color(0xFFFFFFFF), // ボタンやアクセント要素の文字色
      'timerCircleColor': Color(0xFF4A2C2A), // 焙煎タイマーの円の色
      'bottomNavigationColor': Color(0xFF1A0E0A), // ボトムナビゲーションバーの背景色
      'inputBackgroundColor': Color(0xFFF7F1ED), // テキスト入力欄の背景色
      'iconColor': Color(0xFFD4AF37), // アイコンの色
      'memberBackgroundColor': Color(0xFFEDDDD4), // メンバー表示の背景色
      'appBarTextColor': Color(0xFFFFFFFF), // アプリバーの文字色
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // ボトムナビゲーションの文字色
      'dialogBackgroundColor': Color(0xFFFFFFFF), // ダイアログの背景色
      'dialogTextColor': Color(0xFF000000), // ダイアログの文字色
      'inputTextColor': Color(0xFF000000), // テキスト入力欄の文字色
      'borderColor': Color(0xFFE0E0E0), // 境界線の色
      'bottomNavigationSelectedColor': Color(0xFFD4AF37), // ボトムナビゲーション選択時の色
      'bottomNavigationUnselectedColor': Color(0xFFFFFFFF), // ボトムナビゲーション非選択時の色
      'settingsColor': Color(0xFF3E2723), // 設定機能のアクセント色
      'calculatorColor': Color(0xFFD4AF37), // 計算機機能のアクセント色
      'todoColor': Color(0xFFD4AF37), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    'カプチーノ': {
      'appBarColor': Color(0xFFA0764A), // アプリバーの背景色
      'backgroundColor': Color(0xFFFFF9F2), // 画面全体の背景色
      'buttonColor': Color(0xFF8D6E63), // プリセット選択ボタンの色
      'appButtonColor': Color(0xFF8D6E63), // アプリ全体のボタンの色
      'cardBackgroundColor': Color(0xFFFFFFFF), // カード・パネルの背景色
      'fontColor1': Color(0xFF000000), // メインの文字色
      'fontColor2': Color(0xFFFFFFFF), // ボタンやアクセント要素の文字色
      'timerCircleColor': Color(0xFF8D6E63), // 焙煎タイマーの円の色
      'bottomNavigationColor': Color(0xFFA0764A), // ボトムナビゲーションバーの背景色
      'inputBackgroundColor': Color(0xFFFFF7EC), // テキスト入力欄の背景色
      'iconColor': Color(0xFFCD853F), // アイコンの色
      'memberBackgroundColor': Color(0xFFF4E7D1), // メンバー表示の背景色
      'appBarTextColor': Color(0xFFFFFFFF), // アプリバーの文字色
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // ボトムナビゲーションの文字色
      'dialogBackgroundColor': Color(0xFFFFFFFF), // ダイアログの背景色
      'dialogTextColor': Color(0xFF000000), // ダイアログの文字色
      'inputTextColor': Color(0xFF000000), // テキスト入力欄の文字色
      'borderColor': Color(0xFFE0E0E0), // 境界線の色
      'bottomNavigationSelectedColor': Color(0xFFCD853F), // ボトムナビゲーション選択時の色
      'bottomNavigationUnselectedColor': Color(0xFF8B7355), // ボトムナビゲーション非選択時の色
      'settingsColor': Color(0xFF6D4C41), // 設定機能のアクセント色
      'calculatorColor': Color(0xFFCD853F), // 計算機機能のアクセント色
      'todoColor': Color(0xFFCD853F), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    // 赤・ピンク系（より洗練された色調）
    'サクラ': {
      'appBarColor': Color(0xFFE91E63), // アプリバーの背景色
      'backgroundColor': Color(0xFFFFF0F5), // 画面全体の背景色
      'buttonColor': Color(0xFFD81B60), // プリセット選択ボタンの色
      'appButtonColor': Color(0xFFD81B60), // アプリ全体のボタンの色
      'cardBackgroundColor': Color(0xFFFFFFFF), // カード・パネルの背景色
      'fontColor1': Color(0xFF000000), // メインの文字色
      'fontColor2': Color(0xFFFFFFFF), // ボタンやアクセント要素の文字色
      'timerCircleColor': Color(0xFFD81B60), // 焙煎タイマーの円の色
      'bottomNavigationColor': Color(0xFFE91E63), // ボトムナビゲーションバーの背景色
      'inputBackgroundColor': Color(0xFFFDF2F8), // テキスト入力欄の背景色
      'iconColor': Color(0xFFFF80AB), // アイコンの色
      'memberBackgroundColor': Color(0xFFFCE4EC), // メンバー表示の背景色
      'appBarTextColor': Color(0xFFFFFFFF), // アプリバーの文字色
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // ボトムナビゲーションの文字色
      'dialogBackgroundColor': Color(0xFFFFFFFF), // ダイアログの背景色
      'dialogTextColor': Color(0xFF000000), // ダイアログの文字色
      'inputTextColor': Color(0xFF000000), // テキスト入力欄の文字色
      'borderColor': Color(0xFFE0E0E0), // 境界線の色
      'bottomNavigationSelectedColor': Color(0xFFFF80AB), // ボトムナビゲーション選択時の色
      'bottomNavigationUnselectedColor': Color(0xFFE1BEE7), // ボトムナビゲーション非選択時の色
      'settingsColor': Color(0xFFC2185B), // 設定機能のアクセント色
      'calculatorColor': Color(0xFFFF80AB), // 計算機機能のアクセント色
      'todoColor': Color(0xFFFF80AB), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    // グリーン系（自然で現代的）
    'フォレスト': {
      'appBarColor': Color(0xFF2E7D32), // アプリバーの背景色
      'backgroundColor': Color(0xFFF1F8E9), // 画面全体の背景色
      'buttonColor': Color(0xFF388E3C), // プリセット選択ボタンの色
      'appButtonColor': Color(0xFF388E3C), // アプリ全体のボタンの色
      'cardBackgroundColor': Color(0xFFFFFFFF), // カード・パネルの背景色
      'fontColor1': Color(0xFF000000), // メインの文字色
      'fontColor2': Color(0xFFFFFFFF), // ボタンやアクセント要素の文字色
      'timerCircleColor': Color(0xFF388E3C), // 焙煎タイマーの円の色
      'bottomNavigationColor': Color(0xFF2E7D32), // ボトムナビゲーションバーの背景色
      'inputBackgroundColor': Color(0xFFF7FCF0), // テキスト入力欄の背景色
      'iconColor': Color(0xFF81C784), // アイコンの色
      'memberBackgroundColor': Color(0xFFE8F5E8), // メンバー表示の背景色
      'appBarTextColor': Color(0xFFFFFFFF), // アプリバーの文字色
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // ボトムナビゲーションの文字色
      'dialogBackgroundColor': Color(0xFFFFFFFF), // ダイアログの背景色
      'dialogTextColor': Color(0xFF000000), // ダイアログの文字色
      'inputTextColor': Color(0xFF000000), // テキスト入力欄の文字色
      'borderColor': Color(0xFFE0E0E0), // 境界線の色
      'bottomNavigationSelectedColor': Color(0xFF81C784), // ボトムナビゲーション選択時の色
      'bottomNavigationUnselectedColor': Color(0xFF8B7355), // ボトムナビゲーション非選択時の色
      'settingsColor': Color(0xFF2E7D32), // 設定機能のアクセント色
      'calculatorColor': Color(0xFF81C784), // 計算機機能のアクセント色
      'todoColor': Color(0xFF81C784), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    'ティール': {
      // 新追加
      'appBarColor': Color(0xFF00695C),
      'backgroundColor': Color(0xFFE0F2F1),
      'buttonColor': Color(0xFF00796B), // より濃い色でコントラスト改善
      'cardBackgroundColor': Color(0xFFFFFFFF),
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
      'borderColor': Color(0xFFE0E0E0),
      'bottomNavigationSelectedColor': Color(0xFF80CBC4),
      'bottomNavigationUnselectedColor': Color(0xFFB2DFDB), // 薄いティール（深い背景に対して）
      'settingsColor': Color(0xFF00695C), // ダークティール
      'calculatorColor': Color(0xFF80CBC4), // 計算機機能のアクセント色
      'todoColor': Color(0xFF80CBC4), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    'ミントグリーン': {
      // 新追加
      'appBarColor': Color(0xFF00796B),
      'backgroundColor': Color(0xFFE8F5F2),
      'buttonColor': Color(0xFF26A69A), // より鮮やかなミントグリーンでコントラスト改善
      'cardBackgroundColor': Color(0xFFFFFFFF),
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
      'borderColor': Color(0xFFE0E0E0),
      'bottomNavigationSelectedColor': Color(0xFF4DB6AC),
      'bottomNavigationUnselectedColor': Color(
        0xFFB2DFDB,
      ), // 薄いミントグリーン（深い背景に対して）
      'settingsColor': Color(0xFF00796B), // ダークミントグリーン
      'calculatorColor': Color(0xFF4DB6AC), // 計算機機能のアクセント色
      'todoColor': Color(0xFF4DB6AC), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    // ブルー系（クリーンで現代的）
    'オーシャン': {
      // 新追加
      'appBarColor': Color(0xFF0277BD),
      'backgroundColor': Color(0xFFE1F5FE),
      'buttonColor': Color(0xFF0288D1), // より濃い青でコントラスト改善
      'cardBackgroundColor': Color(0xFFFFFFFF),
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
      'borderColor': Color(0xFFE0E0E0),
      'bottomNavigationSelectedColor': Color(0xFF4FC3F7),
      'bottomNavigationUnselectedColor': Color(0xFFFFFFFF), // 白
      'settingsColor': Color(0xFF0277BD), // ダークオーシャン
      'calculatorColor': Color(0xFF4FC3F7), // 計算機機能のアクセント色
      'todoColor': Color(0xFF4FC3F7), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    'ネイビー': {
      'appBarColor': Color(0xFF1A237E), // より深いネイビー
      'backgroundColor': Color(0xFFF3F7FF),
      'buttonColor': Color(0xFF303F9F), // より濃い色でコントラスト改善
      'cardBackgroundColor': Color(0xFFFFFFFF),
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
      'borderColor': Color(0xFFE0E0E0),
      'bottomNavigationSelectedColor': Color(0xFF7986CB),
      'bottomNavigationUnselectedColor': Color(0xFFC5CAE9), // 薄いネイビー（深い背景に対して）
      'settingsColor': Color(0xFF1A237E), // ダークネイビー
      'calculatorColor': Color(0xFF7986CB), // 計算機機能のアクセント色
      'todoColor': Color(0xFF7986CB), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    // パープル系（エレガント）
    'ラベンダー': {
      // 新追加
      'appBarColor': Color(0xFF7B1FA2),
      'backgroundColor': Color(0xFFFAF4FF),
      'buttonColor': Color(0xFF8E24AA), // より濃い色でコントラスト改善
      'cardBackgroundColor': Color(0xFFFFFFFF),
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
      'borderColor': Color(0xFFE0E0E0),
      'bottomNavigationSelectedColor': Color(0xFFCE93D8),
      'bottomNavigationUnselectedColor': Color(0xFFE1BEE7), // 薄いラベンダー（深い背景に対して）
      'settingsColor': Color(0xFF7B1FA2), // ダークラベンダー
      'calculatorColor': Color(0xFFCE93D8), // 計算機機能のアクセント色
      'todoColor': Color(0xFFCE93D8), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    // ゴールド系（エレガント）
    'ゴールド': {
      'appBarColor': Color(0xFFB8860B), // ダークゴールド
      'backgroundColor': Color(0xFFFFFDF0), // 非常に薄いゴールド
      'buttonColor': Color(0xFFDAA520), // ゴールデンロッド
      'cardBackgroundColor': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF2C1810), // 深いコーヒー色の文字
      'fontColor2': Color(0xFFFFFFFF), // 白色でコントラスト確保
      'timerCircleColor': Color(0xFFDAA520),
      'bottomNavigationColor': Color(0xFFB8860B),
      'inputBackgroundColor': Color(0xFFFFFEF8),
      'iconColor': Color(0xFFFFD700), // ゴールド
      'memberBackgroundColor': Color(0xFFFFF8DC), // コーンフラワー
      'appBarTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF2C1810), // 深いコーヒー色の文字
      'inputTextColor': Color(0xFF2C1810), // 深いコーヒー色の文字
      'borderColor': Color(0xFFFFF8DC), // 薄いゴールドの境界線
      'bottomNavigationSelectedColor': Color(0xFFFFD700),
      'bottomNavigationUnselectedColor': Color(0xFFFFF8DC), // 薄いゴールド（深い背景に対して）
      'settingsColor': Color(0xFFB8860B), // ダークゴールド
      'calculatorColor': Color(0xFFFFD700), // 計算機機能のアクセント色
      'todoColor': Color(0xFFFFD700), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    // シルバー系（エレガント）
    'シルバー': {
      'appBarColor': Color(0xFF696969), // ディムグレー
      'backgroundColor': Color(0xFFFAFAFA), // 非常に薄いグレー
      'buttonColor': Color(0xFF808080), // グレー
      'cardBackgroundColor': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF2C1810), // 深いコーヒー色の文字
      'fontColor2': Color(0xFFFFFFFF), // 白色でコントラスト確保
      'timerCircleColor': Color(0xFF808080),
      'bottomNavigationColor': Color(0xFF696969),
      'inputBackgroundColor': Color(0xFFFCFCFC),
      'iconColor': Color(0xFFC0C0C0), // シルバー
      'memberBackgroundColor': Color(0xFFF5F5F5), // ホワイトスモーク
      'appBarTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'bottomNavigationTextColor': Color(0xFFFFFFFF), // 暗い背景なので白文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF2C1810), // 深いコーヒー色の文字
      'inputTextColor': Color(0xFF2C1810), // 深いコーヒー色の文字
      'borderColor': Color(0xFFE8E8E8), // 薄いグレーの境界線
      'bottomNavigationSelectedColor': Color(0xFFC0C0C0),
      'bottomNavigationUnselectedColor': Color(0xFFD3D3D3), // 薄いシルバー（深い背景に対して）
      'settingsColor': Color(0xFF696969), // ダークグレー
      'calculatorColor': Color(0xFFC0C0C0), // 計算機機能のアクセント色
      'todoColor': Color(0xFFC0C0C0), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    // レッド・オレンジ系テーマ
    'レッド': {
      'appBarColor': Color(0xFFC62828), // 深いレッド
      'backgroundColor': Color(0xFFFFF5F5),
      'buttonColor': Color(0xFFD32F2F), // より濃いレッドでコントラスト改善
      'cardBackgroundColor': Color(0xFFFFFFFF),
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
      'borderColor': Color(0xFFE0E0E0),
      'bottomNavigationSelectedColor': Color(0xFFEF5350),
      'bottomNavigationUnselectedColor': Color(0xFFFFCDD2), // 薄いレッド（深い背景に対して）
      'settingsColor': Color(0xFFC62828), // ダークレッド
      'calculatorColor': Color(0xFFEF5350), // 計算機機能のアクセント色
      'todoColor': Color(0xFFEF5350), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    'オレンジ': {
      // 新追加
      'appBarColor': Color(0xFFE65100),
      'backgroundColor': Color(0xFFFFF8F0),
      'buttonColor': Color(0xFFF57C00), // より濃いオレンジでコントラスト改善
      'cardBackgroundColor': Color(0xFFFFFFFF), // ←追加
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
      'borderColor': Color(0xFFE0E0E0),
      'bottomNavigationSelectedColor': Color(0xFFFFB74D),
      'bottomNavigationUnselectedColor': Color(0xFFFFE0B2), // 薄いオレンジ（深い背景に対して）
      'settingsColor': Color(0xFFE65100), // ダークオレンジ
      'calculatorColor': Color(0xFFFFB74D), // 計算機機能のアクセント色
      'todoColor': Color(0xFFFFB74D), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    'タンジェリン': {
      // 新追加
      'appBarColor': Color(0xFFFF6F00),
      'backgroundColor': Color(0xFFFFF7ED),
      'buttonColor': Color(0xFFFF8F00), // より濃い色でコントラスト改善
      'cardBackgroundColor': Color(0xFFFFFFFF), // ←追加
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
      'borderColor': Color(0xFFE0E0E0),
      'bottomNavigationSelectedColor': Color(0xFFFFCC02),
      'bottomNavigationUnselectedColor': Color(0xFFFFE0B2), // 薄いオレンジ（深い背景に対して）
      'settingsColor': Color(0xFFFF6F00), // ダークタンジェリン
      'calculatorColor': Color(0xFFFFCC02), // 計算機機能のアクセント色
      'todoColor': Color(0xFFFFCC02), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    'アンバー': {
      // 新追加
      'appBarColor': Color(0xFFFF8F00),
      'backgroundColor': Color(0xFFFFF8E1),
      'buttonColor': Color(0xFFFFB300), // より濃い色でコントラスト改善
      'cardBackgroundColor': Color(0xFFFFFFFF), // ←追加
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
      'borderColor': Color(0xFFE0E0E0),
      'bottomNavigationSelectedColor': Color(0xFFFDD835),
      'bottomNavigationUnselectedColor': Color(0xFFFFECB3), // 薄いアンバー（深い背景に対して）
      'settingsColor': Color(0xFFFF8F00), // ダークアンバー
      'calculatorColor': Color(0xFFFDD835), // 計算機機能のアクセント色
      'todoColor': Color(0xFFFDD835), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    'キャラメル': {
      // 新追加
      'appBarColor': Color(0xFFC17817),
      'backgroundColor': Color(0xFFFFF9F2),
      'buttonColor': Color(0xFFB8860B), // より濃い色でコントラスト改善
      'cardBackgroundColor': Color(0xFFFFFFFF), // ←追加
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
      'borderColor': Color(0xFFE0E0E0),
      'bottomNavigationSelectedColor': Color(0xFFDAA520),
      'bottomNavigationUnselectedColor': Color(0xFFF3E5AB), // 薄いキャラメル（深い背景に対して）
      'settingsColor': Color(0xFFB8860B), // ダークキャラメル
      'calculatorColor': Color(0xFFDAA520), // 計算機機能のアクセント色
      'todoColor': Color(0xFFDAA520), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    'パンプキン': {
      // 新追加
      'appBarColor': Color(0xFFD2691E),
      'backgroundColor': Color(0xFFFFF7F0),
      'buttonColor': Color(0xFFCD853F), // より濃い色でコントラスト改善
      'cardBackgroundColor': Color(0xFFFFFFFF), // ←追加
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
      'borderColor': Color(0xFFE0E0E0),
      'bottomNavigationSelectedColor': Color(0xFFFFB347),
      'bottomNavigationUnselectedColor': Color(0xFFFFD8B1), // 薄いパンプキン（深い背景に対して）
      'settingsColor': Color(0xFFCD853F), // ダークパンプキン
      'calculatorColor': Color(0xFFFFB347), // 計算機機能のアクセント色
      'todoColor': Color(0xFFFFB347), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    // 新しいトレンドカラー
    'サンセット': {
      // 新追加
      'appBarColor': Color(0xFFFF5722),
      'backgroundColor': Color(0xFFFFF3E0),
      'buttonColor': Color(0xFFE64A19), // より濃い色でコントラスト改善
      'cardBackgroundColor': Color(0xFFFFFFFF), // ←追加
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
      'borderColor': Color(0xFFE0E0E0),
      'bottomNavigationSelectedColor': Color(0xFFFFAB91),
      'bottomNavigationUnselectedColor': Color(0xFFFFCCBC), // 薄いサンセット（深い背景に対して）
      'settingsColor': Color(0xFFD84315), // ダークオレンジ
      'calculatorColor': Color(0xFFFFAB91), // 計算機機能のアクセント色
      'todoColor': Color(0xFFFFAB91), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    // パステル系テーマ
    'ピンク': {
      'appBarColor': Color(0xFFFFB3D9), // 優しいピンク
      'backgroundColor': Color(0xFFFFF0F8), // 非常に薄いピンク
      'buttonColor': Color(0xFFFF80AB), // パステルピンク
      'cardBackgroundColor': Color(0xFFFFFFFF), // ←追加
      'fontColor1': Color(0xFF2C1810), // 深いコーヒー色の文字
      'fontColor2': Color(0xFFFFFFFF), // 白色でコントラスト確保
      'timerCircleColor': Color(0xFFFF80AB),
      'bottomNavigationColor': Color(0xFFFFB3D9),
      'inputBackgroundColor': Color(0xFFFFF8FC),
      'iconColor': Color(0xFFF48FB1), // パステルピンク
      'memberBackgroundColor': Color(0xFFFFE1F2),
      'appBarTextColor': Color(0xFF2C1810), // 明るい背景なので黒文字
      'bottomNavigationTextColor': Color(0xFF2C1810), // 明るい背景なので黒文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF2C1810), // 深いコーヒー色の文字
      'inputTextColor': Color(0xFF2C1810), // 深いコーヒー色の文字
      'borderColor': Color(0xFFFFE1F2), // 薄いピンクの境界線
      'bottomNavigationSelectedColor': Color(0xFFF48FB1),
      'bottomNavigationUnselectedColor': Color(0xFF757575), // グレー（明るい背景に対して）
      'settingsColor': Color(0xFFE91E63), // ダークピンク
      'calculatorColor': Color(0xFFF48FB1), // 計算機機能のアクセント色
      'todoColor': Color(0xFFF48FB1), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    'ブルー': {
      'appBarColor': Color(0xFFB3E5FC), // 優しいブルー
      'backgroundColor': Color(0xFFF0FBFF), // 非常に薄いブルー
      'buttonColor': Color(0xFF81D4FA), // パステルブルー
      'cardBackgroundColor': Color(0xFFFFFFFF), // ←追加
      'fontColor1': Color(0xFF2C1810), // 深いコーヒー色の文字
      'fontColor2': Color(0xFFFFFFFF), // 白色でコントラスト確保
      'timerCircleColor': Color(0xFF81D4FA),
      'bottomNavigationColor': Color(0xFFB3E5FC),
      'inputBackgroundColor': Color(0xFFF8FCFF),
      'iconColor': Color(0xFF4FC3F7), // パステルブルー
      'memberBackgroundColor': Color(0xFFE1F5FE),
      'appBarTextColor': Color(0xFF2C1810), // 明るい背景なので黒文字
      'bottomNavigationTextColor': Color(0xFF2C1810), // 明るい背景なので黒文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF2C1810), // 深いコーヒー色の文字
      'inputTextColor': Color(0xFF2C1810), // 深いコーヒー色の文字
      'borderColor': Color(0xFFE1F5FE), // 薄いブルーの境界線
      'bottomNavigationSelectedColor': Color(0xFF4FC3F7),
      'bottomNavigationUnselectedColor': Color(0xFF757575), // グレー（明るい背景に対して）
      'settingsColor': Color(0xFF0277BD), // ダークブルー
      'calculatorColor': Color(0xFF4FC3F7), // 計算機機能のアクセント色
      'todoColor': Color(0xFF4FC3F7), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    'グリーン': {
      'appBarColor': Color(0xFFC8E6C9), // 優しいグリーン
      'backgroundColor': Color(0xFFF1F8E9), // 非常に薄いグリーン
      'buttonColor': Color(0xFFA5D6A7), // パステルグリーン
      'cardBackgroundColor': Color(0xFFFFFFFF), // ←追加
      'fontColor1': Color(0xFF2C1810), // 深いコーヒー色の文字
      'fontColor2': Color(0xFFFFFFFF), // 白色でコントラスト確保
      'timerCircleColor': Color(0xFFA5D6A7),
      'bottomNavigationColor': Color(0xFFC8E6C9),
      'inputBackgroundColor': Color(0xFFF8FCF0),
      'iconColor': Color(0xFF81C784), // パステルグリーン
      'memberBackgroundColor': Color(0xFFE8F5E8),
      'appBarTextColor': Color(0xFF2C1810), // 明るい背景なので黒文字
      'bottomNavigationTextColor': Color(0xFF2C1810), // 明るい背景なので黒文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF2C1810), // 深いコーヒー色の文字
      'inputTextColor': Color(0xFF2C1810), // 深いコーヒー色の文字
      'borderColor': Color(0xFFE8F5E8), // 薄いグリーンの境界線
      'bottomNavigationSelectedColor': Color(0xFF81C784),
      'bottomNavigationUnselectedColor': Color(0xFF757575), // グレー（明るい背景に対して）
      'settingsColor': Color(0xFF388E3C), // ダークグリーン
      'calculatorColor': Color(0xFF81C784), // 計算機機能のアクセント色
      'todoColor': Color(0xFF81C784), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    'イエロー': {
      'appBarColor': Color(0xFFFFF9C4), // 優しいイエロー
      'backgroundColor': Color(0xFFFFFDE7), // 非常に薄いイエロー
      'buttonColor': Color(0xFFFFF59D), // パステルイエロー
      'cardBackgroundColor': Color(0xFFFFFFFF), // ←追加
      'fontColor1': Color(0xFF2C1810), // 深いコーヒー色の文字
      'fontColor2': Color(0xFF2C1810), // 明るいボタンなので黒文字
      'timerCircleColor': Color(0xFFFFF59D),
      'bottomNavigationColor': Color(0xFFFFF9C4),
      'inputBackgroundColor': Color(0xFFFFFEF0),
      'iconColor': Color(0xFFFFF176), // パステルイエロー
      'memberBackgroundColor': Color(0xFFFFF8E1),
      'appBarTextColor': Color(0xFF2C1810), // 明るい背景なので黒文字
      'bottomNavigationTextColor': Color(0xFF2C1810), // 明るい背景なので黒文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF2C1810), // 深いコーヒー色の文字
      'inputTextColor': Color(0xFF2C1810), // 深いコーヒー色の文字
      'borderColor': Color(0xFFFFF8E1), // 薄いイエローの境界線
      'bottomNavigationSelectedColor': Color(0xFFFFF176),
      'bottomNavigationUnselectedColor': Color(0xFF757575), // グレー（明るい背景に対して）
      'settingsColor': Color(0xFFF57F17), // ダークイエロー
      'calculatorColor': Color(0xFFFFF176), // 計算機機能のアクセント色
      'todoColor': Color(0xFFFFF176), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    'パープル': {
      'appBarColor': Color(0xFFE1BEE7), // 優しいパープル
      'backgroundColor': Color(0xFFFAF4FF), // 非常に薄いパープル
      'buttonColor': Color(0xFFCE93D8), // パステルパープル
      'cardBackgroundColor': Color(0xFFFFFFFF), // ←追加
      'fontColor1': Color(0xFF2C1810), // 深いコーヒー色の文字
      'fontColor2': Color(0xFFFFFFFF), // 白色でコントラスト確保
      'timerCircleColor': Color(0xFFCE93D8),
      'bottomNavigationColor': Color(0xFFE1BEE7),
      'inputBackgroundColor': Color(0xFFF7F1FF),
      'iconColor': Color(0xFFBA68C8), // パステルパープル
      'memberBackgroundColor': Color(0xFFF3E5F5),
      'appBarTextColor': Color(0xFF2C1810), // 明るい背景なので黒文字
      'bottomNavigationTextColor': Color(0xFF2C1810), // 明るい背景なので黒文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF2C1810), // 深いコーヒー色の文字
      'inputTextColor': Color(0xFF2C1810), // 深いコーヒー色の文字
      'borderColor': Color(0xFFF3E5F5), // 薄いパープルの境界線
      'bottomNavigationSelectedColor': Color(0xFFBA68C8),
      'bottomNavigationUnselectedColor': Color(0xFF757575), // グレー（明るい背景に対して）
      'settingsColor': Color(0xFF8E24AA), // ダークパープル
      'calculatorColor': Color(0xFFBA68C8), // 計算機機能のアクセント色
      'todoColor': Color(0xFFBA68C8), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
    },
    'ピーチ': {
      'appBarColor': Color(0xFFFFCCBC), // 優しいピーチ
      'backgroundColor': Color(0xFFFFF8F5), // 非常に薄いピーチ
      'buttonColor': Color(0xFFFFAB91), // パステルピーチ
      'cardBackgroundColor': Color(0xFFFFFFFF), // ←追加
      'fontColor1': Color(0xFF2C1810), // 深いコーヒー色の文字
      'fontColor2': Color(0xFFFFFFFF), // 白色でコントラスト確保
      'timerCircleColor': Color(0xFFFFAB91),
      'bottomNavigationColor': Color(0xFFFFCCBC),
      'inputBackgroundColor': Color(0xFFFFFCF8),
      'iconColor': Color(0xFFFF8A65), // パステルピーチ
      'memberBackgroundColor': Color(0xFFFFE0B2),
      'appBarTextColor': Color(0xFF2C1810), // 明るい背景なので黒文字
      'bottomNavigationTextColor': Color(0xFF2C1810), // 明るい背景なので黒文字
      'dialogBackgroundColor': Color(0xFFFFFFFF),
      'dialogTextColor': Color(0xFF2C1810), // 深いコーヒー色の文字
      'inputTextColor': Color(0xFF2C1810), // 深いコーヒー色の文字
      'borderColor': Color(0xFFFFE0B2), // 薄いピーチの境界線
      'bottomNavigationSelectedColor': Color(0xFFFF8A65),
      'bottomNavigationUnselectedColor': Color(0xFF757575), // グレー（明るい背景に対して）
      'settingsColor': Color(0xFFD84315), // ダークピーチ
      'calculatorColor': Color(0xFFFF8A65), // 計算機機能のアクセント色
      'todoColor': Color(0xFFFF8A65), // TODO機能のアクセント色
      'tastingColor': Color(0xFFD84315), // テイスティング機能のアクセント色
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

  // フォントの優先順位リスト（フォールバック用）
  static const List<String> fontFallbacks = [
    'Noto Sans JP',
    'ZenMaruGothic',
    'KiwiMaru',
    'HannariMincho',
    'Harenosora',
    'utsukushiFONT',
  ];

  // 遅延初期化用のフラグ
  static bool _isInitialized = false;
  static ThemeSettings? _instance;

  // シングルトンパターンで遅延初期化
  static Future<ThemeSettings> load() async {
    if (_isInitialized && _instance != null) {
      return _instance!;
    }

    try {
      // Firebase初期化の確認
      try {
        // Firebaseが初期化されているかチェック
        FirebaseFirestore.instance;
      } catch (e) {
        // Firebaseが初期化されていない場合は、デフォルトテーマのみで作成
        // Firebase初期化エラー - デフォルトテーマを使用
        final defaultTheme = presets['デフォルト']!;
        _instance = ThemeSettings(
          appBarColor: defaultTheme['appBarColor']!,
          backgroundColor: defaultTheme['backgroundColor']!,
          buttonColor: defaultTheme['buttonColor']!,
          appButtonColor: defaultTheme['appButtonColor']!,
          cardBackgroundColor: defaultTheme['cardBackgroundColor']!,
          fontColor1: defaultTheme['fontColor1']!,
          fontColor2: defaultTheme['fontColor2']!,
          iconColor: defaultTheme['iconColor']!,
          timerCircleColor: defaultTheme['timerCircleColor']!,
          bottomNavigationColor: defaultTheme['bottomNavigationColor']!,
          inputBackgroundColor: defaultTheme['inputBackgroundColor']!,
          memberBackgroundColor: defaultTheme['memberBackgroundColor']!,
          appBarTextColor: defaultTheme['appBarTextColor']!,
          bottomNavigationTextColor: defaultTheme['bottomNavigationTextColor']!,
          dialogBackgroundColor: defaultTheme['dialogBackgroundColor']!,
          dialogTextColor: defaultTheme['dialogTextColor']!,
          inputTextColor: defaultTheme['inputTextColor']!,
          fontSizeScale: 1.0,
          fontFamily: 'Noto Sans JP',
          borderColor: defaultTheme['borderColor']!,
          calculatorColor: defaultTheme['calculatorColor']!,
          settingsColor: defaultTheme['settingsColor']!,
          todoColor: defaultTheme['todoColor']!,
          tastingColor: defaultTheme['tastingColor']!,
        );
        _isInitialized = true;
        return _instance!;
      }

      // デフォルトテーマで即座にインスタンスを作成
      final defaultTheme = presets['デフォルト']!;
      _instance = ThemeSettings(
        appBarColor: defaultTheme['appBarColor']!,
        backgroundColor: defaultTheme['backgroundColor']!,
        buttonColor: defaultTheme['buttonColor']!,
        appButtonColor: defaultTheme['appButtonColor']!,
        cardBackgroundColor: defaultTheme['cardBackgroundColor']!,
        fontColor1: defaultTheme['fontColor1']!,
        fontColor2: defaultTheme['fontColor2']!,
        iconColor: defaultTheme['iconColor']!,
        timerCircleColor: defaultTheme['timerCircleColor']!,
        bottomNavigationColor: defaultTheme['bottomNavigationColor']!,
        inputBackgroundColor: defaultTheme['inputBackgroundColor']!,
        memberBackgroundColor: defaultTheme['memberBackgroundColor']!,
        appBarTextColor: defaultTheme['appBarTextColor']!,
        bottomNavigationTextColor: defaultTheme['bottomNavigationTextColor']!,
        dialogBackgroundColor: defaultTheme['dialogBackgroundColor']!,
        dialogTextColor: defaultTheme['dialogTextColor']!,
        inputTextColor: defaultTheme['inputTextColor']!,
        fontSizeScale: 1.0,
        fontFamily: 'Noto Sans JP',
        borderColor: defaultTheme['borderColor']!,
        calculatorColor: defaultTheme['calculatorColor']!,
        settingsColor: defaultTheme['settingsColor']!,
        todoColor: defaultTheme['todoColor']!,
        tastingColor: defaultTheme['tastingColor']!,
      );

      // バックグラウンドでFirebaseから設定を非同期取得
      _loadSettingsFromFirebaseAsync();

      _isInitialized = true;
      return _instance!;
    } catch (e) {
      // 初期化エラー - デフォルトテーマを使用
      // エラー時もデフォルトテーマで作成
      final defaultTheme = presets['デフォルト']!;
      _instance = ThemeSettings(
        appBarColor: defaultTheme['appBarColor']!,
        backgroundColor: defaultTheme['backgroundColor']!,
        buttonColor: defaultTheme['buttonColor']!,
        appButtonColor: defaultTheme['appButtonColor']!,
        cardBackgroundColor: defaultTheme['cardBackgroundColor']!,
        fontColor1: defaultTheme['fontColor1']!,
        fontColor2: defaultTheme['fontColor2']!,
        iconColor: defaultTheme['iconColor']!,
        timerCircleColor: defaultTheme['timerCircleColor']!,
        bottomNavigationColor: defaultTheme['bottomNavigationColor']!,
        inputBackgroundColor: defaultTheme['inputBackgroundColor']!,
        memberBackgroundColor: defaultTheme['memberBackgroundColor']!,
        appBarTextColor: defaultTheme['appBarTextColor']!,
        bottomNavigationTextColor: defaultTheme['bottomNavigationTextColor']!,
        dialogBackgroundColor: defaultTheme['dialogBackgroundColor']!,
        dialogTextColor: defaultTheme['dialogTextColor']!,
        inputTextColor: defaultTheme['inputTextColor']!,
        fontSizeScale: 1.0,
        fontFamily: 'Noto Sans JP',
        borderColor: defaultTheme['borderColor']!,
        calculatorColor: defaultTheme['calculatorColor']!,
        settingsColor: defaultTheme['settingsColor']!,
        todoColor: defaultTheme['todoColor']!,
        tastingColor: defaultTheme['tastingColor']!,
      );
      _isInitialized = true;
      return _instance!;
    }
  }

  // バックグラウンドでFirebaseから設定を非同期取得
  static Future<void> _loadSettingsFromFirebaseAsync() async {
    try {
      // Firebaseからテーマ設定を取得
      final settings = await UserSettingsFirestoreService.getMultipleSettings([
        'theme_appBarColor',
        'theme_backgroundColor',
        'theme_buttonColor',
        'theme_appButtonColor',
        'theme_cardBackgroundColor',
        'theme_fontColor1',
        'theme_fontColor2',
        'theme_iconColor',
        'theme_timerCircleColor',
        'theme_bottomNavigationColor',
        'theme_inputBackgroundColor',
        'theme_memberBackgroundColor',
        'theme_appBarTextColor',
        'theme_bottomNavigationTextColor',
        'theme_dialogBackgroundColor',
        'theme_dialogTextColor',
        'theme_inputTextColor',
        'theme_fontSizeScale',
        'theme_fontFamily',
        'theme_bottomNavigationSelectedColor',
        'theme_bottomNavigationUnselectedColor',
        'theme_settingsColor',
        'theme_todoColor',
        'theme_calculatorColor',
        'custom_themes',
      ]);

      // デフォルトテーマ
      final defaultTheme = presets['デフォルト']!;

      // 取得した設定を適用
      if (_instance != null) {
        _instance!.appBarColor = Color(
          settings['theme_appBarColor'] ??
              defaultTheme['appBarColor']!.toARGB32(),
        );
        _instance!.backgroundColor = Color(
          settings['theme_backgroundColor'] ??
              defaultTheme['backgroundColor']!.toARGB32(),
        );
        _instance!.buttonColor = Color(
          settings['theme_buttonColor'] ??
              defaultTheme['buttonColor']!.toARGB32(),
        );
        _instance!.appButtonColor = Color(
          settings['theme_appButtonColor'] ??
              defaultTheme['appButtonColor']!.toARGB32(),
        );
        _instance!.cardBackgroundColor = Color(
          settings['theme_cardBackgroundColor'] ??
              defaultTheme['cardBackgroundColor']!.toARGB32(),
        );
        _instance!.fontColor1 = Color(
          settings['theme_fontColor1'] ??
              defaultTheme['fontColor1']!.toARGB32(),
        );
        _instance!.fontColor2 = Color(
          settings['theme_fontColor2'] ??
              defaultTheme['fontColor2']!.toARGB32(),
        );
        _instance!.iconColor = Color(
          settings['theme_iconColor'] ?? defaultTheme['iconColor']!.toARGB32(),
        );
        _instance!.timerCircleColor = Color(
          settings['theme_timerCircleColor'] ??
              defaultTheme['timerCircleColor']!.toARGB32(),
        );
        _instance!.bottomNavigationColor = Color(
          settings['theme_bottomNavigationColor'] ??
              defaultTheme['bottomNavigationColor']!.toARGB32(),
        );
        _instance!.inputBackgroundColor = Color(
          settings['theme_inputBackgroundColor'] ??
              defaultTheme['inputBackgroundColor']!.toARGB32(),
        );
        _instance!.memberBackgroundColor = Color(
          settings['theme_memberBackgroundColor'] ??
              defaultTheme['memberBackgroundColor']!.toARGB32(),
        );
        _instance!.appBarTextColor = Color(
          settings['theme_appBarTextColor'] ??
              defaultTheme['appBarTextColor']!.toARGB32(),
        );
        _instance!.bottomNavigationTextColor = Color(
          settings['theme_bottomNavigationTextColor'] ??
              defaultTheme['bottomNavigationTextColor']!.toARGB32(),
        );
        _instance!.dialogBackgroundColor = Color(
          settings['theme_dialogBackgroundColor'] ??
              defaultTheme['dialogBackgroundColor']!.toARGB32(),
        );
        _instance!.dialogTextColor = Color(
          settings['theme_dialogTextColor'] ??
              defaultTheme['dialogTextColor']!.toARGB32(),
        );
        _instance!.inputTextColor = Color(
          settings['theme_inputTextColor'] ??
              defaultTheme['inputTextColor']!.toARGB32(),
        );
        _instance!.fontSizeScale = settings['theme_fontSizeScale'] ?? 1.0;
        _instance!.fontFamily = settings['theme_fontFamily'] ?? 'Noto Sans JP';
        _instance!.borderColor = Color(
          settings['theme_borderColor'] ??
              defaultTheme['borderColor']!.toARGB32(),
        );
        _instance!._bottomNavigationSelectedColor =
            settings['theme_bottomNavigationSelectedColor'] != null
            ? Color(settings['theme_bottomNavigationSelectedColor'])
            : defaultTheme['bottomNavigationSelectedColor'];
        _instance!._bottomNavigationUnselectedColor =
            settings['theme_bottomNavigationUnselectedColor'] != null
            ? Color(settings['theme_bottomNavigationUnselectedColor'])
            : defaultTheme['bottomNavigationUnselectedColor'];
        _instance!.customBottomNavigationSelectedColor = null;
        _instance!.customBottomNavigationUnselectedColor = null;
        _instance!.settingsColor = Color(
          settings['theme_settingsColor'] ??
              defaultTheme['settingsColor']!.toARGB32(),
        );
        _instance!.todoColor = Color(
          settings['theme_todoColor'] ?? defaultTheme['todoColor']!.toARGB32(),
        );
        _instance!.calculatorColor = Color(
          settings['theme_calculatorColor'] ??
              defaultTheme['calculatorColor']!.toARGB32(),
        );

        // 設定変更を通知
        _instance!.notifyListeners();
        // Firebaseから設定を非同期取得完了
      }
    } catch (e) {
      // Firebase設定取得エラー
    }
  }

  Future<void> save() async {
    // Firebaseに保存
    try {
      final themeData = {
        'appBarColor': appBarColor.toARGB32(),
        'backgroundColor': backgroundColor.toARGB32(),
        'buttonColor': buttonColor.toARGB32(),
        'appButtonColor': appButtonColor.toARGB32(),
        'cardBackgroundColor': cardBackgroundColor.toARGB32(),
        'fontColor1': fontColor1.toARGB32(),
        'fontColor2': fontColor2.toARGB32(),
        'iconColor': iconColor.toARGB32(),
        'timerCircleColor': timerCircleColor.toARGB32(),
        'bottomNavigationColor': bottomNavigationColor.toARGB32(),
        'inputBackgroundColor': inputBackgroundColor.toARGB32(),
        'memberBackgroundColor': memberBackgroundColor.toARGB32(),
        'appBarTextColor': appBarTextColor.toARGB32(),
        'bottomNavigationTextColor': bottomNavigationTextColor.toARGB32(),
        'dialogBackgroundColor': dialogBackgroundColor.toARGB32(),
        'dialogTextColor': dialogTextColor.toARGB32(),
        'inputTextColor': inputTextColor.toARGB32(),
        'borderColor': borderColor.toARGB32(),
        'bottomNavigationSelectedColor': bottomNavigationSelectedColor
            .toARGB32(),
        'bottomNavigationUnselectedColor': bottomNavigationUnselectedColor
            .toARGB32(),
        'settingsColor': settingsColor.toARGB32(),
        'fontSizeScale': fontSizeScale,
        'fontFamily': fontFamily,
        if (customBottomNavigationSelectedColor != null)
          'customBottomNavigationSelectedColor':
              customBottomNavigationSelectedColor!.toARGB32(),
        if (customBottomNavigationUnselectedColor != null)
          'customBottomNavigationUnselectedColor':
              customBottomNavigationUnselectedColor!.toARGB32(),
      };

      await UserSettingsFirestoreService.saveMultipleSettings({
        'theme_appBarColor': appBarColor.toARGB32(),
        'theme_backgroundColor': backgroundColor.toARGB32(),
        'theme_buttonColor': buttonColor.toARGB32(),
        'theme_appButtonColor': appButtonColor.toARGB32(),
        'theme_cardBackgroundColor': cardBackgroundColor.toARGB32(),
        'theme_fontColor1': fontColor1.toARGB32(),
        'theme_fontColor2': fontColor2.toARGB32(),
        'theme_iconColor': iconColor.toARGB32(),
        'theme_timerCircleColor': timerCircleColor.toARGB32(),
        'theme_bottomNavigationColor': bottomNavigationColor.toARGB32(),
        'theme_inputBackgroundColor': inputBackgroundColor.toARGB32(),
        'theme_memberBackgroundColor': memberBackgroundColor.toARGB32(),
        'theme_appBarTextColor': appBarTextColor.toARGB32(),
        'theme_bottomNavigationTextColor': bottomNavigationTextColor.toARGB32(),
        'theme_dialogBackgroundColor': dialogBackgroundColor.toARGB32(),
        'theme_dialogTextColor': dialogTextColor.toARGB32(),
        'theme_inputTextColor': inputTextColor.toARGB32(),
        'theme_bottomNavigationSelectedColor': bottomNavigationSelectedColor
            .toARGB32(),
        'theme_bottomNavigationUnselectedColor': bottomNavigationUnselectedColor
            .toARGB32(),
        'theme_settingsColor': settingsColor.toARGB32(),
        'theme_todoColor': todoColor.toARGB32(),
        'theme_calculatorColor': calculatorColor.toARGB32(),
        'theme_fontSizeScale': fontSizeScale,
        'theme_fontFamily': fontFamily,
        'custom_themes': themeData,
      });

      developer.log(
        'ThemeSettings: Firebaseにテーマ設定を保存しました',
        name: 'ThemeSettings',
      );
    } catch (e, st) {
      developer.log(
        'テーマ設定保存エラー',
        name: 'ThemeSettings',
        error: e,
        stackTrace: st,
      );
      rethrow;
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

  void updateCardBackgroundColor(Color color) {
    cardBackgroundColor = color;
    notifyListeners();
    save();
  }

  void updateButtonColor(Color color) {
    buttonColor = color;
    notifyListeners();
    save();
  }

  void updateAppButtonColor(Color color) {
    appButtonColor = color;
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
    // 設定アイコンの色も同時に更新
    settingsColor = color;
    notifyListeners();
    save();
  }

  void updateTodoColor(Color color) {
    todoColor = color;
    notifyListeners();
    save();
  }

  void updateCalculatorColor(Color color) {
    calculatorColor = color;
    notifyListeners();
    save();
  }

  void updateSettingsColor(Color color) {
    settingsColor = color;
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
    // フォントサイズはローカル保存のみ（Firestore保存をスキップ）
    _saveToLocalOnly();
  }

  void updateFontFamily(String family) {
    fontFamily = family;
    notifyListeners();
    // フォントファミリーはローカル保存のみ（Firestore保存をスキップ）
    _saveToLocalOnly();

    // WEB版でのフォント適用を確実にするため、少し遅延を入れる
    if (kIsWeb) {
      Future.delayed(Duration(milliseconds: 100), () {
        notifyListeners();
      });
    }
  }

  // ローカル保存のみのメソッド（Firestore保存をスキップ）
  void _saveToLocalOnly() async {
    try {
      await EncryptedLocalStorageService.setDouble(
        'fontSizeScale',
        fontSizeScale,
      );
      await EncryptedLocalStorageService.setString('fontFamily', fontFamily);
    } catch (e, st) {
      developer.log(
        'ローカル保存エラー',
        name: 'ThemeSettings',
        error: e,
        stackTrace: st,
      );
    }
  }

  void resetToDefault() {
    // デフォルトテーマのプリセットを適用
    final defaultTheme = presets['デフォルト']!;
    appBarColor = defaultTheme['appBarColor']!;
    backgroundColor = defaultTheme['backgroundColor']!;
    buttonColor = defaultTheme['buttonColor']!;
    appButtonColor = defaultTheme['buttonColor']!;
    cardBackgroundColor = defaultTheme['cardBackgroundColor']!;
    fontColor1 = defaultTheme['fontColor1']!;
    fontColor2 = defaultTheme['fontColor2']!;
    iconColor = defaultTheme['iconColor']!; // オレンジ色
    timerCircleColor = defaultTheme['timerCircleColor']!;
    bottomNavigationColor = defaultTheme['bottomNavigationColor']!;
    inputBackgroundColor = defaultTheme['inputBackgroundColor']!;
    memberBackgroundColor = defaultTheme['memberBackgroundColor']!;
    appBarTextColor = defaultTheme['appBarTextColor']!;
    bottomNavigationTextColor = defaultTheme['bottomNavigationTextColor']!;
    dialogBackgroundColor = defaultTheme['dialogBackgroundColor']!;
    dialogTextColor = defaultTheme['dialogTextColor']!;
    inputTextColor = defaultTheme['inputTextColor']!;
    borderColor = defaultTheme['borderColor']!;
    customBottomNavigationSelectedColor =
        defaultTheme['bottomNavigationSelectedColor']!;
    settingsColor = defaultTheme['iconColor']!; // アイコンの色と同じ値に設定
    todoColor = defaultTheme['iconColor']!; // ToDo色もアイコンの色と同じ値に設定
    calculatorColor = defaultTheme['iconColor']!; // アイコンの色と同じ値に設定
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
      appButtonColor = preset['appButtonColor'] ?? preset['buttonColor']!;
      cardBackgroundColor = preset['cardBackgroundColor']!;
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
      borderColor = preset['borderColor']!;
      // カスタム設定をクリアしてプリセットの値を使用
      customBottomNavigationSelectedColor = null;
      customBottomNavigationUnselectedColor = null;
      // プリセットの選択色と未選択色を設定
      _bottomNavigationSelectedColor = preset['bottomNavigationSelectedColor'];
      _bottomNavigationUnselectedColor =
          preset['bottomNavigationUnselectedColor'];
      settingsColor = preset['iconColor']!; // アイコンの色と同じ値に設定
      todoColor = preset['iconColor']!; // ToDo色もアイコンの色と同じ値に設定
      calculatorColor = preset['iconColor']!; // アイコンの色と同じ値に設定
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
    final customThemes = await getCustomThemes();
    customThemes[name] = themeData;

    final themeDataMap = customThemes.map(
      (key, value) =>
          MapEntry(key, value.map((k, v) => MapEntry(k, v.toARGB32()))),
    );
    await UserSettingsFirestoreService.saveSetting(
      'custom_themes',
      themeDataMap,
    );

    // クラウドにも保存
    try {
      await ThemeCloudService.saveCustomThemesToCloud(customThemes);
    } catch (e, st) {
      developer.log(
        'カスタムテーマのクラウド保存に失敗しました',
        name: 'ThemeSettings',
        error: e,
        stackTrace: st,
      );
    }
  }

  // カスタムテーマを取得
  static Future<Map<String, Map<String, Color>>> getCustomThemes() async {
    // クラウドからカスタムテーマを取得を試行
    Map<String, Map<String, Color>> cloudCustomThemes = {};
    try {
      cloudCustomThemes = await ThemeCloudService.getCustomThemesFromCloud();
    } catch (e, st) {
      developer.log(
        'クラウドからのカスタムテーマ取得に失敗しました',
        name: 'ThemeSettings',
        error: e,
        stackTrace: st,
      );
    }

    // クラウドのカスタムテーマがあれば使用、なければローカルの設定を使用
    if (cloudCustomThemes.isNotEmpty) {
      return cloudCustomThemes;
    }

    final customThemesData = await UserSettingsFirestoreService.getSetting(
      'custom_themes',
    );
    if (customThemesData == null) return {};

    try {
      return customThemesData.map(
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
    final customThemes = await getCustomThemes();
    customThemes.remove(name);

    final themeDataMap = customThemes.map(
      (key, value) =>
          MapEntry(key, value.map((k, v) => MapEntry(k, v.toARGB32()))),
    );
    await UserSettingsFirestoreService.saveSetting(
      'custom_themes',
      themeDataMap,
    );

    // クラウドからも削除
    try {
      await ThemeCloudService.saveCustomThemesToCloud(customThemes);
    } catch (e, st) {
      developer.log(
        'カスタムテーマのクラウド削除に失敗しました',
        name: 'ThemeSettings',
        error: e,
        stackTrace: st,
      );
    }
  }

  // カスタムテーマ名を変更
  static Future<void> renameCustomTheme(String oldName, String newName) async {
    final customThemes = await getCustomThemes();
    if (customThemes.containsKey(oldName)) {
      final themeData = customThemes[oldName];
      if (themeData != null) {
        await deleteCustomTheme(oldName);
        await saveCustomTheme(newName, themeData);
      }
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
      'appButtonColor': appButtonColor,
      'cardBackgroundColor': cardBackgroundColor,
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
      'borderColor': borderColor,
      'bottomNavigationSelectedColor': bottomNavigationSelectedColor,
      'settingsColor': settingsColor,
      if (customBottomNavigationSelectedColor != null)
        'customBottomNavigationSelectedColor':
            customBottomNavigationSelectedColor!,
      if (customBottomNavigationUnselectedColor != null)
        'customBottomNavigationUnselectedColor':
            customBottomNavigationUnselectedColor!,
    };

    final name = await getNextCustomThemeName();
    await saveCustomTheme(name, themeData);
  }

  // カスタムテーマを適用
  Future<void> applyCustomTheme(String name) async {
    final customThemes = await getCustomThemes();
    final themeData = customThemes[name];
    if (themeData != null) {
      appBarColor = themeData['appBarColor'] ?? Color(0xFF2C1810);
      backgroundColor = themeData['backgroundColor'] ?? Color(0xFFFFFBF5);
      buttonColor = themeData['buttonColor'] ?? Color(0xFF8D6E63);
      appButtonColor = themeData['buttonColor'] ?? Color(0xFF8D6E63);
      cardBackgroundColor =
          themeData['cardBackgroundColor'] ?? Color(0xFFFFFFFF);
      fontColor1 = themeData['fontColor1'] ?? Color(0xFF000000);
      fontColor2 = themeData['fontColor2'] ?? Color(0xFFFFFFFF);
      iconColor = themeData['iconColor'] ?? Color(0xFFE67E22);
      timerCircleColor = themeData['timerCircleColor'] ?? Color(0xFF8D6E63);
      bottomNavigationColor =
          themeData['bottomNavigationColor'] ?? Color(0xFF2C1810);
      inputBackgroundColor =
          themeData['inputBackgroundColor'] ?? Color(0xFFF7F3F0);
      memberBackgroundColor =
          themeData['memberBackgroundColor'] ?? Color(0xFFF1F8E9);
      appBarTextColor = themeData['appBarTextColor'] ?? Color(0xFFFFFFFF);
      bottomNavigationTextColor =
          themeData['bottomNavigationTextColor'] ?? Color(0xFFFFFFFF);
      dialogBackgroundColor =
          themeData['dialogBackgroundColor'] ?? Color(0xFFFFFFFF);
      dialogTextColor = themeData['dialogTextColor'] ?? Color(0xFF000000);
      inputTextColor = themeData['inputTextColor'] ?? Color(0xFF000000);
      borderColor = themeData['borderColor'] ?? Color(0xFFE0E0E0);
      customBottomNavigationSelectedColor =
          themeData['customBottomNavigationSelectedColor'] ??
          themeData['bottomNavigationSelectedColor'] ??
          themeData['buttonColor'] ??
          Color(0xFFE67E22); // デフォルトのオレンジ色
      customBottomNavigationUnselectedColor =
          themeData['customBottomNavigationUnselectedColor'] ??
          themeData['bottomNavigationTextColor'] ??
          Color(0xFF000000); // デフォルトの黒色
      settingsColor =
          themeData['settingsColor'] ??
          themeData['iconColor'] ??
          Color(0xFFE67E22); // アイコンの色と同じ値に設定
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
    if (_fontSettingsStream != null) {
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

  // フォントファミリーを動的に設定する関数
  static String getFontFamily(String fontFamily) {
    switch (fontFamily) {
      case 'Noto Sans JP':
        return 'Noto Sans JP';
      case 'ZenMaruGothic':
        return 'ZenMaruGothic';
      case 'utsukushiFONT':
        return 'utsukushiFONT';
      case 'KiwiMaru':
        return 'KiwiMaru';
      case 'HannariMincho':
        return 'HannariMincho';
      case 'Harenosora':
        return 'Harenosora';
      default:
        return 'Noto Sans JP';
    }
  }
}
