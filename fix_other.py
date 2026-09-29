import os
import re

files_to_patch = [
    'c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/common/widgets/entry_widgets.dart',
    'c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/common/widgets/common_widgets.dart',
    'c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/common/widgets/app_widgets.dart'
]

for filepath in files_to_patch:
    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            c = f.read()
        
        c = c.replace('_kBlue = AppColors.primary;', 'var _kBlue = AppColors.primary;')
        c = c.replace('static _primaryBlue = AppColors.primary;', 'static var _primaryBlue = AppColors.primary;')
        c = c.replace('this.color = AppTheme.secondary', 'this.color')
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(c)

print("Fixed other manual errors")
