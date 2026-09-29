import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme_color';
  
  // Available theme colors mirroring the web portal
  final List<Map<String, dynamic>> availableThemes = [
    {'name': 'Orange', 'color': const Color(0xFFF97316)},
    {'name': 'Blue', 'color': const Color(0xFF173EEA)},
    {'name': 'Purple', 'color': const Color(0xFFB137FF)},
    {'name': 'Green', 'color': const Color(0xFF10B981)},
    {'name': 'Rose', 'color': const Color(0xFFE11D48)},
  ];

  Color _currentColor = AppColors.primaryBlue;
  Color get currentColor => _currentColor;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedColor = prefs.getInt(_themeKey);
    if (savedColor != null) {
      _currentColor = Color(savedColor);
      AppColors.primary = _currentColor;
      notifyListeners();
    }
  }

  Future<void> setTheme(Color color) async {
    _currentColor = color;
    AppColors.primary = color;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, color.value);
    
    notifyListeners();
  }
}
