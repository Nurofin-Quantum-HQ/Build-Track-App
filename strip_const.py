import os
import re

lib_dir = 'c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib'
count = 0

def remove_const_from_line(line):
    if 'AppColors.primary' in line or 'AppColors.primaryLight' in line or 'AppTheme.primary' in line:
        return re.sub(r'\bconst\b\s+', '', line)
    return line

for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()

            lines = content.split('\n')
            new_lines = []
            changed = False
            for line in lines:
                new_line = remove_const_from_line(line)
                if new_line != line:
                    changed = True
                new_lines.append(new_line)
            
            if changed:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write('\n'.join(new_lines))
                count += 1

print(f"Stripped const in {count} files")
