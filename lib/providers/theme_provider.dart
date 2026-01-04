import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_theme.dart';

class ThemeProvider with ChangeNotifier {
  AppTheme _currentAppTheme;
  String _appFontFamily;

  // Constructor with optional initial values
  ThemeProvider({AppTheme? initialTheme, String? initialFontFamily})
    : _currentAppTheme = initialTheme ?? AppTheme.oledBlack,
      _appFontFamily = initialFontFamily ?? 'Nothing Font';

  AppTheme get currentAppTheme => _currentAppTheme;
  String get appFontFamily => _appFontFamily;

  ThemeData get currentTheme {
    final baseTheme = _currentAppTheme.toThemeData();
    return baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: _appFontFamily),
    );
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString('theme') ?? 'OLED Black';
    _appFontFamily = prefs.getString('appFontFamily') ?? 'Nothing Font';

    _currentAppTheme = AppTheme.allThemes.firstWhere(
      (theme) => theme.name == themeName,
      orElse: () => AppTheme.oledBlack,
    );
    notifyListeners();
  }

  Future<void> setTheme(AppTheme theme) async {
    _currentAppTheme = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', theme.name);
    notifyListeners();
  }

  Future<void> setAppFontFamily(String fontFamily) async {
    _appFontFamily = fontFamily;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appFontFamily', fontFamily);
    notifyListeners();
  }
}
