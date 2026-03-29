#!/usr/bin/env python3
"""
Verifica e corrige métodos que usam `r.` sem ter `final r = context.r;` definido.

Lógica:
- Para cada arquivo, parseia os métodos/funções
- Se um método usa `r.s(`, `r.fs(`, `r.w(`, `r.h(` mas NÃO tem `final r = context.r;`
  e NÃO é o build() method (que já tem), adiciona `final r = context.r;` no início
- Para métodos que não recebem BuildContext, verifica se estão dentro de um State
  (que tem `context` disponível)
"""
import re
import glob
import os

FRONTEND_LIB = '/home/ubuntu/NexusHub/frontend/lib'

EXCLUDE = {'responsive.dart', 'app_theme.dart', 'app_config.dart', 'main.dart', 'app_router.dart'}

total_fixes = 0

for filepath in sorted(glob.glob(os.path.join(FRONTEND_LIB, '**', '*.dart'), recursive=True)):
    if os.path.basename(filepath) in EXCLUDE:
        continue
    
    with open(filepath, 'r') as f:
        content = f.read()
    
    if 'r.s(' not in content and 'r.fs(' not in content and 'r.w(' not in content and 'r.h(' not in content:
        continue
    
    lines = content.split('\n')
    new_lines = []
    in_method = False
    method_start = -1
    method_has_r = False
    method_uses_r = False
    method_is_build = False
    brace_depth = 0
    method_indent = ''
    fixes_in_file = 0
    
    # Simple approach: find Widget-returning methods and _build* methods
    # that use r. but don't define it
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        
        # Detect method start: Widget _buildSomething(...) { or similar
        method_match = re.match(
            r'^(\s*)(Widget\s+\w+|void\s+\w+|[A-Z]\w*\s+\w+)\s*\([^)]*\)\s*\{?\s*$',
            line
        )
        if not method_match and re.match(r'^(\s*)(Widget\s+\w+|void\s+\w+)\s*\(', line):
            # Multi-line method signature
            method_match = re.match(r'^(\s*)', line)
        
        # Check for build method (already handled)
        if 'Widget build(BuildContext context)' in line:
            new_lines.append(line)
            i += 1
            continue
        
        # For _build* helper methods in State classes, add r if needed
        if re.match(r'\s*Widget\s+_build\w+\s*\(', line) or \
           re.match(r'\s*Widget\s+_\w+\s*\(\s*\)\s*\{', line):
            # Collect the entire method to check if it uses r.
            indent_match = re.match(r'^(\s*)', line)
            indent = indent_match.group(1) if indent_match else '  '
            
            # Look ahead to see if this method uses r. and doesn't define it
            j = i + 1
            depth = line.count('{') - line.count('}')
            uses_r = False
            has_r = False
            method_lines = [line]
            
            while j < len(lines) and depth > 0:
                mline = lines[j]
                depth += mline.count('{') - mline.count('}')
                if 'final r = context.r;' in mline:
                    has_r = True
                if re.search(r'\br\.(s|fs|w|h)\(', mline):
                    uses_r = True
                method_lines.append(mline)
                j += 1
            
            if uses_r and not has_r:
                # Add `final r = context.r;` after the opening brace
                new_lines.append(line)
                # Find where the opening brace is
                if '{' in line:
                    new_lines.append(f'{indent}    final r = context.r;')
                    fixes_in_file += 1
                else:
                    # Opening brace might be on next line
                    i += 1
                    new_lines.append(lines[i])
                    if '{' in lines[i]:
                        new_lines.append(f'{indent}    final r = context.r;')
                        fixes_in_file += 1
                i += 1
                continue
        
        new_lines.append(line)
        i += 1
    
    if fixes_in_file > 0:
        total_fixes += fixes_in_file
        content = '\n'.join(new_lines)
        with open(filepath, 'w') as f:
            f.write(content)
        print(f'  [{fixes_in_file}] {os.path.relpath(filepath, FRONTEND_LIB)}')

print(f'\n✅ {total_fixes} métodos helper corrigidos')
