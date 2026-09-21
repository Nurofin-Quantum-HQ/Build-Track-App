import os

path = r"c:\Users\Muneesha\Desktop\build-track\Build-Track-App\lib\screen\reports\report.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

sync_helper = """  Future<void> _syncPreferences(String key, List<String> cols) async {
    try {
      await ApiService.put('/users/profile', {
        'preferences': {
          key: cols,
        }
      });
    } catch(e) {}
  }

  Future<void> _setActiveColumnsForTab(String tabName, List<String> cols) async {"""

text = text.replace("  Future<void> _setActiveColumnsForTab(String tabName, List<String> cols) async {", sync_helper)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done")
