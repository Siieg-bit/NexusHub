#!/usr/bin/env python3
"""Validação textual do módulo Streaming Rules server-driven.

O ambiente de automação não possui Flutter/Dart no PATH, então esta checagem
complementa as validações existentes garantindo que os contratos críticos de
backend e frontend foram adicionados de forma consistente.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

CHECKS = [
    (
        "modelo tipado de regras",
        ROOT / "frontend/lib/features/live/screening/models/streaming_platform_rule.dart",
        [
            "class StreamingPlatformRule",
            "factory StreamingPlatformRule.fromJson",
            "hostPatterns",
            "videoUrlPatterns",
            "blockedUrlPatterns",
            "class StreamingRuleDecision",
        ],
    ),
    (
        "serviço server-driven conservador",
        ROOT / "frontend/lib/features/live/screening/services/streaming_rules_service.dart",
        [
            "class StreamingRulesService",
            "RemoteConfigService.isRemoteStreamingRulesEnabled",
            "get_streaming_platform_rules",
            "assertUrlAllowed",
            "fallbackRules",
            "Domínio não permitido para a Sala de Projeção",
        ],
    ),
    (
        "feature flag remota",
        ROOT / "frontend/lib/core/services/remote_config_service.dart",
        [
            "isRemoteStreamingRulesEnabled",
            "features.remote_streaming_rules_enabled",
        ],
    ),
    (
        "resolvedor central protegido",
        ROOT / "frontend/lib/features/live/screening/services/stream_resolver_service.dart",
        [
            "import 'streaming_rules_service.dart';",
            "StreamingRulesService.assertUrlAllowed",
            "_platformRuleId",
            "case StreamPlatform.youtubeLive:",
        ],
    ),
    (
        "provider de sala protegido",
        ROOT / "frontend/lib/features/live/screening/providers/screening_room_provider.dart",
        [
            "import '../services/streaming_rules_service.dart';",
            "skipStreamingRuleValidation",
            "StreamingRulesService.assertUrlAllowed(videoUrl)",
            "StreamingRulesService.assertUrlAllowed(url)",
        ],
    ),
    (
        "browser sheet valida URL original",
        ROOT / "frontend/lib/features/live/screening/widgets/screening_browser_sheet.dart",
        [
            "import '../services/streaming_rules_service.dart';",
            "StreamingRulesService.assertUrlAllowed(",
            "preferredPlatformId: _platform.id",
            "on StreamingRulesException catch",
            "skipStreamingRuleValidation: true",
        ],
    ),
    (
        "migration 247",
        ROOT / "backend/supabase/migrations/247_streaming_rules_server_driven.sql",
        [
            "CREATE TABLE IF NOT EXISTS public.streaming_platform_rules",
            "CREATE POLICY \"streaming_platform_rules_read\"",
            "CREATE OR REPLACE FUNCTION public.get_streaming_platform_rules",
            "GRANT EXECUTE ON FUNCTION public.get_streaming_platform_rules(INTEGER) TO authenticated",
            "features.remote_streaming_rules_enabled",
            "ON CONFLICT (platform_id) DO UPDATE SET",
        ],
    ),
]


def main() -> int:
    failures: list[str] = []
    for label, path, needles in CHECKS:
        if not path.exists():
            failures.append(f"[{label}] arquivo ausente: {path.relative_to(ROOT)}")
            continue
        content = path.read_text(encoding="utf-8")
        missing = [needle for needle in needles if needle not in content]
        if missing:
            failures.append(
                f"[{label}] marcadores ausentes em {path.relative_to(ROOT)}: "
                + ", ".join(missing)
            )

    if failures:
        print("Streaming Rules validation failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("Streaming Rules validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
