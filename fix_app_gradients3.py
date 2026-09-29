import re

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/common/themes/app_gradients.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace hardcoded mixed gradients
# primaryButton: [AppColors.primary, AppColors.primaryPurple, AppColors.primaryLightBlue] -> [AppColors.primary, AppColors.primary.withValues(alpha: 0.8), AppColors.primary.withValues(alpha: 0.6)]

content = content.replace(
    'colors: [\n      AppColors.primary,\n      AppColors.primaryPurple,\n      AppColors.primaryLightBlue,\n    ],',
    'colors: [\n      AppColors.primary,\n      AppColors.primary.withValues(alpha: 0.85),\n      AppColors.primary.withValues(alpha: 0.7),\n    ],'
)

content = content.replace(
    'colors: [\n      AppColors.primaryBlue,\n      AppColors.primaryPurple,\n      AppColors.primaryLightBlue,\n    ],',
    'colors: [\n      AppColors.primary,\n      AppColors.primary.withValues(alpha: 0.85),\n      AppColors.primary.withValues(alpha: 0.7),\n    ],'
)

content = content.replace(
    'colors: [AppColors.primary, AppColors.primaryPurple]',
    'colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)]'
)

content = content.replace(
    'colors: [AppColors.primaryBlue, AppColors.primaryPurple]',
    'colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)]'
)

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/common/themes/app_gradients.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed app_gradients mixed colors")
