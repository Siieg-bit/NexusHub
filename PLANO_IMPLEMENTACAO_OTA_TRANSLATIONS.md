# Plano de Implementação — OTA Translations

**Autor:** Manus AI  
**Data:** 07 de Maio de 2026  
**Status:** Implementado no código e validado textualmente no ambiente atual. A promoção para produção depende de `flutter analyze`, testes do app e aplicação controlada da migration.

## Decisão técnica

A migração adotada é **OTA Translations incremental com wrapper isolado**, porque ela entrega o objetivo central de permitir correções e ajustes de texto sem publicar novo APK, mas mantém o aplicativo resiliente para uso offline. A solução inicial **não remove** as strings locais do APK, pois elas continuam sendo fallback obrigatório para boot, falha de rede, cache frio e rollback. Em vez de alterar milhares de getters diretamente nos arquivos `app_strings_*.dart`, foi criado um wrapper `OtaAppStrings` que implementa a mesma interface `AppStrings` e consulta o servidor antes de devolver o fallback local.

## Arquitetura final

| Camada | Implementação | Responsabilidade | Critério de produção |
|---|---|---|---|
| Banco | `public.app_translations` | Armazenar `locale`, `key`, `value`, categoria e auditoria básica. | Migration idempotente com `ON CONFLICT`. |
| RPC | `public.get_app_translations(p_locale TEXT)` | Retornar um JSON por idioma para reduzir round-trips do app. | `SECURITY DEFINER`, `search_path = public`, grant para `anon` e `authenticated`. |
| Serviço Flutter | `OtaTranslationService` | Carregar traduções, salvar cache local e oferecer lookup estático. | Timeout por idioma, fetch paralelo, fallback de cache e sem crash no boot. |
| L10n | `OtaAppStrings` | Cobrir todos os getters simples com overlay remoto e delegar métodos parametrizados. | 3053 getters cobertos e 85 métodos delegados. |
| Provider | `locale_provider.dart` | Retornar o wrapper OTA no `stringsProvider` mantendo fallback local separado. | Troca de idioma preservada e reversível. |
| Boot | `main.dart` | Inicializar OTA após Supabase e Remote Config. | Falhas tratadas por `_initSafe`, sem bloquear indefinidamente. |

## Escopo entregue nesta etapa

Esta etapa cobre os **getters simples de localização**. Esses textos passam a ser editáveis por servidor e cacheados no dispositivo. Os **métodos parametrizados** continuam delegados ao fallback local para preservar interpolação, pluralização e regras gramaticais de cada idioma. Essa escolha evita regressão linguística e mantém a porta aberta para uma segunda fase com placeholders versionados, quando houver painel/admin e validação semântica para traduções com parâmetros.

## Por que não alterar diretamente os arquivos de idioma

A primeira tentativa automática de modificar todos os `app_strings_*.dart` foi revertida porque criava um diff massivo, difícil de revisar e com maior risco de regressão. A arquitetura final é mais limpa: os arquivos de idioma empacotados permanecem fonte canônica offline, enquanto a camada OTA atua como overlay. Isso melhora revisão, rollback, manutenção e compatibilidade com o contrato atual.

## Ordem correta para produção

| Ordem | Ação | Responsável | Critério de aceite |
|---:|---|---|---|
| 1 | Revisar PR/diff da branch. | Desenvolvimento | Confirmar que apenas wrapper, serviço, provider, boot, migration, checklist e scripts de geração/validação foram alterados. |
| 2 | Executar `flutter analyze` e testes automatizados. | Desenvolvimento/CI | Zero erros críticos. Warnings devem ser avaliados antes do merge. |
| 3 | Aplicar a migration `241_app_translations.sql` em staging. | Backend | Tabela, policies e RPC criadas; `select public.get_app_translations('pt')` retorna JSON com chaves. |
| 4 | Buildar APK/AAB de staging. | Mobile | App abre offline e online; idioma troca corretamente; textos aparecem mesmo sem rede. |
| 5 | Alterar uma chave em staging, por exemplo `pt.ok`. | QA/Admin | Após restart ou novo fetch, UI reflete a alteração sem novo APK; cache preserva último valor baixado. |
| 6 | Aplicar migration em produção. | Backend | Sem erros SQL e sem queda de APIs existentes. |
| 7 | Publicar build com OTA habilitado em rollout gradual. | Release | Monitorar crash rate, tempo de boot, logs de `OtaTranslations` e feedback de idioma. |
| 8 | Criar painel/admin de traduções. | Produto/Dev | Equipe consegue editar textos com permissões, auditoria e validação. |
| 9 | Planejar redução real de peso do APK. | Arquitetura | Migrar conteúdos maiores e assets configuráveis, não apenas strings curtas. |

## Rollback

| Cenário | Rollback recomendado | Impacto |
|---|---|---|
| Falha de rede ou Supabase indisponível | Nenhuma ação; app usa cache ou fallback local. | Sem crash esperado. |
| Tradução remota incorreta | Atualizar ou desativar chave no banco. | Correção sem novo APK. |
| Problema no serviço OTA do app | Remover inicialização em `main.dart` e retornar `fallback` direto no provider em hotfix. | App volta ao comportamento anterior. |
| Problema na migration | Desativar policies/RPC ou marcar linhas como `is_active = FALSE`. | Fallback local continua funcionando. |

## Validações executadas neste ambiente

| Validação | Resultado |
|---|---|
| `python3.11 scripts/validate_ota_translations.py` | OK. |
| Cobertura do wrapper | 3053 getters de 3053 cobertos. |
| Métodos parametrizados | 85 de 85 delegados ao fallback local. |
| Seed SQL | 29950 linhas de tradução inicial. |
| Artefatos binários | Nenhum byte NUL detectado nos arquivos críticos. |
| Dart/Flutter no ambiente | Não disponível no PATH; precisa rodar no CI/dev antes de produção. |

## Próximas evoluções recomendadas

A próxima evolução lógica é criar um **painel administrativo de traduções** com permissões de equipe, busca por chave, histórico de alterações, preview por idioma e validação de placeholders. Depois disso, a equipe pode evoluir para **Remote Content/Assets**, migrando conteúdos maiores, catálogos, banners, textos longos, configurações de onboarding e recursos de eventos sazonais para servidor/CDN. Essa segunda etapa é a que realmente reduz peso do APK; OTA Translations melhora agilidade de atualização e governança textual.
