# Documentação Amino Nexus (NexusHub)

O **Amino Nexus** (codinome interno NexusHub) é uma plataforma social moderna, inspirada no clássico Amino, desenvolvida com Flutter (Frontend) e Supabase (Backend). O projeto visa recriar a experiência de comunidades focadas em interesses específicos, oferecendo chats em tempo real, blogs ricos, personalização visual avançada e um sistema de reputação.

## 1. Arquitetura do Projeto

O projeto segue uma arquitetura limpa e modular, dividida em features (funcionalidades) independentes, facilitando a manutenção e escalabilidade.

### 1.1. Frontend (Flutter)
- **Framework:** Flutter (Dart)
- **Gerenciamento de Estado:** Riverpod (`flutter_riverpod`)
- **Roteamento:** GoRouter (`go_router`)
- **Design System:** Tema customizado com suporte a Dark Mode (`AppTheme`)
- **Estrutura de Pastas:**
  - `lib/core/`: Componentes compartilhados, modelos, serviços (Supabase), utilitários e localização.
  - `lib/features/`: Módulos independentes do app (Chat, Feed, Communities, Profile, Stickers, Stories, Moderation).
  - `lib/config/`: Configurações globais, como temas e rotas.

### 1.2. Backend (Supabase)
- **Banco de Dados:** PostgreSQL (via Supabase)
- **Autenticação:** Supabase Auth (Email/Senha, OAuth)
- **Storage:** Supabase Storage para imagens, vídeos, áudios e stickers.
- **Realtime:** Supabase Realtime para chats e notificações.
- **Edge Functions / RPCs:** Funções PL/pgSQL para lógica complexa (ex: `get_wall_comments`, `create_story`).

## 2. Principais Funcionalidades (Features)

### 2.1. Comunidades (Communities)
O coração do Amino Nexus. Usuários podem criar e participar de comunidades temáticas.
- **Criação:** Definição de nome, descrição, idioma e cor de tema (via seletor RGB avançado).
- **ACM (Amino Community Manager):** Painel de administração para líderes customizarem o visual, gerenciarem membros e configurarem módulos.
- **Módulos:** Suporte a diferentes tipos de conteúdo dentro da comunidade (Feed, Chats Públicos, Wiki).

### 2.2. Feed e Posts
Sistema de conteúdo rico e interativo.
- **Tipos de Post:** Texto normal, Blog (com blocos de conteúdo), Imagem, Link, Enquete (Poll), Quiz, Pergunta (Q&A) e Story.
- **Editor de Blog:** Suporte a blocos intercalados de texto, imagens inline e formatação rica.
- **Personalização:** Autores podem definir cor de fundo e cor do título de seus posts.
- **Comentários:** Sistema de comentários aninhados com suporte a texto, imagens e stickers.

### 2.3. Chat em Tempo Real
Sistema de mensagens instantâneas robusto.
- **Tipos de Mensagem:** Texto, Imagem, GIF, Vídeo, Áudio (Voice Note) e Stickers.
- **Visualizador de Mídia:** Imagens e GIFs abrem em um visualizador fullscreen com suporte a zoom (pinch-to-zoom) e salvamento na galeria (long press).
- **Cosméticos:** Usuários podem equipar "Chat Bubbles" personalizados (molduras e cores) que alteram a aparência de suas mensagens.
- **Salas de Projeção e Voice Chat:** Suporte a chamadas de voz e vídeo em grupo.

### 2.4. Perfil e Mural (Wall)
- **Mural:** Um espaço no perfil do usuário onde outros podem deixar mensagens públicas (texto, imagens, stickers).
- **Cosméticos de Perfil:** Avatares com molduras animadas e fundos de perfil customizáveis.
- **Reputação:** Sistema de níveis baseado em engajamento (check-ins, posts, tempo online).

### 2.5. Stickers e Loja
- **Criação de Stickers:** Ferramenta embutida para criar stickers a partir de imagens da galeria, adicionando textos, emojis e cores de fundo/texto.
- **Packs:** Stickers são organizados em pacotes que podem ser favoritados e usados nos chats e comentários.

## 3. Componentes Core (UI)

O projeto possui uma biblioteca de widgets reutilizáveis em `lib/core/widgets/`:

- **`ImageViewer` (`showImageViewer` / `showSingleImageViewer`):** Modal fullscreen para visualização de imagens com suporte a gestos, hero animation e salvamento.
- **`TappableImage`:** Wrapper para imagens que automaticamente integra o `ImageViewer`.
- **`RGBColorPicker` (`showRGBColorPicker` / `ColorPickerButton`):** Modal avançado para seleção de cores, contendo roda HSV, sliders RGB, campo HEX e paletas de cores recentes/predefinidas.
- **`CosmeticAvatar`:** Widget que renderiza a foto de perfil do usuário com sua respectiva moldura cosmética equipada.

## 4. Fluxo de Desenvolvimento e Contribuição

1. **Padrão de Código:** O projeto utiliza `flutter_lints`. Mantenha o código limpo e tipado.
2. **Gerenciamento de Estado:** Sempre use `ConsumerWidget` ou `ConsumerStatefulWidget` do Riverpod para acessar providers. Evite `setState` para estados globais.
3. **Responsividade:** Utilize a extensão `.r` (ex: `context.r.s(16)`) do `Responsive` para garantir que a UI escale corretamente em diferentes tamanhos de tela.
4. **Internacionalização:** Use `getStrings()` do `LocaleProvider` para textos na UI, garantindo suporte a múltiplos idiomas.

---
*Documentação gerada automaticamente para o projeto NexusHub.*
