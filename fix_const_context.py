#!/usr/bin/env python3
"""Remove 'const' de expressões que contêm context. (não são const-eligible)."""
import re
import glob
import os

FRONTEND_LIB = '/home/ubuntu/NexusHub/frontend/lib'
count = 0

for filepath in sorted(glob.glob(os.path.join(FRONTEND_LIB, '**', '*.dart'), recursive=True)):
    with open(filepath, 'r') as f:
        content = f.read()
    
    original = content
    
    # Remove const before Text( when the same line or nearby has context.
    lines = content.split('\n')
    new_lines = []
    for i, line in enumerate(lines):
        if 'const Text(' in line and 'context.' in line:
            line = line.replace('const Text(', 'Text(', 1)
            count += 1
        elif 'const TextStyle(' in line and 'context.' in line:
            line = line.replace('const TextStyle(', 'TextStyle(', 1)
            count += 1
        new_lines.append(line)
    
    content = '\n'.join(new_lines)
    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)

print(f'✅ Removidos {count} const inválidos com context.')
