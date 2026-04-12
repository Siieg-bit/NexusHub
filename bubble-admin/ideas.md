# NexusHub Bubble Admin — Design Ideas

## Contexto
Painel interno privado para Team Members criarem chat bubbles para a loja do NexusHub.
Fluxo principal: login Supabase → upload imagem 128x128 → definir nome/preço → publicar na loja.

---

<response>
<text>
## Ideia 1 — Dark Terminal Craft

**Design Movement:** Neubrutalism meets Dark Dev Tools

**Core Principles:**
- Contraste extremo: fundo quase preto com acentos neon rosa/magenta (cor do Heart Bubble)
- Tipografia monospace para campos técnicos, sans-serif bold para títulos
- Bordas sólidas visíveis, sem sombras difusas — cada elemento tem peso visual próprio
- Sensação de "ferramenta interna" — não tenta ser bonito, mas é preciso e funcional

**Color Philosophy:**
- Background: #0D0D0F (quase preto)
- Surface: #141418 (cards)
- Accent: #E040FB (rosa/magenta — cor do Heart Bubble)
- Text: #F0F0F0 com variações de opacidade
- Success: #00E676 (verde neon)

**Layout Paradigm:**
- Sidebar fixa à esquerda com navegação mínima
- Área principal dividida em dois painéis: formulário à esquerda, preview do bubble à direita
- Preview mostra o bubble em contexto real de chat (simulação de conversa)

**Signature Elements:**
- Borda neon rosa no card ativo
- Grid de pontos sutis no background
- Badge "TEAM ONLY" no header com animação de pulso

**Interaction Philosophy:**
- Feedback imediato: preview atualiza em tempo real ao mudar nome/cor
- Upload com drag-and-drop e validação visual de dimensões (128x128)
- Toast notifications estilo terminal

**Animation:**
- Entrada dos cards com slide-in suave da esquerda
- Preview do bubble com bounce ao carregar nova imagem
- Botão de publicar com shimmer ao fazer hover

**Typography System:**
- Títulos: Space Grotesk Bold
- Labels técnicos: JetBrains Mono
- Body: Inter Regular
</text>
<probability>0.08</probability>
</response>

<response>
<text>
## Ideia 2 — Glassmorphism Soft Studio

**Design Movement:** Glassmorphism + Soft UI (Neumorphism leve)

**Core Principles:**
- Fundo gradiente roxo/azul escuro com blur nos cards
- Transparência e profundidade como linguagem visual principal
- Elementos flutuam sobre o fundo — sensação de painel premium
- Cores do NexusHub (verde Amino + rosa bubble) como acentos

**Color Philosophy:**
- Background: gradiente #1A0533 → #0D1B4B
- Cards: rgba(255,255,255,0.06) com backdrop-blur
- Primary: #7C3AED (roxo)
- Accent: #E040FB (rosa bubble)
- Text: branco com opacidades variadas

**Layout Paradigm:**
- Layout centralizado com max-width 900px
- Card único de criação com seções colapsáveis
- Preview flutuante à direita como "sticker" sobre o fundo

**Signature Elements:**
- Gradiente de borda nos cards (border-image)
- Partículas sutis animadas no fundo
- Avatar do usuário logado no canto superior direito com frame

**Interaction Philosophy:**
- Formulário em etapas (step 1: upload, step 2: detalhes, step 3: confirmar)
- Cada etapa com animação de transição

**Animation:**
- Fade + scale nas transições de step
- Glow pulsante no botão de publicar

**Typography System:**
- Títulos: Sora Bold
- Body: Nunito
</text>
<probability>0.07</probability>
</response>

<response>
<text>
## Ideia 3 — Stark Admin Precision

**Design Movement:** Swiss International Style + Dark Admin

**Core Principles:**
- Grid rígido e tipografia como estrutura visual principal
- Fundo escuro neutro (não preto puro) com hierarquia clara por peso tipográfico
- Cor usada com parcimônia — apenas para ações e estados
- Eficiência máxima: tudo visível, nada escondido

**Color Philosophy:**
- Background: #111214 (cinza escuro neutro)
- Surface: #1C1E22
- Border: #2A2D34
- Primary: #E040FB (rosa — cor identitária do bubble)
- Secondary: #4ADE80 (verde — sucesso/publicado)
- Text: #E8E8E8 / #9CA3AF

**Layout Paradigm:**
- Sidebar esquerda estreita (64px) com ícones apenas
- Área principal com split 60/40: formulário | preview
- Preview mostra simulação de chat com o bubble aplicado em mensagens reais
- Lista de bubbles existentes na parte inferior como grid de cards

**Signature Elements:**
- Linha vertical colorida à esquerda do card ativo
- Tag de status (Ativo/Rascunho) com cor sólida
- Contador de itens na loja no header

**Interaction Philosophy:**
- Tudo em uma única página — sem navegação entre steps
- Upload, preview e publicação visíveis simultaneamente
- Validação inline com mensagens precisas

**Animation:**
- Micro-animações apenas: hover states, focus rings, loading spinners
- Preview do bubble atualiza com crossfade suave

**Typography System:**
- Títulos: DM Sans Bold
- Labels: DM Mono (campos técnicos)
- Body: DM Sans Regular
</text>
<probability>0.09</probability>
</response>
