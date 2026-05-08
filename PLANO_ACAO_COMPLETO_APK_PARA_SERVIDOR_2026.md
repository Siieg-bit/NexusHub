# Plano de Ação Completo — Migração APK → Servidor NexusHub 2026

Autor: **Manus AI**  
Data: **2026-05-07**  
Escopo: transformar o Mapa de Migração Futura em um plano executável de produção, cobrindo todos os itens ainda hardcoded no APK, com arquitetura, ordem de execução, critérios de aceite, validações e rollback.

## 1. Objetivo de produção

O objetivo desta migração não é apenas criar uma base técnica; é levar o NexusHub a um modelo em que **conteúdo operacional, copy, regras visuais, recompensas, onboarding, domínios permitidos e parâmetros de cache possam ser atualizados pelo servidor**, sem obrigar o usuário final a instalar um novo APK. A redução real do APK virá em fases controladas, depois que os payloads remotos estiverem validados, cacheados e com fallback mínimo confiável.

> Definição de pronto global: a migração só pode ser considerada completa quando todos os itens do Mapa de Migração Futura estiverem cobertos por **fonte remota versionada**, **fallback local seguro**, **validação automatizada**, **teste de staging**, **rollback documentado** e **ordem operacional clara para produção**.

A primeira implementação já criada, `f23884b3 — feat: add OTA translations infrastructure`, deve ser tratada como **Fase 1A: infraestrutura inicial de OTA Translations**, não como conclusão total do mapa. Ela é uma fundação válida, mas precisa ser endurecida, validada com Flutter real e complementada pelas migrações restantes.

## 2. Princípios obrigatórios

Esta execução deve seguir os princípios da skill NexusHub: responsabilidade na camada correta, nenhuma gambiarra, migrations versionadas, RPCs seguras quando houver mutação, fallback defensivo e decisão explícita quando houver impacto de produto. A UI não deve compensar ausência de modelo; telas consomem serviços e providers, serviços consomem RPCs/configurações, e regras de negócio sensíveis devem estar no banco ou em serviços dedicados.

| Princípio | Aplicação neste plano | Critério de aceite |
|---|---|---|
| **Sem gambiarra** | Nada de queries extras em telas para buscar configurações; toda configuração remota deve passar por serviço/provider tipado. | Nenhuma tela contém lógica de parsing remoto complexa. |
| **Fallback local obrigatório** | Todo payload remoto tem valor local mínimo para offline, cold start e falha Supabase. | App abre e opera offline sem crash. |
| **Migração incremental** | Cada domínio terá migration, serviço, integração e teste próprios. | Nenhuma fase depende de mudança incompleta de outra. |
| **Rollback simples** | Toda feature remota tem `enabled`, `schema_version`, `updated_at` e fallback. | Desligar remoto restaura comportamento local. |
| **Produção com staging primeiro** | Nenhuma migration entra em produção antes de staging validar build, RPC e cold start. | Evidências registradas antes do rollout. |
| **Redução real só após confiança** | Remover payloads do APK apenas depois de métricas e fallback mínimo. | Não sacrificar experiência offline por redução prematura. |

## 3. Arquitetura final recomendada

A arquitetura recomendada usa três classes de fonte remota. Para valores escalares e listas simples, o projeto deve continuar aproveitando `app_remote_config`, pois ele já é o centro de configuração operacional. Para conteúdo estruturado, ordenável ou testável por variação, devem ser criadas tabelas próprias com RPCs de leitura. Para localização, a infraestrutura OTA deve ser mantida e otimizada por locale, com seed inicial e fallback local.

| Tipo de dado | Fonte recomendada | Exemplos | Motivo |
|---|---|---|---|
| **Configuração simples** | `app_remote_config` | TTLs, domínios permitidos, cores de nível, nomes de canais push. | Menor custo de schema e já existe padrão no app. |
| **Conteúdo estruturado** | Tabelas dedicadas + RPC de leitura | Free Coins tasks, onboarding slides, level titles por locale. | Precisa ordenação, status, versionamento e validação. |
| **Textos simples de UI** | `app_translations` + `OtaAppStrings` | Labels, mensagens e copy geral. | Permite correções rápidas sem APK e fallback local. |
| **Banners/comunicados** | `system_announcements` existente | Broadcast, manutenção, avisos globais. | O mapa já indica tabela existente. |
| **Assets grandes futuros** | Supabase Storage + metadados em tabela | Imagens remotas de onboarding, ilustrações e campanhas. | Redução real do APK sem bloquear abertura offline. |

## 4. Fases executivas completas

### Fase 0 — Preparação, CI e baseline obrigatório

Antes de expandir a migração, o commit local de OTA deve passar por validação real. O ambiente atual validou textualmente, mas não tinha `flutter`/`dart` no PATH. Portanto, a primeira fase operacional é garantir que o repositório tenha uma trilha confiável de análise, build e staging.

| Entrega | Arquivos/ações | Critério de pronto | Rollback |
|---|---|---|---|
| CI ou validação local Flutter | `flutter pub get`, `dart format --set-exit-if-changed`, `flutter analyze`, build Android interno. | Build compila sem erros e sem novos warnings críticos. | Reverter commit OTA ou corrigir antes do push. |
| Staging Supabase | Aplicar `241_app_translations.sql` em staging. | RPC retorna JSON por locale e app usa fallback offline. | Desabilitar uso OTA no app ou reverter migration em staging. |
| Checklist mestre | Atualizar `CHECKLIST_MIGRACAO_APK_SERVIDOR.md`. | Checklist reflete estado real por fase. | N/A. |

### Fase 1 — OTA Translations completo e pronto para produção

A infraestrutura atual cobre getters simples, mas precisa ser finalizada como produto de produção. O serviço deve buscar primeiro o locale ativo, evitar carregar todos os idiomas no boot, ter telemetria mínima de falhas e permitir uma estratégia futura para reduzir o APK sem perder fallback.

| Subfase | Implementação | Critério de pronto |
|---|---|---|
| 1.1 Hardening do serviço | Ajustar `OtaTranslationService` para buscar locale ativo primeiro; pré-carregar demais idiomas em background opcional. | Cold start não degrada perceptivelmente e app não trava sem rede. |
| 1.2 Feature flag | Criar chave `features.ota_translations_enabled` no Remote Config. | Desligar flag faz app usar apenas fallback local. |
| 1.3 Admin operacional | Definir fluxo seguro para editar traduções: SQL controlado, painel admin ou RPC admin. | Equipe consegue alterar uma string em staging sem deploy. |
| 1.4 Validação de paridade | Script compara traduções locais x seed remoto por locale/key. | 100% dos getters simples mapeados ou justificativa documentada. |
| 1.5 Redução planejada do APK | Depois de 1–2 releases estáveis, gerar bundle com fallback mínimo por locale principal e traduções remotas para demais. | Redução mensurada no tamanho final do APK/AAB sem quebrar offline básico. |

### Fase 2 — Free Coins remoto e recompensas atualizáveis

Os cards e textos de recompensa têm impacto direto em retenção e monetização, então devem sair do APK com modelo estruturado, não apenas strings soltas. A solução mais limpa é criar uma tabela `reward_tasks` ou equivalente, com campos de copy, valores, ordenação, status, locale e regras.

| Campo sugerido | Tipo | Finalidade |
|---|---|---|
| `id` | UUID | Identidade estável da task. |
| `code` | text unique | Chave lógica como `create_post`, `comment_posts`, `invite_friends`. |
| `locale` | text | Localização do título/descrição. |
| `title` | text | Título exibido no card. |
| `description` | text | Explicação da ação. |
| `reward_label` | text | Texto como `+5–25`, `+10–100`. |
| `min_reward` / `max_reward` | integer | Valores estruturados para lógica futura. |
| `icon_key` | text | Ícone local permitido, evitando asset remoto obrigatório. |
| `sort_order` | integer | Ordem no app. |
| `is_active` | boolean | Ativação sem APK. |
| `schema_version` | integer | Compatibilidade entre app e servidor. |

A UI `free_coins_screen.dart` deve consumir um provider tipado, por exemplo `rewardTasksProvider`, que carrega via RPC `get_reward_tasks(locale)` e cai para uma lista local mínima. O app não deve calcular economia sensível apenas a partir do client; caso recompensas reais sejam concedidas por interação, a validação deve continuar em RPC server-side.

| Etapa | Critério de aceite | Validação |
|---|---|---|
| Criar migration e seed inicial dos cards atuais. | Cards atuais aparecem idênticos via servidor. | Teste snapshot/manual da tela. |
| Implementar serviço/provider. | Tela não contém parsing direto de Supabase. | Code review. |
| Criar fallback local. | Free Coins abre offline. | Teste sem rede. |
| Testar alteração remota. | Alterar `reward_label` em staging aparece sem novo APK. | Teste em build interno. |
| Criar flag `features.remote_reward_tasks_enabled`. | Rollback por config. | Flag off restaura fallback. |

### Fase 3 — Níveis: títulos, faixas e cores remotos

Títulos de nível e cores devem ser migrados juntos para evitar inconsistência visual. A melhor modelagem é uma tabela `level_definitions`, porque cores, faixas, nomes e possíveis thresholds pertencem ao mesmo domínio de progressão.

| Campo sugerido | Tipo | Finalidade |
|---|---|---|
| `level_min` / `level_max` | integer | Faixa de níveis. |
| `title_key` | text | Chave textual ou título por locale. |
| `locale` | text | Idioma do título. |
| `color_hex` | text | Cor principal da faixa. |
| `gradient_hex` | jsonb | Futuro suporte a gradientes/badges. |
| `sort_order` | integer | Ordem estável. |
| `is_active` | boolean | Rollback e testes. |
| `schema_version` | integer | Compatibilidade. |

`helpers.dart` e `app_theme.dart` devem passar a consumir um `LevelDefinitionService` ou provider global com cache. O fallback local deve conter os 20 títulos e 9 cores atuais. A UI nunca deve buscar Supabase diretamente para resolver cor/título; deve chamar um helper ou serviço já hidratado.

| Etapa | Critério de aceite | Rollback |
|---|---|---|
| Migration `level_definitions` + seed atual. | Paridade com níveis atuais. | Flag off usa constantes locais. |
| Serviço de cache e provider. | Títulos/cores resolvidos por domínio central. | Fallback local. |
| Substituir chamadas hardcoded. | `getLevelColor()` e title lookup usam serviço/helper remoto. | Manter fallback embutido. |
| Teste visual. | Cores e nomes idênticos ao baseline. | Reverter flag. |

### Fase 4 — Onboarding remoto com suporte a testes A/B

Onboarding deve ser migrado para uma tabela `onboarding_slides`, pois envolve ordem, título, descrição, imagem, CTA, segmentação e testes. Imagens podem continuar locais no começo via `asset_key`; depois podem migrar para Supabase Storage com cache.

| Campo sugerido | Tipo | Finalidade |
|---|---|---|
| `id` | UUID | Identidade do slide. |
| `locale` | text | Idioma. |
| `title` / `description` | text | Copy do slide. |
| `image_asset_key` | text | Fallback local. |
| `image_url` | text nullable | Imagem remota futura. |
| `cta_label` | text | Texto do botão. |
| `variant` | text | A/B test, ex. `control`, `retention_v2`. |
| `sort_order` | integer | Ordem. |
| `is_active` | boolean | Ativação. |
| `min_app_version` | text | Compatibilidade. |

| Etapa | Critério de aceite |
|---|---|
| Criar tabela/RPC `get_onboarding_slides(locale, variant)`. | Retorna slides ativos ordenados. |
| Seed com slides atuais. | Onboarding permanece visualmente igual. |
| Provider com fallback local. | App novo abre onboarding offline. |
| Feature flag e variante. | Equipe testa nova copy sem APK. |
| Cache de imagens remotas futuro. | Imagem remota não bloqueia abertura. |

### Fase 5 — System Announcements operacional

O mapa indica que `system_announcements` já existe ou deve ser usada. A migração aqui é garantir que os textos de broadcast/manutenção saiam de `app_strings.dart` e sejam dirigidos por dados ativos no servidor. O app deve exibir banners ou modais com janela de tempo, severidade e segmentação.

| Campo recomendado | Finalidade |
|---|---|
| `title`, `body`, `locale` | Conteúdo localizado. |
| `severity` | `info`, `warning`, `maintenance`, `critical`. |
| `starts_at`, `ends_at` | Janela ativa. |
| `target_audience` | Todos, versão mínima, plataforma ou comunidade. |
| `dismissible` | Permite fechar. |
| `is_active` | Rollback operacional. |

Critério de pronto: textos genéricos de manutenção em `AppStrings` continuam como fallback, mas banners reais vêm da tabela. O app deve lidar com ausência de anúncio sem erro e deve cachear o último anúncio ativo apenas se fizer sentido para UX.

### Fase 6 — Domínios de streaming remotos

Domínios permitidos e regras de embed devem migrar para Remote Config ou tabela `streaming_domain_rules`. Como este domínio afeta segurança e conteúdo externo, a leitura deve ser conservadora: se a configuração remota falhar, usar allowlist local segura, nunca permissiva.

| Chave/campo | Exemplo | Critério |
|---|---|---|
| `features.allowed_stream_domains` | `youtube.com`, `youtu.be`, `twitch.tv`, `crunchyroll.com` | Lista validada e normalizada. |
| `features.blocked_stream_domains` | domínios removidos emergencialmente | Bloqueio prevalece sobre permitido. |
| `provider` | `youtube`, `twitch`, `crunchyroll` | Mapeia serviço resolvedor. |
| `embed_strategy` | `iframe`, `hls`, `native` | Evita inferência frágil no client. |

Critério de pronto: `stream_resolver_service.dart` deixa de conter a fonte primária de domínios e passa a consultar um serviço de regras. O fallback local contém apenas provedores confiáveis atuais. O rollback é desligar `features.remote_stream_rules_enabled`.

### Fase 7 — Cache TTLs remotos

TTL hardcoded deve migrar para Remote Config tipado. A solução deve centralizar parsing em `CachePolicyService`, para evitar `Duration(...)` espalhado pela base.

| Chave | Valor inicial sugerido | Uso |
|---|---:|---|
| `cache.ttl.default_seconds` | 300 | Fallback global atual de 5 minutos. |
| `cache.ttl.remote_config_seconds` | 300 | Revalidação de config. |
| `cache.ttl.translations_seconds` | 86400 | Traduções mudam pouco. |
| `cache.ttl.onboarding_seconds` | 3600 | Testes e campanhas. |
| `cache.ttl.streaming_rules_seconds` | 1800 | Regras externas podem mudar. |
| `cache.ttl.reward_tasks_seconds` | 900 | Campanhas de recompensa. |

Critério de pronto: `cache_service.dart` aceita política injetada ou consulta serviço central, mantendo fallback local. Nenhum parse de TTL deve estar em tela.

### Fase 8 — Nomes de canais push remotos, com cautela

Este item é baixa prioridade porque canais Android têm limitações de comportamento após criados no dispositivo. A estratégia correta não é prometer alteração total de canais existentes, e sim versionar novos canais futuros e manter fallback local.

| Entrega | Critério de aceite |
|---|---|
| Chave `notifications.channels` no Remote Config | Define nomes/descrições para novos canais. |
| Fallback local em `push_notification_service.dart` | Notificações continuam funcionando sem config. |
| Versionamento de channel IDs | Evita tentar renomear canal já fixado no Android sem controle. |
| Documentação operacional | Equipe sabe quando criar novo ID de canal. |

### Fase 9 — Painel/admin e governança de conteúdo

Para ir a produção de forma sustentável, a equipe precisa alterar conteúdo sem editar SQL manualmente. O mínimo aceitável é um fluxo documentado com scripts de seed/patch e permissões de admin; o ideal é integrar ao `bubble-admin`.

| Área admin | Ação mínima | Ação ideal |
|---|---|---|
| Traduções OTA | Script seguro de upsert por CSV/JSON. | Tela de edição por locale/key com diff. |
| Free Coins | Script de seed e alteração controlada. | CRUD de reward tasks com preview. |
| Níveis | Script de atualização por versão. | Editor de faixas, cores e títulos. |
| Onboarding | Script de slides. | Builder visual com variantes. |
| Streaming rules | Remote Config editável. | UI com validação de domínio. |
| Announcements | Usar tabela existente. | CRUD com agendamento e segmentação. |

### Fase 10 — Redução real do APK/AAB

A redução de tamanho só deve começar quando os domínios remotos estiverem estáveis. Remover payload do binário antes disso cria risco de tela vazia offline. A estratégia segura é manter **fallback mínimo** e transferir conteúdo volumoso para Supabase/Storage.

| Alvo de redução | Quando remover | Fallback mínimo |
|---|---|---|
| Traduções completas de idiomas secundários | Depois de OTA estável em produção. | Idioma padrão + mensagens críticas. |
| Imagens de onboarding/campanhas | Depois de cache remoto validado. | Logo e ilustrações base. |
| Copy longa e campanhas | Depois de admin operacional. | Mensagens genéricas locais. |
| Configurações extensas | Depois de feature flags estáveis. | Valores seguros locais. |

## 5. Ordem de produção recomendada

A ordem abaixo evita que a equipe implemente funcionalidades dependentes antes da base estar confiável. Cada fase deve terminar com commit, push, validação e checklist atualizada.

| Ordem | Fase | Motivo | Pode ir para produção quando... |
|---:|---|---|---|
| 0 | CI, staging e baseline OTA | Sem validação real, qualquer expansão fica arriscada. | `flutter analyze`, build interno e migration staging OK. |
| 1 | Hardening OTA Translations | É a base de copy remota e correção sem APK. | Locale ativo busca rápido e fallback opera offline. |
| 2 | Free Coins remoto | Alto impacto em retenção/monetização. | Cards mudam remotamente e economia permanece segura. |
| 3 | Níveis e cores | Alto impacto visual e gamificação. | Nomes/cores idênticos ao baseline e editáveis remotamente. |
| 4 | System Announcements | Necessário para comunicação operacional. | Banners ativos por janela e locale funcionam. |
| 5 | Onboarding remoto | Flexibilidade de aquisição e A/B test. | Slides remotos com fallback e variante. |
| 6 | Streaming domains | Segurança e manutenção de provedores externos. | Allowlist remota conservadora validada. |
| 7 | Cache TTLs | Otimização operacional. | TTLs centralizados sem regressão. |
| 8 | Push channels | Baixa prioridade e sensível ao Android. | Versionamento de canais documentado. |
| 9 | Admin/governança | Reduz dependência de dev para alterações. | Equipe altera conteúdo com permissões. |
| 10 | Redução do APK/AAB | Só após estabilidade comprovada. | Tamanho reduzido com fallback mínimo e métricas estáveis. |

## 6. Checklist mestre de execução

| ID | Item | Status inicial | Critério de conclusão |
|---|---|---|---|
| P0.1 | Rodar análise Flutter real do commit OTA atual. | Pendente | `flutter analyze` sem erro. |
| P0.2 | Aplicar migration OTA em staging. | Pendente | RPC retorna traduções por locale. |
| P0.3 | Testar alteração de uma string sem novo APK. | Pendente | UI reflete alteração após refresh/cache. |
| P1.1 | Otimizar fetch OTA por locale ativo. | Pendente | Cold start validado. |
| P1.2 | Criar feature flag OTA. | Pendente | Flag off usa fallback local. |
| P2.1 | Criar `reward_tasks` e seed. | Pendente | Free Coins remoto equivalente ao atual. |
| P2.2 | Integrar provider Free Coins. | Pendente | Tela não tem conteúdo hardcoded primário. |
| P3.1 | Criar `level_definitions`. | Pendente | Títulos e cores remotos com fallback. |
| P3.2 | Remover fonte primária hardcoded de níveis/cores. | Pendente | Helpers usam serviço central. |
| P4.1 | Ativar announcements por tabela existente. | Pendente | Banners/manutenção vêm do servidor. |
| P5.1 | Criar `onboarding_slides`. | Pendente | Slides remotos com fallback. |
| P5.2 | Suportar variante/A-B test. | Pendente | Variante configurável sem APK. |
| P6.1 | Migrar streaming domains. | Pendente | Allowlist remota conservadora. |
| P7.1 | Migrar cache TTLs. | Pendente | `CachePolicyService` central. |
| P8.1 | Versionar canais push futuros. | Pendente | Config remota documentada. |
| P9.1 | Criar scripts/admin operacional. | Pendente | Equipe altera dados sem SQL manual arriscado. |
| P10.1 | Medir tamanho APK/AAB baseline. | Pendente | Métrica antes/depois registrada. |
| P10.2 | Remover payloads redundantes com fallback mínimo. | Pendente | Redução comprovada sem crash/offline vazio. |

## 7. Validação obrigatória por fase

Toda fase deve ter três níveis de validação. A validação textual por script é útil, mas não substitui análise Flutter e teste de app real.

| Nível | O que validar | Ferramenta/processo |
|---|---|---|
| **Código** | Formatação, análise estática, imports e tipos. | `dart format`, `flutter analyze`, scripts Python específicos. |
| **Banco** | Migration idempotente, RLS, grants, RPCs e seed. | Staging Supabase antes de produção. |
| **Produto** | Tela funcionando, offline, flag off, alteração remota e rollback. | Build interno + checklist manual. |
| **Performance** | Cold start, payload, cache hit/miss. | Logs locais e métricas de sessão/crash. |
| **Operação** | Equipe consegue alterar dados com segurança. | Script/admin e permissões. |

## 8. Estratégia de rollback

Rollback deve ser planejado por camada, porque nem todo problema exige reverter APK. A ordem padrão é: desligar feature flag, corrigir dados remotos, reverter migration apenas se necessário, e só então publicar novo build.

| Falha | Rollback primário | Rollback secundário |
|---|---|---|
| Tradução remota errada | Corrigir valor no banco ou desativar key. | Flag off OTA. |
| Free Coins remoto incorreto | Desativar task ou flag remota. | Fallback local. |
| Cor/nível inválido | Corrigir `level_definitions` ou flag off. | Fallback local de cores/títulos. |
| Onboarding quebrado | Desativar variante/slides. | Fallback local. |
| Domínio streaming inseguro | Remover domínio remoto e bloquear. | Fallback allowlist local conservadora. |
| TTL prejudica performance | Ajustar Remote Config. | Fallback local padrão. |
| Migration falha | Não promover para produção; corrigir em staging. | Reverter migration se aplicada parcialmente. |

## 9. Critérios finais para declarar a migração completa

A migração APK → Servidor só estará pronta para produção completa quando todos os itens abaixo forem verdadeiros. Antes disso, qualquer entrega deve ser tratada como fase parcial.

| Critério final | Exigência |
|---|---|
| Cobertura funcional | Todos os itens do mapa têm fonte remota primária ou decisão formal de manter no APK. |
| Fallback | Cada domínio tem fallback local mínimo e testado offline. |
| Segurança | Mutações admin passam por RPC/serviço seguro; cliente não recebe segredo. |
| Observabilidade | Falhas remotas não crasham o app e são registráveis. |
| Governança | Equipe consegue alterar conteúdo sem deploy e sem SQL manual perigoso. |
| Rollout | Staging validado, build interno aprovado e rollout gradual planejado. |
| Redução APK/AAB | Tamanho medido antes/depois e redução aplicada somente após estabilidade. |
| Documentação | Checklist e plano atualizados junto de cada commit. |

## 10. Próxima ação recomendada

A próxima ação mais sábia é **não começar Free Coins ainda**. Primeiro, deve-se fechar a Fase 0: validar o commit OTA existente com Flutter/CI e aplicar a migration em staging. Isso evita empilhar novas migrações sobre uma base ainda não compilada em ambiente real. Assim que a Fase 0 estiver verde, a execução deve seguir para **Fase 1 — hardening OTA**, e depois para **Fase 2 — Free Coins remoto**, que é o primeiro item de alta prioridade ainda não coberto.

Se for necessário escolher uma sequência prática de commits, a recomendação é:

| Commit | Conteúdo | Motivo |
|---:|---|---|
| 1 | Validar/push da infraestrutura OTA atual, corrigindo qualquer erro do analyzer. | Base técnica. |
| 2 | Hardening OTA: locale ativo, flag, telemetria e staging notes. | Produção segura. |
| 3 | Free Coins remoto com tabela/RPC/provider/fallback. | Alta prioridade e impacto direto. |
| 4 | Level definitions com títulos/cores/faixas. | Consistência visual e gamificação. |
| 5 | System announcements + onboarding remoto. | Operação e aquisição. |
| 6 | Streaming rules + cache TTLs + push channels. | Infraestrutura e segurança. |
| 7 | Admin/governança e redução APK/AAB. | Operação sustentável e redução real. |

## 11. Matriz técnica de execução por módulo

Esta matriz transforma o plano em uma lista de execução prática. Ela deve ser usada durante a implementação para impedir que uma fase comece sem terminar o ciclo completo de migration, serviço, provider, fallback, teste, documentação e checklist.

| Módulo | Arquivos prováveis no app | Migration/RPC | Serviço/provider esperado | Validação mínima |
|---|---|---|---|---|
| OTA Translations | `frontend/lib/core/services/ota_translation_service.dart`, `frontend/lib/core/l10n/app_strings_ota.dart`, `locale_provider.dart`, `main.dart` | `app_translations`, `get_app_translations(locale)` | `OtaTranslationService` e wrapper `OtaAppStrings` | Alterar uma key em staging e ver refletir na UI sem novo APK. |
| Free Coins | `frontend/lib/features/.../free_coins_screen.dart` e providers relacionados | `reward_tasks`, `get_reward_tasks(locale)` | `RewardTaskService` + provider tipado | Cards atuais idênticos por seed; mudança remota visível; fallback offline. |
| Level Definitions | `frontend/lib/core/utils/helpers.dart`, `frontend/lib/core/theme/app_theme.dart`, widgets de perfil/gamificação | `level_definitions`, `get_level_definitions(locale)` | `LevelDefinitionService` + cache | Cores e títulos equivalentes ao baseline; alteração em staging refletida. |
| Onboarding | `frontend/lib/features/.../onboarding_screen.dart` | `onboarding_slides`, `get_onboarding_slides(locale, variant)` | `OnboardingContentService` + provider | Slides atuais idênticos; variante remota controlada por config. |
| Announcements | pontos de shell/app layout e banners globais | `system_announcements` existente ou ajustada | `AnnouncementService` | Mensagem ativa por janela aparece; expirada desaparece; fallback sem anúncio. |
| Streaming Rules | `frontend/lib/features/live/screening/services/*stream*_service.dart` | `app_remote_config` ou `streaming_domain_rules` | `StreamingRulesService` | Domínio permitido funciona; domínio bloqueado é recusado; falha remota é conservadora. |
| Cache TTLs | `frontend/lib/core/services/cache_service.dart` e serviços que definem `Duration` | `app_remote_config` | `CachePolicyService` | TTL alterável em staging; ausência de config usa padrão seguro. |
| Push Channels | `frontend/lib/core/services/push_notification_service.dart`, `match_queue_service.dart` | `app_remote_config` | `NotificationChannelConfigService` | Novos canais respeitam config; canais existentes não são renomeados de forma frágil. |
| Redução APK/AAB | `pubspec.yaml`, assets, l10n e bundles | N/A | Processo de build e medição | AAB antes/depois comparado; fallback mínimo testado sem rede. |

## 12. Gates obrigatórios antes de cada merge

Cada PR ou commit de fase deve cumprir os gates abaixo. Se algum gate falhar, a fase não deve ser marcada como concluída e não deve ser promovida para produção.

| Gate | Pergunta objetiva | Resultado exigido |
|---|---|---|
| **Schema** | A migration é idempotente, versionada e compatível com RLS do projeto? | Sim, testada em staging. |
| **Client** | O app tem fallback local e não crasha sem rede? | Sim, testado manualmente. |
| **Provider** | A UI consome provider/serviço tipado, sem Supabase direto na tela? | Sim, confirmado em review. |
| **Flag** | Existe forma de desligar o remoto sem novo APK? | Sim, por Remote Config ou `is_active`. |
| **Paridade** | O comportamento remoto inicial é igual ao APK atual? | Sim, evidenciado por seed/teste visual. |
| **Performance** | O boot e a tela não ficaram dependentes de chamada lenta? | Sim, timeout/cache/fallback implementados. |
| **Documentação** | Checklist e plano foram atualizados no mesmo commit? | Sim. |

## 13. Como executar sem deixar nada pela metade

A execução deve seguir um ciclo fixo para cada item do mapa. Primeiro, criar ou ajustar o schema e o seed em staging. Depois, criar o modelo Dart, serviço e provider com fallback local. Em seguida, integrar a tela ou helper sem remover ainda o comportamento local. Só depois deve-se ativar a feature flag em staging, validar paridade, testar rollback e registrar evidências. A remoção de payloads do APK deve ser sempre uma etapa posterior, nunca simultânea à primeira migração.

| Passo | Descrição | Saída obrigatória |
|---:|---|---|
| 1 | Criar migration e seed com os valores atuais do APK. | SQL versionado e idempotente. |
| 2 | Criar modelos e serviço de leitura com timeout e cache. | Serviço testável e sem lógica de UI. |
| 3 | Criar fallback local equivalente ao estado atual. | App funcional offline. |
| 4 | Integrar provider/helper mantendo comportamento antigo como fallback. | UI estável. |
| 5 | Adicionar flag/controle remoto de ativação. | Rollback sem novo APK. |
| 6 | Rodar validações locais e staging. | Evidências salvas. |
| 7 | Atualizar checklist e plano. | Documentação fiel ao estado real. |
| 8 | Commit e push após aprovação. | Histórico limpo e reversível. |

## 14. Decisões que exigem confirmação antes da implementação

Alguns pontos não devem ser decididos unilateralmente porque afetam produto, operação ou monetização. Antes de codificar estas partes, a decisão deve ser confirmada.

| Decisão | Por que precisa de confirmação | Opções recomendadas |
|---|---|---|
| Redução agressiva de traduções no APK | Pode prejudicar experiência offline em idiomas secundários. | Manter todos os idiomas por 1 release; depois fallback mínimo. |
| Imagens remotas no onboarding | Pode afetar cold start e consumo de dados. | Começar com `asset_key`; migrar imagem remota depois. |
| Regras de recompensa Free Coins | Pode impactar economia interna. | Migrar copy primeiro; migrar lógica de concessão só via RPC segura. |
| Canal push Android | Canais existentes podem não refletir renomeação como esperado no dispositivo. | Versionar novos IDs apenas quando necessário. |
| Domínios de streaming externos | Afeta segurança e legalidade de conteúdo. | Allowlist conservadora, bloqueio remoto prioritário. |

## 15. Estado recomendado antes do próximo commit de código

Antes de iniciar qualquer nova implementação, o estado desejado é: commit OTA atual validado com Flutter real, plano completo versionado, checklist mestre atualizada, e decisão explícita de que a próxima execução será **Fase 0 + Fase 1**, não Free Coins diretamente. Isso garante que a base técnica esteja sólida antes de migrar domínios de produto de maior impacto.

