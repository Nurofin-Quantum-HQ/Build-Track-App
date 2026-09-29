import re

# 1. Fix user_session.dart import
with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/controller/user_session.dart', 'r', encoding='utf-8') as f:
    content = f.read()

if "import 'package:buildtrack_mobile/common/themes/app_colors.dart';" not in content:
    content = content.replace("import 'package:shared_preferences/shared_preferences.dart';",
                              "import 'package:shared_preferences/shared_preferences.dart';\nimport 'package:buildtrack_mobile/common/themes/app_colors.dart';")
    with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/controller/user_session.dart', 'w', encoding='utf-8') as f:
        f.write(content)

# 2. Fix report.dart const errors
with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/reports/report.dart', 'r', encoding='utf-8') as f:
    r_content = f.read()

r_content = r_content.replace('style: const TextStyle(\n                fontSize: 12,\n                fontWeight: FontWeight.bold,\n                color: AppColors.primary,\n              ),',
                              'style: TextStyle(\n                fontSize: 12,\n                fontWeight: FontWeight.bold,\n                color: AppColors.primary,\n              ),')

r_content = r_content.replace('content = const Padding(\n            padding: EdgeInsets.symmetric(vertical: 20),\n            child: Center(\n              child: CircularProgressIndicator(\n                strokeWidth: 1.5,\n                valueColor: AlwaysStoppedAnimation<Color>(\n                  AppColors.primary,\n                ),\n              ),\n            ),\n          );',
                              'content = Padding(\n            padding: const EdgeInsets.symmetric(vertical: 20),\n            child: Center(\n              child: CircularProgressIndicator(\n                strokeWidth: 1.5,\n                valueColor: AlwaysStoppedAnimation<Color>(\n                  AppColors.primary,\n                ),\n              ),\n            ),\n          );')

r_content = r_content.replace('child: const Text(\n                                    \'View Entry\',\n                                    style: TextStyle(\n                                      fontSize: 10,\n                                      fontWeight: FontWeight.bold,\n                                      color: AppColors.primary,\n                                      decoration: TextDecoration.underline,\n                                    ),\n                                  ),',
                              'child: Text(\n                                    \'View Entry\',\n                                    style: TextStyle(\n                                      fontSize: 10,\n                                      fontWeight: FontWeight.bold,\n                                      color: AppColors.primary,\n                                      decoration: TextDecoration.underline,\n                                    ),\n                                  ),')

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/reports/report.dart', 'w', encoding='utf-8') as f:
    f.write(r_content)

print("Fixed compile errors")
