# Guia de Deployment - NexusHub

## 🚀 Pré-requisitos

- Supabase CLI instalado: `npm install -g supabase`
- Acesso ao projeto Supabase
- Token de acesso do Supabase
- Flutter SDK atualizado

## 📋 Migrations Pendentes

As seguintes migrations foram criadas e precisam ser aplicadas ao Supabase:

| # | Nome | Descrição | Status |
|---|------|-----------|--------|
| 098 | Fix Quiz System | Tabela quiz_answers e RPC answer_quiz | ⏳ Pendente |
| 099 | Chat Forms Support | Tipo form no enum e tabelas de formulários | ⏳ Pendente |
| 100 | Improve Drafts System | RPCs save_draft, get_drafts, get_draft, delete_draft | ⏳ Pendente |
| 101 | Fix Wiki System | RPC create_wiki_entry com validações | ⏳ Pendente |
| 102 | Community Visual Enhancements | Capa, cores de tema e RPCs de comunidades | ⏳ Pendente |
| 103 | Smart Links System | Tabelas smart_links, link_usages e RPCs | ⏳ Pendente |

## 🔧 Passos para Deployment

### 1. Sincronizar Migrations com Supabase

```bash
# Navegar para o diretório do projeto
cd /home/ubuntu/NexusHub

# Fazer login no Supabase
supabase login

# Listar migrations pendentes
supabase migration list

# Aplicar todas as migrations
supabase migration up

# Ou aplicar migration específica
supabase migration up --version 098
```

### 2. Verificar Status das Migrations

```bash
# Ver migrations aplicadas
supabase migration list --status applied

# Ver migrations pendentes
supabase migration list --status pending

# Ver detalhes de uma migration
supabase migration info 098
```

### 3. Validar RPCs no Banco

```sql
-- Conectar ao Supabase SQL Editor e executar:

-- Verificar se RPC answer_quiz existe
SELECT routine_name FROM information_schema.routines 
WHERE routine_name = 'answer_quiz';

-- Verificar se tabela quiz_answers existe
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_name = 'quiz_answers'
);

-- Verificar se tipo 'form' existe no enum
SELECT enum_range(NULL::chat_message_type);
```

### 4. Testar RPCs Localmente

```bash
# Iniciar Supabase localmente
supabase start

# Executar testes de RPC
flutter test test/features/quiz/
flutter test test/features/chat/
flutter test test/features/feed/
```

### 5. Deploy para Produção

```bash
# Build do Flutter
flutter build apk --release  # Android
flutter build ios --release  # iOS
flutter build web --release  # Web

# Upload para stores
# - Google Play Store (Android)
# - Apple App Store (iOS)
# - Firebase Hosting (Web)
```

## 🔐 Variáveis de Ambiente

Certifique-se de que as seguintes variáveis estão configuradas:

```bash
# Supabase
SUPABASE_URL=https://ylvzqqvcanzzswjkqeya.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Firebase (se usar)
FIREBASE_PROJECT_ID=...
FIREBASE_API_KEY=...
```

## 📊 Checklist de Deployment

- [ ] Todas as migrations aplicadas com sucesso
- [ ] RPCs testadas e funcionando
- [ ] RLS policies verificadas
- [ ] Índices criados para performance
- [ ] Backups do banco realizados
- [ ] Testes de integração passando
- [ ] Performance otimizada (Lighthouse 85+)
- [ ] Segurança auditada
- [ ] Documentação atualizada
- [ ] Logs e monitoring ativados

## 🐛 Troubleshooting

### Migration falha com erro de constraint

```sql
-- Verificar constraints existentes
SELECT constraint_name FROM information_schema.table_constraints
WHERE table_name = 'posts' AND constraint_type = 'FOREIGN KEY';

-- Remover constraint se necessário
ALTER TABLE posts DROP CONSTRAINT constraint_name;
```

### RPC não encontrada

```sql
-- Listar todas as funções
SELECT routine_name FROM information_schema.routines
WHERE routine_schema = 'public';

-- Recriar RPC
CREATE OR REPLACE FUNCTION public.function_name(...) ...
```

### Erro de permissão em RPC

```sql
-- Verificar grants
SELECT grantee, privilege_type 
FROM information_schema.role_table_grants
WHERE table_name = 'posts';

-- Conceder permissão
GRANT EXECUTE ON FUNCTION public.answer_quiz(...) TO authenticated;
```

## 📈 Monitoramento Pós-Deploy

### Logs

```bash
# Ver logs de erro
supabase logs tail --project-ref ylvzqqvcanzzswjkqeya

# Filtrar por função
supabase logs tail --project-ref ylvzqqvcanzzswjkqeya --function answer_quiz
```

### Métricas

- Tempo de resposta das RPCs
- Taxa de erro das migrations
- Uso de storage
- Conexões ativas
- Queries lentas

### Alertas Recomendados

- Erro em RPC > 1% de requisições
- Tempo de resposta > 1s
- Storage > 80% da quota
- Conexões > 100 simultâneas

## 🔄 Rollback

Se algo der errado, é possível fazer rollback:

```bash
# Listar migrations aplicadas
supabase migration list

# Fazer rollback de uma migration
supabase migration down --version 103

# Ou fazer rollback de todas
supabase migration down --all
```

## 📚 Documentação Adicional

- [Supabase Migrations](https://supabase.com/docs/guides/cli/local-development#migrations)
- [RLS Policies](https://supabase.com/docs/guides/auth/row-level-security)
- [Flutter Deployment](https://flutter.dev/docs/deployment)

## 📞 Suporte

Para problemas com deployment:
1. Verificar logs do Supabase
2. Consultar documentação oficial
3. Abrir issue no repositório GitHub

---

**Última Atualização**: 13 de Abril de 2026
**Versão**: 1.0.0
**Status**: Pronto para Deploy 🚀
