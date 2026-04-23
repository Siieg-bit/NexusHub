/**
 * ThemesDashboard — Sistema completo de criação e personalização de temas
 *
 * Funcionalidades:
 *  - Lista de temas com preview de paleta de cores
 *  - Criação de novo tema (do zero ou duplicando existente)
 *  - Editor visual com color pickers para cada token semântico
 *  - Sliders para opacidades
 *  - Editor de gradientes (2 cores + direção)
 *  - Preview em tempo real simulando o app (bottom nav, cards, botões, chips, inputs)
 *  - Ativação/desativação de temas
 *  - Proteção de temas built-in (não podem ser deletados)
 *  - Persistência no Supabase (tabela app_themes)
 *
 * Design: Stark Admin Precision — #111214, surface #1C1E22, accent #E040FB
 */

import { useState, useCallback, useEffect, useRef } from "react";
import { supabase } from "@/lib/supabase";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { toast } from "sonner";
import {
  Palette,
  Plus,
  Trash2,
  CheckCircle2,
  AlertCircle,
  Loader2,
  Copy,
  Eye,
  EyeOff,
  ChevronDown,
  ChevronRight,
  Sun,
  Moon,
  Save,
  RefreshCw,
  Sparkles,
  Lock,
  Pencil,
  X,
} from "lucide-react";

// ─── Tipos ────────────────────────────────────────────────────────────────────

type GradientDef = {
  colors: string[];
  begin: string;
  end: string;
};

type ShadowDef = {
  color: string;
  blurRadius: number;
  offsetX: number;
  offsetY: number;
};

type ThemeColors = Record<string, string>;
type ThemeGradients = Record<string, GradientDef>;
type ThemeShadows = Record<string, ShadowDef[]>;
type ThemeOpacities = Record<string, number>;

type AppTheme = {
  id: string;
  slug: string;
  name: string;
  description: string;
  base_mode: "dark" | "light";
  colors: ThemeColors;
  gradients: ThemeGradients;
  shadows: ThemeShadows;
  opacities: ThemeOpacities;
  is_active: boolean;
  is_builtin: boolean;
  sort_order: number;
  created_at: string;
};

// ─── Definição dos grupos de tokens ──────────────────────────────────────────

const COLOR_GROUPS: { label: string; keys: string[] }[] = [
  {
    label: "Fundos",
    keys: ["backgroundPrimary", "backgroundSecondary"],
  },
  {
    label: "Superfícies",
    keys: [
      "surfacePrimary",
      "surfaceSecondary",
      "cardBackground",
      "cardBackgroundElevated",
      "modalBackground",
    ],
  },
  {
    label: "Overlay",
    keys: ["overlayColor"],
  },
  {
    label: "Textos",
    keys: ["textPrimary", "textSecondary", "textHint", "textDisabled"],
  },
  {
    label: "Ícones",
    keys: ["iconPrimary", "iconSecondary", "iconDisabled"],
  },
  {
    label: "Acentos",
    keys: ["accentPrimary", "accentSecondary"],
  },
  {
    label: "Botões",
    keys: [
      "buttonPrimaryBackground",
      "buttonPrimaryForeground",
      "buttonSecondaryBackground",
      "buttonSecondaryForeground",
      "buttonDestructiveBackground",
      "buttonDestructiveForeground",
    ],
  },
  {
    label: "Estados",
    keys: [
      "success",
      "successContainer",
      "error",
      "errorContainer",
      "warning",
      "warningContainer",
      "info",
      "infoContainer",
    ],
  },
  {
    label: "Bordas",
    keys: ["borderPrimary", "borderSubtle", "borderFocus"],
  },
  {
    label: "Inputs",
    keys: ["inputBackground", "inputBorder", "inputHint"],
  },
  {
    label: "Interação",
    keys: ["selectedState", "disabledState"],
  },
  {
    label: "Bottom Nav",
    keys: [
      "bottomNavBackground",
      "bottomNavSelectedItem",
      "bottomNavUnselectedItem",
    ],
  },
  {
    label: "App Bar",
    keys: ["appBarBackground", "appBarForeground"],
  },
  {
    label: "Drawer",
    keys: [
      "drawerBackground",
      "drawerHeaderBackground",
      "drawerSidebarBackground",
    ],
  },
  {
    label: "Chips",
    keys: [
      "chipBackground",
      "chipSelectedBackground",
      "chipText",
      "chipSelectedText",
    ],
  },
  {
    label: "Misc",
    keys: [
      "divider",
      "shimmerBase",
      "shimmerHighlight",
      "levelBadgeBackground",
      "levelBadgeForeground",
      "coinColor",
      "onlineIndicator",
      "previewAccent",
    ],
  },
];

const GRADIENT_KEYS = [
  "primaryGradient",
  "accentGradient",
  "fabGradient",
  "streakGradient",
  "walletGradient",
  "aminoPlusGradient",
];

const GRADIENT_DIRECTIONS = [
  "topLeft",
  "topCenter",
  "topRight",
  "centerLeft",
  "center",
  "centerRight",
  "bottomLeft",
  "bottomCenter",
  "bottomRight",
];

const SHADOW_KEYS = ["cardShadow", "modalShadow", "buttonShadow"];

// ─── Tema padrão para novo tema ───────────────────────────────────────────────

const DEFAULT_COLORS: ThemeColors = {
  backgroundPrimary: "#111214",
  backgroundSecondary: "#1C1E22",
  surfacePrimary: "#1C1E22",
  surfaceSecondary: "#252830",
  cardBackground: "#1C1E22",
  cardBackgroundElevated: "#252830",
  modalBackground: "#1C1E22",
  overlayColor: "#000000",
  textPrimary: "#F0F0F5",
  textSecondary: "#9CA3AF",
  textHint: "#6B7280",
  textDisabled: "#374151",
  iconPrimary: "#F0F0F5",
  iconSecondary: "#9CA3AF",
  iconDisabled: "#374151",
  accentPrimary: "#E040FB",
  accentSecondary: "#CE30E8",
  buttonPrimaryBackground: "#E040FB",
  buttonPrimaryForeground: "#000000",
  buttonSecondaryBackground: "#2A1A2E",
  buttonSecondaryForeground: "#E040FB",
  buttonDestructiveBackground: "#CF6679",
  buttonDestructiveForeground: "#FFFFFF",
  success: "#4ADE80",
  successContainer: "#052E16",
  error: "#F87171",
  errorContainer: "#3B0A0A",
  warning: "#FBBF24",
  warningContainer: "#2D1A00",
  info: "#60A5FA",
  infoContainer: "#0A1A3B",
  borderPrimary: "#2A2D34",
  borderSubtle: "#1E2028",
  borderFocus: "#E040FB",
  inputBackground: "#252830",
  inputBorder: "#2A2D34",
  inputHint: "#6B7280",
  selectedState: "#E040FB",
  disabledState: "#374151",
  bottomNavBackground: "#111214",
  bottomNavSelectedItem: "#E040FB",
  bottomNavUnselectedItem: "#6B7280",
  appBarBackground: "#111214",
  appBarForeground: "#F0F0F5",
  drawerBackground: "#1C1E22",
  drawerHeaderBackground: "#252830",
  drawerSidebarBackground: "#2A1A2E",
  chipBackground: "#252830",
  chipSelectedBackground: "#E040FB",
  chipText: "#9CA3AF",
  chipSelectedText: "#000000",
  divider: "#2A2D34",
  shimmerBase: "#252830",
  shimmerHighlight: "#2A2D34",
  levelBadgeBackground: "#E040FB",
  levelBadgeForeground: "#000000",
  coinColor: "#FFD700",
  onlineIndicator: "#4ADE80",
  previewAccent: "#E040FB",
};

const DEFAULT_GRADIENTS: ThemeGradients = {
  primaryGradient: {
    colors: ["#E040FB", "#CE30E8"],
    begin: "topLeft",
    end: "bottomRight",
  },
  accentGradient: {
    colors: ["#CE30E8", "#A020C8"],
    begin: "topLeft",
    end: "bottomRight",
  },
  fabGradient: {
    colors: ["#E040FB", "#CE30E8"],
    begin: "topLeft",
    end: "bottomRight",
  },
  streakGradient: {
    colors: ["#FF6D00", "#FFAB40"],
    begin: "centerLeft",
    end: "centerRight",
  },
  walletGradient: {
    colors: ["#E040FB", "#CE30E8"],
    begin: "topCenter",
    end: "bottomCenter",
  },
  aminoPlusGradient: {
    colors: ["#E040FB", "#CE30E8"],
    begin: "centerLeft",
    end: "centerRight",
  },
};

const DEFAULT_SHADOWS: ThemeShadows = {
  cardShadow: [
    { color: "#00000066", blurRadius: 8, offsetX: 0, offsetY: 2 },
  ],
  modalShadow: [
    { color: "#00000099", blurRadius: 24, offsetX: 0, offsetY: 8 },
  ],
  buttonShadow: [
    { color: "#E040FB40", blurRadius: 12, offsetX: 0, offsetY: 4 },
  ],
};

const DEFAULT_OPACITIES: ThemeOpacities = {
  overlayOpacity: 0.6,
  disabledOpacity: 0.38,
};

// ─── Helpers ──────────────────────────────────────────────────────────────────

function hexToLabel(key: string): string {
  return key
    .replace(/([A-Z])/g, " $1")
    .replace(/^./, (s) => s.toUpperCase())
    .trim();
}

function gradientCss(g: GradientDef): string {
  const dirMap: Record<string, string> = {
    topLeft: "135deg",
    topCenter: "180deg",
    topRight: "225deg",
    centerLeft: "90deg",
    center: "90deg",
    centerRight: "270deg",
    bottomLeft: "315deg",
    bottomCenter: "0deg",
    bottomRight: "45deg",
  };
  const deg = dirMap[g.begin] ?? "135deg";
  return `linear-gradient(${deg}, ${g.colors[0]}, ${g.colors[1] ?? g.colors[0]})`;
}

// ─── Componente: Color Token Row ──────────────────────────────────────────────

function ColorRow({
  tokenKey,
  value,
  onChange,
}: {
  tokenKey: string;
  value: string;
  onChange: (key: string, val: string) => void;
}) {
  const inputRef = useRef<HTMLInputElement>(null);
  return (
    <div className="flex items-center gap-3 py-1.5">
      <button
        onClick={() => inputRef.current?.click()}
        className="w-7 h-7 rounded-md border border-[#2A2D34] flex-shrink-0 cursor-pointer hover:scale-110 transition-transform"
        style={{ background: value }}
        title={value}
      />
      <input
        ref={inputRef}
        type="color"
        value={value.length === 7 ? value : "#000000"}
        onChange={(e) => onChange(tokenKey, e.target.value)}
        className="sr-only"
      />
      <span
        className="text-[#9CA3AF] text-xs flex-1 truncate"
        style={{ fontFamily: "'DM Mono', monospace" }}
      >
        {hexToLabel(tokenKey)}
      </span>
      <input
        type="text"
        value={value}
        onChange={(e) => {
          const v = e.target.value;
          if (/^#[0-9A-Fa-f]{0,8}$/.test(v)) onChange(tokenKey, v);
        }}
        className="w-24 bg-[#1C1E22] border border-[#2A2D34] rounded px-2 py-0.5 text-xs text-white focus:outline-none focus:border-[#E040FB]"
        style={{ fontFamily: "'DM Mono', monospace" }}
      />
    </div>
  );
}

// ─── Componente: Gradient Editor ──────────────────────────────────────────────

function GradientRow({
  gradKey,
  value,
  onChange,
}: {
  gradKey: string;
  value: GradientDef;
  onChange: (key: string, val: GradientDef) => void;
}) {
  const c0Ref = useRef<HTMLInputElement>(null);
  const c1Ref = useRef<HTMLInputElement>(null);
  return (
    <div className="py-2 space-y-2">
      <div className="flex items-center gap-2">
        <div
          className="h-5 flex-1 rounded"
          style={{ background: gradientCss(value) }}
        />
        <span
          className="text-[#9CA3AF] text-xs"
          style={{ fontFamily: "'DM Mono', monospace" }}
        >
          {hexToLabel(gradKey)}
        </span>
      </div>
      <div className="flex items-center gap-2 pl-1">
        {/* Cor 0 */}
        <button
          onClick={() => c0Ref.current?.click()}
          className="w-6 h-6 rounded border border-[#2A2D34] flex-shrink-0 cursor-pointer"
          style={{ background: value.colors[0] }}
        />
        <input
          ref={c0Ref}
          type="color"
          value={value.colors[0]}
          onChange={(e) =>
            onChange(gradKey, {
              ...value,
              colors: [e.target.value, value.colors[1] ?? value.colors[0]],
            })
          }
          className="sr-only"
        />
        <span className="text-[#6B7280] text-xs">→</span>
        {/* Cor 1 */}
        <button
          onClick={() => c1Ref.current?.click()}
          className="w-6 h-6 rounded border border-[#2A2D34] flex-shrink-0 cursor-pointer"
          style={{ background: value.colors[1] ?? value.colors[0] }}
        />
        <input
          ref={c1Ref}
          type="color"
          value={value.colors[1] ?? value.colors[0]}
          onChange={(e) =>
            onChange(gradKey, {
              ...value,
              colors: [value.colors[0], e.target.value],
            })
          }
          className="sr-only"
        />
        {/* Direção */}
        <select
          value={value.begin}
          onChange={(e) =>
            onChange(gradKey, { ...value, begin: e.target.value })
          }
          className="ml-auto bg-[#1C1E22] border border-[#2A2D34] rounded px-2 py-0.5 text-xs text-[#9CA3AF] focus:outline-none focus:border-[#E040FB]"
          style={{ fontFamily: "'DM Mono', monospace" }}
        >
          {GRADIENT_DIRECTIONS.map((d) => (
            <option key={d} value={d}>
              {d}
            </option>
          ))}
        </select>
      </div>
    </div>
  );
}

// ─── Componente: Shadow Editor ────────────────────────────────────────────────

function ShadowRow({
  shadowKey,
  value,
  onChange,
}: {
  shadowKey: string;
  value: ShadowDef[];
  onChange: (key: string, val: ShadowDef[]) => void;
}) {
  const shadow = value[0] ?? {
    color: "#00000066",
    blurRadius: 8,
    offsetX: 0,
    offsetY: 2,
  };
  const colorRef = useRef<HTMLInputElement>(null);
  const update = (partial: Partial<ShadowDef>) =>
    onChange(shadowKey, [{ ...shadow, ...partial }]);

  return (
    <div className="py-2 space-y-1.5">
      <span
        className="text-[#9CA3AF] text-xs"
        style={{ fontFamily: "'DM Mono', monospace" }}
      >
        {hexToLabel(shadowKey)}
      </span>
      <div className="flex items-center gap-3 pl-1 flex-wrap">
        <div className="flex items-center gap-1.5">
          <button
            onClick={() => colorRef.current?.click()}
            className="w-5 h-5 rounded border border-[#2A2D34] cursor-pointer"
            style={{ background: shadow.color }}
          />
          <input
            ref={colorRef}
            type="color"
            value={shadow.color.slice(0, 7)}
            onChange={(e) => update({ color: e.target.value })}
            className="sr-only"
          />
          <span className="text-[#6B7280] text-[10px]">cor</span>
        </div>
        <div className="flex items-center gap-1">
          <span className="text-[#6B7280] text-[10px]">blur</span>
          <input
            type="number"
            value={shadow.blurRadius}
            min={0}
            max={60}
            onChange={(e) => update({ blurRadius: Number(e.target.value) })}
            className="w-12 bg-[#1C1E22] border border-[#2A2D34] rounded px-1.5 py-0.5 text-xs text-white focus:outline-none focus:border-[#E040FB]"
            style={{ fontFamily: "'DM Mono', monospace" }}
          />
        </div>
        <div className="flex items-center gap-1">
          <span className="text-[#6B7280] text-[10px]">x</span>
          <input
            type="number"
            value={shadow.offsetX}
            min={-20}
            max={20}
            onChange={(e) => update({ offsetX: Number(e.target.value) })}
            className="w-12 bg-[#1C1E22] border border-[#2A2D34] rounded px-1.5 py-0.5 text-xs text-white focus:outline-none focus:border-[#E040FB]"
            style={{ fontFamily: "'DM Mono', monospace" }}
          />
        </div>
        <div className="flex items-center gap-1">
          <span className="text-[#6B7280] text-[10px]">y</span>
          <input
            type="number"
            value={shadow.offsetY}
            min={-20}
            max={20}
            onChange={(e) => update({ offsetY: Number(e.target.value) })}
            className="w-12 bg-[#1C1E22] border border-[#2A2D34] rounded px-1.5 py-0.5 text-xs text-white focus:outline-none focus:border-[#E040FB]"
            style={{ fontFamily: "'DM Mono', monospace" }}
          />
        </div>
      </div>
    </div>
  );
}

// ─── Componente: Preview do App ───────────────────────────────────────────────

function AppPreview({ colors, gradients }: { colors: ThemeColors; gradients: ThemeGradients }) {
  const accent = colors.accentPrimary ?? "#E040FB";
  const bg = colors.backgroundPrimary ?? "#111214";
  const card = colors.cardBackground ?? "#1C1E22";
  const textPrimary = colors.textPrimary ?? "#F0F0F5";
  const textSecondary = colors.textSecondary ?? "#9CA3AF";
  const border = colors.borderPrimary ?? "#2A2D34";
  const bottomNav = colors.bottomNavBackground ?? "#111214";
  const bottomNavSelected = colors.bottomNavSelectedItem ?? accent;
  const bottomNavUnselected = colors.bottomNavUnselectedItem ?? "#6B7280";
  const appBar = colors.appBarBackground ?? bg;
  const appBarFg = colors.appBarForeground ?? textPrimary;
  const chipBg = colors.chipBackground ?? "#252830";
  const chipSel = colors.chipSelectedBackground ?? accent;
  const chipText = colors.chipText ?? textSecondary;
  const chipSelText = colors.chipSelectedText ?? "#000000";
  const inputBg = colors.inputBackground ?? "#252830";
  const inputBorder = colors.inputBorder ?? border;
  const btnPrimBg = colors.buttonPrimaryBackground ?? accent;
  const btnPrimFg = colors.buttonPrimaryForeground ?? "#000000";
  const btnSecBg = colors.buttonSecondaryBackground ?? "#2A1A2E";
  const btnSecFg = colors.buttonSecondaryForeground ?? accent;
  const divider = colors.divider ?? border;
  const success = colors.onlineIndicator ?? "#4ADE80";
  const primaryGrad = gradients.primaryGradient;

  return (
    <div
      className="rounded-xl overflow-hidden border border-[#2A2D34] select-none"
      style={{ background: bg, width: 260, minHeight: 480, position: "relative", fontFamily: "'DM Sans', sans-serif" }}
    >
      {/* App Bar */}
      <div
        className="flex items-center justify-between px-3 py-2.5"
        style={{ background: appBar, borderBottom: `1px solid ${divider}` }}
      >
        <div className="flex items-center gap-2">
          <div className="w-7 h-7 rounded-full overflow-hidden" style={{ background: chipBg }}>
            <div className="w-full h-full flex items-center justify-center text-[10px]" style={{ color: textSecondary }}>A</div>
          </div>
          <div>
            <div className="text-[11px] font-bold" style={{ color: appBarFg }}>NexusHub</div>
            <div className="text-[9px]" style={{ color: textSecondary }}>Explorar</div>
          </div>
        </div>
        <div className="flex items-center gap-1.5">
          <div className="w-6 h-6 rounded-full" style={{ background: chipBg }} />
          <div className="w-6 h-6 rounded-full" style={{ background: chipBg }} />
        </div>
      </div>

      {/* Chips */}
      <div className="flex gap-1.5 px-3 py-2 overflow-hidden">
        {["Todos", "Trending", "Novo"].map((c, i) => (
          <div
            key={c}
            className="px-2.5 py-1 rounded-full text-[9px] font-medium flex-shrink-0"
            style={{
              background: i === 0 ? chipSel : chipBg,
              color: i === 0 ? chipSelText : chipText,
            }}
          >
            {c}
          </div>
        ))}
      </div>

      {/* Featured Card */}
      <div className="px-3 mb-2">
        <div
          className="rounded-xl p-3 relative overflow-hidden"
          style={{
            background: primaryGrad
              ? gradientCss(primaryGrad)
              : `linear-gradient(135deg, ${accent}, ${colors.accentSecondary ?? accent})`,
            minHeight: 80,
          }}
        >
          <div className="text-[11px] font-bold text-white mb-0.5">Comunidade em Destaque</div>
          <div className="text-[9px] text-white/70">12.4k membros • Trending</div>
          <div
            className="absolute bottom-2 right-2 px-2 py-0.5 rounded-full text-[8px] font-bold"
            style={{ background: "rgba(255,255,255,0.2)", color: "#fff" }}
          >
            Entrar
          </div>
        </div>
      </div>

      {/* Post Cards */}
      {[1, 2].map((i) => (
        <div
          key={i}
          className="mx-3 mb-2 rounded-xl p-3"
          style={{
            background: card,
            border: `1px solid ${border}`,
          }}
        >
          <div className="flex items-center gap-2 mb-2">
            <div
              className="w-6 h-6 rounded-full flex-shrink-0 flex items-center justify-center text-[8px] font-bold"
              style={{ background: accent, color: btnPrimFg }}
            >
              U
            </div>
            <div>
              <div className="text-[10px] font-semibold" style={{ color: textPrimary }}>
                Usuário {i}
              </div>
              <div className="text-[8px]" style={{ color: textSecondary }}>
                há 2h
              </div>
            </div>
            <div
              className="ml-auto w-1.5 h-1.5 rounded-full"
              style={{ background: success }}
            />
          </div>
          <div className="text-[10px] mb-2" style={{ color: textPrimary }}>
            Post de exemplo #{i} com conteúdo interessante...
          </div>
          <div className="flex items-center gap-2">
            <div
              className="px-2 py-0.5 rounded text-[8px]"
              style={{ background: chipBg, color: chipText }}
            >
              ♥ 42
            </div>
            <div
              className="px-2 py-0.5 rounded text-[8px]"
              style={{ background: chipBg, color: chipText }}
            >
              💬 8
            </div>
          </div>
        </div>
      ))}

      {/* Input */}
      <div className="px-3 mb-3">
        <div
          className="rounded-xl px-3 py-2 text-[10px]"
          style={{
            background: inputBg,
            border: `1px solid ${inputBorder}`,
            color: colors.inputHint ?? "#6B7280",
          }}
        >
          Escreva algo...
        </div>
      </div>

      {/* Buttons */}
      <div className="px-3 mb-3 flex gap-2">
        <div
          className="flex-1 py-1.5 rounded-lg text-[10px] font-bold text-center"
          style={{ background: btnPrimBg, color: btnPrimFg }}
        >
          Publicar
        </div>
        <div
          className="flex-1 py-1.5 rounded-lg text-[10px] font-bold text-center"
          style={{
            background: btnSecBg,
            color: btnSecFg,
            border: `1px solid ${accent}`,
          }}
        >
          Cancelar
        </div>
      </div>

      {/* Bottom Nav */}
      <div
        className="absolute bottom-0 left-0 right-0 flex items-center justify-around py-2 px-2"
        style={{
          background: bottomNav,
          borderTop: `1px solid ${divider}`,
        }}
      >
        {["🏠", "🔍", "➕", "💬", "👤"].map((icon, i) => (
          <div
            key={i}
            className="flex flex-col items-center gap-0.5"
          >
            <span className="text-sm">{icon}</span>
            {i === 0 && (
              <div
                className="w-1 h-1 rounded-full"
                style={{ background: bottomNavSelected }}
              />
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Componente: Paleta de cores (card de tema) ───────────────────────────────

function ThemePalette({ colors }: { colors: ThemeColors }) {
  const swatches = [
    colors.backgroundPrimary,
    colors.accentPrimary,
    colors.cardBackground,
    colors.textPrimary,
    colors.bottomNavSelectedItem,
    colors.success ?? colors.onlineIndicator,
  ].filter(Boolean) as string[];

  return (
    <div className="flex gap-1">
      {swatches.map((c, i) => (
        <div
          key={i}
          className="w-4 h-4 rounded-sm border border-white/10"
          style={{ background: c }}
          title={c}
        />
      ))}
    </div>
  );
}

// ─── Componente principal ─────────────────────────────────────────────────────

export default function ThemesDashboard() {
  const [themes, setThemes] = useState<AppTheme[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [previewOpen, setPreviewOpen] = useState(true);
  const [expandedGroups, setExpandedGroups] = useState<Set<string>>(
    new Set(["Fundos", "Acentos", "Botões"])
  );
  const [activeSection, setActiveSection] = useState<
    "colors" | "gradients" | "shadows" | "opacities"
  >("colors");

  // Estado de edição
  const [editName, setEditName] = useState("");
  const [editDescription, setEditDescription] = useState("");
  const [editBaseMode, setEditBaseMode] = useState<"dark" | "light">("dark");
  const [editColors, setEditColors] = useState<ThemeColors>(DEFAULT_COLORS);
  const [editGradients, setEditGradients] =
    useState<ThemeGradients>(DEFAULT_GRADIENTS);
  const [editShadows, setEditShadows] = useState<ThemeShadows>(DEFAULT_SHADOWS);
  const [editOpacities, setEditOpacities] =
    useState<ThemeOpacities>(DEFAULT_OPACITIES);
  const [isDirty, setIsDirty] = useState(false);

  // ── Carregar temas ──────────────────────────────────────────────────────────
  const loadThemes = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from("app_themes")
        .select("*")
        .order("sort_order", { ascending: true });
      if (error) throw error;
      setThemes((data as AppTheme[]) ?? []);
    } catch (e: unknown) {
      toast.error("Erro ao carregar temas: " + (e as Error).message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadThemes();
  }, [loadThemes]);

  // ── Selecionar tema para edição ─────────────────────────────────────────────
  const selectTheme = useCallback((theme: AppTheme) => {
    setSelectedId(theme.id);
    setEditName(theme.name);
    setEditDescription(theme.description ?? "");
    setEditBaseMode(theme.base_mode);
    setEditColors({ ...DEFAULT_COLORS, ...theme.colors });
    setEditGradients({ ...DEFAULT_GRADIENTS, ...theme.gradients });
    setEditShadows({ ...DEFAULT_SHADOWS, ...theme.shadows });
    setEditOpacities({ ...DEFAULT_OPACITIES, ...theme.opacities });
    setIsDirty(false);
  }, []);

  // ── Novo tema ───────────────────────────────────────────────────────────────
  const createNew = useCallback(() => {
    setSelectedId("__new__");
    setEditName("Novo Tema");
    setEditDescription("");
    setEditBaseMode("dark");
    setEditColors({ ...DEFAULT_COLORS });
    setEditGradients({ ...DEFAULT_GRADIENTS });
    setEditShadows({ ...DEFAULT_SHADOWS });
    setEditOpacities({ ...DEFAULT_OPACITIES });
    setIsDirty(true);
  }, []);

  // ── Duplicar tema ───────────────────────────────────────────────────────────
  const duplicateTheme = useCallback(
    (theme: AppTheme) => {
      setSelectedId("__new__");
      setEditName(theme.name + " (cópia)");
      setEditDescription(theme.description ?? "");
      setEditBaseMode(theme.base_mode);
      setEditColors({ ...DEFAULT_COLORS, ...theme.colors });
      setEditGradients({ ...DEFAULT_GRADIENTS, ...theme.gradients });
      setEditShadows({ ...DEFAULT_SHADOWS, ...theme.shadows });
      setEditOpacities({ ...DEFAULT_OPACITIES, ...theme.opacities });
      setIsDirty(true);
    },
    []
  );

  // ── Salvar tema ─────────────────────────────────────────────────────────────
  const saveTheme = useCallback(async () => {
    if (!editName.trim()) {
      toast.error("Nome do tema é obrigatório");
      return;
    }
    setSaving(true);
    try {
      const slug = editName
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "_")
        .replace(/^_|_$/g, "");

      const payload = {
        slug,
        name: editName.trim(),
        description: editDescription.trim(),
        base_mode: editBaseMode,
        colors: editColors,
        gradients: editGradients,
        shadows: editShadows,
        opacities: editOpacities,
      };

      if (selectedId === "__new__") {
        const { data, error } = await supabase
          .from("app_themes")
          .insert({ ...payload, is_active: true, sort_order: themes.length })
          .select()
          .single();
        if (error) throw error;
        setThemes((prev) => [...prev, data as AppTheme]);
        setSelectedId((data as AppTheme).id);
        toast.success("Tema criado com sucesso!");
      } else {
        const { error } = await supabase
          .from("app_themes")
          .update(payload)
          .eq("id", selectedId!);
        if (error) throw error;
        setThemes((prev) =>
          prev.map((t) =>
            t.id === selectedId ? { ...t, ...payload } : t
          )
        );
        toast.success("Tema salvo!");
      }
      setIsDirty(false);
    } catch (e: unknown) {
      toast.error("Erro ao salvar: " + (e as Error).message);
    } finally {
      setSaving(false);
    }
  }, [
    selectedId,
    editName,
    editDescription,
    editBaseMode,
    editColors,
    editGradients,
    editShadows,
    editOpacities,
    themes.length,
  ]);

  // ── Toggle ativo ────────────────────────────────────────────────────────────
  const toggleActive = useCallback(async (theme: AppTheme) => {
    try {
      const { error } = await supabase
        .from("app_themes")
        .update({ is_active: !theme.is_active })
        .eq("id", theme.id);
      if (error) throw error;
      setThemes((prev) =>
        prev.map((t) =>
          t.id === theme.id ? { ...t, is_active: !t.is_active } : t
        )
      );
    } catch (e: unknown) {
      toast.error("Erro: " + (e as Error).message);
    }
  }, []);

  // ── Deletar tema ────────────────────────────────────────────────────────────
  const deleteTheme = useCallback(
    async (theme: AppTheme) => {
      if (theme.is_builtin) {
        toast.error("Temas built-in não podem ser deletados");
        return;
      }
      if (!confirm(`Deletar o tema "${theme.name}"?`)) return;
      try {
        const { error } = await supabase
          .from("app_themes")
          .delete()
          .eq("id", theme.id);
        if (error) throw error;
        setThemes((prev) => prev.filter((t) => t.id !== theme.id));
        if (selectedId === theme.id) setSelectedId(null);
        toast.success("Tema deletado");
      } catch (e: unknown) {
        toast.error("Erro: " + (e as Error).message);
      }
    },
    [selectedId]
  );

  // ── Handlers de edição ──────────────────────────────────────────────────────
  const handleColorChange = useCallback((key: string, val: string) => {
    setEditColors((prev) => ({ ...prev, [key]: val }));
    setIsDirty(true);
  }, []);

  const handleGradientChange = useCallback((key: string, val: GradientDef) => {
    setEditGradients((prev) => ({ ...prev, [key]: val }));
    setIsDirty(true);
  }, []);

  const handleShadowChange = useCallback(
    (key: string, val: ShadowDef[]) => {
      setEditShadows((prev) => ({ ...prev, [key]: val }));
      setIsDirty(true);
    },
    []
  );

  const handleOpacityChange = useCallback((key: string, val: number) => {
    setEditOpacities((prev) => ({ ...prev, [key]: val }));
    setIsDirty(true);
  }, []);

  const toggleGroup = useCallback((label: string) => {
    setExpandedGroups((prev) => {
      const next = new Set(prev);
      if (next.has(label)) next.delete(label);
      else next.add(label);
      return next;
    });
  }, []);

  // ── Render ──────────────────────────────────────────────────────────────────
  const selectedTheme = themes.find((t) => t.id === selectedId);
  const isNew = selectedId === "__new__";

  return (
    <div className="flex h-[calc(100vh-112px)]">
      {/* ── Painel esquerdo: lista de temas ── */}
      <div
        className="w-72 flex-shrink-0 border-r border-[#2A2D34] flex flex-col"
        style={{ background: "#111214" }}
      >
        {/* Header da lista */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-[#2A2D34]">
          <span
            className="text-xs font-semibold text-[#9CA3AF] uppercase tracking-wider"
            style={{ fontFamily: "'DM Mono', monospace" }}
          >
            Temas ({themes.length})
          </span>
          <div className="flex items-center gap-1">
            <button
              onClick={loadThemes}
              className="p-1.5 rounded text-[#6B7280] hover:text-white hover:bg-[#2A2D34] transition-colors"
              title="Recarregar"
            >
              <RefreshCw className="w-3.5 h-3.5" />
            </button>
            <button
              onClick={createNew}
              className="flex items-center gap-1 px-2 py-1 rounded text-xs font-medium text-black transition-colors"
              style={{ background: "#E040FB", fontFamily: "'DM Mono', monospace" }}
            >
              <Plus className="w-3 h-3" />
              Novo
            </button>
          </div>
        </div>

        {/* Lista */}
        <div className="flex-1 overflow-y-auto">
          {loading ? (
            <div className="flex items-center justify-center h-32">
              <Loader2 className="w-5 h-5 text-[#E040FB] animate-spin" />
            </div>
          ) : themes.length === 0 ? (
            <div className="flex flex-col items-center justify-center h-32 gap-2 text-[#6B7280]">
              <Palette className="w-8 h-8" />
              <span className="text-xs">Nenhum tema</span>
            </div>
          ) : (
            <div className="py-1">
              {/* Item "Novo" se estiver criando */}
              {isNew && (
                <div
                  className="px-4 py-3 border-l-2 border-[#E040FB] bg-[#E040FB]/5"
                >
                  <div className="flex items-center gap-2 mb-1">
                    <Sparkles className="w-3.5 h-3.5 text-[#E040FB]" />
                    <span className="text-sm font-semibold text-white truncate">
                      {editName || "Novo Tema"}
                    </span>
                  </div>
                  <ThemePalette colors={editColors} />
                </div>
              )}

              {themes.map((theme) => (
                <div
                  key={theme.id}
                  onClick={() => selectTheme(theme)}
                  className={`px-4 py-3 cursor-pointer transition-colors border-l-2 ${
                    selectedId === theme.id && !isNew
                      ? "border-[#E040FB] bg-[#E040FB]/5"
                      : "border-transparent hover:bg-[#1C1E22]"
                  }`}
                >
                  <div className="flex items-center gap-2 mb-1">
                    {theme.base_mode === "dark" ? (
                      <Moon className="w-3 h-3 text-[#6B7280]" />
                    ) : (
                      <Sun className="w-3 h-3 text-[#6B7280]" />
                    )}
                    <span className="text-sm font-semibold text-white truncate flex-1">
                      {theme.name}
                    </span>
                    {theme.is_builtin && (
                      <span title="Built-in"><Lock className="w-3 h-3 text-[#6B7280]" /></span>
                    )}
                    {!theme.is_active && (
                      <span title="Inativo"><EyeOff className="w-3 h-3 text-[#6B7280]" /></span>
                    )}
                  </div>
                  <ThemePalette colors={theme.colors} />
                  {theme.description && (
                    <p className="text-[10px] text-[#6B7280] mt-1 truncate">
                      {theme.description}
                    </p>
                  )}
                  {/* Ações rápidas */}
                  <div
                    className="flex items-center gap-1 mt-2"
                    onClick={(e) => e.stopPropagation()}
                  >
                    <button
                      onClick={() => toggleActive(theme)}
                      className={`flex items-center gap-1 text-[10px] px-2 py-0.5 rounded transition-colors ${
                        theme.is_active
                          ? "bg-green-500/10 text-green-400 hover:bg-green-500/20"
                          : "bg-[#2A2D34] text-[#9CA3AF] hover:bg-[#3A3D44]"
                      }`}
                      style={{ fontFamily: "'DM Mono', monospace" }}
                    >
                      {theme.is_active ? (
                        <CheckCircle2 className="w-2.5 h-2.5" />
                      ) : (
                        <AlertCircle className="w-2.5 h-2.5" />
                      )}
                      {theme.is_active ? "Ativo" : "Inativo"}
                    </button>
                    <button
                      onClick={() => duplicateTheme(theme)}
                      className="p-1 rounded text-[#6B7280] hover:text-white hover:bg-[#2A2D34] transition-colors"
                      title="Duplicar"
                    >
                      <Copy className="w-3 h-3" />
                    </button>
                    {!theme.is_builtin && (
                      <button
                        onClick={() => deleteTheme(theme)}
                        className="p-1 rounded text-[#6B7280] hover:text-red-400 hover:bg-red-500/10 transition-colors"
                        title="Deletar"
                      >
                        <Trash2 className="w-3 h-3" />
                      </button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* ── Painel central: editor ── */}
      {selectedId ? (
        <div className="flex-1 flex overflow-hidden">
          {/* Editor de tokens */}
          <div className="flex-1 flex flex-col overflow-hidden">
            {/* Header do editor */}
            <div
              className="flex items-center gap-3 px-5 py-3 border-b border-[#2A2D34] flex-shrink-0"
              style={{ background: "#1C1E22" }}
            >
              <Pencil className="w-4 h-4 text-[#E040FB]" />
              <div className="flex-1 min-w-0">
                <input
                  type="text"
                  value={editName}
                  onChange={(e) => {
                    setEditName(e.target.value);
                    setIsDirty(true);
                  }}
                  className="bg-transparent text-white font-bold text-sm focus:outline-none w-full"
                  style={{ fontFamily: "'DM Sans', sans-serif" }}
                  placeholder="Nome do tema"
                />
                <input
                  type="text"
                  value={editDescription}
                  onChange={(e) => {
                    setEditDescription(e.target.value);
                    setIsDirty(true);
                  }}
                  className="bg-transparent text-[#6B7280] text-xs focus:outline-none w-full mt-0.5"
                  style={{ fontFamily: "'DM Sans', sans-serif" }}
                  placeholder="Descrição curta..."
                />
              </div>
              {/* Modo claro/escuro */}
              <button
                onClick={() => {
                  setEditBaseMode((m) => (m === "dark" ? "light" : "dark"));
                  setIsDirty(true);
                }}
                className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg border border-[#2A2D34] text-xs text-[#9CA3AF] hover:text-white hover:border-[#E040FB] transition-colors"
                style={{ fontFamily: "'DM Mono', monospace" }}
              >
                {editBaseMode === "dark" ? (
                  <Moon className="w-3.5 h-3.5" />
                ) : (
                  <Sun className="w-3.5 h-3.5" />
                )}
                {editBaseMode}
              </button>
              {/* Preview toggle */}
              <button
                onClick={() => setPreviewOpen((v) => !v)}
                className="p-1.5 rounded text-[#6B7280] hover:text-white hover:bg-[#2A2D34] transition-colors"
                title={previewOpen ? "Ocultar preview" : "Mostrar preview"}
              >
                {previewOpen ? (
                  <EyeOff className="w-4 h-4" />
                ) : (
                  <Eye className="w-4 h-4" />
                )}
              </button>
              {/* Salvar */}
              <button
                onClick={saveTheme}
                disabled={saving || !isDirty}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition-all ${
                  isDirty
                    ? "text-black"
                    : "text-[#6B7280] cursor-not-allowed opacity-50"
                }`}
                style={{
                  background: isDirty ? "#E040FB" : "#2A2D34",
                  fontFamily: "'DM Mono', monospace",
                }}
              >
                {saving ? (
                  <Loader2 className="w-3.5 h-3.5 animate-spin" />
                ) : (
                  <Save className="w-3.5 h-3.5" />
                )}
                {isNew ? "Criar" : "Salvar"}
              </button>
              {/* Fechar */}
              <button
                onClick={() => setSelectedId(null)}
                className="p-1.5 rounded text-[#6B7280] hover:text-white hover:bg-[#2A2D34] transition-colors"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Abas de seção */}
            <div
              className="flex items-center gap-0 px-5 border-b border-[#2A2D34] flex-shrink-0"
              style={{ background: "#1C1E22" }}
            >
              {(
                [
                  { key: "colors", label: "Cores", count: Object.keys(editColors).length },
                  { key: "gradients", label: "Gradientes", count: GRADIENT_KEYS.length },
                  { key: "shadows", label: "Sombras", count: SHADOW_KEYS.length },
                  { key: "opacities", label: "Opacidades", count: Object.keys(editOpacities).length },
                ] as const
              ).map(({ key, label, count }) => (
                <button
                  key={key}
                  onClick={() => setActiveSection(key)}
                  className={`flex items-center gap-1.5 px-3 py-2.5 text-xs font-medium border-b-2 transition-all ${
                    activeSection === key
                      ? "border-[#E040FB] text-white"
                      : "border-transparent text-[#6B7280] hover:text-[#9CA3AF]"
                  }`}
                  style={{ fontFamily: "'DM Mono', monospace" }}
                >
                  {label}
                  <span
                    className="text-[9px] px-1 py-0.5 rounded"
                    style={{
                      background:
                        activeSection === key ? "#E040FB22" : "#2A2D34",
                      color:
                        activeSection === key ? "#E040FB" : "#6B7280",
                    }}
                  >
                    {count}
                  </span>
                </button>
              ))}
            </div>

            {/* Conteúdo do editor */}
            <div className="flex-1 overflow-y-auto px-5 py-3">
              {/* ── Cores ── */}
              {activeSection === "colors" && (
                <div className="space-y-1">
                  {COLOR_GROUPS.map((group) => (
                    <div key={group.label}>
                      <button
                        onClick={() => toggleGroup(group.label)}
                        className="flex items-center gap-2 w-full py-1.5 text-left"
                      >
                        {expandedGroups.has(group.label) ? (
                          <ChevronDown className="w-3.5 h-3.5 text-[#6B7280]" />
                        ) : (
                          <ChevronRight className="w-3.5 h-3.5 text-[#6B7280]" />
                        )}
                        <span
                          className="text-xs font-semibold text-[#9CA3AF] uppercase tracking-wider"
                          style={{ fontFamily: "'DM Mono', monospace" }}
                        >
                          {group.label}
                        </span>
                        <span className="text-[10px] text-[#4B5563]">
                          ({group.keys.length})
                        </span>
                        {/* Mini swatches */}
                        <div className="flex gap-0.5 ml-auto">
                          {group.keys.slice(0, 4).map((k) => (
                            <div
                              key={k}
                              className="w-3 h-3 rounded-sm border border-white/10"
                              style={{ background: editColors[k] ?? "#888" }}
                            />
                          ))}
                        </div>
                      </button>
                      {expandedGroups.has(group.label) && (
                        <div className="pl-5 border-l border-[#2A2D34] ml-1.5 mb-2">
                          {group.keys.map((k) => (
                            <ColorRow
                              key={k}
                              tokenKey={k}
                              value={editColors[k] ?? "#000000"}
                              onChange={handleColorChange}
                            />
                          ))}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              )}

              {/* ── Gradientes ── */}
              {activeSection === "gradients" && (
                <div className="space-y-1 divide-y divide-[#2A2D34]">
                  {GRADIENT_KEYS.map((k) => (
                    <GradientRow
                      key={k}
                      gradKey={k}
                      value={
                        editGradients[k] ?? DEFAULT_GRADIENTS[k]
                      }
                      onChange={handleGradientChange}
                    />
                  ))}
                </div>
              )}

              {/* ── Sombras ── */}
              {activeSection === "shadows" && (
                <div className="space-y-1 divide-y divide-[#2A2D34]">
                  {SHADOW_KEYS.map((k) => (
                    <ShadowRow
                      key={k}
                      shadowKey={k}
                      value={editShadows[k] ?? DEFAULT_SHADOWS[k]}
                      onChange={handleShadowChange}
                    />
                  ))}
                </div>
              )}

              {/* ── Opacidades ── */}
              {activeSection === "opacities" && (
                <div className="space-y-4">
                  {Object.entries(editOpacities).map(([k, v]) => (
                    <div key={k} className="space-y-1.5">
                      <div className="flex items-center justify-between">
                        <Label
                          className="text-xs text-[#9CA3AF]"
                          style={{ fontFamily: "'DM Mono', monospace" }}
                        >
                          {hexToLabel(k)}
                        </Label>
                        <span
                          className="text-xs text-white"
                          style={{ fontFamily: "'DM Mono', monospace" }}
                        >
                          {v.toFixed(2)}
                        </span>
                      </div>
                      <input
                        type="range"
                        min={0}
                        max={1}
                        step={0.01}
                        value={v}
                        onChange={(e) =>
                          handleOpacityChange(k, Number(e.target.value))
                        }
                        className="w-full accent-[#E040FB]"
                      />
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>

          {/* ── Painel direito: preview ── */}
          {previewOpen && (
            <div
              className="w-80 flex-shrink-0 border-l border-[#2A2D34] flex flex-col"
              style={{ background: "#0D0D0F" }}
            >
              <div className="flex items-center gap-2 px-4 py-3 border-b border-[#2A2D34]">
                <Eye className="w-3.5 h-3.5 text-[#E040FB]" />
                <span
                  className="text-xs font-semibold text-[#9CA3AF] uppercase tracking-wider"
                  style={{ fontFamily: "'DM Mono', monospace" }}
                >
                  Preview em tempo real
                </span>
              </div>
              <div className="flex-1 overflow-y-auto flex items-start justify-center p-4">
                <AppPreview colors={editColors} gradients={editGradients} />
              </div>
            </div>
          )}
        </div>
      ) : (
        /* Estado vazio */
        <div className="flex-1 flex flex-col items-center justify-center gap-4 text-[#6B7280]">
          <Palette className="w-16 h-16 opacity-20" />
          <div className="text-center">
            <p className="text-sm font-medium text-[#9CA3AF]">
              Selecione um tema para editar
            </p>
            <p className="text-xs mt-1">
              ou crie um novo clicando em{" "}
              <span className="text-[#E040FB]">+ Novo</span>
            </p>
          </div>
          <button
            onClick={createNew}
            className="flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-bold text-black transition-colors"
            style={{ background: "#E040FB", fontFamily: "'DM Mono', monospace" }}
          >
            <Plus className="w-4 h-4" />
            Criar primeiro tema
          </button>
        </div>
      )}
    </div>
  );
}
