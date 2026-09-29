import re

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/reports/report.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix content = const Padding( ... AppColors.primary
content = re.sub(r'content = const Padding\(', 'content = Padding(', content)
content = re.sub(r'child: const Text\(\s*\'View Entry\'', 'child: Text(\n                                    \\'View Entry\\'', content)

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/reports/report.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed const errors robustly")
