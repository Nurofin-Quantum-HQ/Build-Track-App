import re

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/profile/profile.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the duplicate _ThemePicker in keys array
keys_regex = r'final keys = <GlobalKey>\[.*?\];'
correct_keys = '''final keys = <GlobalKey>[
                ShowcaseKeys.profileFields,
                _settingsCardKey,
                ShowcaseKeys.profileSubscription,
                if (RoleManager.canViewTeamAccess) _teamAccessKey,
                _logoutKey,
              ];'''

content = re.sub(keys_regex, correct_keys, content, flags=re.DOTALL)

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/profile/profile.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed profile keys")
