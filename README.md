# NexusHub

O **NexusHub** é um aplicativo mobile em **Flutter** inspirado na experiência social do Amino, com backend em **Supabase** e foco em comunidades, chats, feed, wiki, moderação, economia virtual e recursos em tempo real. O repositório já contém uma base funcional ampla, com frontend organizado por features, backend serverless baseado em migrações SQL e Edge Functions, além de uma trilha extensa de documentos técnicos e relatórios de evolução.

> **Para qualquer nova IA ou colaborador que for analisar este projeto, a ordem recomendada é:** ler este `README.md` primeiro e, em seguida, abrir o arquivo [`instrucoes.txt`](./instrucoes.txt). Esse arquivo resume o contexto operacional do repositório, aponta os diretórios mais importantes e acelera a análise.

## Visão geral do estado atual

O estado atual do repositório mostra um projeto significativamente mais avançado do que uma prova de conceito simples. A aplicação possui estrutura mobile consolidada, integração com Supabase, múltiplos módulos sociais, suporte a mídia, fluxo de comunidades, sistema de reputação, notificações e uma camada de backend com dezenas de migrações versionadas.

| Área | Estado atual observado |
| --- | --- |
| Frontend | Aplicação Flutter organizada por módulos e rotas extensas |
| Backend | Supabase com **72 migrações SQL** e **10 Edge Functions** |
| Estrutura de código | Aproximadamente **205 arquivos Dart** em `frontend/lib/` |
| Testes | **11 arquivos de teste** em `frontend/test/` |
| CI/CD | Workflow em `.github/workflows/ci.yml` com análise, testes, build Android e deploy de funções |
| Documentação | README central atualizado e arquivo `instrucoes.txt` para onboarding técnico rápido |

## Arquitetura do projeto

A arquitetura é dividida em duas camadas principais. O frontend é um aplicativo Flutter com organização feature-first, gerenciamento de estado com Riverpod e roteamento com GoRouter. O backend utiliza Supabase como base relacional, autenticação, storage, realtime e execução serverless por Edge Functions.

| Camada | Tecnologias principais | Observações |
| --- | --- | --- |
| Frontend mobile | Flutter, Dart, Riverpod, GoRouter | App com múltiplas áreas funcionais e navegação extensa |
| Backend/BaaS | Supabase, PostgreSQL, RLS, Realtime, Storage | Schema evolutivo por migrações versionadas |
| Serverless | Supabase Edge Functions em TypeScript/Deno | Automação, moderação, notificações e integrações |
| CI/CD | GitHub Actions | Pipeline de análise, testes, build Android e deploy de funções |

## Módulos implementados no frontend

A árvore de `frontend/lib/features/` indica que o aplicativo já está organizado em módulos funcionais concretos. Isso confirma que a documentação deve tratar o projeto como uma base ampla de produto, não apenas como um mock visual.

| Módulo | Finalidade geral |
| --- | --- |
| `auth` | autenticação, onboarding e fluxo inicial |
| `chat` | lista de conversas, salas, grupos, chats públicos e chamadas |
| `communities` | descoberta, criação, detalhes, membros e gestão de comunidades |
| `explore` | exploração, busca e descoberta de conteúdo |
| `feed` | posts, blogs, enquetes, quizzes, drafts e detalhes de conteúdo |
| `gamification` | check-in, ranking, carteira, conquistas e inventário |
| `live` | screening rooms e experiências síncronas |
| `moderation` | central de denúncias, painel admin e ações moderativas |
| `notifications` | notificações globais e contextuais |
| `profile` | perfil global, perfil por comunidade, seguidores e mural |
| `settings` | privacidade, permissões, dispositivos, termos e contas vinculadas |
| `stickers` | exploração, criação e gerenciamento de stickers |
| `store` | loja e compra de moedas/itens |
| `stories` | criação e visualização de stories |
| `wiki` | visualização, criação e curadoria de wikis |

## Backend Supabase

O backend está concentrado em `backend/supabase/` e mostra um sistema versionado de forma consistente. As migrações vão de `001` até `074`, com algumas numerações ausentes no intervalo, o que é comum em ciclos reais de desenvolvimento. O conjunto cobre schema central, conteúdo, chat, moderação, economia, notificações, storage, RPCs, stories, stickers, sistema de blog, sistema de bloqueio, melhorias de screening room, short URLs e recursos de perfil/comunidade.

As Edge Functions atualmente presentes no repositório são as seguintes:

| Edge Function | Papel geral inferido pelo nome |
| --- | --- |
| `agora-token` | emissão/gestão de token para recursos em tempo real da Agora |
| `check-in` | rotinas de check-in/gamificação |
| `content-moderation-bot` | automação de moderação de conteúdo |
| `delete-user-data` | exclusão de dados do usuário |
| `export-user-data` | exportação de dados do usuário |
| `fetch-og-tags` | coleta de metadados Open Graph |
| `link-preview` | pré-visualização de links |
| `moderation` | lógica de moderação server-side |
| `push-notification` | envio de notificações push |
| `webhook-handler` | tratamento de webhooks/integradores |

## Configuração e credenciais

O repositório contém um template de variáveis em `frontend/.env.example`, mas a configuração principal do aplicativo atualmente também aparece centralizada em `frontend/lib/config/app_config.dart`. Na prática, isso significa que qualquer manutenção deve verificar os dois pontos antes de alterar setup, onboarding ou deploy.

> **Importante:** para análise, manutenção e onboarding técnico, considere `frontend/.env.example` como referência documental de configuração e `frontend/lib/config/app_config.dart` como ponto efetivo de consumo atual no app. Não replique segredos em documentação, issues, prompts ou commits públicos.

| Arquivo | Função |
| --- | --- |
| `frontend/.env.example` | template de variáveis do frontend |
| `frontend/lib/config/app_config.dart` | configuração principal atualmente usada pelo app |
| `backend/supabase/config.toml` | configuração do ambiente local do Supabase CLI |
| `.env.example` | referência adicional de ambiente na raiz do projeto |

## Fluxo de desenvolvimento local

Para trabalhar no projeto localmente, o caminho mais seguro é preparar o backend Supabase primeiro e, depois, executar o frontend Flutter. O backend local já possui configuração em `backend/supabase/config.toml`, seed habilitada e ports definidos para API, banco, Studio e serviços auxiliares.

### Backend local

```bash
cd backend/supabase
supabase start
supabase db reset
```

### Frontend local

```bash
cd frontend
cp .env.example .env
flutter pub get
flutter run
```

Se a configuração efetiva do projeto continuar centralizada em `app_config.dart`, qualquer alteração de ambiente deve ser validada também nesse arquivo antes de testes, builds ou depuração de integração.

## Testes e validação

A pasta `frontend/test/` mostra que o projeto possui testes de modelo, segurança, paginação, serviços, validadores e regressões específicas ligadas a fases recentes de correção. Isso sugere uma preocupação prática com estabilidade, especialmente em mudanças de RPC, fluxo de runtime e hardening de regressões.

| Arquivos de teste observados | Cobertura funcional aproximada |
| --- | --- |
| `models_test.dart` | modelos e serialização |
| `pagination_test.dart` | paginação e comportamento incremental |
| `security_test.dart` | segurança e permissões |
| `services_test.dart` | serviços centrais |
| `validators_test.dart` | validações de entrada |
| `phase3_*`, `runtime_*`, `regression_*`, `rpc_flow_*` | correções, regressões e estabilização recente |

Execução local dos testes:

```bash
cd frontend
flutter test
```

## CI/CD atual

O workflow em `.github/workflows/ci.yml` mostra uma pipeline real de integração contínua. O fluxo realiza análise estática, instalação de dependências, testes unitários, build Android e deploy das Edge Functions em condições específicas de branch e secrets.

| Job | Objetivo |
| --- | --- |
| `analyze` | análise estática e verificação de formatação |
| `test` | testes unitários com geração de coverage |
| `build-android` | build de APK em `main` |
| `build-release` | build AAB condicionado a commits `release:` em `main` |
| `deploy-functions` | deploy automatizado das Edge Functions via Supabase CLI |

## Estrutura resumida do repositório

A organização geral do repositório hoje pode ser entendida da seguinte forma:

```text
NexusHub/
├── backend/
│   ├── seed/
│   └── supabase/
│       ├── config.toml
│       ├── functions/
│       ├── migrations/
│       └── run_migrations.py
├── frontend/
│   ├── android/
│   ├── ios/
│   ├── assets/
│   ├── lib/
│   ├── patches/
│   ├── test/
│   └── pubspec.yaml
├── redirect/
├── scripts/
└── README.md
```

## Documentação complementar

A documentação foi propositalmente enxugada para reduzir ruído e evitar que relatórios históricos desatualizados confundam novas análises. A referência principal do projeto agora está concentrada neste `README.md`, enquanto o arquivo [`instrucoes.txt`](./instrucoes.txt) atua como guia curto de onboarding técnico para outras IAs ou colaboradores.

| Arquivo | Finalidade |
| --- | --- |
| `README.md` | visão atual do projeto, arquitetura, setup e estrutura |
| [`instrucoes.txt`](./instrucoes.txt) | resumo operacional para acelerar análise técnica |

## Observações práticas para manutenção

Este repositório deve ser tratado como uma base ativa e multifuncional. Antes de grandes mudanças, vale revisar o impacto em rotas, RPCs, políticas de acesso, integrações com Supabase e fluxos mobile nativos. Também é recomendável verificar se uma funcionalidade está documentada apenas em relatórios históricos ou se já está realmente refletida no código e nos testes.

## Licença e observação de referência

O repositório deve preservar a observação de que se trata de um projeto inspirado na experiência social do Amino, sem afiliação oficial com a marca original. Caso exista um arquivo de licença formal no projeto, ele deve ser considerado a fonte definitiva para uso e distribuição.
