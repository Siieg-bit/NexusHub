# Planejamento do Ecossistema RPG (NexusHub)

O NexusHub introduzirá um **Ecossistema RPG** completo para comunidades, permitindo que os hosts criem experiências imersivas de roleplay, progressão e economia para seus membros. O sistema é flexível e modular, ativado exclusivamente pelo host da comunidade.

## 1. Visão Geral e Ativação

O modo RPG transforma a comunidade em um ambiente gamificado.
- **Ativação:** O host da comunidade ativa o "Modo RPG" no painel ACM (Amino Community Manager).
- **Controle Exclusivo:** Apenas o host (ou co-hosts delegados) pode configurar atributos, classes, economia e criar itens.
- **Adesão do Membro:** Os membros da comunidade podem criar um "Personagem" (Ficha RPG) vinculada àquela comunidade específica.

## 2. Estrutura de Dados (Banco de Dados)

O ecossistema será construído sobre as seguintes tabelas no Supabase:

### 2.1. `rpg_attributes_config`
Configuração global dos atributos permitidos na comunidade.
- `id` (UUID)
- `community_id` (UUID)
- `name` (TEXT) - Ex: Força, Agilidade, Inteligência, Mana, Vida.
- `type` (ENUM) - `stat` (valor numérico cumulativo) ou `resource` (valor atual/máximo, ex: HP).
- `icon_url` (TEXT)
- `color` (TEXT)

### 2.2. `rpg_classes` (Evolução de `community_roles`)
Classes ou raças que os jogadores podem escolher.
- `id` (UUID)
- `community_id` (UUID)
- `name` (TEXT)
- `description` (TEXT)
- `base_attributes` (JSONB) - Bônus iniciais (ex: `{"força": 5, "agilidade": 3}`).
- `color` (TEXT)
- `icon_url` (TEXT)

### 2.3. `rpg_characters` (Fichas de Personagem)
A ficha do jogador na comunidade.
- `id` (UUID)
- `community_id` (UUID)
- `user_id` (UUID)
- `name` (TEXT) - Nome do personagem (pode diferir do nickname global).
- `class_id` (UUID) - Referência a `rpg_classes`.
- `avatar_url` (TEXT)
- `bio` (TEXT) - História/Background.
- `level` (INT) - Nível atual.
- `xp` (INT) - Experiência acumulada.
- `currency_balance` (INT) - Dinheiro do personagem (Moeda RPG da comunidade).
- `attributes` (JSONB) - Valores atuais dos atributos.
- `status` (ENUM) - `alive`, `dead`, `inactive`.

### 2.4. `rpg_items`
Itens que podem ser comprados, dropados ou dados pelo host.
- `id` (UUID)
- `community_id` (UUID)
- `name` (TEXT)
- `description` (TEXT)
- `type` (ENUM) - `weapon`, `armor`, `consumable`, `quest_item`.
- `rarity` (ENUM) - `common`, `uncommon`, `rare`, `epic`, `legendary`.
- `price` (INT) - Valor na loja da comunidade.
- `attribute_modifiers` (JSONB) - Ex: `{"força": +2}`.
- `image_url` (TEXT)

### 2.5. `rpg_inventory`
Relação N:N entre personagens e itens.
- `id` (UUID)
- `character_id` (UUID)
- `item_id` (UUID)
- `quantity` (INT)
- `is_equipped` (BOOLEAN)

## 3. Painel do Host (RPG Master Panel)

Uma tela exclusiva (`/community/:id/rpg-admin`) acessível apenas pelo host.

### Seções do Painel:
1. **Configurações Gerais:**
   - Nome da Moeda (Ex: "Ouro", "Gemas", "Créditos").
   - Ícone da Moeda.
   - Multiplicador de XP global.
2. **Sistema de Atributos:**
   - Criar, editar e excluir atributos base que todas as fichas terão.
3. **Classes & Raças:**
   - Gerenciar as opções disponíveis para os jogadores.
4. **Bestiário / Loja de Itens:**
   - Criar itens que ficarão disponíveis na loja da comunidade ou para distribuição manual.
5. **Gerenciamento de Fichas (Painel do Mestre):**
   - Visualizar todas as fichas ativas.
   - Modificar XP, Dinheiro e Atributos de qualquer jogador (para recompensar ou punir eventos de roleplay).

## 4. Experiência do Jogador (Membro)

### 4.1. Criação de Personagem
- Ao entrar em uma comunidade com RPG ativo, o usuário vê um CTA: "Criar Ficha de Personagem".
- Fluxo: Escolher Nome, Classe/Raça, distribuir pontos iniciais (se configurado pelo host) e definir Avatar/Bio.

### 4.2. Perfil RPG (Ficha)
- O perfil do usuário na comunidade (`CommunityProfileScreen`) ganha uma aba "Ficha RPG".
- Exibe: Level, Barra de XP, Barra de Vida/Mana (se houver), Status, Atributos e Inventário.
- **Equipamentos:** Slots visuais para mostrar itens equipados.

### 4.3. Progressão e Interação
- **Chat:** Em chats de Roleplay, mensagens podem conceder XP passivamente (configurável pelo host).
- **Comandos/Dados:** Implementação futura de comandos de rolagem de dados (ex: `/roll 1d20`) no chat.
- **Loja:** Tela onde o jogador gasta sua `currency_balance` para comprar `rpg_items`.

## 5. Próximos Passos de Implementação

1. **Fase 3:** Criar a migration SQL (`190_rpg_ecosystem.sql`) com todas as tabelas, RLS (Row Level Security) e RPCs necessários (ex: `create_rpg_character`, `award_xp`, `buy_item`).
2. **Fase 4:** Desenvolver a UI do Painel do Host (`RpgAdminScreen`).
3. **Fase 5:** Desenvolver a UI da Ficha de Personagem no perfil da comunidade e o fluxo de criação de ficha.
