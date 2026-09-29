import re

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/common/themes/app_theme.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Change static final ThemeData lightTheme = ThemeData(
# to static ThemeData get lightTheme => ThemeData(
content = content.replace('static final ThemeData lightTheme = ThemeData(', 'static ThemeData get lightTheme => ThemeData(')

# Change AppColors.primaryBlue to AppColors.primary
# Wait, I see:
#        seedColor: AppColors.primaryBlue,
#        primary: AppColors.primaryBlue,
content = content.replace('seedColor: AppColors.primaryBlue,', 'seedColor: AppColors.primary,')
content = content.replace('primary: AppColors.primaryBlue,', 'primary: AppColors.primary,')
content = content.replace('borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5),', 'borderSide: BorderSide(color: AppColors.primary, width: 1.5),')
content = content.replace('borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),', 'borderSide: BorderSide(color: AppColors.primary, width: 1.5),')

# Also wait! There is a ; at the end of lightTheme definition?
# Let's check how it ends. ); should stay the same since it's => ThemeData(...)

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/common/themes/app_theme.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed app_theme getter")
