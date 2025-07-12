import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'dart:convert';

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
  });

  // 背景色の明度を計算するメソッド
  static double _calculateLuminance(Color color) {
    return color.computeLuminance();
  }

  // 背景色に応じて適切なアイコン色を決定するメソッド
  static Color _getContrastingIconColor(Color backgroundColor) {
    final luminance = _calculateLuminance(backgroundColor);
    // 背景が明るい場合は黒、暗い場合は白
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  // プリセットテーマの定義（アイコン色は薄い色で設定）
  static const Map<String, Map<String, Color>> presets = {
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
      'iconColor': Color(0xFF9E9E9E),
      'memberBackgroundColor': Color(0xFFC8E6C9),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFBDBDBD),
    },
    'ダーク': {
      'appBarColor': Color(0xFF1A1A1A),
      'backgroundColor': Color(0xFF121212),
      'buttonColor': Color(0xFF000000),
      'backgroundColor2': Color(0xFF1E1E1E),
      'fontColor1': Color(0xFFFFFFFF),
      'fontColor2': Color(0xFFFFFFFF),
      'timerCircleColor': Color(0xFF424242),
      'bottomNavigationColor': Color(0xFF1A1A1A),
      'inputBackgroundColor': Color(0xFF2A2A2A),
      'iconColor': Color(0xFF757575),
      'memberBackgroundColor': Color(0xFFFFFFFF),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFF9E9E9E),
    },
    'ライト': {
      'appBarColor': Color(0xFFF5F5F5),
      'backgroundColor': Color(0xFFFFFFFF),
      'buttonColor': Color(0xFFFFFFFF),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000),
      'fontColor2': Color(0xFF000000),
      'timerCircleColor': Color(0xFF000000),
      'bottomNavigationColor': Color(0xFFF5F5F5),
      'inputBackgroundColor': Color(0xFFF5F5F5),
      'iconColor': Color(0xFF424242),
      'memberBackgroundColor': Color(0xFFF0F0F0),
      'appBarTextColor': Color(0xFF000000),
      'bottomNavigationTextColor': Color(0xFF666666),
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
      'iconColor': Color(0xFFBDBDBD),
      'memberBackgroundColor': Color(0xFFE0E0E0),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFE0E0E0),
    },
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
      'iconColor': Color(0xFFBCAAA4),
      'memberBackgroundColor': Color(0xFFD7CCC8),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFD7CCC8),
    },
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
      'iconColor': Color(0xFFEF9A9A),
      'memberBackgroundColor': Color(0xFFFFCDD2),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFFFCDD2),
    },
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
      'iconColor': Color(0xFFFFB74D),
      'memberBackgroundColor': Color(0xFFFFCC80),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFFFCC80),
    },
    'ディープオレンジ': {
      'appBarColor': Color(0xFFBF360C),
      'backgroundColor': Color(0xFFFBE9E7),
      'buttonColor': Color(0xFFFF5722),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000),
      'fontColor2': Color(0xFFFFFFFF),
      'timerCircleColor': Color(0xFFFF5722),
      'bottomNavigationColor': Color(0xFFBF360C),
      'inputBackgroundColor': Color(0xFFFFF5F0),
      'iconColor': Color(0xFFFF8A65),
      'memberBackgroundColor': Color(0xFFFFAB91),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFFFAB91),
    },
    'アンバー': {
      'appBarColor': Color(0xFFF57F17),
      'backgroundColor': Color(0xFFFFF8E1),
      'buttonColor': Color(0xFFFFC107),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000),
      'fontColor2': Color(0xFF000000),
      'timerCircleColor': Color(0xFFFFC107),
      'bottomNavigationColor': Color(0xFFF57F17),
      'inputBackgroundColor': Color(0xFFFFFDF0),
      'iconColor': Color(0xFFFFD54F),
      'memberBackgroundColor': Color(0xFFFFE082),
      'appBarTextColor': Color(0xFF000000),
      'bottomNavigationTextColor': Color(0xFFFFE082),
    },
    'ライム': {
      'appBarColor': Color(0xFF827717),
      'backgroundColor': Color(0xFFF9FBE7),
      'buttonColor': Color(0xFFCDDC39),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000),
      'fontColor2': Color(0xFF000000),
      'timerCircleColor': Color(0xFFCDDC39),
      'bottomNavigationColor': Color(0xFF827717),
      'inputBackgroundColor': Color(0xFFFDFFF0),
      'iconColor': Color(0xFFCDDC39),
      'memberBackgroundColor': Color(0xFFDCE775),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFDCE775),
    },
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
      'iconColor': Color(0xFF81C784),
      'memberBackgroundColor': Color(0xFFC8E6C9),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFA5D6A7),
    },
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
      'iconColor': Color(0xFF80CBC4),
      'memberBackgroundColor': Color(0xFFB2DFDB),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFB2DFDB),
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
      'iconColor': Color(0xFF64B5F6),
      'memberBackgroundColor': Color(0xFFBBDEFB),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFF90CAF9),
    },
    'インディゴ': {
      'appBarColor': Color(0xFF283593),
      'backgroundColor': Color(0xFFE8EAF6),
      'buttonColor': Color(0xFF3F51B5),
      'backgroundColor2': Color(0xFFFFFFFF),
      'fontColor1': Color(0xFF000000),
      'fontColor2': Color(0xFFFFFFFF),
      'timerCircleColor': Color(0xFF3F51B5),
      'bottomNavigationColor': Color(0xFF283593),
      'inputBackgroundColor': Color(0xFFF0F0FF),
      'iconColor': Color(0xFF9FA8DA),
      'memberBackgroundColor': Color(0xFFC5CAE9),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFC5CAE9),
    },
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
      'iconColor': Color(0xFFCE93D8),
      'memberBackgroundColor': Color(0xFFE1BEE7),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFE1BEE7),
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
      'iconColor': Color(0xFFF48FB1),
      'memberBackgroundColor': Color(0xFFF8BBD9),
      'appBarTextColor': Color(0xFFFFFFFF),
      'bottomNavigationTextColor': Color(0xFFF8BBD9),
    },
  };

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

  static Future<ThemeSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
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
    );
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

  void resetToDefault() {
    appBarColor = Color(0xFF2C1D17);
    backgroundColor = Color(0xFFFFF8E1);
    buttonColor = Color(0xFF795548);
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
  }

  // カスタムテーマを取得
  static Future<Map<String, Map<String, Color>>> getCustomThemes() async {
    final prefs = await SharedPreferences.getInstance();
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

      notifyListeners();
      save();
    }
  }
}
