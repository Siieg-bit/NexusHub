#!/usr/bin/env python3
"""Validação textual do módulo Cache TTL remoto.

Este script cobre a implementação server-driven de políticas de cache sem
executar Flutter/Dart, indisponíveis no ambiente atual. Ele valida presença de
serviço, integrações, feature flag, payload remoto e migration 248.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

CHECKS = [
    (
        "CachePolicyService criado",
        ROOT / "frontend/lib/core/services/cache_policy_service.dart",
        [
            "class CachePolicyService",
            "RemoteConfigService.isRemoteCachePoliciesEnabled",
            "RemoteConfigService.cacheTtlSeconds",
            "policyKeyFor",
            "effectivePolicies",
            "_fallbackTtlSeconds",
            "_minTtlSeconds",
            "_maxTtlSeconds",
        ],
    ),
    (
        "CacheService integrado ao CachePolicyService",
        ROOT / "frontend/lib/core/services/cache_service.dart",
        [
            "import 'cache_policy_service.dart';",
            "Duration? maxAge",
            "CachePolicyService.maxAgeFor(key)",
        ],
    ),
    (
        "RemoteConfigService expõe flag e payload de cache",
        ROOT / "frontend/lib/core/services/remote_config_service.dart",
        [
            "cacheTtlSeconds",
            "cache.ttl_seconds",
            "isRemoteCachePoliciesEnabled",
            "features.remote_cache_policies_enabled",
        ],
    ),
    (
        "Migration 248 contém seed idempotente de políticas",
        ROOT / "backend/supabase/migrations/248_cache_policies_remote_config.sql",
        [
            "features.remote_cache_policies_enabled",
            "cache.ttl_seconds",
            "ON CONFLICT (key) DO UPDATE",
            '"messages": 120',
            '"profiles": 3600',
            '"wiki": 900',
        ],
    ),
]


def main() -> int:
    failures: list[str] = []
    for label, path, snippets in CHECKS:
        if not path.exists():
            failures.append(f"{label}: arquivo ausente: {path}")
            continue
        text = path.read_text(encoding="utf-8")
        for snippet in snippets:
            if snippet not in text:
                failures.append(f"{label}: trecho não encontrado: {snippet}")

    if failures:
        print("FAIL: validação Cache Policies encontrou problemas:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("OK: Cache Policies server-driven validado textualmente")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
