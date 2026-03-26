# NexusHub (Amino Clone)

NexusHub é um aplicativo mobile completo inspirado no antigo **Amino Apps**, construído com uma arquitetura moderna, segura e escalável, projetado para permitir o desenvolvimento paralelo entre Frontend e Backend.

O objetivo deste projeto é copiar diretamente, de forma evoluída, o conceito de comunidades sociais com chat, feed, wiki e gamificação.

## 🏗️ Arquitetura do Sistema

O sistema está dividido em duas camadas principais:

### 1. FRONTEND (App Mobile)
- **Framework:** Flutter (Dart)
- **Gerenciamento de Estado:** Riverpod
- **Roteamento:** GoRouter
- **Design:** Tema escuro (Dark Theme) inspirado no Amino, com componentes customizados.
- **Funcionalidades:**
  - Autenticação (Login/Cadastro)
  - Descoberta de Comunidades (Explore)
  - Feed Global e Feed de Comunidades
  - Chat em Tempo Real (WebSocket via Supabase Realtime)
  - Wiki de Comunidades
  - Perfil de Usuário
  - Gamificação (Check-in Diário, Níveis, XP, Ranking)
  - Notificações

### 2. BACKEND (API + Banco + Realtime)
- **BaaS (Backend as a Service):** Supabase (PostgreSQL)
- **Autenticação:** Supabase Auth (Email/Senha, Social Logins)
- **Banco de Dados:** PostgreSQL com Row Level Security (RLS) para segurança em nível de linha.
- **Tempo Real:** Supabase Realtime para Chats e Notificações.
- **Armazenamento:** Supabase Storage para Avatares, Banners e Mídias de Posts.
- **Lógica de Negócio:** Supabase Edge Functions (Deno/TypeScript) e RPCs (Postgres Functions).

---

## 🚀 Como Executar o Projeto

Este projeto foi desenhado para ser desenvolvido por dois desenvolvedores em paralelo.

### Configuração do Backend (Desenvolvedor 1)

O backend é inteiramente baseado no Supabase. Para configurar:

1. Crie um projeto no [Supabase](https://supabase.com).
2. Vá para o SQL Editor no painel do Supabase.
3. Execute os arquivos SQL localizados em `backend/supabase/migrations/` na seguinte ordem:
   - `001_initial_schema.sql` (Criação das tabelas)
   - `002_rls_policies.sql` (Regras de segurança)
   - `003_rpc_functions.sql` (Funções de banco de dados para gamificação, etc.)
   - `004_realtime_storage.sql` (Configuração de buckets e realtime)
4. (Opcional) Execute `backend/seed/seed_data.sql` para popular o banco com dados de teste.
5. Copie a **URL do Projeto** e a **Chave Anon (public)** nas configurações de API do Supabase.

### Configuração do Frontend (Desenvolvedor 2)

O frontend é um aplicativo Flutter.

1. Instale o [Flutter SDK](https://flutter.dev/docs/get-started/install).
2. Navegue até a pasta `frontend/`:
   ```bash
   cd frontend
   ```
3. Instale as dependências:
   ```bash
   flutter pub get
   ```
4. Configure as variáveis de ambiente. No arquivo `lib/config/app_config.dart`, substitua pelas suas credenciais do Supabase:
   ```dart
   static const String supabaseUrl = 'SUA_URL_AQUI';
   static const String supabaseAnonKey = 'SUA_CHAVE_AQUI';
   ```
5. Execute o aplicativo:
   ```bash
   flutter run
   ```

---

## 🔍 Engenharia Reversa do Amino

Este projeto foi construído com base em uma análise detalhada (engenharia reversa) do APK original do Amino (versão 3.5.35109). As descobertas detalhadas podem ser encontradas no documento `amino_reverse_engineering.md` incluído na entrega.

Principais descobertas aplicadas ao NexusHub:
- **Estrutura de Modelos:** Como o Amino organiza `User`, `Community`, `Blog` (Post), `Comment`, `Item` (Wiki) e `Chat`.
- **Comunicação em Tempo Real:** O Amino usa WebSockets (`wss://wsX.narvii.com`) para chats e notificações. No NexusHub, replicamos isso usando Supabase Realtime.
- **Sistema de Gamificação:** Implementamos a lógica de Check-In Diário, Níveis baseados em Reputação (XP) e Moedas (Coins), exatamente como no app original.
- **Hierarquia de Permissões:** Líderes, Curadores e Membros, implementados de forma segura usando PostgreSQL RLS (Row Level Security).

---

## 📄 Estrutura de Pastas

```text
amino_clone/
├── backend/
│   ├── supabase/
│   │   ├── migrations/      # Scripts SQL de criação do banco e RLS
│   │   └── functions/       # Edge Functions (TypeScript)
│   └── seed/                # Dados de teste
│
├── frontend/
│   ├── lib/
│   │   ├── config/          # Tema e configurações da API
│   │   ├── core/            # Modelos de dados e serviços centrais (Supabase)
│   │   ├── features/        # Módulos do app (auth, feed, chat, etc.)
│   │   ├── router/          # Configuração de rotas (GoRouter)
│   │   └── main.dart        # Ponto de entrada do app
│   └── pubspec.yaml         # Dependências do Flutter
│
└── README.md                # Este arquivo
```

## 👨‍💻 Fluxo de Trabalho Recomendado

1. **Desenvolvedor Backend:** Foca na pasta `backend/`. Modifica esquemas SQL, cria novas políticas RLS e desenvolve Edge Functions para lógicas complexas (ex: processamento de pagamentos, moderação via IA).
2. **Desenvolvedor Frontend:** Foca na pasta `frontend/`. Constrói as interfaces em Flutter, integra com o Supabase usando o `SupabaseService` e gerencia o estado global com Riverpod.

Ambos os desenvolvedores podem trabalhar independentemente, concordando previamente com os modelos de dados (já definidos em `lib/core/models/`).
