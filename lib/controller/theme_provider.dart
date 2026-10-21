import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:buildtrack_mobile/config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/design/bt_theme.dart';

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

  /// Built-in accent presets (Design V2). Identified by their colour, which is
  /// what `themePreference` already stores — no new storage or API.
  static const Map<BtPreset, Color> presetColors = BtTheme.presetColors;

  Color _currentColor = BtTheme.brass;
  Color get currentColor => _currentColor;

  BtPreset get preset {
    for (final e in presetColors.entries) {
      if (e.value.toARGB32() == _currentColor.toARGB32()) return e.key;
    }
    return BtPreset.custom;
  }

  /// Tokens for the active theme.
  BtTheme get btTheme => BtTheme.forPreset(preset, custom: _currentColor);

  ThemeProvider() {
    AppColors.primary = btTheme.brand;
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedColor = prefs.getInt(_themeKey);
    if (savedColor != null && (savedColor >> 24) != 0) {
      _currentColor = Color(savedColor);
      AppColors.primary = btTheme.brand;
      notifyListeners();
    }
  }

  Future<void> setPreset(BtPreset p) async {
    if (p == BtPreset.custom) return;
    await setTheme(presetColors[p]!);
  }

  Future<void> setTheme(Color color) async {
    _currentColor = color;
    AppColors.primary = btTheme.brand;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, color.toARGB32());

    notifyListeners();

    try {
      final token = prefs.getString('auth_token') ?? '';
      if (token.isNotEmpty) {
        final hexColor = '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
        await http.put(
          Uri.parse('${ApiConfig.baseUrl}/auth/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode({'themePreference': hexColor}),
        );
      }
    } catch (e) {
      debugPrint('Failed to sync theme to backend: $e');
    }
  }
}
