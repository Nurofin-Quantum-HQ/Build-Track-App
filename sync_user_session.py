import re

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/controller/user_session.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add theme logic to fromLoginResponse
old_from_login = '''  static Future<void> fromLoginResponse(Map<String, dynamic> user) async {
    _userId = user['id']?.toString() ?? '';
    final rawRoleStr = user['role']?.toString() ?? '';'''

new_from_login = '''  static Future<void> fromLoginResponse(Map<String, dynamic> user) async {
    _userId = user['id']?.toString() ?? '';
    final rawRoleStr = user['role']?.toString() ?? '';
    
    // Sync themePreference from backend
    final themePref = user['themePreference']?.toString();
    if (themePref != null && themePref.isNotEmpty) {
      try {
        final hex = themePref.replaceAll('#', '');
        if (hex.length == 6) {
          final colorVal = int.parse('FF\', radix: 16);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('app_theme_color', colorVal);
          // Update global color for immediate effect before provider reloads
          AppColors.primary = Color(colorVal);
        }
      } catch (e) {
        debugPrint('Failed to parse themePreference: \');
      }
    }'''

content = content.replace(old_from_login, new_from_login)

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/controller/user_session.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated UserSession to sync theme")
