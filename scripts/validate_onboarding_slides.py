from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

FILES = [
    'frontend/lib/features/auth/models/onboarding_slide.dart',
    'frontend/lib/features/auth/services/onboarding_slide_service.dart',
    'frontend/lib/features/auth/providers/onboarding_slides_provider.dart',
    'frontend/lib/features/auth/screens/onboarding_screen.dart',
    'frontend/lib/core/services/remote_config_service.dart',
    'backend/supabase/migrations/246_onboarding_slides_server_driven.sql',
]

REQUIRED_TOKENS = {
    'frontend/lib/features/auth/models/onboarding_slide.dart': [
        'class OnboardingSlide',
        'factory OnboardingSlide.fromMap',
        'slideKey',
        'locale',
        'title',
        'body',
        'iconName',
        'iconColorHex',
        'gradientHex',
        'variantKey',
        'schemaVersion',
    ],
    'frontend/lib/features/auth/services/onboarding_slide_service.dart': [
        'class OnboardingSlideService',
        'RemoteConfigService.isRemoteOnboardingSlidesEnabled',
        "'get_onboarding_slides'",
        "'p_locale'",
        "'p_variant_key'",
        "'p_schema_version'",
        'fallbackSlides',
        '_isValidSlideSet',
    ],
    'frontend/lib/features/auth/providers/onboarding_slides_provider.dart': [
        'final onboardingSlidesProvider',
        'FutureProvider<List<OnboardingSlide>>',
        'localeProvider',
        'stringsProvider',
        'OnboardingSlideService.fetchSlides',
    ],
    'frontend/lib/features/auth/screens/onboarding_screen.dart': [
        'onboardingSlidesProvider',
        'OnboardingSlideService.fallbackSlides',
        '_FeatureRow',
        '_iconFor',
        '_colorFromHex',
        'slide.title',
        'slide.body',
    ],
    'frontend/lib/core/services/remote_config_service.dart': [
        'isRemoteOnboardingSlidesEnabled',
        "features.remote_onboarding_slides_enabled",
    ],
    'backend/supabase/migrations/246_onboarding_slides_server_driven.sql': [
        'CREATE TABLE IF NOT EXISTS public.onboarding_slides',
        'ALTER TABLE public.onboarding_slides ENABLE ROW LEVEL SECURITY',
        'CREATE POLICY "onboarding_slides_read"',
        'CREATE POLICY "onboarding_slides_admin_write"',
        'CREATE OR REPLACE FUNCTION public.get_onboarding_slides',
        'SECURITY DEFINER',
        'SET search_path = public',
        'GRANT EXECUTE ON FUNCTION public.get_onboarding_slides(TEXT, TEXT, INTEGER) TO authenticated',
        'features.remote_onboarding_slides_enabled',
        'ON CONFLICT (locale, variant_key, slide_key) DO UPDATE',
    ],
}

FORBIDDEN_TOKENS = {
    'frontend/lib/features/auth/screens/onboarding_screen.dart': [
        's.thousandsOfCommunities,',
        's.realTimeChat,',
        's.customizeProfile,',
        "child: const Text('Criar Conta')",
    ],
}


def fail(message: str) -> None:
    raise SystemExit(f'FAIL: {message}')


def read(relative: str) -> str:
    path = ROOT / relative
    if not path.exists():
        fail(f'arquivo ausente: {relative}')
    data = path.read_bytes()
    if b'\x00' in data:
        fail(f'byte NUL encontrado em {relative}')
    return data.decode('utf-8')


def main() -> None:
    for relative in FILES:
        content = read(relative)
        for token in REQUIRED_TOKENS.get(relative, []):
            if token not in content:
                fail(f'{relative} sem token obrigatório: {token}')
        for token in FORBIDDEN_TOKENS.get(relative, []):
            if token in content:
                fail(f'{relative} ainda contém token legado proibido: {token}')

    migration = read('backend/supabase/migrations/246_onboarding_slides_server_driven.sql')
    references = migration.count('onboarding_slides')
    if references < 20:
        fail(f'migration parece incompleta: onboarding_slides aparece {references} vezes')

    locale_count = migration.count("'communities', '")
    if locale_count < 10:
        fail(f'seed multilíngue insuficiente: communities aparece em {locale_count} locales')

    print('OK: Onboarding Slides validado textualmente')
    print('arquivos_validados=6')
    print(f'referencias_onboarding_slides={references}')
    print(f'locales_seedados={locale_count}')


if __name__ == '__main__':
    main()
