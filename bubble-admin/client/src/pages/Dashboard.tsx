import { useState, useEffect, useRef, useCallback, useMemo } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { supabase, StoreItem } from "@/lib/supabase";
import { toast } from "sonner";
import { Upload, Trash2, AlertCircle, CheckCircle2, Loader2, RefreshCw, Pencil, Move } from "lucide-react";
import AdminLayout, { AdminSection } from "@/components/AdminLayout";
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
import BroadcastPage from "./BroadcastPage";

// ─── Tipos e Constantes ───────────────────────────────────────────────────────

type Rarity = "common" | "rare" | "epic" | "legendary";
type TextAlign = "left" | "center" | "right";

/** Ponto normalizado (0–1) para o polígono de fill */
interface PolyPoint { x: number; y: number; }

/** Configuração tipada do asset_config para bubbles */
interface BubbleAssetConfig {
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
}

const EMPTY_FORM: BubbleForm = {
  name: "", description: "", priceCoins: 150, rarity: "common",
  isActive: true, isAnimated: false, textColor: "",
  sliceTop: 38, sliceBottom: 38, sliceLeft: 38, sliceRight: 38,
  fontSize: 13, textAlign: "left",
  padTop: 8, padBottom: 8, padLeft: 8, padRight: 8,
  usePolyFill: false,
  polyPoints: [],
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

// ─── NineSliceCanvas ──────────────────────────────────────────────────────────
// Renderiza um balao nine-slice via canvas com suporte a High-DPI (Retina).
// Recebe a imagem ja carregada (HTMLImageElement) para evitar recarregamentos.
// Usa canvas temporario para medicao de texto — evita re-render durante draw.

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
  padTop = 8, padBottom = 8, padLeft = 8, padRight = 8,
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
    const maxContentW = Math.max(1, maxWidth - innerLeft - innerRight);

    // Usa canvas temporario para medir texto sem causar re-render
    const measureCtx = document.createElement("canvas").getContext("2d")!;
    measureCtx.font = `${fontSize}px 'Space Grotesk', sans-serif`;

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

    const maxLineW = Math.max(...lines.map(l => measureCtx.measureText(l).width));
    const logW = Math.min(maxWidth, Math.max(
      Math.ceil(maxLineW) + innerLeft + innerRight,
      sl + sr + 24
    ));
    const textH = lines.length * lineHeight;
    const logH = Math.max(textH + innerTop + innerBot, st + sb + 8);

    // Redimensiona canvas (isso limpa o conteudo — intencional)
    canvas.width  = Math.round(logW * dpr);
    canvas.height = Math.round(logH * dpr);
    canvas.style.width  = logW + "px";
    canvas.style.height = logH + "px";
    ctx.scale(dpr, dpr);

    // Desenha nine-slice (9 regioes)
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

    // Texto centralizado verticalmente na area de conteudo (entre innerTop e logH-innerBot)
    const contentH = logH - innerTop - innerBot;
    const textStartY = innerTop + Math.max(0, (contentH - textH) / 2);
    const fillW = logW - innerLeft - innerRight;

    ctx.fillStyle = msgColor;
    ctx.font = `${fontSize}px 'Space Grotesk', sans-serif`;
    ctx.textBaseline = "top";
    ctx.textAlign = textAlign;

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
}

function NineSliceEditor({
  imageUrl, imageDimensions, slice, onChange,
  textColor, fontSize, textAlign,
  padTop, padBottom, padLeft, padRight,
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

    const dx = x - dragStart.current.x;
    const dy = y - dragStart.current.y;

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
          <div style={{ position: "absolute", left: 0, right: 0, top: 0, height: topPx, background: "rgba(0,0,0,0.25)" }} />
          <div style={{ position: "absolute", left: 0, right: 0, bottom: 0, height: canvasSize.h - bottomPx, background: "rgba(0,0,0,0.25)" }} />
          <div style={{ position: "absolute", left: 0, width: leftPx, top: topPx, height: bottomPx - topPx, background: "rgba(0,0,0,0.25)" }} />
          <div style={{ position: "absolute", right: 0, width: canvasSize.w - rightPx, top: topPx, height: bottomPx - topPx, background: "rgba(0,0,0,0.25)" }} />
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

      {/* Preview de texto em tempo real */}
      <NineSlicePreviewPanel
        imageUrl={imageUrl}
        slice={slice}
        textColor={textColor}
        fontSize={fontSize}
        textAlign={textAlign}
        padTop={padTop} padBottom={padBottom} padLeft={padLeft} padRight={padRight}
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
}

const PREVIEW_SAMPLES = [
  { id: "short",  label: "Curto",  text: "Oi!",                                        maxWidth: 140, mine: true  },
  { id: "medium", label: "Médio",  text: "Esse bubble ficou incrível 🔥",               maxWidth: 200, mine: false },
  { id: "long",   label: "Longo",  text: "Concordo! Muito estiloso mesmo, adorei o design!", maxWidth: 260, mine: true  },
];

function NineSlicePreviewPanel({
  imageUrl, slice, textColor, fontSize, textAlign,
  padTop, padBottom, padLeft, padRight,
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
      {imgState.status === "ready" && (
        <div className="flex flex-col gap-2 pt-1">
          {PREVIEW_SAMPLES.map((s) => (
            <div key={s.id} className="flex items-center gap-2">
              <span className="text-[8px] font-mono w-10 flex-shrink-0 text-right" style={{ color: "rgba(255,255,255,0.2)" }}>{s.label}</span>
              <div className={`flex flex-1 ${s.mine ? "justify-end" : "justify-start"}`}>
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
    });
    setImageUrl(item.preview_url);
    setImageDimensions(cfg.image_width && cfg.image_height ? { w: cfg.image_width, h: cfg.image_height } : null);
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

      const assetConfig: BubbleAssetConfig = {
        bubble_style: form.isAnimated ? "animated" : "nine_slice",
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
        // Campos de compatibilidade com o app Flutter (EdgeInsets.symmetric)
        content_padding_h: Math.round((form.padLeft + form.padRight) / 2),
        content_padding_v: Math.round((form.padTop + form.padBottom) / 2),
        // Polígono opcional — só salvo quando o admin ativou o modo poligonal
        ...(form.usePolyFill && form.polyPoints.length === 8
          ? { poly_points: form.polyPoints }
          : {}),
      };

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
                    </div>

                    {imageUrl ? (
                      <>
                        {previewTab === "slice" && !form.isAnimated && (
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
                          />
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
