import re

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/controller/theme_provider.dart', 'r', encoding='utf-8') as f:
    content = f.read()

bad_set_theme = r"  Future<void> setTheme\(Color color\) async \{.*?catch \(e\) \{\n      debugPrint\('Failed to sync theme to backend: .*?;\n    \}\n  \}"
new_set_theme = '''  Future<void> setTheme(Color color) async {
    _currentColor = color;
    AppColors.primary = color;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, color.value);
    
    notifyListeners();

    try {
      final token = prefs.getString('auth_token') ?? '';
      if (token.isNotEmpty) {
        final hexColor = '#\';
        await http.put(
          Uri.parse('\/auth/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer \',
          },
          body: json.encode({'themePreference': hexColor}),
        );
      }
    } catch (e) {
      debugPrint('Failed to sync theme to backend: \');
    }
  }'''

content = re.sub(bad_set_theme, new_set_theme, content, flags=re.DOTALL)

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/controller/theme_provider.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed ThemeProvider dart syntax")
