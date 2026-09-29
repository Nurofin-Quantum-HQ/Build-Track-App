import re

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/common/themes/app_colors.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('static const Color primary = primaryBlue;', 'static Color primary = primaryBlue;')
content = content.replace('static const Color primaryLight = primaryLightBlue;', 'static Color primaryLight = primaryLightBlue;')

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/common/themes/app_colors.dart', 'w', encoding='utf-8') as f:
    f.write(content)

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/common/themes/app_theme.dart', 'r', encoding='utf-8') as f:
    content2 = f.read()
    
content2 = content2.replace('static const Color primary = AppColors.primaryBlue;', 'static Color primary = AppColors.primaryBlue;')
content2 = content2.replace('static const Color primaryLight = AppColors.primaryLightBlue;', 'static Color primaryLight = AppColors.primaryLightBlue;')
with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/common/themes/app_theme.dart', 'w', encoding='utf-8') as f:
    f.write(content2)

print("Modified AppColors")
