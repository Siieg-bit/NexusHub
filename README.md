# NexusHub (Amino Clone)

![NexusHub Banner](https://via.placeholder.com/1200x400/0D1B2A/00BCD4?text=NexusHub+-+The+Ultimate+Community+Platform)

NexusHub é um aplicativo mobile completo inspirado no clássico **Amino Apps**, construído com uma arquitetura moderna, segura e escalável. O projeto recria a experiência de comunidades sociais com chat em tempo real, feed de posts, wiki colaborativa e um robusto sistema de gamificação.

---

## 🌟 Principais Funcionalidades

### 👥 Sistema de Comunidades
- **Descoberta:** Tela Explore com categorias, busca global e recomendações.
- **Perfis Isolados:** Os usuários podem ter perfis diferentes (nickname, avatar, bio) em cada comunidade.
- **Customização:** Líderes podem alterar o tema, ícone, banner e links gerais da comunidade.
- **Módulos Dinâmicos:** Habilite ou desabilite módulos como Chat, Wiki, Shared Folder e Screening Rooms.

### 💬 Comunicação em Tempo Real
- **Chats Globais e Locais:** Salas de chat públicas, privadas e em grupo.
- **Recursos Ricos:** Envio de imagens, stickers, GIFs, mensagens de voz e reações.
- **Indicadores:** Status de "digitando" e presença online via WebSockets.
- **Screening Rooms:** Assista a vídeos do YouTube em grupo com chat de voz integrado (via SDK Agora).

### 📝 Criação de Conteúdo
- **Feed Global e Local:** Algoritmo de feed com suporte a posts fixados e destaques.
- **Rich Text Editor:** Criação de blogs com blocos de texto, imagens inline, enquetes e quizzes.
- **Wiki Colaborativa:** Sistema de pastas, submissão para curadoria e fixação no perfil.
- **Stories:** Conteúdo efêmero em formato de vídeo/imagem estilo Reels.

### 🎮 Gamificação e Economia
- **Reputação (XP):** Ganhe pontos por check-in diário, tempo online e engajamento.
- **Níveis (1 a 20):** Títulos customizáveis por comunidade (ex: "Newcomer" até "Supreme").
- **Leaderboard:** Ranking animado com pódio (Top 3) e filtros por período (Semana/Mês/Geral).
- **Nexus Coins:** Moeda virtual para comprar molduras de avatar (frames) e balões de chat customizados na Loja.

### 🛡️ Moderação e Segurança
- **Hierarquia de Cargos:** Agent (Criador), Leader, Curator e Member.
- **Painel de Moderação:** Central de denúncias (Flag Center), histórico de moderação e ações rápidas (Ban, Strike, Mute).
- **Filtro de Conteúdo:** Integração com IA para detecção de toxicidade e imagens NSFW via Edge Functions.

---

## 🏗️ Arquitetura do Sistema

O sistema adota uma arquitetura Serverless orientada a eventos, dividida em duas camadas principais:

### 1. FRONTEND (App Mobile)
- **Framework:** Flutter (Dart)
- **Gerenciamento de Estado:** Riverpod
- **Roteamento:** GoRouter com suporte a Deep Links (`nexushub://`)
- **Design System:** Tema escuro nativo (`AppTheme`) com componentes pixel-perfect inspirados no Amino.
- **Armazenamento Local:** Hive (Cache offline-first) e SharedPreferences.

### 2. BACKEND (BaaS - Supabase)
- **Banco de Dados:** PostgreSQL com 30+ tabelas relacionais.
- **Segurança:** Row Level Security (RLS) garantindo que usuários só acessem o que têm permissão.
- **Autenticação:** Supabase Auth (Email/Senha, Google, Apple).
- **Tempo Real:** Supabase Realtime (Presence, Broadcast e Postgres Changes).
- **Armazenamento:** Supabase Storage (Avatares, Banners, Mídias).
- **Lógica de Servidor:** Edge Functions (Deno/TypeScript) para tarefas assíncronas (Push Notifications, Webhooks, Moderação).

---

## 🚀 Como Executar o Projeto

### Pré-requisitos
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (v3.24+)
- [Supabase CLI](https://supabase.com/docs/guides/cli) (Para rodar o backend localmente)
- Conta no [Supabase](https://supabase.com) (Para produção)

### 1. Configuração do Backend (Supabase)

1. Crie um projeto no Supabase.
2. No painel do Supabase, vá em **SQL Editor** e execute as migrações localizadas em `backend/supabase/migrations/` em ordem sequencial (de `001` a `030`).
3. Configure os buckets no **Storage**: `avatars`, `banners`, `chat-media`, `post-media`.
4. Obtenha a **URL do Projeto** e a **Chave Anon (public)** nas configurações de API.

*(Opcional) Para rodar localmente:*
```bash
cd backend/supabase
supabase start
supabase db reset
```

### 2. Configuração do Frontend (Flutter)

1. Clone o repositório e navegue até a pasta do frontend:
```bash
git clone https://github.com/seu-usuario/NexusHub.git
cd NexusHub/frontend
```

2. Instale as dependências:
```bash
flutter pub get
```

3. Configure as variáveis de ambiente. Crie um arquivo `.env` na raiz da pasta `frontend/` (baseado no `.env.example` se existir) ou edite `lib/config/app_config.dart`:
```dart
static const String supabaseUrl = 'SUA_URL_AQUI';
static const String supabaseAnonKey = 'SUA_CHAVE_AQUI';
static const String agoraAppId = 'SEU_AGORA_APP_ID'; // Para Screening Rooms
```

4. Execute o aplicativo:
```bash
flutter run
```

---

## 📁 Estrutura de Diretórios

```text
NexusHub/
├── backend/
│   └── supabase/
│       ├── functions/       # Edge Functions (TypeScript/Deno)
│       └── migrations/      # Scripts SQL (Schema, RLS, RPCs)
│
├── frontend/
│   ├── android/             # Configurações nativas Android
│   ├── ios/                 # Configurações nativas iOS
│   ├── lib/
│   │   ├── config/          # Temas, rotas e constantes
│   │   ├── core/            # Serviços (Supabase, Cache), Utils e Widgets globais
│   │   ├── features/        # Módulos da aplicação (Feature-First Architecture)
│   │   │   ├── auth/        # Login, Cadastro, Onboarding
│   │   │   ├── communities/ # Descoberta, Perfil da Comunidade, Configurações
│   │   │   ├── feed/        # Feed Global, Criação de Posts, Comentários
│   │   │   ├── chat/        # Lista de Chats, Salas de Mensagens
│   │   │   ├── gamification/# Leaderboard, Check-in, Loja, Inventário
│   │   │   ├── moderation/  # Flag Center, Ações de Admin
│   │   │   └── profile/     # Perfil de Usuário, Mural, Seguidores
│   │   └── main.dart        # Ponto de entrada
│   └── pubspec.yaml         # Dependências Flutter
│
└── docs/                    # Documentação de engenharia reversa e UI
```

---

## 🧪 Testes e Qualidade

O projeto possui uma suíte de testes unitários cobrindo as regras de negócio principais:

```bash
cd frontend
flutter test
```
- `models_test.dart`: Validação de serialização/desserialização JSON.
- `security_test.dart`: Testes de permissões e roles (Leader vs Member).
- `validators_test.dart`: Validação de formulários (Email, Senha, Nickname).
- `pagination_test.dart`: Lógica de paginação do feed e chat.

---

## 🛠️ CI/CD (GitHub Actions)

O projeto inclui workflows automatizados em `.github/workflows/ci.yml`:
- **PRs para `main`:** Executa `flutter analyze` e `flutter test`.
- **Push na `main`:** Faz o build do APK (Debug) e AAB (Release) para Android.
- **Deploy de Edge Functions:** Sincroniza automaticamente as funções serverless com o Supabase.

---

## 📄 Licença

Este projeto é distribuído sob a licença MIT. Veja o arquivo `LICENSE` para mais detalhes.

*Nota: Este é um projeto educacional e de portfólio. "Amino" e "Amino Apps" são marcas registradas da MediaLab AI, Inc. Este projeto não tem afiliação com a MediaLab.*
