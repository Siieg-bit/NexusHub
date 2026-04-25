import { useState, useEffect, useRef, useCallback, useMemo } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { supabase, StoreItem } from "@/lib/supabase";
import { toast } from "sonner";
import { Upload, Trash2, AlertCircle, CheckCircle2, Loader2, RefreshCw, Pencil, Move } from "lucide-react";
import AdminLayout, { AdminSection } from "@/components/AdminLayout";
import {
  getBubbleMode,
  getSliceConfig,
  getDynamicContent,
  getDynamicBehavior,
  serializeDynamicConfig,
  calculateNineSliceZones,
  DYNAMIC_CONTENT_DEFAULTS,
  DYNAMIC_BEHAVIOR_DEFAULTS,
  type BubbleMode,
  type DynamicContentConfig,
  type DynamicBehaviorConfig,
} from "@/lib/dynamicNineSlice";
import OverviewPage from "./OverviewPage";
import StoreItemsPage from "./StoreItemsPage";
import FramesDashboard from "./FramesDashboard";
import ThemesDashboard from "./ThemesDashboard";
import StickersPage from "./StickersPage";
import UsersPage from "./UsersPage";
import TransactionsPage from "./TransactionsPage";
import SettingsPage from "./SettingsPage";
import ModerationPage from "./ModerationPage";
import CommunitiesPage from "./CommunitiesPage";
import AchievementsPage from "./AchievementsPage";
import { HorizontalStretchEditor } from "@/components/HorizontalStretchEditor";
import BroadcastPage from "./BroadcastPage";

// ─── Tipos e Constantes ───────────────────────────────────────────────────────

type Rarity = "common" | "rare" | "epic" | "legendary";
type TextAlign = "left" | "center" | "right";

/** Ponto normalizado (0–1) para o polígono de fill */
interface PolyPoint { x: number; y: number; }

/** Configuração tipada do asset_config para bubbles */
interface BubbleAssetConfig {
  mode?: BubbleMode;
  bubble_style: "nine_slice" | "animated";
  image_url: string | null;
  bubble_url: string | null;
  image_width: number;
  image_height: number;
  is_animated: boolean;
  rarity: Rarity;
  // Nine-slice
  slice_top: number;
  slice_bottom: number;
  slice_left: number;
  slice_right: number;
  // Tipografia
  text_color?: string;
  font_size: number;
  text_align: TextAlign;
  // Padding interno (independente das bordas de slice)
  pad_top: number;
  pad_bottom: number;
  pad_left: number;
  pad_right: number;
  content_padding_h?: number;
  content_padding_v?: number;
  /** Polígono opcional de fill (8 pontos normalizados 0–1). Quando presente, o Flutter aplica ClipPath. */
  poly_points?: PolyPoint[];
  // ── NOVOS: campos do modo dynamic_nineslice ──────────────────────────────────────
  slice?: { left: number; right: number; top: number; bottom: number };
  content?: { padding?: { x: number; y: number }; maxWidth?: number; minWidth?: number };
  behavior?: { horizontalPriority?: boolean; maxHeightRatio?: number; transitionZone?: number };
  // ── Campos do modo horizontal_stretch ──────────────────────────────────────
  horizontal_stretch?: { maxWidth?: number; minWidth?: number; paddingX?: number; paddingY?: number };
}

/** Valores padrão para um novo bubble */
const DEFAULT_ASSET_CONFIG: Omit<BubbleAssetConfig, "image_url" | "bubble_url" | "image_width" | "image_height"> = {
  bubble_style: "nine_slice",
  is_animated: false,
  rarity: "common",
  slice_top: 38, slice_bottom: 38, slice_left: 38, slice_right: 38,
  font_size: 13, text_align: "left",
  pad_top: 8, pad_bottom: 8, pad_left: 8, pad_right: 8,
};

/** Formulário do modal de criação/edição */
interface BubbleForm {
  name: string;
  description: string;
  priceCoins: number;
  rarity: Rarity;
  isActive: boolean;
  isAnimated: boolean;
  textColor: string;
  sliceTop: number; sliceBottom: number; sliceLeft: number; sliceRight: number;
  fontSize: number;
  textAlign: TextAlign;
  padTop: number; padBottom: number; padLeft: number; padRight: number;
  usePolyFill: boolean;
  polyPoints: PolyPoint[];
  // ── Modo dinâmico (dynamic_nineslice) ───────────────────────────────────────────────────────
  isDynamic: boolean;
  dynMaxWidth: number;
  dynMinWidth: number;
  dynPaddingX: number;
  dynPaddingY: number;
  dynHorizontalPriority: boolean;
  dynTransitionZone: number;
  // ── Modo horizontal_stretch ───────────────────────────────────────────────────────────
  isHorizontalStretch: boolean;
  hsMaxWidth: number;
  hsMinWidth: number;
  hsPaddingX: number;
  hsPaddingY: number;
}

const EMPTY_FORM: BubbleForm = {
  name: "", description: "", priceCoins: 150, rarity: "common",
  isActive: true, isAnimated: false, textColor: "",
  sliceTop: 38, sliceBottom: 38, sliceLeft: 38, sliceRight: 38,
  fontSize: 13, textAlign: "left",
  padTop: 8, padBottom: 8, padLeft: 8, padRight: 8,
  usePolyFill: false,
  polyPoints: [],
  isDynamic: false,
  dynMaxWidth: 260,
  dynMinWidth: 60,
  dynPaddingX: 16,
  dynPaddingY: 12,
  dynHorizontalPriority: true,
  dynTransitionZone: 0.15,
  isHorizontalStretch: false,
  hsMaxWidth: 280,
  hsMinWidth: 60,
  hsPaddingX: 4,
  hsPaddingY: 4,
};

type SliceValues = { top: number; bottom: number; left: number; right: number };

const RARITY_COLORS: Record<Rarity, { color: string; rgb: string }> = {
  common:    { color: "#94A3B8", rgb: "148,163,184" },
  rare:      { color: "#60A5FA", rgb: "96,165,250" },
  epic:      { color: "#A78BFA", rgb: "167,139,250" },
  legendary: { color: "#FBBF24", rgb: "251,191,36" },
};

const RARITY_LABELS: Record<Rarity, string> = {
  common: "Comum", rare: "Raro", epic: "Épico", legendary: "Lendário",
};

const fadeUp = {
  hidden: { opacity: 0, y: 10 },
  show: (i: number) => ({ opacity: 1, y: 0, transition: { delay: i * 0.04, duration: 0.25, ease: "easeOut" as const } }),
};

// ─── Helpers ──────────────────────────────────────────────────────────────────

function detectBubbleIsAnimated(file: File): boolean {
  const ext = file.name.split(".").pop()?.toLowerCase() ?? "";
  return file.type === "image/gif" || ext === "gif" || ext === "apng";
}

/** Parseia o asset_config do banco com defaults seguros */
function parseBubbleConfig(raw: Record<string, unknown>): BubbleAssetConfig {
  return {
    bubble_style: (raw.bubble_style as BubbleAssetConfig["bubble_style"]) ?? "nine_slice",
    image_url: (raw.image_url as string) ?? null,
    bubble_url: (raw.bubble_url as string) ?? null,
    image_width: (raw.image_width as number) ?? 128,
    image_height: (raw.image_height as number) ?? 128,
    is_animated: (raw.is_animated as boolean) ?? false,
    rarity: (raw.rarity as Rarity) ?? "common",
    slice_top: (raw.slice_top as number) ?? 38,
    slice_bottom: (raw.slice_bottom as number) ?? 38,
    slice_left: (raw.slice_left as number) ?? 38,
    slice_right: (raw.slice_right as number) ?? 38,
    text_color: (raw.text_color as string) ?? undefined,
    font_size: (raw.font_size as number) ?? 13,
    text_align: (raw.text_align as TextAlign) ?? "left",
    pad_top: (raw.pad_top as number) ?? 8,
    pad_bottom: (raw.pad_bottom as number) ?? 8,
    pad_left: (raw.pad_left as number) ?? 8,
    pad_right: (raw.pad_right as number) ?? 8,
    poly_points: Array.isArray(raw.poly_points) ? (raw.poly_points as PolyPoint[]) : undefined,
    mode: (raw.mode as BubbleMode) ?? undefined,
    slice: raw.slice as BubbleAssetConfig["slice"],
    content: raw.content as BubbleAssetConfig["content"],
    behavior: raw.behavior as BubbleAssetConfig["behavior"],
  };
}

// ─── Hook: useImageLoader ─────────────────────────────────────────────────────
// Carrega uma imagem de forma segura e reativa.
// - Object URLs (blob:): carregados diretamente sem crossOrigin
// - URLs remotas: usa crossOrigin="anonymous" para permitir drawImage no canvas
//   sem "tainted canvas" (Supabase Storage serve com Access-Control-Allow-Origin: *)
type ImageState =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "ready"; img: HTMLImageElement }
  | { status: "error"; message: string };
// Cache de sessão: evita múltiplos carregamentos da mesma URL
const _sessionCache = new Map<string, HTMLImageElement>();
function useImageLoader(url: string | null): ImageState {
  const [state, setState] = useState<ImageState>(() => {
    if (!url) return { status: "idle" };
    const cached = _sessionCache.get(url);
    if (cached) return { status: "ready", img: cached };
    return { status: "loading" };
  });
  useEffect(() => {
    if (!url) { setState({ status: "idle" }); return; }
    // Já no cache — aplica imediatamente
    const cached = _sessionCache.get(url);
    if (cached) { setState({ status: "ready", img: cached }); return; }
    setState({ status: "loading" });
    let cancelled = false;
    const img = new window.Image();
    // crossOrigin DEVE ser definido antes de img.src para ter efeito
    if (!url.startsWith("blob:") && !url.startsWith("data:")) {
      img.crossOrigin = "anonymous";
    }
    img.onload = () => {
      if (cancelled) return;
      _sessionCache.set(url, img);
      setState({ status: "ready", img });
    };
    img.onerror = () => {
      if (cancelled) return;
      setState({ status: "error", message: "Falha ao carregar imagem" });
    };
    img.src = url;
    return () => { cancelled = true; };
  }, [url]);
  return state;
}

// ─── Chat Preview (cards da lista — usa CSS border-image) ─────────────────────
function ChatPreview({ imageUrl, name, cfg }: { imageUrl: string | null; name: string; cfg?: { slice_top: number; slice_bottom: number; slice_left: number; slice_right: number; font_size: number; text_color?: string; pad_top: number; pad_bottom: number; pad_left: number; pad_right: number } }) {
  const messages = [
    { id: 1, mine: false, text: "Que bubble incrível 👀" },
    { id: 2, mine: true,  text: name || "Novo bubble" },
    { id: 3, mine: false, text: "Adorei! Quanto custa?" },
    { id: 4, mine: true,  text: "Tá na loja! 🎉" },
  ];
  return (
    <div className="flex flex-col gap-2 p-4">
      {messages.map((msg) => (
        <div key={msg.id} className={`flex ${msg.mine ? "justify-end" : "justify-start"}`}>
          {imageUrl ? (
            <div
              className="relative max-w-[180px]"
              style={{
                backgroundImage: `url(${imageUrl})`,
                backgroundRepeat: "no-repeat",
                backgroundSize: "100% 100%",
                borderImageSource: `url(${imageUrl})`,
                borderImageSlice: `${cfg?.slice_top ?? 38} ${cfg?.slice_right ?? 38} ${cfg?.slice_bottom ?? 38} ${cfg?.slice_left ?? 38} fill`,
                borderImageWidth: `${cfg?.slice_top ?? 38}px ${cfg?.slice_right ?? 38}px ${cfg?.slice_bottom ?? 38}px ${cfg?.slice_left ?? 38}px`,
                borderImageRepeat: "stretch",
                minHeight: "40px",
                paddingTop: `${(cfg?.slice_top ?? 38) + (cfg?.pad_top ?? 8)}px`,
                paddingBottom: `${(cfg?.slice_bottom ?? 38) + (cfg?.pad_bottom ?? 8)}px`,
                paddingLeft: `${(cfg?.slice_left ?? 38) + (cfg?.pad_left ?? 8)}px`,
                paddingRight: `${(cfg?.slice_right ?? 38) + (cfg?.pad_right ?? 8)}px`,
                fontSize: `${cfg?.font_size ?? 13}px`,
                color: cfg?.text_color?.trim() || "rgba(255,255,255,0.9)",
                fontFamily: "'Space Grotesk', sans-serif",
                lineHeight: "1.45",
              }}
            >
              {msg.text}
            </div>
          ) : (
            <div
              className="max-w-[180px] px-3.5 py-2 rounded-2xl text-[13px]"
              style={{
                background: msg.mine ? "rgba(124,58,237,0.4)" : "rgba(255,255,255,0.07)",
                color: "rgba(255,255,255,0.85)",
                fontFamily: "'Space Grotesk', sans-serif",
              }}
            >
              {msg.text}
            </div>
          )}
        </div>
      ))}
    </div>
  );
}


// ─── DynamicNineSliceOverlay ──────────────────────────────────────────────────
// Overlay visual INTERATIVO com 3 zonas: bordas (fixas), transição (suavização), centro (stretch).
// Handles arrastáveis para ajustar os 4 slices e a zona de transição diretamente no overlay.
type OverlayHandle = "top" | "bottom" | "left" | "right" | "transition"
  | "stretch-top" | "stretch-bottom" | "stretch-left" | "stretch-right" | null;
interface DynamicNineSliceOverlayProps {
  imageUrl: string;
  imageDimensions: { w: number; h: number } | null;
  slice: SliceValues;
  transitionZone: number;
  onSliceChange?: (s: SliceValues) => void;
  onTransitionChange?: (t: number) => void;
}
function DynamicNineSliceOverlay({
  imageUrl, imageDimensions, slice, transitionZone,
  onSliceChange, onTransitionChange,
}: DynamicNineSliceOverlayProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [canvasSize, setCanvasSize] = useState({ w: 240, h: 240 });
  const [dragging, setDragging] = useState<OverlayHandle>(null);
  const [hovering, setHovering] = useState<OverlayHandle>(null);
  const dragStart = useRef<{ x: number; y: number; value: number } | null>(null);
  const imgW = imageDimensions?.w ?? 128;
  const imgH = imageDimensions?.h ?? 128;
  useEffect(() => {
    function update() {
      if (!containerRef.current) return;
      const rect = containerRef.current.getBoundingClientRect();
      setCanvasSize({ w: rect.width, h: rect.height });
    }
    update();
    const ro = new ResizeObserver(update);
    if (containerRef.current) ro.observe(containerRef.current);
    return () => ro.disconnect();
  }, []);
  const scaleX = canvasSize.w / imgW;
  const scaleY = canvasSize.h / imgH;
  const topPx    = slice.top    * scaleY;
  const bottomPx = canvasSize.h - slice.bottom * scaleY;
  const leftPx   = slice.left   * scaleX;
  const rightPx  = canvasSize.w - slice.right  * scaleX;
  const centerW  = rightPx - leftPx;
  const centerH  = bottomPx - topPx;
  const tzW = centerW * transitionZone;
  const tzH = centerH * transitionZone;
  const HIT = 10;
  // Handle de transição: canto inferior direito da zona de transição
  const tzHandleX = rightPx - tzW;
  const tzHandleY = bottomPx - tzH;

  // Posição das arestas do retângulo STRETCH (interior do nine-slice)
  const stretchTop    = topPx + tzH;
  const stretchBottom = bottomPx - tzH;
  const stretchLeft   = leftPx + tzW;
  const stretchRight  = rightPx - tzW;
  const getHandleAt = useCallback((x: number, y: number): OverlayHandle => {
    // Handle TZ tem prioridade máxima
    if (Math.abs(x - tzHandleX) < HIT + 4 && Math.abs(y - tzHandleY) < HIT + 4) return "transition";
    // Linhas externas de slice
    if (Math.abs(y - topPx)    < HIT) return "top";
    if (Math.abs(y - bottomPx) < HIT) return "bottom";
    if (Math.abs(x - leftPx)   < HIT) return "left";
    if (Math.abs(x - rightPx)  < HIT) return "right";
    // Arestas do retângulo STRETCH (só dentro da zona de transição)
    const inStretchX = x >= stretchLeft - HIT && x <= stretchRight + HIT;
    const inStretchY = y >= stretchTop  - HIT && y <= stretchBottom + HIT;
    if (Math.abs(y - stretchTop)    < HIT && inStretchX) return "stretch-top";
    if (Math.abs(y - stretchBottom) < HIT && inStretchX) return "stretch-bottom";
    if (Math.abs(x - stretchLeft)   < HIT && inStretchY) return "stretch-left";
    if (Math.abs(x - stretchRight)  < HIT && inStretchY) return "stretch-right";
    return null;
  }, [topPx, bottomPx, leftPx, rightPx, tzHandleX, tzHandleY, stretchTop, stretchBottom, stretchLeft, stretchRight]);

  const getCursor = (h: OverlayHandle) => {
    if (h === "top" || h === "bottom" || h === "stretch-top" || h === "stretch-bottom") return "ns-resize";
    if (h === "left" || h === "right" || h === "stretch-left" || h === "stretch-right") return "ew-resize";
    if (h === "transition") return "nwse-resize";
    return "default";
  };
  const cursor = getCursor(dragging ?? hovering);

  const onMouseDown = useCallback((e: React.MouseEvent) => {
    const rect = containerRef.current!.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    const handle = getHandleAt(x, y);
    if (!handle) return;
    e.preventDefault();
    setDragging(handle);
    // Mapeia handle do stretch para o slice correspondente
    const stretchToSlice: Partial<Record<NonNullable<OverlayHandle>, keyof SliceValues>> = {
      "stretch-top": "top", "stretch-bottom": "bottom",
      "stretch-left": "left", "stretch-right": "right",
    };
    const sliceKey = stretchToSlice[handle];
    dragStart.current = {
      x, y,
      value: handle === "transition"
        ? transitionZone
        : sliceKey
          ? slice[sliceKey]
          : slice[handle as keyof SliceValues],
    };
  }, [getHandleAt, slice, transitionZone]);

  const onMouseMove = useCallback((e: React.MouseEvent) => {
    const rect = containerRef.current!.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    if (!dragging || !dragStart.current) {
      setHovering(getHandleAt(x, y));
      return;
    }
    e.preventDefault(); // bloqueia scroll/seleção de texto durante drag
    const dx = x - dragStart.current.x;
    const dy = y - dragStart.current.y;
    if (dragging === "transition") {
      // Arrastar para cima/esquerda = menos transição; baixo/direita = mais
      const delta = (dx - dy) / (canvasSize.w * 0.5);
      const newTz = Math.max(0, Math.min(0.5, dragStart.current.value - delta));
      onTransitionChange?.(Math.round(newTz * 100) / 100);
    } else if (dragging === "stretch-top" || dragging === "stretch-bottom" ||
               dragging === "stretch-left" || dragging === "stretch-right") {
      // Handles do STRETCH: arrastar a aresta para dentro aumenta o slice correspondente
      // stretch-top para baixo  = aumenta slice.top  (borda maior, stretch menor)
      // stretch-top para cima   = diminui slice.top  (borda menor, stretch maior)
      // stretch-bottom para cima = aumenta slice.bottom
      // stretch-left para direita = aumenta slice.left
      // stretch-right para esquerda = aumenta slice.right
      const sliceMap: Record<string, keyof SliceValues> = {
        "stretch-top": "top", "stretch-bottom": "bottom",
        "stretch-left": "left", "stretch-right": "right",
      };
      const sliceKey = sliceMap[dragging];
      const isVertical = dragging === "stretch-top" || dragging === "stretch-bottom";
      const delta = isVertical ? dy : dx;
      const scale = isVertical ? scaleY : scaleX;
      // stretch-top: arrastar para baixo (+dy) aumenta slice.top (+)
      // stretch-bottom: arrastar para cima (-dy) aumenta slice.bottom (+)
      // stretch-left: arrastar para direita (+dx) aumenta slice.left (+)
      // stretch-right: arrastar para esquerda (-dx) aumenta slice.right (+)
      const sign = (dragging === "stretch-bottom" || dragging === "stretch-right") ? -1 : 1;
      const newVal = Math.max(0, Math.round(dragStart.current.value + sign * delta / scale));
      onSliceChange?.({ ...slice, [sliceKey]: newVal });
    } else {
      const isVertical = dragging === "top" || dragging === "bottom";
      const delta = isVertical ? dy : dx;
      const scale = isVertical ? scaleY : scaleX;
      const sign  = (dragging === "bottom" || dragging === "right") ? -1 : 1;
      const newVal = Math.max(0, Math.round(dragStart.current.value + sign * delta / scale));
      onSliceChange?.({ ...slice, [dragging]: newVal });
    }
  }, [dragging, getHandleAt, slice, scaleX, scaleY, canvasSize, onSliceChange, onTransitionChange]);

  const onMouseUp = useCallback(() => {
    setDragging(null);
    dragStart.current = null;
  }, []);

  const lineBase = (active: boolean, color: string): React.CSSProperties => ({
    position: "absolute",
    background: active ? color : color + "99",
    boxShadow: active ? `0 0 6px ${color}` : "none",
    transition: active ? "none" : "background 0.15s",
    pointerEvents: "none",
  });

  return (
    <div className="space-y-3">
      {/* Legenda */}
      <div className="flex items-center gap-3 flex-wrap">
        <div className="flex items-center gap-1.5">
          <div className="w-3 h-3 rounded-sm" style={{ background: "rgba(245,158,11,0.4)", border: "1px solid #F59E0B" }} />
          <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.35)" }}>Bordas fixas</span>
        </div>
        <div className="flex items-center gap-1.5">
          <div className="w-3 h-3 rounded-sm" style={{ background: "rgba(167,139,250,0.3)", border: "1px solid #A78BFA" }} />
          <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.35)" }}>Transição</span>
        </div>
        <div className="flex items-center gap-1.5">
          <div className="w-3 h-3 rounded-sm" style={{ background: "rgba(52,211,153,0.3)", border: "1px solid #34D399" }} />
          <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.35)" }}>Centro (stretch)</span>
        </div>
        <span className="text-[9px] font-mono ml-auto" style={{ color: "rgba(255,255,255,0.2)" }}>Arraste as linhas</span>
      </div>

      {/* Container interativo */}
      <div
        ref={containerRef}
        className="relative rounded-xl overflow-hidden select-none"
        style={{
          width: "100%",
          paddingBottom: `${(imgH / imgW) * 100}%`,
          background: "repeating-conic-gradient(rgba(255,255,255,0.04) 0% 25%, transparent 0% 50%) 0 0 / 12px 12px",
          border: `1px solid ${dragging ? "rgba(255,255,255,0.2)" : "rgba(255,255,255,0.08)"}`,
          cursor,
          userSelect: "none",
          touchAction: "none",       // bloqueia scroll touch durante drag
          overflowAnchor: "none",    // impede que o browser reposicione a página
        }}
        onMouseDown={onMouseDown}
        onMouseMove={onMouseMove}
        onMouseUp={onMouseUp}
        onMouseLeave={onMouseUp}
      >
        {/* Imagem de fundo */}
        <img
          src={imageUrl}
          alt="bubble"
          draggable={false}
          style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "fill", pointerEvents: "none" }}
        />

        {/* SVG — zonas coloridas */}
        <svg
          style={{ position: "absolute", inset: 0, width: "100%", height: "100%", pointerEvents: "none" }}
          viewBox={`0 0 ${canvasSize.w} ${canvasSize.h}`}
          preserveAspectRatio="none"
        >
          {/* Bordas fixas — âmbar */}
          <rect x={0} y={0} width={canvasSize.w} height={topPx} fill="rgba(245,158,11,0.18)" />
          <rect x={0} y={bottomPx} width={canvasSize.w} height={canvasSize.h - bottomPx} fill="rgba(245,158,11,0.18)" />
          <rect x={0} y={topPx} width={leftPx} height={centerH} fill="rgba(245,158,11,0.18)" />
          <rect x={rightPx} y={topPx} width={canvasSize.w - rightPx} height={centerH} fill="rgba(245,158,11,0.18)" />
          {/* Transição — violeta */}
          <rect x={leftPx} y={topPx} width={centerW} height={tzH} fill="rgba(167,139,250,0.2)" />
          <rect x={leftPx} y={bottomPx - tzH} width={centerW} height={tzH} fill="rgba(167,139,250,0.2)" />
          <rect x={leftPx} y={topPx + tzH} width={tzW} height={Math.max(0, centerH - tzH * 2)} fill="rgba(167,139,250,0.2)" />
          <rect x={rightPx - tzW} y={topPx + tzH} width={tzW} height={Math.max(0, centerH - tzH * 2)} fill="rgba(167,139,250,0.2)" />
          {/* Centro stretch + handles das arestas — tudo dentro do SVG para alinhamento perfeito */}
          {(() => {
            const stretchActive = dragging?.startsWith("stretch") || hovering?.startsWith("stretch");
            const sw = Math.max(0, centerW - tzW * 2);
            const sh = Math.max(0, centerH - tzH * 2);
            const sx = leftPx + tzW;
            const sy = topPx + tzH;
            // Comprimento dos handles: 60% da aresta, centrado
            const hLenH = sw * 0.6;  // comprimento horizontal (topo/base)
            const hLenV = sh * 0.6;  // comprimento vertical (esq/dir)
            const hThick = 2.5;      // espessura visual
            const isActive = (id: string) => dragging === id || hovering === id;
            const hColor = (id: string) => isActive(id) ? "#34D399" : "rgba(52,211,153,0.7)";
            return (
              <>
                {/* Retângulo STRETCH */}
                <rect
                  x={sx} y={sy} width={sw} height={sh}
                  fill={stretchActive ? "rgba(52,211,153,0.22)" : "rgba(52,211,153,0.12)"}
                  stroke={stretchActive ? "#34D399" : "#34D39944"}
                  strokeWidth={stretchActive ? 1.5 : 0.75}
                />
                {sw > 40 && sh > 20 && (
                  <text
                    x={sx + sw / 2} y={sy + sh / 2}
                    textAnchor="middle" dominantBaseline="middle"
                    fontSize="8" fontFamily="'DM Mono', monospace"
                    fill="#34D399" opacity="0.7"
                  >STRETCH</text>
                )}
                {/* Handle aresta TOPO — linha horizontal centrada na borda superior do STRETCH */}
                <rect
                  x={sx + (sw - hLenH) / 2} y={sy - hThick / 2}
                  width={hLenH} height={hThick}
                  fill={hColor("stretch-top")} rx={1}
                  style={{ filter: isActive("stretch-top") ? "drop-shadow(0 0 4px #34D399)" : "none" }}
                />
                {/* Handle aresta BASE */}
                <rect
                  x={sx + (sw - hLenH) / 2} y={sy + sh - hThick / 2}
                  width={hLenH} height={hThick}
                  fill={hColor("stretch-bottom")} rx={1}
                  style={{ filter: isActive("stretch-bottom") ? "drop-shadow(0 0 4px #34D399)" : "none" }}
                />
                {/* Handle aresta ESQUERDA */}
                <rect
                  x={sx - hThick / 2} y={sy + (sh - hLenV) / 2}
                  width={hThick} height={hLenV}
                  fill={hColor("stretch-left")} rx={1}
                  style={{ filter: isActive("stretch-left") ? "drop-shadow(0 0 4px #34D399)" : "none" }}
                />
                {/* Handle aresta DIREITA */}
                <rect
                  x={sx + sw - hThick / 2} y={sy + (sh - hLenV) / 2}
                  width={hThick} height={hLenV}
                  fill={hColor("stretch-right")} rx={1}
                  style={{ filter: isActive("stretch-right") ? "drop-shadow(0 0 4px #34D399)" : "none" }}
                />
              </>
            );
          })()}
        </svg>

        {/* Linha Topo */}
        <div style={{ ...lineBase(dragging === "top" || hovering === "top", "#F59E0B"), left: 0, right: 0, top: topPx - 1, height: 2 }}>
          <div style={{ position: "absolute", right: 4, top: -11, fontSize: 9, fontFamily: "'DM Mono', monospace", color: "#F59E0B", background: "rgba(0,0,0,0.75)", padding: "1px 4px", borderRadius: 4, whiteSpace: "nowrap" }}>
            T: {slice.top}px
          </div>
        </div>
        {/* Linha Base */}
        <div style={{ ...lineBase(dragging === "bottom" || hovering === "bottom", "#F59E0B"), left: 0, right: 0, top: bottomPx - 1, height: 2 }}>
          <div style={{ position: "absolute", right: 4, bottom: -11, fontSize: 9, fontFamily: "'DM Mono', monospace", color: "#F59E0B", background: "rgba(0,0,0,0.75)", padding: "1px 4px", borderRadius: 4, whiteSpace: "nowrap" }}>
            B: {slice.bottom}px
          </div>
        </div>
        {/* Linha Esquerda */}
        <div style={{ ...lineBase(dragging === "left" || hovering === "left", "#34D399"), top: 0, bottom: 0, left: leftPx - 1, width: 2 }}>
          <div style={{ position: "absolute", left: 4, top: 4, fontSize: 9, fontFamily: "'DM Mono', monospace", color: "#34D399", background: "rgba(0,0,0,0.75)", padding: "1px 4px", borderRadius: 4, whiteSpace: "nowrap", writingMode: "vertical-rl", transform: "rotate(180deg)" }}>
            L: {slice.left}px
          </div>
        </div>
        {/* Linha Direita */}
        <div style={{ ...lineBase(dragging === "right" || hovering === "right", "#34D399"), top: 0, bottom: 0, left: rightPx - 1, width: 2 }}>
          <div style={{ position: "absolute", right: 4, top: 4, fontSize: 9, fontFamily: "'DM Mono', monospace", color: "#34D399", background: "rgba(0,0,0,0.75)", padding: "1px 4px", borderRadius: 4, whiteSpace: "nowrap", writingMode: "vertical-rl" }}>
            R: {slice.right}px
          </div>
        </div>

        {/* Handle de transição — quadrado TZ arrastável */}
        {centerW > 20 && centerH > 20 && (
          <div
            style={{
              position: "absolute",
              left: tzHandleX - 7,
              top: tzHandleY - 7,
              width: 14,
              height: 14,
              borderRadius: 3,
              background: dragging === "transition" || hovering === "transition" ? "#A78BFA" : "rgba(167,139,250,0.7)",
              border: "1.5px solid #A78BFA",
              boxShadow: dragging === "transition" ? "0 0 8px #A78BFA" : "none",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              pointerEvents: "none",
              transition: "background 0.15s",
            }}
          >
            <span style={{ fontSize: 6, color: "white", fontFamily: "monospace", lineHeight: 1 }}>TZ</span>
          </div>
        )}
      </div>

      {/* Inputs numéricos */}
      <div className="grid grid-cols-5 gap-1.5">
        {([
          { label: "Topo",  key: "top"    as const, color: "#F59E0B" },
          { label: "Base",  key: "bottom" as const, color: "#F59E0B" },
          { label: "Esq.",  key: "left"   as const, color: "#34D399" },
          { label: "Dir.",  key: "right"  as const, color: "#34D399" },
        ]).map(({ label, key, color }) => (
          <div key={key}>
            <label className="text-[9px] font-mono block mb-1" style={{ color: "rgba(255,255,255,0.3)" }}>{label}</label>
            <input
              type="number" min={0}
              value={slice[key]}
              onChange={(e) => onSliceChange?.({ ...slice, [key]: Math.max(0, parseInt(e.target.value) || 0) })}
              className="w-full px-1.5 py-1 rounded-lg text-[11px] outline-none font-mono text-center"
              style={{ background: "rgba(255,255,255,0.04)", border: `1px solid ${color}30`, color }}
            />
          </div>
        ))}
        <div>
          <label className="text-[9px] font-mono block mb-1" style={{ color: "rgba(255,255,255,0.3)" }}>Trans.%</label>
          <input
            type="number" min={0} max={50} step={1}
            value={Math.round(transitionZone * 100)}
            onChange={(e) => onTransitionChange?.(Math.max(0, Math.min(50, parseInt(e.target.value) || 0)) / 100)}
            className="w-full px-1.5 py-1 rounded-lg text-[11px] outline-none font-mono text-center"
            style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(167,139,250,0.3)", color: "#A78BFA" }}
          />
        </div>
      </div>
      <p className="text-[9px] font-mono" style={{ color: "rgba(255,255,255,0.2)" }}>
        Arraste as linhas coloridas · Quadrado TZ = zona de transição
      </p>
    </div>
  );
}
// ─── DynamicNineSliceCanvas ──────────────────────────────────────────────────
// Renderiza um balão nine-slice dinâmico via canvas, medindo o texto antes de desenhar.
interface DynamicNineSliceCanvasProps {
  img: HTMLImageElement;
  slice: SliceValues;
  text: string;
  maxWidth?: number;
  minWidth?: number;
  paddingX?: number;
  paddingY?: number;
  horizontalPriority?: boolean;
  textColor?: string;
  fontSize?: number;
  textAlign?: TextAlign;
}
function DynamicNineSliceCanvas({
  img, slice, text,
  maxWidth = 260,
  minWidth = 60,
  paddingX = 16,
  paddingY = 12,
  horizontalPriority = true,
  textColor = "rgba(255,255,255,0.9)",
  fontSize = 13,
  textAlign = "left",
}: DynamicNineSliceCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    const dpr = window.devicePixelRatio || 1;
    const msgColor = textColor.trim() || "rgba(255,255,255,0.9)";

    // ── Fase 1: medir texto na escala 1:1 para calcular o renderScale ────────────
    // Usamos os slices originais para calcular o layout ideal sem escala.
    // Depois calculamos um fator de escala para que o balão fique proporcional
    // ao conteúdo, sem distorcer os cantos do asset.
    const { top: st0, bottom: sb0, left: sl0, right: sr0 } = slice;
    const measureCtx = document.createElement("canvas").getContext("2d")!;
    measureCtx.font = `${fontSize}px 'Space Grotesk', sans-serif`;
    const rawTextWidth0 = Math.ceil(measureCtx.measureText(text).width);
    // Padding efetivo na escala 1:1 (max 40% do slice)
    const effPadX0 = Math.min(paddingX, Math.max(2, Math.round(sl0 * 0.08)));
    // Largura ideal sem escala
    const idealW0 = rawTextWidth0 + sl0 + sr0 + effPadX0 * 2;
    const safeMin0 = sl0 + sr0 + 20;
    const effMin0  = Math.max(minWidth, safeMin0);
    const effMax0  = horizontalPriority ? maxWidth : Math.round(maxWidth * 0.7);
    const logW0    = Math.max(effMin0, Math.min(effMax0, idealW0));

    // ── Fase 2: calcular renderScale ─────────────────────────────────────────────
    // Se o conteúdo de texto é pequeno em relação aos slices, reduzir a escala
    // de renderização para que o balão fique proporcional.
    // Regra: o conteúdo de texto deve ocupar pelo menos 25% da largura total.
    // Se não ocupar, reduzimos a escala até que ocupe.
    const textFraction = rawTextWidth0 / logW0;
    // renderScale: 1.0 quando textFraction >= 0.25, reduz linearmente até 0.55
    // quando textFraction -> 0. Isso evita balões minúsculos para textos vazios.
    const renderScale = Math.max(0.55, Math.min(1.0, textFraction / 0.25));

    // ── Fase 3: recalcular tudo na escala final ──────────────────────────────────
    // Escalar os slices e o fontSize pelo renderScale
    const sl = Math.round(sl0 * renderScale);
    const sr = Math.round(sr0 * renderScale);
    const st = Math.round(st0 * renderScale);
    const sb = Math.round(sb0 * renderScale);
    const scaledFontSize = Math.max(8, Math.round(fontSize * renderScale));
    const lineHeight = Math.round(scaledFontSize * 1.45);
    // Padding efetivo na escala final
    const safeMaxPadH = Math.max(2, Math.round(sl * 0.08));
    const safeMaxPadV = Math.max(2, Math.round(st * 0.08));
    const effectivePadX = Math.min(Math.round(paddingX * renderScale), safeMaxPadH);
    const effectivePadY = Math.min(Math.round(paddingY * renderScale), safeMaxPadV);
    const innerLeft  = sl + effectivePadX;
    const innerRight = sr + effectivePadX;
    const innerTop   = st + effectivePadY;
    const innerBot   = sb + effectivePadY;
    // Remedir texto na escala final
    measureCtx.font = `${scaledFontSize}px 'Space Grotesk', sans-serif`;
    const rawTextWidth = Math.ceil(measureCtx.measureText(text).width);
    const idealWidth   = rawTextWidth + innerLeft + innerRight;
    const safeMinWidth = sl + sr + 20;
    const effectiveMin = Math.max(Math.round(minWidth * renderScale), safeMinWidth);
    const effectiveMax = horizontalPriority
      ? Math.round(maxWidth * renderScale)
      : Math.round(maxWidth * renderScale * 0.7);
    const logW = Math.max(effectiveMin, Math.min(effectiveMax, idealWidth));
    const maxContentW = Math.max(1, logW - innerLeft - innerRight);
    // ── Quebra de linha ──────────────────────────────────────────────────────────
    const words = text.split(" ");
    const lines: string[] = [];
    let cur = "";
    for (const word of words) {
      const test = cur ? cur + " " + word : word;
      if (measureCtx.measureText(test).width > maxContentW && cur) {
        lines.push(cur);
        cur = word;
      } else {
        cur = test;
      }
    }
    if (cur) lines.push(cur);
    if (lines.length === 0) lines.push("");
    // ── Cálculo de altura ────────────────────────────────────────────────────────
    const textH = lines.length * lineHeight;
    const logH  = Math.max(textH + innerTop + innerBot, st + sb + 8);
    // ── Redimensiona canvas ──────────────────────────────────────────────────────
    canvas.width  = Math.round(logW * dpr);
    canvas.height = Math.round(logH * dpr);
    canvas.style.width  = logW + "px";
    canvas.style.height = logH + "px";
    ctx.scale(dpr, dpr);
    // ── Desenha nine-slice (9 regiões) com slices escalados ──────────────────────
    const iw = img.naturalWidth;
    const ih = img.naturalHeight;
    const mw = logW - sl - sr;
    const mh = logH - st - sb;
    const regions: [number, number, number, number, number, number, number, number][] = [
      [0,      0,      sl,        st,        0,       0,       sl,  st  ],
      [sl,     0,      iw-sl-sr,  st,        sl,      0,       mw,  st  ],
      [iw-sr,  0,      sr,        st,        sl+mw,   0,       sr,  st  ],
      [0,      st,     sl,        ih-st-sb,  0,       st,      sl,  mh  ],
      [sl,     st,     iw-sl-sr,  ih-st-sb,  sl,      st,      mw,  mh  ],
      [iw-sr,  st,     sr,        ih-st-sb,  sl+mw,   st,      sr,  mh  ],
      [0,      ih-sb,  sl,        sb,        0,       st+mh,   sl,  sb  ],
      [sl,     ih-sb,  iw-sl-sr,  sb,        sl,      st+mh,   mw,  sb  ],
      [iw-sr,  ih-sb,  sr,        sb,        sl+mw,   st+mh,   sr,  sb  ],
    ];
    ctx.clearRect(0, 0, logW, logH);
    for (const [sx, sy, sw, sh, dx, dy, dw, dh] of regions) {
      if (sw > 0 && sh > 0 && dw > 0 && dh > 0) {
        ctx.drawImage(img, sx, sy, sw, sh, dx, dy, dw, dh);
      }
    }

    // ── Renderiza texto ──────────────────────────────────────────────────────
    const contentH   = logH - innerTop - innerBot;
    const textStartY = innerTop + Math.max(0, (contentH - textH) / 2);
    const fillW      = logW - innerLeft - innerRight;
    ctx.fillStyle   = msgColor;
    ctx.font        = `${scaledFontSize}px 'Space Grotesk', sans-serif`;
    ctx.textBaseline = "top";
    ctx.textAlign   = textAlign;
    lines.forEach((line, i) => {
      let x: number;
      if (textAlign === "center") x = innerLeft + fillW / 2;
      else if (textAlign === "right") x = logW - innerRight;
      else x = innerLeft;
      ctx.fillText(line, x, textStartY + i * lineHeight);
    });
  }, [img, slice, text, maxWidth, minWidth, paddingX, paddingY, horizontalPriority, textColor, fontSize, textAlign]);
  return <canvas ref={canvasRef} style={{ display: "block", maxWidth: "100%" }} />;
}

// ─── NineSliceCanvasCompact ───────────────────────────────────────────────────
// Variante experimental: cantos FIXOS no tamanho original do asset,
// fill zone (região central) se ajusta ao conteúdo — expande do meio para os
// lados, como o Amino fazia. Sem renderScale: os slices nunca são escalados.
// A largura mínima é sl+sr+8 (cantos + fill zone mínima de 8px), permitindo
// balões compactos para textos curtos sem distorcer os cantos decorativos.
interface NineSliceCanvasCompactProps {
  img: HTMLImageElement;
  slice: SliceValues;
  text: string;
  maxWidth?: number;
  minWidth?: number;
  paddingX?: number;
  paddingY?: number;
  horizontalPriority?: boolean;
  textColor?: string;
  fontSize?: number;
  textAlign?: TextAlign;
}
function NineSliceCanvasCompact({
  img, slice, text,
  maxWidth = 260,
  minWidth = 60,
  paddingX = 16,
  paddingY = 12,
  horizontalPriority = true,
  textColor = "rgba(255,255,255,0.9)",
  fontSize = 13,
  textAlign = "left",
}: NineSliceCanvasCompactProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    const dpr = window.devicePixelRatio || 1;
    const { top: st, bottom: sb, left: sl, right: sr } = slice;
    const lineHeight = Math.round(fontSize * 1.45);
    const msgColor = textColor.trim() || "rgba(255,255,255,0.9)";

    // ── Cantos FIXOS: padding adicional mínimo (8% do slice, máx 2px) ─────────
    // Para slices grandes (ex: 38px), o texto já está bem posicionado dentro
    // da borda decorativa. Padding adicional deve ser mínimo para evitar
    // espaço em branco excessivo.
    const safeMaxPadH = Math.max(2, Math.round(sl * 0.08));
    const safeMaxPadV = Math.max(2, Math.round(st * 0.08));
    const effectivePadX = Math.min(paddingX, safeMaxPadH);
    const effectivePadY = Math.min(paddingY, safeMaxPadV);
    const innerLeft  = sl + effectivePadX;
    const innerRight = sr + effectivePadX;
    const innerTop   = st + effectivePadY;
    const innerBot   = sb + effectivePadY;

    // ── Medição de texto ─────────────────────────────────────────────────────
    const measureCtx = document.createElement("canvas").getContext("2d")!;
    measureCtx.font = `${fontSize}px 'Space Grotesk', sans-serif`;
    const rawTextWidth = measureCtx.measureText(text).width;
    const idealWidth   = Math.ceil(rawTextWidth) + innerLeft + innerRight;

    // ── Largura: fill zone mínima de 8px (cantos nunca se sobrepõem) ─────────
    // hardMin = sl + sr + 8  → mínimo absoluto (cantos + fill zone mínima)
    // O minWidth do usuário é ignorado para textos curtos — o balão fica
    // tão estreito quanto o conteúdo exige.
    const hardMin      = sl + sr + 8;
    const effectiveMax = horizontalPriority ? maxWidth : Math.round(maxWidth * 0.7);
    const logW = Math.max(hardMin, Math.min(effectiveMax, idealWidth));
    const maxContentW = Math.max(1, logW - innerLeft - innerRight);

    // ── Quebra de linha ──────────────────────────────────────────────────────
    const words = text.split(" ");
    const lines: string[] = [];
    let cur = "";
    for (const word of words) {
      const test = cur ? cur + " " + word : word;
      if (measureCtx.measureText(test).width > maxContentW && cur) {
        lines.push(cur);
        cur = word;
      } else {
        cur = test;
      }
    }
    if (cur) lines.push(cur);
    if (lines.length === 0) lines.push("");

    // ── Cálculo de altura ────────────────────────────────────────────────────
    const textH = lines.length * lineHeight;
    const logH  = Math.max(textH + innerTop + innerBot, st + sb + 8);

    // ── Redimensiona canvas ──────────────────────────────────────────────────
    canvas.width  = Math.round(logW * dpr);
    canvas.height = Math.round(logH * dpr);
    canvas.style.width  = logW + "px";
    canvas.style.height = logH + "px";
    ctx.scale(dpr, dpr);

    // ── Desenha nine-slice (9 regiões) — cantos fixos, fill zone variável ────
    const iw = img.naturalWidth;
    const ih = img.naturalHeight;
    const mw = logW - sl - sr;
    const mh = logH - st - sb;
    const regions: [number, number, number, number, number, number, number, number][] = [
      [0,      0,      sl,        st,        0,       0,       sl,  st  ],
      [sl,     0,      iw-sl-sr,  st,        sl,      0,       mw,  st  ],
      [iw-sr,  0,      sr,        st,        sl+mw,   0,       sr,  st  ],
      [0,      st,     sl,        ih-st-sb,  0,       st,      sl,  mh  ],
      [sl,     st,     iw-sl-sr,  ih-st-sb,  sl,      st,      mw,  mh  ],
      [iw-sr,  st,     sr,        ih-st-sb,  sl+mw,   st,      sr,  mh  ],
      [0,      ih-sb,  sl,        sb,        0,       st+mh,   sl,  sb  ],
      [sl,     ih-sb,  iw-sl-sr,  sb,        sl,      st+mh,   mw,  sb  ],
      [iw-sr,  ih-sb,  sr,        sb,        sl+mw,   st+mh,   sr,  sb  ],
    ];
    ctx.clearRect(0, 0, logW, logH);
    for (const [sx, sy, sw, sh, dx, dy, dw, dh] of regions) {
      if (sw > 0 && sh > 0 && dw > 0 && dh > 0) {
        ctx.drawImage(img, sx, sy, sw, sh, dx, dy, dw, dh);
      }
    }
    // ── Renderiza texto ──────────────────────────────────────────────────────
    const contentH   = logH - innerTop - innerBot;
    const textStartY = innerTop + Math.max(0, (contentH - textH) / 2);
    const fillW      = logW - innerLeft - innerRight;
    ctx.fillStyle   = msgColor;
    ctx.font        = `${fontSize}px 'Space Grotesk', sans-serif`;
    ctx.textBaseline = "top";
    ctx.textAlign   = textAlign;
    lines.forEach((line, i) => {
      let x: number;
      if (textAlign === "center") x = innerLeft + fillW / 2;
      else if (textAlign === "right") x = logW - innerRight;
      else x = innerLeft;
      ctx.fillText(line, x, textStartY + i * lineHeight);
    });
  }, [img, slice, text, maxWidth, minWidth, paddingX, paddingY, horizontalPriority, textColor, fontSize, textAlign]);
  return <canvas ref={canvasRef} style={{ display: "block", maxWidth: "100%" }} />;
}

// ─── HorizontalStretchCanvas ────────────────────────────────────────────────────
// Modo onde APENAS a faixa central horizontal estica.
// Top, bottom e laterais são completamente fixos — nunca distorcem.
interface HorizontalStretchCanvasProps {
  img: HTMLImageElement;
  slice: SliceValues;
  text: string;
  maxWidth?: number;
  minWidth?: number;
  paddingX?: number;
  paddingY?: number;
  textColor?: string;
  fontSize?: number;
  textAlign?: TextAlign;
}
function HorizontalStretchCanvas({
  img, slice, text,
  maxWidth = 280,
  minWidth = 60,
  paddingX = 4,
  paddingY = 4,
  textColor,
  fontSize = 13,
  textAlign = "left",
}: HorizontalStretchCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    const dpr = window.devicePixelRatio || 1;
    const msgColor = textColor && textColor.trim() ? textColor.trim() : "#1a1a2e";
    const lineHeight = Math.round(fontSize * 1.45);
    const { top: st, bottom: sb, left: sl, right: sr } = slice;
    const iw = img.naturalWidth;
    const ih = img.naturalHeight;
    // ── Medição de texto ─────────────────────────────────────────────────────
    const measureCtx = document.createElement("canvas").getContext("2d")!;
    measureCtx.font = `${fontSize}px 'Space Grotesk', sans-serif`;
    const maxContentW = Math.max(1, maxWidth - sl - sr - paddingX * 2);
    const words = text.split(" ");
    const lines: string[] = [];
    let cur = "";
    for (const word of words) {
      const test = cur ? cur + " " + word : word;
      if (measureCtx.measureText(test).width > maxContentW && cur) {
        lines.push(cur); cur = word;
      } else { cur = test; }
    }
    if (cur) lines.push(cur);
    if (lines.length === 0) lines.push("");
    const maxLineWidth = Math.max(...lines.map(l => measureCtx.measureText(l).width));
    // ── Largura lógica: sl fixo + stretchZone + sr fixo ───────────────────────
    const stretchZone = Math.max(4, Math.ceil(maxLineWidth) + paddingX * 2);
    const rawW = sl + stretchZone + sr;
    const logW = Math.max(minWidth, Math.min(maxWidth, rawW), sl + sr + 4);
    // ── Altura lógica: usa altura da imagem como base ────────────────────────
    const textH = lines.length * lineHeight;
    const logH = Math.max(ih, textH + paddingY * 2);
    // ── Redimensiona canvas ──────────────────────────────────────────────────
    canvas.width  = Math.round(logW * dpr);
    canvas.height = Math.round(logH * dpr);
    canvas.style.width  = logW + "px";
    canvas.style.height = logH + "px";
    ctx.scale(dpr, dpr);
    ctx.clearRect(0, 0, logW, logH);
    // ── Desenha nine-slice: só o centro horizontal estica ─────────────────────
    const mw = logW - sl - sr;
    const mh = logH - st - sb;
    const srcCW = iw - sl - sr;
    const srcCH = ih - st - sb;
    const regions: [number,number,number,number,number,number,number,number][] = [
      [0,      0,      sl,    st,    0,       0,       sl, st],
      [iw-sr,  0,      sr,    st,    logW-sr, 0,       sr, st],
      [0,      ih-sb,  sl,    sb,    0,       logH-sb, sl, sb],
      [iw-sr,  ih-sb,  sr,    sb,    logW-sr, logH-sb, sr, sb],
      [sl,     0,      srcCW, st,    sl,      0,       mw, st],
      [sl,     ih-sb,  srcCW, sb,    sl,      logH-sb, mw, sb],
      [0,      st,     sl,    srcCH, 0,       st,      sl, mh],
      [iw-sr,  st,     sr,    srcCH, logW-sr, st,      sr, mh],
      [sl,     st,     srcCW, srcCH, sl,      st,      mw, mh],
    ];
    for (const [sx,sy,sw,sh,dx,dy,dw,dh] of regions) {
      if (sw>0 && sh>0 && dw>0 && dh>0) ctx.drawImage(img, sx,sy,sw,sh, dx,dy,dw,dh);
    }
    // ── Renderiza texto ──────────────────────────────────────────────────────
    const contentX = sl + paddingX;
    const contentW = logW - sl - sr - paddingX * 2;
    const contentH = logH - paddingY * 2;
    const textStartY = paddingY + Math.max(0, (contentH - textH) / 2);
    ctx.fillStyle    = msgColor;
    ctx.font         = `${fontSize}px 'Space Grotesk', sans-serif`;
    ctx.textBaseline = "top";
    ctx.textAlign    = textAlign;
    lines.forEach((line, i) => {
      const x = textAlign === "center" ? contentX + contentW / 2
              : textAlign === "right"  ? contentX + contentW
              : contentX;
      ctx.fillText(line, x, textStartY + i * lineHeight);
    });
  }, [img, slice, text, maxWidth, minWidth, paddingX, paddingY, textColor, fontSize, textAlign]);
  return <canvas ref={canvasRef} style={{ display: "block", maxWidth: "100%" }} />;
}

// ─── NineSliceCanvas ──────────────────────────────────────────────────────────
// Renderiza um balão nine-slice clássico via canvas com suporte a High-DPI (Retina).
interface NineSliceCanvasProps {
  img: HTMLImageElement;
  slice: SliceValues;
  text: string;
  maxWidth?: number;
  textColor?: string;
  fontSize?: number;
  textAlign?: TextAlign;
  padTop?: number; padBottom?: number; padLeft?: number; padRight?: number;
}
function NineSliceCanvas({
  img, slice, text,
  maxWidth = 220,
  textColor = "rgba(255,255,255,0.9)",
  fontSize = 13,
  textAlign = "left",
  padTop = 12, padBottom = 12, padLeft = 16, padRight = 16,
}: NineSliceCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    const dpr = window.devicePixelRatio || 1;
    const { top: st, bottom: sb, left: sl, right: sr } = slice;
    const lineHeight = Math.round(fontSize * 1.45);
    const msgColor = textColor.trim() || "rgba(255,255,255,0.9)";
    const innerLeft  = sl + padLeft;
    const innerRight = sr + padRight;
    const innerTop   = st + padTop;
    const innerBot   = sb + padBottom;
    const measureCtx = document.createElement("canvas").getContext("2d")!;
    measureCtx.font = `${fontSize}px 'Space Grotesk', sans-serif`;
    const maxContentW = Math.max(1, maxWidth - innerLeft - innerRight);
    const words = text.split(" ");
    const lines: string[] = [];
    let cur = "";
    for (const word of words) {
      const test = cur ? cur + " " + word : word;
      if (measureCtx.measureText(test).width > maxContentW && cur) {
        lines.push(cur);
        cur = word;
      } else {
        cur = test;
      }
    }
    if (cur) lines.push(cur);
    if (lines.length === 0) lines.push("");
    const textH = lines.length * lineHeight;
    const logW  = maxWidth;
    const logH  = Math.max(textH + innerTop + innerBot, st + sb + 8);
    canvas.width  = Math.round(logW * dpr);
    canvas.height = Math.round(logH * dpr);
    canvas.style.width  = logW + "px";
    canvas.style.height = logH + "px";
    ctx.scale(dpr, dpr);
    const iw = img.naturalWidth;
    const ih = img.naturalHeight;
    const mw = logW - sl - sr;
    const mh = logH - st - sb;
    const regions: [number, number, number, number, number, number, number, number][] = [
      [0,      0,      sl,        st,        0,       0,       sl,  st  ],
      [sl,     0,      iw-sl-sr,  st,        sl,      0,       mw,  st  ],
      [iw-sr,  0,      sr,        st,        sl+mw,   0,       sr,  st  ],
      [0,      st,     sl,        ih-st-sb,  0,       st,      sl,  mh  ],
      [sl,     st,     iw-sl-sr,  ih-st-sb,  sl,      st,      mw,  mh  ],
      [iw-sr,  st,     sr,        ih-st-sb,  sl+mw,   st,      sr,  mh  ],
      [0,      ih-sb,  sl,        sb,        0,       st+mh,   sl,  sb  ],
      [sl,     ih-sb,  iw-sl-sr,  sb,        sl,      st+mh,   mw,  sb  ],
      [iw-sr,  ih-sb,  sr,        sb,        sl+mw,   st+mh,   sr,  sb  ],
    ];
    ctx.clearRect(0, 0, logW, logH);
    for (const [sx, sy, sw, sh, dx, dy, dw, dh] of regions) {
      if (sw > 0 && sh > 0 && dw > 0 && dh > 0) ctx.drawImage(img, sx, sy, sw, sh, dx, dy, dw, dh);
    }
    const contentH   = logH - innerTop - innerBot;
    const textStartY = innerTop + Math.max(0, (contentH - textH) / 2);
    const fillW      = logW - innerLeft - innerRight;
    ctx.fillStyle    = msgColor;
    ctx.font         = `${fontSize}px 'Space Grotesk', sans-serif`;
    ctx.textBaseline = "top";
    ctx.textAlign    = textAlign;
    lines.forEach((line, i) => {
      let x: number;
      if (textAlign === "center") x = innerLeft + fillW / 2;
      else if (textAlign === "right") x = logW - innerRight;
      else x = innerLeft;
      ctx.fillText(line, x, textStartY + i * lineHeight);
    });
  }, [img, slice, text, maxWidth, textColor, fontSize, textAlign, padTop, padBottom, padLeft, padRight]);
  return <canvas ref={canvasRef} style={{ display: "block", maxWidth: "100%" }} />;
}
// ─── NineSliceBubble ──────────────────────────────────────────────────────────
// Wrapper que gerencia o carregamento da imagem e delega o desenho ao NineSliceCanvas.
interface NineSliceBubbleProps extends Omit<NineSliceCanvasProps, "img"> {
  imageUrl: string;
}

function NineSliceBubble({ imageUrl, ...rest }: NineSliceBubbleProps) {
  const imgState = useImageLoader(imageUrl);

  if (imgState.status === "loading") {
    return (
      <div className="flex items-center justify-center rounded-xl"
        style={{ width: rest.maxWidth ?? 220, height: 60, background: "rgba(255,255,255,0.03)" }}>
        <Loader2 size={12} className="animate-spin" style={{ color: "rgba(255,255,255,0.15)" }} />
      </div>
    );
  }
  if (imgState.status === "error" || imgState.status === "idle") {
    return null;
  }
  return <NineSliceCanvas img={imgState.img} {...rest} />;
}

// ─── NineSliceEditor ──────────────────────────────────────────────────────────
// Editor interativo com handles arrastáveis + inputs numéricos + preview de texto.

type DragHandle = "top" | "bottom" | "left" | "right" | null;

const MIN_CENTER = 4; // pixels mínimos para a área central do nine-slice

interface NineSliceEditorProps {
  imageUrl: string;
  imageDimensions: { w: number; h: number } | null;
  slice: SliceValues;
  onChange: (s: SliceValues) => void;
  textColor: string;
  fontSize: number;
  textAlign: TextAlign;
  padTop: number; padBottom: number; padLeft: number; padRight: number;
  // Campos do modo dynamic_nineslice (opcionais)
  isDynamic?: boolean;
  dynMaxWidth?: number;
  dynMinWidth?: number;
  dynPaddingX?: number;
  dynPaddingY?: number;
  dynHorizontalPriority?: boolean;
  dynTransitionZone?: number;
  onTransitionChange?: (t: number) => void;
  // Campos do modo horizontal_stretch (opcionais)
  isHorizontalStretch?: boolean;
  hsMaxWidth?: number;
  hsMinWidth?: number;
  hsPaddingX?: number;
  hsPaddingY?: number;
}

function NineSliceEditor({
  imageUrl, imageDimensions, slice, onChange,
  textColor, fontSize, textAlign,
  padTop, padBottom, padLeft, padRight,
  isDynamic = false,
  dynMaxWidth = 260,
  dynMinWidth = 60,
  dynPaddingX = 16,
  dynPaddingY = 12,
  dynHorizontalPriority = true,
  dynTransitionZone = 0.15,
  onTransitionChange,
  isHorizontalStretch = false,
  hsMaxWidth = 280,
  hsMinWidth = 60,
  hsPaddingX = 4,
  hsPaddingY = 4,
}: NineSliceEditorProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [canvasSize, setCanvasSize] = useState({ w: 240, h: 240 });
  const [dragging, setDragging] = useState<DragHandle>(null);
  const [hovering, setHovering] = useState<DragHandle>(null);
  const dragStart = useRef<{ x: number; y: number; value: number } | null>(null);

  // Observa redimensionamento do container
  useEffect(() => {
    function update() {
      if (!containerRef.current) return;
      const rect = containerRef.current.getBoundingClientRect();
      setCanvasSize({ w: rect.width, h: rect.height });
    }
    update();
    const ro = new ResizeObserver(update);
    if (containerRef.current) ro.observe(containerRef.current);
    return () => ro.disconnect();
  }, []);

  const imgW = imageDimensions?.w ?? 128;
  const imgH = imageDimensions?.h ?? 128;
  const scaleX = canvasSize.w / imgW;
  const scaleY = canvasSize.h / imgH;

  // Posição das linhas em pixels no canvas
  const topPx    = slice.top    * scaleY;
  const bottomPx = canvasSize.h - slice.bottom * scaleY;
  const leftPx   = slice.left   * scaleX;
  const rightPx  = canvasSize.w - slice.right  * scaleX;

  const HIT = 10; // tolerância de hit em px

  const getHandleAt = useCallback((x: number, y: number): DragHandle => {
    // Prioridade: linhas horizontais antes das verticais
    if (Math.abs(y - topPx)    < HIT) return "top";
    if (Math.abs(y - bottomPx) < HIT) return "bottom";
    if (Math.abs(x - leftPx)   < HIT) return "left";
    if (Math.abs(x - rightPx)  < HIT) return "right";
    return null;
  }, [topPx, bottomPx, leftPx, rightPx]);

  const onMouseDown = useCallback((e: React.MouseEvent) => {
    const rect = containerRef.current!.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    const handle = getHandleAt(x, y);
    if (!handle) return;
    e.preventDefault();
    setDragging(handle);
    const currentVal = slice[handle];
    dragStart.current = { x, y, value: currentVal };
  }, [getHandleAt, slice]);

   const onMouseMove = useCallback((e: React.MouseEvent) => {
    const rect = containerRef.current!.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    if (!dragging || !dragStart.current) {
      setHovering(getHandleAt(x, y));
      return;
    }
    e.preventDefault(); // bloqueia scroll/seleção de texto durante drag
    const dx = x - dragStart.current.x;
    const dy = y - dragStart.current.y;;

    // Constraints estritas: impede que linhas se cruzem
    let newVal: number;
    if (dragging === "top") {
      const maxTop = imgH - slice.bottom - MIN_CENTER;
      newVal = Math.max(0, Math.min(Math.round(dragStart.current.value + dy / scaleY), maxTop));
      onChange({ ...slice, top: newVal });
    } else if (dragging === "bottom") {
      const maxBot = imgH - slice.top - MIN_CENTER;
      newVal = Math.max(0, Math.min(Math.round(dragStart.current.value - dy / scaleY), maxBot));
      onChange({ ...slice, bottom: newVal });
    } else if (dragging === "left") {
      const maxLeft = imgW - slice.right - MIN_CENTER;
      newVal = Math.max(0, Math.min(Math.round(dragStart.current.value + dx / scaleX), maxLeft));
      onChange({ ...slice, left: newVal });
    } else {
      const maxRight = imgW - slice.left - MIN_CENTER;
      newVal = Math.max(0, Math.min(Math.round(dragStart.current.value - dx / scaleX), maxRight));
      onChange({ ...slice, right: newVal });
    }
  }, [dragging, getHandleAt, slice, onChange, imgW, imgH, scaleX, scaleY]);

  const onMouseUp = useCallback(() => {
    setDragging(null);
    dragStart.current = null;
  }, []);

  const cursor = dragging
    ? (dragging === "top" || dragging === "bottom" ? "ns-resize" : "ew-resize")
    : hovering
    ? (hovering === "top" || hovering === "bottom" ? "ns-resize" : "ew-resize")
    : "default";

  const LINE_COLORS: Record<string, string> = {
    top: "#F59E0B", bottom: "#F59E0B",
    left: "#34D399", right: "#34D399",
  };

  function lineStyle(handle: DragHandle, isHorizontal: boolean): React.CSSProperties {
    const active = dragging === handle || hovering === handle;
    const color = LINE_COLORS[handle!];
    return {
      position: "absolute",
      background: active ? color : `${color}99`,
      transition: dragging ? "none" : "background 0.15s",
      zIndex: 10,
      ...(isHorizontal
        ? { left: 0, right: 0, height: active ? 2 : 1.5, cursor: "ns-resize" }
        : { top: 0, bottom: 0, width: active ? 2 : 1.5, cursor: "ew-resize" }),
    };
  }

  // Labels das 9 regiões
  const regions = useMemo(() => [
    { label: "TL",   x: leftPx / 2,                          y: topPx / 2 },
    { label: "TR",   x: (rightPx + canvasSize.w) / 2,        y: topPx / 2 },
    { label: "BL",   x: leftPx / 2,                          y: (bottomPx + canvasSize.h) / 2 },
    { label: "BR",   x: (rightPx + canvasSize.w) / 2,        y: (bottomPx + canvasSize.h) / 2 },
    { label: "T",    x: (leftPx + rightPx) / 2,              y: topPx / 2 },
    { label: "B",    x: (leftPx + rightPx) / 2,              y: (bottomPx + canvasSize.h) / 2 },
    { label: "L",    x: leftPx / 2,                          y: (topPx + bottomPx) / 2 },
    { label: "R",    x: (rightPx + canvasSize.w) / 2,        y: (topPx + bottomPx) / 2 },
    { label: "FILL", x: (leftPx + rightPx) / 2,              y: (topPx + bottomPx) / 2 },
  ], [leftPx, rightPx, topPx, bottomPx, canvasSize]);

  // Validação dos inputs numéricos com constraints
  function handleInputChange(key: keyof SliceValues, raw: string) {
    const val = Math.max(0, parseInt(raw) || 0);
    const next = { ...slice, [key]: val };
    // Aplica constraints
    if (key === "top")    next.top    = Math.min(val, imgH - next.bottom - MIN_CENTER);
    if (key === "bottom") next.bottom = Math.min(val, imgH - next.top    - MIN_CENTER);
    if (key === "left")   next.left   = Math.min(val, imgW - next.right  - MIN_CENTER);
    if (key === "right")  next.right  = Math.min(val, imgW - next.left   - MIN_CENTER);
    onChange(next);
  }

  return (
    <div className="space-y-3">
      {/* Legenda */}
      <div className="flex items-center gap-3 flex-wrap">
        <div className="flex items-center gap-1.5">
          <div className="w-4 h-0.5 rounded" style={{ background: "#F59E0B" }} />
          <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.35)" }}>Topo / Base</span>
        </div>
        <div className="flex items-center gap-1.5">
          <div className="w-0.5 h-4 rounded" style={{ background: "#34D399" }} />
          <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.35)" }}>Esq. / Dir.</span>
        </div>
        <div className="flex items-center gap-1.5 ml-auto">
          <Move size={10} style={{ color: "rgba(255,255,255,0.25)" }} />
          <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.25)" }}>Arraste as linhas</span>
        </div>
      </div>

      {/* Canvas interativo */}
      <div
        ref={containerRef}
        className="relative rounded-xl overflow-hidden select-none"
        style={{
          width: "100%",
          paddingBottom: `${(imgH / imgW) * 100}%`,
          background: "repeating-conic-gradient(rgba(255,255,255,0.04) 0% 25%, transparent 0% 50%) 0 0 / 12px 12px",
          border: "1px solid rgba(255,255,255,0.08)",
          cursor,
          userSelect: "none",
          touchAction: "none",
          overflowAnchor: "none",
        }}
        onMouseDown={onMouseDown}
        onMouseMove={onMouseMove}
        onMouseUp={onMouseUp}
        onMouseLeave={onMouseUp}
      >
        {/* Imagem de fundo */}
        <img
          src={imageUrl}
          alt="bubble"
          draggable={false}
          style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "fill", pointerEvents: "none" }}
        />

        {/* Overlay nas regiões de borda */}
        <div style={{ position: "absolute", inset: 0, pointerEvents: "none" }}>
          {/* Topo: de 0 até topPx */}
          <div style={{ position: "absolute", left: 0, right: 0, top: 0, height: topPx, background: "rgba(0,0,0,0.25)" }} />
          {/* Base: de bottomPx até o fim — usa top+bottom=0 para não depender de canvasSize.h */}
          <div style={{ position: "absolute", left: 0, right: 0, top: bottomPx, bottom: 0, background: "rgba(0,0,0,0.25)" }} />
          {/* Esquerda: faixa vertical entre topPx e bottomPx */}
          <div style={{ position: "absolute", left: 0, width: leftPx, top: topPx, bottom: `calc(100% - ${bottomPx}px)`, background: "rgba(0,0,0,0.25)" }} />
          {/* Direita: faixa vertical entre topPx e bottomPx — usa right+left para não depender de canvasSize.w */}
          <div style={{ position: "absolute", left: rightPx, right: 0, top: topPx, bottom: `calc(100% - ${bottomPx}px)`, background: "rgba(0,0,0,0.25)" }} />
        </div>

        {/* Linha Topo */}
        <div style={{ ...lineStyle("top", true), top: topPx - 0.75 }}>
          <div style={{ position: "absolute", right: 4, top: -9, fontSize: 9, fontFamily: "'DM Mono', monospace", color: "#F59E0B", background: "rgba(0,0,0,0.7)", padding: "1px 4px", borderRadius: 4, whiteSpace: "nowrap" }}>
            T: {slice.top}px
          </div>
        </div>

        {/* Linha Base */}
        <div style={{ ...lineStyle("bottom", true), top: bottomPx - 0.75 }}>
          <div style={{ position: "absolute", right: 4, bottom: -9, fontSize: 9, fontFamily: "'DM Mono', monospace", color: "#F59E0B", background: "rgba(0,0,0,0.7)", padding: "1px 4px", borderRadius: 4, whiteSpace: "nowrap" }}>
            B: {slice.bottom}px
          </div>
        </div>

        {/* Linha Esquerda */}
        <div style={{ ...lineStyle("left", false), left: leftPx - 0.75 }}>
          <div style={{ position: "absolute", left: 4, top: 4, fontSize: 9, fontFamily: "'DM Mono', monospace", color: "#34D399", background: "rgba(0,0,0,0.7)", padding: "1px 4px", borderRadius: 4, whiteSpace: "nowrap", writingMode: "vertical-rl", transform: "rotate(180deg)" }}>
            L: {slice.left}px
          </div>
        </div>

        {/* Linha Direita */}
        <div style={{ ...lineStyle("right", false), left: rightPx - 0.75 }}>
          <div style={{ position: "absolute", right: 4, top: 4, fontSize: 9, fontFamily: "'DM Mono', monospace", color: "#34D399", background: "rgba(0,0,0,0.7)", padding: "1px 4px", borderRadius: 4, whiteSpace: "nowrap", writingMode: "vertical-rl" }}>
            R: {slice.right}px
          </div>
        </div>

        {/* Labels das regiões */}
        {regions.map(({ label, x, y }) => (
          <div key={label} style={{
            position: "absolute", left: x, top: y,
            transform: "translate(-50%, -50%)",
            fontSize: 8, fontFamily: "'DM Mono', monospace",
            color: "rgba(255,255,255,0.35)", background: "rgba(0,0,0,0.5)",
            padding: "1px 3px", borderRadius: 3, pointerEvents: "none", whiteSpace: "nowrap",
          }}>
            {label}
          </div>
        ))}
      </div>

      {/* Inputs numéricos sincronizados com os handles */}
      <div className="grid grid-cols-4 gap-2">
        {([
          { label: "Topo",  key: "top"    as const, color: "#F59E0B" },
          { label: "Base",  key: "bottom" as const, color: "#F59E0B" },
          { label: "Esq.",  key: "left"   as const, color: "#34D399" },
          { label: "Dir.",  key: "right"  as const, color: "#34D399" },
        ]).map(({ label, key, color }) => (
          <div key={key}>
            <label className="text-[9px] font-mono block mb-1" style={{ color: "rgba(255,255,255,0.3)" }}>{label}</label>
            <input
              type="number" min={0}
              value={slice[key]}
              onChange={(e) => handleInputChange(key, e.target.value)}
              className="w-full px-2 py-1.5 rounded-lg text-[12px] outline-none font-mono text-center"
              style={{ background: "rgba(255,255,255,0.04)", border: `1px solid ${color}30`, color }}
            />
          </div>
        ))}
      </div>

      {/* Overlay de zonas dinâmicas — PRIMEIRO no DOM para não ser empurrado pelo preview */}
      {/* O preview fica abaixo e pode crescer livremente sem deslocar o overlay durante o drag */}
      {isDynamic && (
        <DynamicNineSliceOverlay
          imageUrl={imageUrl}
          imageDimensions={imageDimensions}
          slice={slice}
          transitionZone={dynTransitionZone}
          onSliceChange={onChange}
          onTransitionChange={onTransitionChange}
        />
      )}
      {/* Preview de texto em tempo real — modo dinâmico ou clássico conforme isDynamic */}
      <NineSlicePreviewPanel
        imageUrl={imageUrl}
        slice={slice}
        textColor={textColor}
        fontSize={fontSize}
        textAlign={textAlign}
        padTop={padTop} padBottom={padBottom} padLeft={padLeft} padRight={padRight}
        isDynamic={isDynamic}
        dynMaxWidth={dynMaxWidth}
        dynMinWidth={dynMinWidth}
        dynPaddingX={dynPaddingX}
        dynPaddingY={dynPaddingY}
        dynHorizontalPriority={dynHorizontalPriority}
        dynTransitionZone={dynTransitionZone}
        isHorizontalStretch={isHorizontalStretch}
        hsMaxWidth={hsMaxWidth}
        hsMinWidth={hsMinWidth}
        hsPaddingX={hsPaddingX}
        hsPaddingY={hsPaddingY}
      />
    </div>
  );
}


// ─── PolyFillEditor ───────────────────────────────────────────────────────────
// Editor poligonal opcional com 8 handles arrastáveis (TL, T, TR, R, BR, B, BL, L).
// Os pontos são normalizados (0–1) em relação às dimensões da imagem original.
// Quando ativo, o Flutter usa ClipPath com esses pontos; caso contrário, usa o
// padding normal (slice + pad) — comportamento padrão preservado.
interface PolyFillEditorProps {
  imageUrl: string;
  imageDimensions: { w: number; h: number } | null;
  points: PolyPoint[];          // 8 pontos normalizados: TL,T,TR,R,BR,B,BL,L
  onChange: (pts: PolyPoint[]) => void;
  sliceValues: SliceValues;
  padTop: number; padBottom: number; padLeft: number; padRight: number;
}

/** Gera 8 pontos iniciais a partir dos valores de slice+pad (normalizados 0–1) */
function defaultPolyPoints(
  imgW: number, imgH: number,
  slice: SliceValues,
  padTop: number, padBottom: number, padLeft: number, padRight: number,
): PolyPoint[] {
  const l = (slice.left  + padLeft)   / imgW;
  const r = (imgW - slice.right  - padRight)  / imgW;
  const t = (slice.top   + padTop)    / imgH;
  const b = (imgH - slice.bottom - padBottom) / imgH;
  const cx = (l + r) / 2;
  const cy = (t + b) / 2;
  // Ordem: TL, T, TR, R, BR, B, BL, L
  return [
    { x: l,  y: t  },  // TL
    { x: cx, y: t  },  // T
    { x: r,  y: t  },  // TR
    { x: r,  y: cy },  // R
    { x: r,  y: b  },  // BR
    { x: cx, y: b  },  // B
    { x: l,  y: b  },  // BL
    { x: l,  y: cy },  // L
  ];
}

const HANDLE_LABELS = ["TL", "T", "TR", "R", "BR", "B", "BL", "L"];
const HANDLE_COLOR  = "#A78BFA";
const HANDLE_RADIUS = 7;

function PolyFillEditor({
  imageUrl, imageDimensions, points, onChange,
  sliceValues, padTop, padBottom, padLeft, padRight,
}: PolyFillEditorProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [dragging, setDragging] = useState<number | null>(null);
  const dragStart = useRef<{ mx: number; my: number; ox: number; oy: number } | null>(null);

  const imgW = imageDimensions?.w ?? 128;
  const imgH = imageDimensions?.h ?? 128;

  // Tamanho do canvas em px (igual ao NineSliceEditor)
  const [canvasSize, setCanvasSize] = useState({ w: 300, h: 300 });
  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    const obs = new ResizeObserver(() => {
      const w = el.clientWidth;
      const h = Math.round(w * (imgH / imgW));
      setCanvasSize({ w, h });
    });
    obs.observe(el);
    return () => obs.disconnect();
  }, [imgW, imgH]);

  // Inicializa pontos se ainda estiver vazio
  useEffect(() => {
    if (points.length === 0) {
      onChange(defaultPolyPoints(imgW, imgH, sliceValues, padTop, padBottom, padLeft, padRight));
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const scaleX = canvasSize.w / imgW;
  const scaleY = canvasSize.h / imgH;

  // Converte ponto normalizado → px no canvas
  const toPx = (p: PolyPoint) => ({ x: p.x * imgW * scaleX, y: p.y * imgH * scaleY });
  // Converte px no canvas → normalizado
  const toNorm = (px: number, py: number): PolyPoint => ({
    x: Math.max(0, Math.min(1, px / (imgW * scaleX))),
    y: Math.max(0, Math.min(1, py / (imgH * scaleY))),
  });

  const pts = points.length === 8 ? points
    : defaultPolyPoints(imgW, imgH, sliceValues, padTop, padBottom, padLeft, padRight);

  // SVG polygon string
  const polyStr = pts.map(p => {
    const { x, y } = toPx(p);
    return `${x},${y}`;
  }).join(" ");

  function getHandleAt(mx: number, my: number): number | null {
    for (let i = 0; i < pts.length; i++) {
      const { x, y } = toPx(pts[i]);
      if (Math.hypot(mx - x, my - y) < HANDLE_RADIUS + 4) return i;
    }
    return null;
  }

  const onMouseDown = useCallback((e: React.MouseEvent) => {
    const rect = containerRef.current!.getBoundingClientRect();
    const mx = e.clientX - rect.left;
    const my = e.clientY - rect.top;
    const idx = getHandleAt(mx, my);
    if (idx === null) return;
    e.preventDefault();
    setDragging(idx);
    const { x, y } = toPx(pts[idx]);
    dragStart.current = { mx, my, ox: x, oy: y };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pts, canvasSize]);

  const onMouseMove = useCallback((e: React.MouseEvent) => {
    if (dragging === null || !dragStart.current) return;
    e.preventDefault(); // bloqueia scroll/seleção de texto durante drag
    const rect = containerRef.current!.getBoundingClientRect();
    const mx = e.clientX - rect.left;
    const my = e.clientY - rect.top;
    const dx = mx - dragStart.current.mx;
    const dy = my - dragStart.current.my;
    const newPx = dragStart.current.ox + dx;
    const newPy = dragStart.current.oy + dy;
    const norm = toNorm(newPx, newPy);
    const next = pts.map((p, i) => i === dragging ? norm : p);
    onChange(next);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [dragging, pts, canvasSize]);

  const onMouseUp = useCallback(() => {
    setDragging(null);
    dragStart.current = null;
  }, []);

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <p className="text-[9px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.25)" }}>
          Área de Texto Poligonal
        </p>
        <button
          type="button"
          onClick={() => onChange(defaultPolyPoints(imgW, imgH, sliceValues, padTop, padBottom, padLeft, padRight))}
          className="text-[9px] font-mono px-2 py-1 rounded-lg transition-all"
          style={{ background: "rgba(167,139,250,0.08)", border: "1px solid rgba(167,139,250,0.2)", color: "#A78BFA" }}
        >
          Resetar
        </button>
      </div>
      <div
        ref={containerRef}
        className="relative rounded-xl overflow-hidden select-none"
        style={{
          width: "100%",
          paddingBottom: `${(imgH / imgW) * 100}%`,
          background: "repeating-conic-gradient(rgba(255,255,255,0.04) 0% 25%, transparent 0% 50%) 0 0 / 12px 12px",
          border: "1px solid rgba(255,255,255,0.08)",
          cursor: dragging !== null ? "grabbing" : "default",
          userSelect: "none",
        }}
        onMouseDown={onMouseDown}
        onMouseMove={onMouseMove}
        onMouseUp={onMouseUp}
        onMouseLeave={onMouseUp}
      >
        {/* Imagem de fundo */}
        <img
          src={imageUrl}
          alt="bubble"
          draggable={false}
          style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "fill", pointerEvents: "none" }}
        />
        {/* SVG overlay */}
        <svg
          style={{ position: "absolute", inset: 0, width: "100%", height: "100%", pointerEvents: "none" }}
          viewBox={`0 0 ${canvasSize.w} ${canvasSize.h}`}
          preserveAspectRatio="none"
        >
          {/* Overlay escuro fora do polígono */}
          <defs>
            <mask id="poly-mask">
              <rect width={canvasSize.w} height={canvasSize.h} fill="white" />
              <polygon points={polyStr} fill="black" />
            </mask>
          </defs>
          <rect width={canvasSize.w} height={canvasSize.h} fill="rgba(0,0,0,0.45)" mask="url(#poly-mask)" />
          {/* Borda do polígono */}
          <polygon points={polyStr} fill="none" stroke={HANDLE_COLOR} strokeWidth="1.5" strokeDasharray="4 3" opacity="0.8" />
          {/* Handles */}
          {pts.map((p, i) => {
            const { x, y } = toPx(p);
            return (
              <g key={i} style={{ pointerEvents: "all", cursor: "grab" }}>
                <circle cx={x} cy={y} r={HANDLE_RADIUS + 3} fill="transparent" />
                <circle
                  cx={x} cy={y} r={HANDLE_RADIUS}
                  fill={dragging === i ? HANDLE_COLOR : "rgba(167,139,250,0.25)"}
                  stroke={HANDLE_COLOR}
                  strokeWidth={dragging === i ? 2 : 1.5}
                />
                <text
                  x={x} y={y + 1}
                  textAnchor="middle" dominantBaseline="middle"
                  fontSize="6" fontFamily="'DM Mono', monospace"
                  fill="white" opacity="0.8"
                  style={{ pointerEvents: "none" }}
                >
                  {HANDLE_LABELS[i]}
                </text>
              </g>
            );
          })}
        </svg>
      </div>
      <p className="text-[9px] font-mono" style={{ color: "rgba(255,255,255,0.2)" }}>
        Arraste os 8 pontos para definir o polígono de fill. O texto ficará confinado a essa área no app.
      </p>
    </div>
  );
}

// ─── NineSlicePreviewPanel ────────────────────────────────────────────────────
// Painel de preview com texto editável e 3 tamanhos de balão.
// Compartilhado entre a aba "Ajustar Bordas" e a aba "Preview Final".

interface NineSlicePreviewPanelProps {
  imageUrl: string;
  slice: SliceValues;
  textColor: string;
  fontSize: number;
  textAlign: TextAlign;
  padTop: number; padBottom: number; padLeft: number; padRight: number;
  // Campos do modo dynamic_nineslice (opcionais — padrões compatíveis com modo clássico)
  isDynamic?: boolean;
  dynMaxWidth?: number;
  dynMinWidth?: number;
  dynPaddingX?: number;
  dynPaddingY?: number;
  dynHorizontalPriority?: boolean;
  dynTransitionZone?: number;
  // Campos do modo horizontal_stretch
  isHorizontalStretch?: boolean;
  hsMaxWidth?: number;
  hsMinWidth?: number;
  hsPaddingX?: number;
  hsPaddingY?: number;
}

const PREVIEW_SAMPLES = [
  { id: "short",  label: "Curto",  text: "Oi!",                                        maxWidth: 140, mine: true  },
  { id: "medium", label: "Médio",  text: "Esse bubble ficou incrível 🔥",               maxWidth: 200, mine: false },
  { id: "long",   label: "Longo",  text: "Concordo! Muito estiloso mesmo, adorei o design!", maxWidth: 260, mine: true  },
];

function NineSlicePreviewPanel({
  imageUrl, slice, textColor, fontSize, textAlign,
  padTop, padBottom, padLeft, padRight,
  isDynamic = false,
  dynMaxWidth = 260,
  dynMinWidth = 60,
  dynPaddingX = 16,
  dynPaddingY = 12,
  dynHorizontalPriority = true,
  dynTransitionZone = 0.15,
  isHorizontalStretch = false,
  hsMaxWidth = 280,
  hsMinWidth = 60,
  hsPaddingX = 4,
  hsPaddingY = 4,
}: NineSlicePreviewPanelProps) {
  const [customText, setCustomText] = useState("");
  const imgState = useImageLoader(imageUrl);

  return (
    <div className="rounded-xl space-y-2" style={{ background: "rgba(0,0,0,0.25)", border: "1px solid rgba(255,255,255,0.06)", padding: "10px 12px" }}>
      {/* Campo de texto editável */}
      <div className="flex items-center gap-2">
        <p className="text-[9px] font-mono tracking-widest uppercase flex-shrink-0" style={{ color: "rgba(255,255,255,0.25)" }}>TESTAR TEXTO</p>
        <input
          value={customText}
          onChange={(e) => setCustomText(e.target.value)}
          placeholder="Digite para testar..."
          className="flex-1 px-2 py-1 rounded-lg text-[11px] outline-none"
          style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)", color: "rgba(255,255,255,0.7)", fontFamily: "'Space Grotesk', sans-serif" }}
        />
      </div>

      {/* Estado de carregamento */}
      {imgState.status === "loading" && (
        <div className="flex items-center justify-center py-4 gap-2">
          <Loader2 size={14} className="animate-spin" style={{ color: "rgba(255,255,255,0.2)" }} />
          <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.2)" }}>Carregando imagem...</span>
        </div>
      )}

      {imgState.status === "error" && (
        <div className="flex items-center justify-center py-4 gap-2">
          <AlertCircle size={14} style={{ color: "rgba(239,68,68,0.6)" }} />
          <span className="text-[10px] font-mono" style={{ color: "rgba(239,68,68,0.6)" }}>Erro ao carregar imagem</span>
        </div>
      )}

      {/* Previews — só renderiza quando a imagem está pronta */}
      {/* min-height fixo: evita que mudanças de tamanho dos canvases dinâmicos
           empurrem o layout durante o drag no overlay acima */}
      {imgState.status === "ready" && (
        <div className="flex flex-col gap-2 pt-1" style={{ minHeight: 120, overflow: "hidden" }}>
          {/* Badge de modo */}
          {isDynamic && (
            <div className="flex items-center gap-1.5 mb-1">
              <div className="w-1.5 h-1.5 rounded-full" style={{ background: "#34D399" }} />
              <span className="text-[9px] font-mono" style={{ color: "#34D399" }}>dynamic_nineslice</span>
              <span className="text-[9px] font-mono" style={{ color: "rgba(255,255,255,0.2)" }}>
                · max {dynMaxWidth}px · min {dynMinWidth}px · pad {dynPaddingX}/{dynPaddingY}
              </span>
            </div>
          )}
          {isHorizontalStretch && (
            <div className="flex items-center gap-1.5 mb-1">
              <div className="w-1.5 h-1.5 rounded-full" style={{ background: "#FBBF24" }} />
              <span className="text-[9px] font-mono" style={{ color: "#FBBF24" }}>horizontal_stretch</span>
              <span className="text-[9px] font-mono" style={{ color: "rgba(255,255,255,0.2)" }}>
                · max {hsMaxWidth}px · min {hsMinWidth}px · pad {hsPaddingX}/{hsPaddingY}
              </span>
            </div>
          )}
          {PREVIEW_SAMPLES.map((s) => (
            <div key={s.id} className="flex items-center gap-2">
              <span className="text-[8px] font-mono w-10 flex-shrink-0 text-right" style={{ color: "rgba(255,255,255,0.2)" }}>{s.label}</span>
              <div className={`flex flex-1 ${s.mine ? "justify-end" : "justify-start"}`}>
                {isHorizontalStretch ? (
                  <HorizontalStretchCanvas
                    img={imgState.img}
                    slice={slice}
                    text={customText || s.text}
                    maxWidth={hsMaxWidth}
                    minWidth={hsMinWidth}
                    paddingX={hsPaddingX}
                    paddingY={hsPaddingY}
                    textColor={textColor}
                    fontSize={fontSize}
                    textAlign={textAlign}
                  />
                ) : isDynamic ? (
                  <div className="flex flex-col gap-1 items-inherit">
                    <DynamicNineSliceCanvas
                      img={imgState.img}
                      slice={slice}
                      text={customText || s.text}
                      maxWidth={dynMaxWidth}
                      minWidth={dynMinWidth}
                      paddingX={dynPaddingX}
                      paddingY={dynPaddingY}
                      horizontalPriority={dynHorizontalPriority}
                      textColor={textColor}
                      fontSize={fontSize}
                      textAlign={textAlign}
                    />
                    <div className="flex items-center gap-1">
                      <span className="text-[7px] font-mono" style={{ color: "rgba(251,191,36,0.5)" }}>▸ compact</span>
                      <NineSliceCanvasCompact
                        img={imgState.img}
                        slice={slice}
                        text={customText || s.text}
                        maxWidth={dynMaxWidth}
                        minWidth={dynMinWidth}
                        paddingX={dynPaddingX}
                        paddingY={dynPaddingY}
                        horizontalPriority={dynHorizontalPriority}
                        textColor={textColor}
                        fontSize={fontSize}
                        textAlign={textAlign}
                      />
                    </div>
                  </div>
                ) : (
                  <NineSliceCanvas
                    img={imgState.img}
                    slice={slice}
                    text={customText || s.text}
                    maxWidth={s.maxWidth}
                    textColor={textColor}
                    fontSize={fontSize}
                    textAlign={textAlign}
                    padTop={padTop} padBottom={padBottom} padLeft={padLeft} padRight={padRight}
                  />
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ─── Bubbles Dashboard ────────────────────────────────────────────────────────
function BubblesDashboard() {
  const [bubbles, setBubbles] = useState<StoreItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [showForm, setShowForm] = useState(false);
  const [editingBubble, setEditingBubble] = useState<StoreItem | null>(null);
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [imageUrl, setImageUrl] = useState<string | null>(null);
  const [imageDimensions, setImageDimensions] = useState<{ w: number; h: number } | null>(null);
  const [isDragging, setIsDragging] = useState(false);
  const [previewTab, setPreviewTab] = useState<"slice" | "result">("slice");
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [form, setForm] = useState<BubbleForm>(EMPTY_FORM);

  // Mantém referência para revogar Object URLs ao trocar de imagem
  const objectUrlRef = useRef<string | null>(null);

  async function loadBubbles() {
    setLoading(true);
    const { data, error } = await supabase
      .from("store_items").select("*").eq("type", "chat_bubble").order("created_at", { ascending: false });
    if (!error && data) setBubbles(data as StoreItem[]);
    setLoading(false);
  }

  useEffect(() => { loadBubbles(); }, []);

  // Revoga Object URL ao desmontar o componente
  useEffect(() => {
    return () => {
      if (objectUrlRef.current) URL.revokeObjectURL(objectUrlRef.current);
    };
  }, []);

  const handleFile = useCallback((file: File) => {
    if (!file.type.startsWith("image/")) { toast.error("Selecione uma imagem."); return; }

    // Revoga o Object URL anterior para evitar memory leak
    if (objectUrlRef.current) {
      URL.revokeObjectURL(objectUrlRef.current);
      objectUrlRef.current = null;
    }

    setImageFile(file);
    setForm(f => ({ ...f, isAnimated: detectBubbleIsAnimated(file) }));

    const url = URL.createObjectURL(file);
    objectUrlRef.current = url;

    // Lê dimensões e define URL (o hook useImageLoader cuidará do carregamento)
    const img = new window.Image();
    img.onload = () => {
      setImageDimensions({ w: img.naturalWidth, h: img.naturalHeight });
      URL.revokeObjectURL(img.src); // revoga o blob temporário usado só para medir
    };
    img.src = URL.createObjectURL(file); // segundo blob apenas para medir
    setImageUrl(url);
  }, []);

  const onDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault(); setIsDragging(false);
    const file = e.dataTransfer.files[0];
    if (file) handleFile(file);
  }, [handleFile]);

  async function openEdit(item: StoreItem) {
    const cfg = parseBubbleConfig((item.asset_config as Record<string, unknown>) ?? {});
    setEditingBubble(item);
    setForm({
      name: item.name,
      description: item.description ?? "",
      priceCoins: item.price_coins,
      rarity: cfg.rarity,
      isActive: item.is_active,
      isAnimated: cfg.is_animated,
      textColor: cfg.text_color ?? "",
      sliceTop: cfg.slice_top, sliceBottom: cfg.slice_bottom,
      sliceLeft: cfg.slice_left, sliceRight: cfg.slice_right,
      fontSize: cfg.font_size,
      textAlign: cfg.text_align,
      padTop: cfg.pad_top, padBottom: cfg.pad_bottom,
      padLeft: cfg.pad_left, padRight: cfg.pad_right,
      usePolyFill: Array.isArray(cfg.poly_points) && cfg.poly_points.length === 8,
      polyPoints: Array.isArray(cfg.poly_points) && cfg.poly_points.length === 8
        ? cfg.poly_points
        : [],
      // Campos dinâmicos — lidos do asset_config se existirem
      isDynamic: cfg.mode === "dynamic_nineslice",
      dynMaxWidth:  cfg.content?.maxWidth  ?? DYNAMIC_CONTENT_DEFAULTS.maxWidth,
      dynMinWidth:  cfg.content?.minWidth  ?? DYNAMIC_CONTENT_DEFAULTS.minWidth,
      dynPaddingX:  cfg.content?.padding?.x ?? cfg.pad_left  ?? DYNAMIC_CONTENT_DEFAULTS.paddingX,
      dynPaddingY:  cfg.content?.padding?.y ?? cfg.pad_top   ?? DYNAMIC_CONTENT_DEFAULTS.paddingY,
      dynHorizontalPriority: cfg.behavior?.horizontalPriority ?? DYNAMIC_BEHAVIOR_DEFAULTS.horizontalPriority,
      dynTransitionZone:     cfg.behavior?.transitionZone     ?? DYNAMIC_BEHAVIOR_DEFAULTS.transitionZone,
      // Campos horizontal_stretch
      isHorizontalStretch: cfg.mode === "horizontal_stretch",
      hsMaxWidth: cfg.horizontal_stretch?.maxWidth ?? 280,
      hsMinWidth: cfg.horizontal_stretch?.minWidth ?? 60,
      hsPaddingX: cfg.horizontal_stretch?.paddingX ?? cfg.pad_left ?? 4,
      hsPaddingY: cfg.horizontal_stretch?.paddingY ?? cfg.pad_top ?? 4,
    });
    setImageUrl(item.preview_url);
    if (cfg.image_width && cfg.image_height) {
      setImageDimensions({ w: cfg.image_width, h: cfg.image_height });
    } else if (item.preview_url) {
      // Mede as dimensões reais da imagem quando não estão no asset_config
      const img = new window.Image();
      img.onload = () => setImageDimensions({ w: img.naturalWidth, h: img.naturalHeight });
      img.src = item.preview_url;
    } else {
      setImageDimensions(null);
    }
    setShowForm(true);
  }

  function cancelEdit() {
    setEditingBubble(null);
    setShowForm(false);
    setForm(EMPTY_FORM);
    setImageFile(null);
    setImageUrl(null);
    setImageDimensions(null);
    setPreviewTab("slice");
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!editingBubble && !imageFile) { toast.error("Selecione uma imagem para o bubble."); return; }
    if (!form.name.trim()) { toast.error("Defina um nome para o bubble."); return; }
    setSubmitting(true);
    try {
      let publicUrl = editingBubble?.preview_url ?? null;
      if (imageFile) {
        const ext = imageFile.name.split(".").pop() ?? "png";
        const slug = form.name.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "");
        const path = `bubbles/${slug}_${Date.now()}.${ext}`;
        const { error: uploadError } = await supabase.storage
          .from("store-assets").upload(path, imageFile, { contentType: imageFile.type, upsert: false });
        if (uploadError) throw new Error(`Upload falhou: ${uploadError.message}`);
        const { data: urlData } = supabase.storage.from("store-assets").getPublicUrl(path);
        publicUrl = urlData.publicUrl;
      }

      const imgW = imageDimensions?.w ?? 128;
      const imgH = imageDimensions?.h ?? 128;

      // Base do asset_config (campos comuns a todos os modos)
      const baseConfig = {
        bubble_style: (form.isAnimated ? "animated" : "nine_slice") as BubbleAssetConfig["bubble_style"],
        image_url: publicUrl,
        bubble_url: publicUrl,
        image_width: imgW,
        image_height: imgH,
        is_animated: form.isAnimated,
        rarity: form.rarity,
        slice_top: form.sliceTop, slice_bottom: form.sliceBottom,
        slice_left: form.sliceLeft, slice_right: form.sliceRight,
        ...(form.textColor.trim() ? { text_color: form.textColor.trim() } : {}),
        font_size: form.fontSize,
        text_align: form.textAlign,
        pad_top: form.padTop, pad_bottom: form.padBottom,
        pad_left: form.padLeft, pad_right: form.padRight,
        content_padding_h: Math.round((form.padLeft + form.padRight) / 2),
        content_padding_v: Math.round((form.padTop + form.padBottom) / 2),
        ...(form.usePolyFill && form.polyPoints.length === 8
          ? { poly_points: form.polyPoints }
          : {}),
      };
      // Se o modo dinâmico estiver ativo, serializa com os campos extras.
      // O cast `as BubbleAssetConfig` é seguro: serializeDynamicConfig sempre
      // inclui bubble_style (via base) e os campos obrigatórios do tipo local.
      const assetConfig = (form.isHorizontalStretch && !form.isAnimated
        ? {
            ...baseConfig,
            mode: "horizontal_stretch" as BubbleMode,
            horizontal_stretch: {
              maxWidth:  form.hsMaxWidth,
              minWidth:  form.hsMinWidth,
              paddingX:  form.hsPaddingX,
              paddingY:  form.hsPaddingY,
              stretchZoneMin: 4,
            },
          }
        : form.isDynamic && !form.isAnimated
          ? serializeDynamicConfig(
              baseConfig,
              { left: form.sliceLeft, right: form.sliceRight, top: form.sliceTop, bottom: form.sliceBottom },
              { paddingX: form.dynPaddingX, paddingY: form.dynPaddingY, maxWidth: form.dynMaxWidth, minWidth: form.dynMinWidth },
              { horizontalPriority: form.dynHorizontalPriority, maxHeightRatio: 0.6, transitionZone: form.dynTransitionZone },
            )
          : baseConfig) as BubbleAssetConfig;

      const payload = {
        type: "chat_bubble",
        name: form.name.trim(),
        description: form.description.trim() || null,
        preview_url: publicUrl,
        asset_url: publicUrl,
        asset_config: assetConfig,
        price_coins: form.priceCoins,
        price_real_cents: 0,
        is_premium_only: false,
        is_limited_edition: false,
        is_active: form.isActive,
        sort_order: 0,
      };

      if (editingBubble) {
        const { error } = await supabase.from("store_items").update(payload).eq("id", editingBubble.id);
        if (error) throw new Error(`DB error: ${error.message}`);
        toast.success(`"${form.name}" atualizado!`);
      } else {
        const { error } = await supabase.from("store_items").insert(payload);
        if (error) throw new Error(`DB error: ${error.message}`);
        toast.success(`"${form.name}" publicado na loja! 🎉`);
      }
      cancelEdit(); loadBubbles();
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : String(err));
    } finally { setSubmitting(false); }
  }

  async function toggleActive(item: StoreItem) {
    const { error } = await supabase.from("store_items").update({ is_active: !item.is_active }).eq("id", item.id);
    if (error) { toast.error("Erro ao atualizar status."); return; }
    setBubbles(prev => prev.map(b => b.id === item.id ? { ...b, is_active: !b.is_active } : b));
    toast.success(`"${item.name}" ${!item.is_active ? "ativado" : "desativado"}.`);
  }

  async function deleteBubble(item: StoreItem) {
    if (!confirm(`Deletar "${item.name}"? Esta ação não pode ser desfeita.`)) return;
    const { error } = await supabase.from("store_items").delete().eq("id", item.id);
    if (error) { toast.error("Erro ao deletar."); return; }
    setBubbles(prev => prev.filter(b => b.id !== item.id));
    toast.success(`"${item.name}" removido da loja.`);
  }

  const sliceValues: SliceValues = {
    top: form.sliceTop, bottom: form.sliceBottom,
    left: form.sliceLeft, right: form.sliceRight,
  };

  function handleSliceChange(s: SliceValues) {
    setForm(f => ({ ...f, sliceTop: s.top, sliceBottom: s.bottom, sliceLeft: s.left, sliceRight: s.right }));
  }

  return (
    <div className="p-4 md:p-6 max-w-7xl mx-auto space-y-5">
      {/* Header */}
      <motion.div variants={fadeUp} initial="hidden" animate="show" custom={0} className="flex items-center justify-between gap-3">
        <div>
          <h1 className="text-[20px] font-bold tracking-tight" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.95)" }}>
            Chat Bubbles
          </h1>
          <p className="text-[12px] font-mono mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>
            {bubbles.length} bubble{bubbles.length !== 1 ? "s" : ""} cadastrado{bubbles.length !== 1 ? "s" : ""}
          </p>
        </div>
        <div className="flex gap-2">
          <button onClick={loadBubbles} className="w-8 h-8 rounded-xl flex items-center justify-center transition-all duration-150"
            style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.4)" }}>
            <RefreshCw size={13} />
          </button>
          <button onClick={() => { cancelEdit(); setShowForm(true); }}
            className="flex items-center gap-2 px-4 py-2 rounded-xl text-[13px] font-semibold transition-all duration-150"
            style={{ background: "linear-gradient(135deg, rgba(124,58,237,0.8), rgba(236,72,153,0.6))", color: "white", fontFamily: "'Space Grotesk', sans-serif", boxShadow: "0 0 20px rgba(124,58,237,0.3)" }}>
            + Novo Bubble
          </button>
        </div>
      </motion.div>

      {/* Form Modal */}
      <AnimatePresence>
        {showForm && (
          <motion.div
            initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-start justify-center p-4 overflow-y-auto"
            style={{ background: "rgba(0,0,0,0.75)", backdropFilter: "blur(8px)" }}
            onClick={(e) => e.target === e.currentTarget && cancelEdit()}
          >
            <motion.div
              initial={{ opacity: 0, scale: 0.95, y: 20 }} animate={{ opacity: 1, scale: 1, y: 0 }} exit={{ opacity: 0, scale: 0.95, y: 20 }}
              className="w-full max-w-4xl rounded-2xl my-4"
              style={{ background: "rgba(13,17,23,0.98)", border: "1px solid rgba(255,255,255,0.1)", boxShadow: "0 40px 120px rgba(0,0,0,0.8)" }}
              onClick={(e) => e.stopPropagation()}
            >
              <div className="p-5 md:p-6">
                {/* Modal Header */}
                <div className="flex items-center justify-between mb-5">
                  <h2 className="text-[16px] font-bold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.95)" }}>
                    {editingBubble ? `Editar: ${editingBubble.name}` : "Novo Chat Bubble"}
                  </h2>
                  <button onClick={cancelEdit} className="w-7 h-7 rounded-lg flex items-center justify-center text-[18px] transition-all duration-150"
                    style={{ background: "rgba(255,255,255,0.05)", color: "rgba(255,255,255,0.4)" }}>×</button>
                </div>

                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                  {/* ── Coluna Esquerda: Formulário ── */}
                  <form onSubmit={handleSubmit} className="space-y-4">
                    {/* Upload */}
                    <div>
                      <label className="text-[10px] font-mono tracking-widest uppercase block mb-2" style={{ color: "rgba(255,255,255,0.3)" }}>Imagem</label>
                      <div
                        onDragOver={(e) => { e.preventDefault(); setIsDragging(true); }}
                        onDragLeave={() => setIsDragging(false)}
                        onDrop={onDrop}
                        onClick={() => fileInputRef.current?.click()}
                        className="cursor-pointer rounded-xl transition-all duration-200"
                        style={{ border: `1px dashed ${isDragging ? "rgba(124,58,237,0.6)" : "rgba(255,255,255,0.1)"}`, background: isDragging ? "rgba(124,58,237,0.05)" : "rgba(255,255,255,0.02)" }}
                      >
                        {imageUrl ? (
                          <div className="flex items-center gap-4 p-4">
                            <div className="w-14 h-14 rounded-xl overflow-hidden flex-shrink-0" style={{ background: "rgba(255,255,255,0.05)" }}>
                              <img src={imageUrl} alt="preview" className="w-full h-full object-contain" />
                            </div>
                            <div>
                              <p className="text-[12px] font-semibold" style={{ color: "rgba(255,255,255,0.8)", fontFamily: "'Space Grotesk', sans-serif" }}>
                                {imageFile?.name ?? "Imagem atual"}
                              </p>
                              {imageDimensions && (
                                <p className="text-[11px] font-mono mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>{imageDimensions.w}×{imageDimensions.h}px</p>
                              )}
                              <p className="text-[10px] font-mono mt-1" style={{ color: "rgba(124,58,237,0.7)" }}>Clique para trocar</p>
                            </div>
                          </div>
                        ) : (
                          <div className="py-7 text-center">
                            <Upload size={20} className="mx-auto mb-2" style={{ color: "rgba(255,255,255,0.2)" }} />
                            <p className="text-[12px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>Arraste ou clique para selecionar</p>
                            <p className="text-[10px] font-mono mt-1" style={{ color: "rgba(255,255,255,0.15)" }}>PNG · GIF · WebP · APNG</p>
                            <p className="text-[10px] font-mono mt-0.5" style={{ color: "rgba(124,58,237,0.5)" }}>Recomendado: 256×256px mín. · PNG/WebP · fundo transparente</p>
                          </div>
                        )}
                      </div>
                      <input ref={fileInputRef} type="file" accept="image/*" className="hidden"
                        onChange={(e) => { const f = e.target.files?.[0]; if (f) handleFile(f); }} />
                    </div>

                    {/* Nome + Preço */}
                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.3)" }}>Nome *</label>
                        <input value={form.name} onChange={(e) => setForm(f => ({ ...f, name: e.target.value }))} required placeholder="Ex: Bubble Neon"
                          className="w-full px-3 py-2 rounded-xl text-[13px] outline-none"
                          style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.85)", fontFamily: "'Space Grotesk', sans-serif" }} />
                      </div>
                      <div>
                        <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.3)" }}>Preço (coins)</label>
                        <input type="number" min={0} value={form.priceCoins} onChange={(e) => setForm(f => ({ ...f, priceCoins: parseInt(e.target.value) || 0 }))}
                          className="w-full px-3 py-2 rounded-xl text-[13px] outline-none font-mono"
                          style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "#F59E0B" }} />
                      </div>
                    </div>

                    {/* Descrição */}
                    <div>
                      <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.3)" }}>Descrição</label>
                      <input value={form.description} onChange={(e) => setForm(f => ({ ...f, description: e.target.value }))} placeholder="Descrição opcional"
                        className="w-full px-3 py-2 rounded-xl text-[13px] outline-none"
                        style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.7)", fontFamily: "'Space Grotesk', sans-serif" }} />
                    </div>

                    {/* Raridade */}
                    <div>
                      <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.3)" }}>Raridade</label>
                      <select value={form.rarity} onChange={(e) => setForm(f => ({ ...f, rarity: e.target.value as Rarity }))}
                        className="w-full px-3 py-2 rounded-xl text-[13px] outline-none"
                        style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: RARITY_COLORS[form.rarity].color, fontFamily: "'Space Mono', monospace" }}>
                        {(Object.entries(RARITY_LABELS) as [Rarity, string][]).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
                      </select>
                    </div>

                    {/* Cor do texto */}
                    <div>
                      <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.3)" }}>Cor do Texto do Balão</label>
                      <div className="flex items-center gap-2">
                        <input type="color" value={form.textColor || "#FFFFFF"} onChange={(e) => setForm(f => ({ ...f, textColor: e.target.value }))}
                          className="w-9 h-9 rounded-xl cursor-pointer flex-shrink-0 p-0.5"
                          style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.1)" }} />
                        <input value={form.textColor} onChange={(e) => setForm(f => ({ ...f, textColor: e.target.value }))} placeholder="#FFFFFF (vazio = padrão do app)"
                          className="flex-1 px-3 py-2 rounded-xl text-[13px] outline-none font-mono"
                          style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.7)" }} />
                        {form.textColor && (
                          <button type="button" onClick={() => setForm(f => ({ ...f, textColor: "" }))}
                            className="px-2 py-1.5 rounded-lg text-[10px] font-mono transition-all"
                            style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.4)" }}>
                            Limpar
                          </button>
                        )}
                      </div>
                    </div>

                    {/* Tipografia e Layout do Texto */}
                    {!form.isAnimated && (
                      <div className="space-y-3 rounded-xl p-3" style={{ background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.06)" }}>
                        <p className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.25)" }}>Tipografia e Posicionamento</p>

                        <div className="grid grid-cols-2 gap-3">
                          <div>
                            <label className="text-[9px] font-mono block mb-1" style={{ color: "rgba(255,255,255,0.3)" }}>Tamanho da Fonte (px)</label>
                            <input
                              type="number" min={8} max={32}
                              value={form.fontSize}
                              onChange={(e) => setForm(f => ({ ...f, fontSize: Math.max(8, Math.min(32, parseInt(e.target.value) || 13)) }))}
                              className="w-full px-2 py-1.5 rounded-lg text-[12px] outline-none font-mono text-center"
                              style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.1)", color: "rgba(255,255,255,0.8)" }}
                            />
                          </div>
                          <div>
                            <label className="text-[9px] font-mono block mb-1" style={{ color: "rgba(255,255,255,0.3)" }}>Alinhamento</label>
                            <div className="flex gap-1">
                              {(["left", "center", "right"] as const).map((align) => (
                                <button
                                  key={align} type="button"
                                  onClick={() => setForm(f => ({ ...f, textAlign: align }))}
                                  className="flex-1 py-1.5 rounded-lg text-[10px] font-mono transition-all"
                                  style={{
                                    background: form.textAlign === align ? "rgba(124,58,237,0.2)" : "rgba(255,255,255,0.04)",
                                    border: `1px solid ${form.textAlign === align ? "rgba(124,58,237,0.4)" : "rgba(255,255,255,0.08)"}`,
                                    color: form.textAlign === align ? "#A78BFA" : "rgba(255,255,255,0.4)",
                                  }}
                                >
                                  {align === "left" ? "←" : align === "center" ? "↔" : "→"}
                                </button>
                              ))}
                            </div>
                          </div>
                        </div>

                        <div>
                          <label className="text-[9px] font-mono block mb-1.5" style={{ color: "rgba(255,255,255,0.3)" }}>Padding Interno (px) — independente das bordas de slice</label>
                          <div className="grid grid-cols-4 gap-2">
                            {([
                              { label: "Topo",  key: "padTop"    as const, color: "#F59E0B" },
                              { label: "Base",  key: "padBottom" as const, color: "#F59E0B" },
                              { label: "Esq.",  key: "padLeft"   as const, color: "#34D399" },
                              { label: "Dir.",  key: "padRight"  as const, color: "#34D399" },
                            ]).map(({ label, key, color }) => (
                              <div key={key}>
                                <label className="text-[8px] font-mono block mb-0.5" style={{ color: "rgba(255,255,255,0.25)" }}>{label}</label>
                                <input
                                  type="number" min={0} max={60}
                                  value={form[key]}
                                  onChange={(e) => setForm(f => ({ ...f, [key]: Math.max(0, parseInt(e.target.value) || 0) }))}
                                  className="w-full px-1.5 py-1.5 rounded-lg text-[11px] outline-none font-mono text-center"
                                  style={{ background: "rgba(255,255,255,0.04)", border: `1px solid ${color}30`, color }}
                                />
                              </div>
                            ))}
                          </div>
                        </div>
                      </div>
                    )}


                    {/* ── Modo Dinâmico (dynamic_nineslice) ── */}
                    {!form.isAnimated && (
                      <div className="space-y-3 rounded-xl p-3" style={{ background: form.isDynamic ? "rgba(52,211,153,0.04)" : "rgba(255,255,255,0.02)", border: `1px solid ${form.isDynamic ? "rgba(52,211,153,0.2)" : "rgba(255,255,255,0.06)"}`, transition: "all 0.2s" }}>
                        {/* Toggle do modo */}
                        <div className="flex items-center justify-between">
                          <div>
                            <p className="text-[10px] font-mono tracking-widest uppercase" style={{ color: form.isDynamic ? "#34D399" : "rgba(255,255,255,0.25)" }}>
                              Modo Dinâmico
                            </p>
                            <p className="text-[9px] mt-0.5" style={{ color: "rgba(255,255,255,0.2)", fontFamily: "'Space Grotesk', sans-serif" }}>
                              {form.isDynamic ? "dynamic_nineslice — layout calculado pelo conteúdo" : "nine_slice clássico — comportamento padrão"}
                            </p>
                          </div>
                          <div
                            onClick={() => setForm(f => ({ ...f, isDynamic: !f.isDynamic, isHorizontalStretch: f.isDynamic ? f.isHorizontalStretch : false }))}
                            className="w-9 h-5 rounded-full relative transition-all duration-200 flex-shrink-0 cursor-pointer"
                            style={{ background: form.isDynamic ? "#34D399" : "rgba(255,255,255,0.1)" }}
                          >
                            <div className="absolute top-0.5 w-4 h-4 rounded-full bg-white shadow transition-all duration-200"
                              style={{ left: form.isDynamic ? "calc(100% - 18px)" : "2px" }} />
                          </div>
                        </div>
                        {/* Controles dinâmicos — só visíveis quando ativo */}
                        {form.isDynamic && (
                          <div className="space-y-3 pt-1">
                            {/* Largura */}
                            <div className="grid grid-cols-2 gap-2">
                              <div>
                                <label className="text-[9px] font-mono block mb-1" style={{ color: "rgba(255,255,255,0.3)" }}>Largura Máx. (px)</label>
                                <input
                                  type="number" min={80} max={400}
                                  value={form.dynMaxWidth}
                                  onChange={(e) => setForm(f => ({ ...f, dynMaxWidth: Math.max(80, parseInt(e.target.value) || 260) }))}
                                  className="w-full px-2 py-1.5 rounded-lg text-[12px] outline-none font-mono text-center"
                                  style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(52,211,153,0.2)", color: "#34D399" }}
                                />
                              </div>
                              <div>
                                <label className="text-[9px] font-mono block mb-1" style={{ color: "rgba(255,255,255,0.3)" }}>Largura Mín. (px)</label>
                                <input
                                  type="number" min={40} max={200}
                                  value={form.dynMinWidth}
                                  onChange={(e) => setForm(f => ({ ...f, dynMinWidth: Math.max(40, parseInt(e.target.value) || 60) }))}
                                  className="w-full px-2 py-1.5 rounded-lg text-[12px] outline-none font-mono text-center"
                                  style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(52,211,153,0.2)", color: "#34D399" }}
                                />
                              </div>
                            </div>
                            {/* Padding dinâmico */}
                            <div className="grid grid-cols-2 gap-2">
                              <div>
                                <label className="text-[9px] font-mono block mb-1" style={{ color: "rgba(255,255,255,0.3)" }}>Padding X (px)</label>
                                <input
                                  type="number" min={0} max={60}
                                  value={form.dynPaddingX}
                                  onChange={(e) => setForm(f => ({ ...f, dynPaddingX: Math.max(0, parseInt(e.target.value) || 16) }))}
                                  className="w-full px-2 py-1.5 rounded-lg text-[12px] outline-none font-mono text-center"
                                  style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(52,211,153,0.15)", color: "rgba(255,255,255,0.7)" }}
                                />
                              </div>
                              <div>
                                <label className="text-[9px] font-mono block mb-1" style={{ color: "rgba(255,255,255,0.3)" }}>Padding Y (px)</label>
                                <input
                                  type="number" min={0} max={60}
                                  value={form.dynPaddingY}
                                  onChange={(e) => setForm(f => ({ ...f, dynPaddingY: Math.max(0, parseInt(e.target.value) || 12) }))}
                                  className="w-full px-2 py-1.5 rounded-lg text-[12px] outline-none font-mono text-center"
                                  style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(52,211,153,0.15)", color: "rgba(255,255,255,0.7)" }}
                                />
                              </div>
                            </div>
                            {/* Intensidade da transição */}
                            <div>
                              <div className="flex items-center justify-between mb-1">
                                <label className="text-[9px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>
                                  Intensidade da Transição
                                </label>
                                <span className="text-[9px] font-mono" style={{ color: "#A78BFA" }}>
                                  {Math.round(form.dynTransitionZone * 100)}%
                                </span>
                              </div>
                              <input
                                type="range" min={0} max={40} step={1}
                                value={Math.round(form.dynTransitionZone * 100)}
                                onChange={(e) => setForm(f => ({ ...f, dynTransitionZone: parseInt(e.target.value) / 100 }))}
                                className="w-full h-1.5 rounded-full appearance-none cursor-pointer"
                                style={{ accentColor: "#A78BFA" }}
                              />
                              <div className="flex justify-between mt-0.5">
                                <span className="text-[8px] font-mono" style={{ color: "rgba(255,255,255,0.2)" }}>Nenhuma</span>
                                <span className="text-[8px] font-mono" style={{ color: "rgba(255,255,255,0.2)" }}>Máxima</span>
                              </div>
                            </div>
                            {/* Toggle prioridade */}
                            <label className="flex items-center gap-3 cursor-pointer p-2.5 rounded-xl"
                              style={{ background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.06)" }}>
                              <div
                                onClick={() => setForm(f => ({ ...f, dynHorizontalPriority: !f.dynHorizontalPriority }))}
                                className="w-9 h-5 rounded-full relative transition-all duration-200 flex-shrink-0"
                                style={{ background: form.dynHorizontalPriority ? "#34D399" : "rgba(255,255,255,0.1)", cursor: "pointer" }}
                              >
                                <div className="absolute top-0.5 w-4 h-4 rounded-full bg-white shadow transition-all duration-200"
                                  style={{ left: form.dynHorizontalPriority ? "calc(100% - 18px)" : "2px" }} />
                              </div>
                              <div>
                                <span className="text-[11px] font-mono block" style={{ color: "rgba(255,255,255,0.6)" }}>
                                  {form.dynHorizontalPriority ? "\u2194 Prioridade: Largura" : "\u2195 Prioridade: Altura"}
                                </span>
                                <span className="text-[9px]" style={{ color: "rgba(255,255,255,0.25)", fontFamily: "'Space Grotesk', sans-serif" }}>
                                  {form.dynHorizontalPriority ? "Expande horizontalmente antes de quebrar linha" : "Quebra linha mais cedo, cresce verticalmente"}
                                </span>
                              </div>
                            </label>
                          </div>
                        )}
                      </div>
                    )}
                    {/* ── Modo Horizontal Stretch ── */}
                    {!form.isAnimated && (
                      <div className="space-y-3 rounded-xl p-3" style={{ background: form.isHorizontalStretch ? "rgba(251,191,36,0.04)" : "rgba(255,255,255,0.02)", border: `1px solid ${form.isHorizontalStretch ? "rgba(251,191,36,0.2)" : "rgba(255,255,255,0.06)"}`, transition: "all 0.2s" }}>
                        <div className="flex items-center justify-between">
                          <div>
                            <p className="text-[10px] font-mono tracking-widest uppercase" style={{ color: form.isHorizontalStretch ? "#FBBF24" : "rgba(255,255,255,0.25)" }}>
                              Horizontal Stretch
                            </p>
                            <p className="text-[9px] mt-0.5" style={{ color: "rgba(255,255,255,0.2)", fontFamily: "'Space Grotesk', sans-serif" }}>
                              {form.isHorizontalStretch ? "horizontal_stretch — só o centro estica, bordas fixas" : "ativar para assets com decoração nas bordas"}
                            </p>
                          </div>
                          <div
                            onClick={() => setForm(f => ({ ...f, isHorizontalStretch: !f.isHorizontalStretch, isDynamic: f.isHorizontalStretch ? f.isDynamic : false }))}
                            className="w-9 h-5 rounded-full relative transition-all duration-200 flex-shrink-0 cursor-pointer"
                            style={{ background: form.isHorizontalStretch ? "#FBBF24" : "rgba(255,255,255,0.1)" }}
                          >
                            <div className="absolute top-0.5 w-4 h-4 rounded-full bg-white shadow transition-all duration-200"
                              style={{ left: form.isHorizontalStretch ? "calc(100% - 18px)" : "2px" }} />
                          </div>
                        </div>
                        {form.isHorizontalStretch && (
                          <div className="space-y-3 pt-1">
                            <div className="grid grid-cols-2 gap-2">
                              <div>
                                <label className="text-[9px] font-mono block mb-1" style={{ color: "rgba(255,255,255,0.3)" }}>Largura Máx. (px)</label>
                                <input
                                  type="number" min={80} max={500}
                                  value={form.hsMaxWidth}
                                  onChange={(e) => setForm(f => ({ ...f, hsMaxWidth: Math.max(80, parseInt(e.target.value) || 280) }))}
                                  className="w-full px-2 py-1.5 rounded-lg text-[12px] outline-none font-mono text-center"
                                  style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(251,191,36,0.2)", color: "#FBBF24" }}
                                />
                              </div>
                              <div>
                                <label className="text-[9px] font-mono block mb-1" style={{ color: "rgba(255,255,255,0.3)" }}>Largura Mín. (px)</label>
                                <input
                                  type="number" min={40} max={200}
                                  value={form.hsMinWidth}
                                  onChange={(e) => setForm(f => ({ ...f, hsMinWidth: Math.max(40, parseInt(e.target.value) || 60) }))}
                                  className="w-full px-2 py-1.5 rounded-lg text-[12px] outline-none font-mono text-center"
                                  style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(251,191,36,0.2)", color: "#FBBF24" }}
                                />
                              </div>
                            </div>
                            <div className="grid grid-cols-2 gap-2">
                              <div>
                                <label className="text-[9px] font-mono block mb-1" style={{ color: "rgba(255,255,255,0.3)" }}>Padding X (px)</label>
                                <input
                                  type="number" min={0} max={40}
                                  value={form.hsPaddingX}
                                  onChange={(e) => setForm(f => ({ ...f, hsPaddingX: Math.max(0, parseInt(e.target.value) || 4) }))}
                                  className="w-full px-2 py-1.5 rounded-lg text-[12px] outline-none font-mono text-center"
                                  style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(251,191,36,0.15)", color: "rgba(255,255,255,0.7)" }}
                                />
                              </div>
                              <div>
                                <label className="text-[9px] font-mono block mb-1" style={{ color: "rgba(255,255,255,0.3)" }}>Padding Y (px)</label>
                                <input
                                  type="number" min={0} max={40}
                                  value={form.hsPaddingY}
                                  onChange={(e) => setForm(f => ({ ...f, hsPaddingY: Math.max(0, parseInt(e.target.value) || 4) }))}
                                  className="w-full px-2 py-1.5 rounded-lg text-[12px] outline-none font-mono text-center"
                                  style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(251,191,36,0.15)", color: "rgba(255,255,255,0.7)" }}
                                />
                              </div>
                            </div>
                            <p className="text-[8px]" style={{ color: "rgba(251,191,36,0.5)", fontFamily: "'Space Grotesk', sans-serif" }}>
                              ⚠ Configure os slices (esq/dir) para cobrir toda a decoração lateral. Só a faixa central (4px) vai esticar.
                            </p>
                          </div>
                        )}
                      </div>
                    )}

                    {/* Toggles */}
                    <div className="flex flex-col sm:flex-row gap-3">
                      {([
                        { label: "Bubble Animado (GIF/APNG)", key: "isAnimated" as const, color: "#A78BFA" },
                        { label: "Ativo na Loja",              key: "isActive"   as const, color: "#34D399" },
                      ]).map(({ label, key, color }) => (
                        <label key={key} className="flex items-center gap-3 cursor-pointer flex-1 p-3 rounded-xl"
                          style={{ background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.06)" }}>
                          <div
                            onClick={() => setForm(f => ({ ...f, [key]: !f[key] }))}
                            className="w-9 h-5 rounded-full relative transition-all duration-200 flex-shrink-0"
                            style={{ background: form[key] ? color : "rgba(255,255,255,0.1)", cursor: "pointer" }}
                          >
                            <div className="absolute top-0.5 w-4 h-4 rounded-full bg-white shadow transition-all duration-200"
                              style={{ left: form[key] ? "calc(100% - 18px)" : "2px" }} />
                          </div>
                          <span className="text-[12px] font-mono" style={{ color: "rgba(255,255,255,0.5)" }}>{label}</span>
                        </label>
                      ))}
                    </div>

                    {/* Actions */}
                    <div className="flex gap-3 pt-1">
                      <button type="button" onClick={cancelEdit}
                        className="flex-1 py-2.5 rounded-xl text-[13px] font-semibold transition-all duration-150"
                        style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.5)", fontFamily: "'Space Grotesk', sans-serif" }}>
                        Cancelar
                      </button>
                      <button type="submit" disabled={submitting}
                        className="flex-1 py-2.5 rounded-xl text-[13px] font-bold flex items-center justify-center gap-2 transition-all duration-150"
                        style={{ background: submitting ? "rgba(124,58,237,0.4)" : "linear-gradient(135deg, #7C3AED, #EC4899)", color: "white", fontFamily: "'Space Grotesk', sans-serif", boxShadow: submitting ? "none" : "0 0 20px rgba(124,58,237,0.3)" }}>
                        {submitting ? <Loader2 size={13} className="animate-spin" /> : null}
                        {submitting ? "Salvando..." : editingBubble ? "Salvar" : "Publicar"}
                      </button>
                    </div>
                  </form>

                  {/* ── Coluna Direita: Visualizador Nine-Slice ── */}
                  <div className="space-y-4">
                    {/* Tabs */}
                    <div className="flex gap-2">
                      <button onClick={() => setPreviewTab("slice")}
                        className="flex-1 py-2 rounded-xl text-[12px] font-semibold transition-all"
                        style={{
                          background: previewTab === "slice" ? "rgba(124,58,237,0.15)" : "rgba(255,255,255,0.03)",
                          border: `1px solid ${previewTab === "slice" ? "rgba(124,58,237,0.3)" : "rgba(255,255,255,0.07)"}`,
                          color: previewTab === "slice" ? "#A78BFA" : "rgba(255,255,255,0.35)",
                          fontFamily: "'Space Grotesk', sans-serif",
                        }}>
                        Ajustar Bordas
                      </button>
                      <button onClick={() => setPreviewTab("result")}
                        className="flex-1 py-2 rounded-xl text-[12px] font-semibold transition-all"
                        style={{
                          background: previewTab === "result" ? "rgba(52,211,153,0.12)" : "rgba(255,255,255,0.03)",
                          border: `1px solid ${previewTab === "result" ? "rgba(52,211,153,0.25)" : "rgba(255,255,255,0.07)"}`,
                          color: previewTab === "result" ? "#34D399" : "rgba(255,255,255,0.35)",
                          fontFamily: "'Space Grotesk', sans-serif",
                        }}>
                        Preview Final
                      </button>
                      {!form.isAnimated && (
                        <button onClick={() => setPreviewTab("poly" as "slice")}
                          className="flex-1 py-2 rounded-xl text-[12px] font-semibold transition-all"
                          style={{
                            background: previewTab === ("poly" as string) ? "rgba(167,139,250,0.15)" : "rgba(255,255,255,0.03)",
                            border: `1px solid ${previewTab === ("poly" as string) ? "rgba(167,139,250,0.3)" : "rgba(255,255,255,0.07)"}`,
                            color: previewTab === ("poly" as string) ? "#A78BFA" : "rgba(255,255,255,0.35)",
                            fontFamily: "'Space Grotesk', sans-serif",
                          }}>
                          {form.usePolyFill ? "✦ Polígono" : "Polígono"}
                        </button>
                      )}
                      {/* Aba Zonas removida: quando isDynamic=true, o DynamicNineSliceOverlay
                           já aparece diretamente na aba Ajustar Bordas. */}
                    </div>

                    {imageUrl ? (
                      <>
                        {previewTab === "slice" && !form.isAnimated && !form.isDynamic && !form.isHorizontalStretch && (
                          // Modo clássico: editor de bordas com overlay de escurecimento
                          <NineSliceEditor
                            imageUrl={imageUrl}
                            imageDimensions={imageDimensions}
                            slice={sliceValues}
                            onChange={handleSliceChange}
                            textColor={form.textColor}
                            fontSize={form.fontSize}
                            textAlign={form.textAlign}
                            padTop={form.padTop} padBottom={form.padBottom}
                            padLeft={form.padLeft} padRight={form.padRight}
                            isDynamic={false}
                            dynMaxWidth={form.dynMaxWidth}
                            dynMinWidth={form.dynMinWidth}
                            dynPaddingX={form.dynPaddingX}
                            dynPaddingY={form.dynPaddingY}
                            dynHorizontalPriority={form.dynHorizontalPriority}
                            dynTransitionZone={form.dynTransitionZone}
                            onTransitionChange={(t) => setForm(f => ({ ...f, dynTransitionZone: t }))}
                            isHorizontalStretch={false}
                            hsMaxWidth={form.hsMaxWidth}
                            hsMinWidth={form.hsMinWidth}
                            hsPaddingX={form.hsPaddingX}
                            hsPaddingY={form.hsPaddingY}
                          />
                        )}
                        {previewTab === "slice" && !form.isAnimated && form.isDynamic && (
                          // Modo dinâmico: overlay de zonas + preview de texto na mesma aba
                          <div className="space-y-3">
                            <DynamicNineSliceOverlay
                              imageUrl={imageUrl}
                              imageDimensions={imageDimensions}
                              slice={sliceValues}
                              transitionZone={form.dynTransitionZone}
                              onSliceChange={handleSliceChange}
                              onTransitionChange={(t) => setForm(f => ({ ...f, dynTransitionZone: t }))}
                            />
                            <NineSlicePreviewPanel
                              imageUrl={imageUrl}
                              slice={sliceValues}
                              textColor={form.textColor}
                              fontSize={form.fontSize}
                              textAlign={form.textAlign}
                              padTop={form.padTop} padBottom={form.padBottom}
                              padLeft={form.padLeft} padRight={form.padRight}
                              isDynamic={true}
                              dynMaxWidth={form.dynMaxWidth}
                              dynMinWidth={form.dynMinWidth}
                              dynPaddingX={form.dynPaddingX}
                              dynPaddingY={form.dynPaddingY}
                              dynHorizontalPriority={form.dynHorizontalPriority}
                              dynTransitionZone={form.dynTransitionZone}
                              isHorizontalStretch={false}
                              hsMaxWidth={form.hsMaxWidth}
                              hsMinWidth={form.hsMinWidth}
                              hsPaddingX={form.hsPaddingX}
                              hsPaddingY={form.hsPaddingY}
                            />
                          </div>
                        )}
                        {previewTab === "slice" && !form.isAnimated && form.isHorizontalStretch && (
                          // Modo horizontal_stretch: editor dedicado — só linhas verticais (L e R)
                          <div className="space-y-3">
                            <HorizontalStretchEditor
                              imageUrl={imageUrl}
                              imageDimensions={imageDimensions}
                              slice={sliceValues}
                              onChange={handleSliceChange}
                              textColor={form.textColor}
                              fontSize={form.fontSize}
                              padTop={form.padTop} padBottom={form.padBottom}
                              padLeft={form.padLeft} padRight={form.padRight}
                              hsMaxWidth={form.hsMaxWidth}
                              hsMinWidth={form.hsMinWidth}
                              hsPaddingX={form.hsPaddingX}
                              hsPaddingY={form.hsPaddingY}
                            />
                            {/* Preview de texto em tempo real com o modo horizontal_stretch */}
                            <NineSlicePreviewPanel
                              imageUrl={imageUrl}
                              slice={sliceValues}
                              textColor={form.textColor}
                              fontSize={form.fontSize}
                              textAlign={form.textAlign}
                              padTop={form.padTop} padBottom={form.padBottom}
                              padLeft={form.padLeft} padRight={form.padRight}
                              isDynamic={false}
                              dynMaxWidth={form.dynMaxWidth}
                              dynMinWidth={form.dynMinWidth}
                              dynPaddingX={form.dynPaddingX}
                              dynPaddingY={form.dynPaddingY}
                              dynHorizontalPriority={form.dynHorizontalPriority}
                              dynTransitionZone={form.dynTransitionZone}
                              isHorizontalStretch={true}
                              hsMaxWidth={form.hsMaxWidth}
                              hsMinWidth={form.hsMinWidth}
                              hsPaddingX={form.hsPaddingX}
                              hsPaddingY={form.hsPaddingY}
                            />
                          </div>
                        )}

                        {previewTab === ("poly" as string) && !form.isAnimated && (
                          <div className="space-y-3">
                            {/* Toggle de ativação */}
                            <label className="flex items-center gap-3 cursor-pointer p-3 rounded-xl"
                              style={{ background: form.usePolyFill ? "rgba(167,139,250,0.08)" : "rgba(255,255,255,0.02)", border: `1px solid ${form.usePolyFill ? "rgba(167,139,250,0.25)" : "rgba(255,255,255,0.06)"}` }}>
                              <div
                                onClick={() => setForm(f => ({ ...f, usePolyFill: !f.usePolyFill }))}
                                className="w-9 h-5 rounded-full relative transition-all duration-200 flex-shrink-0"
                                style={{ background: form.usePolyFill ? "#A78BFA" : "rgba(255,255,255,0.1)", cursor: "pointer" }}
                              >
                                <div className="absolute top-0.5 w-4 h-4 rounded-full bg-white shadow transition-all duration-200"
                                  style={{ left: form.usePolyFill ? "calc(100% - 18px)" : "2px" }} />
                              </div>
                              <div>
                                <span className="text-[12px] font-mono block" style={{ color: form.usePolyFill ? "#A78BFA" : "rgba(255,255,255,0.5)" }}>
                                  Área de Texto Poligonal
                                </span>
                                <span className="text-[10px]" style={{ color: "rgba(255,255,255,0.25)", fontFamily: "'Space Grotesk', sans-serif" }}>
                                  {form.usePolyFill ? "Ativo — poly_points será salvo no asset_config" : "Inativo — usa padding normal (slice + pad)"}
                                </span>
                              </div>
                            </label>
                            {/* Editor poligonal */}
                            {imageUrl && (
                              <PolyFillEditor
                                imageUrl={imageUrl}
                                imageDimensions={imageDimensions}
                                points={form.polyPoints}
                                onChange={(pts) => setForm(f => ({ ...f, polyPoints: pts, usePolyFill: true }))}
                                sliceValues={sliceValues}
                                padTop={form.padTop} padBottom={form.padBottom}
                                padLeft={form.padLeft} padRight={form.padRight}
                              />
                            )}
                          </div>
                        )}
                        {previewTab === ("zones" as string) && !form.isAnimated && form.isDynamic && (
                          <DynamicNineSliceOverlay
                            imageUrl={imageUrl}
                            imageDimensions={imageDimensions}
                            slice={sliceValues}
                            transitionZone={form.dynTransitionZone}
                            onSliceChange={handleSliceChange}
                            onTransitionChange={(t) => setForm(f => ({ ...f, dynTransitionZone: t }))}
                          />
                        )}
                        {previewTab === "slice" && form.isAnimated && (
                          <div className="rounded-xl p-4 text-center space-y-2"
                            style={{ background: "rgba(167,139,250,0.06)", border: "1px solid rgba(167,139,250,0.15)" }}>
                            <p className="text-[12px] font-mono" style={{ color: "#A78BFA" }}>Bubble animado (GIF/APNG)</p>
                            <p className="text-[11px]" style={{ color: "rgba(255,255,255,0.4)", fontFamily: "'Space Grotesk', sans-serif" }}>
                              Bubbles animados não usam nine-slice. O ajuste de bordas não se aplica.
                            </p>
                            <img src={imageUrl} alt="animated" className="mx-auto max-h-32 rounded-lg object-contain" />
                          </div>
                        )}

                        {previewTab === "result" && (
                          <div className="space-y-2">
                            <p className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.3)" }}>Como ficará no chat</p>
                            <div className="rounded-xl overflow-hidden" style={{ background: "rgba(0,0,0,0.3)", border: "1px solid rgba(255,255,255,0.07)" }}>
                              {form.isAnimated ? (
                                <ChatPreview imageUrl={imageUrl} name={form.name || "Bubble"} cfg={{
                                  slice_top: form.sliceTop, slice_bottom: form.sliceBottom,
                                  slice_left: form.sliceLeft, slice_right: form.sliceRight,
                                  font_size: form.fontSize, text_color: form.textColor,
                                  pad_top: form.padTop, pad_bottom: form.padBottom,
                                  pad_left: form.padLeft, pad_right: form.padRight,
                                }} />
                              ) : (
                                <NineSlicePreviewPanel
                                  imageUrl={imageUrl}
                                  slice={sliceValues}
                                  textColor={form.textColor}
                                  fontSize={form.fontSize}
                                  textAlign={form.textAlign}
                                  padTop={form.padTop} padBottom={form.padBottom}
                                  padLeft={form.padLeft} padRight={form.padRight}
                                  isDynamic={form.isDynamic}
                                  dynMaxWidth={form.dynMaxWidth}
                                  dynMinWidth={form.dynMinWidth}
                                  dynPaddingX={form.dynPaddingX}
                                  dynPaddingY={form.dynPaddingY}
                                  dynHorizontalPriority={form.dynHorizontalPriority}
                                  dynTransitionZone={form.dynTransitionZone}
                                  isHorizontalStretch={form.isHorizontalStretch}
                                  hsMaxWidth={form.hsMaxWidth}
                                  hsMinWidth={form.hsMinWidth}
                                  hsPaddingX={form.hsPaddingX}
                                  hsPaddingY={form.hsPaddingY}
                                />
                              )}
                            </div>
                            {/* Resumo dos valores de slice */}
                            {!form.isAnimated && (
                              <div className="grid grid-cols-4 gap-1.5 mt-2">
                                {([
                                  { label: "T", value: form.sliceTop,    color: "#F59E0B" },
                                  { label: "B", value: form.sliceBottom, color: "#F59E0B" },
                                  { label: "L", value: form.sliceLeft,   color: "#34D399" },
                                  { label: "R", value: form.sliceRight,  color: "#34D399" },
                                ]).map(({ label, value, color }) => (
                                  <div key={label} className="rounded-lg px-2 py-1.5 text-center"
                                    style={{ background: `${color}10`, border: `1px solid ${color}20` }}>
                                    <p className="text-[9px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>{label}</p>
                                    <p className="text-[13px] font-mono font-bold" style={{ color }}>{value}</p>
                                  </div>
                                ))}
                              </div>
                            )}
                          </div>
                        )}
                      </>
                    ) : (
                      <div className="rounded-xl p-8 text-center"
                        style={{ background: "rgba(255,255,255,0.02)", border: "1px dashed rgba(255,255,255,0.07)" }}>
                        <div className="text-3xl mb-2">💬</div>
                        <p className="text-[12px] font-mono" style={{ color: "rgba(255,255,255,0.25)" }}>
                          Selecione uma imagem para<br />visualizar o nine-slice
                        </p>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Bubbles Grid */}
      {loading ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {[...Array(6)].map((_, i) => <div key={i} className="h-52 rounded-2xl" style={{ background: "rgba(255,255,255,0.03)" }} />)}
        </div>
      ) : bubbles.length === 0 ? (
        <motion.div variants={fadeUp} initial="hidden" animate="show" custom={1}
          className="py-16 text-center rounded-2xl"
          style={{ background: "rgba(255,255,255,0.02)", border: "1px dashed rgba(255,255,255,0.08)" }}
        >
          <div className="text-3xl mb-3">💬</div>
          <p className="text-[13px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>Nenhum bubble cadastrado ainda</p>
          <button onClick={() => setShowForm(true)} className="mt-4 px-4 py-2 rounded-xl text-[12px] font-semibold"
            style={{ background: "rgba(124,58,237,0.1)", border: "1px solid rgba(124,58,237,0.2)", color: "#A78BFA", fontFamily: "'Space Grotesk', sans-serif" }}>
            Criar primeiro bubble
          </button>
        </motion.div>
      ) : (
        <motion.div variants={fadeUp} initial="hidden" animate="show" custom={1} className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {bubbles.map((bubble, i) => {
            const cfg = parseBubbleConfig((bubble.asset_config as Record<string, unknown>) ?? {});
            const rc = RARITY_COLORS[cfg.rarity];
            return (
              <motion.div key={bubble.id} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.04 }}
                className="rounded-2xl overflow-hidden"
                style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}
              >
                <div className="relative" style={{ background: "rgba(0,0,0,0.3)", borderBottom: "1px solid rgba(255,255,255,0.05)" }}>
                  <ChatPreview imageUrl={bubble.preview_url} name={bubble.name} cfg={cfg} />
                  <div className="absolute top-2 right-2">
                    <span className="text-[9px] font-mono px-2 py-0.5 rounded-full"
                      style={{ background: `rgba(${rc.rgb},0.12)`, color: rc.color, border: `1px solid rgba(${rc.rgb},0.25)` }}>
                      {RARITY_LABELS[cfg.rarity]}
                    </span>
                  </div>
                </div>
                <div className="p-3">
                  <div className="flex items-start justify-between gap-2 mb-2">
                    <div className="min-w-0">
                      <h3 className="text-[13px] font-semibold truncate" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.9)" }}>{bubble.name}</h3>
                      {bubble.description && <p className="text-[11px] font-mono truncate mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>{bubble.description}</p>}
                    </div>
                    <span className="text-[12px] font-mono font-bold flex-shrink-0" style={{ color: "#F59E0B" }}>{bubble.price_coins} ✦</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <button onClick={() => toggleActive(bubble)}
                      className="flex items-center gap-1 text-[10px] font-mono px-2 py-1 rounded-lg transition-all duration-150"
                      style={{ background: bubble.is_active ? "rgba(52,211,153,0.1)" : "rgba(239,68,68,0.1)", color: bubble.is_active ? "#34D399" : "#FCA5A5", border: `1px solid ${bubble.is_active ? "rgba(52,211,153,0.2)" : "rgba(239,68,68,0.2)"}` }}>
                      {bubble.is_active ? <CheckCircle2 size={9} /> : <AlertCircle size={9} />}
                      {bubble.is_active ? "Ativo" : "Inativo"}
                    </button>
                    <div className="flex gap-1">
                      <button onClick={() => openEdit(bubble)} className="w-7 h-7 rounded-lg flex items-center justify-center transition-all duration-150"
                        style={{ background: "rgba(255,255,255,0.04)", color: "rgba(255,255,255,0.3)" }}
                        onMouseEnter={e => { e.currentTarget.style.background = "rgba(124,58,237,0.15)"; e.currentTarget.style.color = "#A78BFA"; }}
                        onMouseLeave={e => { e.currentTarget.style.background = "rgba(255,255,255,0.04)"; e.currentTarget.style.color = "rgba(255,255,255,0.3)"; }}>
                        <Pencil size={11} />
                      </button>
                      <button onClick={() => deleteBubble(bubble)} className="w-7 h-7 rounded-lg flex items-center justify-center transition-all duration-150"
                        style={{ background: "rgba(255,255,255,0.04)", color: "rgba(255,255,255,0.3)" }}
                        onMouseEnter={e => { e.currentTarget.style.background = "rgba(239,68,68,0.15)"; e.currentTarget.style.color = "#FCA5A5"; }}
                        onMouseLeave={e => { e.currentTarget.style.background = "rgba(255,255,255,0.04)"; e.currentTarget.style.color = "rgba(255,255,255,0.3)"; }}>
                        <Trash2 size={11} />
                      </button>
                    </div>
                  </div>
                </div>
              </motion.div>
            );
          })}
        </motion.div>
      )}
    </div>
  );
}

// ─── Dashboard Principal ──────────────────────────────────────────────────────
export default function Dashboard() {
  const [activeSection, setActiveSection] = useState<AdminSection>("overview");

  function renderSection() {
    switch (activeSection) {
      case "overview":       return <OverviewPage />;
      case "store-items":    return <StoreItemsPage />;
      case "bubbles":        return <BubblesDashboard />;
      case "frames":         return <FramesDashboard />;
      case "stickers":       return <StickersPage />;
      case "themes":         return <ThemesDashboard />;
      case "users":          return <UsersPage />;
      case "moderation":     return <ModerationPage />;
      case "communities":    return <CommunitiesPage />;
      case "achievements":   return <AchievementsPage />;
      case "broadcast":      return <BroadcastPage />;
      case "transactions":   return <TransactionsPage />;
      case "settings":       return <SettingsPage />;
      default:               return <OverviewPage />;
    }
  }

  return (
    <AdminLayout activeSection={activeSection} onSectionChange={setActiveSection}>
      {renderSection()}
    </AdminLayout>
  );
}
