"""
NexusHub — Script de Migração do Banco de Dados
Executa todos os arquivos SQL no Supabase via REST API (pg_query)
"""

import os
import requests
import sys

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://SEU_PROJETO.supabase.co")
SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", 
    "SUA_SUPABASE_SERVICE_ROLE_KEY_AQUI"
)

HEADERS = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=minimal"
}

# Ordem das migrações
MIGRATIONS = [
    "001_enums_and_core.sql",
    "002_content.sql",
    "003_chat.sql",
    "004_moderation.sql",
    "005_economy.sql",
    "006_notifications_and_misc.sql",
    "007_rls_policies.sql",
    "008_triggers_and_rpcs.sql",
    "009_storage_and_realtime.sql",
]

def execute_sql(sql: str, filename: str) -> bool:
    """Executa SQL via Supabase REST API (rpc)"""
    url = f"{SUPABASE_URL}/rest/v1/rpc/exec_sql"
    
    # Tentar via pg_query endpoint direto
    url = f"{SUPABASE_URL}/pg/query"
    
    response = requests.post(
        url,
        headers=HEADERS,
        json={"query": sql}
    )
    
    if response.status_code in (200, 201, 204):
        return True
    else:
        print(f"  ERRO ({response.status_code}): {response.text[:500]}")
        return False


def execute_sql_via_sql_endpoint(sql: str, filename: str) -> bool:
    """Executa SQL via endpoint /sql do Supabase (Management API)"""
    # Usar o endpoint REST /rpc para executar SQL raw
    # Primeiro, criar uma função temporária para executar SQL
    url = f"{SUPABASE_URL}/rest/v1/rpc/"
    
    # Dividir o SQL em statements individuais para execução
    # Remover comentários de linha
    lines = sql.split('\n')
    clean_lines = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith('--'):
            continue
        clean_lines.append(line)
    
    clean_sql = '\n'.join(clean_lines)
    
    # Executar via psql-like endpoint
    response = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/exec_sql",
        headers=HEADERS,
        json={"sql_text": clean_sql}
    )
    
    if response.status_code in (200, 201, 204):
        return True
    
    return False


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    print("=" * 60)
    print("NexusHub — Executando Migrações do Banco de Dados")
    print("=" * 60)
    print(f"Supabase URL: {SUPABASE_URL}")
    print()
    
    success_count = 0
    fail_count = 0
    
    for filename in MIGRATIONS:
        filepath = os.path.join(script_dir, filename)
        
        if not os.path.exists(filepath):
            print(f"[SKIP] {filename} — arquivo não encontrado")
            continue
        
        print(f"[RUN]  {filename}...", end=" ", flush=True)
        
        with open(filepath, 'r') as f:
            sql = f.read()
        
        if execute_sql(sql, filename):
            print("OK ✓")
            success_count += 1
        else:
            print("FALHOU ✗")
            fail_count += 1
    
    print()
    print(f"Resultado: {success_count} sucesso, {fail_count} falhas")
    
    if fail_count > 0:
        print("\nAs migrações com falha precisam ser executadas manualmente no SQL Editor do Supabase.")
        print(f"Acesse: {SUPABASE_URL.replace('.supabase.co', '')}/project/default/sql")
        sys.exit(1)


if __name__ == "__main__":
    main()
