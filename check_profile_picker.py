import re

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/profile/profile.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace color in the BoxShape.circle with a LinearGradient
search = '''                        decoration: BoxDecoration(
                          color: themeColor,
                          shape: BoxShape.circle,
                        ),'''
                        
# Wait, let me check the exact string of the BoxDecoration in profile.dart.
