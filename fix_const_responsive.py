#!/usr/bin/env python3
"""Remove 'const' de expressões que agora contêm r.s(), r.fs(), r.w(), r.h()."""
import re
import glob
import os

FRONTEND_LIB = '/home/ubuntu/NexusHub/frontend/lib'
count = 0

for filepath in glob.glob(os.path.join(FRONTEND_LIB, '**', '*.dart'), recursive=True):
    with open(filepath, 'r') as f:
        content = f.read()
    
    original = content
    
    # Remove 'const' before any expression that contains r.s, r.fs, r.w, r.h
    # Pattern: const <Something>(... r.s|r.fs|r.w|r.h ...)
    # We need to be careful - const can be before constructors, lists, etc.
    
    # Strategy: find lines with 'const' and 'r.' on the same line or nearby
    lines = content.split('\n')
    new_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        # Check if line has const and r. pattern
        if 'const ' in line and re.search(r'\br\.(s|fs|w|h)\(', line):
            # Remove const from this line
            new_line = re.sub(r'\bconst\s+(?=[A-Z\[])', '', line)
            # Also handle: const TextStyle, const EdgeInsets, const SizedBox, etc.
            new_line = re.sub(r'\bconst\s+(?=TextStyle|EdgeInsets|SizedBox|Icon\(|Padding|BoxConstraints|ShimmerBox|ShimmerCircle|AminoShimmer|Text\()', '', new_line)
            if new_line != line:
                count += 1
            new_lines.append(new_line)
        else:
            new_lines.append(line)
        i += 1
    
    content = '\n'.join(new_lines)
    
    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)

print(f'✅ Removidos {count} const inválidos')
