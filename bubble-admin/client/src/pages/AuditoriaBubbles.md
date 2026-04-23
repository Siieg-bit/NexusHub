# Auditoria e Proposta de Refatoração: Editor de Bubbles (Nine-Slice)

## 1. Problemas Identificados (Bugs e Gambiarras)

### 1.1. Gerenciamento de Estado e Ciclo de Vida da Imagem
- **Cache Global Imperfeito:** O uso de `_imgCache` e `_imgLoading` globais fora do ciclo de vida do React causa condições de corrida. O `NineSliceBubble` tenta ler o cache de forma síncrona na montagem, mas se a Promise do `loadImageCached` ainda não resolveu, ele renderiza em branco e não reage quando a Promise termina (pois o `useEffect` não escuta mudanças no cache global).
- **Vazamento de Memória (Memory Leak):** O `URL.createObjectURL(file)` é chamado no `handleFile`, mas nunca é revogado (`URL.revokeObjectURL`). Cada nova imagem enviada cria um novo blob na memória que só é limpo ao recarregar a página.
- **Múltiplos Carregamentos Simultâneos:** O `NineSliceTextPreview` renderiza 3 instâncias de `NineSliceBubble` simultaneamente. Mesmo com o cache, isso gera complexidade desnecessária e flashes na tela.

### 1.2. Arquitetura do Canvas e Performance
- **Redesenho Excessivo:** O `NineSliceBubble` redesenha o canvas inteiro a cada mudança de texto ou de slice. Para o preview em tempo real (onde o usuário digita o texto), isso causa recálculos pesados de quebra de linha (`measureText`) e redesenho de 9 recortes de imagem a cada tecla pressionada.
- **Cálculo de Largura/Altura Frágil:** A lógica de `totalW` e `totalH` mistura valores de slice com padding interno de forma confusa, o que já causou bugs anteriores (como o balão esticando com textos curtos).
- **Falta de Suporte a High-DPI (Retina):** O canvas não usa `window.devicePixelRatio`. Em telas modernas (MacBooks, celulares), o texto e as bordas do balão ficam borrados/pixelados.

### 1.3. Tipagem e Estrutura de Dados
- **`asset_config` Não Tipado:** O `asset_config` é salvo e lido como `Record<string, unknown>`. Isso obriga o uso de casts manuais (`as number`, `as string`) em todo o código, facilitando erros de digitação (ex: `font_size` vs `fontSize`).
- **Formulário Monolítico:** O estado `form` contém todas as propriedades misturadas (nome, preço, slices, tipografia). Isso torna o `BubblesDashboard` gigante e difícil de manter.

### 1.4. UX do Editor Nine-Slice
- **Cálculo de Hitbox Inpreciso:** A detecção de qual linha está sendo arrastada (`getHandleAt`) usa coordenadas absolutas misturadas com escala, o que pode falhar se o canvas for redimensionado.
- **Falta de Limites Seguros (Constraints):** O usuário pode arrastar a linha `top` para baixo da linha `bottom`, quebrando a lógica do nine-slice (as regiões centrais ficam com altura negativa).

---

## 2. Proposta de Nova Arquitetura (Boas Práticas)

### 2.1. Separação de Responsabilidades (Componentização)
O arquivo `Dashboard.tsx` deve ser dividido ou, no mínimo, ter suas responsabilidades claramente separadas:
1. **`useImageLoader` (Hook Customizado):** Gerencia o carregamento da imagem, revogação de Object URLs e estado de loading/erro de forma reativa, eliminando o cache global manual.
2. **`NineSliceCanvas` (Componente Base):** Apenas desenha o nine-slice e o texto. Suporta High-DPI.
3. **`NineSliceEditor` (Componente Interativo):** Gerencia o drag-and-drop das linhas com constraints matemáticas estritas (ex: `top` nunca pode ser maior que `bottom - minGap`).
4. **`BubblePreviewList`:** Gerencia a lista de previews (Curto, Médio, Longo) de forma otimizada.

### 2.2. Tipagem Estrita
Criar uma interface clara para a configuração do Bubble:
```typescript
interface BubbleAssetConfig {
  bubble_style: "nine_slice" | "animated";
  image_url: string;
  image_width: number;
  image_height: number;
  // Nine-slice
  slice_top?: number;
  slice_bottom?: number;
  slice_left?: number;
  slice_right?: number;
  // Tipografia
  text_color?: string;
  font_size?: number;
  text_align?: "left" | "center" | "right";
  // Padding
  pad_top?: number;
  pad_bottom?: number;
  pad_left?: number;
  pad_right?: number;
}
```

### 2.3. Otimização do Canvas (High-DPI)
O novo `NineSliceCanvas` deve multiplicar a largura/altura interna pelo `devicePixelRatio` e escalar via CSS, garantindo texto nítido:
```typescript
const dpr = window.devicePixelRatio || 1;
canvas.width = logicalWidth * dpr;
canvas.height = logicalHeight * dpr;
ctx.scale(dpr, dpr);
canvas.style.width = `${logicalWidth}px`;
canvas.style.height = `${logicalHeight}px`;
```

### 2.4. Constraints Matemáticas no Editor
Ao arrastar as linhas, aplicar limites estritos:
- `top` ≤ `imgH - bottom - minCenter`
- `bottom` ≤ `imgH - top - minCenter`
- `left` ≤ `imgW - right - minCenter`
- `right` ≤ `imgW - left - minCenter`

---

## 3. Plano de Ação para a Reescrever

1. **Remover o cache global (`_imgCache`)** e substituí-lo por um hook `useImageLoader` seguro contra memory leaks.
2. **Reescrever o `NineSliceBubble`** para suportar High-DPI e simplificar a matemática de layout.
3. **Reescrever o `NineSliceEditor`** para usar constraints matemáticas seguras no drag-and-drop.
4. **Refatorar o `BubblesDashboard`** para usar tipagem estrita no `asset_config` e limpar o código monolítico.
