from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

FILES = [
    'frontend/lib/features/feed/models/system_announcement.dart',
    'frontend/lib/features/feed/services/announcement_service.dart',
    'frontend/lib/features/feed/providers/announcements_provider.dart',
    'frontend/lib/features/feed/widgets/announcement_banner.dart',
    'frontend/lib/core/services/remote_config_service.dart',
    'backend/supabase/migrations/245_system_announcements_server_driven.sql',
]

REQUIRED_TOKENS = {
    'frontend/lib/features/feed/models/system_announcement.dart': [
        'class SystemAnnouncement',
        'static SystemAnnouncement fromMap',
        'severity',
        'placement',
        'dismissible',
        'sortOrder',
        'schemaVersion',
        'metadata',
    ],
    'frontend/lib/features/feed/services/announcement_service.dart': [
        'class AnnouncementService',
        'RemoteConfigService.isRemoteAnnouncementsEnabled',
        "'get_active_announcements_v2'",
        "'p_locale'",
        "'p_schema_version'",
        "'p_placement'",
        'fallbackAnnouncements',
    ],
    'frontend/lib/features/feed/providers/announcements_provider.dart': [
        'final activeAnnouncementsProvider',
        'FutureProvider<List<SystemAnnouncement>>',
        'localeProvider',
        'AnnouncementService.fetchActiveAnnouncements',
    ],
    'frontend/lib/features/feed/widgets/announcement_banner.dart': [
        'activeAnnouncementsProvider',
        'SystemAnnouncement',
        'announcement.dismissible',
        'announcement.severity',
        'SharedPreferences',
        'LaunchMode.externalApplication',
    ],
    'frontend/lib/core/services/remote_config_service.dart': [
        'isRemoteAnnouncementsEnabled',
        "features.remote_announcements_enabled",
    ],
    'backend/supabase/migrations/245_system_announcements_server_driven.sql': [
        'ALTER TABLE public.system_announcements',
        'ADD COLUMN IF NOT EXISTS severity',
        'ADD COLUMN IF NOT EXISTS placement',
        'ADD COLUMN IF NOT EXISTS dismissible',
        'ADD COLUMN IF NOT EXISTS sort_order',
        'ADD COLUMN IF NOT EXISTS schema_version',
        'CREATE OR REPLACE FUNCTION public.get_active_announcements_v2',
        'SECURITY DEFINER',
        'SET search_path = public',
        'GRANT EXECUTE ON FUNCTION public.get_active_announcements_v2(TEXT, INTEGER, TEXT) TO authenticated',
        'features.remote_announcements_enabled',
    ],
}

FORBIDDEN_TOKENS = {
    'frontend/lib/features/feed/widgets/announcement_banner.dart': [
        'final systemAnnouncementsProvider',
        'get_active_system_announcements',
        "import '../../../core/services/supabase_service.dart';",
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

    migration = read('backend/supabase/migrations/245_system_announcements_server_driven.sql')
    required_sql_count = migration.count('system_announcements')
    if required_sql_count < 20:
        fail(f'migration parece incompleta: system_announcements aparece {required_sql_count} vezes')

    print('OK: System Announcements validado textualmente')
    print('arquivos_validados=6')
    print(f'referencias_system_announcements={required_sql_count}')


if __name__ == '__main__':
    main()
