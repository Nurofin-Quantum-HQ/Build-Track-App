import re

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/common/themes/app_gradients.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the syntax: static LinearGradient get name = LinearGradient( -> static LinearGradient get name => LinearGradient(
content = re.sub(r'static LinearGradient get (\w+)\s*=\s*LinearGradient', r'static LinearGradient get \1 => LinearGradient', content)

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/common/themes/app_gradients.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed app_gradients syntax")
