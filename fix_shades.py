import os
import re

files_to_check = [
    'c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/reports/ai_chat_report_screen.dart',
    'c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/inventory/project_report_screen.dart',
    'c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/projects/add_project.dart',
    'c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/projects/edit_project.dart',
    'c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/dashboard/homescreen.dart',
    'c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/inventory/fulfillment_payment_screen.dart'
]

for filepath in files_to_check:
    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            c = f.read()
            
        # Replace .shade50 with .withValues(alpha: 0.1)
        c = c.replace('.shade50', '.withValues(alpha: 0.1)')
        
        # Replace .shade100 with .withValues(alpha: 0.2)
        c = c.replace('.shade100', '.withValues(alpha: 0.2)')
        
        # Replace .shade200 with .withValues(alpha: 0.3)
        c = c.replace('.shade200', '.withValues(alpha: 0.3)')
        
        # Replace .shade600 with .withValues(alpha: 0.8)
        c = c.replace('.shade600', '.withValues(alpha: 0.8)')
        
        # Replace .shade900 with .withValues(alpha: 0.95)
        c = c.replace('.shade900', '.withValues(alpha: 0.95)')
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(c)

print("Fixed shade errors")
