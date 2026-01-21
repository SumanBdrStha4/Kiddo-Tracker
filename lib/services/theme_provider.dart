import 'package:flutter/material.dart';
import 'package:kiddo_tracker/widget/shareperference.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    _isDarkMode = await SharedPreferenceHelper.getDarkMode() ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await SharedPreferenceHelper.setDarkMode(_isDarkMode);
    notifyListeners();
  }
}
