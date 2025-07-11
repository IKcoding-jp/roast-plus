import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeSettings extends ChangeNotifier {
  Color appBarColor;
  Color backgroundColor;
  Color buttonColor;
  Color backgroundColor2;

  ThemeSettings({
    required this.appBarColor,
    required this.backgroundColor,
    required this.buttonColor,
    required this.backgroundColor2,
  });

  static const _appBarKey = 'theme_appBarColor';
  static const _backgroundKey = 'theme_backgroundColor';
  static const _buttonKey = 'theme_buttonColor';
  static const _background2Key = 'theme_backgroundColor2';

  static Future<ThemeSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ThemeSettings(
      appBarColor: Color(prefs.getInt(_appBarKey) ?? 0xFF2C1D17),
      backgroundColor: Color(prefs.getInt(_backgroundKey) ?? 0xFFFFF8E1),
      buttonColor: Color(prefs.getInt(_buttonKey) ?? 0xFF795548),
      backgroundColor2: Color(prefs.getInt(_background2Key) ?? 0xFFFFFFFF),
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_appBarKey, appBarColor.value);
    await prefs.setInt(_backgroundKey, backgroundColor.value);
    await prefs.setInt(_buttonKey, buttonColor.value);
    await prefs.setInt(_background2Key, backgroundColor2.value);
  }

  void updateAppBarColor(Color color) {
    appBarColor = color;
    notifyListeners();
    save();
  }

  void updateBackgroundColor(Color color) {
    backgroundColor = color;
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

  void resetToDefault() {
    appBarColor = Color(0xFF2C1D17);
    backgroundColor = Color(0xFFFFF8E1);
    buttonColor = Color(0xFF795548);
    backgroundColor2 = Color(0xFFFFFFFF);
    notifyListeners();
    save();
  }
}
