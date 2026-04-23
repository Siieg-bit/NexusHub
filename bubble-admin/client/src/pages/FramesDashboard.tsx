/**
 * FramesDashboard — Gerenciamento de Molduras de Perfil
 * Dark #111214, surface #1C1E22, accent rosa #E040FB
 * DM Sans (títulos) + DM Mono (labels técnicos)
 *
 * Fluxo:
 *  1. Upload PNG/GIF/WebP animado da moldura
 *  2. Detecção automática de animação
 *  3. Preencher nome, descrição, preço, raridade e estilo
 *  4. Reposicionamento visual com drag-and-drop + controles de escala/offset
 *  5. Preview em tempo real com avatar simulado em múltiplos tamanhos
 *  6. Publicar / Editar → salva offset_x, offset_y, scale no asset_config
 *
 * asset_config gerado:
 *  { frame_url, image_url, rarity, frame_style, image_width, image_height,
 *    is_animated, mime_type, offset_x, offset_y, scale }
 *
 * offset_x / offset_y: deslocamento em px relativo ao centro (positivo = direita/baixo)
 * scale: multiplicador do tamanho base (1.0 = padrão 1.4× avatar, 1.2 = 20% maior, etc.)
 */
import { useState, useRef, useCallback, useEffect } from "react";
import { supabase, StoreItem } from "@/lib/supabase";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { toast } from "sonner";
import {
  Upload,
  Trash2,
  AlertCircle,
  CheckCircle2,
  Loader2,
  ImagePlus,
  Package,
  RefreshCw,
  User,
  Frame,
  Zap,
  Pencil,
  X,
  Move,
  ZoomIn,
  ZoomOut,
  RotateCcw,
  Crosshair,
} from "lucide-react";

// ─── Tipos ───────────────────────────────────────────────────────────────────

type FrameForm = {
  name: string;
  description: string;
  priceCoins: number;
  rarity: "common" | "rare" | "epic" | "legendary";
  frameStyle: "default" | "sparkle" | "fire" | "ice" | "neon" | "gold";
  isActive: boolean;
};

type FrameTransform = {
  offsetX: number; // px deslocamento horizontal (-100 a +100)
  offsetY: number; // px deslocamento vertical (-100 a +100)
  scale: number;   // multiplicador de escala (0.5 a 2.0)
};

const DEFAULT_TRANSFORM: FrameTransform = { offsetX: 0, offsetY: 0, scale: 1.0 };

const RARITY_COLORS: Record<string, string> = {
  common: "#9CA3AF",
  rare: "#60A5FA",
  epic: "#A78BFA",
  legendary: "#FBBF24",
};

const FRAME_STYLE_LABELS: Record<string, string> = {
  default: "Padrão",
  sparkle: "Sparkle ✨",
  fire: "Fire 🔥",
  ice: "Ice ❄️",
  neon: "Neon 💜",
  gold: "Gold 🏆",
};

function detectIsAnimated(file: File): boolean {
  const ext = file.name.split(".").pop()?.toLowerCase() ?? "";
  if (file.type === "image/gif" || ext === "gif" || ext === "apng") return true;
  return false;
}

// ─── Frame Position Editor (Drag + Sliders) ──────────────────────────────────

function FramePositionEditor({
  frameUrl,
  transform,
  onChange,
  isAnimated,
}: {
  frameUrl: string | null;
  transform: FrameTransform;
  onChange: (t: FrameTransform) => void;
  isAnimated: boolean;
}) {
  const CANVAS_SIZE = 240;
  const AVATAR_SIZE = 80;
  const BASE_FRAME_MULTIPLIER = 1.4;

  const isDraggingRef = useRef(false);
  const dragStartRef = useRef({ x: 0, y: 0, ox: 0, oy: 0 });
  const canvasRef = useRef<HTMLDivElement>(null);

  const frameSize = Math.round(AVATAR_SIZE * BASE_FRAME_MULTIPLIER * transform.scale);
  const centerX = CANVAS_SIZE / 2;
  const centerY = CANVAS_SIZE / 2;

  // Posição final da moldura no canvas
  const frameLeft = centerX - frameSize / 2 + transform.offsetX;
  const frameTop = centerY - frameSize / 2 + transform.offsetY;

  function onMouseDown(e: React.MouseEvent) {
    if (!frameUrl) return;
    e.preventDefault();
    isDraggingRef.current = true;
    dragStartRef.current = {
      x: e.clientX,
      y: e.clientY,
      ox: transform.offsetX,
      oy: transform.offsetY,
    };
  }

  function onTouchStart(e: React.TouchEvent) {
    if (!frameUrl) return;
    const touch = e.touches[0];
    isDraggingRef.current = true;
    dragStartRef.current = {
      x: touch.clientX,
      y: touch.clientY,
      ox: transform.offsetX,
      oy: transform.offsetY,
    };
  }

  useEffect(() => {
    function onMouseMove(e: MouseEvent) {
      if (!isDraggingRef.current) return;
      const dx = e.clientX - dragStartRef.current.x;
      const dy = e.clientY - dragStartRef.current.y;
      const newOx = Math.round(Math.max(-100, Math.min(100, dragStartRef.current.ox + dx)));
      const newOy = Math.round(Math.max(-100, Math.min(100, dragStartRef.current.oy + dy)));
      onChange({ ...transform, offsetX: newOx, offsetY: newOy });
    }

    function onTouchMove(e: TouchEvent) {
      if (!isDraggingRef.current) return;
      const touch = e.touches[0];
      const dx = touch.clientX - dragStartRef.current.x;
      const dy = touch.clientY - dragStartRef.current.y;
      const newOx = Math.round(Math.max(-100, Math.min(100, dragStartRef.current.ox + dx)));
      const newOy = Math.round(Math.max(-100, Math.min(100, dragStartRef.current.oy + dy)));
      onChange({ ...transform, offsetX: newOx, offsetY: newOy });
    }

    function onUp() {
      isDraggingRef.current = false;
    }

    window.addEventListener("mousemove", onMouseMove);
    window.addEventListener("mouseup", onUp);
    window.addEventListener("touchmove", onTouchMove, { passive: true });
    window.addEventListener("touchend", onUp);
    return () => {
      window.removeEventListener("mousemove", onMouseMove);
      window.removeEventListener("mouseup", onUp);
      window.removeEventListener("touchmove", onTouchMove);
      window.removeEventListener("touchend", onUp);
    };
  }, [transform, onChange]);

  const isDefault =
    transform.offsetX === 0 && transform.offsetY === 0 && transform.scale === 1.0;

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Move className="w-4 h-4 text-[#E040FB]" />
          <span
            className="text-xs uppercase tracking-widest text-[#9CA3AF]"
            style={{ fontFamily: "'DM Mono', monospace" }}
          >
            Reposicionamento Visual
          </span>
        </div>
        {!isDefault && (
          <button
            type="button"
            onClick={() => onChange(DEFAULT_TRANSFORM)}
            className="flex items-center gap-1 text-[10px] px-2 py-1 rounded-md bg-[#2A2D34] text-[#9CA3AF] hover:text-white hover:bg-[#3A3D44] transition-colors"
            style={{ fontFamily: "'DM Mono', monospace" }}
          >
            <RotateCcw className="w-3 h-3" />
            Resetar
          </button>
        )}
      </div>

      {/* Canvas de drag */}
      <div className="flex gap-4 items-start">
        <div className="flex flex-col items-center gap-2">
          <p
            className="text-[10px] text-[#4B5563] uppercase tracking-widest"
            style={{ fontFamily: "'DM Mono', monospace" }}
          >
            Arraste a moldura
          </p>

          <div
            ref={canvasRef}
            className="relative rounded-xl overflow-hidden select-none"
            style={{
              width: CANVAS_SIZE,
              height: CANVAS_SIZE,
              backgroundColor: "#111214",
              border: "1px solid #2A2D34",
              backgroundImage:
                "radial-gradient(circle, #1C1E22 1px, transparent 1px)",
              backgroundSize: "16px 16px",
              cursor: frameUrl ? "grab" : "default",
            }}
            onMouseDown={onMouseDown}
            onTouchStart={onTouchStart}
          >
            {/* Crosshair central */}
            <div
              className="absolute pointer-events-none"
              style={{
                left: centerX - 0.5,
                top: 0,
                width: 1,
                height: CANVAS_SIZE,
                backgroundColor: "#2A2D34",
              }}
            />
            <div
              className="absolute pointer-events-none"
              style={{
                left: 0,
                top: centerY - 0.5,
                width: CANVAS_SIZE,
                height: 1,
                backgroundColor: "#2A2D34",
              }}
            />

            {/* Avatar simulado — sempre centralizado */}
            <div
              className="absolute rounded-full bg-gradient-to-br from-[#2A2D34] to-[#1C1E22] border-2 border-[#3A3D44] flex items-center justify-center overflow-hidden"
              style={{
                width: AVATAR_SIZE,
                height: AVATAR_SIZE,
                left: centerX - AVATAR_SIZE / 2,
                top: centerY - AVATAR_SIZE / 2,
              }}
            >
              <User className="w-10 h-10 text-[#4B5563]" />
            </div>

            {/* Moldura — arrastável */}
            {frameUrl ? (
              <img
                src={frameUrl}
                alt="Frame"
                draggable={false}
                className="absolute object-contain pointer-events-none"
                style={{
                  width: frameSize,
                  height: frameSize,
                  left: frameLeft,
                  top: frameTop,
                  transition: isDraggingRef.current ? "none" : "left 0.05s, top 0.05s",
                }}
              />
            ) : (
              <div
                className="absolute flex items-center justify-center"
                style={{
                  left: centerX - 40,
                  top: centerY - 40,
                  width: 80,
                  height: 80,
                }}
              >
                <Crosshair className="w-8 h-8 text-[#2A2D34]" />
              </div>
            )}

            {/* Label de offset quando deslocado */}
            {(transform.offsetX !== 0 || transform.offsetY !== 0) && (
              <div
                className="absolute bottom-2 left-2 text-[9px] px-1.5 py-0.5 rounded"
                style={{
                  backgroundColor: "#E040FB20",
                  color: "#E040FB",
                  fontFamily: "'DM Mono', monospace",
                }}
              >
                {transform.offsetX > 0 ? "+" : ""}{transform.offsetX}, {transform.offsetY > 0 ? "+" : ""}{transform.offsetY}px
              </div>
            )}

            {/* Instrução quando sem imagem */}
            {!frameUrl && (
              <div
                className="absolute inset-0 flex items-end justify-center pb-3"
              >
                <p
                  className="text-[10px] text-[#4B5563]"
                  style={{ fontFamily: "'DM Mono', monospace" }}
                >
                  Envie uma imagem para habilitar
                </p>
              </div>
            )}
          </div>

          {/* Escala */}
          <div className="flex items-center gap-2 w-full">
            <button
              type="button"
              onClick={() => onChange({ ...transform, scale: Math.max(0.5, parseFloat((transform.scale - 0.05).toFixed(2))) })}
              className="p-1 rounded bg-[#2A2D34] text-[#9CA3AF] hover:text-white transition-colors"
              disabled={transform.scale <= 0.5}
            >
              <ZoomOut className="w-3.5 h-3.5" />
            </button>
            <input
              type="range"
              min={0.5}
              max={2.0}
              step={0.05}
              value={transform.scale}
              onChange={(e) => onChange({ ...transform, scale: parseFloat(e.target.value) })}
              className="flex-1 h-1 rounded-full appearance-none cursor-pointer"
              style={{ accentColor: "#E040FB" }}
            />
            <button
              type="button"
              onClick={() => onChange({ ...transform, scale: Math.min(2.0, parseFloat((transform.scale + 0.05).toFixed(2))) })}
              className="p-1 rounded bg-[#2A2D34] text-[#9CA3AF] hover:text-white transition-colors"
              disabled={transform.scale >= 2.0}
            >
              <ZoomIn className="w-3.5 h-3.5" />
            </button>
            <span
              className="text-[10px] w-10 text-right text-[#9CA3AF]"
              style={{ fontFamily: "'DM Mono', monospace" }}
            >
              {transform.scale.toFixed(2)}×
            </span>
          </div>
        </div>

        {/* Controles numéricos */}
        <div className="flex-1 space-y-3">
          {/* Offset X */}
          <div className="space-y-1">
            <div className="flex items-center justify-between">
              <Label
                className="text-[#4B5563] text-[10px] uppercase tracking-widest"
                style={{ fontFamily: "'DM Mono', monospace" }}
              >
                Offset X
              </Label>
              <span
                className="text-[10px] text-[#9CA3AF]"
                style={{ fontFamily: "'DM Mono', monospace" }}
              >
                {transform.offsetX > 0 ? "+" : ""}{transform.offsetX}px
              </span>
            </div>
            <input
              type="range"
              min={-100}
              max={100}
              step={1}
              value={transform.offsetX}
              onChange={(e) => onChange({ ...transform, offsetX: parseInt(e.target.value) })}
              className="w-full h-1 rounded-full appearance-none cursor-pointer"
              style={{ accentColor: "#60A5FA" }}
            />
            <div className="flex justify-between text-[9px] text-[#4B5563]" style={{ fontFamily: "'DM Mono', monospace" }}>
              <span>-100</span><span>0</span><span>+100</span>
            </div>
          </div>

          {/* Offset Y */}
          <div className="space-y-1">
            <div className="flex items-center justify-between">
              <Label
                className="text-[#4B5563] text-[10px] uppercase tracking-widest"
                style={{ fontFamily: "'DM Mono', monospace" }}
              >
                Offset Y
              </Label>
              <span
                className="text-[10px] text-[#9CA3AF]"
                style={{ fontFamily: "'DM Mono', monospace" }}
              >
                {transform.offsetY > 0 ? "+" : ""}{transform.offsetY}px
              </span>
            </div>
            <input
              type="range"
              min={-100}
              max={100}
              step={1}
              value={transform.offsetY}
              onChange={(e) => onChange({ ...transform, offsetY: parseInt(e.target.value) })}
              className="w-full h-1 rounded-full appearance-none cursor-pointer"
              style={{ accentColor: "#34D399" }}
            />
            <div className="flex justify-between text-[9px] text-[#4B5563]" style={{ fontFamily: "'DM Mono', monospace" }}>
              <span>-100</span><span>0</span><span>+100</span>
            </div>
          </div>

          {/* Escala numérica */}
          <div className="space-y-1">
            <div className="flex items-center justify-between">
              <Label
                className="text-[#4B5563] text-[10px] uppercase tracking-widest"
                style={{ fontFamily: "'DM Mono', monospace" }}
              >
                Escala
              </Label>
              <span
                className="text-[10px] text-[#9CA3AF]"
                style={{ fontFamily: "'DM Mono', monospace" }}
              >
                {transform.scale.toFixed(2)}×
              </span>
            </div>
            <input
              type="range"
              min={0.5}
              max={2.0}
              step={0.05}
              value={transform.scale}
              onChange={(e) => onChange({ ...transform, scale: parseFloat(e.target.value) })}
              className="w-full h-1 rounded-full appearance-none cursor-pointer"
              style={{ accentColor: "#E040FB" }}
            />
            <div className="flex justify-between text-[9px] text-[#4B5563]" style={{ fontFamily: "'DM Mono', monospace" }}>
              <span>0.5×</span><span>1.0×</span><span>2.0×</span>
            </div>
          </div>

          {/* Info técnica */}
          <div
            className="p-2.5 rounded-lg space-y-1"
            style={{ backgroundColor: "#111214", border: "1px solid #2A2D34" }}
          >
            <p
              className="text-[9px] text-[#4B5563] uppercase tracking-widest mb-1.5"
              style={{ fontFamily: "'DM Mono', monospace" }}
            >
              asset_config
            </p>
            <p className="text-[10px] text-[#6B7280]" style={{ fontFamily: "'DM Mono', monospace" }}>
              offset_x: <span style={{ color: "#60A5FA" }}>{transform.offsetX}</span>
            </p>
            <p className="text-[10px] text-[#6B7280]" style={{ fontFamily: "'DM Mono', monospace" }}>
              offset_y: <span style={{ color: "#34D399" }}>{transform.offsetY}</span>
            </p>
            <p className="text-[10px] text-[#6B7280]" style={{ fontFamily: "'DM Mono', monospace" }}>
              scale: <span style={{ color: "#E040FB" }}>{transform.scale.toFixed(2)}</span>
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── Preview de Avatar com Moldura ───────────────────────────────────────────

function AvatarPreview({
  frameUrl,
  name,
  rarity,
  isAnimated,
  transform,
}: {
  frameUrl: string | null;
  name: string;
  rarity: string;
  isAnimated: boolean;
  transform: FrameTransform;
}) {
  const AVATAR_SIZE = 80;
  const BASE_FRAME_MULTIPLIER = 1.4;

  return (
    <div className="flex flex-col items-center gap-5 p-6">
      {/* Preview principal */}
      <div className="flex flex-col items-center gap-3">
        <div className="flex items-center gap-2">
          <p
            className="text-[#4B5563] text-xs uppercase tracking-widest"
            style={{ fontFamily: "'DM Mono', monospace" }}
          >
            Preview — Avatar + Moldura
          </p>
          {isAnimated && (
            <span
              className="flex items-center gap-1 text-[10px] px-1.5 py-0.5 rounded font-medium"
              style={{
                color: "#34D399",
                backgroundColor: "#34D39920",
                fontFamily: "'DM Mono', monospace",
              }}
            >
              <Zap className="w-2.5 h-2.5" />
              ANIMADO
            </span>
          )}
        </div>

        {/* Stack: avatar + frame overlay com transform aplicado */}
        {(() => {
          const frameSize = Math.round(AVATAR_SIZE * BASE_FRAME_MULTIPLIER * transform.scale);
          const containerSize = Math.max(frameSize + Math.abs(transform.offsetX) * 2, AVATAR_SIZE) + 20;
          return (
            <div
              className="relative flex items-center justify-center"
              style={{ width: containerSize, height: containerSize }}
            >
              {/* Avatar simulado */}
              <div
                className="absolute rounded-full bg-gradient-to-br from-[#2A2D34] to-[#1C1E22] border-2 border-[#3A3D44] flex items-center justify-center overflow-hidden"
                style={{
                  width: AVATAR_SIZE,
                  height: AVATAR_SIZE,
                  left: containerSize / 2 - AVATAR_SIZE / 2,
                  top: containerSize / 2 - AVATAR_SIZE / 2,
                }}
              >
                <User className="w-10 h-10 text-[#4B5563]" />
              </div>

              {/* Moldura overlay com transform */}
              {frameUrl && (
                <img
                  src={frameUrl}
                  alt="Frame preview"
                  className="absolute object-contain pointer-events-none"
                  style={{
                    width: frameSize,
                    height: frameSize,
                    left: containerSize / 2 - frameSize / 2 + transform.offsetX,
                    top: containerSize / 2 - frameSize / 2 + transform.offsetY,
                  }}
                />
              )}

              {!frameUrl && (
                <div
                  className="absolute rounded-full border-4 border-dashed border-[#2A2D34] pointer-events-none"
                  style={{
                    width: frameSize,
                    height: frameSize,
                    left: containerSize / 2 - frameSize / 2,
                    top: containerSize / 2 - frameSize / 2,
                  }}
                />
              )}
            </div>
          );
        })()}

        {/* Nome e raridade */}
        <div className="text-center">
          <p className="text-white text-sm font-semibold">
            {name || "Nova Moldura"}
          </p>
          <span
            className="text-[10px] px-2 py-0.5 rounded-full font-medium"
            style={{
              color: RARITY_COLORS[rarity] ?? RARITY_COLORS.common,
              backgroundColor:
                (RARITY_COLORS[rarity] ?? RARITY_COLORS.common) + "20",
              fontFamily: "'DM Mono', monospace",
            }}
          >
            {rarity}
          </span>
        </div>
      </div>

      {/* Exemplos de tamanho com transform aplicado */}
      <div className="w-full border-t border-[#2A2D34] pt-4">
        <p
          className="text-[#4B5563] text-xs uppercase tracking-widest mb-3 text-center"
          style={{ fontFamily: "'DM Mono', monospace" }}
        >
          Tamanhos no App
        </p>
        <div className="flex items-end justify-center gap-6">
          {[
            { label: "Chat", avatarPx: 36 },
            { label: "Perfil", avatarPx: 80 },
            { label: "Header", avatarPx: 56 },
          ].map(({ label, avatarPx }) => {
            const framePx = Math.round(avatarPx * BASE_FRAME_MULTIPLIER * transform.scale);
            // Escalar o offset proporcionalmente ao tamanho do avatar
            const scaledOx = Math.round(transform.offsetX * (avatarPx / AVATAR_SIZE));
            const scaledOy = Math.round(transform.offsetY * (avatarPx / AVATAR_SIZE));
            const containerPx = Math.max(framePx + Math.abs(scaledOx) * 2, avatarPx) + 8;
            return (
              <div key={label} className="flex flex-col items-center gap-1.5">
                <div
                  className="relative flex items-center justify-center"
                  style={{ width: containerPx, height: containerPx }}
                >
                  <div
                    className="absolute rounded-full bg-gradient-to-br from-[#2A2D34] to-[#1C1E22] border border-[#3A3D44] flex items-center justify-center"
                    style={{
                      width: avatarPx,
                      height: avatarPx,
                      left: containerPx / 2 - avatarPx / 2,
                      top: containerPx / 2 - avatarPx / 2,
                    }}
                  >
                    <User
                      style={{
                        width: avatarPx * 0.55,
                        height: avatarPx * 0.55,
                        color: "#4B5563",
                      }}
                    />
                  </div>
                  {frameUrl && (
                    <img
                      src={frameUrl}
                      alt=""
                      className="absolute object-contain pointer-events-none"
                      style={{
                        width: framePx,
                        height: framePx,
                        left: containerPx / 2 - framePx / 2 + scaledOx,
                        top: containerPx / 2 - framePx / 2 + scaledOy,
                      }}
                    />
                  )}
                </div>
                <p
                  className="text-[#4B5563] text-[10px]"
                  style={{ fontFamily: "'DM Mono', monospace" }}
                >
                  {label}
                </p>
              </div>
            );
          })}
        </div>
      </div>

      {/* Info técnica */}
      <div className="w-full border-t border-[#2A2D34] pt-3 space-y-0.5">
        <p
          className="text-[#4B5563] text-xs"
          style={{ fontFamily: "'DM Mono', monospace" }}
        >
          {isAnimated ? "overlay GIF/WebP animado" : "overlay PNG transparente"}
        </p>
        <p
          className="text-[#4B5563] text-xs"
          style={{ fontFamily: "'DM Mono', monospace" }}
        >
          frame_size = avatar × 1.4 × {transform.scale.toFixed(2)}
        </p>
        <p
          className="text-[#4B5563] text-xs"
          style={{ fontFamily: "'DM Mono', monospace" }}
        >
          offset: ({transform.offsetX > 0 ? "+" : ""}{transform.offsetX}px, {transform.offsetY > 0 ? "+" : ""}{transform.offsetY}px)
        </p>
        {isAnimated && (
          <p
            className="text-[#34D399] text-xs"
            style={{ fontFamily: "'DM Mono', monospace" }}
          >
            is_animated: true → Flutter renderiza loop automático
          </p>
        )}
      </div>
    </div>
  );
}

// ─── Componente principal ─────────────────────────────────────────────────────

export default function FramesDashboard() {
  // Form state
  const [form, setForm] = useState<FrameForm>({
    name: "",
    description: "",
    priceCoins: 200,
    rarity: "common",
    frameStyle: "default",
    isActive: true,
  });

  // Transform state (offset + scale)
  const [transform, setTransform] = useState<FrameTransform>(DEFAULT_TRANSFORM);

  // Editing state
  const [editingFrame, setEditingFrame] = useState<StoreItem | null>(null);

  // Upload state
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [imageDimensions, setImageDimensions] = useState<{ w: number; h: number } | null>(null);
  const [isDragging, setIsDragging] = useState(false);
  const [isAnimated, setIsAnimated] = useState(false);
  const [isWebP, setIsWebP] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Submission state
  const [submitting, setSubmitting] = useState(false);

  // Existing frames
  const [frames, setFrames] = useState<StoreItem[]>([]);
  const [loadingFrames, setLoadingFrames] = useState(true);

  // ── Load existing frames ───────────────────────────────────────────────────

  async function loadFrames() {
    setLoadingFrames(true);
    const { data, error } = await supabase
      .from("store_items")
      .select("*")
      .eq("type", "avatar_frame")
      .order("created_at", { ascending: false });
    if (!error && data) setFrames(data as StoreItem[]);
    setLoadingFrames(false);
  }

  useEffect(() => { loadFrames(); }, []);

  // ── Image handling ─────────────────────────────────────────────────────────

  function handleFile(file: File) {
    if (!file.type.startsWith("image/")) {
      toast.error("Arquivo inválido. Envie PNG, GIF ou WebP.");
      return;
    }
    const ext = file.name.split(".").pop()?.toLowerCase() ?? "";
    const detected = detectIsAnimated(file);
    const webp = file.type === "image/webp" || ext === "webp";
    setIsAnimated(detected);
    setIsWebP(webp);
    if (detected) toast.info(`Moldura animada detectada (${ext.toUpperCase()}).`, { duration: 3000 });
    else if (webp) toast.info("WebP detectado. Ative o toggle se for animado.", { duration: 4000 });

    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => { setImageDimensions({ w: img.width, h: img.height }); URL.revokeObjectURL(url); };
    img.src = url;
    setImageFile(file);
    const reader = new FileReader();
    reader.onload = (e) => setImagePreview(e.target?.result as string);
    reader.readAsDataURL(file);
  }

  const onDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    const file = e.dataTransfer.files[0];
    if (file) handleFile(file);
  }, []);

  // ── Open edit ──────────────────────────────────────────────────────────────

  function openEdit(item: StoreItem) {
    const cfg = (item.asset_config as Record<string, unknown>) ?? {};
    setEditingFrame(item);
    setForm({
      name: item.name,
      description: item.description ?? "",
      priceCoins: item.price_coins,
      rarity: (cfg.rarity as FrameForm["rarity"]) ?? "common",
      frameStyle: (cfg.frame_style as FrameForm["frameStyle"]) ?? "default",
      isActive: item.is_active,
    });
    setTransform({
      offsetX: (cfg.offset_x as number) ?? 0,
      offsetY: (cfg.offset_y as number) ?? 0,
      scale: (cfg.scale as number) ?? 1.0,
    });
    setIsAnimated((cfg.is_animated as boolean) ?? false);
    setIsWebP(false);
    setImageFile(null);
    setImagePreview(item.preview_url ?? null);
    setImageDimensions(
      cfg.image_width && cfg.image_height
        ? { w: cfg.image_width as number, h: cfg.image_height as number }
        : null
    );
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  // ── Cancel edit ────────────────────────────────────────────────────────────

  function cancelEdit() {
    setEditingFrame(null);
    setForm({ name: "", description: "", priceCoins: 200, rarity: "common", frameStyle: "default", isActive: true });
    setTransform(DEFAULT_TRANSFORM);
    setImageFile(null);
    setImagePreview(null);
    setImageDimensions(null);
    setIsAnimated(false);
    setIsWebP(false);
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!editingFrame && !imageFile) { toast.error("Selecione uma imagem para a moldura."); return; }
    if (!form.name.trim()) { toast.error("Defina um nome para a moldura."); return; }
    setSubmitting(true);
    try {
      let publicUrl: string | null = editingFrame?.preview_url ?? null;
      if (imageFile) {
        const ext = imageFile.name.split(".").pop()?.toLowerCase() ?? "png";
        const slug = form.name.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "");
        const path = `frames/${slug}_${Date.now()}.${ext}`;
        const { error: uploadError } = await supabase.storage.from("store-assets").upload(path, imageFile, { contentType: imageFile.type, upsert: false });
        if (uploadError) throw new Error(`Upload falhou: ${uploadError.message}`);
        const { data: urlData } = supabase.storage.from("store-assets").getPublicUrl(path);
        publicUrl = urlData.publicUrl;
      }
      const imgW = imageDimensions?.w ?? 512;
      const imgH = imageDimensions?.h ?? 512;
      const assetConfig = {
        frame_url: publicUrl,
        image_url: publicUrl,
        rarity: form.rarity,
        frame_style: form.frameStyle,
        image_width: imgW,
        image_height: imgH,
        is_animated: isAnimated,
        mime_type: imageFile?.type ?? (editingFrame?.asset_config as Record<string, unknown>)?.mime_type ?? "image/png",
        // Campos de reposicionamento — lidos pelo Flutter em AvatarWithFrame
        offset_x: transform.offsetX,
        offset_y: transform.offsetY,
        scale: transform.scale,
      };
      const payload = {
        type: "avatar_frame",
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
      if (editingFrame) {
        const { error } = await supabase.from("store_items").update(payload).eq("id", editingFrame.id);
        if (error) throw new Error(`DB error: ${error.message}`);
        toast.success(`"${form.name}" atualizada! ✨`);
      } else {
        const { error } = await supabase.from("store_items").insert(payload);
        if (error) throw new Error(`DB error: ${error.message}`);
        toast.success(`"${form.name}" publicada na loja! 🎉`);
      }
      cancelEdit();
      loadFrames();
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : String(err));
    } finally {
      setSubmitting(false);
    }
  }

  // ── Toggle active ──────────────────────────────────────────────────────────

  async function toggleActive(item: StoreItem) {
    const { error } = await supabase.from("store_items").update({ is_active: !item.is_active }).eq("id", item.id);
    if (error) { toast.error("Erro ao atualizar status."); return; }
    setFrames((prev) => prev.map((f) => f.id === item.id ? { ...f, is_active: !f.is_active } : f));
    toast.success(`"${item.name}" ${!item.is_active ? "ativada" : "desativada"}.`);
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  async function deleteFrame(item: StoreItem) {
    if (!confirm(`Deletar "${item.name}"? Esta ação não pode ser desfeita.`)) return;
    const { error } = await supabase.from("store_items").delete().eq("id", item.id);
    if (error) { toast.error("Erro ao deletar."); return; }
    setFrames((prev) => prev.filter((f) => f.id !== item.id));
    toast.success(`"${item.name}" removida da loja.`);
  }

  // ── Render ─────────────────────────────────────────────────────────────────

  const accentColor = editingFrame ? "#FBBF24" : "#E040FB";

  return (
    <div className="relative z-10 max-w-7xl mx-auto px-4 md:px-6 py-5 md:py-8">

      {/* ── Header ── */}
      <div className="mb-8">
        <div className="flex items-center justify-between gap-2 mb-1">
          <div className="flex items-center gap-2">
            <div className="w-1 h-5 rounded-full" style={{ backgroundColor: accentColor }} />
            <h2 className="text-lg font-bold text-white">
              {editingFrame ? `Editando: ${editingFrame.name}` : "Criar nova Moldura de Perfil"}
            </h2>
          </div>
          {editingFrame && (
            <button
              type="button"
              onClick={cancelEdit}
              className="flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-md bg-[#2A2D34] text-[#9CA3AF] hover:text-white hover:bg-[#3A3D44] transition-colors"
              style={{ fontFamily: "'DM Mono', monospace" }}
            >
              <X className="w-3.5 h-3.5" />
              Cancelar edição
            </button>
          )}
        </div>
        <p className="text-[#9CA3AF] text-sm ml-3" style={{ fontFamily: "'DM Mono', monospace" }}>
          {editingFrame
            ? "Ajuste os campos e reposicione a moldura arrastando no editor visual."
            : "Envie PNG, GIF ou WebP. Use o editor visual para ajustar posição e escala."}
        </p>
      </div>

      {/* ── Banner de edição ── */}
      {editingFrame && (
        <div className="flex items-start gap-3 bg-[#FBBF24]/5 border border-[#FBBF24]/20 rounded-xl p-4 mb-6">
          <Pencil className="w-4 h-4 text-[#FBBF24] flex-shrink-0 mt-0.5" />
          <div>
            <p className="text-[#FBBF24] text-sm font-medium" style={{ fontFamily: "'DM Mono', monospace" }}>
              Modo de edição ativo
            </p>
            <p className="text-[#4B5563] text-xs mt-1" style={{ fontFamily: "'DM Mono', monospace" }}>
              Editando "{editingFrame.name}" · Deixe o campo de imagem vazio para manter a imagem atual.
            </p>
          </div>
        </div>
      )}

      <form onSubmit={handleSubmit}>
        {/* ── Layout principal: formulário + preview ── */}
        <div className="grid grid-cols-1 lg:grid-cols-5 gap-4 md:gap-6 mb-6 md:mb-10">

          {/* Formulário — 3/5 */}
          <div className="lg:col-span-3 space-y-5">

            {/* Upload zone */}
            <div
              className={`border-2 border-dashed rounded-xl p-6 text-center cursor-pointer transition-all duration-200 ${
                isDragging ? "border-[#E040FB] bg-[#E040FB]/5"
                : imageFile ? isAnimated ? "border-[#34D399]/60 bg-[#34D399]/5" : "border-[#E040FB]/50 bg-[#E040FB]/5"
                : editingFrame ? "border-[#FBBF24]/30 bg-[#FBBF24]/5 hover:border-[#FBBF24]/50"
                : "border-[#2A2D34] bg-[#1C1E22] hover:border-[#E040FB]/40 hover:bg-[#E040FB]/5"
              }`}
              onClick={() => fileInputRef.current?.click()}
              onDragOver={(e) => { e.preventDefault(); setIsDragging(true); }}
              onDragLeave={() => setIsDragging(false)}
              onDrop={onDrop}
            >
              <input
                ref={fileInputRef}
                type="file"
                accept="image/png,image/gif,image/webp,image/apng,.apng"
                className="hidden"
                onChange={(e) => { const f = e.target.files?.[0]; if (f) handleFile(f); }}
              />
              {imagePreview ? (
                <div className="flex items-center gap-4">
                  <div
                    className="w-16 h-16 rounded-lg border overflow-hidden flex items-center justify-center flex-shrink-0 relative"
                    style={{
                      borderColor: isAnimated ? "#34D39940" : editingFrame && !imageFile ? "#FBBF2440" : "#2A2D34",
                      backgroundImage: "linear-gradient(45deg, #2A2D34 25%, transparent 25%), linear-gradient(-45deg, #2A2D34 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #2A2D34 75%), linear-gradient(-45deg, transparent 75%, #2A2D34 75%)",
                      backgroundSize: "8px 8px",
                      backgroundPosition: "0 0, 0 4px, 4px -4px, -4px 0px",
                    }}
                  >
                    <img src={imagePreview} alt="Preview" className="w-full h-full object-contain" />
                    {isAnimated && (
                      <div className="absolute bottom-0.5 right-0.5 bg-[#34D399] rounded-sm px-1 flex items-center gap-0.5">
                        <Zap style={{ width: 8, height: 8, color: "#111214" }} />
                        <span style={{ fontSize: 8, color: "#111214", fontFamily: "'DM Mono', monospace", fontWeight: 700 }}>GIF</span>
                      </div>
                    )}
                    {editingFrame && !imageFile && (
                      <div className="absolute bottom-0.5 right-0.5 bg-[#FBBF24] rounded-sm px-1">
                        <span style={{ fontSize: 7, color: "#111214", fontFamily: "'DM Mono', monospace", fontWeight: 700 }}>ATUAL</span>
                      </div>
                    )}
                  </div>
                  <div className="text-left">
                    <div className="flex items-center gap-2">
                      <p className="text-white font-medium text-sm">{imageFile ? imageFile.name : "Imagem atual"}</p>
                      {isAnimated && (
                        <span className="text-[10px] px-1.5 py-0.5 rounded font-medium" style={{ color: "#34D399", backgroundColor: "#34D39920", fontFamily: "'DM Mono', monospace" }}>ANIMADO</span>
                      )}
                    </div>
                    <p className="text-[#9CA3AF] text-xs mt-0.5" style={{ fontFamily: "'DM Mono', monospace" }}>
                      {imageDimensions ? `${imageDimensions.w}×${imageDimensions.h}px` : "Dimensões não disponíveis"}
                      {imageDimensions && imageDimensions.w !== imageDimensions.h && <span className="text-yellow-400 ml-2">⚠ Recomendado: quadrado</span>}
                    </p>
                    <p className="text-xs mt-1" style={{ color: editingFrame ? "#FBBF24" : "#E040FB" }}>
                      {editingFrame && !imageFile ? "Clique para substituir a imagem" : "Clique para trocar"}
                    </p>
                  </div>
                </div>
              ) : (
                <div>
                  <Frame className="w-8 h-8 text-[#4B5563] mx-auto mb-2" />
                  <p className="text-[#9CA3AF] text-sm">Arraste ou clique para enviar</p>
                  <p className="text-[#4B5563] text-xs mt-1" style={{ fontFamily: "'DM Mono', monospace" }}>PNG estático · GIF animado · WebP animado</p>
                  <p className="text-[#6B21A8] text-xs mt-0.5" style={{ fontFamily: "'DM Mono', monospace" }}>Recomendado: 512×512px · fundo transparente</p>
                </div>
              )}
            </div>

            {/* Toggle animação */}
            {(imageFile || editingFrame) && (isWebP || !isAnimated) && (
              <div className="flex items-start gap-3 bg-[#1C1E22] border border-[#2A2D34] rounded-xl p-4">
                <button type="button" onClick={() => setIsAnimated((v) => !v)}
                  className={`relative w-10 h-5 rounded-full transition-colors duration-200 flex-shrink-0 mt-0.5 ${isAnimated ? "bg-[#34D399]" : "bg-[#2A2D34]"}`}
                >
                  <span className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform duration-200 ${isAnimated ? "translate-x-5" : "translate-x-0.5"}`} />
                </button>
                <div>
                  <div className="flex items-center gap-2">
                    <Zap className="w-3.5 h-3.5" style={{ color: isAnimated ? "#34D399" : "#4B5563" }} />
                    <span className="text-sm font-medium" style={{ color: isAnimated ? "#34D399" : "#9CA3AF", fontFamily: "'DM Mono', monospace" }}>Moldura Animada</span>
                  </div>
                  <p className="text-[#4B5563] text-xs mt-1" style={{ fontFamily: "'DM Mono', monospace" }}>
                    {isWebP ? "WebP pode ser estático ou animado. Ative se contém animação." : "Marcar como animada no asset_config."}
                  </p>
                </div>
              </div>
            )}

            {/* Nome */}
            <div className="space-y-1.5">
              <Label className="text-[#9CA3AF] text-xs uppercase tracking-widest" style={{ fontFamily: "'DM Mono', monospace" }}>Nome da Moldura *</Label>
              <Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="Ex: Golden Crown, Neon Halo..." required
                className="bg-[#1C1E22] border-[#2A2D34] text-white placeholder:text-[#4B5563] focus:border-[#E040FB] h-10" />
            </div>

            {/* Descrição */}
            <div className="space-y-1.5">
              <Label className="text-[#9CA3AF] text-xs uppercase tracking-widest" style={{ fontFamily: "'DM Mono', monospace" }}>Descrição (opcional)</Label>
              <Input value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} placeholder="Descrição breve para a loja..."
                className="bg-[#1C1E22] border-[#2A2D34] text-white placeholder:text-[#4B5563] focus:border-[#E040FB] h-10" />
            </div>

            {/* Preço + Raridade */}
            <div className="grid grid-cols-2 gap-2 md:gap-4">
              <div className="space-y-1.5">
                <Label className="text-[#9CA3AF] text-xs uppercase tracking-widest" style={{ fontFamily: "'DM Mono', monospace" }}>Preço (coins) *</Label>
                <Input type="number" min={0} value={form.priceCoins}
                  onChange={(e) => setForm({ ...form, priceCoins: parseInt(e.target.value) || 0 })}
                  className="bg-[#1C1E22] border-[#2A2D34] text-white focus:border-[#E040FB] h-10" style={{ fontFamily: "'DM Mono', monospace" }} />
              </div>
              <div className="space-y-1.5">
                <Label className="text-[#9CA3AF] text-xs uppercase tracking-widest" style={{ fontFamily: "'DM Mono', monospace" }}>Raridade</Label>
                <select value={form.rarity} onChange={(e) => setForm({ ...form, rarity: e.target.value as FrameForm["rarity"] })}
                  className="w-full h-10 rounded-md bg-[#1C1E22] border border-[#2A2D34] text-white px-3 text-sm focus:border-[#E040FB] focus:outline-none"
                  style={{ fontFamily: "'DM Mono', monospace" }}>
                  <option value="common">Common</option>
                  <option value="rare">Rare</option>
                  <option value="epic">Epic</option>
                  <option value="legendary">Legendary</option>
                </select>
              </div>
            </div>

            {/* Estilo */}
            <div className="space-y-1.5">
              <Label className="text-[#9CA3AF] text-xs uppercase tracking-widest" style={{ fontFamily: "'DM Mono', monospace" }}>Estilo / Efeito</Label>
              <select value={form.frameStyle} onChange={(e) => setForm({ ...form, frameStyle: e.target.value as FrameForm["frameStyle"] })}
                className="w-full h-10 rounded-md bg-[#1C1E22] border border-[#2A2D34] text-white px-3 text-sm focus:border-[#E040FB] focus:outline-none"
                style={{ fontFamily: "'DM Mono', monospace" }}>
                {Object.entries(FRAME_STYLE_LABELS).map(([value, label]) => (
                  <option key={value} value={value}>{label}</option>
                ))}
              </select>
            </div>

            {/* ── Editor de Reposicionamento Visual ── */}
            <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl p-4">
              <FramePositionEditor
                frameUrl={imagePreview}
                transform={transform}
                onChange={setTransform}
                isAnimated={isAnimated}
              />
            </div>

            {/* Status */}
            <div className="flex items-center gap-3">
              <button type="button" onClick={() => setForm({ ...form, isActive: !form.isActive })}
                className={`relative w-10 h-5 rounded-full transition-colors duration-200 ${form.isActive ? "bg-[#E040FB]" : "bg-[#2A2D34]"}`}>
                <span className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform duration-200 ${form.isActive ? "translate-x-5" : "translate-x-0.5"}`} />
              </button>
              <span className="text-[#9CA3AF] text-sm" style={{ fontFamily: "'DM Mono', monospace" }}>
                {form.isActive ? "Publicar na loja imediatamente" : "Salvar como rascunho"}
              </span>
            </div>

            {/* Botões */}
            <div className="flex gap-3">
              <Button type="submit"
                disabled={submitting || (!editingFrame && !imageFile) || !form.name.trim()}
                className="flex-1 h-11 text-white font-semibold border-0 transition-all duration-200 disabled:opacity-40"
                style={{ backgroundColor: accentColor }}
              >
                {submitting ? (
                  <span className="flex items-center gap-2"><Loader2 className="w-4 h-4 animate-spin" />{editingFrame ? "Salvando..." : "Publicando..."}</span>
                ) : editingFrame ? (
                  <span className="flex items-center gap-2"><Pencil className="w-4 h-4" />Salvar Alterações</span>
                ) : (
                  <span className="flex items-center gap-2">
                    <Upload className="w-4 h-4" />Publicar na Loja
                    {isAnimated && <span className="text-[10px] px-1.5 py-0.5 rounded font-medium ml-1" style={{ color: "#34D399", backgroundColor: "#34D39930", fontFamily: "'DM Mono', monospace" }}>ANIMADA</span>}
                  </span>
                )}
              </Button>
              {editingFrame && (
                <Button type="button" onClick={cancelEdit} variant="ghost"
                  className="h-11 px-4 text-[#9CA3AF] hover:text-white hover:bg-[#2A2D34] border border-[#2A2D34]">
                  <X className="w-4 h-4 mr-1.5" />Cancelar
                </Button>
              )}
            </div>
          </div>

          {/* Preview — 2/5 */}
          <div className="lg:col-span-2">
            <div
              className="border rounded-xl overflow-hidden lg:sticky lg:top-6"
              style={{
                backgroundColor: "#1C1E22",
                borderColor: editingFrame ? "#FBBF2430" : isAnimated ? "#34D39930" : "#2A2D34",
              }}
            >
              <div
                className="px-4 py-3 border-b flex items-center gap-2"
                style={{ borderColor: editingFrame ? "#FBBF2430" : isAnimated ? "#34D39930" : "#2A2D34" }}
              >
                <User className="w-4 h-4" style={{ color: editingFrame ? "#FBBF24" : isAnimated ? "#34D399" : "#E040FB" }} />
                <span className="text-xs uppercase tracking-widest" style={{ color: "#9CA3AF", fontFamily: "'DM Mono', monospace" }}>Preview em tempo real</span>
                {editingFrame && (
                  <span className="ml-auto flex items-center gap-1 text-[10px] px-1.5 py-0.5 rounded font-medium" style={{ color: "#FBBF24", backgroundColor: "#FBBF2420", fontFamily: "'DM Mono', monospace" }}>
                    <Pencil className="w-2.5 h-2.5" />EDITANDO
                  </span>
                )}
                {!editingFrame && isAnimated && (
                  <span className="ml-auto flex items-center gap-1 text-[10px] px-1.5 py-0.5 rounded font-medium" style={{ color: "#34D399", backgroundColor: "#34D39920", fontFamily: "'DM Mono', monospace" }}>
                    <Zap className="w-2.5 h-2.5" />ANIMADO
                  </span>
                )}
              </div>
              <div className="bg-[#111214]">
                <AvatarPreview
                  frameUrl={imagePreview}
                  name={form.name}
                  rarity={form.rarity}
                  isAnimated={isAnimated}
                  transform={transform}
                />
              </div>
            </div>
          </div>
        </div>
      </form>

      {/* ── Lista de molduras existentes ── */}
      <div>
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2">
            <div className="w-1 h-5 bg-[#E040FB] rounded-full" />
            <h2 className="text-lg font-bold text-white">Molduras na Loja</h2>
            <span className="text-[#4B5563] text-sm" style={{ fontFamily: "'DM Mono', monospace" }}>({frames.length})</span>
          </div>
          <Button variant="ghost" size="sm" onClick={loadFrames} className="text-[#9CA3AF] hover:text-white hover:bg-[#2A2D34] h-8 px-2">
            <RefreshCw className="w-3.5 h-3.5" />
          </Button>
        </div>

        {loadingFrames ? (
          <div className="flex items-center justify-center py-16">
            <Loader2 className="w-6 h-6 text-[#E040FB] animate-spin" />
          </div>
        ) : frames.length === 0 ? (
          <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl p-10 text-center">
            <Package className="w-10 h-10 text-[#2A2D34] mx-auto mb-3" />
            <p className="text-[#4B5563] text-sm">Nenhuma moldura na loja ainda.</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
            {frames.map((item) => {
              const cfg = item.asset_config as Record<string, unknown>;
              const rarity = (cfg?.rarity as string) ?? "common";
              const frameStyle = (cfg?.frame_style as string) ?? "default";
              const frameIsAnimated = (cfg?.is_animated as boolean) ?? false;
              const frameUrl = (cfg?.frame_url as string) || item.preview_url || null;
              const hasCustomTransform = cfg?.offset_x !== 0 || cfg?.offset_y !== 0 || (cfg?.scale !== undefined && cfg?.scale !== 1.0);
              const isEditing = editingFrame?.id === item.id;

              return (
                <div
                  key={item.id}
                  className={`bg-[#1C1E22] border rounded-xl overflow-hidden transition-all duration-200 ${
                    isEditing ? "border-[#FBBF24]/50 ring-1 ring-[#FBBF24]/20"
                    : item.is_active ? frameIsAnimated ? "border-[#34D399]/20 hover:border-[#34D399]/40" : "border-[#2A2D34] hover:border-[#E040FB]/30"
                    : "border-[#2A2D34] opacity-50"
                  }`}
                >
                  <div className="h-1 w-full" style={{ backgroundColor: isEditing ? "#FBBF24" : RARITY_COLORS[rarity] ?? RARITY_COLORS.common }} />
                  <div className="p-4">
                    {/* Preview mini */}
                    <div className="w-16 h-16 rounded-lg bg-[#111214] border border-[#2A2D34] mb-3 overflow-hidden flex items-center justify-center relative">
                      <div className="w-10 h-10 rounded-full bg-gradient-to-br from-[#2A2D34] to-[#1C1E22] flex items-center justify-center">
                        <User className="w-5 h-5 text-[#4B5563]" />
                      </div>
                      {frameUrl ? (
                        <img src={frameUrl} alt={item.name} className="absolute inset-0 w-full h-full object-contain pointer-events-none" />
                      ) : (
                        <ImagePlus className="w-6 h-6 text-[#4B5563] absolute" />
                      )}
                      {frameIsAnimated && (
                        <div className="absolute top-0.5 right-0.5 flex items-center gap-0.5 px-1 rounded-sm" style={{ backgroundColor: "#34D399" }}>
                          <Zap style={{ width: 7, height: 7, color: "#111214" }} />
                        </div>
                      )}
                    </div>

                    {/* Nome + raridade */}
                    <div className="flex items-start justify-between gap-2 mb-1">
                      <p className="text-white font-semibold text-sm leading-tight">{item.name}</p>
                      <div className="flex flex-col items-end gap-1 shrink-0">
                        <span className="text-[10px] px-1.5 py-0.5 rounded font-medium"
                          style={{ color: RARITY_COLORS[rarity] ?? RARITY_COLORS.common, backgroundColor: (RARITY_COLORS[rarity] ?? RARITY_COLORS.common) + "20", fontFamily: "'DM Mono', monospace" }}>
                          {rarity}
                        </span>
                        {frameIsAnimated && (
                          <span className="flex items-center gap-0.5 text-[9px] px-1.5 py-0.5 rounded font-medium"
                            style={{ color: "#34D399", backgroundColor: "#34D39920", fontFamily: "'DM Mono', monospace" }}>
                            <Zap style={{ width: 8, height: 8 }} />anim
                          </span>
                        )}
                      </div>
                    </div>

                    {/* Style + transform badge */}
                    <div className="flex items-center gap-1.5 mb-1">
                      <p className="text-[#6B7280] text-[10px]" style={{ fontFamily: "'DM Mono', monospace" }}>
                        {FRAME_STYLE_LABELS[frameStyle] ?? frameStyle}
                      </p>
                      {hasCustomTransform && (
                        <span className="flex items-center gap-0.5 text-[9px] px-1 py-0.5 rounded"
                          style={{ color: "#60A5FA", backgroundColor: "#60A5FA15", fontFamily: "'DM Mono', monospace" }}>
                          <Move style={{ width: 7, height: 7 }} />pos
                        </span>
                      )}
                    </div>

                    <p className="text-[#9CA3AF] text-xs mb-3" style={{ fontFamily: "'DM Mono', monospace" }}>{item.price_coins} coins</p>

                    {/* Actions */}
                    <div className="flex items-center gap-2">
                      <button onClick={() => openEdit(item)}
                        className={`flex items-center gap-1.5 text-xs px-2.5 py-1.5 rounded-md transition-colors ${
                          isEditing ? "bg-[#FBBF24]/20 text-[#FBBF24]" : "bg-[#2A2D34] text-[#9CA3AF] hover:bg-[#3A3D44] hover:text-white"
                        }`}
                        style={{ fontFamily: "'DM Mono', monospace" }}>
                        <Pencil className="w-3 h-3" />
                        {isEditing ? "Editando" : "Editar"}
                      </button>
                      <button onClick={() => toggleActive(item)}
                        className={`flex items-center gap-1.5 text-xs px-2.5 py-1.5 rounded-md transition-colors ${
                          item.is_active ? "bg-green-500/10 text-green-400 hover:bg-green-500/20" : "bg-[#2A2D34] text-[#9CA3AF] hover:bg-[#3A3D44]"
                        }`}
                        style={{ fontFamily: "'DM Mono', monospace" }}>
                        {item.is_active ? <><CheckCircle2 className="w-3 h-3" />Ativa</> : <><AlertCircle className="w-3 h-3" />Inativa</>}
                      </button>
                      <button onClick={() => deleteFrame(item)} className="ml-auto p-1.5 rounded-md text-[#4B5563] hover:text-red-400 hover:bg-red-500/10 transition-colors">
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
