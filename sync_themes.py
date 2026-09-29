import re

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/controller/theme_provider.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace availableThemes list
old_themes = '''  final List<Map<String, dynamic>> availableThemes = [
    {'name': 'Orange', 'color': const Color(0xFFF97316)},
    {'name': 'Blue', 'color': const Color(0xFF173EEA)},
    {'name': 'Purple', 'color': const Color(0xFFB137FF)},
    {'name': 'Green', 'color': const Color(0xFF10B981)},
    {'name': 'Rose', 'color': const Color(0xFFE11D48)},
  ];'''

new_themes = '''  final List<Map<String, dynamic>> availableThemes = [
    {'name': 'Orange', 'color': const Color(0xFFF97316)},
    {'name': 'Blue', 'color': const Color(0xFF3B82F6)},
    {'name': 'Green', 'color': const Color(0xFF10B981)},
    {'name': 'Purple', 'color': const Color(0xFF8B5CF6)},
    {'name': 'Rose', 'color': const Color(0xFFF43F5E)},
    {'name': 'Slate', 'color': const Color(0xFF64748B)},
  ];'''

if old_themes in content:
    content = content.replace(old_themes, new_themes)
else:
    # Fallback if whitespace differs
    content = re.sub(r'final List<Map<String, dynamic>> availableThemes = \[.*?\];', new_themes, content, flags=re.DOTALL)

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/controller/theme_provider.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated theme_provider colors")
