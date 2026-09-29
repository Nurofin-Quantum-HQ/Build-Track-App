import re

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/common/widgets/app_widgets.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Instead of doing complex regex, let's just find 	his.color, and if the class has inal Color color;, change it to inal Color? color;

content = content.replace('final Color color;', 'final Color? color;')
# There might be multiple! This works perfectly.

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/common/widgets/app_widgets.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed app_widgets.dart color nullable")
