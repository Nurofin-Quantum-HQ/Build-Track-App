import re

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/profile/profile.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix duplicate _ThemePicker
content = content.replace('''                      const _ThemePicker(),
                            const SizedBox(height: 16),
                          const _ThemePicker(),
                        const SizedBox(height: 16),''', '''                      const _ThemePicker(),
                        const SizedBox(height: 16),''')

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/profile/profile.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed duplicate _ThemePicker")
