# Auditoria de Feature Completeness — Fase 4

**Data:** 30/03/2026
**Base analisada:** commit `main` (HEAD)
**Método:** Varredura completa de rotas, telas, providers, services, models, backend (migrations + edge functions), e referências cruzadas.

---

## 1. Visão Geral do Projeto

O NexusHub é um clone do Amino Apps construído com Flutter (frontend) e Supabase (backend). O projeto possui **142 arquivos Dart** (~62k LOC), **30 migrations SQL**, **7 Edge Functions** e **14 features** organizadas por domínio.

| Domínio | Arquivos | LOC | Profundidade Supabase |
|---|---|---|---|
| chat | 16 | 7.875 | Alta (41 calls em chat_room) |
| communities | 16 | 8.477 | Alta (24 calls em community_profile) |
| feed | 10 | 6.715 | Alta (18 calls em post_detail) |
| profile | 11 | 4.744 | Média |
| gamification | 6 | 3.456 | Média |
| moderation | 6 | 2.812 | Alta |
| auth | 5 | 2.137 | Média |
| wiki | 2 | 1.750 | Média |
| store | 2 | 1.399 | Média |
| explore | 2 | 1.355 | Média |
| stories | 3 | 1.311 | Média |
| live | 2 | 1.265 | Média |
| notifications | 1 | 577 | Baixa (via provider) |
| settings | 9 | 4.009 | Média |

---

## 2. Serviços: Integrados vs. Código Morto

A auditoria revelou que **10 de 19 serviços** estão total ou parcialmente desconectados do restante do app. Eles existem como código funcional completo, mas nenhuma tela ou provider os consome.

### 2.1 Serviços Totalmente Integrados

| Serviço | Consumidores | Status |
|---|---|---|
| `supabase_service.dart` | 77 arquivos | Integrado (core) |
| `realtime_service.dart` | 4 arquivos | Integrado (Fase 3) |
| `presence_service.dart` | 3 arquivos | Integrado |
| `call_service.dart` | 2 arquivos (call_screen, call_provider) | Integrado |
| `ad_service.dart` | 2 arquivos (coin_shop, free_coins) | Integrado |
| `iap_service.dart` | 2 arquivos (coin_shop, main) | Integrado |
| `cache_service.dart` | 2 arquivos (notification_provider, main) | Integrado |

### 2.2 Serviços Inicializados mas Não Consumidos por Telas

| Serviço | LOC | Inicializado em | Consumido por telas? | Classificação |
|---|---|---|---|---|
| `analytics_service.dart` | 204 | `main.dart` | **Não** — init() chamado mas nenhum `logScreen`, `logPostCreated`, etc. é invocado em nenhuma tela | **FEAT-A** |
| `error_handler.dart` | 314 | `main.dart` (scaffoldKey) | **Parcial** — scaffoldKey conectado, mas `ErrorHandler.showError()`, `showSuccess()` nunca chamados por telas | **FEAT-A** |
| `deep_link_service.dart` | 180 | `main.dart` | **Parcial** — `init(router)` chamado, mas nenhum deep link é registrado/testado | **FEAT-C** |
| `push_notification_service.dart` | 230 | `main.dart` | **Parcial** — `initialize()` chamado, mas nenhuma tela registra/gerencia tokens | **FEAT-B** |
| `device_fingerprint_service.dart` | 120 | `main.dart` | **Não** — `registerDevice()` chamado mas nenhuma tela usa fingerprint | **FEAT-D** |

### 2.3 Serviços Completamente Mortos (Nem Inicializados)

| Serviço | LOC | Descrição | Classificação |
|---|---|---|---|
| `media_upload_service.dart` | 327 | Upload centralizado com crop, progresso, buckets tipados. **Nenhuma tela usa** — todas fazem upload inline via `SupabaseService.storage` | **FEAT-A** |
| `rate_limiter_service.dart` | 176 | Rate limiting client+server. **Zero consumidores** | **FEAT-B** |
| `privacy_service.dart` | 124 | Níveis de privacidade (público/semi/privado). **Zero consumidores** | **FEAT-B** |
| `security_service.dart` | 163 | HMAC, sanitização, validação. **Zero consumidores** | **FEAT-C** |
| `pagination_service.dart` | ~100 | Paginação genérica. **Zero consumidores** (telas usam PaginatedListView ou manual) | **FEAT-D** |
| `captcha_service.dart` | 150 | CAPTCHA visual math challenge. **Zero consumidores** | **FEAT-C** |
| `system_account_service.dart` | 173 | Broadcast de sistema, welcome messages. **Zero consumidores** | **FEAT-C** |

---

## 3. Lacunas de Feature por Domínio

### 3.1 Chat

| Lacuna | Descrição | Impacto | Classificação |
|---|---|---|---|
| Upload inline duplicado | 6 pontos de upload direto via `SupabaseService.storage` em vez de `MediaUploadService` | Código duplicado, sem progresso, sem crop | **FEAT-A** |
| Giphy Picker sem API key | `GiphyPicker` usa API pública do Giphy mas a key pode estar hardcoded ou ausente | Funcional mas frágil | **FEAT-B** |

### 3.2 Feed

| Lacuna | Descrição | Impacto | Classificação |
|---|---|---|---|
| Upload inline duplicado | `create_post_screen.dart` e `block_editor.dart` fazem upload direto | Mesmo problema do chat | **FEAT-A** |
| Crosspost funcional | `CrosspostPicker` existe e parece completo (390 LOC) | OK | — |

### 3.3 Communities

| Lacuna | Descrição | Impacto | Classificação |
|---|---|---|---|
| ACM (Community Manager) | 907 LOC, parece completo com seções configuráveis | OK | — |
| Shared Folder | 238 LOC, upload funcional | OK | — |

### 3.4 Gamification

| Lacuna | Descrição | Impacto | Classificação |
|---|---|---|---|
| Check-in | Tela completa com RPC `daily_checkin`, lucky draw, repair streak | OK | — |
| Wallet | Provider completo com coins e transações | OK | — |
| Achievements | Tela funcional com heatmap de check-ins | OK | — |

### 3.5 Stories

| Lacuna | Descrição | Impacto | Classificação |
|---|---|---|---|
| Vídeo em stories | `create_story_screen.dart` menciona "video: placeholder para futura implementação" | Parcial — imagem funciona, vídeo não | **FEAT-B** |

### 3.6 Moderation

| Lacuna | Descrição | Impacto | Classificação |
|---|---|---|---|
| Edge function `moderation` | Existe no backend e é chamada via `push_notification_service` | Parcial | **FEAT-B** |
| Admin Panel | 485 LOC, funcional | OK | — |
| Flag Center | 406 LOC, funcional | OK | — |

### 3.7 Notifications

| Lacuna | Descrição | Impacto | Classificação |
|---|---|---|---|
| Push notifications | `PushNotificationService` inicializado mas não integrado com telas | Notificações locais funcionam, push não chega ao device | **FEAT-B** |

### 3.8 Transversal

| Lacuna | Descrição | Impacto | Classificação |
|---|---|---|---|
| L10n não utilizado | 57 de 57 telas usam strings hardcoded em PT-BR. O sistema `AppStrings` existe (912 LOC) mas **nenhuma tela o consome** | Internacionalização impossível | **FEAT-D** |
| Analytics não integrado | `AnalyticsService` tem 15+ métodos de tracking mas nenhum é chamado | Zero telemetria | **FEAT-A** |
| ErrorHandler não integrado | `ErrorHandler.showError/showSuccess` nunca chamados — telas usam SnackBar manual | UX inconsistente | **FEAT-A** |
| MediaUploadService não integrado | 327 LOC de upload centralizado ignorado — 19+ pontos de upload inline | Código duplicado, sem progresso | **FEAT-A** |
| RateLimiter não integrado | Rate limiting existe mas nenhuma ação é protegida | Spam possível | **FEAT-B** |
| PrivacyService não integrado | Níveis de privacidade existem mas nenhum perfil/conteúdo os verifica | Privacidade não funciona | **FEAT-B** |

---

## 4. Classificação FEAT-A/B/C/D

Seguindo o critério solicitado:

- **FEAT-A (Alta prioridade):** Serviços prontos que deveriam estar integrados e cuja ausência causa inconsistência real no app.
- **FEAT-B (Média prioridade):** Features parcialmente implementadas que precisam de wiring adicional para funcionar.
- **FEAT-C (Baixa prioridade):** Features de segurança/infraestrutura que são importantes mas não afetam UX diretamente.
- **FEAT-D (Backlog):** Melhorias de qualidade de código que não afetam funcionalidade.

### Matriz de Priorização

| ID | Lacuna | Classificação | Esforço | Risco | Lote Recomendado |
|---|---|---|---|---|---|
| F01 | Integrar `MediaUploadService` nos 19+ pontos de upload inline | FEAT-A | Alto | Médio | **4A** |
| F02 | Integrar `ErrorHandler.showError/showSuccess` nas telas principais | FEAT-A | Médio | Baixo | **4A** |
| F03 | Integrar `AnalyticsService` nos fluxos críticos (login, post, like, navigate) | FEAT-A | Médio | Baixo | **4A** |
| F04 | Integrar `RateLimiterService` em ações sensíveis (post, comment, message, like) | FEAT-B | Médio | Médio | **4B** |
| F05 | Integrar `PrivacyService` em perfil e conteúdo | FEAT-B | Médio | Médio | **4B** |
| F06 | Completar integração de `PushNotificationService` | FEAT-B | Alto | Alto | **4B** |
| F07 | Completar stories com vídeo | FEAT-B | Médio | Baixo | **4C** |
| F08 | Integrar `CaptchaService` em ações sensíveis | FEAT-C | Baixo | Baixo | **4C** |
| F09 | Integrar `SecurityService` (sanitização) | FEAT-C | Baixo | Baixo | **4C** |
| F10 | Integrar `SystemAccountService` (welcome, broadcast) | FEAT-C | Baixo | Baixo | **4C** |
| F11 | Migrar L10n para todas as telas | FEAT-D | Muito Alto | Baixo | **Backlog** |
| F12 | Remover `PaginationService` (substituído por PaginatedListView) | FEAT-D | Mínimo | Nenhum | **4A** |

---

## 5. Recomendação de Lotes

### Lote 4A — Integração de Serviços Core (FEAT-A)

O foco é conectar os 3 serviços mais impactantes que já estão prontos mas desconectados. Isso elimina código duplicado, padroniza UX de erros, e ativa telemetria.

Escopo:
1. **F01 — MediaUploadService:** Substituir os 19+ pontos de upload inline pelo serviço centralizado. Isso traz: crop de imagem, progresso de upload, buckets tipados, e tratamento de erro consistente.
2. **F02 — ErrorHandler:** Substituir os SnackBars manuais espalhados pelas telas por `ErrorHandler.showError()` e `ErrorHandler.showSuccess()`. Isso padroniza a UX de feedback.
3. **F03 — AnalyticsService:** Adicionar chamadas de tracking nos fluxos críticos: login, signup, post create, like, comment, navigate.
4. **F12 — Remover PaginationService:** Código morto, pode ser removido com segurança.

### Lote 4B — Features de Proteção (FEAT-B)

Escopo:
1. **F04 — RateLimiterService:** Proteger post_create, comment_create, message_send, like_toggle, report_create.
2. **F05 — PrivacyService:** Integrar verificação de privacidade em profile_screen, user_wall, followers.
3. **F06 — PushNotificationService:** Completar o wiring de token FCM e navegação por push.

### Lote 4C — Features Complementares (FEAT-C)

Escopo:
1. **F07 — Stories com vídeo**
2. **F08 — CaptchaService em ações sensíveis**
3. **F09 — SecurityService (sanitização de input)**
4. **F10 — SystemAccountService (welcome messages, broadcasts)**

---

## 6. Observações Importantes

**Sobre o que NÃO é lacuna:** A auditoria confirmou que os seguintes sistemas estão funcionais e completos: check-in com gamificação, wallet/economia, achievements, leaderboard, store/coin shop, wiki com curadoria, live/screening room com Agora, chamadas de voz/vídeo, moderação (admin panel, flag center, reports), DM invites, sticker picker, giphy picker, voice recorder, forward message, poll/quiz, block editor, crosspost picker, story carousel, e todo o sistema de comunidades (ACM, shared folder, members, search).

**Sobre L10n:** Nenhuma das 57 telas usa o sistema `AppStrings`. Todas as strings estão hardcoded em PT-BR. A migração seria massiva (~57 telas) e foi classificada como FEAT-D (backlog) por não afetar funcionalidade.

**Sobre Edge Functions:** Das 7 edge functions, apenas `agora-token` é invocada diretamente pelo frontend (via `CallService`). As demais (`check-in`, `moderation`, `push-notification`, `webhook-handler`, `delete-user-data`, `export-user-data`) são chamadas via RPCs ou database webhooks, não diretamente pelo frontend. O check-in usa RPC `daily_checkin`, não a edge function diretamente. Delete/export user data usam RPCs em `settings_screen.dart`.
