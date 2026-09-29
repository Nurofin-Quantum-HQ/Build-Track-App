import subprocess
import re
import os

def run_build():
    print("Running flutter build...")
    result = subprocess.run(['flutter.bat', 'build', 'apk', '--debug'], capture_output=True, text=True)
    return result.stdout + result.stderr, result.returncode

def fix_errors(log_text):
    fixes = {}
    lines = log_text.splitlines()
    for line in lines:
        if line.startswith('lib/') and ':' in line:
            parts = line.split(':')
            if len(parts) >= 3 and parts[1].isdigit():
                file_path = 'c:/Users/Muneesha/Desktop/build-track/Build-Track-App/' + parts[0]
                line_num = int(parts[1]) - 1
                if file_path not in fixes:
                    fixes[file_path] = set()
                fixes[file_path].add(line_num)
                
    count = 0
    for file_path, line_nums in fixes.items():
        if os.path.exists(file_path):
            with open(file_path, 'r', encoding='utf-8') as f:
                content_lines = f.readlines()
            
            for ln in line_nums:
                if ln < len(content_lines):
                    old_line = content_lines[ln]
                    content_lines[ln] = re.sub(r'\bconst\s+', '', content_lines[ln])
                    if old_line != content_lines[ln]:
                        count += 1
                    
            with open(file_path, 'w', encoding='utf-8') as f:
                f.writelines(content_lines)
    
    return count

max_iterations = 15
for i in range(max_iterations):
    log, code = run_build()
    if code == 0:
        print("Build succeeded!")
        break
    
    count = fix_errors(log)
    print(f"Iteration {i+1}: fixed {count} lines.")
    if count == 0:
        print("No lines fixed, but build failed. Stopping.")
        break

