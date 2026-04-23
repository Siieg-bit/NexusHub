import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { toast } from "sonner";
import {
  Bell, Send, RefreshCw, CheckCircle2, XCircle,
  Users, Globe, Hash, Loader2, ChevronDown,
  Megaphone, Calendar, Image as ImageIcon, Link,
  Trash2, ToggleLeft, ToggleRight,
} from "lucide-react";

// ─── Tipos (schema real: tabela broadcasts) ───────────────────────────────────
// broadcasts: id, author_id, community_id, title, content, image_url,
//             action_url, target_roles (text[]), is_active, created_at, expires_at

type TargetRole = "member" | "moderator" | "admin" | "premium";

type Broadcast = {
  id: string;
  author_id: string;
  community_id: string | null;
  title: string;
  content: string;
  image_url: string | null;
  action_url: string | null;
  target_roles: TargetRole[];
  is_active: boolean;
  created_at: string;
  expires_at: string | null;
};

const ROLE_CONFIG: Record<TargetRole, { label: string; color: string; rgb: string }> = {
  member:    { label: "Membros",      color: "#60A5FA", rgb: "96,165,250" },
  moderator: { label: "Moderadores",  color: "#A78BFA", rgb: "167,139,250" },
  admin:     { label: "Admins",       color: "#FBBF24", rgb: "251,191,36" },
  premium:   { label: "Premium",      color: "#EC4899", rgb: "236,72,153" },
};

const fadeUp = {
  hidden: { opacity: 0, y: 12 },
  show: (i: number) => ({ opacity: 1, y: 0, transition: { delay: i * 0.04, duration: 0.25, ease: "easeOut" } }),
};

// ─── Preview ──────────────────────────────────────────────────────────────────
function BroadcastPreview({ title, content }: { title: string; content: string }) {
  return (
    <div className="rounded-2xl p-4 flex items-start gap-3"
      style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}>
      <div className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 text-lg"
        style={{ background: "rgba(249,115,22,0.15)" }}>
        📢
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-[13px] font-semibold leading-tight" style={{ color: "rgba(255,255,255,0.9)", fontFamily: "'Space Grotesk', sans-serif" }}>
          {title || "Título do broadcast"}
        </p>
        <p className="text-[11px] mt-0.5 line-clamp-3" style={{ color: "rgba(255,255,255,0.5)", fontFamily: "'Space Grotesk', sans-serif" }}>
          {content || "Conteúdo da mensagem aparece aqui..."}
        </p>
        <p className="text-[10px] font-mono mt-1" style={{ color: "rgba(255,255,255,0.2)" }}>NexusHub · agora</p>
      </div>
    </div>
  );
}

// ─── Página principal ─────────────────────────────────────────────────────────
export default function BroadcastPage() {
  const [broadcasts, setBroadcasts] = useState<Broadcast[]>([]);
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [filterActive, setFilterActive] = useState<"all" | "active" | "inactive">("all");
  const [error, setError] = useState<string | null>(null);

  const [form, setForm] = useState({
    title: "",
    content: "",
    community_id: "",
    image_url: "",
    action_url: "",
    target_roles: ["member"] as TargetRole[],
    expires_at: "",
  });

  async function loadBroadcasts() {
    setLoading(true);
    setError(null);
    try {
      let query = supabase
        .from("broadcasts")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(50);
      if (filterActive === "active") query = query.eq("is_active", true);
      if (filterActive === "inactive") query = query.eq("is_active", false);
      const { data, error } = await query;
      if (error) throw error;
      setBroadcasts((data as Broadcast[]) ?? []);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Erro ao carregar broadcasts.";
      setError(msg);
      toast.error(msg);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { loadBroadcasts(); }, [filterActive]);

  function toggleRole(role: TargetRole) {
    setForm((prev) => ({
      ...prev,
      target_roles: prev.target_roles.includes(role)
        ? prev.target_roles.filter((r) => r !== role)
        : [...prev.target_roles, role],
    }));
  }

  async function handleSend() {
    if (!form.title.trim()) { toast.error("Defina um título."); return; }
    if (!form.content.trim()) { toast.error("Defina o conteúdo da mensagem."); return; }
    if (form.target_roles.length === 0) { toast.error("Selecione pelo menos um cargo alvo."); return; }
    setSending(true);
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error("Não autenticado. Faça login para enviar broadcasts.");

      const payload: Record<string, unknown> = {
        author_id: user.id,
        title: form.title.trim(),
        content: form.content.trim(),
        target_roles: form.target_roles,
        is_active: true,
        community_id: form.community_id.trim() || null,
        image_url: form.image_url.trim() || null,
        action_url: form.action_url.trim() || null,
        expires_at: form.expires_at ? new Date(form.expires_at).toISOString() : null,
      };

      const { data, error } = await supabase.from("broadcasts").insert(payload).select().single();
      if (error) throw error;

      toast.success("Broadcast publicado com sucesso!");
      setBroadcasts((prev) => [data as Broadcast, ...prev]);
      setForm({ title: "", content: "", community_id: "", image_url: "", action_url: "", target_roles: ["member"], expires_at: "" });
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : "Erro ao publicar.");
    } finally { setSending(false); }
  }

  async function toggleActive(b: Broadcast) {
    const { error } = await supabase.from("broadcasts").update({ is_active: !b.is_active }).eq("id", b.id);
    if (error) { toast.error("Erro ao atualizar."); return; }
    setBroadcasts((prev) => prev.map((x) => x.id === b.id ? { ...x, is_active: !b.is_active } : x));
    toast.success(b.is_active ? "Broadcast desativado." : "Broadcast reativado.");
  }

  async function deleteBroadcast(b: Broadcast) {
    if (!confirm(`Deletar "${b.title}"?`)) return;
    const { error } = await supabase.from("broadcasts").delete().eq("id", b.id);
    if (error) { toast.error("Erro ao deletar."); return; }
    setBroadcasts((prev) => prev.filter((x) => x.id !== b.id));
    toast.success("Broadcast removido.");
  }

  const activeCount = broadcasts.filter((b) => b.is_active).length;
  const inputClass = "w-full px-3 py-2 rounded-xl text-[13px] outline-none";
  const inputStyle = { background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.85)", fontFamily: "'Space Grotesk', sans-serif" };
  const labelClass = "text-[10px] font-mono tracking-widest uppercase block mb-1.5";
  const labelStyle = { color: "rgba(255,255,255,0.3)" };

  return (
    <div className="p-4 md:p-6 max-w-7xl mx-auto space-y-5">
      {/* Header */}
      <motion.div variants={fadeUp} initial="hidden" animate="show" custom={0}>
        <div className="flex items-start justify-between gap-3">
          <div>
            <h1 className="text-[20px] font-bold tracking-tight" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.95)" }}>Broadcast</h1>
            <p className="text-[12px] font-mono mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>Publicar mensagens para grupos de usuários</p>
          </div>
          <button onClick={loadBroadcasts} className="w-8 h-8 rounded-xl flex items-center justify-center transition-all"
            style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.4)" }}>
            <RefreshCw size={13} />
          </button>
        </div>
      </motion.div>

      {/* Stats */}
      <motion.div variants={fadeUp} initial="hidden" animate="show" custom={1} className="grid grid-cols-3 gap-3">
        {[
          { label: "Total", value: broadcasts.length, color: "#F97316", rgb: "249,115,22", icon: Megaphone },
          { label: "Ativos", value: activeCount, color: "#34D399", rgb: "52,211,153", icon: CheckCircle2 },
          { label: "Inativos", value: broadcasts.length - activeCount, color: "#6B7280", rgb: "107,114,128", icon: XCircle },
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

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
        {/* ── Formulário ── */}
        <motion.div variants={fadeUp} initial="hidden" animate="show" custom={2}
          className="rounded-2xl p-5 space-y-4"
          style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(249,115,22,0.15)" }}>

          <div className="flex items-center gap-2 mb-1">
            <Megaphone size={15} style={{ color: "#F97316" }} />
            <h2 className="text-[14px] font-bold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.9)" }}>Novo Broadcast</h2>
          </div>

          {/* Cargos alvo */}
          <div className="space-y-1.5">
            <label className={labelClass} style={labelStyle}>Cargos destinatários</label>
            <div className="flex gap-1.5 flex-wrap">
              {(Object.entries(ROLE_CONFIG) as [TargetRole, typeof ROLE_CONFIG[TargetRole]][]).map(([role, cfg]) => {
                const selected = form.target_roles.includes(role);
                return (
                  <button key={role} onClick={() => toggleRole(role)}
                    className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl text-[11px] font-mono transition-all"
                    style={{
                      background: selected ? `rgba(${cfg.rgb},0.15)` : "rgba(255,255,255,0.03)",
                      border: `1px solid ${selected ? `rgba(${cfg.rgb},0.3)` : "rgba(255,255,255,0.07)"}`,
                      color: selected ? cfg.color : "rgba(255,255,255,0.3)",
                    }}>
                    <Users size={10} />
                    {cfg.label}
                  </button>
                );
              })}
            </div>
          </div>

          {/* Comunidade específica (opcional) */}
          <div className="space-y-1.5">
            <label className={labelClass} style={labelStyle}>Comunidade (opcional — deixe vazio para global)</label>
            <input value={form.community_id} onChange={(e) => setForm({ ...form, community_id: e.target.value })}
              placeholder="UUID da comunidade..."
              className={inputClass} style={{ ...inputStyle, fontFamily: "'DM Mono', monospace" }} />
          </div>

          {/* Título */}
          <div className="space-y-1.5">
            <label className={labelClass} style={labelStyle}>Título *</label>
            <input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} placeholder="Título do broadcast..."
              className={inputClass} style={inputStyle} maxLength={200} />
            <p className="text-[10px] font-mono text-right" style={{ color: "rgba(255,255,255,0.2)" }}>{form.title.length}/200</p>
          </div>

          {/* Conteúdo */}
          <div className="space-y-1.5">
            <label className={labelClass} style={labelStyle}>Conteúdo *</label>
            <textarea value={form.content} onChange={(e) => setForm({ ...form, content: e.target.value })} rows={4}
              placeholder="Corpo da mensagem..." className={`${inputClass} resize-none`} style={inputStyle} maxLength={2000} />
            <p className="text-[10px] font-mono text-right" style={{ color: "rgba(255,255,255,0.2)" }}>{form.content.length}/2000</p>
          </div>

          {/* Imagem e link */}
          <div className="grid grid-cols-1 gap-3">
            <div className="space-y-1.5">
              <label className={labelClass} style={labelStyle}><ImageIcon size={9} className="inline mr-1" />URL da imagem (opcional)</label>
              <input value={form.image_url} onChange={(e) => setForm({ ...form, image_url: e.target.value })}
                placeholder="https://..." className={inputClass} style={{ ...inputStyle, fontFamily: "'DM Mono', monospace" }} />
            </div>
            <div className="space-y-1.5">
              <label className={labelClass} style={labelStyle}><Link size={9} className="inline mr-1" />URL de ação / deep link (opcional)</label>
              <input value={form.action_url} onChange={(e) => setForm({ ...form, action_url: e.target.value })}
                placeholder="nexushub://... ou https://..." className={inputClass} style={{ ...inputStyle, fontFamily: "'DM Mono', monospace" }} />
            </div>
          </div>

          {/* Expiração */}
          <div className="space-y-1.5">
            <label className={labelClass} style={labelStyle}><Calendar size={9} className="inline mr-1" />Expira em (opcional)</label>
            <input type="datetime-local" value={form.expires_at} onChange={(e) => setForm({ ...form, expires_at: e.target.value })}
              className={inputClass} style={{ ...inputStyle, fontFamily: "'DM Mono', monospace" }} />
          </div>

          {/* Preview */}
          {(form.title || form.content) && (
            <div className="space-y-1.5">
              <label className={labelClass} style={labelStyle}>Preview</label>
              <BroadcastPreview title={form.title} content={form.content} />
            </div>
          )}

          {/* Botão */}
          <button onClick={handleSend} disabled={sending}
            className="w-full flex items-center justify-center gap-2 py-3 rounded-xl text-[14px] font-semibold transition-all disabled:opacity-50"
            style={{ background: "rgba(249,115,22,0.15)", border: "1px solid rgba(249,115,22,0.3)", color: "#F97316", fontFamily: "'Space Grotesk', sans-serif" }}>
            {sending ? <><Loader2 size={15} className="animate-spin" />Publicando...</> : <><Send size={15} />Publicar Broadcast</>}
          </button>
        </motion.div>

        {/* ── Histórico ── */}
        <motion.div variants={fadeUp} initial="hidden" animate="show" custom={3} className="space-y-3">
          <div className="flex items-center justify-between">
            <h2 className="text-[14px] font-bold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.9)" }}>Histórico</h2>
            <div className="flex gap-1.5">
              {(["all", "active", "inactive"] as const).map((f) => {
                const labels = { all: "Todos", active: "Ativos", inactive: "Inativos" };
                const colors = { all: "#A78BFA", active: "#34D399", inactive: "#6B7280" };
                return (
                  <button key={f} onClick={() => setFilterActive(f)}
                    className="px-2.5 py-1 rounded-lg text-[10px] font-mono transition-all"
                    style={{
                      background: filterActive === f ? `${colors[f]}15` : "rgba(255,255,255,0.03)",
                      border: `1px solid ${filterActive === f ? `${colors[f]}30` : "rgba(255,255,255,0.07)"}`,
                      color: filterActive === f ? colors[f] : "rgba(255,255,255,0.3)",
                    }}>
                    {labels[f]}
                  </button>
                );
              })}
            </div>
          </div>

          {error && (
            <div className="p-3 rounded-xl" style={{ background: "rgba(239,68,68,0.08)", border: "1px solid rgba(239,68,68,0.2)" }}>
              <p className="text-[11px] font-mono" style={{ color: "#FCA5A5" }}>{error}</p>
            </div>
          )}

          {loading ? (
            <div className="space-y-2">{[...Array(4)].map((_, i) => <div key={i} className="h-16 rounded-xl animate-pulse" style={{ background: "rgba(255,255,255,0.03)" }} />)}</div>
          ) : broadcasts.length === 0 ? (
            <div className="rounded-2xl p-8 text-center" style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}>
              <Bell className="w-8 h-8 text-[#4B5563] mx-auto mb-2 opacity-40" />
              <p className="text-[#4B5563] text-sm">Nenhum broadcast publicado</p>
            </div>
          ) : (
            <div className="space-y-2 max-h-[600px] overflow-y-auto pr-1">
              {broadcasts.map((b, i) => {
                const isExpanded = expandedId === b.id;
                return (
                  <motion.div key={b.id} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.02 }}
                    className="rounded-xl overflow-hidden"
                    style={{
                      background: "rgba(255,255,255,0.025)",
                      border: `1px solid ${b.is_active ? "rgba(255,255,255,0.07)" : "rgba(255,255,255,0.03)"}`,
                      opacity: b.is_active ? 1 : 0.6,
                    }}>
                    <div className="flex items-center gap-3 px-4 py-3 cursor-pointer" onClick={() => setExpandedId(isExpanded ? null : b.id)}>
                      <div className="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 text-base"
                        style={{ background: "rgba(249,115,22,0.12)" }}>
                        📢
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-[13px] font-semibold truncate" style={{ color: "rgba(255,255,255,0.9)", fontFamily: "'Space Grotesk', sans-serif" }}>{b.title}</p>
                        <p className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>
                          {new Date(b.created_at).toLocaleString("pt-BR")}
                          {b.community_id ? " · Comunidade" : " · Global"}
                        </p>
                      </div>
                      <div className="flex items-center gap-1.5 flex-shrink-0">
                        {/* Badges de cargo */}
                        {(b.target_roles ?? []).slice(0, 2).map((role) => {
                          const cfg = ROLE_CONFIG[role as TargetRole] ?? { color: "#9CA3AF", label: role };
                          return (
                            <span key={role} className="text-[9px] px-1.5 py-0.5 rounded font-mono" style={{ background: `${cfg.color}15`, color: cfg.color }}>
                              {cfg.label}
                            </span>
                          );
                        })}
                        {(b.target_roles ?? []).length > 2 && (
                          <span className="text-[9px] px-1 py-0.5 rounded font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>+{b.target_roles.length - 2}</span>
                        )}
                        <span className="text-[9px] px-1.5 py-0.5 rounded font-mono ml-1" style={{ background: b.is_active ? "rgba(52,211,153,0.1)" : "rgba(107,114,128,0.1)", color: b.is_active ? "#34D399" : "#6B7280" }}>
                          {b.is_active ? "Ativo" : "Inativo"}
                        </span>
                        <ChevronDown size={13} className={`transition-transform ml-1 ${isExpanded ? "rotate-180" : ""}`} style={{ color: "rgba(255,255,255,0.3)" }} />
                      </div>
                    </div>

                    <AnimatePresence>
                      {isExpanded && (
                        <motion.div initial={{ height: 0, opacity: 0 }} animate={{ height: "auto", opacity: 1 }} exit={{ height: 0, opacity: 0 }}
                          className="overflow-hidden">
                          <div className="px-4 pb-4 space-y-3" style={{ borderTop: "1px solid rgba(255,255,255,0.05)" }}>
                            <p className="text-[12px] pt-3 whitespace-pre-wrap" style={{ color: "rgba(255,255,255,0.6)", fontFamily: "'Space Grotesk', sans-serif" }}>{b.content}</p>
                            <div className="flex items-center gap-2 flex-wrap">
                              {b.image_url && (
                                <a href={b.image_url} target="_blank" rel="noreferrer" className="text-[10px] font-mono flex items-center gap-1" style={{ color: "#60A5FA" }}>
                                  <ImageIcon size={10} />Imagem
                                </a>
                              )}
                              {b.action_url && (
                                <span className="text-[10px] font-mono flex items-center gap-1" style={{ color: "#A78BFA" }}>
                                  <Link size={10} />{b.action_url}
                                </span>
                              )}
                              {b.expires_at && (
                                <span className="text-[10px] font-mono flex items-center gap-1" style={{ color: "#F59E0B" }}>
                                  <Calendar size={10} />Expira: {new Date(b.expires_at).toLocaleString("pt-BR")}
                                </span>
                              )}
                            </div>
                            <div className="flex items-center gap-2 pt-1">
                              <button onClick={() => toggleActive(b)}
                                className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-[11px] font-mono transition-all"
                                style={{ background: b.is_active ? "rgba(107,114,128,0.08)" : "rgba(52,211,153,0.08)", border: `1px solid ${b.is_active ? "rgba(107,114,128,0.15)" : "rgba(52,211,153,0.15)"}`, color: b.is_active ? "#6B7280" : "#34D399" }}>
                                {b.is_active ? <><ToggleLeft size={10} />Desativar</> : <><ToggleRight size={10} />Reativar</>}
                              </button>
                              <button onClick={() => deleteBroadcast(b)} className="ml-auto p-1.5 rounded-lg text-[#4B5563] hover:text-red-400 hover:bg-red-500/10 transition-colors">
                                <Trash2 size={12} />
                              </button>
                            </div>
                          </div>
                        </motion.div>
                      )}
                    </AnimatePresence>
                  </motion.div>
                );
              })}
            </div>
          )}
        </motion.div>
      </div>
    </div>
  );
}
