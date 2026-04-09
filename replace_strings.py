#!/usr/bin/env python3
"""
Replace all hardcoded Portuguese/English strings in Dart files with
localized references using stringsProvider (s.keyName).

This script:
1. Reads each Dart file
2. Detects if it's a ConsumerWidget/ConsumerStatefulWidget or StatelessWidget/StatefulWidget
3. Adds the import for locale_provider if missing
4. Converts StatelessWidget -> ConsumerWidget, StatefulWidget -> ConsumerStatefulWidget if needed
5. Adds `final s = ref.watch(stringsProvider);` in the build method
6. Replaces hardcoded strings with s.keyName references
"""

import json
import re
import os

# Load the mapping
with open('/home/ubuntu/NexusHub/i18n_mapping.json', 'r') as f:
    data = json.load(f)

keys_map = data['keys_map']
file_strings = data['file_strings']

LOCALE_IMPORT = "import '../../core/l10n/locale_provider.dart';"
# For files in core/widgets, the import path is different
LOCALE_IMPORT_CORE = "import '../l10n/locale_provider.dart';"

def get_locale_import(filepath):
    """Determine the correct relative import path based on file location."""
    if '/core/widgets/' in filepath:
        return LOCALE_IMPORT_CORE
    # Count depth from lib/
    rel = filepath.split('/frontend/lib/')[-1]
    parts = rel.split('/')
    depth = len(parts) - 1  # number of directories
    prefix = '../' * depth
    return f"import '{prefix}core/l10n/locale_provider.dart';"


def needs_conversion(content):
    """Check if file uses StatelessWidget/StatefulWidget (needs conversion to Consumer*)."""
    has_consumer = bool(re.search(r'extends\s+Consumer(Stateful)?Widget', content))
    has_plain = bool(re.search(r'extends\s+Stateless(?!Consumer)Widget|extends\s+Stateful(?!Consumer)Widget', content))
    return has_plain and not has_consumer


def has_riverpod_import(content):
    """Check if flutter_riverpod is already imported."""
    return 'flutter_riverpod' in content


def add_import(content, filepath):
    """Add locale_provider import if not present."""
    locale_import = get_locale_import(filepath)
    if 'locale_provider.dart' in content:
        return content
    
    # Find the last import line and add after it
    lines = content.split('\n')
    last_import_idx = -1
    for i, line in enumerate(lines):
        if line.strip().startswith('import '):
            last_import_idx = i
    
    if last_import_idx >= 0:
        lines.insert(last_import_idx + 1, locale_import)
    else:
        lines.insert(0, locale_import)
    
    return '\n'.join(lines)


def add_riverpod_import(content):
    """Add flutter_riverpod import if not present."""
    if has_riverpod_import(content):
        return content
    
    lines = content.split('\n')
    # Find first import and add riverpod before it
    for i, line in enumerate(lines):
        if line.strip().startswith('import '):
            lines.insert(i, "import 'package:flutter_riverpod/flutter_riverpod.dart';")
            break
    
    return '\n'.join(lines)


def convert_to_consumer(content):
    """Convert StatelessWidget -> ConsumerWidget, StatefulWidget -> ConsumerStatefulWidget."""
    # Handle StatelessWidget -> ConsumerWidget
    content = re.sub(
        r'extends\s+StatelessWidget\b',
        'extends ConsumerWidget',
        content
    )
    # Fix build method: add WidgetRef ref parameter
    content = re.sub(
        r'Widget\s+build\(BuildContext\s+context\)\s*\{',
        'Widget build(BuildContext context, WidgetRef ref) {',
        content
    )
    
    # Handle StatefulWidget -> ConsumerStatefulWidget
    content = re.sub(
        r'extends\s+StatefulWidget\b',
        'extends ConsumerStatefulWidget',
        content
    )
    # State -> ConsumerState
    content = re.sub(
        r'extends\s+State<(\w+)>',
        r'extends ConsumerState<\1>',
        content
    )
    
    return content


def add_strings_declaration(content):
    """Add `final s = ref.watch(stringsProvider);` at the start of build methods."""
    # Pattern: Widget build(BuildContext context, WidgetRef ref) { or Widget build(BuildContext context) {
    # For ConsumerState, build has just (BuildContext context) but ref is available as widget member
    
    lines = content.split('\n')
    new_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        new_lines.append(line)
        
        # Check if this is a build method
        if re.search(r'Widget\s+build\(BuildContext\s+context', line):
            # Check if the opening brace is on this line
            if '{' in line:
                # Check if s = ref.watch(stringsProvider) already exists nearby
                next_few = '\n'.join(lines[i:i+5])
                if 'stringsProvider' not in next_few:
                    # Add the declaration after the opening brace
                    # Find indentation
                    indent = len(line) - len(line.lstrip()) + 4
                    new_lines.append(' ' * indent + 'final s = ref.watch(stringsProvider);')
            elif i + 1 < len(lines) and '{' in lines[i + 1]:
                new_lines.append(lines[i + 1])
                i += 1
                next_few = '\n'.join(lines[i:i+5])
                if 'stringsProvider' not in next_few:
                    indent = len(lines[i]) - len(lines[i].lstrip()) + 4
                    new_lines.append(' ' * indent + 'final s = ref.watch(stringsProvider);')
        
        i += 1
    
    return '\n'.join(new_lines)


def replace_strings_in_content(content, strings_to_replace):
    """Replace hardcoded strings with s.keyName references."""
    # Sort by length (longest first) to avoid partial replacements
    sorted_strings = sorted(strings_to_replace, key=len, reverse=True)
    
    for pt_str in sorted_strings:
        key = keys_map.get(pt_str)
        if not key:
            continue
        
        replacement = f's.{key}'
        
        # Replace 'string' and "string" patterns
        # Be careful not to replace inside comments or debugPrint
        lines = content.split('\n')
        new_lines = []
        for line in lines:
            stripped = line.strip()
            # Skip comment lines and debugPrint
            if stripped.startswith('//') or stripped.startswith('///') or 'debugPrint' in line:
                new_lines.append(line)
                continue
            
            # Replace single-quoted strings
            escaped_str = pt_str.replace("'", "\\'")
            line = line.replace(f"'{escaped_str}'", replacement)
            line = line.replace(f"'{pt_str}'", replacement)
            
            # Replace double-quoted strings
            escaped_str_dq = pt_str.replace('"', '\\"')
            line = line.replace(f'"{escaped_str_dq}"', replacement)
            line = line.replace(f'"{pt_str}"', replacement)
            
            new_lines.append(line)
        
        content = '\n'.join(new_lines)
    
    return content


def process_file(filepath, strings_in_file):
    """Process a single Dart file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original = content
    
    # Get unique strings for this file
    unique_strings = list(set(s for _, s in strings_in_file))
    
    # 1. Add riverpod import if needed
    if not has_riverpod_import(content):
        content = add_riverpod_import(content)
    
    # 2. Add locale import
    content = add_import(content, filepath)
    
    # 3. Convert to Consumer* if needed
    if needs_conversion(content):
        content = convert_to_consumer(content)
    
    # 4. Add strings declaration in build methods
    content = add_strings_declaration(content)
    
    # 5. Replace hardcoded strings
    content = replace_strings_in_content(content, unique_strings)
    
    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    return False


def main():
    modified = 0
    errors = []
    
    for filepath, strings_in_file in sorted(file_strings.items()):
        try:
            if process_file(filepath, strings_in_file):
                modified += 1
                print(f"  ✓ {os.path.basename(filepath)}")
            else:
                print(f"  - {os.path.basename(filepath)} (no changes)")
        except Exception as e:
            errors.append((filepath, str(e)))
            print(f"  ✗ {os.path.basename(filepath)}: {e}")
    
    print(f"\nModified: {modified}/{len(file_strings)} files")
    if errors:
        print(f"Errors: {len(errors)}")
        for fp, err in errors:
            print(f"  {fp}: {err}")


if __name__ == '__main__':
    main()
