# Análise e Arquitetura do Sistema - Plataforma de Comunidades (Clone Amino)

**Autor:** Manus AI

Este documento detalha a arquitetura do sistema para a nova plataforma de comunidades inspirada no aplicativo Amino. A arquitetura foi elaborada com base na engenharia reversa do APK original (versão 3.5.35109) e nas melhores práticas modernas de desenvolvimento mobile e backend, utilizando Flutter e Supabase.

## Visão Geral do Sistema

O sistema é projetado como uma plataforma multi-tenant onde os usuários podem criar e participar de comunidades temáticas (fandoms). A estrutura principal do aplicativo original foi mantida, mas a implementação técnica foi modernizada para garantir maior leveza, segurança e escalabilidade. O aplicativo será dividido em duas camadas principais, permitindo o desenvolvimento paralelo por dois desenvolvedores distintos.

A comunicação entre o cliente e o servidor ocorrerá através de chamadas REST para operações CRUD tradicionais e conexões WebSocket (via Supabase Realtime) para funcionalidades que exigem baixa latência, como o chat e atualizações de feed em tempo real. A engenharia reversa do aplicativo original revelou o uso intensivo de WebSockets com estratégias de reconexão e *ping/pong* a cada 60 segundos, padrão que será replicado nativamente pelo SDK do Supabase.

## Divisão de Responsabilidades

O desenvolvimento será executado de forma paralela, com responsabilidades estritamente definidas para garantir a coesão do produto final.

| Desenvolvedor | Camada | Tecnologias | Responsabilidades Principais |
| --- | --- | --- | --- |
| Dev 1 | Frontend (App) | Flutter, Riverpod, Dart | UI/UX, Navegação, Gerenciamento de Estado, Integração com API, Lógica de Apresentação, Tratamento de WebSockets no cliente. |
| Dev 2 | Backend (Infra) | Supabase, PostgreSQL, Edge Functions | Modelagem de Banco de Dados, Autenticação, Row Level Security (RLS), Funções RPC, Configuração de Realtime e Storage. |

## Modelagem de Dados Baseada na Engenharia Reversa

A análise dos arquivos *smali* do APK original revelou uma estrutura de dados rica e interconectada. Os modelos abaixo foram adaptados para o PostgreSQL do Supabase, incorporando os campos mais relevantes descobertos durante a pesquisa.

### Tabela: users
Esta tabela armazena as informações globais dos usuários na plataforma.

| Campo | Tipo | Descrição |
| --- | --- | --- |
| id | UUID | Identificador único (Primary Key), integrado ao Supabase Auth. |
| amino_id | VARCHAR | Nome de usuário único e amigável (ex: @user123). |
| nickname | VARCHAR | Nome de exibição do usuário. |
| avatar_url | TEXT | URL para a imagem de perfil armazenada no Supabase Storage. |
| bio_content | TEXT | Biografia ou descrição do perfil. |
| global_level | INT | Nível global do usuário na plataforma. |
| reputation | INT | Pontuação de reputação global (XP). |
| online_status | INT | Status de conexão (1 = Online, 2 = Offline). |
| created_at | TIMESTAMPTZ | Data e hora de criação da conta. |

### Tabela: communities
Representa as comunidades temáticas criadas pelos usuários. O aplicativo original utilizava o conceito de *ndcId* para identificar comunidades; aqui utilizaremos UUIDs.

| Campo | Tipo | Descrição |
| --- | --- | --- |
| id | UUID | Identificador único da comunidade (Primary Key). |
| name | VARCHAR | Nome da comunidade. |
| tagline | VARCHAR | Slogan ou frase de efeito curta. |
| description | TEXT | Descrição detalhada e regras da comunidade. |
| icon_url | TEXT | URL do ícone ou logo da comunidade. |
| owner_id | UUID | Referência ao usuário criador (Foreign Key para users). |
| primary_language | VARCHAR | Idioma principal (ex: pt-BR). |
| members_count | INT | Contador em cache do número de membros. |
| created_at | TIMESTAMPTZ | Data de criação da comunidade. |

### Tabela: community_members
Gerencia o relacionamento entre usuários e comunidades, incluindo papéis e permissões específicas. A engenharia reversa indicou papéis como USER, CURATOR, LEADER e AGENT.

| Campo | Tipo | Descrição |
| --- | --- | --- |
| user_id | UUID | Referência ao usuário (Foreign Key). |
| community_id | UUID | Referência à comunidade (Foreign Key). |
| role | INT | Papel do usuário (0 = User, 100 = Curator, 101 = Leader, 102 = Agent). |
| reputation | INT | Reputação específica do usuário dentro desta comunidade. |
| joined_at | TIMESTAMPTZ | Data em que o usuário entrou na comunidade. |

### Tabela: posts (Feed/Blogs)
Engloba o conteúdo gerado no feed. No Amino original, *Blogs*, *Polls* e *Quizzes* estendiam um modelo base de *Feed*.

| Campo | Tipo | Descrição |
| --- | --- | --- |
| id | UUID | Identificador único do post (Primary Key). |
| community_id | UUID | Comunidade onde o post foi publicado (Foreign Key). |
| author_id | UUID | Autor do post (Foreign Key para users). |
| title | VARCHAR | Título do post (opcional para posts simples). |
| content | TEXT | Conteúdo principal em formato rico ou Markdown. |
| media_urls | JSONB | Lista de URLs de mídias anexadas ao post. |
| post_type | INT | Tipo de post (1 = Blog, 2 = Image, 3 = Link, 4 = Wiki/Item). |
| likes_count | INT | Contador em cache de curtidas. |
| comments_count| INT | Contador em cache de comentários. |
| created_at | TIMESTAMPTZ | Data de publicação. |

### Tabela: comments
Estrutura hierárquica para comentários em posts, suportando subcomentários (respostas).

| Campo | Tipo | Descrição |
| --- | --- | --- |
| id | UUID | Identificador único do comentário (Primary Key). |
| post_id | UUID | Post ao qual o comentário pertence (Foreign Key). |
| author_id | UUID | Autor do comentário (Foreign Key para users). |
| parent_id | UUID | Referência a outro comentário, caso seja uma resposta. |
| content | TEXT | Texto do comentário. |
| created_at | TIMESTAMPTZ | Data de publicação do comentário. |

### Tabela: messages (Chat Realtime)
Base para o sistema de chat em tempo real, que é um dos pilares do aplicativo.

| Campo | Tipo | Descrição |
| --- | --- | --- |
| id | UUID | Identificador único da mensagem (Primary Key). |
| community_id | UUID | Comunidade onde o chat ocorre (Foreign Key). |
| sender_id | UUID | Usuário que enviou a mensagem (Foreign Key). |
| content | TEXT | Conteúdo da mensagem (texto). |
| media_url | TEXT | URL de mídia anexada (imagem, áudio). |
| created_at | TIMESTAMPTZ | Data e hora exata do envio. |

## Arquitetura de Segurança (RLS)

A segurança é um aspecto crítico do sistema, especialmente devido à natureza multi-tenant das comunidades. O Supabase utilizará Row Level Security (RLS) em todas as tabelas para garantir que os dados sejam acessados apenas por usuários autorizados.

As seguintes políticas RLS serão implementadas:
- **users:** Leitura pública para perfis, mas edição restrita ao próprio usuário autenticado.
- **communities:** Leitura pública para comunidades listadas. Edição restrita aos usuários com papel de *Leader* ou *Agent* na tabela `community_members`.
- **community_members:** Leitura pública dentro da comunidade. Inserção permitida para usuários autenticados que desejam entrar na comunidade.
- **posts & comments:** Leitura permitida para membros da comunidade. Inserção restrita a membros autenticados. Edição e deleção restritas ao autor ou moderadores (*Curators* e *Leaders*).
- **messages:** Leitura e inserção estritamente limitadas aos membros da respectiva comunidade.

## Gamificação e Check-in

A análise do código original revelou a classe `CheckInHistory`, responsável por rastrear a sequência de logins diários (`consecutiveCheckInDays`). Este sistema será replicado utilizando Edge Functions do Supabase ou RPCs (Remote Procedure Calls) no PostgreSQL, que serão acionadas na primeira abertura do aplicativo a cada dia, incrementando a reputação do usuário e atualizando seu histórico de *streaks*.

## Considerações sobre o Frontend

O aplicativo Flutter seguirá os princípios da *Clean Architecture* e será organizado pelo padrão *Feature-first*. O gerenciamento de estado com Riverpod garantirá que as atualizações em tempo real via WebSocket reflitam imediatamente na interface do usuário, sem necessidade de recarregamentos manuais, proporcionando uma experiência fluida e moderna, superando as limitações de performance observadas no aplicativo original.

---
**Próximos Passos:** O desenvolvimento prosseguirá com a configuração do backend no Supabase (Fase 3), incluindo a criação das tabelas, políticas RLS e funções de banco de dados, seguido pela implementação do frontend em Flutter (Fase 4).
