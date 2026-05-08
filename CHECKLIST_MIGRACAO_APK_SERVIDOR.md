# Checklist de Migração APK → Servidor — NexusHub

Autor: **Manus AI**  
Data de início: **2026-05-07**  
Escopo atualizado: **migração completa dos pontos do Mapa de Migração Futura para fontes remotas, com fallback local, validação real, rollback e redução progressiva do APK/AAB.**

## Princípios obrigatórios

Esta migração deve reduzir a necessidade de publicar novos APKs para ajustes operacionais, conteúdo textual, configurações e experimentos. A implementação deve preservar a experiência offline, manter fallback local, evitar acoplamento frágil e permitir rollback seguro. Nenhuma etapa iniciada deve permanecer incompleta; se uma alternativa apresentar risco técnico relevante, ela deve ser corrigida ou revertida antes de avançar.

| Princípio | Aplicação prática | Status |
|---|---|---|
| **Fallback local sempre disponível** | O app deve continuar funcional sem rede ou sem Supabase. | Obrigatório em todas as fases |
| **Mudança incremental e reversível** | Cada domínio deve ter flag, `is_active` ou fallback local. | Obrigatório em todas as fases |
| **Sem segredo no APK** | Cliente usa apenas dados públicos e anon key; mutações sensíveis ficam em RPC/servidor. | Obrigatório em todas as fases |
| **Validação antes de commit/push** | Todo código Dart/SQL precisa passar por checagens disponíveis e depois por Flutter real no CI/dev. | Em andamento |
| **Ordem de produção explícita** | Migration, seed, app, feature flag, teste e rollout devem estar documentados. | Atualizado no plano completo |
| **Sem redução prematura do APK** | Remover conteúdo do binário só depois de remoto estável e fallback mínimo testado. | Obrigatório |

## Auditoria do estado atual

A primeira entrega implementada é a infraestrutura inicial de **OTA Translations**. A abordagem massiva que alterava diretamente todos os arquivos `app_strings_*.dart` foi revertida por risco de diff excessivo, artefatos Unicode e dificuldade de revisão. A solução mantida é a arquitetura isolada `OtaAppStrings`, que implementa `AppStrings`, recebe a implementação local como fallback e aplica overlay remoto somente nos getters simples. Métodos parametrizados continuam delegando ao fallback local.

| Item auditado | Resultado | Decisão |
|---|---|---|
| Serviço `ota_translation_service.dart` | Criado com cache, lookup e fallback defensivo. | Manter e endurecer na Fase 1. |
| Migration `241_app_translations.sql` | Criada com tabela, policies, RPC e seed inicial. | Validar em staging antes de produção. |
| `app_strings_*.dart` | Alterações massivas revertidas. | Não tocar diretamente nesses arquivos. |
| `app_strings_ota.dart` | Wrapper gerado e isolado. | Manter como camada OTA. |
| `locale_provider.dart` | Integrado ao wrapper sem quebrar fallback local. | Validar com Flutter real. |
| `main.dart` | Inicializa OTA após serviços essenciais. | Validar impacto no boot. |
| Scripts `generate_ota_app_strings.py` e `validate_ota_translations.py` | Criados para geração e validação reexecutável. | Manter versionados. |
| Commit local `f23884b3` | Criado localmente; push pendente por autenticação. | Não promover sem validação Flutter real/staging. |

## Plano de arquitetura aprovado para seguir

A arquitetura aprovada é **remota por domínio, tipada e com fallback local**. Textos simples usam `app_translations`; configurações escalares usam `app_remote_config`; conteúdo estruturado usa tabelas próprias e RPCs de leitura; assets grandes devem migrar para Storage apenas depois de cache e fallback testados.

| Camada | Responsabilidade | Critério de pronto |
|---|---|---|
| Banco remoto | Armazenar dados ativos, versionados, com RLS e seed inicial. | Migration revisada e aplicada em staging. |
| RPCs/Remote Config | Expor dados públicos sem vazar regras sensíveis. | Resposta validada e compatível com fallback. |
| Serviços Flutter | Buscar, validar, cachear e fazer fallback. | Sem exceções fatais offline. |
| Providers/helpers | Entregar modelos tipados à UI. | UI não faz parsing remoto direto. |
| Feature flags | Permitir desligar remoto sem novo APK. | Flag off restaura comportamento local. |
| Documentação | Registrar ordem, rollback e evidências. | Checklist e plano atualizados por commit. |

## Checklist operacional — infraestrutura OTA já iniciada

| Etapa | Descrição | Status |
|---|---|---|
| 1 | Consolidar contexto do relatório e conversa anterior. | Concluído |
| 2 | Auditar alterações já iniciadas e identificar riscos. | Concluído |
| 3 | Criar checklist versionada e mantê-la atualizada. | Concluído |
| 4 | Reverter/refatorar abordagem massiva nos arquivos `app_strings_*.dart`. | Concluído |
| 5 | Gerar wrapper OTA isolado com fallback local. | Concluído |
| 6 | Revisar serviço `OtaTranslationService` para cache, inicialização, timeout e erro offline. | Concluído textualmente; pendente Flutter real |
| 7 | Revisar migration `241_app_translations.sql` para RLS, RPC e seed. | Concluído textualmente; pendente staging |
| 8 | Integrar wrapper no provider sem quebrar troca de idioma. | Concluído textualmente; pendente Flutter real |
| 9 | Executar validações disponíveis no ambiente. | Concluído |
| 10 | Atualizar plano de produção e rollback. | Concluído |
| 11 | Criar commit local. | Concluído |
| 12 | Fazer push. | Pendente autenticação GitHub e decisão após validação |

## Checklist mestre — cobertura completa do Mapa de Migração Futura

| ID | Domínio | Entrega obrigatória | Status | Observação |
|---|---|---|---|---|
| P0.1 | Baseline | Rodar `flutter analyze`, format e build interno. | Pendente | O ambiente atual não possui Flutter/Dart no PATH. |
| P0.2 | Banco | Aplicar `241_app_translations.sql` em staging. | Pendente | Não promover direto para produção. |
| P0.3 | OTA | Testar alteração real de uma string sem novo APK. | Pendente | Exige staging + build interno. |
| P1.1 | OTA | Buscar locale ativo primeiro e demais em background opcional. | Concluído textualmente; pendente Flutter real | Implementado em `OtaTranslationService.initialize(initialLocale:)` com prefetch via `unawaited`. |
| P1.2 | OTA | Criar flag `features.ota_translations_enabled`. | Aplicado e validado no Supabase remoto; pendente Flutter real | Getter em `RemoteConfigService` e migration `242_ota_translations_remote_config_flag.sql` aplicados no projeto `ylvzqqvcanzzswjkqeya`. |
| P1.3 | OTA | Criar fluxo admin/script seguro para editar traduções. | Pendente | Evita SQL manual arriscado. |
| P2.1 | Free Coins | Criar tabela/RPC `reward_tasks`. | Aplicado e validado no Supabase remoto; pendente teste no app | Migration `243_reward_tasks_free_coins.sql` aplicada no projeto `ylvzqqvcanzzswjkqeya`; tabela, RPC, grants, policies, seed PT/EN e flag confirmados. |
| P2.2 | Free Coins | Integrar tela via service/provider tipado. | Concluído textualmente; pendente Flutter real | `RewardTaskService`, `rewardTasksProvider` e `free_coins_screen.dart` refatorada sem parsing direto de Supabase para cards. |
| P2.3 | Free Coins | Fallback local e flag de rollback. | Aplicado e validado no Supabase remoto; pendente teste offline no app | Fallback em `RewardTaskService.fallbackRewardTasks` e flag `features.remote_reward_tasks_enabled` confirmada em `app_remote_config`. |
| P3.1 | Níveis | Criar tabela/RPC `level_definitions`. | Aplicado e validado no Supabase remoto; pendente teste no app | Migration `244_level_definitions.sql` aplicada no projeto `ylvzqqvcanzzswjkqeya`; tabela, RPC, grants, policies, seed multilíngue de 200 registros e flag confirmados. |
| P3.2 | Níveis | Integrar helpers/theme ao serviço central. | Concluído textualmente; pendente Flutter real | `LevelDefinitionService` inicializa no boot, `helpers.dart` usa thresholds/títulos centralizados e `AppTheme.getLevelColor()` usa cor remota com fallback local. |
| P3.3 | Níveis | Validar paridade visual com baseline. | Concluído textualmente; pendente teste visual em device/staging | Validação textual confirmou seed multilíngue, RPC, flag e integrações; falta `flutter analyze`, staging Supabase e comparação visual real. |
| P4.1 | Announcements | Usar/ajustar `system_announcements` para banners/manutenção. | Aplicado e validado no Supabase remoto; pendente teste no app | Migration `245_system_announcements_server_driven.sql` aplicada no projeto `ylvzqqvcanzzswjkqeya`; colunas v2, RPC `get_active_announcements_v2`, grants, policies, flag e RPC legada preservada foram confirmados remotamente. |
| P4.2 | Announcements | Implementar janela ativa, severidade e dismiss. | Concluído textualmente; pendente Flutter real | `AnnouncementService`, `activeAnnouncementsProvider` e `announcement_banner.dart` usam conteúdo remoto tipado, severidade visual, CTA, `dismissible` persistido e fallback local vazio. |
| P5.1 | Onboarding | Criar tabela/RPC `onboarding_slides`. | Aplicado e validado no Supabase remoto; pendente teste no app | Migration `246_onboarding_slides_server_driven.sql` aplicada no projeto `ylvzqqvcanzzswjkqeya`; tabela, RPC `get_onboarding_slides`, grants, policies, flag e seed multilíngue de 30 registros/10 locales confirmados remotamente. |
| P5.2 | Onboarding | Integrar provider com fallback local. | Concluído textualmente; pendente Flutter real | `OnboardingSlideService`, `onboardingSlidesProvider` e `onboarding_screen.dart` usam conteúdo remoto tipado, fallback local imediato e reagem ao locale ativo. |
| P5.3 | Onboarding | Preparar variante/A-B test. | Parcialmente preparado; pendente decisão de produto | Schema/RPC já aceitam `variant_key`, mantendo `default`; falta definir estratégia e governança de experimentos antes de ativar variantes reais. |
| P6.1 | Streaming | Migrar allowlist/blocklist para Remote Config ou tabela. | Aplicado e validado no Supabase remoto; pendente teste no app | Migration `247_streaming_rules_server_driven.sql` aplicada no projeto `ylvzqqvcanzzswjkqeya`; tabela, RPC `get_streaming_platform_rules`, grants, policies, flag e seed conservador de 17 plataformas confirmados remotamente. |
| P6.2 | Streaming | Integrar resolvedores a `StreamingRulesService`. | Concluído textualmente; pendente Flutter real | `StreamingRulesService`, `StreamResolverService`, `ScreeningRoomProvider` e `screening_browser_sheet.dart` validam URL original, aplicam allowlist/blocklist server-driven e preservam bypass controlado para URLs internas já resolvidas. |
| P7.1 | Cache | Criar `CachePolicyService` e chaves TTL remotas. | Aplicado e validado no Supabase remoto; pendente teste no app | Migration `248_cache_policies_remote_config.sql` aplicada no projeto `ylvzqqvcanzzswjkqeya`; flag `features.remote_cache_policies_enabled` e payload `cache.ttl_seconds` com chaves baseline foram confirmados remotamente. |
| P7.2 | Cache | Validar performance e fallback dos TTLs. | Concluído textualmente; pendente Flutter real | `CachePolicyService` centraliza TTLs remotos com limites mínimos/máximos, fallback local seguro e integração no `CacheService.isCacheExpired` sem quebrar chamadas com `maxAge` explícito. |
| P8.1 | Push | Versionar nomes/descrições de canais futuros. | Aplicado e validado no Supabase remoto; pendente teste no app | Migration `249_notification_channels_remote_config.sql` aplicada no projeto `ylvzqqvcanzzswjkqeya`; flag `features.remote_notification_channels_enabled`, payload `notifications.channels`, canais estáveis `nexushub_*` e mapeamento por tipo confirmados remotamente. |
| P9.1 | Admin | Criar scripts/admin operacional para conteúdo remoto. | Aplicado e validado no Supabase remoto; pendente teste manual no painel com usuário Team Admin | Migration `250_admin_remote_config_governance.sql` aplicada no projeto `ylvzqqvcanzzswjkqeya`; criada RPC `admin_update_remote_config` `SECURITY DEFINER`, tabela `app_remote_config_audit_log`, policy de leitura para equipe, grant para `authenticated` e `RemoteConfigPage` passou a criar/salvar configs via RPC auditável, sem mutação direta de `app_remote_config`. |
| P10.1 | APK/AAB | Medir tamanho baseline antes de reduzir. | Pendente | Métrica obrigatória. |
| P10.2 | APK/AAB | Remover payloads redundantes apenas após estabilidade. | Pendente | Redução real e segura. |

## Ordem correta para produção

| Ordem | Ação | Observação |
|---:|---|---|
| 0 | Validar o commit OTA atual com Flutter real e staging. | Não iniciar novas migrações sobre base não compilada. |
| 1 | Endurecer OTA Translations com flag, locale ativo e fluxo de edição. | Base para copy remota. |
| 2 | Migrar Free Coins para tabela/RPC/provider/fallback. | Primeiro item de alto impacto ainda pendente. |
| 3 | Migrar Level Definitions, incluindo títulos, faixas e cores. | Concluído textualmente; próximo bloqueio é Flutter real + staging Supabase para validar paridade visual. |
| 4 | Ativar System Announcements por servidor. | Concluído textualmente e aplicado no Supabase remoto; falta validação Flutter/device. |
| 5 | Migrar Onboarding com fallback e variantes. | Concluído textualmente e aplicado no Supabase remoto; falta validação Flutter/device e decisão de produto para variantes A/B reais. |
| 6 | Migrar Streaming Rules com allowlist conservadora. | Concluído textualmente e aplicado no Supabase remoto; falta validação Flutter/device. |
| 7 | Migrar Cache TTLs para política central remota. | Concluído textualmente e aplicado no Supabase remoto; falta validação Flutter/device. |
| 8 | Versionar canais push futuros. | Concluído textualmente e aplicado no Supabase remoto; falta validação Flutter/device, especialmente em Android com canais já criados. |
| 9 | Criar governança/admin operacional. | Concluído textualmente e aplicado no Supabase remoto; falta teste manual autenticado no painel com usuário Team Admin. |
| 10 | Reduzir APK/AAB com métrica antes/depois. | Só após estabilidade comprovada. |

## Observações abertas

Validação executada novamente após o hardening P0/P1: `python3.11 scripts/validate_ota_translations.py` retornou OK, com 3053 getters cobertos, 85 métodos delegados e 29950 linhas de seed. A migração Free Coins também passou por validação textual local, confirmando migration `reward_tasks`, RPC `get_reward_tasks`, feature flag `features.remote_reward_tasks_enabled`, provider tipado e ausência de parsing direto de Supabase na tela. A migração Level Definitions passou por validação textual local, confirmando migration `level_definitions`, RPC `get_level_definitions`, seed multilíngue de 20 níveis por idioma, feature flag `features.remote_level_definitions_enabled`, boot em `main.dart`, helpers centralizados e cores remotas no tema com fallback. A migração Streaming Rules passou por validação textual local e remota, confirmando migration `247_streaming_rules_server_driven.sql`, tabela `streaming_platform_rules`, RPC `get_streaming_platform_rules`, seed conservador de 17 plataformas, feature flag `features.remote_streaming_rules_enabled`, bloqueios de URL direta e integrações no resolvedor, provider da sala e browser sheet. A migração Cache TTL remoto passou por validação textual local e remota, confirmando migration `248_cache_policies_remote_config.sql`, flag `features.remote_cache_policies_enabled`, payload `cache.ttl_seconds`, baseline positivo de TTLs e integração central no `CacheService` via `CachePolicyService`. A migração Notification Channels passou por validação textual local e remota, confirmando migration `249_notification_channels_remote_config.sql`, flag `features.remote_notification_channels_enabled`, payload `notifications.channels`, canais estáveis `nexushub_default`, `nexushub_chat`, `nexushub_social`, `nexushub_community` e `nexushub_moderation`, mapeamento por tipo e integração central em `NotificationChannelConfigService`. A migração Admin Remote Config passou por validação textual local e remota, confirmando migration `250_admin_remote_config_governance.sql`, tabela `app_remote_config_audit_log`, RPC `admin_update_remote_config` `SECURITY DEFINER`, grant para `authenticated`, policy de leitura para equipe e alteração do `RemoteConfigPage` para criação/salvamento via RPC auditável sem mutação direta de `app_remote_config`. Em 07/05/2026, as migrations `242_ota_translations_remote_config_flag.sql`, `243_reward_tasks_free_coins.sql` e `244_level_definitions.sql` foram aplicadas no Supabase remoto do projeto `ylvzqqvcanzzswjkqeya` via Management API e validadas por consulta remota: `reward_tasks` contém 16 registros sem duplicatas, `level_definitions` contém 200 registros sem duplicatas, as RPCs são `SECURITY DEFINER`, os grants para `authenticated`, as policies de leitura/admin e as três flags em `app_remote_config` foram confirmadas. O ambiente atual não possui `dart` nem `flutter` no PATH, então a análise estática oficial do Flutter deve ser executada no CI ou em uma máquina de desenvolvimento antes de promover a build do app.

O plano completo de produção está documentado em `PLANO_ACAO_COMPLETO_APK_PARA_SERVIDOR_2026.md`. A conclusão atual é que a infraestrutura OTA criada é uma base correta, mas a migração completa do mapa ainda depende das fases P0 a P10 acima.
