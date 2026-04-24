/**
 * dynamicNineSlice.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Módulo core do modo "dynamic_nineslice".
 *
 * Filosofia: extensão sobre o nine-slice clássico, não substituição.
 *  - Se mode !== "dynamic_nineslice" → comportamento antigo inalterado.
 *  - Se mode === "dynamic_nineslice" → lógica de layout pré-calculado.
 *
 * Compatibilidade:
 *  - Todos os campos antigos (slice_top/bottom/left/right, pad_*, etc.) são
 *    mantidos e lidos normalmente.
 *  - Os novos campos (content.maxWidth, behavior.*) são opcionais com defaults.
 *
 * Regra de expansão:
 *  1. Crescimento prioritariamente horizontal (horizontalPriority = true).
 *  2. Crescimento vertical apenas quando o texto excede maxWidth.
 *  3. Centro absorve a deformação; bordas permanecem estáveis.
 *  4. Bordas usam tile (repetição) quando possível, não stretch linear.
 */

// ─── Tipos ────────────────────────────────────────────────────────────────────

/** Modo de renderização do balão. */
export type BubbleMode = "nine_slice" | "dynamic_nineslice" | "animated";

/** Configuração de slice (pontos de corte). */
export interface SliceConfig {
  left: number;
  right: number;
  top: number;
  bottom: number;
}

/** Configuração de conteúdo do modo dinâmico. */
export interface DynamicContentConfig {
  /** Padding interno horizontal (px). */
  paddingX: number;
  /** Padding interno vertical (px). */
  paddingY: number;
  /** Largura máxima do balão (px). */
  maxWidth: number;
  /** Largura mínima do balão (px). */
  minWidth: number;
}

/** Configuração de comportamento do modo dinâmico. */
export interface DynamicBehaviorConfig {
  /** Se true, expande horizontalmente antes de quebrar linha. */
  horizontalPriority: boolean;
  /** Proporção máxima da altura em relação à tela (0–1). */
  maxHeightRatio: number;
  /**
   * Fração da zona de transição (0–1).
   * Define a suavização entre a borda fixa e o centro elástico.
   * Usado no overlay visual do editor.
   */
  transitionZone: number;
}

/**
 * Configuração completa do asset_config para bubbles.
 * Compatível com o formato antigo (nine_slice) e o novo (dynamic_nineslice).
 */
export interface BubbleAssetConfig {
  // ── Campos de identidade (antigos + novos) ──────────────────────────────
  /** Modo de renderização. Ausente ou "nine_slice" = comportamento antigo. */
  mode?: BubbleMode;
  /** Alias legado. Lido se `mode` não estiver presente. */
  bubble_style?: "nine_slice" | "animated";

  // ── URLs e dimensões da imagem ──────────────────────────────────────────
  image_url: string | null;
  bubble_url?: string | null;
  image_width: number;
  image_height: number;
  is_animated?: boolean;
  rarity?: string;

  // ── Slice clássico (flat — compatibilidade total) ───────────────────────
  slice_top: number;
  slice_bottom: number;
  slice_left: number;
  slice_right: number;

  // ── Padding clássico (flat) ─────────────────────────────────────────────
  pad_top: number;
  pad_bottom: number;
  pad_left: number;
  pad_right: number;
  /** Compatibilidade com itens antigos que usavam padding simétrico. */
  content_padding_h?: number;
  content_padding_v?: number;

  // ── Tipografia ──────────────────────────────────────────────────────────
  text_color?: string;
  font_size?: number;
  text_align?: "left" | "center" | "right";

  // ── Polígono opcional ───────────────────────────────────────────────────
  poly_points?: Array<{ x: number; y: number }>;

  // ── NOVOS: campos do modo dynamic_nineslice ─────────────────────────────
  /**
   * Configuração de slice no formato objeto (novo).
   * Quando presente, tem prioridade sobre slice_top/bottom/left/right.
   */
  slice?: SliceConfig;

  /** Configuração de conteúdo dinâmico. */
  content?: {
    padding?: { x: number; y: number };
    maxWidth?: number;
    minWidth?: number;
  };

  /** Configuração de comportamento dinâmico. */
  behavior?: {
    horizontalPriority?: boolean;
    maxHeightRatio?: number;
    transitionZone?: number;
  };
}

// ─── Defaults ─────────────────────────────────────────────────────────────────

export const DYNAMIC_CONTENT_DEFAULTS: DynamicContentConfig = {
  paddingX: 16,
  paddingY: 12,
  maxWidth: 260,
  minWidth: 60,
};

export const DYNAMIC_BEHAVIOR_DEFAULTS: DynamicBehaviorConfig = {
  horizontalPriority: true,
  maxHeightRatio: 0.6,
  transitionZone: 0.15,
};

// ─── Helpers de leitura ───────────────────────────────────────────────────────

/** Retorna o modo efetivo do bubble (compatível com campo legado bubble_style). */
export function getBubbleMode(cfg: Partial<BubbleAssetConfig>): BubbleMode {
  if (cfg.mode === "dynamic_nineslice") return "dynamic_nineslice";
  if (cfg.mode === "animated" || cfg.bubble_style === "animated" || cfg.is_animated) return "animated";
  return "nine_slice";
}

/** Extrai o SliceConfig normalizado, preferindo o objeto `slice` se presente. */
export function getSliceConfig(cfg: Partial<BubbleAssetConfig>): SliceConfig {
  if (cfg.slice) {
    return {
      left:   cfg.slice.left   ?? 38,
      right:  cfg.slice.right  ?? 38,
      top:    cfg.slice.top    ?? 38,
      bottom: cfg.slice.bottom ?? 38,
    };
  }
  return {
    left:   cfg.slice_left   ?? 38,
    right:  cfg.slice_right  ?? 38,
    top:    cfg.slice_top    ?? 38,
    bottom: cfg.slice_bottom ?? 38,
  };
}

/** Extrai a configuração de conteúdo dinâmico com defaults. */
export function getDynamicContent(cfg: Partial<BubbleAssetConfig>): DynamicContentConfig {
  const c = cfg.content ?? {};
  const p = c.padding ?? {};
  return {
    paddingX:  p.x        ?? cfg.pad_left  ?? DYNAMIC_CONTENT_DEFAULTS.paddingX,
    paddingY:  p.y        ?? cfg.pad_top   ?? DYNAMIC_CONTENT_DEFAULTS.paddingY,
    maxWidth:  c.maxWidth ?? DYNAMIC_CONTENT_DEFAULTS.maxWidth,
    minWidth:  c.minWidth ?? DYNAMIC_CONTENT_DEFAULTS.minWidth,
  };
}

/** Extrai a configuração de comportamento dinâmico com defaults. */
export function getDynamicBehavior(cfg: Partial<BubbleAssetConfig>): DynamicBehaviorConfig {
  const b = cfg.behavior ?? {};
  return {
    horizontalPriority: b.horizontalPriority ?? DYNAMIC_BEHAVIOR_DEFAULTS.horizontalPriority,
    maxHeightRatio:     b.maxHeightRatio     ?? DYNAMIC_BEHAVIOR_DEFAULTS.maxHeightRatio,
    transitionZone:     b.transitionZone     ?? DYNAMIC_BEHAVIOR_DEFAULTS.transitionZone,
  };
}

// ─── Lógica de Layout Dinâmico ────────────────────────────────────────────────

export interface TextMeasurement {
  lines: string[];
  maxLineWidth: number;
  totalHeight: number;
}

export interface BubbleLayout {
  width: number;
  height: number;
  contentX: number;
  contentY: number;
  contentWidth: number;
  contentHeight: number;
  lineHeight: number;
  lines: string[];
}

/**
 * Mede o texto e calcula o layout do balão dinâmico.
 *
 * Algoritmo:
 *  1. Mede cada palavra com o contexto fornecido.
 *  2. Quebra linhas ao atingir maxContentWidth.
 *  3. Calcula largura: clamp(maxLineWidth + paddingH, minWidth, maxWidth).
 *  4. Calcula altura: linhas * lineHeight + paddingV.
 *  5. Garante que as bordas de slice nunca sejam comprimidas.
 *
 * @param text         Texto da mensagem.
 * @param measureFn    Função que retorna a largura de uma string em px.
 * @param slice        Configuração de slice.
 * @param content      Configuração de conteúdo dinâmico.
 * @param fontSize     Tamanho da fonte em px.
 */
export function calculateDynamicLayout(
  text: string,
  measureFn: (str: string) => number,
  slice: SliceConfig,
  content: DynamicContentConfig,
  fontSize: number,
): BubbleLayout {
  const lineHeight = Math.round(fontSize * 1.45);

  // Área interna disponível para o texto
  const paddingH = content.paddingX * 2;
  const paddingV = content.paddingY * 2;

  // Largura máxima do conteúdo de texto (sem padding)
  const maxContentWidth = Math.max(1, content.maxWidth - paddingH);

  // ── Quebra de linha ──────────────────────────────────────────────────────
  const words = text.split(" ");
  const lines: string[] = [];
  let currentLine = "";

  for (const word of words) {
    const testLine = currentLine ? `${currentLine} ${word}` : word;
    if (measureFn(testLine) > maxContentWidth && currentLine) {
      lines.push(currentLine);
      currentLine = word;
    } else {
      currentLine = testLine;
    }
  }
  if (currentLine) lines.push(currentLine);
  if (lines.length === 0) lines.push("");

  // ── Cálculo de dimensões ─────────────────────────────────────────────────
  const maxLineWidth = Math.max(...lines.map((l) => measureFn(l)));

  // Largura: clamp(textWidth + padding, minWidth, maxWidth)
  const rawWidth = maxLineWidth + paddingH;
  const width = Math.max(
    content.minWidth,
    Math.min(content.maxWidth, Math.ceil(rawWidth)),
    // Garante que as bordas de slice nunca sejam comprimidas
    slice.left + slice.right + 24,
  );

  // Altura: linhas * lineHeight + padding vertical
  const textHeight = lines.length * lineHeight;
  const height = Math.max(
    textHeight + paddingV,
    // Garante que as bordas de slice nunca sejam comprimidas
    slice.top + slice.bottom + 8,
  );

  // ── Posição do conteúdo ──────────────────────────────────────────────────
  const contentX = content.paddingX;
  const contentY = content.paddingY;
  const contentWidth = width - paddingH;
  const contentHeight = height - paddingV;

  return {
    width,
    height,
    contentX,
    contentY,
    contentWidth,
    contentHeight,
    lineHeight,
    lines,
  };
}

// ─── Serialização para asset_config ──────────────────────────────────────────

/**
 * Serializa os campos do modo dynamic_nineslice para o asset_config do banco.
 * Mantém todos os campos legados para compatibilidade com o Flutter atual.
 */
export function serializeDynamicConfig(
  base: Omit<BubbleAssetConfig, "mode" | "slice" | "content" | "behavior">,
  slice: SliceConfig,
  content: DynamicContentConfig,
  behavior: DynamicBehaviorConfig,
): BubbleAssetConfig {
  return {
    ...base,
    // Novo modo
    mode: "dynamic_nineslice",
    // Objeto slice (novo formato)
    slice,
    // Objeto content (novo formato)
    content: {
      padding: { x: content.paddingX, y: content.paddingY },
      maxWidth: content.maxWidth,
      minWidth: content.minWidth,
    },
    // Objeto behavior (novo formato)
    behavior: {
      horizontalPriority: behavior.horizontalPriority,
      maxHeightRatio: behavior.maxHeightRatio,
      transitionZone: behavior.transitionZone,
    },
    // ── Campos legados (compatibilidade Flutter/site antigo) ──────────────
    slice_top:    slice.top,
    slice_bottom: slice.bottom,
    slice_left:   slice.left,
    slice_right:  slice.right,
    pad_top:    content.paddingY,
    pad_bottom: content.paddingY,
    pad_left:   content.paddingX,
    pad_right:  content.paddingX,
    content_padding_h: content.paddingX,
    content_padding_v: content.paddingY,
  };
}

/**
 * Parseia um asset_config do banco para BubbleAssetConfig com defaults seguros.
 * Compatível com todos os formatos históricos.
 */
export function parseBubbleAssetConfig(raw: Record<string, unknown>): BubbleAssetConfig {
  const asNum = (v: unknown, fallback: number): number => {
    if (v == null) return fallback;
    if (typeof v === "number") return v;
    return parseFloat(String(v)) || fallback;
  };
  const asStr = (v: unknown): string => (v == null ? "" : String(v).trim());

  // Lê slice: prefere objeto `slice`, fallback para campos flat
  const sliceObj = raw.slice as Record<string, unknown> | undefined;
  const sliceTop    = asNum(sliceObj?.top    ?? raw.slice_top,    38);
  const sliceBottom = asNum(sliceObj?.bottom ?? raw.slice_bottom, 38);
  const sliceLeft   = asNum(sliceObj?.left   ?? raw.slice_left,   38);
  const sliceRight  = asNum(sliceObj?.right  ?? raw.slice_right,  38);

  // Lê content: prefere objeto `content`, fallback para campos flat
  const contentObj = raw.content as Record<string, unknown> | undefined;
  const paddingObj = contentObj?.padding as Record<string, unknown> | undefined;
  const fallbackH  = asNum(raw.content_padding_h ?? raw.pad_left,  20);
  const fallbackV  = asNum(raw.content_padding_v ?? raw.pad_top,   14);
  const padLeft    = asNum(paddingObj?.x ?? raw.pad_left,   fallbackH);
  const padRight   = asNum(paddingObj?.x ?? raw.pad_right,  fallbackH);
  const padTop     = asNum(paddingObj?.y ?? raw.pad_top,    fallbackV);
  const padBottom  = asNum(paddingObj?.y ?? raw.pad_bottom, fallbackV);

  // Lê behavior
  const behaviorObj = raw.behavior as Record<string, unknown> | undefined;

  // Determina o modo
  const modeRaw = asStr(raw.mode);
  let mode: BubbleMode = "nine_slice";
  if (modeRaw === "dynamic_nineslice") mode = "dynamic_nineslice";
  else if (modeRaw === "animated" || asStr(raw.bubble_style) === "animated" || raw.is_animated === true) mode = "animated";

  return {
    mode,
    bubble_style: (raw.bubble_style as BubbleAssetConfig["bubble_style"]) ?? "nine_slice",
    image_url:    asStr(raw.image_url) || asStr(raw.bubble_url) || null,
    bubble_url:   asStr(raw.bubble_url) || null,
    image_width:  asNum(raw.image_width,  128),
    image_height: asNum(raw.image_height, 128),
    is_animated:  raw.is_animated as boolean | undefined,
    rarity:       asStr(raw.rarity) || undefined,
    slice_top:    sliceTop,
    slice_bottom: sliceBottom,
    slice_left:   sliceLeft,
    slice_right:  sliceRight,
    pad_top:    padTop,
    pad_bottom: padBottom,
    pad_left:   padLeft,
    pad_right:  padRight,
    content_padding_h: asNum(raw.content_padding_h, fallbackH),
    content_padding_v: asNum(raw.content_padding_v, fallbackV),
    text_color: asStr(raw.text_color) || undefined,
    font_size:  asNum(raw.font_size, 13),
    text_align: (raw.text_align as BubbleAssetConfig["text_align"]) ?? "left",
    poly_points: raw.poly_points as BubbleAssetConfig["poly_points"],
    // Objetos novos (podem ser undefined para itens antigos)
    slice: sliceObj
      ? { left: sliceLeft, right: sliceRight, top: sliceTop, bottom: sliceBottom }
      : undefined,
    content: contentObj
      ? {
          padding: paddingObj
            ? { x: padLeft, y: padTop }
            : undefined,
          maxWidth:  asNum(contentObj.maxWidth,  DYNAMIC_CONTENT_DEFAULTS.maxWidth),
          minWidth:  asNum(contentObj.minWidth,  DYNAMIC_CONTENT_DEFAULTS.minWidth),
        }
      : undefined,
    behavior: behaviorObj
      ? {
          horizontalPriority: behaviorObj.horizontalPriority as boolean | undefined,
          maxHeightRatio:     asNum(behaviorObj.maxHeightRatio, DYNAMIC_BEHAVIOR_DEFAULTS.maxHeightRatio),
          transitionZone:     asNum(behaviorObj.transitionZone, DYNAMIC_BEHAVIOR_DEFAULTS.transitionZone),
        }
      : undefined,
  };
}

// ─── Zonas do overlay visual ──────────────────────────────────────────────────

export interface NineSliceZones {
  /** Zona de borda fixa (corners + edges). */
  corners: {
    topLeft:     { x: number; y: number; w: number; h: number };
    topRight:    { x: number; y: number; w: number; h: number };
    bottomLeft:  { x: number; y: number; w: number; h: number };
    bottomRight: { x: number; y: number; w: number; h: number };
  };
  edges: {
    top:    { x: number; y: number; w: number; h: number };
    bottom: { x: number; y: number; w: number; h: number };
    left:   { x: number; y: number; w: number; h: number };
    right:  { x: number; y: number; w: number; h: number };
  };
  /** Zona central (stretch principal). */
  center: { x: number; y: number; w: number; h: number };
  /** Zonas de transição (suavização entre borda e centro). */
  transitions: {
    topTransition:    { x: number; y: number; w: number; h: number };
    bottomTransition: { x: number; y: number; w: number; h: number };
    leftTransition:   { x: number; y: number; w: number; h: number };
    rightTransition:  { x: number; y: number; w: number; h: number };
  };
}

/**
 * Calcula as zonas do overlay visual para o editor.
 * As zonas de transição são calculadas a partir de `transitionZone` (fração).
 */
export function calculateNineSliceZones(
  imgW: number,
  imgH: number,
  slice: SliceConfig,
  transitionZone: number,
): NineSliceZones {
  const { top: st, bottom: sb, left: sl, right: sr } = slice;
  const centerW = imgW - sl - sr;
  const centerH = imgH - st - sb;

  // Tamanho da zona de transição em px (fração do centro)
  const tzW = Math.round(centerW * transitionZone);
  const tzH = Math.round(centerH * transitionZone);

  return {
    corners: {
      topLeft:     { x: 0,       y: 0,       w: sl, h: st },
      topRight:    { x: imgW-sr, y: 0,       w: sr, h: st },
      bottomLeft:  { x: 0,       y: imgH-sb, w: sl, h: sb },
      bottomRight: { x: imgW-sr, y: imgH-sb, w: sr, h: sb },
    },
    edges: {
      top:    { x: sl,       y: 0,       w: centerW, h: st },
      bottom: { x: sl,       y: imgH-sb, w: centerW, h: sb },
      left:   { x: 0,        y: st,      w: sl,      h: centerH },
      right:  { x: imgW-sr,  y: st,      w: sr,      h: centerH },
    },
    center: {
      x: sl + tzW,
      y: st + tzH,
      w: Math.max(0, centerW - tzW * 2),
      h: Math.max(0, centerH - tzH * 2),
    },
    transitions: {
      topTransition:    { x: sl,       y: st,       w: centerW, h: tzH },
      bottomTransition: { x: sl,       y: imgH-sb-tzH, w: centerW, h: tzH },
      leftTransition:   { x: sl,       y: st+tzH,   w: tzW, h: Math.max(0, centerH - tzH * 2) },
      rightTransition:  { x: imgW-sr-tzW, y: st+tzH, w: tzW, h: Math.max(0, centerH - tzH * 2) },
    },
  };
}
