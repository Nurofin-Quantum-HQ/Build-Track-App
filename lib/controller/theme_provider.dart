import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:buildtrack_mobile/config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme_color';
  
  // Available theme colors mirroring the web portal
  final List<Map<String, dynamic>> availableThemes = [
    {'name': 'Orange', 'color': const Color(0xFFF97316)},
    {'name': 'Blue', 'color': const Color(0xFF3B82F6)},
    {'name': 'Green', 'color': const Color(0xFF10B981)},
    {'name': 'Purple', 'color': const Color(0xFF8B5CF6)},
    {'name': 'Rose', 'color': const Color(0xFFF43F5E)},
    {'name': 'Slate', 'color': const Color(0xFF64748B)},
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

    try {
      final token = prefs.getString('auth_token') ?? '';
      if (token.isNotEmpty) {
        final hexColor = '#' + (color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
        await http.put(
          Uri.parse(ApiConfig.baseUrl + '/auth/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ' + token,
          },
          body: json.encode({'themePreference': hexColor}),
        );
      }
    } catch (e) {
      debugPrint('Failed to sync theme to backend: ' + e.toString());
    }
  }
}
