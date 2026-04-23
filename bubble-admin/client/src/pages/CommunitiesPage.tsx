import { useState, useEffect, useRef, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { toast } from "sonner";
import {
  Globe, Users, Search, ArrowLeft, ChevronRight, RefreshCw,
  Edit2, CheckCircle2, XCircle, Eye, EyeOff, ImagePlus,
  Loader2, Hash, Calendar, Activity, Lock, Unlock, Flame,
  Upload, X, Save,
} from "lucide-react";

// ─── Tipos ────────────────────────────────────────────────────────────────────

type JoinType = "open" | "request" | "invite_only";
type ListedStatus = "listed" | "unlisted" | "hidden";
type CommunityStatus = "active" | "probation" | "suspended" | "archived";

type Community = {
  id: string;
  name: string;
  tagline: string | null;
  description: string | null;
  endpoint: string;
  icon_url: string | null;
  banner_url: string | null;
  banner_header_url: string | null;
  banner_card_url: string | null;
  join_type: JoinType;
  listed_status: ListedStatus;
  is_searchable: boolean;
  members_count: number;
  posts_count: number;
  community_heat: number;
  category: string | null;
  theme_color: string | null;
  status: CommunityStatus;
  probation_status: string | null;
  created_at: string;
  welcome_message: string | null;
  rules: string | null;
  about_text: string | null;
};

const STATUS_CONFIG: Record<CommunityStatus, { label: string; color: string; bg: string; border: string }> = {
  active:     { label: "Ativa",      color: "#34D399", bg: "rgba(52,211,153,0.1)",   border: "rgba(52,211,153,0.2)" },
  probation:  { label: "Probatória", color: "#F59E0B", bg: "rgba(245,158,11,0.1)",   border: "rgba(245,158,11,0.2)" },
  suspended:  { label: "Suspensa",   color: "#EF4444", bg: "rgba(239,68,68,0.1)",    border: "rgba(239,68,68,0.2)" },
  archived:   { label: "Arquivada",  color: "#6B7280", bg: "rgba(107,114,128,0.1)",  border: "rgba(107,114,128,0.2)" },
};

const JOIN_TYPE_LABELS: Record<JoinType, string> = {
  open: "Aberta",
  request: "Por Solicitação",
  invite_only: "Convite",
};

const LISTED_LABELS: Record<ListedStatus, string> = {
  listed: "Listada",
  unlisted: "Não listada",
  hidden: "Oculta",
};

const fadeUp = {
  hidden: { opacity: 0, y: 12 },
  show: (i: number) => ({ opacity: 1, y: 0, transition: { delay: i * 0.04, duration: 0.25, ease: "easeOut" } }),
};

// ─── Upload de imagem helper ──────────────────────────────────────────────────

function useImageUpload(bucket: string, folder: string) {
  async function upload(file: File, name: string): Promise<string> {
    const ext = file.name.split(".").pop()?.toLowerCase() ?? "jpg";
    const path = `${folder}/${name}_${Date.now()}.${ext}`;
    const { error } = await supabase.storage.from(bucket).upload(path, file, { contentType: file.type, upsert: false });
    if (error) throw new Error(`Upload falhou: ${error.message}`);
    const { data } = supabase.storage.from(bucket).getPublicUrl(path);
    return data.publicUrl;
  }
  return { upload };
}

// ─── Editor de comunidade ─────────────────────────────────────────────────────

function CommunityEditor({
  community,
  onClose,
  onSaved,
}: {
  community: Community;
  onClose: () => void;
  onSaved: (updated: Community) => void;
}) {
  const [form, setForm] = useState({
    name: community.name,
    tagline: community.tagline ?? "",
    description: community.description ?? "",
    join_type: community.join_type,
    listed_status: community.listed_status,
    is_searchable: community.is_searchable,
    status: community.status,
    theme_color: community.theme_color ?? "#7C3AED",
    welcome_message: community.welcome_message ?? "",
    rules: community.rules ?? "",
    about_text: community.about_text ?? "",
  });

  const [iconFile, setIconFile] = useState<File | null>(null);
  const [iconPreview, setIconPreview] = useState<string | null>(community.icon_url);
  const [bannerFile, setBannerFile] = useState<File | null>(null);
  const [bannerPreview, setBannerPreview] = useState<string | null>(community.banner_url);
  const [bannerHeaderFile, setBannerHeaderFile] = useState<File | null>(null);
  const [bannerHeaderPreview, setBannerHeaderPreview] = useState<string | null>(community.banner_header_url);
  const [bannerCardFile, setBannerCardFile] = useState<File | null>(null);
  const [bannerCardPreview, setBannerCardPreview] = useState<string | null>(community.banner_card_url);

  const [saving, setSaving] = useState(false);
  const { upload } = useImageUpload("community-assets", "communities");

  function handleFileChange(file: File, setter: (f: File | null) => void, previewSetter: (s: string | null) => void) {
    setter(file);
    const reader = new FileReader();
    reader.onload = (e) => previewSetter(e.target?.result as string);
    reader.readAsDataURL(file);
  }

  async function handleSave() {
    setSaving(true);
    try {
      const slug = community.endpoint;
      let iconUrl = community.icon_url;
      let bannerUrl = community.banner_url;
      let bannerHeaderUrl = community.banner_header_url;
      let bannerCardUrl = community.banner_card_url;

      if (iconFile) iconUrl = await upload(iconFile, `${slug}_icon`);
      if (bannerFile) bannerUrl = await upload(bannerFile, `${slug}_banner`);
      if (bannerHeaderFile) bannerHeaderUrl = await upload(bannerHeaderFile, `${slug}_banner_header`);
      if (bannerCardFile) bannerCardUrl = await upload(bannerCardFile, `${slug}_banner_card`);

      const payload = {
        name: form.name.trim(),
        tagline: form.tagline.trim() || null,
        description: form.description.trim() || null,
        join_type: form.join_type,
        listed_status: form.listed_status,
        is_searchable: form.is_searchable,
        status: form.status,
        theme_color: form.theme_color,
        welcome_message: form.welcome_message.trim() || null,
        rules: form.rules.trim() || null,
        about_text: form.about_text.trim() || null,
        icon_url: iconUrl,
        banner_url: bannerUrl,
        banner_header_url: bannerHeaderUrl,
        banner_card_url: bannerCardUrl,
      };

      const { error } = await supabase.from("communities").update(payload).eq("id", community.id);
      if (error) throw error;

      toast.success(`Comunidade "${form.name}" atualizada!`);
      onSaved({ ...community, ...payload });
      onClose();
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : "Erro ao salvar.");
    } finally { setSaving(false); }
  }

  const inputClass = "w-full px-3 py-2 rounded-xl text-[13px] outline-none";
  const inputStyle = { background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.85)", fontFamily: "'Space Grotesk', sans-serif" };
  const labelClass = "text-[10px] font-mono tracking-widest uppercase block mb-1.5";
  const labelStyle = { color: "rgba(255,255,255,0.3)" };

  function ImageUploadField({ label, preview, onFile, hint }: { label: string; preview: string | null; onFile: (f: File) => void; hint?: string }) {
    const ref = useRef<HTMLInputElement>(null);
    return (
      <div className="space-y-1.5">
        <label className={labelClass} style={labelStyle}>{label}</label>
        <div
          className="relative h-20 rounded-xl overflow-hidden cursor-pointer border flex items-center justify-center group"
          style={{ background: "rgba(255,255,255,0.03)", borderColor: "rgba(255,255,255,0.08)", borderStyle: "dashed" }}
          onClick={() => ref.current?.click()}
        >
          {preview ? (
            <>
              <img src={preview} alt={label} className="w-full h-full object-cover" />
              <div className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                <Upload size={16} className="text-white" />
              </div>
            </>
          ) : (
            <div className="flex flex-col items-center gap-1">
              <ImagePlus size={18} style={{ color: "rgba(255,255,255,0.2)" }} />
              {hint && <p className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.2)" }}>{hint}</p>}
            </div>
          )}
          <input ref={ref} type="file" accept="image/*" className="hidden" onChange={(e) => { const f = e.target.files?.[0]; if (f) onFile(f); }} />
        </div>
      </div>
    );
  }

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
        className="w-full max-w-2xl rounded-2xl my-4"
        style={{ background: "#1C1E22", border: "1px solid rgba(52,211,153,0.2)" }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4" style={{ borderBottom: "1px solid rgba(255,255,255,0.07)" }}>
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-xl flex items-center justify-center" style={{ background: "rgba(52,211,153,0.1)" }}>
              <Globe size={16} style={{ color: "#34D399" }} />
            </div>
            <div>
              <h3 className="text-[15px] font-bold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.95)" }}>Editar Comunidade</h3>
              <p className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>/{community.endpoint}</p>
            </div>
          </div>
          <button onClick={onClose} className="w-7 h-7 rounded-lg flex items-center justify-center" style={{ background: "rgba(255,255,255,0.05)", color: "rgba(255,255,255,0.4)" }}>
            <X size={13} />
          </button>
        </div>

        <div className="p-6 space-y-5">
          {/* Básico */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className={labelClass} style={labelStyle}>Nome *</label>
              <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} className={inputClass} style={inputStyle} />
            </div>
            <div className="space-y-1.5">
              <label className={labelClass} style={labelStyle}>Tagline</label>
              <input value={form.tagline} onChange={(e) => setForm({ ...form, tagline: e.target.value })} placeholder="Slogan curto..." className={inputClass} style={inputStyle} />
            </div>
          </div>

          <div className="space-y-1.5">
            <label className={labelClass} style={labelStyle}>Descrição</label>
            <textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} rows={3} placeholder="Descrição da comunidade..."
              className={`${inputClass} resize-none`} style={inputStyle} />
          </div>

          <div className="space-y-1.5">
            <label className={labelClass} style={labelStyle}>Sobre (about_text)</label>
            <textarea value={form.about_text} onChange={(e) => setForm({ ...form, about_text: e.target.value })} rows={2} placeholder="Texto de apresentação detalhado..."
              className={`${inputClass} resize-none`} style={inputStyle} />
          </div>

          <div className="space-y-1.5">
            <label className={labelClass} style={labelStyle}>Regras</label>
            <textarea value={form.rules} onChange={(e) => setForm({ ...form, rules: e.target.value })} rows={3} placeholder="Regras da comunidade (uma por linha)..."
              className={`${inputClass} resize-none`} style={inputStyle} />
          </div>

          <div className="space-y-1.5">
            <label className={labelClass} style={labelStyle}>Mensagem de Boas-vindas</label>
            <input value={form.welcome_message} onChange={(e) => setForm({ ...form, welcome_message: e.target.value })} placeholder="Mensagem exibida ao novo membro..."
              className={inputClass} style={inputStyle} />
          </div>

          {/* Config */}
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
            <div className="space-y-1.5">
              <label className={labelClass} style={labelStyle}>Entrada</label>
              <select value={form.join_type} onChange={(e) => setForm({ ...form, join_type: e.target.value as JoinType })}
                className="w-full h-9 rounded-xl px-3 text-[12px] outline-none" style={{ ...inputStyle, fontFamily: "'DM Mono', monospace" }}>
                {Object.entries(JOIN_TYPE_LABELS).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
              </select>
            </div>
            <div className="space-y-1.5">
              <label className={labelClass} style={labelStyle}>Visibilidade</label>
              <select value={form.listed_status} onChange={(e) => setForm({ ...form, listed_status: e.target.value as ListedStatus })}
                className="w-full h-9 rounded-xl px-3 text-[12px] outline-none" style={{ ...inputStyle, fontFamily: "'DM Mono', monospace" }}>
                {Object.entries(LISTED_LABELS).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
              </select>
            </div>
            <div className="space-y-1.5">
              <label className={labelClass} style={labelStyle}>Status</label>
              <select value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value as CommunityStatus })}
                className="w-full h-9 rounded-xl px-3 text-[12px] outline-none" style={{ ...inputStyle, fontFamily: "'DM Mono', monospace" }}>
                {Object.keys(STATUS_CONFIG).map((v) => <option key={v} value={v}>{STATUS_CONFIG[v as CommunityStatus].label}</option>)}
              </select>
            </div>
          </div>

          {/* Toggles + cor */}
          <div className="flex items-center gap-4 flex-wrap">
            <div className="flex items-center gap-2">
              <button type="button" onClick={() => setForm({ ...form, is_searchable: !form.is_searchable })}
                className={`relative w-9 h-5 rounded-full transition-colors ${form.is_searchable ? "bg-[#34D399]" : "bg-[#2A2D34]"}`}>
                <span className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform ${form.is_searchable ? "translate-x-4" : "translate-x-0.5"}`} />
              </button>
              <span className="text-[12px] font-mono" style={{ color: "rgba(255,255,255,0.5)" }}>Pesquisável</span>
            </div>
            <div className="flex items-center gap-2">
              <label className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.3)" }}>Cor tema</label>
              <input type="color" value={form.theme_color} onChange={(e) => setForm({ ...form, theme_color: e.target.value })}
                className="w-8 h-8 rounded-lg cursor-pointer border-0 p-0.5" style={{ background: "rgba(255,255,255,0.05)" }} />
              <span className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.4)" }}>{form.theme_color}</span>
            </div>
          </div>

          {/* Assets visuais */}
          <div>
            <p className="text-[10px] font-mono tracking-widest uppercase mb-3" style={{ color: "rgba(255,255,255,0.3)" }}>Assets Visuais</p>
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
              <ImageUploadField label="Ícone" preview={iconPreview} onFile={(f) => handleFileChange(f, setIconFile, setIconPreview)} hint="Quadrado" />
              <ImageUploadField label="Banner Principal" preview={bannerPreview} onFile={(f) => handleFileChange(f, setBannerFile, setBannerPreview)} hint="16:9" />
              <ImageUploadField label="Banner Header" preview={bannerHeaderPreview} onFile={(f) => handleFileChange(f, setBannerHeaderFile, setBannerHeaderPreview)} hint="Header" />
              <ImageUploadField label="Banner Card" preview={bannerCardPreview} onFile={(f) => handleFileChange(f, setBannerCardFile, setBannerCardPreview)} hint="Card" />
            </div>
          </div>

          {/* Botões */}
          <div className="flex gap-3 pt-2">
            <button onClick={handleSave} disabled={saving}
              className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl text-[13px] font-semibold transition-all disabled:opacity-50"
              style={{ background: "rgba(52,211,153,0.15)", border: "1px solid rgba(52,211,153,0.3)", color: "#34D399", fontFamily: "'Space Grotesk', sans-serif" }}>
              {saving ? <><Loader2 size={14} className="animate-spin" />Salvando...</> : <><Save size={14} />Salvar Alterações</>}
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

export default function CommunitiesPage() {
  const [communities, setCommunities] = useState<Community[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState<CommunityStatus | "all">("all");
  const [editing, setEditing] = useState<Community | null>(null);

  async function loadCommunities() {
    setLoading(true);
    const { data, error } = await supabase
      .from("communities")
      .select("id, name, tagline, description, endpoint, icon_url, banner_url, banner_header_url, banner_card_url, join_type, listed_status, is_searchable, members_count, posts_count, community_heat, category, theme_color, status, probation_status, created_at, welcome_message, rules, about_text")
      .order("members_count", { ascending: false });
    if (!error && data) setCommunities(data as Community[]);
    setLoading(false);
  }

  useEffect(() => { loadCommunities(); }, []);

  async function toggleStatus(community: Community, newStatus: CommunityStatus) {
    const { error } = await supabase.from("communities").update({ status: newStatus }).eq("id", community.id);
    if (error) { toast.error("Erro ao atualizar status."); return; }
    setCommunities((prev) => prev.map((c) => c.id === community.id ? { ...c, status: newStatus } : c));
    toast.success(`"${community.name}" agora está ${STATUS_CONFIG[newStatus].label.toLowerCase()}.`);
  }

  function handleSaved(updated: Community) {
    setCommunities((prev) => prev.map((c) => c.id === updated.id ? updated : c));
  }

  const filtered = communities.filter((c) => {
    const matchSearch = !search || c.name.toLowerCase().includes(search.toLowerCase()) || c.endpoint.toLowerCase().includes(search.toLowerCase());
    const matchStatus = statusFilter === "all" || c.status === statusFilter;
    return matchSearch && matchStatus;
  });

  const totalMembers = communities.reduce((s, c) => s + (c.members_count || 0), 0);
  const activeCount = communities.filter((c) => c.status === "active").length;

  return (
    <>
      <AnimatePresence>
        {editing && (
          <CommunityEditor community={editing} onClose={() => setEditing(null)} onSaved={handleSaved} />
        )}
      </AnimatePresence>

      <div className="p-4 md:p-6 max-w-7xl mx-auto space-y-5">
        {/* Header */}
        <motion.div variants={fadeUp} initial="hidden" animate="show" custom={0}>
          <div className="flex items-start justify-between gap-3">
            <div>
              <h1 className="text-[20px] font-bold tracking-tight" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.95)" }}>Comunidades</h1>
              <p className="text-[12px] font-mono mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>Gerenciar comunidades, assets visuais e configurações</p>
            </div>
            <button onClick={loadCommunities} className="w-8 h-8 rounded-xl flex items-center justify-center transition-all"
              style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.4)" }}>
              <RefreshCw size={13} />
            </button>
          </div>
        </motion.div>

        {/* Stats */}
        <motion.div variants={fadeUp} initial="hidden" animate="show" custom={1} className="grid grid-cols-3 gap-3">
          {[
            { label: "Total", value: communities.length, color: "#34D399", rgb: "52,211,153", icon: Globe },
            { label: "Membros", value: totalMembers.toLocaleString(), color: "#A78BFA", rgb: "167,139,250", icon: Users },
            { label: "Ativas", value: activeCount, color: "#60A5FA", rgb: "96,165,250", icon: CheckCircle2 },
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

        {/* Filtros */}
        <motion.div variants={fadeUp} initial="hidden" animate="show" custom={2} className="flex gap-2 flex-wrap">
          <div className="relative flex-1 min-w-[200px]">
            <Search size={13} className="absolute left-3 top-1/2 -translate-y-1/2" style={{ color: "rgba(255,255,255,0.25)" }} />
            <input placeholder="Buscar por nome ou endpoint..." value={search} onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-9 pr-3 py-2 rounded-xl text-[13px] outline-none"
              style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.85)", fontFamily: "'Space Grotesk', sans-serif" }} />
          </div>
          <div className="flex gap-1.5">
            {(["all", "active", "probation", "suspended", "archived"] as const).map((s) => {
              const cfg = s === "all" ? { label: "Todas", color: "#A78BFA" } : STATUS_CONFIG[s];
              return (
                <button key={s} onClick={() => setStatusFilter(s)}
                  className="px-3 py-1.5 rounded-xl text-[11px] font-mono transition-all"
                  style={{
                    background: statusFilter === s ? `${cfg.color}15` : "rgba(255,255,255,0.03)",
                    border: `1px solid ${statusFilter === s ? `${cfg.color}30` : "rgba(255,255,255,0.07)"}`,
                    color: statusFilter === s ? cfg.color : "rgba(255,255,255,0.3)",
                  }}>
                  {cfg.label}
                </button>
              );
            })}
          </div>
        </motion.div>

        {/* Lista */}
        {loading ? (
          <div className="space-y-2">{[...Array(5)].map((_, i) => <div key={i} className="h-20 rounded-xl" style={{ background: "rgba(255,255,255,0.03)" }} />)}</div>
        ) : filtered.length === 0 ? (
          <div className="rounded-2xl p-10 text-center" style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}>
            <Globe className="w-10 h-10 text-[#4B5563] mx-auto mb-3 opacity-40" />
            <p className="text-[#4B5563] text-sm">Nenhuma comunidade encontrada</p>
          </div>
        ) : (
          <motion.div variants={fadeUp} initial="hidden" animate="show" custom={3} className="space-y-2">
            {filtered.map((community, i) => {
              const statusCfg = STATUS_CONFIG[community.status] ?? STATUS_CONFIG.active;
              return (
                <motion.div key={community.id} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.02 }}
                  className="flex items-center gap-3 px-4 py-3 rounded-2xl"
                  style={{ background: "rgba(255,255,255,0.025)", border: `1px solid ${community.status !== "active" ? statusCfg.border : "rgba(255,255,255,0.07)"}` }}>

                  {/* Ícone */}
                  <div className="w-11 h-11 rounded-xl overflow-hidden flex-shrink-0 flex items-center justify-center"
                    style={{ background: community.theme_color ? `${community.theme_color}20` : "rgba(52,211,153,0.1)", border: `1px solid ${community.theme_color ? `${community.theme_color}30` : "rgba(52,211,153,0.2)"}` }}>
                    {community.icon_url ? (
                      <img src={community.icon_url} alt={community.name} className="w-full h-full object-cover" />
                    ) : (
                      <Globe size={18} style={{ color: community.theme_color ?? "#34D399" }} />
                    )}
                  </div>

                  {/* Info */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="text-[14px] font-semibold" style={{ color: "rgba(255,255,255,0.9)", fontFamily: "'Space Grotesk', sans-serif" }}>{community.name}</span>
                      <span className="text-[10px] font-mono px-1.5 py-0.5 rounded" style={{ background: statusCfg.bg, color: statusCfg.color, border: `1px solid ${statusCfg.border}` }}>
                        {statusCfg.label}
                      </span>
                      <span className="text-[10px] font-mono px-1.5 py-0.5 rounded" style={{ background: "rgba(255,255,255,0.05)", color: "rgba(255,255,255,0.4)" }}>
                        {JOIN_TYPE_LABELS[community.join_type]}
                      </span>
                    </div>
                    <div className="flex items-center gap-3 mt-0.5">
                      <span className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>/{community.endpoint}</span>
                      <span className="flex items-center gap-1 text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>
                        <Users size={10} />{(community.members_count || 0).toLocaleString()}
                      </span>
                      {community.community_heat > 0 && (
                        <span className="flex items-center gap-1 text-[11px] font-mono" style={{ color: "#F97316" }}>
                          <Flame size={10} />{community.community_heat}
                        </span>
                      )}
                    </div>
                  </div>

                  {/* Ações */}
                  <div className="flex items-center gap-2 flex-shrink-0">
                    {/* Toggle ativa/suspensa */}
                    {community.status === "active" ? (
                      <button onClick={() => toggleStatus(community, "suspended")}
                        className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl text-[11px] font-mono transition-all"
                        style={{ background: "rgba(239,68,68,0.08)", border: "1px solid rgba(239,68,68,0.15)", color: "#FCA5A5" }}>
                        <XCircle size={11} />Suspender
                      </button>
                    ) : community.status === "suspended" ? (
                      <button onClick={() => toggleStatus(community, "active")}
                        className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl text-[11px] font-mono transition-all"
                        style={{ background: "rgba(52,211,153,0.08)", border: "1px solid rgba(52,211,153,0.15)", color: "#34D399" }}>
                        <CheckCircle2 size={11} />Ativar
                      </button>
                    ) : null}

                    <button onClick={() => setEditing(community)}
                      className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl text-[11px] font-mono transition-all"
                      style={{ background: "rgba(52,211,153,0.08)", border: "1px solid rgba(52,211,153,0.15)", color: "#34D399" }}>
                      <Edit2 size={11} />Editar
                    </button>
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
