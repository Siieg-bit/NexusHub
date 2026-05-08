from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
INTERFACE = ROOT / 'frontend/lib/core/l10n/app_strings.dart'
OUTPUT = ROOT / 'frontend/lib/core/l10n/app_strings_ota.dart'

GETTER_RE = re.compile(r'^\s*String\s+get\s+(\w+)\s*;.*$')
METHOD_RE = re.compile(r'^\s*String\s+(\w+)\((.*)\)\s*;.*$')


def split_params(raw: str) -> list[str]:
    raw = raw.strip()
    if not raw:
        return []
    params = []
    current = []
    depth = 0
    for ch in raw:
        if ch == ',' and depth == 0:
            params.append(''.join(current).strip())
            current = []
            continue
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
        current.append(ch)
    if current:
        params.append(''.join(current).strip())
    return params


def arg_name(param: str) -> str:
    cleaned = param.strip()
    cleaned = cleaned.replace('required ', '')
    cleaned = cleaned.strip('{}[] ')
    cleaned = cleaned.split('=')[0].strip()
    return cleaned.split()[-1].replace('?', '')


def delegate_args(params: list[str]) -> str:
    # A interface atual usa parâmetros posicionais. A lógica abaixo preserva o
    # caminho para named params caso sejam adicionados no futuro.
    rendered = []
    for param in params:
        name = arg_name(param)
        if param.strip().startswith('required '):
            rendered.append(f'{name}: {name}')
        else:
            rendered.append(name)
    return ', '.join(rendered)


def main() -> None:
    getters: list[str] = []
    methods: list[tuple[str, str, list[str]]] = []

    for line in INTERFACE.read_text(encoding='utf-8').splitlines():
        getter = GETTER_RE.match(line)
        if getter:
            getters.append(getter.group(1))
            continue
        method = METHOD_RE.match(line)
        if method:
            name, raw_params = method.groups()
            methods.append((name, raw_params, split_params(raw_params)))

    lines = [
        "import 'app_strings.dart';",
        "import 'package:amino_clone/core/services/ota_translation_service.dart';",
        '',
        '/// Camada OTA para traduções remotas com fallback local.',
        '///',
        '/// Esta classe evita alterar os arquivos `app_strings_*.dart` existentes.',
        '/// Getters simples podem ser sobrescritos pelo servidor; métodos com',
        '/// parâmetros permanecem delegados ao fallback local para preservar',
        '/// interpolação, pluralização e regras gramaticais por idioma.',
        'class OtaAppStrings implements AppStrings {',
        '  const OtaAppStrings({',
        '    required this.locale,',
        '    required this.fallback,',
        '  });',
        '',
        '  final String locale;',
        '  final AppStrings fallback;',
        '',
    ]

    for name in getters:
        lines.extend([
            '  @override',
            "  String get {name} => OtaTranslationService.translate(locale, '{name}', fallback.{name});".format(name=name),
            '',
        ])

    for name, raw_params, params in methods:
        args = delegate_args(params)
        lines.extend([
            '  @override',
            f'  String {name}({raw_params}) => fallback.{name}({args});',
            '',
        ])

    lines.append('}')
    lines.append('')
    OUTPUT.write_text('\n'.join(lines), encoding='utf-8')
    print(f'Generated {OUTPUT.relative_to(ROOT)} with {len(getters)} getters and {len(methods)} delegated methods')


if __name__ == '__main__':
    main()
