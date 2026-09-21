import os

path = r"c:\Users\Muneesha\Desktop\build-track\Build-Track-App\lib\controller\user_session.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

sync_code = """      _companyLogo = user['companyLogo']?.toString();
      _initialized = true;

      // Sync preferences from backend
      if (user['preferences'] != null) {
          try {
              final pref = user['preferences'] as Map<String, dynamic>;
              final prefs = await SharedPreferences.getInstance();
              for (final key in pref.keys) {
                 if (key.startsWith('activeColumns')) {
                    final list = List<String>.from(pref[key] as List);
                    await prefs.setStringList('${key}_$_userId', list);
                 }
              }
          } catch(e) {}
      }

      await _persist();"""

text = text.replace("      _companyLogo = user['companyLogo']?.toString();\n      _initialized = true;\n      await _persist();", sync_code)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done")
