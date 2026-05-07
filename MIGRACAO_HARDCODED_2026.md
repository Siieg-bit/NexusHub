# Relatório de Arquitetura: Migração de Conteúdo Hardcoded para Atualizações Dinâmicas (NexusHub 2026)

**Autor:** Manus AI
**Data:** 07 de Maio de 2026

Este relatório apresenta uma análise profunda do projeto NexusHub e propõe as melhores estratégias arquiteturais para 2026, visando migrar conteúdos e regras de negócio hardcoded no frontend (Flutter) para o backend (Supabase) ou serviços de configuração remota. O objetivo é permitir atualizações dinâmicas sem a necessidade de submeter novas versões do APK às lojas de aplicativos, reduzindo o tamanho do app e melhorando a experiência do usuário e da equipe de desenvolvimento.

---

## 1. Análise do Estado Atual (O que está Hardcoded)

Após uma varredura completa no código-fonte do frontend (`/frontend/lib`) e nas migrations do backend (`/backend/supabase/migrations`), identificamos diversas áreas críticas que atualmente exigem atualização do APK para serem modificadas:

### 1.1. Regras de Gamificação e Economia
- **Limites de XP e Níveis:** A tabela de XP necessário para cada nível (`levelThresholds` com 20 níveis) e a fórmula de cálculo estão fixas no arquivo `helpers.dart` e `app_config.dart`.
- **Recompensas por Ação:** Os valores de XP ganhos por post, comentário, like, check-in, etc., estão hardcoded na classe `ReputationRewards` (`helpers.dart`) e duplicados no `app_config.dart`.
- **Pacotes de Moedas (Loja):** Os pacotes de moedas (`fallbackCoinPackages`) e seus preços de referência estão fixos no `iap_service.dart`.

### 1.2. Configurações e Limites do App
- **Limites de UI/UX:** Tamanhos máximos de texto (título, conteúdo, bio, comentários), paginação (`defaultPageSize`, `chatPageSize`) e limites de mídia estão fixos no `app_config.dart` e `constants.dart`.
- **Rate Limits (Client-side):** Os limites de ações por tempo (ex: 5 posts/hora, 60 mensagens/minuto) estão fixos no `rate_limiter_service.dart`.

### 1.3. Conteúdo Estático e Onboarding
- **Categorias de Interesse:** A lista de 24 categorias de interesse (com ícones e cores) no onboarding (`interest_wizard_screen.dart`) está totalmente hardcoded, apesar de existir uma tabela `interests` no banco de dados.
- **Textos Legais e de Suporte:** A Política de Privacidade (`privacy_policy_screen.dart`), Termos de Uso (`terms_of_use_screen.dart`) e links de suporte/FAQ (`settings_screen.dart`) estão embutidos no código.

### 1.4. Temas e UI
- **Temas Built-in:** Os temas `principal`, `midnight` e `greenLeaf` estão fixos no `nexus_themes.dart`. Embora o app já possua suporte a temas remotos via tabela `app_themes`, os temas principais ainda exigem atualização do APK para serem alterados.

---

## 2. Estratégias de Migração para 2026

Para resolver esses problemas de forma inteligente e sem "gambiarras", propomos uma abordagem em três frentes, utilizando as tecnologias mais modernas e adequadas para o ecossistema Flutter + Supabase em 2026.

### Estratégia A: Supabase Remote Config (Server-Driven Configuration)

A solução mais nativa e integrada para o NexusHub é expandir o uso do Supabase para atuar como um serviço de Remote Config.

**Como implementar:**
1. **Tabela `app_remote_config`:** Criar uma tabela no Supabase com estrutura chave-valor (JSONB) para armazenar configurações globais.
   ```sql
   CREATE TABLE public.app_remote_config (
     key TEXT PRIMARY KEY,
     value JSONB NOT NULL,
     updated_at TIMESTAMPTZ DEFAULT NOW()
   );
   ```
2. **Sincronização no App Start:** No `main.dart` ou na tela de splash, o app faz o fetch dessas configurações e as armazena em cache local (usando `shared_preferences` ou `hive`).
3. **O que migrar para cá:**
   - Limites de paginação e tamanhos de texto (`app_config.dart`).
   - Rate limits do client-side (`rate_limiter_service.dart`).
   - Links de suporte, FAQ e webhooks do Discord.
   - Feature flags (ex: ativar/desativar modo RPG globalmente, habilitar novas abas).

**Vantagens:** Não adiciona dependências extras (já usa Supabase), atualização em tempo real via Supabase Realtime, e controle total pelo painel `bubble-admin`.

### Estratégia B: Migração de Dados Estáticos para o Banco de Dados

Dados que representam entidades de negócio devem viver exclusivamente no banco de dados, sendo consumidos via API.

**O que migrar:**
1. **Categorias de Interesse:** Remover a lista hardcoded do `interest_wizard_screen.dart`. O app deve fazer um `SELECT` na tabela `interests` (já existente no banco) durante o onboarding. Os ícones podem ser mapeados via strings (ex: nome do ícone Material) ou URLs de imagens no Supabase Storage.
2. **Regras de Gamificação:** Criar uma tabela `gamification_rules` para armazenar os `levelThresholds` e `ReputationRewards`. O cálculo de nível no Flutter (`helpers.dart`) passará a usar os dados cacheados dessa tabela.
3. **Textos Legais:** Mover a Política de Privacidade e Termos de Uso para o Supabase (tabela `legal_documents` ou via Remote Config) ou renderizá-los via WebView/Markdown a partir de uma URL externa (ex: Notion ou site institucional). Isso reduz drasticamente o tamanho do código e permite atualizações instantâneas.

### Estratégia C: Shorebird (Over-The-Air Code Push)

Para alterações de lógica de negócio, correções de bugs urgentes (hotfixes) e pequenas mudanças de UI que não podem ser resolvidas apenas com dados remotos, a tecnologia definitiva para Flutter em 2026 é o **Shorebird** [1].

**O que é:** Criado por ex-membros da equipe do Flutter, o Shorebird permite enviar atualizações de código Dart diretamente para os dispositivos dos usuários (OTA - Over-The-Air), contornando o processo de revisão das lojas (App Store e Google Play) [2].

**Como funciona no NexusHub:**
- O Shorebird modifica o motor do Flutter no app para verificar patches na inicialização.
- Se houver um patch, ele é baixado e aplicado na próxima execução.
- **Limitações:** Só atualiza código Dart. Não atualiza código nativo (Kotlin/Swift) nem dependências nativas (como o SDK do Agora RTC ou MediaKit) [3].

**Quando usar:**
- Correção de um bug crítico no cálculo de XP.
- Alteração no layout de um widget (ex: mudar a cor de um botão que não está no sistema de temas).
- Adição de uma nova tela simples que consome uma API existente.

**Conformidade com as Lojas:** O Shorebird é 100% compatível com as diretrizes da Google Play e App Store, desde que a atualização não mude o propósito principal do aplicativo de forma enganosa [3].

---

## 3. Plano de Ação e Recomendações

Para implementar essa arquitetura moderna, recomendamos a seguinte ordem de execução:

### Fase 1: Limpeza e Banco de Dados (Curto Prazo)
1. **Interesses:** Refatorar o `interest_wizard_screen.dart` para consumir a tabela `interests` do Supabase.
2. **Textos Legais:** Mover os textos de `privacy_policy_screen.dart` e `terms_of_use_screen.dart` para o Supabase ou hospedagem externa.
3. **Temas:** Remover os temas `principal`, `midnight` e `greenLeaf` do código e inseri-los na tabela `app_themes` (já existente via migration 096). O app passará a baixar todos os temas remotamente.

### Fase 2: Implementação do Remote Config (Médio Prazo)
1. Criar a tabela `app_remote_config` no Supabase.
2. Criar um `RemoteConfigService` no Flutter que baixa e faz cache dessas configurações na inicialização.
3. Substituir as constantes do `app_config.dart`, `constants.dart` e `rate_limiter_service.dart` por chamadas a esse serviço.
4. Adicionar uma interface no `bubble-admin` para editar essas configurações.

### Fase 3: Integração do Shorebird (Longo Prazo)
1. Criar uma conta no Shorebird e inicializar o projeto (`shorebird init`).
2. Integrar o Shorebird ao pipeline de CI/CD (GitHub Actions) para gerar releases e patches automaticamente.
3. Treinar a equipe para usar o comando `shorebird patch` para hotfixes, reservando as atualizações nas lojas apenas para mudanças que envolvam código nativo (ex: atualização do SDK do Firebase ou Agora).

## 4. Conclusão

A migração do conteúdo hardcoded para uma arquitetura híbrida de **Supabase Remote Config + Shorebird OTA** colocará o NexusHub no estado da arte do desenvolvimento mobile em 2026. 

Essa abordagem não apenas reduzirá o tamanho do APK (removendo textos longos e assets embutidos), mas também dará à equipe de administração um poder sem precedentes para ajustar a economia, gamificação e regras do app em tempo real, sem depender da aprovação das lojas de aplicativos.

---

## Referências

[1] Shorebird. "Over-the-Air Updates in Flutter with Shorebird". Disponível em: https://shorebird.dev
[2] Dev.to. "How to Push Over-the-Air (OTA) Flutter Updates with Shorebird". Disponível em: https://dev.to/techwithsam/how-to-push-over-the-air-ota-flutter-updates-with-shorebird-complete-2026-guide-4d35
[3] Shorebird Documentation. "FAQ - Use Cases & Limitations". Disponível em: https://docs.shorebird.dev/code-push/faq/
