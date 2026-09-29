import re

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/profile/profile.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove duplicate _ThemePicker occurrences
# Find all occurrences of "const _ThemePicker()," and only keep the first one in the list.
# Actually, the tree structure is:
# const SizedBox(height: AppTheme.spacingLg),
# const _ThemePicker(),
# const SizedBox(height: 16),
# const _ThemePicker(),

content = re.sub(r'const _ThemePicker\(\),\s*const SizedBox\(height: 16\),\s*const _ThemePicker\(\),', r'const _ThemePicker(),', content)

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/profile/profile.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed duplicate _ThemePicker for real")
