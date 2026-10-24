import 'package:flutter/material.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:buildtrack_mobile/services/auth_service.dart';
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

  /// Re-read the saved theme. Call after login (the account's
  /// `themePreference` is written to prefs by UserSession) and after logout
  /// (prefs cleared → back to the default), so a user never keeps the
  /// previous account's colour.
  Future<void> reload() async {
    final prefs = await SharedPreferences.getInstance();
    final savedColor = prefs.getInt(_themeKey);
    _currentColor = (savedColor != null && (savedColor >> 24) != 0) ? Color(savedColor) : BtTheme.brass;
    AppColors.primary = btTheme.brand;
    notifyListeners();
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
      // Save to the account (PUT /auth/profile → themePreference) so it
      // follows the user to other devices and survives logout. (Before: read
      // a never-written 'auth_token' pref, so nothing was ever sent.)
      if (await AuthService.isLoggedIn()) {
        final hexColor = '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
        final res = await ApiService.put('/auth/profile', {'themePreference': hexColor});
        if (res.statusCode != 200) {
          debugPrint('Theme sync failed: ${res.statusCode} ${res.body}');
        }
      }
    } catch (e) {
      debugPrint('Failed to sync theme to backend: $e');
    }
  }
}
