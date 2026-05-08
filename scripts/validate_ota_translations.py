from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
FILES = [
    'frontend/lib/core/l10n/app_strings.dart',
    'frontend/lib/core/l10n/app_strings_ota.dart',
    'frontend/lib/core/l10n/locale_provider.dart',
    'frontend/lib/core/services/ota_translation_service.dart',
    'frontend/lib/main.dart',
    'backend/supabase/migrations/241_app_translations.sql',
]

GETTER_RE = re.compile(r'^\s*String\s+get\s+(\w+)\s*;.*$')
WRAP_GETTER_RE = re.compile(r'^\s*String\s+get\s+(\w+)\s*=>.*$')
METHOD_RE = re.compile(r'^\s*String\s+(\w+)\(.*\)\s*;.*$')
WRAP_METHOD_RE = re.compile(r'^\s*String\s+(\w+)\(.*\)\s*=>.*$')


def fail(message: str) -> None:
    raise SystemExit(f'FAIL: {message}')


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding='utf-8')


def main() -> None:
    for relative in FILES:
        path = ROOT / relative
        if not path.exists():
            fail(f'arquivo ausente: {relative}')
        data = path.read_bytes()
        if b'\x00' in data:
            fail(f'byte NUL encontrado em {relative}')

    interface_lines = read('frontend/lib/core/l10n/app_strings.dart').splitlines()
    wrapper_lines = read('frontend/lib/core/l10n/app_strings_ota.dart').splitlines()

    interface_getters = {
        m.group(1)
        for line in interface_lines
        if (m := GETTER_RE.match(line))
    }
    wrapper_getters = {
        m.group(1)
        for line in wrapper_lines
        if (m := WRAP_GETTER_RE.match(line))
    }
    interface_methods = {
        m.group(1)
        for line in interface_lines
        if (m := METHOD_RE.match(line))
    }
    wrapper_methods = {
        m.group(1)
        for line in wrapper_lines
        if (m := WRAP_METHOD_RE.match(line))
    }

    missing_getters = sorted(interface_getters - wrapper_getters)
    extra_getters = sorted(wrapper_getters - interface_getters)
    missing_methods = sorted(interface_methods - wrapper_methods)
    extra_methods = sorted(wrapper_methods - interface_methods)

    if missing_getters or extra_getters:
        fail(f'cobertura de getters divergente. missing={missing_getters[:10]} extra={extra_getters[:10]}')
    if missing_methods or extra_methods:
        fail(f'cobertura de métodos divergente. missing={missing_methods[:10]} extra={extra_methods[:10]}')

    wrapper = read('frontend/lib/core/l10n/app_strings_ota.dart')
    if "import 'app_strings.dart';" not in wrapper:
        fail('wrapper sem import de app_strings.dart')
    if 'OtaTranslationService.translate' not in wrapper:
        fail('wrapper não usa OtaTranslationService.translate')

    locale_provider = read('frontend/lib/core/l10n/locale_provider.dart')
    if "import 'app_strings_ota.dart';" not in locale_provider:
        fail('locale_provider sem import do wrapper OTA')
    if 'AppStrings get _fallbackStrings' not in locale_provider:
        fail('locale_provider sem fallback local explícito')
    if 'OtaAppStrings(locale: code, fallback: fallback)' not in locale_provider:
        fail('locale_provider não retorna wrapper OTA')

    main_dart = read('frontend/lib/main.dart')
    if "import 'core/services/ota_translation_service.dart';" not in main_dart:
        fail('main.dart sem import do serviço OTA')
    if "_initSafe(\n    'otaTranslations'," not in main_dart or 'OtaTranslationService.initialize(initialLocale:' not in main_dart:
        fail('main.dart não inicializa OTA Translations')
    if 'updateGlobalStrings(initialLocale)' not in main_dart:
        fail('main.dart não sincroniza strings globais após OTA')

    service = read('frontend/lib/core/services/ota_translation_service.dart')
    required_service_tokens = [
        'SharedPreferences',
        'SupabaseService.client',
        'Future.wait',
        'RemoteConfigService.isOtaTranslationsEnabled',
        'unawaited(_preloadLocalesInBackground',
        '.timeout(_kTranslationFetchTimeout)',
        '_loadFromLocalCache',
        '_saveToLocalCache',
    ]
    for token in required_service_tokens:
        if token not in service:
            fail(f'serviço OTA sem token obrigatório: {token}')

    migration = read('backend/supabase/migrations/241_app_translations.sql')
    required_sql_tokens = [
        'CREATE TABLE IF NOT EXISTS public.app_translations',
        'ALTER TABLE public.app_translations ENABLE ROW LEVEL SECURITY',
        'CREATE POLICY "app_translations_public_read"',
        'CREATE POLICY "app_translations_admin_write"',
        'CREATE OR REPLACE FUNCTION public.get_app_translations',
        'SECURITY DEFINER',
        'GRANT EXECUTE ON FUNCTION public.get_app_translations(TEXT) TO anon, authenticated',
        'ON CONFLICT (locale, key) DO UPDATE',
    ]
    for token in required_sql_tokens:
        if token not in migration:
            fail(f'migration sem token obrigatório: {token}')

    seed_rows = sum(1 for line in migration.splitlines() if line.startswith("  ('"))
    if seed_rows < 1000:
        fail(f'seed pequeno demais para OTA translations: {seed_rows}')

    print('OK: OTA Translations validado textualmente')
    print(f'getters_cobertos={len(wrapper_getters)}')
    print(f'metodos_delegados={len(wrapper_methods)}')
    print(f'seed_rows={seed_rows}')


if __name__ == '__main__':
    main()
