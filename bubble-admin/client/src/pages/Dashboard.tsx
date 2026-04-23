import { useState, useRef, useCallback, useEffect } from "react";
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

// ─── Tipos ────────────────────────────────────────────────────────────────────
type BubbleForm = {
  name: string; description: string; priceCoins: number;
  rarity: "common" | "rare" | "epic" | "legendary";
  isActive: boolean; isAnimated: boolean;
  sliceTop: number; sliceLeft: number; sliceRight: number; sliceBottom: number;
  textColor: string;
};

function detectBubbleIsAnimated(file: File): boolean {
  const ext = file.name.split(".").pop()?.toLowerCase() ?? "";
  if (file.type === "image/gif" || ext === "gif") return true;
  if (ext === "apng") return true;
  return false;
}

const RARITY_COLORS: Record<string, { color: string; rgb: string }> = {
  common:    { color: "#94A3B8", rgb: "148,163,184" },
  rare:      { color: "#60A5FA", rgb: "96,165,250" },
  epic:      { color: "#A78BFA", rgb: "167,139,250" },
  legendary: { color: "#FBBF24", rgb: "251,191,36" },
};

const RARITY_LABELS: Record<string, string> = {
  common: "Comum", rare: "Raro", epic: "Épico", legendary: "Lendário",
};

const fadeUp = {
  hidden: { opacity: 0, y: 10 },
  show: (i: number) => ({ opacity: 1, y: 0, transition: { delay: i * 0.04, duration: 0.25, ease: "easeOut" } }),
};

// ─── Chat Preview (cards da lista) ───────────────────────────────────────────
function ChatPreview({ imageUrl, name }: { imageUrl: string | null; name: string }) {
  const messages = [
    { id: 1, mine: false, text: "Que bubble incrível 👀" },
    { id: 2, mine: true, text: name || "Novo bubble" },
    { id: 3, mine: false, text: "Adorei! Quanto custa?" },
    { id: 4, mine: true, text: "Tá na loja! 🎉" },
  ];
  return (
    <div className="flex flex-col gap-2 p-4">
      {messages.map((msg) => (
        <div key={msg.id} className={`flex ${msg.mine ? "justify-end" : "justify-start"}`}>
          {imageUrl ? (
            <div
              className="relative max-w-[180px] px-4 py-2.5 text-[13px]"
              style={{
                backgroundImage: `url(${imageUrl})`,
                backgroundRepeat: "no-repeat",
                backgroundSize: "100% 100%",
                borderImageSource: `url(${imageUrl})`,
                borderImageSlice: "38 fill",
                borderImageWidth: "38px",
                borderImageRepeat: "stretch",
                minHeight: "40px",
                color: "rgba(255,255,255,0.9)",
                fontFamily: "'Space Grotesk', sans-serif",
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

// ─── Nine-Slice Editor ────────────────────────────────────────────────────────
// Visualizador interativo: 4 linhas arrastáveis sobre a imagem + preview em tempo real

type SliceValues = { top: number; left: number; right: number; bottom: number };
type DragHandle = "top" | "left" | "right" | "bottom" | null;

function NineSliceEditor({
  imageUrl,
  imageDimensions,
  slice,
  onChange,
  textColor,
}: {
  imageUrl: string;
  imageDimensions: { w: number; h: number } | null;
  slice: SliceValues;
  onChange: (s: SliceValues) => void;
  textColor: string;
}) {
  const canvasRef = useRef<HTMLDivElement>(null);
  const [canvasSize, setCanvasSize] = useState({ w: 240, h: 240 });
  const [dragging, setDragging] = useState<DragHandle>(null);
  const [hovering, setHovering] = useState<DragHandle>(null);
  const dragStart = useRef<{ x: number; y: number; value: number } | null>(null);

  // Atualiza tamanho do canvas ao montar e ao redimensionar
  useEffect(() => {
    function update() {
      if (!canvasRef.current) return;
      const rect = canvasRef.current.getBoundingClientRect();
      setCanvasSize({ w: rect.width, h: rect.height });
    }
    update();
    const ro = new ResizeObserver(update);
    if (canvasRef.current) ro.observe(canvasRef.current);
    return () => ro.disconnect();
  }, []);

  // Dimensões reais da imagem (para calcular proporção)
  const imgW = imageDimensions?.w ?? 128;
  const imgH = imageDimensions?.h ?? 128;

  // Posição das linhas em pixels no canvas (proporcional)
  const scaleX = canvasSize.w / imgW;
  const scaleY = canvasSize.h / imgH;

  // Posição das linhas em px no canvas
  const topPx    = slice.top    * scaleY;
  const bottomPx = canvasSize.h - slice.bottom * scaleY;
  const leftPx   = slice.left   * scaleX;
  const rightPx  = canvasSize.w - slice.right  * scaleX;

  // Área de hit das linhas (px de tolerância)
  const HIT = 8;

  function getHandleAt(x: number, y: number): DragHandle {
    if (Math.abs(y - topPx)    < HIT) return "top";
    if (Math.abs(y - bottomPx) < HIT) return "bottom";
    if (Math.abs(x - leftPx)   < HIT) return "left";
    if (Math.abs(x - rightPx)  < HIT) return "right";
    return null;
  }

  function onMouseDown(e: React.MouseEvent) {
    const rect = canvasRef.current!.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    const handle = getHandleAt(x, y);
    if (!handle) return;
    e.preventDefault();
    setDragging(handle);
    const currentVal = handle === "top" ? slice.top : handle === "bottom" ? slice.bottom : handle === "left" ? slice.left : slice.right;
    dragStart.current = { x, y, value: currentVal };
  }

  function onMouseMove(e: React.MouseEvent) {
    const rect = canvasRef.current!.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;

    if (!dragging || !dragStart.current) {
      setHovering(getHandleAt(x, y));
      return;
    }

    const dx = x - dragStart.current.x;
    const dy = y - dragStart.current.y;

    let newVal: number;
    if (dragging === "top") {
      newVal = Math.max(0, Math.min(Math.round(dragStart.current.value + dy / scaleY), imgH - slice.bottom - 4));
      onChange({ ...slice, top: newVal });
    } else if (dragging === "bottom") {
      newVal = Math.max(0, Math.min(Math.round(dragStart.current.value - dy / scaleY), imgH - slice.top - 4));
      onChange({ ...slice, bottom: newVal });
    } else if (dragging === "left") {
      newVal = Math.max(0, Math.min(Math.round(dragStart.current.value + dx / scaleX), imgW - slice.right - 4));
      onChange({ ...slice, left: newVal });
    } else {
      newVal = Math.max(0, Math.min(Math.round(dragStart.current.value - dx / scaleX), imgW - slice.left - 4));
      onChange({ ...slice, right: newVal });
    }
  }

  function onMouseUp() {
    setDragging(null);
    dragStart.current = null;
  }

  // Cursor dinâmico
  const cursor = dragging
    ? (dragging === "top" || dragging === "bottom" ? "ns-resize" : "ew-resize")
    : hovering
    ? (hovering === "top" || hovering === "bottom" ? "ns-resize" : "ew-resize")
    : "default";

  // Cores das linhas
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

  // Labels das regiões nine-slice
  const regions = [
    // Cantos
    { label: "TL", x: leftPx / 2, y: topPx / 2 },
    { label: "TR", x: (rightPx + canvasSize.w) / 2, y: topPx / 2 },
    { label: "BL", x: leftPx / 2, y: (bottomPx + canvasSize.h) / 2 },
    { label: "BR", x: (rightPx + canvasSize.w) / 2, y: (bottomPx + canvasSize.h) / 2 },
    // Bordas
    { label: "T", x: (leftPx + rightPx) / 2, y: topPx / 2 },
    { label: "B", x: (leftPx + rightPx) / 2, y: (bottomPx + canvasSize.h) / 2 },
    { label: "L", x: leftPx / 2, y: (topPx + bottomPx) / 2 },
    { label: "R", x: (rightPx + canvasSize.w) / 2, y: (topPx + bottomPx) / 2 },
    // Centro
    { label: "FILL", x: (leftPx + rightPx) / 2, y: (topPx + bottomPx) / 2 },
  ];

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

      {/* Canvas */}
      <div
        ref={canvasRef}
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
          style={{
            position: "absolute", inset: 0,
            width: "100%", height: "100%",
            objectFit: "fill",
            pointerEvents: "none",
            userSelect: "none",
          }}
        />

        {/* Overlay escurecido nas regiões de borda (para destacar o centro) */}
        <div style={{ position: "absolute", inset: 0, pointerEvents: "none" }}>
          {/* Topo */}
          <div style={{ position: "absolute", left: 0, right: 0, top: 0, height: topPx, background: "rgba(0,0,0,0.25)" }} />
          {/* Base */}
          <div style={{ position: "absolute", left: 0, right: 0, bottom: 0, height: canvasSize.h - bottomPx, background: "rgba(0,0,0,0.25)" }} />
          {/* Esquerda (centro) */}
          <div style={{ position: "absolute", left: 0, width: leftPx, top: topPx, height: bottomPx - topPx, background: "rgba(0,0,0,0.25)" }} />
          {/* Direita (centro) */}
          <div style={{ position: "absolute", right: 0, width: canvasSize.w - rightPx, top: topPx, height: bottomPx - topPx, background: "rgba(0,0,0,0.25)" }} />
        </div>

        {/* Linha Topo */}
        <div style={{ ...lineStyle("top", true), top: topPx - 0.75 }}>
          <div style={{
            position: "absolute", right: 4, top: -9,
            fontSize: 9, fontFamily: "'DM Mono', monospace",
            color: "#F59E0B", background: "rgba(0,0,0,0.7)",
            padding: "1px 4px", borderRadius: 4, whiteSpace: "nowrap",
          }}>
            T: {slice.top}px
          </div>
        </div>

        {/* Linha Base */}
        <div style={{ ...lineStyle("bottom", true), top: bottomPx - 0.75 }}>
          <div style={{
            position: "absolute", right: 4, bottom: -9,
            fontSize: 9, fontFamily: "'DM Mono', monospace",
            color: "#F59E0B", background: "rgba(0,0,0,0.7)",
            padding: "1px 4px", borderRadius: 4, whiteSpace: "nowrap",
          }}>
            B: {slice.bottom}px
          </div>
        </div>

        {/* Linha Esquerda */}
        <div style={{ ...lineStyle("left", false), left: leftPx - 0.75 }}>
          <div style={{
            position: "absolute", left: 4, top: 4,
            fontSize: 9, fontFamily: "'DM Mono', monospace",
            color: "#34D399", background: "rgba(0,0,0,0.7)",
            padding: "1px 4px", borderRadius: 4, whiteSpace: "nowrap",
            writingMode: "vertical-rl", transform: "rotate(180deg)",
          }}>
            L: {slice.left}px
          </div>
        </div>

        {/* Linha Direita */}
        <div style={{ ...lineStyle("right", false), left: rightPx - 0.75 }}>
          <div style={{
            position: "absolute", right: 4, top: 4,
            fontSize: 9, fontFamily: "'DM Mono', monospace",
            color: "#34D399", background: "rgba(0,0,0,0.7)",
            padding: "1px 4px", borderRadius: 4, whiteSpace: "nowrap",
            writingMode: "vertical-rl",
          }}>
            R: {slice.right}px
          </div>
        </div>

        {/* Labels das regiões */}
        {regions.map(({ label, x, y }) => (
          <div key={label} style={{
            position: "absolute",
            left: x, top: y,
            transform: "translate(-50%, -50%)",
            fontSize: 8, fontFamily: "'DM Mono', monospace",
            color: "rgba(255,255,255,0.35)",
            background: "rgba(0,0,0,0.5)",
            padding: "1px 3px", borderRadius: 3,
            pointerEvents: "none",
            whiteSpace: "nowrap",
          }}>
            {label}
          </div>
        ))}
      </div>

      {/* Texto de exemplo em tempo real sobre a área FILL */}
      <div className="rounded-xl overflow-hidden" style={{ background: "rgba(0,0,0,0.25)", border: "1px solid rgba(255,255,255,0.06)" }}>
        <p className="text-[9px] font-mono px-3 pt-2 pb-1" style={{ color: "rgba(255,255,255,0.25)" }}>TEXTO DE EXEMPLO (tempo real)</p>
        <div className="flex flex-col gap-2 px-3 pb-3">
          {[
            { text: "Oi!", mine: true },
            { text: "Esse bubble ficou incrível 🔥", mine: false },
          ].map((msg, i) => (
            <div key={i} className={`flex ${msg.mine ? "justify-end" : "justify-start"}`}>
              <NineSliceBubble
                imageUrl={imageUrl}
                slice={slice}
                textColor={textColor}
                text={msg.text}
                maxWidth={msg.mine ? 100 : 200}
              />
            </div>
          ))}
        </div>
      </div>

      {/* Inputs numéricos sincronizados */}
      <div className="grid grid-cols-4 gap-2">
        {([
          { label: "Topo", key: "top" as const, color: "#F59E0B" },
          { label: "Base", key: "bottom" as const, color: "#F59E0B" },
          { label: "Esq.", key: "left" as const, color: "#34D399" },
          { label: "Dir.", key: "right" as const, color: "#34D399" },
        ] as const).map(({ label, key, color }) => (
          <div key={key}>
            <label className="text-[9px] font-mono block mb-1" style={{ color: "rgba(255,255,255,0.3)" }}>{label}</label>
            <input
              type="number" min={0}
              value={slice[key]}
              onChange={(e) => onChange({ ...slice, [key]: Math.max(0, parseInt(e.target.value) || 0) })}
              className="w-full px-2 py-1.5 rounded-lg text-[12px] outline-none font-mono text-center"
              style={{
                background: "rgba(255,255,255,0.04)",
                border: `1px solid ${color}30`,
                color,
              }}
            />
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Nine-Slice Chat Preview (resultado final) ────────────────────────────────
// Usa canvas para renderizar o nine-slice corretamente com o texto dentro da área central
// A imagem é carregada UMA VEZ e cacheada — redesenha instantaneamente ao mudar slice/texto
function NineSliceBubble({
  imageUrl,
  slice,
  textColor,
  text,
  maxWidth = 220,
}: {
  imageUrl: string;
  slice: SliceValues;
  textColor: string;
  text: string;
  maxWidth?: number;
}) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [size, setSize] = useState({ w: maxWidth, h: 60 });
  // Cache da imagem carregada — evita recarregar a cada mudança de slice
  const imgCacheRef = useRef<HTMLImageElement | null>(null);
  const [imgReady, setImgReady] = useState(false);
  const msgColor = textColor.trim() ? textColor : "rgba(255,255,255,0.9)";

  // Carrega a imagem apenas quando a URL muda
  useEffect(() => {
    setImgReady(false);
    imgCacheRef.current = null;
    const img = new window.Image();
    img.crossOrigin = "anonymous";
    img.onload = () => {
      imgCacheRef.current = img;
      setImgReady(true);
    };
    img.onerror = () => {
      // Tenta sem crossOrigin (para URLs de blob local)
      const img2 = new window.Image();
      img2.onload = () => { imgCacheRef.current = img2; setImgReady(true); };
      img2.src = imageUrl;
    };
    img.src = imageUrl;
  }, [imageUrl]);

  // Redesenha o canvas sempre que a imagem estiver pronta ou slice/texto mudar
  useEffect(() => {
    if (!imgReady || !imgCacheRef.current) return;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const img = imgCacheRef.current;
    const fontSize = 13;
    const lineHeight = 18;
    const padH = Math.max(slice.left, 12) + 8;
    const padV = Math.max(slice.top, 8) + 4;
    const contentW = maxWidth - padH * 2;

    // Quebra o texto em linhas
    ctx.font = `${fontSize}px 'Space Grotesk', sans-serif`;
    const words = text.split(" ");
    const lines: string[] = [];
    let cur = "";
    for (const w of words) {
      const test = cur ? `${cur} ${w}` : w;
      if (ctx.measureText(test).width > contentW && cur) {
        lines.push(cur);
        cur = w;
      } else {
        cur = test;
      }
    }
    if (cur) lines.push(cur);

    const textH = lines.length * lineHeight;
    const totalH = Math.max(textH + padV * 2, slice.top + slice.bottom + 8);
    const totalW = maxWidth;

    canvas.width = totalW;
    canvas.height = totalH;
    setSize({ w: totalW, h: totalH });

    // Desenha nine-slice
    const iw = img.naturalWidth;
    const ih = img.naturalHeight;
    const sl = slice.left, sr = slice.right, st = slice.top, sb = slice.bottom;
    const mw = totalW - sl - sr;
    const mh = totalH - st - sb;

    // 9 regiões: [srcX, srcY, srcW, srcH, dstX, dstY, dstW, dstH]
    const regions = [
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

    ctx.clearRect(0, 0, totalW, totalH);
    for (const [sx, sy, sw, sh, dx, dy, dw, dh] of regions) {
      if (sw > 0 && sh > 0 && dw > 0 && dh > 0) {
        ctx.drawImage(img, sx, sy, sw, sh, dx, dy, dw, dh);
      }
    }

    // Desenha o texto dentro da área central
    ctx.fillStyle = msgColor;
    ctx.font = `${fontSize}px 'Space Grotesk', sans-serif`;
    ctx.textBaseline = "top";
    lines.forEach((line, i) => {
      ctx.fillText(line, padH, padV + i * lineHeight);
    });
  }, [imgReady, slice, textColor, text, maxWidth, msgColor]);

  return (
    <canvas
      ref={canvasRef}
      width={size.w}
      height={size.h}
      style={{ display: "block", maxWidth: "100%" }}
    />
  );
}

function NineSliceChatPreview({
  imageUrl,
  slice,
  textColor,
}: {
  imageUrl: string;
  slice: SliceValues;
  textColor: string;
}) {
  const messages = [
    { id: 1, mine: true,  text: "Oi!" },
    { id: 2, mine: false, text: "Olá! Tudo bem?" },
    { id: 3, mine: true,  text: "Sim! Esse bubble ficou incrível 🔥" },
    { id: 4, mine: false, text: "Concordo! Muito estiloso mesmo, adorei o design!" },
  ];

  return (
    <div className="flex flex-col gap-3 p-3"
      style={{ background: "rgba(0,0,0,0.2)", borderRadius: 12 }}>
      {messages.map((msg) => (
        <div key={msg.id} className={`flex ${msg.mine ? "justify-end" : "justify-start"}`}>
          <NineSliceBubble
            imageUrl={imageUrl}
            slice={slice}
            textColor={textColor}
            text={msg.text}
            maxWidth={msg.text.length > 20 ? 220 : 140}
          />
        </div>
      ))}
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
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [imageDimensions, setImageDimensions] = useState<{ w: number; h: number } | null>(null);
  const [isDragging, setIsDragging] = useState(false);
  const [previewTab, setPreviewTab] = useState<"slice" | "result">("slice");
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [form, setForm] = useState<BubbleForm>({
    name: "", description: "", priceCoins: 150, rarity: "common",
    isActive: true, isAnimated: false,
    sliceTop: 38, sliceLeft: 38, sliceRight: 38, sliceBottom: 38, textColor: "",
  });

  async function loadBubbles() {
    setLoading(true);
    const { data, error } = await supabase
      .from("store_items").select("*").eq("type", "chat_bubble").order("created_at", { ascending: false });
    if (!error && data) setBubbles(data as StoreItem[]);
    setLoading(false);
  }

  useEffect(() => { loadBubbles(); }, []);

  const handleFile = useCallback((file: File) => {
    if (!file.type.startsWith("image/")) { toast.error("Selecione uma imagem."); return; }
    setImageFile(file);
    const url = URL.createObjectURL(file);
    setImagePreview(url);
    const img = new Image();
    img.onload = () => setImageDimensions({ w: img.naturalWidth, h: img.naturalHeight });
    img.src = url;
    const isAnim = detectBubbleIsAnimated(file);
    setForm(f => ({ ...f, isAnimated: isAnim }));
  }, []);

  const onDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault(); setIsDragging(false);
    const file = e.dataTransfer.files[0];
    if (file) handleFile(file);
  }, [handleFile]);

  function openEdit(item: StoreItem) {
    const cfg = (item.asset_config as Record<string, unknown>) ?? {};
    setEditingBubble(item);
    setForm({
      name: item.name, description: item.description ?? "",
      priceCoins: item.price_coins, rarity: (cfg.rarity as BubbleForm["rarity"]) ?? "common",
      isActive: item.is_active, isAnimated: (cfg.is_animated as boolean) ?? false,
      sliceTop: (cfg.slice_top as number) ?? 38, sliceLeft: (cfg.slice_left as number) ?? 38,
      sliceRight: (cfg.slice_right as number) ?? 38, sliceBottom: (cfg.slice_bottom as number) ?? 38,
      textColor: (cfg.text_color as string) ?? "",
    });
    setImagePreview(item.preview_url);
    setShowForm(true);
  }

  function cancelEdit() {
    setEditingBubble(null); setShowForm(false);
    setForm({ name: "", description: "", priceCoins: 150, rarity: "common", isActive: true, isAnimated: false, sliceTop: 38, sliceLeft: 38, sliceRight: 38, sliceBottom: 38, textColor: "" });
    setImageFile(null); setImagePreview(null); setImageDimensions(null);
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
        const { error: uploadError } = await supabase.storage.from("store-assets").upload(path, imageFile, { contentType: imageFile.type, upsert: false });
        if (uploadError) throw new Error(`Upload falhou: ${uploadError.message}`);
        const { data: urlData } = supabase.storage.from("store-assets").getPublicUrl(path);
        publicUrl = urlData.publicUrl;
      }
      const imgW = imageDimensions?.w ?? 128;
      const imgH = imageDimensions?.h ?? 128;
      const assetConfig = form.isAnimated
        ? { image_url: publicUrl, bubble_url: publicUrl, bubble_style: "animated", image_width: imgW, image_height: imgH, content_padding_h: 20, content_padding_v: 14, is_animated: true, rarity: form.rarity, ...(form.textColor.trim() ? { text_color: form.textColor.trim() } : {}) }
        : { image_url: publicUrl, bubble_url: publicUrl, bubble_style: "nine_slice", image_width: imgW, image_height: imgH, slice_top: form.sliceTop, slice_left: form.sliceLeft, slice_right: form.sliceRight, slice_bottom: form.sliceBottom, content_padding_h: 20, content_padding_v: 14, is_animated: false, rarity: form.rarity, ...(form.textColor.trim() ? { text_color: form.textColor.trim() } : {}) };
      const payload = { type: "chat_bubble", name: form.name.trim(), description: form.description.trim() || null, preview_url: publicUrl, asset_url: publicUrl, asset_config: assetConfig, price_coins: form.priceCoins, price_real_cents: 0, is_premium_only: false, is_limited_edition: false, is_active: form.isActive, sort_order: 0 };
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
    top: form.sliceTop, left: form.sliceLeft,
    right: form.sliceRight, bottom: form.sliceBottom,
  };

  function handleSliceChange(s: SliceValues) {
    setForm(f => ({ ...f, sliceTop: s.top, sliceLeft: s.left, sliceRight: s.right, sliceBottom: s.bottom }));
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

                {/* Layout: formulário à esquerda, visualizador à direita */}
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
                        {imagePreview ? (
                          <div className="flex items-center gap-4 p-4">
                            <div className="w-14 h-14 rounded-xl overflow-hidden flex-shrink-0" style={{ background: "rgba(255,255,255,0.05)" }}>
                              <img src={imagePreview} alt="preview" className="w-full h-full object-contain" />
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
                          </div>
                        )}
                      </div>
                      <input ref={fileInputRef} type="file" accept="image/*" className="hidden" onChange={(e) => { const f = e.target.files?.[0]; if (f) handleFile(f); }} />
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
                      <select value={form.rarity} onChange={(e) => setForm(f => ({ ...f, rarity: e.target.value as BubbleForm["rarity"] }))}
                        className="w-full px-3 py-2 rounded-xl text-[13px] outline-none"
                        style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: RARITY_COLORS[form.rarity]?.color ?? "white", fontFamily: "'Space Mono', monospace" }}>
                        {Object.entries(RARITY_LABELS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
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

                    {/* Toggles */}
                    <div className="flex flex-col sm:flex-row gap-3">
                      {[
                        { label: "Bubble Animado (GIF/APNG)", key: "isAnimated", color: "#A78BFA" },
                        { label: "Ativo na Loja", key: "isActive", color: "#34D399" },
                      ].map(({ label, key, color }) => (
                        <label key={key} className="flex items-center gap-3 cursor-pointer flex-1 p-3 rounded-xl"
                          style={{ background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.06)" }}>
                          <div
                            onClick={() => setForm(f => ({ ...f, [key]: !(f as any)[key] }))}
                            className="w-9 h-5 rounded-full relative transition-all duration-200 flex-shrink-0"
                            style={{ background: (form as any)[key] ? color : "rgba(255,255,255,0.1)", cursor: "pointer" }}
                          >
                            <div className="absolute top-0.5 w-4 h-4 rounded-full bg-white shadow transition-all duration-200"
                              style={{ left: (form as any)[key] ? "calc(100% - 18px)" : "2px" }} />
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
                    {/* Tabs do visualizador */}
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
                    </div>

                    {imagePreview ? (
                      <>
                        {previewTab === "slice" && !form.isAnimated && (
                          <NineSliceEditor
                            imageUrl={imagePreview}
                            imageDimensions={imageDimensions}
                            slice={sliceValues}
                            onChange={handleSliceChange}
                            textColor={form.textColor}
                          />
                        )}

                        {previewTab === "slice" && form.isAnimated && (
                          <div className="rounded-xl p-4 text-center space-y-2"
                            style={{ background: "rgba(167,139,250,0.06)", border: "1px solid rgba(167,139,250,0.15)" }}>
                            <p className="text-[12px] font-mono" style={{ color: "#A78BFA" }}>Bubble animado (GIF/APNG)</p>
                            <p className="text-[11px]" style={{ color: "rgba(255,255,255,0.4)", fontFamily: "'Space Grotesk', sans-serif" }}>
                              Bubbles animados não usam nine-slice. O ajuste de bordas não se aplica.
                            </p>
                            <img src={imagePreview} alt="animated" className="mx-auto max-h-32 rounded-lg object-contain" />
                          </div>
                        )}

                        {previewTab === "result" && (
                          <div className="space-y-2">
                            <p className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.3)" }}>
                              Como ficará no chat
                            </p>
                            <div className="rounded-xl overflow-hidden" style={{ background: "rgba(0,0,0,0.3)", border: "1px solid rgba(255,255,255,0.07)" }}>
                              {form.isAnimated ? (
                                <ChatPreview imageUrl={imagePreview} name={form.name || "Bubble"} />
                              ) : (
                                <NineSliceChatPreview
                                  imageUrl={imagePreview}
                                  slice={sliceValues}
                                  textColor={form.textColor}
                                />
                              )}
                            </div>
                            {/* Resumo dos valores */}
                            {!form.isAnimated && (
                              <div className="grid grid-cols-4 gap-1.5 mt-2">
                                {[
                                  { label: "T", value: form.sliceTop, color: "#F59E0B" },
                                  { label: "B", value: form.sliceBottom, color: "#F59E0B" },
                                  { label: "L", value: form.sliceLeft, color: "#34D399" },
                                  { label: "R", value: form.sliceRight, color: "#34D399" },
                                ].map(({ label, value, color }) => (
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
          {[...Array(6)].map((_, i) => <div key={i} className="h-52 rounded-2xl nx-shimmer" style={{ background: "rgba(255,255,255,0.03)" }} />)}
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
            const rarity = (bubble.asset_config as Record<string, string>)?.rarity ?? "common";
            const rc = RARITY_COLORS[rarity] ?? RARITY_COLORS.common;
            return (
              <motion.div key={bubble.id} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.04 }}
                className="rounded-2xl overflow-hidden"
                style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}
              >
                {/* Preview */}
                <div className="relative" style={{ background: "rgba(0,0,0,0.3)", borderBottom: "1px solid rgba(255,255,255,0.05)" }}>
                  <ChatPreview imageUrl={bubble.preview_url} name={bubble.name} />
                  <div className="absolute top-2 right-2">
                    <span className="text-[9px] font-mono px-2 py-0.5 rounded-full"
                      style={{ background: `rgba(${rc.rgb},0.12)`, color: rc.color, border: `1px solid rgba(${rc.rgb},0.25)` }}>
                      {RARITY_LABELS[rarity] ?? rarity}
                    </span>
                  </div>
                </div>
                {/* Info */}
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
