import os

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content
    
    idx = 0
    while True:
        idx = content.find("DateTime.parse(", idx)
        if idx == -1:
            break
        open_count = 0
        i = idx + len("DateTime.parse(") - 1
        while i < len(content):
            if content[i] == '(':
                open_count += 1
            elif content[i] == ')':
                open_count -= 1
                if open_count == 0:
                    break
            i += 1
        
        if i < len(content):
            if not content[i+1:].startswith(".toLocal()"):
                content = content[:i+1] + ".toLocal()" + content[i+1:]
        
        idx = i + 1

    idx = 0
    while True:
        idx = content.find("DateTime.tryParse(", idx)
        if idx == -1:
            break
        open_count = 0
        i = idx + len("DateTime.tryParse(") - 1
        while i < len(content):
            if content[i] == '(':
                open_count += 1
            elif content[i] == ')':
                open_count -= 1
                if open_count == 0:
                    break
            i += 1
        
        if i < len(content):
            if not content[i+1:].startswith("?.toLocal()"):
                content = content[:i+1] + "?.toLocal()" + content[i+1:]
        
        idx = i + 1

    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print("Updated " + filepath)

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
