import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { toast } from "sonner";
import {
  Bell, Send, Clock, CheckCircle2, XCircle, RefreshCw,
  Users, Globe, Hash, Loader2, AlertTriangle, ChevronDown,
  Megaphone, Filter, Calendar,
} from "lucide-react";

// ─── Tipos ────────────────────────────────────────────────────────────────────

type NotifType = "announcement" | "maintenance" | "event" | "promotion" | "update" | "alert";
type NotifTarget = "all" | "community" | "role" | "specific";
type NotifStatus = "draft" | "sent" | "failed" | "scheduled";

type Notification = {
  id: string;
  title: string;
  body: string;
  type: NotifType;
  target_type: NotifTarget;
  target_value: string | null;
  status: NotifStatus;
  sent_count: number | null;
  scheduled_at: string | null;
  sent_at: string | null;
  created_at: string;
  created_by: string | null;
  data: Record<string, unknown> | null;
};

const TYPE_CONFIG: Record<NotifType, { label: string; color: string; rgb: string; emoji: string }> = {
  announcement: { label: "Anúncio",     color: "#A78BFA", rgb: "167,139,250", emoji: "📢" },
  maintenance:  { label: "Manutenção",  color: "#F59E0B", rgb: "245,158,11",  emoji: "🔧" },
  event:        { label: "Evento",      color: "#34D399", rgb: "52,211,153",  emoji: "🎉" },
  promotion:    { label: "Promoção",    color: "#EC4899", rgb: "236,72,153",  emoji: "🎁" },
  update:       { label: "Atualização", color: "#60A5FA", rgb: "96,165,250",  emoji: "✨" },
  alert:        { label: "Alerta",      color: "#EF4444", rgb: "239,68,68",   emoji: "⚠️" },
};

const TARGET_CONFIG: Record<NotifTarget, { label: string; icon: React.ElementType }> = {
  all:       { label: "Todos os usuários", icon: Globe },
  community: { label: "Comunidade específica", icon: Hash },
  role:      { label: "Por cargo", icon: Users },
  specific:  { label: "Usuário específico", icon: Users },
};

const STATUS_CONFIG: Record<NotifStatus, { label: string; color: string; bg: string }> = {
  draft:     { label: "Rascunho",   color: "#9CA3AF", bg: "rgba(156,163,175,0.1)" },
  sent:      { label: "Enviada",    color: "#34D399", bg: "rgba(52,211,153,0.1)" },
  failed:    { label: "Falhou",     color: "#EF4444", bg: "rgba(239,68,68,0.1)" },
  scheduled: { label: "Agendada",   color: "#F59E0B", bg: "rgba(245,158,11,0.1)" },
};

const fadeUp = {
  hidden: { opacity: 0, y: 12 },
  show: (i: number) => ({ opacity: 1, y: 0, transition: { delay: i * 0.04, duration: 0.25, ease: "easeOut" } }),
};

// ─── Preview de notificação ───────────────────────────────────────────────────

function NotifPreview({ title, body, type }: { title: string; body: string; type: NotifType }) {
  const cfg = TYPE_CONFIG[type];
  return (
    <div className="rounded-2xl p-4 flex items-start gap-3"
      style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}>
      <div className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 text-lg"
        style={{ background: `rgba(${cfg.rgb},0.15)` }}>
        {cfg.emoji}
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-[13px] font-semibold leading-tight" style={{ color: "rgba(255,255,255,0.9)", fontFamily: "'Space Grotesk', sans-serif" }}>
          {title || "Título da notificação"}
        </p>
        <p className="text-[11px] mt-0.5 line-clamp-2" style={{ color: "rgba(255,255,255,0.5)", fontFamily: "'Space Grotesk', sans-serif" }}>
          {body || "Corpo da mensagem aparece aqui..."}
        </p>
        <p className="text-[10px] font-mono mt-1" style={{ color: "rgba(255,255,255,0.2)" }}>NexusHub · agora</p>
      </div>
    </div>
  );
}

// ─── Página principal ─────────────────────────────────────────────────────────

export default function BroadcastPage() {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [statusFilter, setStatusFilter] = useState<NotifStatus | "all">("all");
  const [expandedId, setExpandedId] = useState<string | null>(null);

  // Form state
  const [form, setForm] = useState({
    title: "",
    body: "",
    type: "announcement" as NotifType,
    target_type: "all" as NotifTarget,
    target_value: "",
    schedule: false,
    scheduled_at: "",
    deep_link: "",
  });

  async function loadNotifications() {
    setLoading(true);
    let query = supabase
      .from("notifications")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(50);
    if (statusFilter !== "all") query = query.eq("status", statusFilter);
    const { data, error } = await query;
    if (!error && data) setNotifications(data as Notification[]);
    setLoading(false);
  }

  useEffect(() => { loadNotifications(); }, [statusFilter]);

  async function handleSend() {
    if (!form.title.trim()) { toast.error("Defina um título."); return; }
    if (!form.body.trim()) { toast.error("Defina o corpo da mensagem."); return; }
    if ((form.target_type === "community" || form.target_type === "specific" || form.target_type === "role") && !form.target_value.trim()) {
      toast.error("Defina o valor do alvo (endpoint, user_id ou cargo)."); return;
    }
    setSending(true);
    try {
      const { data: { user } } = await supabase.auth.getUser();

      const payload = {
        title: form.title.trim(),
        body: form.body.trim(),
        type: form.type,
        target_type: form.target_type,
        target_value: form.target_value.trim() || null,
        status: form.schedule ? "scheduled" : "sent",
        scheduled_at: form.schedule && form.scheduled_at ? new Date(form.scheduled_at).toISOString() : null,
        sent_at: form.schedule ? null : new Date().toISOString(),
        created_by: user?.id ?? null,
        data: form.deep_link ? { deep_link: form.deep_link } : null,
      };

      const { data, error } = await supabase.from("notifications").insert(payload).select().single();
      if (error) throw error;

      toast.success(form.schedule ? "Notificação agendada!" : "Notificação enviada!");
      setNotifications((prev) => [data as Notification, ...prev]);

      // Reset form
      setForm({ title: "", body: "", type: "announcement", target_type: "all", target_value: "", schedule: false, scheduled_at: "", deep_link: "" });
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : "Erro ao enviar.");
    } finally { setSending(false); }
  }

  const sentCount = notifications.filter((n) => n.status === "sent").length;
  const scheduledCount = notifications.filter((n) => n.status === "scheduled").length;

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
            <p className="text-[12px] font-mono mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>Enviar notificações push para usuários e comunidades</p>
          </div>
          <button onClick={loadNotifications} className="w-8 h-8 rounded-xl flex items-center justify-center transition-all"
            style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.4)" }}>
            <RefreshCw size={13} />
          </button>
        </div>
      </motion.div>

      {/* Stats */}
      <motion.div variants={fadeUp} initial="hidden" animate="show" custom={1} className="grid grid-cols-3 gap-3">
        {[
          { label: "Total enviadas", value: sentCount, color: "#34D399", rgb: "52,211,153", icon: CheckCircle2 },
          { label: "Agendadas", value: scheduledCount, color: "#F59E0B", rgb: "245,158,11", icon: Clock },
          { label: "Histórico", value: notifications.length, color: "#A78BFA", rgb: "167,139,250", icon: Bell },
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
        {/* ── Formulário de envio ── */}
        <motion.div variants={fadeUp} initial="hidden" animate="show" custom={2}
          className="rounded-2xl p-5 space-y-4"
          style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(249,115,22,0.15)" }}>

          <div className="flex items-center gap-2 mb-1">
            <Megaphone size={15} style={{ color: "#F97316" }} />
            <h2 className="text-[14px] font-bold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.9)" }}>Nova Notificação</h2>
          </div>

          {/* Tipo */}
          <div className="space-y-1.5">
            <label className={labelClass} style={labelStyle}>Tipo</label>
            <div className="flex gap-1.5 flex-wrap">
              {Object.entries(TYPE_CONFIG).map(([type, cfg]) => (
                <button key={type} onClick={() => setForm({ ...form, type: type as NotifType })}
                  className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl text-[11px] font-mono transition-all"
                  style={{
                    background: form.type === type ? `rgba(${cfg.rgb},0.15)` : "rgba(255,255,255,0.03)",
                    border: `1px solid ${form.type === type ? `rgba(${cfg.rgb},0.3)` : "rgba(255,255,255,0.07)"}`,
                    color: form.type === type ? cfg.color : "rgba(255,255,255,0.3)",
                  }}>
                  {cfg.emoji} {cfg.label}
                </button>
              ))}
            </div>
          </div>

          {/* Alvo */}
          <div className="space-y-1.5">
            <label className={labelClass} style={labelStyle}>Destinatários</label>
            <div className="grid grid-cols-2 gap-1.5">
              {Object.entries(TARGET_CONFIG).map(([target, { label, icon: Icon }]) => (
                <button key={target} onClick={() => setForm({ ...form, target_type: target as NotifTarget, target_value: "" })}
                  className="flex items-center gap-2 px-3 py-2 rounded-xl text-[12px] transition-all"
                  style={{
                    background: form.target_type === target ? "rgba(249,115,22,0.12)" : "rgba(255,255,255,0.03)",
                    border: `1px solid ${form.target_type === target ? "rgba(249,115,22,0.25)" : "rgba(255,255,255,0.07)"}`,
                    color: form.target_type === target ? "#F97316" : "rgba(255,255,255,0.4)",
                    fontFamily: "'Space Grotesk', sans-serif",
                  }}>
                  <Icon size={12} />
                  {label}
                </button>
              ))}
            </div>
          </div>

          {/* Valor do alvo */}
          {form.target_type !== "all" && (
            <div className="space-y-1.5">
              <label className={labelClass} style={labelStyle}>
                {form.target_type === "community" ? "Endpoint da comunidade" : form.target_type === "role" ? "Cargo (user/moderator/admin)" : "User ID"}
              </label>
              <input value={form.target_value} onChange={(e) => setForm({ ...form, target_value: e.target.value })}
                placeholder={form.target_type === "community" ? "ex: gaming" : form.target_type === "role" ? "ex: moderator" : "ex: uuid..."}
                className={inputClass} style={{ ...inputStyle, fontFamily: "'DM Mono', monospace" }} />
            </div>
          )}

          {/* Título */}
          <div className="space-y-1.5">
            <label className={labelClass} style={labelStyle}>Título *</label>
            <input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} placeholder="Título da notificação..."
              className={inputClass} style={inputStyle} maxLength={100} />
            <p className="text-[10px] font-mono text-right" style={{ color: "rgba(255,255,255,0.2)" }}>{form.title.length}/100</p>
          </div>

          {/* Corpo */}
          <div className="space-y-1.5">
            <label className={labelClass} style={labelStyle}>Mensagem *</label>
            <textarea value={form.body} onChange={(e) => setForm({ ...form, body: e.target.value })} rows={3}
              placeholder="Corpo da notificação..." className={`${inputClass} resize-none`} style={inputStyle} maxLength={300} />
            <p className="text-[10px] font-mono text-right" style={{ color: "rgba(255,255,255,0.2)" }}>{form.body.length}/300</p>
          </div>

          {/* Deep link */}
          <div className="space-y-1.5">
            <label className={labelClass} style={labelStyle}>Deep Link (opcional)</label>
            <input value={form.deep_link} onChange={(e) => setForm({ ...form, deep_link: e.target.value })} placeholder="ex: nexushub://community/gaming"
              className={inputClass} style={{ ...inputStyle, fontFamily: "'DM Mono', monospace" }} />
          </div>

          {/* Agendar */}
          <div className="space-y-2">
            <div className="flex items-center gap-2">
              <button type="button" onClick={() => setForm({ ...form, schedule: !form.schedule })}
                className={`relative w-9 h-5 rounded-full transition-colors ${form.schedule ? "bg-[#F59E0B]" : "bg-[#2A2D34]"}`}>
                <span className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform ${form.schedule ? "translate-x-4" : "translate-x-0.5"}`} />
              </button>
              <span className="text-[12px] font-mono" style={{ color: "rgba(255,255,255,0.5)" }}>Agendar envio</span>
            </div>
            {form.schedule && (
              <input type="datetime-local" value={form.scheduled_at} onChange={(e) => setForm({ ...form, scheduled_at: e.target.value })}
                className={inputClass} style={{ ...inputStyle, fontFamily: "'DM Mono', monospace" }} />
            )}
          </div>

          {/* Preview */}
          {(form.title || form.body) && (
            <div className="space-y-1.5">
              <label className={labelClass} style={labelStyle}>Preview</label>
              <NotifPreview title={form.title} body={form.body} type={form.type} />
            </div>
          )}

          {/* Botão enviar */}
          <button onClick={handleSend} disabled={sending}
            className="w-full flex items-center justify-center gap-2 py-3 rounded-xl text-[14px] font-semibold transition-all disabled:opacity-50"
            style={{
              background: "rgba(249,115,22,0.15)",
              border: "1px solid rgba(249,115,22,0.3)",
              color: "#F97316",
              fontFamily: "'Space Grotesk', sans-serif",
            }}>
            {sending ? <><Loader2 size={15} className="animate-spin" />Enviando...</> : form.schedule ? <><Clock size={15} />Agendar Notificação</> : <><Send size={15} />Enviar Agora</>}
          </button>
        </motion.div>

        {/* ── Histórico ── */}
        <motion.div variants={fadeUp} initial="hidden" animate="show" custom={3} className="space-y-3">
          <div className="flex items-center justify-between">
            <h2 className="text-[14px] font-bold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.9)" }}>Histórico</h2>
            <div className="flex gap-1.5">
              {(["all", "sent", "scheduled", "failed"] as const).map((s) => {
                const cfg = s === "all" ? { label: "Todas", color: "#A78BFA" } : STATUS_CONFIG[s];
                return (
                  <button key={s} onClick={() => setStatusFilter(s)}
                    className="px-2.5 py-1 rounded-lg text-[10px] font-mono transition-all"
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
          </div>

          {loading ? (
            <div className="space-y-2">{[...Array(4)].map((_, i) => <div key={i} className="h-16 rounded-xl" style={{ background: "rgba(255,255,255,0.03)" }} />)}</div>
          ) : notifications.length === 0 ? (
            <div className="rounded-2xl p-8 text-center" style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}>
              <Bell className="w-8 h-8 text-[#4B5563] mx-auto mb-2 opacity-40" />
              <p className="text-[#4B5563] text-sm">Nenhuma notificação enviada</p>
            </div>
          ) : (
            <div className="space-y-2 max-h-[600px] overflow-y-auto pr-1">
              {notifications.map((n, i) => {
                const typeCfg = TYPE_CONFIG[n.type];
                const statusCfg = STATUS_CONFIG[n.status];
                const isExpanded = expandedId === n.id;
                return (
                  <motion.div key={n.id} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.02 }}
                    className="rounded-xl overflow-hidden cursor-pointer"
                    style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}
                    onClick={() => setExpandedId(isExpanded ? null : n.id)}>
                    <div className="flex items-center gap-3 px-4 py-3">
                      <div className="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 text-base"
                        style={{ background: `rgba(${typeCfg.rgb},0.12)` }}>
                        {typeCfg.emoji}
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-[13px] font-semibold truncate" style={{ color: "rgba(255,255,255,0.9)", fontFamily: "'Space Grotesk', sans-serif" }}>{n.title}</p>
                        <p className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>
                          {new Date(n.created_at).toLocaleString("pt-BR")} · {TARGET_CONFIG[n.target_type].label}
                        </p>
                      </div>
                      <div className="flex items-center gap-2 flex-shrink-0">
                        <span className="text-[10px] px-1.5 py-0.5 rounded font-mono" style={{ background: statusCfg.bg, color: statusCfg.color }}>{statusCfg.label}</span>
                        <ChevronDown size={13} className={`transition-transform ${isExpanded ? "rotate-180" : ""}`} style={{ color: "rgba(255,255,255,0.3)" }} />
                      </div>
                    </div>

                    <AnimatePresence>
                      {isExpanded && (
                        <motion.div initial={{ height: 0, opacity: 0 }} animate={{ height: "auto", opacity: 1 }} exit={{ height: 0, opacity: 0 }}
                          className="overflow-hidden">
                          <div className="px-4 pb-4 space-y-2" style={{ borderTop: "1px solid rgba(255,255,255,0.05)" }}>
                            <p className="text-[12px] pt-3" style={{ color: "rgba(255,255,255,0.6)", fontFamily: "'Space Grotesk', sans-serif" }}>{n.body}</p>
                            <div className="flex items-center gap-3 flex-wrap">
                              {n.target_value && (
                                <span className="flex items-center gap-1 text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>
                                  <Hash size={10} />{n.target_value}
                                </span>
                              )}
                              {n.sent_count != null && (
                                <span className="flex items-center gap-1 text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>
                                  <Users size={10} />{n.sent_count} entregues
                                </span>
                              )}
                              {n.scheduled_at && (
                                <span className="flex items-center gap-1 text-[10px] font-mono" style={{ color: "#F59E0B" }}>
                                  <Calendar size={10} />Agendada: {new Date(n.scheduled_at).toLocaleString("pt-BR")}
                                </span>
                              )}
                              {n.data?.deep_link && (
                                <span className="text-[10px] font-mono" style={{ color: "#60A5FA" }}>{String(n.data.deep_link)}</span>
                              )}
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
