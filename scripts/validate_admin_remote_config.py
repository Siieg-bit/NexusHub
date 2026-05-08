#!/usr/bin/env python3.11
"""
Validação textual do módulo P9 — Admin Remote Config Governance.

Confirma que o painel administrativo deixa de mutar `app_remote_config` diretamente,
usa a RPC auditável `admin_update_remote_config`, e que a migration cria a
infraestrutura mínima de governança operacional para conteúdo remoto sem deploy.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "backend/supabase/migrations/250_admin_remote_config_governance.sql"
PAGE = ROOT / "bubble-admin/client/src/pages/RemoteConfigPage.tsx"
CHECKLIST = ROOT / "CHECKLIST_MIGRACAO_APK_SERVIDOR.md"
MIGRATIONS_APPLIED = ROOT / "backend/supabase/MIGRATIONS_APPLIED.md"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(path: Path) -> str:
    require(path.exists(), f"Arquivo obrigatório ausente: {path}")
    return path.read_text(encoding="utf-8")


def main() -> None:
    migration = read(MIGRATION)
    page = read(PAGE)
    checklist = read(CHECKLIST)
    applied = read(MIGRATIONS_APPLIED)

    require("CREATE TABLE IF NOT EXISTS public.app_remote_config_audit_log" in migration,
            "Migration 250 deve criar tabela de auditoria app_remote_config_audit_log")
    require("CREATE OR REPLACE FUNCTION public.admin_update_remote_config" in migration,
            "Migration 250 deve criar RPC admin_update_remote_config")
    require("SECURITY DEFINER" in migration,
            "RPC administrativa deve ser SECURITY DEFINER")
    require("GRANT EXECUTE ON FUNCTION public.admin_update_remote_config" in migration,
            "RPC administrativa deve conceder execução a authenticated")
    require("p.is_team_admin = TRUE" in migration and "COALESCE(p.team_rank, 0) >= 80" in migration,
            "RPC deve restringir escrita a Team Admin ou rank equivalente")
    require("INSERT INTO public.app_remote_config_audit_log" in migration,
            "RPC deve registrar alterações em log append-only")
    require("invalid_key" in migration and "invalid_value" in migration and "invalid_category" in migration,
            "RPC deve validar chave, valor e categoria")

    require('supabase.rpc("admin_update_remote_config"' in page,
            "RemoteConfigPage deve salvar via RPC auditável")
    require("setConfigs((prev)" in page,
            "RemoteConfigPage deve atualizar estado local após retorno da RPC")
    require("Nova configuração remota" in page and "Criar configuração" in page,
            "RemoteConfigPage deve permitir criação operacional de novas configs")
    require("Salvar via RPC auditável" in page,
            "UI deve deixar claro o fluxo auditável de salvamento")
    require("app_remote_config_audit_log" not in page,
            "Cliente não deve escrever diretamente no log de auditoria")

    forbidden_direct_update = re.search(r'\.from\(["\']app_remote_config["\']\)\s*\n\s*\.update\(', page)
    forbidden_direct_insert = re.search(r'\.from\(["\']app_remote_config["\']\)\s*\n\s*\.insert\(', page)
    forbidden_direct_upsert = re.search(r'\.from\(["\']app_remote_config["\']\)\s*\n\s*\.upsert\(', page)
    require(not forbidden_direct_update, "RemoteConfigPage não deve usar update direto em app_remote_config")
    require(not forbidden_direct_insert, "RemoteConfigPage não deve usar insert direto em app_remote_config")
    require(not forbidden_direct_upsert, "RemoteConfigPage não deve usar upsert direto em app_remote_config")

    require("P9.1" in checklist, "Checklist mestre deve conter o item P9.1")
    require("Migration 250" in applied or "Migration 250" in checklist,
            "Registros operacionais devem mencionar a Migration 250 após aplicação/registro")

    print("OK — P9 Admin Remote Config validado textualmente")
    print("- Migration 250 cria RPC SECURITY DEFINER com auditoria e validações")
    print("- RemoteConfigPage salva/cria configs via admin_update_remote_config")
    print("- Mutação direta de app_remote_config pelo cliente não foi encontrada")


if __name__ == "__main__":
    main()
