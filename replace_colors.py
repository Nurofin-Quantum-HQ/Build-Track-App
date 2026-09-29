import os
import re

files_to_check = [
    'c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/reports/ai_chat_report_screen.dart',
    'c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/inventory/project_report_screen.dart',
    'c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/projects/add_project.dart',
    'c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/projects/edit_project.dart'
]

for filepath in files_to_check:
    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            c = f.read()
            
        c = c.replace('Colors.blue', 'AppColors.primary')
        c = c.replace('Colors.orange', 'AppColors.primary')
        c = c.replace('Colors.purple', 'AppColors.primaryPurple')
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(c)

print("Replaced hardcoded colors in reports")
