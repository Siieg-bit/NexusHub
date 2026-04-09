#!/usr/bin/env python3
"""
Pass 3: Automated extraction and replacement of ALL remaining hardcoded
Portuguese strings using OpenAI for translation.

Strategy:
1. Extract all remaining hardcoded strings from all Dart files
2. Use OpenAI to translate them to English and generate camelCase keys
3. Add to l10n files
4. Replace in source files
"""

import os
import re
import json
from openai import OpenAI

PROJECT = "/home/ubuntu/NexusHub/frontend/lib"

def extract_remaining_strings():
    """Extract all remaining hardcoded Portuguese strings from Dart files."""
    all_strings = {}  # string -> list of (filepath, line_num)
    
    # Portuguese character pattern
    pt_pattern = re.compile(r"'([^']{2,})'|\"([^\"]{2,})\"")
    pt_chars = re.compile(r'[áàâãéèêíïóôõöúçñÁÀÂÃÉÈÊÍÏÓÔÕÖÚÇÑ]')
    # Also match capitalized Portuguese words
    pt_words = {'Erro', 'Nenhum', 'Nenhuma', 'Buscar', 'Salvar', 'Excluir', 'Editar',
                'Fechar', 'Voltar', 'Próximo', 'Cancelar', 'Confirmar', 'Enviar',
                'Adicionar', 'Remover', 'Selecionar', 'Criar', 'Publicar', 'Carregar',
                'Atualizar', 'Compartilhar', 'Denunciar', 'Bloquear', 'Seguir',
                'Entrar', 'Sair', 'Aceitar', 'Recusar', 'Aplicar', 'Finalizar'}
    
    for root, dirs, files in os.walk(PROJECT):
        for fname in files:
            if not fname.endswith('.dart'):
                continue
            filepath = os.path.join(root, fname)
            # Skip l10n files themselves
            if '/l10n/' in filepath:
                continue
            
            with open(filepath, 'r') as f:
                lines = f.readlines()
            
            for line_num, line in enumerate(lines, 1):
                stripped = line.strip()
                if stripped.startswith('//') or stripped.startswith('///') or 'debugPrint' in line:
                    continue
                if stripped.startswith('import '):
                    continue
                
                for match in pt_pattern.finditer(line):
                    s = match.group(1) or match.group(2)
                    if not s or len(s) < 2:
                        continue
                    
                    # Skip technical strings
                    if s.startswith('http') or s.startswith('/') or s.startswith('assets/'):
                        continue
                    if s.startswith('s.') or s.startswith('ref.') or s.startswith('context.'):
                        continue
                    if '.dart' in s or '.png' in s or '.jpg' in s or '.svg' in s:
                        continue
                    if s.startswith('package:') or s.startswith('dart:'):
                        continue
                    if all(c in '0123456789.-+eE' for c in s):
                        continue
                    # Skip color/hex values
                    if re.match(r'^[0-9a-fA-F]+$', s) or re.match(r'^#[0-9a-fA-F]+$', s):
                        continue
                    # Skip route paths
                    if s.startswith('/') and '/' in s[1:]:
                        continue
                    # Skip database/technical identifiers
                    if '_' in s and s == s.lower():
                        continue
                    
                    # Check if it contains Portuguese characters or starts with Portuguese word
                    has_pt = bool(pt_chars.search(s))
                    first_word = s.split()[0] if s.split() else ''
                    starts_pt = first_word in pt_words
                    # Also check if it's a capitalized phrase (likely UI text)
                    is_ui_text = bool(re.match(r'^[A-ZÁÀÂÃÉÈÊÍÏÓÔÕÖÚÇÑ]', s)) and len(s) > 2
                    
                    if has_pt or starts_pt or is_ui_text:
                        # Check it's not already using s.xxx
                        context_before = line[:match.start()]
                        if 's.' in context_before.split()[-1:]:
                            continue
                        
                        if s not in all_strings:
                            all_strings[s] = []
                        all_strings[s].append((filepath, line_num))
    
    return all_strings


def translate_batch(strings):
    """Use OpenAI to translate Portuguese strings to English and generate keys."""
    client = OpenAI()
    
    # Split into batches of 50
    string_list = list(strings)
    results = {}
    
    for i in range(0, len(string_list), 50):
        batch = string_list[i:i+50]
        prompt = """Translate each Portuguese string to English and generate a camelCase key name.
Return a JSON array where each element has: {"pt": "original", "en": "translation", "key": "camelCaseKey"}

Rules for keys:
- Use camelCase (e.g., errorLoadingData)
- Keep keys concise but descriptive
- Don't use Dart reserved words (switch, continue, default, class, etc.)
- Don't start with numbers

Strings to translate:
"""
        for s in batch:
            prompt += f'- "{s}"\n'
        
        try:
            response = client.chat.completions.create(
                model="gpt-4.1-nano",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.1,
                response_format={"type": "json_object"},
            )
            
            content = response.choices[0].message.content
            data = json.loads(content)
            
            # Handle both array and object responses
            items = data if isinstance(data, list) else data.get('translations', data.get('items', data.get('results', [])))
            if isinstance(items, dict):
                items = list(items.values()) if all(isinstance(v, dict) for v in items.values()) else [items]
            
            for item in items:
                if isinstance(item, dict) and 'pt' in item and 'en' in item and 'key' in item:
                    results[item['pt']] = (item['en'], item['key'])
        except Exception as e:
            print(f"  Error translating batch {i}: {e}")
            # Fallback: generate simple keys
            for s in batch:
                key = re.sub(r'[^a-zA-Z0-9\s]', '', s)
                words = key.split()[:5]
                if words:
                    key = words[0].lower() + ''.join(w.capitalize() for w in words[1:])
                else:
                    key = f'str{hash(s) % 100000}'
                results[s] = (s, key)  # Keep PT as fallback
    
    return results


def main():
    print("Extracting remaining hardcoded strings...")
    remaining = extract_remaining_strings()
    print(f"Found {len(remaining)} unique remaining strings")
    
    if not remaining:
        print("No remaining strings to process!")
        return
    
    print("\nTranslating with OpenAI...")
    translations = translate_batch(remaining)
    print(f"Translated {len(translations)} strings")
    
    # Ensure unique keys
    used_keys = set()
    # Load existing keys
    with open(f"{PROJECT}/core/l10n/app_strings.dart", 'r') as f:
        for line in f:
            m = re.search(r'String get (\w+)', line)
            if m:
                used_keys.add(m.group(1))
    
    final_map = {}
    for pt_str, (en_str, key) in translations.items():
        # Sanitize key
        key = re.sub(r'[^a-zA-Z0-9]', '', key)
        if not key or key[0].isdigit():
            key = 'str' + key
        # Ensure first char is lowercase
        key = key[0].lower() + key[1:] if key else 'strUnknown'
        
        # Ensure uniqueness
        base_key = key
        counter = 2
        while key in used_keys:
            key = f"{base_key}{counter}"
            counter += 1
        used_keys.add(key)
        
        final_map[pt_str] = (en_str, key)
    
    # Generate l10n additions
    abstract_additions = []
    pt_additions = []
    en_additions = []
    
    for pt_str, (en_str, key) in sorted(final_map.items(), key=lambda x: x[1][1]):
        abstract_additions.append(f"  String get {key};")
        pt_escaped = pt_str.replace("'", "\\'")
        en_escaped = en_str.replace("'", "\\'")
        pt_additions.append(f"  @override\n  String get {key} => '{pt_escaped}';")
        en_additions.append(f"  @override\n  String get {key} => '{en_escaped}';")
    
    # Append to l10n files
    for filepath, additions, comment in [
        (f"{PROJECT}/core/l10n/app_strings.dart", abstract_additions, "// PASS 3 — AUTO-GENERATED"),
        (f"{PROJECT}/core/l10n/app_strings_pt.dart", pt_additions, "// PASS 3 — AUTO-GENERATED"),
        (f"{PROJECT}/core/l10n/app_strings_en.dart", en_additions, "// PASS 3 — AUTO-GENERATED"),
    ]:
        with open(filepath, 'r') as f:
            content = f.read()
        insert_text = f"\n  {comment}\n" + '\n'.join(additions) + '\n'
        content = content.rstrip().rstrip('}') + insert_text + '}\n'
        with open(filepath, 'w') as f:
            f.write(content)
    
    print(f"\nAdded {len(final_map)} new keys to l10n files")
    
    # Replace in source files
    # Sort by length (longest first)
    sorted_replacements = sorted(final_map.items(), key=lambda x: len(x[0]), reverse=True)
    
    modified = 0
    for filepath in set(fp for locs in remaining.values() for fp, _ in locs):
        with open(filepath, 'r') as f:
            content = f.read()
        
        original = content
        
        for pt_str, (en_str, key) in sorted_replacements:
            if pt_str not in content:
                continue
            
            replacement = f's.{key}'
            lines = content.split('\n')
            new_lines = []
            for line in lines:
                stripped = line.strip()
                if stripped.startswith('//') or stripped.startswith('///') or 'debugPrint' in line:
                    new_lines.append(line)
                    continue
                
                escaped = pt_str.replace("'", "\\'")
                line = line.replace(f"'{escaped}'", replacement)
                line = line.replace(f"'{pt_str}'", replacement)
                escaped_dq = pt_str.replace('"', '\\"')
                line = line.replace(f'"{escaped_dq}"', replacement)
                line = line.replace(f'"{pt_str}"', replacement)
                
                new_lines.append(line)
            
            content = '\n'.join(new_lines)
        
        if content != original:
            # Ensure imports
            if 'locale_provider.dart' not in content and 's.' in content:
                rel = filepath.split('/frontend/lib/')[-1]
                parts = rel.split('/')
                depth = len(parts) - 1
                prefix = '../' * depth
                locale_import = f"import '{prefix}core/l10n/locale_provider.dart';"
                lines = content.split('\n')
                last_import_idx = -1
                for i, line in enumerate(lines):
                    if line.strip().startswith('import '):
                        last_import_idx = i
                if last_import_idx >= 0:
                    lines.insert(last_import_idx + 1, locale_import)
                content = '\n'.join(lines)
            
            if 'flutter_riverpod' not in content and 'ref.watch' in content:
                lines = content.split('\n')
                for i, line in enumerate(lines):
                    if line.strip().startswith('import '):
                        lines.insert(i, "import 'package:flutter_riverpod/flutter_riverpod.dart';")
                        break
                content = '\n'.join(lines)
            
            # Ensure build method has stringsProvider
            if 'stringsProvider' not in content and 's.' in content:
                # Find build method and add declaration
                lines = content.split('\n')
                new_lines = []
                for i, line in enumerate(lines):
                    new_lines.append(line)
                    if re.search(r'Widget\s+build\(BuildContext\s+context', line) and '{' in line:
                        next_few = '\n'.join(lines[i:i+5])
                        if 'stringsProvider' not in next_few:
                            indent = len(line) - len(line.lstrip()) + 4
                            new_lines.append(' ' * indent + 'final s = ref.watch(stringsProvider);')
                content = '\n'.join(new_lines)
            
            with open(filepath, 'w') as f:
                f.write(content)
            modified += 1
            print(f"  ✓ {os.path.basename(filepath)}")
    
    print(f"\nModified: {modified} files in pass 3")
    
    # Save the final map for reference
    with open('/home/ubuntu/NexusHub/pass3_mapping.json', 'w') as f:
        json.dump({k: {'en': v[0], 'key': v[1]} for k, v in final_map.items()}, f, ensure_ascii=False, indent=2)


if __name__ == '__main__':
    main()
