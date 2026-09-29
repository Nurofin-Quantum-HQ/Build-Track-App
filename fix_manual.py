import re

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/profile/profile.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix ThemePicker injection error
content = content.replace(
'''              final keys = <GlobalKey>[
                ShowcaseKeys.profileFields,
                _settingsCardKey,
                ShowcaseKeys.profileSubscription,
const _ThemePicker(),
                          const SizedBox(height: 16),
                          if (RoleManager.canViewTeamAccess) _teamAccessKey,
                _logoutKey,
              ];''',
'''              final keys = <GlobalKey>[
                ShowcaseKeys.profileFields,
                _settingsCardKey,
                ShowcaseKeys.profileSubscription,
                if (RoleManager.canViewTeamAccess) _teamAccessKey,
                _logoutKey,
              ];'''
)

# And correctly inject _ThemePicker into the build method, right before Team Access settings tile
search = '''                      if (RoleManager.canViewTeamAccess)'''
replace = '''                      const _ThemePicker(),
                      const SizedBox(height: 16),
                      if (RoleManager.canViewTeamAccess)'''
content = content.replace(search, replace)

# Fix purple and purpleLight
content = content.replace('purple = AppColors.primaryPurple;', 'final purple = AppColors.primaryPurple;')
content = content.replace('purpleLight = AppColors.primaryLightBlue;', 'final purpleLight = AppColors.primaryLightBlue;')

# Fix 'cardTitle'
content = content.replace('AppTheme.cardTitle', 'const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)')

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/profile/profile.dart', 'w', encoding='utf-8') as f:
    f.write(content)

# Fix 'static primaryBlue = AppColors.primary;' -> 'static var primaryBlue = AppColors.primary;'
import os
for root, dirs, files in os.walk('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib'):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                c = f.read()
            c = c.replace('static primaryBlue =', 'static var primaryBlue =')
            c = c.replace('static purple =', 'static var purple =')
            
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(c)

print("Fixed Flutter manual errors")
