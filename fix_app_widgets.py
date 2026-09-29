import re

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/common/widgets/app_widgets.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('this.color = AppTheme.secondary,', 'this.color,')
content = content.replace('this.color = AppTheme.surface,', 'this.color,')

# Now we need to set color to AppTheme.secondary if null in the build method.
# It's better to just remove 'const' from the constructor!
content = content.replace('const CustomCard({', 'CustomCard({')
# Wait, let's just make it 	his.color and then use color ?? AppTheme.secondary where it's used.

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/common/widgets/app_widgets.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed app_widgets.dart")
