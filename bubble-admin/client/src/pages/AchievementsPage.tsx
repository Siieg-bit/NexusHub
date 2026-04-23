import { useState, useEffect, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { toast } from "sonner";
import {
  Trophy, Plus, Pencil, Trash2, RefreshCw, Loader2,
  X, Save, ImagePlus, Upload, CheckCircle2, Eye, EyeOff,
  Hash, Users, Star,
} from "lucide-react";

// ─── Tipos ────────────────────────────────────────────────────────────────────

type AchievementCategory = "social" | "content" | "engagement" | "milestone" | "special";
type AchievementRarity = "common" | "rare" | "epic" | "legendary";

type Achievement = {
  id: string;
  key: string;
  title: string;
  description: string | null;
  icon_url: string | null;
  category: AchievementCategory;
  rarity: AchievementRarity;
  xp_reward: number;
  coins_reward: number;
  is_active: boolean;
  is_hidden: boolean;
  max_progress: number;
  unlocked_count?: number;
  created_at: string;
};

type AchievementForm = {
  key: string;
  title: string;
  description: string;
  category: AchievementCategory;
  rarity: AchievementRarity;
  xp_reward: number;
  coins_reward: number;
  is_active: boolean;
  is_hidden: boolean;
  max_progress: number;
};

const RARITY_COLORS: Record<AchievementRarity, string> = {
  common: "#9CA3AF",
  rare: "#60A5FA",
  epic: "#A78BFA",
  legendary: "#FBBF24",
};

const CATEGORY_COLORS: Record<AchievementCategory, { color: string; label: string }> = {
  social:      { color: "#EC4899", label: "Social" },
  content:     { color: "#34D399", label: "Conteúdo" },
  engagement:  { color: "#60A5FA", label: "Engajamento" },
  milestone:   { color: "#FBBF24", label: "Marco" },
  special:     { color: "#A78BFA", label: "Especial" },
};

const DEFAULT_FORM: AchievementForm = {
  key: "", title: "", description: "",
  category: "engagement", rarity: "common",
  xp_reward: 50, coins_reward: 0,
  is_active: true, is_hidden: false,
  max_progress: 1,
};

const fadeUp = {
  hidden: { opacity: 0, y: 12 },
  show: (i: number) => ({ opacity: 1, y: 0, transition: { delay: i * 0.04, duration: 0.25, ease: "easeOut" } }),
};

// ─── Formulário de conquista ──────────────────────────────────────────────────

function AchievementForm({
  initial,
  editing,
  onClose,
  onSaved,
}: {
  initial: AchievementForm;
  editing: Achievement | null;
  onClose: () => void;
  onSaved: (a: Achievement) => void;
}) {
  const [form, setForm] = useState<AchievementForm>(initial);
  const [iconFile, setIconFile] = useState<File | null>(null);
  const [iconPreview, setIconPreview] = useState<string | null>(editing?.icon_url ?? null);
  const [saving, setSaving] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  async function handleSave() {
    if (!form.key.trim()) { toast.error("Defina uma chave única para a conquista."); return; }
    if (!form.title.trim()) { toast.error("Defina um título."); return; }
    setSaving(true);
    try {
      let iconUrl = editing?.icon_url ?? null;
      if (iconFile) {
        const ext = iconFile.name.split(".").pop()?.toLowerCase() ?? "png";
        const path = `achievements/${form.key}_${Date.now()}.${ext}`;
        const { error: upErr } = await supabase.storage.from("store-assets").upload(path, iconFile, { contentType: iconFile.type, upsert: false });
        if (upErr) throw new Error(`Upload falhou: ${upErr.message}`);
        const { data } = supabase.storage.from("store-assets").getPublicUrl(path);
        iconUrl = data.publicUrl;
      }

      const payload = {
        key: form.key.trim().toLowerCase().replace(/\s+/g, "_"),
        title: form.title.trim(),
        description: form.description.trim() || null,
        category: form.category,
        rarity: form.rarity,
        xp_reward: form.xp_reward,
        coins_reward: form.coins_reward,
        is_active: form.is_active,
        is_hidden: form.is_hidden,
        max_progress: form.max_progress,
        icon_url: iconUrl,
      };

      if (editing) {
        const { data, error } = await supabase.from("achievements").update(payload).eq("id", editing.id).select().single();
        if (error) throw error;
        toast.success(`"${form.title}" atualizada!`);
        onSaved(data as Achievement);
      } else {
        const { data, error } = await supabase.from("achievements").insert(payload).select().single();
        if (error) throw error;
        toast.success(`"${form.title}" criada!`);
        onSaved(data as Achievement);
      }
      onClose();
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : "Erro ao salvar.");
    } finally { setSaving(false); }
  }

  const inputClass = "w-full px-3 py-2 rounded-xl text-[13px] outline-none";
  const inputStyle = { background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.85)", fontFamily: "'Space Grotesk', sans-serif" };
  const labelClass = "text-[10px] font-mono tracking-widest uppercase block mb-1.5";
  const labelStyle = { color: "rgba(255,255,255,0.3)" };

  return (
    <div
      className="fixed inset-0 z-50 flex items-start justify-center p-4 overflow-y-auto"
      style={{ background: "rgba(0,0,0,0.8)", backdropFilter: "blur(4px)" }}
      onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}
    >
      <motion.div
        initial={{ opacity: 0, scale: 0.97, y: 10 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        exit={{ opacity: 0, scale: 0.97, y: 10 }}
        className="w-full max-w-lg rounded-2xl my-4"
        style={{ background: "#1C1E22", border: "1px solid rgba(251,191,36,0.2)" }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4" style={{ borderBottom: "1px solid rgba(255,255,255,0.07)" }}>
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-xl flex items-center justify-center" style={{ background: "rgba(251,191,36,0.1)" }}>
              <Trophy size={16} style={{ color: "#FBBF24" }} />
            </div>
            <h3 className="text-[15px] font-bold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.95)" }}>
              {editing ? "Editar Conquista" : "Nova Conquista"}
            </h3>
          </div>
          <button onClick={onClose} className="w-7 h-7 rounded-lg flex items-center justify-center" style={{ background: "rgba(255,255,255,0.05)", color: "rgba(255,255,255,0.4)" }}>
            <X size={13} />
          </button>
        </div>

        <div className="p-6 space-y-4">
          {/* Ícone */}
          <div className="flex items-center gap-4">
            <div
              className="w-16 h-16 rounded-xl overflow-hidden flex-shrink-0 flex items-center justify-center cursor-pointer border relative group"
              style={{ background: "rgba(255,255,255,0.03)", borderColor: "rgba(255,255,255,0.08)", borderStyle: "dashed" }}
              onClick={() => fileRef.current?.click()}
            >
              {iconPreview ? (
                <>
                  <img src={iconPreview} alt="icon" className="w-full h-full object-cover" />
                  <div className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                    <Upload size={14} className="text-white" />
                  </div>
                </>
              ) : (
                <ImagePlus size={20} style={{ color: "rgba(255,255,255,0.2)" }} />
              )}
              <input ref={fileRef} type="file" accept="image/*" className="hidden" onChange={(e) => {
                const f = e.target.files?.[0];
                if (!f) return;
                setIconFile(f);
                const reader = new FileReader();
                reader.onload = (ev) => setIconPreview(ev.target?.result as string);
                reader.readAsDataURL(f);
              }} />
            </div>
            <div className="flex-1 space-y-1.5">
              <label className={labelClass} style={labelStyle}>Chave única *</label>
              <input value={form.key} onChange={(e) => setForm({ ...form, key: e.target.value })} placeholder="ex: first_post, social_butterfly..."
                className={inputClass} style={{ ...inputStyle, fontFamily: "'DM Mono', monospace" }} />
            </div>
          </div>

          {/* Título + Descrição */}
          <div className="space-y-1.5">
            <label className={labelClass} style={labelStyle}>Título *</label>
            <input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} placeholder="Nome exibido ao usuário..."
              className={inputClass} style={inputStyle} />
          </div>
          <div className="space-y-1.5">
            <label className={labelClass} style={labelStyle}>Descrição</label>
            <textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} rows={2}
              placeholder="Como desbloquear esta conquista..." className={`${inputClass} resize-none`} style={inputStyle} />
          </div>

          {/* Categoria + Raridade */}
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <label className={labelClass} style={labelStyle}>Categoria</label>
              <select value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value as AchievementCategory })}
                className="w-full h-9 rounded-xl px-3 text-[12px] outline-none" style={{ ...inputStyle, fontFamily: "'DM Mono', monospace" }}>
                {Object.entries(CATEGORY_COLORS).map(([v, { label }]) => <option key={v} value={v}>{label}</option>)}
              </select>
            </div>
            <div className="space-y-1.5">
              <label className={labelClass} style={labelStyle}>Raridade</label>
              <select value={form.rarity} onChange={(e) => setForm({ ...form, rarity: e.target.value as AchievementRarity })}
                className="w-full h-9 rounded-xl px-3 text-[12px] outline-none" style={{ ...inputStyle, fontFamily: "'DM Mono', monospace" }}>
                {Object.keys(RARITY_COLORS).map((v) => <option key={v} value={v}>{v.charAt(0).toUpperCase() + v.slice(1)}</option>)}
              </select>
            </div>
          </div>

          {/* Recompensas + Progresso */}
          <div className="grid grid-cols-3 gap-3">
            <div className="space-y-1.5">
              <label className={labelClass} style={labelStyle}>XP</label>
              <input type="number" min={0} value={form.xp_reward} onChange={(e) => setForm({ ...form, xp_reward: parseInt(e.target.value) || 0 })}
                className={inputClass} style={{ ...inputStyle, fontFamily: "'DM Mono', monospace" }} />
            </div>
            <div className="space-y-1.5">
              <label className={labelClass} style={labelStyle}>Coins ✦</label>
              <input type="number" min={0} value={form.coins_reward} onChange={(e) => setForm({ ...form, coins_reward: parseInt(e.target.value) || 0 })}
                className={inputClass} style={{ ...inputStyle, fontFamily: "'DM Mono', monospace" }} />
            </div>
            <div className="space-y-1.5">
              <label className={labelClass} style={labelStyle}>Progresso máx.</label>
              <input type="number" min={1} value={form.max_progress} onChange={(e) => setForm({ ...form, max_progress: parseInt(e.target.value) || 1 })}
                className={inputClass} style={{ ...inputStyle, fontFamily: "'DM Mono', monospace" }} />
            </div>
          </div>

          {/* Toggles */}
          <div className="flex items-center gap-5">
            <div className="flex items-center gap-2">
              <button type="button" onClick={() => setForm({ ...form, is_active: !form.is_active })}
                className={`relative w-9 h-5 rounded-full transition-colors ${form.is_active ? "bg-[#34D399]" : "bg-[#2A2D34]"}`}>
                <span className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform ${form.is_active ? "translate-x-4" : "translate-x-0.5"}`} />
              </button>
              <span className="text-[12px] font-mono" style={{ color: "rgba(255,255,255,0.5)" }}>Ativa</span>
            </div>
            <div className="flex items-center gap-2">
              <button type="button" onClick={() => setForm({ ...form, is_hidden: !form.is_hidden })}
                className={`relative w-9 h-5 rounded-full transition-colors ${form.is_hidden ? "bg-[#A78BFA]" : "bg-[#2A2D34]"}`}>
                <span className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform ${form.is_hidden ? "translate-x-4" : "translate-x-0.5"}`} />
              </button>
              <span className="text-[12px] font-mono" style={{ color: "rgba(255,255,255,0.5)" }}>Oculta (surpresa)</span>
            </div>
          </div>

          {/* Botões */}
          <div className="flex gap-3 pt-1">
            <button onClick={handleSave} disabled={saving}
              className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl text-[13px] font-semibold transition-all disabled:opacity-50"
              style={{ background: "rgba(251,191,36,0.15)", border: "1px solid rgba(251,191,36,0.3)", color: "#FBBF24", fontFamily: "'Space Grotesk', sans-serif" }}>
              {saving ? <><Loader2 size={14} className="animate-spin" />Salvando...</> : <><Save size={14} />{editing ? "Salvar" : "Criar Conquista"}</>}
            </button>
            <button onClick={onClose}
              className="px-4 py-2.5 rounded-xl text-[13px] transition-all"
              style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.4)", fontFamily: "'DM Mono', monospace" }}>
              Cancelar
            </button>
          </div>
        </div>
      </motion.div>
    </div>
  );
}

// ─── Página principal ─────────────────────────────────────────────────────────

export default function AchievementsPage() {
  const [achievements, setAchievements] = useState<Achievement[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<Achievement | null>(null);
  const [categoryFilter, setCategoryFilter] = useState<AchievementCategory | "all">("all");

  async function loadAchievements() {
    setLoading(true);
    const { data, error } = await supabase
      .from("achievements")
      .select("*")
      .order("created_at", { ascending: false });
    if (!error && data) setAchievements(data as Achievement[]);
    setLoading(false);
  }

  useEffect(() => { loadAchievements(); }, []);

  async function toggleActive(a: Achievement) {
    const { error } = await supabase.from("achievements").update({ is_active: !a.is_active }).eq("id", a.id);
    if (error) { toast.error("Erro ao atualizar."); return; }
    setAchievements((prev) => prev.map((x) => x.id === a.id ? { ...x, is_active: !a.is_active } : x));
  }

  async function deleteAchievement(a: Achievement) {
    if (!confirm(`Deletar "${a.title}"? Esta ação não pode ser desfeita.`)) return;
    const { error } = await supabase.from("achievements").delete().eq("id", a.id);
    if (error) { toast.error("Erro ao deletar."); return; }
    setAchievements((prev) => prev.filter((x) => x.id !== a.id));
    toast.success(`"${a.title}" removida.`);
  }

  function handleSaved(a: Achievement) {
    setAchievements((prev) => {
      const idx = prev.findIndex((x) => x.id === a.id);
      if (idx >= 0) { const next = [...prev]; next[idx] = a; return next; }
      return [a, ...prev];
    });
  }

  const filtered = achievements.filter((a) => categoryFilter === "all" || a.category === categoryFilter);
  const activeCount = achievements.filter((a) => a.is_active).length;

  return (
    <>
      <AnimatePresence>
        {(showForm || editing) && (
          <AchievementForm
            initial={editing ? {
              key: editing.key, title: editing.title, description: editing.description ?? "",
              category: editing.category, rarity: editing.rarity,
              xp_reward: editing.xp_reward, coins_reward: editing.coins_reward,
              is_active: editing.is_active, is_hidden: editing.is_hidden,
              max_progress: editing.max_progress,
            } : DEFAULT_FORM}
            editing={editing}
            onClose={() => { setShowForm(false); setEditing(null); }}
            onSaved={handleSaved}
          />
        )}
      </AnimatePresence>

      <div className="p-4 md:p-6 max-w-7xl mx-auto space-y-5">
        {/* Header */}
        <motion.div variants={fadeUp} initial="hidden" animate="show" custom={0}>
          <div className="flex items-start justify-between gap-3">
            <div>
              <h1 className="text-[20px] font-bold tracking-tight" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.95)" }}>Conquistas</h1>
              <p className="text-[12px] font-mono mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>CRUD de conquistas e sistema de gamificação</p>
            </div>
            <div className="flex items-center gap-2">
              <button onClick={loadAchievements} className="w-8 h-8 rounded-xl flex items-center justify-center transition-all"
                style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.4)" }}>
                <RefreshCw size={13} />
              </button>
              <button onClick={() => { setEditing(null); setShowForm(true); }}
                className="flex items-center gap-2 px-4 py-2 rounded-xl text-[13px] font-semibold transition-all"
                style={{ background: "rgba(251,191,36,0.15)", border: "1px solid rgba(251,191,36,0.3)", color: "#FBBF24", fontFamily: "'Space Grotesk', sans-serif" }}>
                <Plus size={14} />Nova Conquista
              </button>
            </div>
          </div>
        </motion.div>

        {/* Stats */}
        <motion.div variants={fadeUp} initial="hidden" animate="show" custom={1} className="grid grid-cols-3 gap-3">
          {[
            { label: "Total", value: achievements.length, color: "#FBBF24", rgb: "251,191,36", icon: Trophy },
            { label: "Ativas", value: activeCount, color: "#34D399", rgb: "52,211,153", icon: CheckCircle2 },
            { label: "Categorias", value: Object.keys(CATEGORY_COLORS).length, color: "#A78BFA", rgb: "167,139,250", icon: Star },
          ].map(({ label, value, color, rgb, icon: Icon }) => (
            <div key={label} className="p-3 md:p-4 rounded-2xl" style={{ background: `rgba(${rgb},0.06)`, border: `1px solid rgba(${rgb},0.15)` }}>
              <div className="flex items-center gap-2 mb-1">
                <Icon size={12} style={{ color }} />
                <span className="text-[10px] font-mono tracking-wider uppercase" style={{ color: "rgba(255,255,255,0.35)" }}>{label}</span>
              </div>
              <div className="text-[18px] font-bold font-mono" style={{ color }}>{value}</div>
            </div>
          ))}
        </motion.div>

        {/* Filtro de categoria */}
        <motion.div variants={fadeUp} initial="hidden" animate="show" custom={2} className="flex gap-2 flex-wrap">
          <button onClick={() => setCategoryFilter("all")}
            className="px-3 py-1.5 rounded-xl text-[11px] font-mono transition-all"
            style={{
              background: categoryFilter === "all" ? "rgba(167,139,250,0.15)" : "rgba(255,255,255,0.03)",
              border: `1px solid ${categoryFilter === "all" ? "rgba(167,139,250,0.3)" : "rgba(255,255,255,0.07)"}`,
              color: categoryFilter === "all" ? "#A78BFA" : "rgba(255,255,255,0.3)",
            }}>
            Todas
          </button>
          {Object.entries(CATEGORY_COLORS).map(([cat, { color, label }]) => (
            <button key={cat} onClick={() => setCategoryFilter(cat as AchievementCategory)}
              className="px-3 py-1.5 rounded-xl text-[11px] font-mono transition-all"
              style={{
                background: categoryFilter === cat ? `${color}15` : "rgba(255,255,255,0.03)",
                border: `1px solid ${categoryFilter === cat ? `${color}30` : "rgba(255,255,255,0.07)"}`,
                color: categoryFilter === cat ? color : "rgba(255,255,255,0.3)",
              }}>
              {label}
            </button>
          ))}
        </motion.div>

        {/* Grid de conquistas */}
        {loading ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
            {[...Array(6)].map((_, i) => <div key={i} className="h-28 rounded-xl" style={{ background: "rgba(255,255,255,0.03)" }} />)}
          </div>
        ) : filtered.length === 0 ? (
          <div className="rounded-2xl p-10 text-center" style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}>
            <Trophy className="w-10 h-10 text-[#4B5563] mx-auto mb-3 opacity-40" />
            <p className="text-[#4B5563] text-sm">Nenhuma conquista encontrada</p>
          </div>
        ) : (
          <motion.div variants={fadeUp} initial="hidden" animate="show" custom={3}
            className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
            {filtered.map((a, i) => {
              const catCfg = CATEGORY_COLORS[a.category];
              const rarityColor = RARITY_COLORS[a.rarity];
              return (
                <motion.div key={a.id} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.02 }}
                  className="rounded-xl overflow-hidden"
                  style={{
                    background: "rgba(255,255,255,0.025)",
                    border: `1px solid ${a.is_active ? "rgba(255,255,255,0.07)" : "rgba(255,255,255,0.04)"}`,
                    opacity: a.is_active ? 1 : 0.55,
                  }}>
                  {/* Barra de raridade */}
                  <div className="h-0.5 w-full" style={{ backgroundColor: rarityColor }} />

                  <div className="p-4">
                    <div className="flex items-start gap-3 mb-3">
                      {/* Ícone */}
                      <div className="w-10 h-10 rounded-xl flex-shrink-0 flex items-center justify-center overflow-hidden"
                        style={{ background: `${catCfg.color}15`, border: `1px solid ${catCfg.color}25` }}>
                        {a.icon_url ? (
                          <img src={a.icon_url} alt={a.title} className="w-full h-full object-cover" />
                        ) : (
                          <Trophy size={16} style={{ color: catCfg.color }} />
                        )}
                      </div>

                      <div className="flex-1 min-w-0">
                        <div className="flex items-start justify-between gap-1">
                          <p className="text-[13px] font-semibold leading-tight" style={{ color: "rgba(255,255,255,0.9)", fontFamily: "'Space Grotesk', sans-serif" }}>{a.title}</p>
                          {a.is_hidden && <EyeOff size={11} className="flex-shrink-0 mt-0.5" style={{ color: "#A78BFA" }} />}
                        </div>
                        <p className="text-[10px] font-mono mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>{a.key}</p>
                      </div>
                    </div>

                    {a.description && (
                      <p className="text-[11px] mb-3 line-clamp-2" style={{ color: "rgba(255,255,255,0.45)", fontFamily: "'Space Grotesk', sans-serif" }}>{a.description}</p>
                    )}

                    {/* Badges */}
                    <div className="flex items-center gap-1.5 flex-wrap mb-3">
                      <span className="text-[10px] px-1.5 py-0.5 rounded font-mono" style={{ background: `${catCfg.color}15`, color: catCfg.color }}>{catCfg.label}</span>
                      <span className="text-[10px] px-1.5 py-0.5 rounded font-mono" style={{ background: `${rarityColor}15`, color: rarityColor }}>{a.rarity}</span>
                      {a.xp_reward > 0 && <span className="text-[10px] px-1.5 py-0.5 rounded font-mono" style={{ background: "rgba(96,165,250,0.1)", color: "#60A5FA" }}>{a.xp_reward} XP</span>}
                      {a.coins_reward > 0 && <span className="text-[10px] px-1.5 py-0.5 rounded font-mono" style={{ background: "rgba(245,158,11,0.1)", color: "#F59E0B" }}>{a.coins_reward} ✦</span>}
                      {a.max_progress > 1 && <span className="text-[10px] px-1.5 py-0.5 rounded font-mono" style={{ background: "rgba(255,255,255,0.05)", color: "rgba(255,255,255,0.4)" }}>0/{a.max_progress}</span>}
                    </div>

                    {/* Ações */}
                    <div className="flex items-center gap-2">
                      <button onClick={() => { setEditing(a); setShowForm(false); }}
                        className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-[11px] font-mono transition-all"
                        style={{ background: "rgba(251,191,36,0.08)", border: "1px solid rgba(251,191,36,0.15)", color: "#FBBF24" }}>
                        <Pencil size={10} />Editar
                      </button>
                      <button onClick={() => toggleActive(a)}
                        className={`flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-[11px] font-mono transition-all ${a.is_active ? "text-[#34D399]" : "text-[#6B7280]"}`}
                        style={{ background: a.is_active ? "rgba(52,211,153,0.08)" : "rgba(107,114,128,0.08)", border: `1px solid ${a.is_active ? "rgba(52,211,153,0.15)" : "rgba(107,114,128,0.15)"}` }}>
                        {a.is_active ? <><CheckCircle2 size={10} />Ativa</> : <><Eye size={10} />Inativa</>}
                      </button>
                      <button onClick={() => deleteAchievement(a)} className="ml-auto p-1.5 rounded-lg text-[#4B5563] hover:text-red-400 hover:bg-red-500/10 transition-colors">
                        <Trash2 size={12} />
                      </button>
                    </div>
                  </div>
                </motion.div>
              );
            })}
          </motion.div>
        )}
      </div>
    </>
  );
}
