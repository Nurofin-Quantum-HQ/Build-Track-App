import re

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/profile/profile.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the color with gradient
search = "color: theme['color'],"
replace = '''gradient: LinearGradient(
                              colors: [
                                theme['color'] as Color,
                                (theme['color'] as Color).withValues(alpha: 0.6),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),'''

content = content.replace(search, replace)

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/profile/profile.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed theme picker gradients")
