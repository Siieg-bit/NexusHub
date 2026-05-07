import { useState, useEffect, useCallback } from "react";
import { motion } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { toast } from "sonner";
import {
  Settings2, RefreshCw, Save, Search, ChevronDown, ChevronRight,
  Sliders, Shield, Link2, Megaphone, ShoppingCart, Flag, Loader2,
} from "lucide-react";

// ─── Tipos ────────────────────────────────────────────────────────────────────
type ConfigRow = {
  key: string;
  value: unknown;
  category: string;
  description: string;
  updated_at: string;
};

const CATEGORY_META: Record<string, { label: string; color: string; rgb: string; icon: React.FC<{ size?: number; style?: React.CSSProperties }> }> = {
  limits:      { label: "Limites",       color: "#60A5FA", rgb: "96,165,250",   icon: Sliders },
  pagination:  { label: "Paginação",     color: "#34D399", rgb: "52,211,153",   icon: Sliders },
  rate_limits: { label: "Rate Limits",   color: "#FBBF24", rgb: "251,191,36",   icon: Shield },
  links:       { label: "Links",         color: "#A78BFA", rgb: "167,139,250",  icon: Link2 },
  ads:         { label: "Anúncios",      color: "#F97316", rgb: "249,115,22",   icon: Megaphone },
  iap:         { label: "IAP / Moedas",  color: "#EC4899", rgb: "236,72,153",   icon: ShoppingCart },
  features:    { label: "Feature Flags", color: "#10B981", rgb: "16,185,129",   icon: Flag },
  general:     { label: "Geral",         color: "#94A3B8", rgb: "148,163,184",  icon: Settings2 },
};

const fadeUp = {
  hidden: { opacity: 0, y: 12 },
  show: (i: number) => ({ opacity: 1, y: 0, transition: { delay: i * 0.04, duration: 0.25, ease: "easeOut" as const } }),
};

function formatValue(value: unknown): string {
  if (typeof value === "string") return value;
  return JSON.stringify(value, null, 2);
}

function parseValue(raw: string): unknown {
  try { return JSON.parse(raw); } catch { return raw; }
}

// ─── Componente de linha editável ─────────────────────────────────────────────
function ConfigItem({
  row,
  onSave,
}: {
  row: ConfigRow;
  onSave: (key: string, value: unknown) => Promise<void>;
}) {
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(formatValue(row.value));
  const [saving, setSaving] = useState(false);
  const isJson = typeof row.value === "object" || (typeof row.value === "string" && (row.value.startsWith("{") || row.value.startsWith("[")));

  async function handleSave() {
    setSaving(true);
    try {
      await onSave(row.key, parseValue(draft));
      setEditing(false);
    } finally {
      setSaving(false);
    }
  }

  return (
    <div
      className="rounded-xl p-3"
      style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.06)" }}
    >
      <div className="flex items-start justify-between gap-2">
        <div className="flex-1 min-w-0">
          <p className="text-[12px] font-mono" style={{ color: "rgba(255,255,255,0.9)" }}>{row.key}</p>
          {row.description && (
            <p className="text-[11px] mt-0.5" style={{ color: "rgba(255,255,255,0.35)", fontFamily: "'Space Grotesk', sans-serif" }}>
              {row.description}
            </p>
          )}
        </div>
        <button
          onClick={() => { setEditing(!editing); setDraft(formatValue(row.value)); }}
          className="text-[11px] px-2 py-0.5 rounded-lg flex-shrink-0"
          style={{
            background: editing ? "rgba(239,68,68,0.1)" : "rgba(255,255,255,0.06)",
            color: editing ? "#FCA5A5" : "rgba(255,255,255,0.5)",
            border: `1px solid ${editing ? "rgba(239,68,68,0.2)" : "rgba(255,255,255,0.08)"}`,
          }}
        >
          {editing ? "Cancelar" : "Editar"}
        </button>
      </div>

      {!editing ? (
        <div
          className="mt-2 rounded-lg px-2 py-1.5 font-mono text-[11px] break-all"
          style={{ background: "rgba(0,0,0,0.2)", color: "#34D399" }}
        >
          {formatValue(row.value)}
        </div>
      ) : (
        <div className="mt-2 space-y-2">
          <textarea
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            rows={isJson ? 5 : 2}
            className="w-full rounded-lg px-2 py-1.5 font-mono text-[11px] resize-y outline-none"
            style={{
              background: "rgba(0,0,0,0.3)",
              color: "#FBBF24",
              border: "1px solid rgba(251,191,36,0.3)",
            }}
          />
          <button
            onClick={handleSave}
            disabled={saving}
            className="flex items-center gap-1.5 text-[11px] px-3 py-1 rounded-lg"
            style={{ background: "rgba(52,211,153,0.15)", color: "#34D399", border: "1px solid rgba(52,211,153,0.3)" }}
          >
            {saving ? <Loader2 size={11} className="animate-spin" /> : <Save size={11} />}
            Salvar
          </button>
        </div>
      )}
    </div>
  );
}

// ─── Página principal ─────────────────────────────────────────────────────────
export default function RemoteConfigPage() {
  const [configs, setConfigs] = useState<ConfigRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [collapsed, setCollapsed] = useState<Record<string, boolean>>({});

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from("app_remote_config")
        .select("*")
        .order("category")
        .order("key");
      if (error) throw error;
      setConfigs(data as ConfigRow[]);
    } catch (e: unknown) {
      toast.error(`Erro ao carregar: ${(e as Error).message}`);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  async function handleSave(key: string, value: unknown) {
    const { error } = await supabase
      .from("app_remote_config")
      .update({ value })
      .eq("key", key);
    if (error) {
      toast.error(`Erro ao salvar: ${error.message}`);
      throw error;
    }
    toast.success(`"${key}" atualizado!`);
    setConfigs((prev) => prev.map((c) => (c.key === key ? { ...c, value } : c)));
  }

  const filtered = configs.filter(
    (c) =>
      c.key.toLowerCase().includes(search.toLowerCase()) ||
      c.description?.toLowerCase().includes(search.toLowerCase())
  );

  // Agrupar por categoria
  const grouped = filtered.reduce<Record<string, ConfigRow[]>>((acc, row) => {
    const cat = row.category || "general";
    if (!acc[cat]) acc[cat] = [];
    acc[cat].push(row);
    return acc;
  }, {});

  const categories = Object.keys(grouped).sort();

  return (
    <div className="p-4 md:p-6 max-w-5xl mx-auto space-y-5">
      {/* Header */}
      <motion.div variants={fadeUp} initial="hidden" animate="show" custom={0}>
        <div className="flex items-center justify-between">
          <div>
            <h1
              className="text-[20px] font-bold tracking-tight"
              style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.95)" }}
            >
              Remote Config
            </h1>
            <p className="text-[12px] font-mono mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>
              {configs.length} configurações · edições aplicadas imediatamente no app
            </p>
          </div>
          <button
            onClick={load}
            disabled={loading}
            className="flex items-center gap-1.5 text-[12px] px-3 py-1.5 rounded-xl"
            style={{ background: "rgba(255,255,255,0.06)", color: "rgba(255,255,255,0.6)", border: "1px solid rgba(255,255,255,0.08)" }}
          >
            <RefreshCw size={13} className={loading ? "animate-spin" : ""} />
            Atualizar
          </button>
        </div>
      </motion.div>

      {/* Busca */}
      <motion.div variants={fadeUp} initial="hidden" animate="show" custom={1}>
        <div
          className="flex items-center gap-2 rounded-xl px-3 py-2"
          style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.07)" }}
        >
          <Search size={14} style={{ color: "rgba(255,255,255,0.3)" }} />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Buscar chave ou descrição..."
            className="flex-1 bg-transparent outline-none text-[13px]"
            style={{ color: "rgba(255,255,255,0.8)", fontFamily: "'Space Grotesk', sans-serif" }}
          />
        </div>
      </motion.div>

      {/* Categorias */}
      {loading ? (
        <div className="flex items-center justify-center py-16">
          <Loader2 size={24} className="animate-spin" style={{ color: "rgba(255,255,255,0.3)" }} />
        </div>
      ) : (
        <div className="space-y-3">
          {categories.map((cat, i) => {
            const meta = CATEGORY_META[cat] ?? CATEGORY_META.general;
            const Icon = meta.icon;
            const isCollapsed = collapsed[cat];
            const rows = grouped[cat];

            return (
              <motion.div
                key={cat}
                variants={fadeUp}
                initial="hidden"
                animate="show"
                custom={i + 2}
                className="rounded-2xl overflow-hidden"
                style={{ border: `1px solid rgba(${meta.rgb},0.15)` }}
              >
                {/* Cabeçalho da categoria */}
                <button
                  onClick={() => setCollapsed((prev) => ({ ...prev, [cat]: !prev[cat] }))}
                  className="w-full flex items-center justify-between px-4 py-3"
                  style={{ background: `rgba(${meta.rgb},0.06)` }}
                >
                  <div className="flex items-center gap-2">
                    <div
                      className="w-7 h-7 rounded-lg flex items-center justify-center"
                      style={{ background: `rgba(${meta.rgb},0.15)`, border: `1px solid rgba(${meta.rgb},0.2)` }}
                    >
                      <Icon size={13} style={{ color: meta.color }} />
                    </div>
                    <span
                      className="text-[13px] font-semibold"
                      style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.9)" }}
                    >
                      {meta.label}
                    </span>
                    <span
                      className="text-[11px] font-mono px-1.5 py-0.5 rounded-md"
                      style={{ background: `rgba(${meta.rgb},0.1)`, color: meta.color }}
                    >
                      {rows.length}
                    </span>
                  </div>
                  {isCollapsed ? (
                    <ChevronRight size={14} style={{ color: "rgba(255,255,255,0.3)" }} />
                  ) : (
                    <ChevronDown size={14} style={{ color: "rgba(255,255,255,0.3)" }} />
                  )}
                </button>

                {/* Itens */}
                {!isCollapsed && (
                  <div className="p-3 space-y-2" style={{ background: "rgba(0,0,0,0.15)" }}>
                    {rows.map((row) => (
                      <ConfigItem key={row.key} row={row} onSave={handleSave} />
                    ))}
                  </div>
                )}
              </motion.div>
            );
          })}
        </div>
      )}
    </div>
  );
}
