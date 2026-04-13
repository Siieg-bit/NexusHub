# 📋 Guia de Aplicação de Migrations ao Supabase

## 🎯 Objetivo

Aplicar todas as 7 migrations do NexusHub v1.1.0 ao Supabase em produção.

---

## ⚠️ Pré-requisitos

1. **Acesso ao Supabase Dashboard**
   - URL: https://app.supabase.com
   - Projeto: ylvzqqvcanzzswjkqeya

2. **Backup do Banco**
   - Fazer backup antes de aplicar migrations
   - Comando: `pg_dump -h db.ylvzqqvcanzzswjkqeya.supabase.co -U postgres -d postgres > backup_$(date +%Y%m%d_%H%M%S).sql`

3. **Permissões**
   - Acesso como admin/owner do projeto
   - Permissão para executar DDL statements

---

## 🔄 Método 1: Via Supabase Dashboard (Recomendado)

### Passo 1: Acessar SQL Editor

1. Ir para https://app.supabase.com
2. Selecionar projeto "NexusHub"
3. Clicar em "SQL Editor" no menu esquerdo
4. Clicar em "New Query"

### Passo 2: Copiar e Executar Migrations

Para cada migration (098 a 103):

1. Abrir arquivo: `backend/supabase/migrations/0XX_*.sql`
2. Copiar todo o conteúdo
3. Colar no SQL Editor
4. Clicar em "Run" (ou Ctrl+Enter)
5. Verificar se executou sem erros

### Passo 3: Verificar Resultados

Após cada migration:

```sql
-- Verificar tabelas criadas
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- Verificar funções criadas
SELECT routine_name FROM information_schema.routines 
WHERE routine_schema = 'public' 
ORDER BY routine_name;

-- Verificar policies
SELECT * FROM pg_policies 
WHERE schemaname = 'public' 
ORDER BY tablename, policyname;
```

---

## 🔄 Método 2: Via Supabase CLI (Alternativo)

### Instalação do CLI

```bash
# macOS
brew install supabase/tap/supabase

# Linux
curl -fsSL https://raw.githubusercontent.com/supabase/cli/main/install.sh | sh

# Windows
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
```

### Aplicar Migrations

```bash
# Login
supabase login

# Listar migrations
supabase migration list --project-ref ylvzqqvcanzzswjkqeya

# Aplicar todas as migrations
supabase migration up --project-ref ylvzqqvcanzzswjkqeya

# Ou aplicar migration específica
supabase migration up --version 098 --project-ref ylvzqqvcanzzswjkqeya
```

---

## 📝 Ordem de Aplicação

As migrations devem ser aplicadas **nesta ordem**:

| # | Migration | Dependências | Tempo Est. |
|---|-----------|--------------|-----------|
| 1 | 098_fix_quiz_system.sql | Nenhuma | 30s |
| 2 | 099_chat_forms_support.sql | Nenhuma | 30s |
| 3 | 100_improve_drafts_system.sql | Nenhuma | 30s |
| 4 | 101_fix_wiki_system.sql | Nenhuma | 20s |
| 5 | 102_community_visual_enhancements.sql | Nenhuma | 20s |
| 6 | 103_smart_links_system.sql | Nenhuma | 30s |

**Tempo Total Estimado**: ~3 minutos

---

## ✅ Checklist de Validação

Após aplicar cada migration, validar:

### Migration 098: Quiz System

```sql
-- Verificar tabela
SELECT * FROM information_schema.tables 
WHERE table_name = 'quiz_answers';

-- Verificar RPC
SELECT routine_name FROM information_schema.routines 
WHERE routine_name LIKE 'answer_quiz%';

-- Verificar policies
SELECT policyname FROM pg_policies 
WHERE tablename = 'quiz_answers';

-- Verificar índices
SELECT indexname FROM pg_indexes 
WHERE tablename = 'quiz_answers';
```

### Migration 099: Chat Forms

```sql
-- Verificar tabelas
SELECT table_name FROM information_schema.tables 
WHERE table_name LIKE 'chat_form%';

-- Verificar enum
SELECT enum_range(NULL::chat_message_type);

-- Verificar RPCs
SELECT routine_name FROM information_schema.routines 
WHERE routine_name LIKE 'create_chat_form%' 
OR routine_name LIKE 'respond_to_chat_form%';
```

### Migration 100: Drafts System

```sql
-- Verificar colunas adicionadas
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'post_drafts' 
AND column_name LIKE 'draft_%';

-- Verificar RPCs
SELECT routine_name FROM information_schema.routines 
WHERE routine_name LIKE 'save_draft%' 
OR routine_name LIKE 'get_draft%';
```

### Migration 101: Wiki System

```sql
-- Verificar coluna
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'posts' 
AND column_name = 'wiki_data';

-- Verificar RPC
SELECT routine_name FROM information_schema.routines 
WHERE routine_name = 'create_wiki_entry';
```

### Migration 102: Community Visuals

```sql
-- Verificar colunas
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'communities' 
AND column_name LIKE 'cover_%' 
OR column_name LIKE 'theme_%';

-- Verificar RPCs
SELECT routine_name FROM information_schema.routines 
WHERE routine_name LIKE 'update_community_visuals%' 
OR routine_name LIKE 'get_my_communities%';
```

### Migration 103: Smart Links

```sql
-- Verificar tabelas
SELECT table_name FROM information_schema.tables 
WHERE table_name LIKE 'smart_links%' 
OR table_name = 'link_usages';

-- Verificar RPCs
SELECT routine_name FROM information_schema.routines 
WHERE routine_name LIKE 'detect_and_save_link%' 
OR routine_name LIKE 'get_link_preview%';
```

---

## 🔍 Validação Completa

Após aplicar todas as migrations:

```sql
-- Contar tabelas criadas
SELECT COUNT(*) FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('quiz_answers', 'chat_forms', 'chat_form_responses', 'smart_links', 'link_usages');

-- Contar RPCs
SELECT COUNT(*) FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN (
  'answer_quiz', 'create_chat_form', 'respond_to_chat_form',
  'save_draft', 'get_drafts', 'get_draft', 'delete_draft',
  'create_wiki_entry', 'update_community_visuals', 'get_my_communities',
  'detect_and_save_link', 'get_link_preview', 'update_link_metadata',
  'track_link_click', 'get_popular_links'
);

-- Contar policies
SELECT COUNT(*) FROM pg_policies 
WHERE schemaname = 'public';

-- Contar índices
SELECT COUNT(*) FROM pg_indexes 
WHERE schemaname = 'public' 
AND indexname LIKE 'idx_%';
```

**Valores Esperados**:
- Tabelas: 5
- RPCs: 19
- Policies: 9
- Índices: 24+

---

## ⚠️ Troubleshooting

### Erro: "relation already exists"

**Causa**: Tabela ou função já existe

**Solução**: 
```sql
-- Verificar se existe
SELECT * FROM information_schema.tables 
WHERE table_name = 'quiz_answers';

-- Se existir, pode ignorar o erro
-- As migrations usam "IF NOT EXISTS"
```

### Erro: "permission denied"

**Causa**: Permissões insuficientes

**Solução**:
```sql
-- Verificar permissões
SELECT * FROM information_schema.role_table_grants 
WHERE grantee = 'authenticated';

-- Conceder permissões
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
```

### Erro: "foreign key constraint failed"

**Causa**: Referência a tabela que não existe

**Solução**:
1. Verificar ordem de aplicação
2. Verificar se todas as migrations anteriores foram aplicadas
3. Verificar se tabelas referenciadas existem

### Erro: "type already exists"

**Causa**: ENUM já existe

**Solução**:
```sql
-- Verificar enum
SELECT enum_range(NULL::chat_message_type);

-- Se existir, pode ignorar
-- A migration usa "IF NOT EXISTS"
```

---

## 🔄 Rollback (Se Necessário)

Se algo der errado, fazer rollback:

```bash
# Via CLI
supabase migration down --version 103

# Ou via SQL Editor
DROP FUNCTION IF EXISTS public.detect_and_save_link;
DROP FUNCTION IF EXISTS public.get_link_preview;
DROP TABLE IF EXISTS public.smart_links;
DROP TABLE IF EXISTS public.link_usages;
-- ... etc
```

---

## 📊 Monitoramento Pós-Aplicação

Após aplicar todas as migrations:

### Verificar Performance

```sql
-- Verificar tamanho das tabelas
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('quiz_answers', 'chat_forms', 'smart_links', 'post_drafts')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Verificar índices
SELECT 
  schemaname,
  tablename,
  indexname,
  pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_indexes
WHERE schemaname = 'public'
AND tablename IN ('quiz_answers', 'chat_forms', 'smart_links')
ORDER BY pg_relation_size(indexrelid) DESC;
```

### Verificar Logs

```bash
# Via Supabase Dashboard
# Ir para: Database > Logs

# Ou via CLI
supabase logs tail --project-ref ylvzqqvcanzzswjkqeya
```

---

## ✅ Checklist Final

- [ ] Backup do banco realizado
- [ ] Migration 098 aplicada com sucesso
- [ ] Migration 099 aplicada com sucesso
- [ ] Migration 100 aplicada com sucesso
- [ ] Migration 101 aplicada com sucesso
- [ ] Migration 102 aplicada com sucesso
- [ ] Migration 103 aplicada com sucesso
- [ ] Todas as validações passaram
- [ ] Testes de integração executados
- [ ] Performance monitorada
- [ ] Logs verificados
- [ ] Pronto para produção

---

## 📞 Suporte

Para problemas:
1. Consultar AUDIT_REPORT.md
2. Consultar DEPLOYMENT_GUIDE.md
3. Verificar logs do Supabase
4. Abrir issue no GitHub

---

**Data**: 13 de Abril de 2026  
**Versão**: 1.0.0  
**Status**: Pronto para Aplicação 🚀
