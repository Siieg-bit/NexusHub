#!/usr/bin/env python3
"""
Aplica responsividade automática em todos os arquivos .dart de UI do NexusHub.

Estratégia:
1. Adiciona import do responsive.dart
2. Adiciona `final r = context.r;` no início de cada build method
3. Substitui valores hardcoded por chamadas ao Responsive:
   - fontSize: X → fontSize: r.fs(X)
   - size: X (em Icon) → size: r.s(X)
   - width: X / height: X (em containers) → r.s(X)
   - EdgeInsets.all(X) → EdgeInsets.all(r.s(X))
   - EdgeInsets.symmetric(horizontal: X, vertical: Y) → (horizontal: r.s(X), vertical: r.s(Y))
   - EdgeInsets.only(...) → r.s(...)
   - BorderRadius.circular(X) → BorderRadius.circular(r.s(X))
   - SizedBox(width: X) / SizedBox(height: X) → SizedBox(width: r.s(X)) / SizedBox(height: r.s(X))
   - maxWidth: X → maxWidth: r.w(X)
   - constraints: BoxConstraints(maxWidth: X) → constraints: BoxConstraints(maxWidth: r.w(X))

NÃO modifica:
- Valores 0, 0.0, 0.5, 1, 1.0, 2 (muito pequenos para escalar)
- Valores dentro de Color(), Offset(), Duration()
- Valores em animações (Tween, etc.)
- Arquivos de models, providers, services, router
- app_theme.dart, responsive.dart
"""

import re
import os
import glob

FRONTEND_LIB = '/home/ubuntu/NexusHub/frontend/lib'

# Arquivos a NÃO modificar
EXCLUDE_PATTERNS = {
    'responsive.dart',
    'app_theme.dart',
    'app_config.dart',
    'main.dart',
    'app_router.dart',
    'shell_screen.dart',
}

# Diretórios a NÃO processar
EXCLUDE_DIRS = {
    'models',
    'providers',
    'services',
    'l10n',
    'utils',
}

RESPONSIVE_IMPORT = "import '../../core/utils/responsive.dart';"

# Valores mínimos para escalar (abaixo disso não faz sentido)
MIN_VALUE = 3


def get_responsive_import(filepath: str) -> str:
    """Calcula o import relativo correto para responsive.dart."""
    rel = os.path.relpath(
        os.path.join(FRONTEND_LIB, 'core', 'utils', 'responsive.dart'),
        os.path.dirname(filepath)
    )
    return f"import '{rel}';"


def has_responsive_import(content: str) -> bool:
    return 'responsive.dart' in content


def should_process(filepath: str) -> bool:
    basename = os.path.basename(filepath)
    if basename in EXCLUDE_PATTERNS:
        return False
    # Verificar diretórios excluídos
    parts = filepath.split(os.sep)
    for part in parts:
        if part in EXCLUDE_DIRS:
            return False
    return True


def is_small_value(val_str: str) -> bool:
    """Verifica se o valor é pequeno demais para escalar."""
    try:
        val = float(val_str)
        return val < MIN_VALUE
    except ValueError:
        return True  # Se não é número, não escalar


def apply_font_size(content: str) -> tuple[str, int]:
    """fontSize: 14 → fontSize: r.fs(14)"""
    count = 0
    def replacer(m):
        nonlocal count
        val = m.group(1)
        if is_small_value(val):
            return m.group(0)
        count += 1
        return f'fontSize: r.fs({val})'
    content = re.sub(r'fontSize:\s*(\d+\.?\d*)', replacer, content)
    return content, count


def apply_icon_size(content: str) -> tuple[str, int]:
    """size: 24 (em contexto de Icon) → size: r.s(24)"""
    count = 0
    def replacer(m):
        nonlocal count
        val = m.group(1)
        if is_small_value(val):
            return m.group(0)
        count += 1
        return f'size: r.s({val})'
    # Apenas size: seguido de número (não size: MediaQuery, size: r., etc.)
    content = re.sub(r'(?<!\.)\bsize:\s*(\d+\.?\d*)(?!\s*[,\)].*r\.)', replacer, content)
    return content, count


def apply_border_radius(content: str) -> tuple[str, int]:
    """BorderRadius.circular(12) → BorderRadius.circular(r.s(12))"""
    count = 0
    def replacer(m):
        nonlocal count
        val = m.group(1)
        if is_small_value(val):
            return m.group(0)
        count += 1
        return f'BorderRadius.circular(r.s({val}))'
    content = re.sub(r'BorderRadius\.circular\((\d+\.?\d*)\)', replacer, content)
    return content, count


def apply_edge_insets_all(content: str) -> tuple[str, int]:
    """EdgeInsets.all(16) → EdgeInsets.all(r.s(16))"""
    count = 0
    def replacer(m):
        nonlocal count
        val = m.group(1)
        if is_small_value(val):
            return m.group(0)
        count += 1
        return f'EdgeInsets.all(r.s({val}))'
    content = re.sub(r'EdgeInsets\.all\((\d+\.?\d*)\)', replacer, content)
    return content, count


def apply_edge_insets_symmetric(content: str) -> tuple[str, int]:
    """EdgeInsets.symmetric(horizontal: 16, vertical: 8) → ...(horizontal: r.s(16), vertical: r.s(8))"""
    count = 0
    def replacer(m):
        nonlocal count
        full = m.group(0)
        # Substituir valores numéricos dentro do symmetric
        def inner_replace(im):
            val = im.group(2)
            if is_small_value(val):
                return im.group(0)
            return f'{im.group(1)}: r.s({val})'
        new_full = re.sub(r'(horizontal|vertical):\s*(\d+\.?\d*)', inner_replace, full)
        if new_full != full:
            count += 1
        return new_full
    content = re.sub(
        r'EdgeInsets\.symmetric\([^)]+\)',
        replacer,
        content
    )
    return content, count


def apply_edge_insets_only(content: str) -> tuple[str, int]:
    """EdgeInsets.only(left: 16, top: 8) → ...(left: r.s(16), top: r.s(8))"""
    count = 0
    def replacer(m):
        nonlocal count
        full = m.group(0)
        def inner_replace(im):
            val = im.group(2)
            if is_small_value(val):
                return im.group(0)
            return f'{im.group(1)}: r.s({val})'
        new_full = re.sub(r'(left|right|top|bottom):\s*(\d+\.?\d*)', inner_replace, full)
        if new_full != full:
            count += 1
        return new_full
    content = re.sub(
        r'EdgeInsets\.only\([^)]+\)',
        replacer,
        content
    )
    return content, count


def apply_edge_insets_fromLTRB(content: str) -> tuple[str, int]:
    """EdgeInsets.fromLTRB(16, 8, 16, 12) → EdgeInsets.fromLTRB(r.s(16), r.s(8), r.s(16), r.s(12))"""
    count = 0
    def replacer(m):
        nonlocal count
        args = m.group(1)
        vals = [v.strip() for v in args.split(',')]
        new_vals = []
        changed = False
        for v in vals:
            try:
                fv = float(v)
                if fv >= MIN_VALUE:
                    new_vals.append(f'r.s({v})')
                    changed = True
                else:
                    new_vals.append(v)
            except ValueError:
                new_vals.append(v)
        if changed:
            count += 1
            return f'EdgeInsets.fromLTRB({", ".join(new_vals)})'
        return m.group(0)
    content = re.sub(
        r'EdgeInsets\.fromLTRB\(([^)]+)\)',
        replacer,
        content
    )
    return content, count


def apply_sized_box(content: str) -> tuple[str, int]:
    """SizedBox(width: 12) → SizedBox(width: r.s(12))
       SizedBox(height: 8) → SizedBox(height: r.s(8))"""
    count = 0
    def replacer(m):
        nonlocal count
        prefix = m.group(1)  # 'width' or 'height'
        val = m.group(2)
        if is_small_value(val):
            return m.group(0)
        count += 1
        return f'SizedBox({prefix}: r.s({val}))'
    content = re.sub(
        r'SizedBox\((width|height):\s*(\d+\.?\d*)\)',
        replacer,
        content
    )
    return content, count


def apply_max_width(content: str) -> tuple[str, int]:
    """maxWidth: 280 → maxWidth: r.w(280)"""
    count = 0
    def replacer(m):
        nonlocal count
        val = m.group(1)
        if is_small_value(val):
            return m.group(0)
        count += 1
        return f'maxWidth: r.w({val})'
    content = re.sub(r'maxWidth:\s*(\d+\.?\d*)', replacer, content)
    return content, count


def apply_container_dimensions(content: str) -> tuple[str, int]:
    """
    width: 48 → width: r.s(48) (em contextos de Container/SizedBox)
    height: 48 → height: r.s(48)
    
    Cuidado: não modificar width/height em MediaQuery, Expanded, Flexible, etc.
    Apenas valores numéricos literais.
    """
    count = 0
    def replacer(m):
        nonlocal count
        prefix = m.group(1)
        val = m.group(2)
        if is_small_value(val):
            return m.group(0)
        # Não escalar valores muito grandes (provavelmente são alturas de tela)
        try:
            if float(val) > 500:
                return m.group(0)
        except ValueError:
            return m.group(0)
        count += 1
        return f'{prefix}: r.s({val})'

    # width: e height: seguidos de número literal (não de variável, MediaQuery, etc.)
    content = re.sub(
        r'(?<!\w)(width|height):\s*(\d+\.?\d*)(?=\s*[,\)\n])',
        replacer,
        content
    )
    return content, count


def inject_r_in_build(content: str) -> tuple[str, int]:
    """
    Adiciona `final r = context.r;` no início de cada build method,
    logo após a abertura `{`.
    """
    count = 0
    
    # Padrão: Widget build(BuildContext context) {
    def replacer(m):
        nonlocal count
        # Verificar se já tem `final r = context.r;` logo após
        after = content[m.end():m.end()+100]
        if 'context.r' in after[:80]:
            return m.group(0)
        count += 1
        indent = '    '  # Indentação padrão
        return f'{m.group(0)}\n{indent}final r = context.r;'
    
    content = re.sub(
        r'Widget\s+build\s*\(\s*BuildContext\s+context\s*\)\s*\{',
        replacer,
        content
    )
    return content, count


def add_import(content: str, filepath: str) -> str:
    """Adiciona o import do responsive.dart se não existir."""
    if has_responsive_import(content):
        return content
    
    rel_import = get_responsive_import(filepath)
    
    # Adicionar após o último import
    import_end = 0
    for match in re.finditer(r"^import\s+'[^']+';", content, re.MULTILINE):
        import_end = match.end()
    
    if import_end > 0:
        content = content[:import_end] + '\n' + rel_import + content[import_end:]
    else:
        content = rel_import + '\n' + content
    
    return content


def process_file(filepath: str) -> tuple[int, bool]:
    if not should_process(filepath):
        return 0, False
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original = content
    total = 0
    
    # 1. Injetar `final r = context.r;` nos build methods
    content, c = inject_r_in_build(content)
    total += c
    
    # 2. Aplicar transformações de responsividade
    content, c = apply_font_size(content)
    total += c
    
    content, c = apply_icon_size(content)
    total += c
    
    content, c = apply_border_radius(content)
    total += c
    
    content, c = apply_edge_insets_all(content)
    total += c
    
    content, c = apply_edge_insets_symmetric(content)
    total += c
    
    content, c = apply_edge_insets_only(content)
    total += c
    
    content, c = apply_edge_insets_fromLTRB(content)
    total += c
    
    content, c = apply_sized_box(content)
    total += c
    
    content, c = apply_max_width(content)
    total += c
    
    content, c = apply_container_dimensions(content)
    total += c
    
    if total == 0:
        return 0, False
    
    # 3. Adicionar import
    content = add_import(content, filepath)
    
    # 4. Remover 'const' de expressões que agora usam r.
    # const EdgeInsets.all(r.s(16)) → EdgeInsets.all(r.s(16))
    content = re.sub(r'\bconst\s+(EdgeInsets\.[a-zA-Z]+\([^)]*r\.)', r'\1', content)
    content = re.sub(r'\bconst\s+(BorderRadius\.[a-zA-Z]+\([^)]*r\.)', r'\1', content)
    content = re.sub(r'\bconst\s+(SizedBox\([^)]*r\.)', r'\1', content)
    content = re.sub(r'\bconst\s+(TextStyle\([^)]*r\.)', r'\1', content)
    content = re.sub(r'\bconst\s+(Icon\([^)]*r\.)', r'\1', content)
    content = re.sub(r'\bconst\s+(IconThemeData\([^)]*r\.)', r'\1', content)
    content = re.sub(r'\bconst\s+(Padding\([^)]*r\.)', r'\1', content)
    content = re.sub(r'\bconst\s+(BoxConstraints\([^)]*r\.)', r'\1', content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    return total, True


def main():
    dart_files = glob.glob(os.path.join(FRONTEND_LIB, '**', '*.dart'), recursive=True)
    
    total_files = 0
    total_changes = 0
    
    for filepath in sorted(dart_files):
        changes, modified = process_file(filepath)
        if modified:
            total_files += 1
            total_changes += changes
            print(f'  [{changes:4d}] {os.path.relpath(filepath, FRONTEND_LIB)}')
    
    print(f'\n✅ {total_changes} alterações em {total_files} arquivos')


if __name__ == '__main__':
    main()
