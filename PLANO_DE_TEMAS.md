# Plano de Ação Técnico: Sistema de Temas do NexusHub

## 1. Visão Geral e Contexto
O NexusHub é um aplicativo Flutter com alta complexidade visual, replicando o estilo do Amino Apps. A auditoria atual do código revela que o gerenciamento de cores está fragmentado:
- Existem **2.582** ocorrências de cores *hardcoded* (`Color(0x...)` ou `Colors.*`) espalhadas pelo código.
- O arquivo `app_theme.dart` centraliza parte das cores, com **1.696** usos estáticos (ex: `AppTheme.primaryColor`).
- Uma extensão de contexto (`context.scaffoldBg`, `context.cardBg`) é usada **1.708** vezes, o que é um bom ponto de partida.
- O `Theme.of(context)` nativo do Flutter é subutilizado (apenas 44 ocorrências).
- Gradientes e sombras estão espalhados em mais de 120 e 110 ocorrências, respectivamente.

O objetivo deste plano é migrar essa arquitetura fragmentada para um sistema de temas centralizado, robusto e escalável, suportando múltiplos temas (Principal, Midnight, GreenLeaf) com troca em tempo real via Riverpod, conforme especificado no documento "Documentação Amino Nexus".

---

## 2. Arquitetura Proposta

A nova arquitetura será baseada em *Design Tokens* semânticos, gerenciados via Riverpod para reatividade instantânea, e acessados através de uma extensão no `BuildContext`.

### 2.1. Modelagem de Dados (`nexus_theme_data.dart`)
Criaremos uma interface/classe base que define todos os tokens visuais necessários. Isso elimina a dependência de cores *hardcoded* ou do `ThemeData` limitado do Material Design.

**Tokens principais:**
- **Fundos e Superfícies:** `backgroundPrimary`, `backgroundSecondary`, `surfacePrimary`, `cardBackground`, `modalBackground`.
- **Textos e Ícones:** `textPrimary`, `textSecondary`, `textMuted`, `iconPrimary`.
- **Destaques e Interações:** `accentPrimary`, `accentSecondary`, `buttonPrimaryBackground`, `selectedState`.
- **Estados Semânticos:** `success`, `error`, `warning`, `info`.
- **Efeitos Visuais:** `primaryGradient`, `fabGradient`, `cardShadow`, `shimmerBase`.

### 2.2. Catálogo de Temas (`nexus_themes.dart`)
Implementação concreta dos três temas exigidos:
1. **Principal:** Tema claro e vibrante (Ciano/Verde), mantendo a identidade original.
2. **Midnight:** Tema escuro premium (Roxo/Preto), focado em conforto visual noturno.
3. **GreenLeaf:** Tema claro natural (Verde/Branco), focado em leveza e frescor.

### 2.3. Gerenciamento de Estado (`nexus_theme_provider.dart`)
Um `StateNotifierProvider` do Riverpod que:
- Mantém o tema atual em memória.
- Persiste a escolha do usuário via `SharedPreferences`.
- Carrega o tema salvo na inicialização do app.

### 2.4. Extensão de Contexto (`nexus_theme_extension.dart`)
Uma extensão no `BuildContext` para acesso fácil aos tokens na camada de UI:
```dart
extension NexusThemeContext on BuildContext {
  NexusThemeData get nexusTheme => ref.watch(nexusThemeProvider); // Pseudo-código para simplificar
}
```
Isso permitirá substituir chamadas como `AppTheme.primaryColor` por `context.nexusTheme.accentPrimary`.

---

## 3. Estratégia de Refatoração

A migração será feita em fases para garantir que a UI não quebre durante o processo. O maior desafio são os arquivos com alta densidade de cores *hardcoded*.

### 3.1. Arquivos Críticos (Maior Densidade de Cores)
A auditoria identificou os seguintes arquivos como prioritários para refatoração:
1. `community_profile_screen.dart` (89 cores hardcoded)
2. `chat_room_screen.dart` (88 cores hardcoded)
3. `wallet_screen.dart` (74 cores hardcoded)
4. `create_story_screen.dart` (70 cores hardcoded)
5. `post_detail_screen.dart` (62 cores hardcoded)
6. `rgb_color_picker.dart` (58 cores hardcoded)

### 3.2. Componentes Base (Widgets Core)
Os widgets reutilizáveis devem ser refatorados primeiro, pois afetam todo o app:
- `amino_bottom_nav.dart`: Substituir gradientes e cores de fundo fixas.
- `amino_top_bar.dart`: Atualizar cores de ícones e pílula de moedas.
- `level_progress_bar.dart` e `level_up_dialog.dart`: Padronizar as cores de níveis com o novo sistema.
- `shimmer_loading.dart`: Utilizar os tokens `shimmerBase` e `shimmerHighlight` do tema ativo.

### 3.3. Integração Global
1. **`main.dart`:**
   - Injetar o `nexusThemeProvider`.
   - Mapear o `NexusThemeData` para o `ThemeData` do Material para garantir compatibilidade com widgets nativos (ex: `showModalBottomSheet`).
   - Ajustar o `SystemUiOverlayStyle` dinamicamente com base no `baseMode` do tema ativo.

2. **`app_theme.dart` (Legado):**
   - O arquivo será mantido temporariamente como *proxy* durante a transição, redirecionando suas chamadas estáticas para o novo sistema onde possível, ou sendo gradualmente descontinuado.

---

## 4. Nova Tela de Seleção de Temas

A tela atual de configurações (`settings_screen.dart`) possui um seletor simples (Claro/Escuro/Sistema).

**Nova Implementação:**
- Criação de uma rota dedicada: `/settings/themes` (`ThemeSelectorScreen`).
- A tela exibirá *cards* interativos para cada tema disponível.
- Cada *card* conterá um **preview visual** (uma mini-representação da interface do app usando as cores do tema).
- A seleção atualizará o `nexusThemeProvider` instantaneamente, refletindo a mudança em todo o app sem necessidade de reinicialização.

---

## 5. Passos de Execução (Roadmap)

| Fase | Tarefa | Risco |
| :--- | :--- | :--- |
| **1** | Criar arquivos base (`nexus_theme_data.dart`, `nexus_themes.dart`, `nexus_theme_extension.dart`). | Baixo |
| **2** | Implementar `nexus_theme_provider.dart` com persistência em `SharedPreferences`. | Baixo |
| **3** | Integrar o provider no `main.dart` e configurar o `MaterialApp`. | Médio |
| **4** | Desenvolver a `ThemeSelectorScreen` com previews visuais e atualizar rotas. | Baixo |
| **5** | Refatorar widgets *core* (`amino_bottom_nav.dart`, `amino_top_bar.dart`, `shimmer_loading.dart`). | Alto |
| **6** | Refatorar telas críticas identificadas na auditoria (Chat, Perfil, Wallet). | Alto |
| **7** | Busca e substituição global de `AppTheme.*` por `context.nexusTheme.*`. | Alto |
| **8** | Testes de consistência visual (Dark Mode vs Light Mode nos 3 temas). | Médio |

---

## 6. Considerações Finais e Riscos
- **Performance:** A leitura do tema via `context.nexusTheme` deve ser eficiente. O uso de `ref.watch` nos métodos `build` é o padrão recomendado pelo Riverpod.
- **Imagens de Fundo:** Telas como `chat_room_screen.dart` e `community_profile_screen.dart` usam imagens de fundo dinâmicas (`background_url`). O novo sistema de temas deve respeitar a legibilidade do texto sobre essas imagens (uso adequado de overlays escuros/claros dependendo da imagem, independente do tema base).
- **Gradientes Complexos:** O projeto faz uso intensivo de gradientes radiais e lineares (ex: `rgb_color_picker.dart`). Estes devem ser cuidadosamente migrados para garantir que não percam a fidelidade visual do design original do Amino.
