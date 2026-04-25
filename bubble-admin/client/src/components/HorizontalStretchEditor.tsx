/**
 * HorizontalStretchEditor
 *
 * Editor dedicado ao modo horizontal_stretch.
 * No modo horizontal_stretch, o topo e a base são FIXOS — apenas as bordas
 * esquerda (sliceLeft) e direita (sliceRight) definem onde o centro começa a
 * esticar. Por isso, este componente exibe apenas duas linhas verticais
 * arrastáveis, com overlays escurecidos nas áreas fixas e um ícone <-> na
 * área central que estica.
 */

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { ArrowLeftRight, Move } from "lucide-react";

// ─── Tipos ────────────────────────────────────────────────────────────────────

export interface SliceValues {
  top: number;
  bottom: number;
  left: number;
  right: number;
}

export interface HorizontalStretchEditorProps {
  imageUrl: string;
  imageDimensions: { w: number; h: number } | null;
  slice: SliceValues;
  onChange: (s: SliceValues) => void;
  // Preview props (passadas para o NineSlicePreviewPanel externo, se necessário)
  textColor?: string;
  fontSize?: number;
  padTop?: number;
  padBottom?: number;
  padLeft?: number;
  padRight?: number;
  // Parâmetros do modo horizontal_stretch
  hsMaxWidth?: number;
  hsMinWidth?: number;
  hsPaddingX?: number;
  hsPaddingY?: number;
}

// ─── Constantes ───────────────────────────────────────────────────────────────

const MIN_CENTER = 4;   // px mínimos para a área central
const HIT        = 12;  // tolerância de hit em px
const LINE_COLOR = "#34D399";
const OVERLAY_BG = "rgba(0,0,0,0.32)";

// ─── Componente ───────────────────────────────────────────────────────────────

export function HorizontalStretchEditor({
  imageUrl,
  imageDimensions,
  slice,
  onChange,
}: HorizontalStretchEditorProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [canvasSize, setCanvasSize]   = useState({ w: 280, h: 280 });
  const [dragging, setDragging]       = useState<"left" | "right" | null>(null);
  const [hovering, setHovering]       = useState<"left" | "right" | null>(null);
  const dragStart = useRef<{ x: number; value: number } | null>(null);

  // ── Observa redimensionamento do container ──────────────────────────────────
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

  const imgW  = imageDimensions?.w ?? 128;
  const imgH  = imageDimensions?.h ?? 128;
  const scaleX = canvasSize.w / imgW;

  // Posição das linhas em px no canvas
  const leftPx  = slice.left  * scaleX;
  const rightPx = canvasSize.w - slice.right * scaleX;

  // ── Hit detection ───────────────────────────────────────────────────────────
  const getHandleAt = useCallback((x: number): "left" | "right" | null => {
    if (Math.abs(x - leftPx)  < HIT) return "left";
    if (Math.abs(x - rightPx) < HIT) return "right";
    return null;
  }, [leftPx, rightPx]);

  // ── Mouse handlers ──────────────────────────────────────────────────────────
  const onMouseDown = useCallback((e: React.MouseEvent) => {
    const rect = containerRef.current!.getBoundingClientRect();
    const x    = e.clientX - rect.left;
    const handle = getHandleAt(x);
    if (!handle) return;
    e.preventDefault();
    setDragging(handle);
    dragStart.current = { x, value: slice[handle] };
  }, [getHandleAt, slice]);

  const onMouseMove = useCallback((e: React.MouseEvent) => {
    const rect = containerRef.current!.getBoundingClientRect();
    const x    = e.clientX - rect.left;

    if (!dragging || !dragStart.current) {
      setHovering(getHandleAt(x));
      return;
    }
    e.preventDefault();

    const dx = x - dragStart.current.x;
    let newVal: number;

    if (dragging === "left") {
      const maxLeft = imgW - slice.right - MIN_CENTER;
      newVal = Math.max(0, Math.min(Math.round(dragStart.current.value + dx / scaleX), maxLeft));
      onChange({ ...slice, left: newVal });
    } else {
      const maxRight = imgW - slice.left - MIN_CENTER;
      newVal = Math.max(0, Math.min(Math.round(dragStart.current.value - dx / scaleX), maxRight));
      onChange({ ...slice, right: newVal });
    }
  }, [dragging, getHandleAt, slice, onChange, imgW, scaleX]);

  const onMouseUp = useCallback(() => {
    setDragging(null);
    dragStart.current = null;
  }, []);

  // ── Touch handlers (mobile) ─────────────────────────────────────────────────
  const onTouchStart = useCallback((e: React.TouchEvent) => {
    const rect   = containerRef.current!.getBoundingClientRect();
    const touch  = e.touches[0];
    const x      = touch.clientX - rect.left;
    const handle = getHandleAt(x);
    if (!handle) return;
    e.preventDefault();
    setDragging(handle);
    dragStart.current = { x, value: slice[handle] };
  }, [getHandleAt, slice]);

  const onTouchMove = useCallback((e: React.TouchEvent) => {
    if (!dragging || !dragStart.current) return;
    e.preventDefault();
    const rect  = containerRef.current!.getBoundingClientRect();
    const touch = e.touches[0];
    const x     = touch.clientX - rect.left;
    const dx    = x - dragStart.current.x;
    let newVal: number;

    if (dragging === "left") {
      const maxLeft = imgW - slice.right - MIN_CENTER;
      newVal = Math.max(0, Math.min(Math.round(dragStart.current.value + dx / scaleX), maxLeft));
      onChange({ ...slice, left: newVal });
    } else {
      const maxRight = imgW - slice.left - MIN_CENTER;
      newVal = Math.max(0, Math.min(Math.round(dragStart.current.value - dx / scaleX), maxRight));
      onChange({ ...slice, right: newVal });
    }
  }, [dragging, slice, onChange, imgW, scaleX]);

  // ── Cursor ──────────────────────────────────────────────────────────────────
  const cursor = (dragging || hovering) ? "ew-resize" : "default";

  // ── Estilo das linhas ───────────────────────────────────────────────────────
  function lineStyle(handle: "left" | "right"): React.CSSProperties {
    const active = dragging === handle || hovering === handle;
    return {
      position: "absolute",
      top: 0, bottom: 0,
      width: active ? 2 : 1.5,
      background: active ? LINE_COLOR : `${LINE_COLOR}99`,
      cursor: "ew-resize",
      zIndex: 10,
      transition: dragging ? "none" : "background 0.15s, width 0.1s",
    };
  }

  // ── Validação dos inputs numéricos ──────────────────────────────────────────
  function handleInputChange(key: "left" | "right", raw: string) {
    const val  = Math.max(0, parseInt(raw) || 0);
    const next = { ...slice, [key]: val };
    if (key === "left")  next.left  = Math.min(val, imgW - next.right - MIN_CENTER);
    if (key === "right") next.right = Math.min(val, imgW - next.left  - MIN_CENTER);
    onChange(next);
  }

  // ── Largura da área central em px (para o ícone) ────────────────────────────
  const centerWidth = useMemo(() => Math.max(0, rightPx - leftPx), [leftPx, rightPx]);
  const centerMid   = useMemo(() => leftPx + centerWidth / 2, [leftPx, centerWidth]);
  const showIcon    = centerWidth > 32;

  return (
    <div className="space-y-3">

      {/* ── Legenda ── */}
      <div className="flex items-center gap-3 flex-wrap">
        <div className="flex items-center gap-1.5">
          <div className="w-0.5 h-4 rounded" style={{ background: LINE_COLOR }} />
          <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.35)" }}>
            Esq. / Dir. — arraste para ajustar
          </span>
        </div>
        <div className="flex items-center gap-1.5">
          <div className="w-4 h-0.5 rounded" style={{ background: "rgba(255,255,255,0.15)" }} />
          <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.25)" }}>
            Topo / Base fixos
          </span>
        </div>
        <div className="flex items-center gap-1.5 ml-auto">
          <Move size={10} style={{ color: "rgba(255,255,255,0.25)" }} />
          <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.25)" }}>
            Arraste as linhas
          </span>
        </div>
      </div>

      {/* ── Canvas interativo ── */}
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
        }}
        onMouseDown={onMouseDown}
        onMouseMove={onMouseMove}
        onMouseUp={onMouseUp}
        onMouseLeave={onMouseUp}
        onTouchStart={onTouchStart}
        onTouchMove={onTouchMove}
        onTouchEnd={onMouseUp}
      >
        {/* Imagem de fundo */}
        <img
          src={imageUrl}
          alt="bubble"
          draggable={false}
          style={{
            position: "absolute", inset: 0,
            width: "100%", height: "100%",
            objectFit: "fill", pointerEvents: "none",
          }}
        />

        {/* ── Overlays: áreas fixas (esquerda e direita) ── */}
        <div style={{ position: "absolute", inset: 0, pointerEvents: "none" }}>
          {/* Overlay esquerdo — área fixa */}
          <div style={{
            position: "absolute", left: 0, top: 0, bottom: 0,
            width: leftPx,
            background: OVERLAY_BG,
          }} />
          {/* Overlay direito — área fixa */}
          <div style={{
            position: "absolute", right: 0, top: 0, bottom: 0,
            left: rightPx,
            background: OVERLAY_BG,
          }} />
        </div>

        {/* ── Destaque da área central que estica ── */}
        <div style={{
          position: "absolute", top: 0, bottom: 0,
          left: leftPx, width: centerWidth,
          border: "1px dashed rgba(52,211,153,0.3)",
          pointerEvents: "none",
          boxSizing: "border-box",
        }} />

        {/* ── Ícone <-> no centro ── */}
        {showIcon && (
          <div style={{
            position: "absolute",
            left: centerMid,
            top: "50%",
            transform: "translate(-50%, -50%)",
            pointerEvents: "none",
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            gap: 3,
          }}>
            <ArrowLeftRight
              size={16}
              style={{ color: `${LINE_COLOR}cc` }}
            />
            <span style={{
              fontSize: 8,
              fontFamily: "'DM Mono', monospace",
              color: `${LINE_COLOR}99`,
              background: "rgba(0,0,0,0.55)",
              padding: "1px 4px",
              borderRadius: 3,
              whiteSpace: "nowrap",
            }}>
              estica
            </span>
          </div>
        )}

        {/* ── Linha Esquerda ── */}
        <div style={{ ...lineStyle("left"), left: leftPx - 0.75 }}>
          {/* Label flutuante durante drag ou hover */}
          {(dragging === "left" || hovering === "left") && (
            <div style={{
              position: "absolute",
              left: 6, top: 4,
              fontSize: 9,
              fontFamily: "'DM Mono', monospace",
              color: LINE_COLOR,
              background: "rgba(0,0,0,0.75)",
              padding: "2px 5px",
              borderRadius: 4,
              whiteSpace: "nowrap",
              writingMode: "vertical-rl",
              transform: "rotate(180deg)",
              pointerEvents: "none",
            }}>
              L: {slice.left}px
            </div>
          )}
          {/* Label sempre visível (menor) */}
          {!(dragging === "left" || hovering === "left") && (
            <div style={{
              position: "absolute",
              left: 4, top: 4,
              fontSize: 8,
              fontFamily: "'DM Mono', monospace",
              color: `${LINE_COLOR}99`,
              background: "rgba(0,0,0,0.6)",
              padding: "1px 3px",
              borderRadius: 3,
              whiteSpace: "nowrap",
              writingMode: "vertical-rl",
              transform: "rotate(180deg)",
              pointerEvents: "none",
            }}>
              L: {slice.left}
            </div>
          )}
        </div>

        {/* ── Linha Direita ── */}
        <div style={{ ...lineStyle("right"), left: rightPx - 0.75 }}>
          {(dragging === "right" || hovering === "right") && (
            <div style={{
              position: "absolute",
              right: 6, top: 4,
              fontSize: 9,
              fontFamily: "'DM Mono', monospace",
              color: LINE_COLOR,
              background: "rgba(0,0,0,0.75)",
              padding: "2px 5px",
              borderRadius: 4,
              whiteSpace: "nowrap",
              writingMode: "vertical-rl",
              pointerEvents: "none",
            }}>
              R: {slice.right}px
            </div>
          )}
          {!(dragging === "right" || hovering === "right") && (
            <div style={{
              position: "absolute",
              right: 4, top: 4,
              fontSize: 8,
              fontFamily: "'DM Mono', monospace",
              color: `${LINE_COLOR}99`,
              background: "rgba(0,0,0,0.6)",
              padding: "1px 3px",
              borderRadius: 3,
              whiteSpace: "nowrap",
              writingMode: "vertical-rl",
              pointerEvents: "none",
            }}>
              R: {slice.right}
            </div>
          )}
        </div>

        {/* ── Labels de região ── */}
        {/* Esquerda fixa */}
        <div style={{
          position: "absolute",
          left: leftPx / 2, top: "50%",
          transform: "translate(-50%, -50%)",
          fontSize: 8, fontFamily: "'DM Mono', monospace",
          color: "rgba(255,255,255,0.3)", background: "rgba(0,0,0,0.5)",
          padding: "1px 3px", borderRadius: 3, pointerEvents: "none",
        }}>
          L (fixo)
        </div>
        {/* Direita fixa */}
        <div style={{
          position: "absolute",
          left: (rightPx + canvasSize.w) / 2, top: "50%",
          transform: "translate(-50%, -50%)",
          fontSize: 8, fontFamily: "'DM Mono', monospace",
          color: "rgba(255,255,255,0.3)", background: "rgba(0,0,0,0.5)",
          padding: "1px 3px", borderRadius: 3, pointerEvents: "none",
        }}>
          R (fixo)
        </div>
      </div>

      {/* ── Inputs numéricos ── */}
      <div className="grid grid-cols-2 gap-3">
        {([
          { label: "Esquerda (sliceLeft)",  key: "left"  as const },
          { label: "Direita (sliceRight)",  key: "right" as const },
        ]).map(({ label, key }) => (
          <div key={key}>
            <label
              className="text-[9px] font-mono block mb-1"
              style={{ color: "rgba(255,255,255,0.3)" }}
            >
              {label}
            </label>
            <input
              type="number"
              min={0}
              value={slice[key]}
              onChange={(e) => handleInputChange(key, e.target.value)}
              className="w-full px-2 py-1.5 rounded-lg text-[12px] outline-none font-mono text-center"
              style={{
                background: "rgba(255,255,255,0.04)",
                border: `1px solid ${LINE_COLOR}30`,
                color: LINE_COLOR,
              }}
            />
          </div>
        ))}
      </div>

      {/* ── Nota informativa ── */}
      <p className="text-[9px] font-mono leading-relaxed" style={{ color: "rgba(255,255,255,0.2)" }}>
        No modo <span style={{ color: "#FBBF24" }}>horizontal_stretch</span>, o topo e a base são sempre fixos.
        Apenas a faixa central entre as duas linhas verdes estica horizontalmente.
      </p>
    </div>
  );
}

export default HorizontalStretchEditor;
