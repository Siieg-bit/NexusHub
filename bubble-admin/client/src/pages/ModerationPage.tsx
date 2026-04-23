import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { toast } from "sonner";
import {
  Shield, Flag, AlertTriangle, CheckCircle2, XCircle, Clock,
  RefreshCw, ChevronDown, User, MessageSquare, FileText,
  Ban, Eye, Hash, Calendar, Filter,
} from "lucide-react";

// ─── Tipos ────────────────────────────────────────────────────────────────────

type FlagStatus = "pending" | "approved" | "rejected" | "all";
type FlagType = "spam" | "harassment" | "hate_speech" | "nsfw" | "misinformation" | "other";

type Flag = {
  id: string;
  reporter_id: string;
  target_type: string;
  target_id: string;
  flag_type: FlagType;
  reason: string | null;
  status: FlagStatus;
  resolved_by: string | null;
  resolved_at: string | null;
  resolution_note: string | null;
  created_at: string;
  community_id: string | null;
  reporter?: { username: string; display_name: string | null };
};

type Strike = {
  id: string;
  user_id: string;
  issued_by: string | null;
  reason: string;
  is_active: boolean;
  created_at: string;
  expires_at: string | null;
  user?: { username: string; display_name: string | null };
};

type ModerationLog = {
  id: string;
  action: string;
  target_type: string;
  target_id: string;
  severity: string | null;
  details: Record<string, unknown> | null;
  created_at: string;
  moderator?: { username: string };
};

const FLAG_TYPE_LABELS: Record<FlagType, string> = {
  spam: "Spam",
  harassment: "Assédio",
  hate_speech: "Discurso de Ódio",
  nsfw: "Conteúdo NSFW",
  misinformation: "Desinformação",
  other: "Outro",
};

const FLAG_TYPE_COLORS: Record<FlagType, string> = {
  spam: "#F59E0B",
  harassment: "#EF4444",
  hate_speech: "#DC2626",
  nsfw: "#EC4899",
  misinformation: "#8B5CF6",
  other: "#6B7280",
};

const STATUS_CONFIG = {
  pending: { label: "Pendente", color: "#F59E0B", bg: "rgba(245,158,11,0.1)", border: "rgba(245,158,11,0.2)", icon: Clock },
  approved: { label: "Aprovada", color: "#34D399", bg: "rgba(52,211,153,0.1)", border: "rgba(52,211,153,0.2)", icon: CheckCircle2 },
  rejected: { label: "Rejeitada", color: "#6B7280", bg: "rgba(107,114,128,0.1)", border: "rgba(107,114,128,0.2)", icon: XCircle },
  all: { label: "Todas", color: "#A78BFA", bg: "rgba(167,139,250,0.1)", border: "rgba(167,139,250,0.2)", icon: Filter },
};

const fadeUp = {
  hidden: { opacity: 0, y: 12 },
  show: (i: number) => ({ opacity: 1, y: 0, transition: { delay: i * 0.04, duration: 0.25, ease: "easeOut" } }),
};

// ─── Modal de resolução de flag ───────────────────────────────────────────────

function ResolveModal({
  flag,
  onClose,
  onResolved,
}: {
  flag: Flag;
  onClose: () => void;
  onResolved: (id: string, status: "approved" | "rejected", note: string) => void;
}) {
  const [action, setAction] = useState<"approved" | "rejected">("approved");
  const [note, setNote] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleResolve() {
    setLoading(true);
    try {
      const { data: { user } } = await supabase.auth.getUser();
      const { error } = await supabase.from("flags").update({
        status: action,
        resolved_by: user?.id ?? null,
        resolved_at: new Date().toISOString(),
        resolution_note: note.trim() || null,
      }).eq("id", flag.id);
      if (error) throw error;

      // Log da ação
      await supabase.from("moderation_logs").insert({
        moderator_id: user?.id,
        action: action === "approved" ? "flag_approved" : "flag_rejected",
        target_type: "flag",
        target_id: flag.id,
        severity: "low",
        details: { flag_type: flag.flag_type, note: note.trim() || null },
      });

      toast.success(`Denúncia ${action === "approved" ? "aprovada" : "rejeitada"} com sucesso.`);
      onResolved(flag.id, action, note);
      onClose();
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : "Erro ao resolver denúncia.");
    } finally { setLoading(false); }
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      style={{ background: "rgba(0,0,0,0.75)", backdropFilter: "blur(4px)" }}
      onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}
    >
      <motion.div
        initial={{ opacity: 0, scale: 0.95, y: 10 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        exit={{ opacity: 0, scale: 0.95, y: 10 }}
        className="w-full max-w-md rounded-2xl p-6 space-y-5"
        style={{ background: "#1C1E22", border: "1px solid rgba(239,68,68,0.2)" }}
      >
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-xl flex items-center justify-center" style={{ background: "rgba(239,68,68,0.1)" }}>
            <Flag size={16} style={{ color: "#EF4444" }} />
          </div>
          <div>
            <h3 className="text-[15px] font-bold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.95)" }}>Resolver Denúncia</h3>
            <p className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>{FLAG_TYPE_LABELS[flag.flag_type]} · {flag.target_type}</p>
          </div>
        </div>

        {/* Detalhes da flag */}
        {flag.reason && (
          <div className="p-3 rounded-xl" style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)" }}>
            <p className="text-[10px] font-mono tracking-widest uppercase mb-1" style={{ color: "rgba(255,255,255,0.3)" }}>Motivo do Denunciante</p>
            <p className="text-[13px]" style={{ color: "rgba(255,255,255,0.7)", fontFamily: "'Space Grotesk', sans-serif" }}>{flag.reason}</p>
          </div>
        )}

        {/* Ação */}
        <div className="flex gap-2">
          {(["approved", "rejected"] as const).map((opt) => (
            <button key={opt} onClick={() => setAction(opt)}
              className="flex-1 py-2.5 rounded-xl text-[13px] font-semibold transition-all flex items-center justify-center gap-2"
              style={{
                background: action === opt ? (opt === "approved" ? "rgba(52,211,153,0.15)" : "rgba(107,114,128,0.15)") : "rgba(255,255,255,0.04)",
                border: `1px solid ${action === opt ? (opt === "approved" ? "rgba(52,211,153,0.3)" : "rgba(107,114,128,0.3)") : "rgba(255,255,255,0.07)"}`,
                color: action === opt ? (opt === "approved" ? "#34D399" : "#9CA3AF") : "rgba(255,255,255,0.3)",
                fontFamily: "'Space Grotesk', sans-serif",
              }}>
              {opt === "approved" ? <><CheckCircle2 size={14} />Aprovar</> : <><XCircle size={14} />Rejeitar</>}
            </button>
          ))}
        </div>

        {/* Nota */}
        <div>
          <label className="text-[10px] font-mono tracking-widest uppercase mb-1.5 block" style={{ color: "rgba(255,255,255,0.3)" }}>Nota de Resolução (opcional)</label>
          <textarea value={note} onChange={(e) => setNote(e.target.value)} placeholder="Descreva a decisão tomada..." rows={3}
            className="w-full px-3 py-2 rounded-xl text-[13px] outline-none resize-none"
            style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.8)", fontFamily: "'Space Grotesk', sans-serif" }} />
        </div>

        <button onClick={handleResolve} disabled={loading}
          className="w-full py-2.5 rounded-xl text-[13px] font-semibold transition-all disabled:opacity-50"
          style={{
            background: action === "approved" ? "rgba(52,211,153,0.15)" : "rgba(107,114,128,0.15)",
            border: `1px solid ${action === "approved" ? "rgba(52,211,153,0.3)" : "rgba(107,114,128,0.3)"}`,
            color: action === "approved" ? "#34D399" : "#9CA3AF",
            fontFamily: "'Space Grotesk', sans-serif",
          }}>
          {loading ? "Processando..." : `Confirmar — ${action === "approved" ? "Aprovar" : "Rejeitar"}`}
        </button>

        <button onClick={onClose} className="w-full py-2 rounded-xl text-[12px] font-mono transition-all"
          style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)", color: "rgba(255,255,255,0.3)" }}>
          Cancelar
        </button>
      </motion.div>
    </div>
  );
}

// ─── Página principal ─────────────────────────────────────────────────────────

export default function ModerationPage() {
  const [tab, setTab] = useState<"flags" | "strikes" | "logs">("flags");
  const [flagFilter, setFlagFilter] = useState<FlagStatus>("pending");
  const [flags, setFlags] = useState<Flag[]>([]);
  const [strikes, setStrikes] = useState<Strike[]>([]);
  const [logs, setLogs] = useState<ModerationLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [resolveModal, setResolveModal] = useState<Flag | null>(null);
  const [expandedFlag, setExpandedFlag] = useState<string | null>(null);

  async function loadFlags() {
    setLoading(true);
    let query = supabase
      .from("flags")
      .select("*, reporter:profiles!reporter_id(username, display_name)")
      .order("created_at", { ascending: false })
      .limit(50);
    if (flagFilter !== "all") query = query.eq("status", flagFilter);
    const { data, error } = await query;
    if (!error && data) setFlags(data as Flag[]);
    setLoading(false);
  }

  async function loadStrikes() {
    setLoading(true);
    const { data, error } = await supabase
      .from("strikes")
      .select("*, user:profiles!user_id(username, display_name)")
      .order("created_at", { ascending: false })
      .limit(50);
    if (!error && data) setStrikes(data as Strike[]);
    setLoading(false);
  }

  async function loadLogs() {
    setLoading(true);
    const { data, error } = await supabase
      .from("moderation_logs")
      .select("*, moderator:profiles!moderator_id(username)")
      .order("created_at", { ascending: false })
      .limit(50);
    if (!error && data) setLogs(data as ModerationLog[]);
    setLoading(false);
  }

  useEffect(() => {
    if (tab === "flags") loadFlags();
    else if (tab === "strikes") loadStrikes();
    else loadLogs();
  }, [tab, flagFilter]);

  async function revokeStrike(strike: Strike) {
    if (!confirm(`Revogar strike de @${strike.user?.username}?`)) return;
    const { error } = await supabase.from("strikes").update({ is_active: false }).eq("id", strike.id);
    if (error) { toast.error("Erro ao revogar strike."); return; }
    setStrikes((prev) => prev.map((s) => s.id === strike.id ? { ...s, is_active: false } : s));
    toast.success("Strike revogado.");
  }

  function handleFlagResolved(id: string, status: "approved" | "rejected", note: string) {
    setFlags((prev) => prev.map((f) => f.id === id ? { ...f, status, resolution_note: note } : f));
  }

  const pendingCount = flags.filter((f) => f.status === "pending").length;
  const activeStrikesCount = strikes.filter((s) => s.is_active).length;

  return (
    <>
      <AnimatePresence>
        {resolveModal && (
          <ResolveModal flag={resolveModal} onClose={() => setResolveModal(null)} onResolved={handleFlagResolved} />
        )}
      </AnimatePresence>

      <div className="p-4 md:p-6 max-w-7xl mx-auto space-y-5">
        {/* Header */}
        <motion.div variants={fadeUp} initial="hidden" animate="show" custom={0}>
          <div className="flex items-start justify-between gap-3">
            <div>
              <h1 className="text-[20px] font-bold tracking-tight" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.95)" }}>
                Moderação
              </h1>
              <p className="text-[12px] font-mono mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>
                Central de denúncias, strikes e logs de ações
              </p>
            </div>
            <button onClick={() => { if (tab === "flags") loadFlags(); else if (tab === "strikes") loadStrikes(); else loadLogs(); }}
              className="w-8 h-8 rounded-xl flex items-center justify-center transition-all"
              style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.4)" }}>
              <RefreshCw size={13} />
            </button>
          </div>
        </motion.div>

        {/* Stats */}
        <motion.div variants={fadeUp} initial="hidden" animate="show" custom={1} className="grid grid-cols-3 gap-3">
          {[
            { label: "Denúncias Pendentes", value: pendingCount, color: "#F59E0B", rgb: "245,158,11", icon: Flag },
            { label: "Strikes Ativos", value: activeStrikesCount, color: "#F97316", rgb: "249,115,22", icon: AlertTriangle },
            { label: "Total de Logs", value: logs.length || "—", color: "#A78BFA", rgb: "167,139,250", icon: Shield },
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

        {/* Tabs */}
        <motion.div variants={fadeUp} initial="hidden" animate="show" custom={2} className="flex gap-2">
          {([
            { key: "flags", label: "Denúncias", icon: Flag },
            { key: "strikes", label: "Strikes", icon: AlertTriangle },
            { key: "logs", label: "Logs", icon: Shield },
          ] as const).map(({ key, label, icon: Icon }) => (
            <button key={key} onClick={() => setTab(key)}
              className="flex items-center gap-2 px-4 py-2 rounded-xl text-[13px] font-semibold transition-all"
              style={{
                background: tab === key ? "rgba(167,139,250,0.15)" : "rgba(255,255,255,0.04)",
                border: `1px solid ${tab === key ? "rgba(167,139,250,0.3)" : "rgba(255,255,255,0.07)"}`,
                color: tab === key ? "#A78BFA" : "rgba(255,255,255,0.4)",
                fontFamily: "'Space Grotesk', sans-serif",
              }}>
              <Icon size={13} />
              {label}
              {key === "flags" && pendingCount > 0 && (
                <span className="text-[10px] px-1.5 py-0.5 rounded-full font-mono" style={{ background: "rgba(245,158,11,0.2)", color: "#F59E0B" }}>{pendingCount}</span>
              )}
            </button>
          ))}
        </motion.div>

        {/* ── Flags Tab ── */}
        {tab === "flags" && (
          <motion.div key="flags" initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-4">
            {/* Filter */}
            <div className="flex gap-2 flex-wrap">
              {(["pending", "approved", "rejected", "all"] as FlagStatus[]).map((s) => {
                const cfg = STATUS_CONFIG[s];
                const Icon = cfg.icon;
                return (
                  <button key={s} onClick={() => setFlagFilter(s)}
                    className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-[12px] font-semibold transition-all"
                    style={{
                      background: flagFilter === s ? cfg.bg : "rgba(255,255,255,0.03)",
                      border: `1px solid ${flagFilter === s ? cfg.border : "rgba(255,255,255,0.07)"}`,
                      color: flagFilter === s ? cfg.color : "rgba(255,255,255,0.3)",
                      fontFamily: "'DM Mono', monospace",
                    }}>
                    <Icon size={11} />
                    {cfg.label}
                  </button>
                );
              })}
            </div>

            {loading ? (
              <div className="space-y-2">{[...Array(5)].map((_, i) => <div key={i} className="h-16 rounded-xl" style={{ background: "rgba(255,255,255,0.03)" }} />)}</div>
            ) : flags.length === 0 ? (
              <div className="rounded-2xl p-10 text-center" style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}>
                <CheckCircle2 className="w-10 h-10 text-[#34D399] mx-auto mb-3 opacity-40" />
                <p className="text-[#4B5563] text-sm">Nenhuma denúncia {flagFilter !== "all" ? STATUS_CONFIG[flagFilter].label.toLowerCase() : ""}</p>
              </div>
            ) : (
              <div className="space-y-2">
                {flags.map((flag, i) => {
                  const cfg = STATUS_CONFIG[flag.status as FlagStatus] ?? STATUS_CONFIG.pending;
                  const StatusIcon = cfg.icon;
                  const isExpanded = expandedFlag === flag.id;
                  return (
                    <motion.div key={flag.id} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.02 }}
                      className="rounded-xl overflow-hidden"
                      style={{ background: "rgba(255,255,255,0.025)", border: `1px solid ${isExpanded ? cfg.border : "rgba(255,255,255,0.07)"}` }}>
                      {/* Row */}
                      <div className="flex items-center gap-3 px-4 py-3 cursor-pointer"
                        onClick={() => setExpandedFlag(isExpanded ? null : flag.id)}>
                        {/* Type badge */}
                        <div className="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0"
                          style={{ background: `${FLAG_TYPE_COLORS[flag.flag_type]}15` }}>
                          <Flag size={14} style={{ color: FLAG_TYPE_COLORS[flag.flag_type] }} />
                        </div>

                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2 flex-wrap">
                            <span className="text-[13px] font-semibold" style={{ color: "rgba(255,255,255,0.9)", fontFamily: "'Space Grotesk', sans-serif" }}>
                              {FLAG_TYPE_LABELS[flag.flag_type]}
                            </span>
                            <span className="text-[10px] px-1.5 py-0.5 rounded font-mono"
                              style={{ background: `${FLAG_TYPE_COLORS[flag.flag_type]}15`, color: FLAG_TYPE_COLORS[flag.flag_type] }}>
                              {flag.target_type}
                            </span>
                          </div>
                          <p className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>
                            por @{flag.reporter?.username ?? "anônimo"} · {new Date(flag.created_at).toLocaleDateString("pt-BR")}
                          </p>
                        </div>

                        <div className="flex items-center gap-2 flex-shrink-0">
                          <span className="flex items-center gap-1 text-[11px] px-2 py-0.5 rounded-full font-mono"
                            style={{ background: cfg.bg, color: cfg.color, border: `1px solid ${cfg.border}` }}>
                            <StatusIcon size={10} />
                            {cfg.label}
                          </span>
                          <ChevronDown size={14} className={`transition-transform ${isExpanded ? "rotate-180" : ""}`} style={{ color: "rgba(255,255,255,0.3)" }} />
                        </div>
                      </div>

                      {/* Expanded */}
                      <AnimatePresence>
                        {isExpanded && (
                          <motion.div initial={{ height: 0, opacity: 0 }} animate={{ height: "auto", opacity: 1 }} exit={{ height: 0, opacity: 0 }}
                            className="overflow-hidden">
                            <div className="px-4 pb-4 space-y-3" style={{ borderTop: "1px solid rgba(255,255,255,0.05)" }}>
                              <div className="pt-3 grid grid-cols-2 gap-3">
                                <div className="space-y-1">
                                  <p className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.3)" }}>Target ID</p>
                                  <div className="flex items-center gap-1.5">
                                    <Hash size={11} style={{ color: "rgba(255,255,255,0.3)" }} />
                                    <p className="text-[11px] font-mono truncate" style={{ color: "rgba(255,255,255,0.5)" }}>{flag.target_id}</p>
                                  </div>
                                </div>
                                <div className="space-y-1">
                                  <p className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.3)" }}>Data</p>
                                  <div className="flex items-center gap-1.5">
                                    <Calendar size={11} style={{ color: "rgba(255,255,255,0.3)" }} />
                                    <p className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.5)" }}>{new Date(flag.created_at).toLocaleString("pt-BR")}</p>
                                  </div>
                                </div>
                              </div>

                              {flag.reason && (
                                <div className="p-3 rounded-xl" style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)" }}>
                                  <p className="text-[10px] font-mono tracking-widest uppercase mb-1" style={{ color: "rgba(255,255,255,0.3)" }}>Motivo</p>
                                  <p className="text-[13px]" style={{ color: "rgba(255,255,255,0.7)", fontFamily: "'Space Grotesk', sans-serif" }}>{flag.reason}</p>
                                </div>
                              )}

                              {flag.resolution_note && (
                                <div className="p-3 rounded-xl" style={{ background: `${cfg.bg}`, border: `1px solid ${cfg.border}` }}>
                                  <p className="text-[10px] font-mono tracking-widest uppercase mb-1" style={{ color: cfg.color }}>Nota de Resolução</p>
                                  <p className="text-[13px]" style={{ color: "rgba(255,255,255,0.7)", fontFamily: "'Space Grotesk', sans-serif" }}>{flag.resolution_note}</p>
                                </div>
                              )}

                              {flag.status === "pending" && (
                                <button onClick={() => setResolveModal(flag)}
                                  className="flex items-center gap-2 px-4 py-2 rounded-xl text-[13px] font-semibold transition-all"
                                  style={{ background: "rgba(167,139,250,0.1)", border: "1px solid rgba(167,139,250,0.2)", color: "#A78BFA", fontFamily: "'Space Grotesk', sans-serif" }}>
                                  <Eye size={14} />
                                  Resolver Denúncia
                                </button>
                              )}
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
        )}

        {/* ── Strikes Tab ── */}
        {tab === "strikes" && (
          <motion.div key="strikes" initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-3">
            {loading ? (
              <div className="space-y-2">{[...Array(5)].map((_, i) => <div key={i} className="h-16 rounded-xl" style={{ background: "rgba(255,255,255,0.03)" }} />)}</div>
            ) : strikes.length === 0 ? (
              <div className="rounded-2xl p-10 text-center" style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}>
                <Shield className="w-10 h-10 text-[#34D399] mx-auto mb-3 opacity-40" />
                <p className="text-[#4B5563] text-sm">Nenhum strike registrado</p>
              </div>
            ) : (
              strikes.map((strike, i) => (
                <motion.div key={strike.id} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.02 }}
                  className="flex items-center gap-3 px-4 py-3 rounded-xl"
                  style={{
                    background: "rgba(255,255,255,0.025)",
                    border: `1px solid ${strike.is_active ? "rgba(249,115,22,0.2)" : "rgba(255,255,255,0.07)"}`,
                    opacity: strike.is_active ? 1 : 0.5,
                  }}>
                  <div className="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0"
                    style={{ background: strike.is_active ? "rgba(249,115,22,0.1)" : "rgba(255,255,255,0.05)" }}>
                    <AlertTriangle size={14} style={{ color: strike.is_active ? "#F97316" : "#6B7280" }} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <span className="text-[13px] font-semibold" style={{ color: "rgba(255,255,255,0.9)", fontFamily: "'Space Grotesk', sans-serif" }}>
                        @{strike.user?.username ?? strike.user_id.slice(0, 8)}
                      </span>
                      <span className={`text-[10px] px-1.5 py-0.5 rounded font-mono ${strike.is_active ? "text-[#F97316]" : "text-[#6B7280]"}`}
                        style={{ background: strike.is_active ? "rgba(249,115,22,0.1)" : "rgba(107,114,128,0.1)" }}>
                        {strike.is_active ? "ATIVO" : "REVOGADO"}
                      </span>
                    </div>
                    <p className="text-[11px] font-mono truncate" style={{ color: "rgba(255,255,255,0.4)" }}>{strike.reason}</p>
                    <p className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.2)" }}>{new Date(strike.created_at).toLocaleDateString("pt-BR")}</p>
                  </div>
                  {strike.is_active && (
                    <button onClick={() => revokeStrike(strike)}
                      className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-[12px] font-semibold transition-all"
                      style={{ background: "rgba(52,211,153,0.1)", border: "1px solid rgba(52,211,153,0.2)", color: "#34D399", fontFamily: "'DM Mono', monospace" }}>
                      <XCircle size={12} />
                      Revogar
                    </button>
                  )}
                </motion.div>
              ))
            )}
          </motion.div>
        )}

        {/* ── Logs Tab ── */}
        {tab === "logs" && (
          <motion.div key="logs" initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-3">
            {loading ? (
              <div className="space-y-2">{[...Array(5)].map((_, i) => <div key={i} className="h-14 rounded-xl" style={{ background: "rgba(255,255,255,0.03)" }} />)}</div>
            ) : logs.length === 0 ? (
              <div className="rounded-2xl p-10 text-center" style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}>
                <FileText className="w-10 h-10 text-[#4B5563] mx-auto mb-3 opacity-40" />
                <p className="text-[#4B5563] text-sm">Nenhum log de moderação</p>
              </div>
            ) : (
              <div className="rounded-2xl overflow-hidden" style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}>
                {logs.map((log, i) => (
                  <div key={log.id} className="flex items-center gap-3 px-4 py-3"
                    style={{ borderBottom: i < logs.length - 1 ? "1px solid rgba(255,255,255,0.04)" : "none" }}>
                    <div className="w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0"
                      style={{ background: "rgba(167,139,250,0.1)" }}>
                      <Shield size={12} style={{ color: "#A78BFA" }} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="text-[12px] font-mono" style={{ color: "#A78BFA" }}>{log.action}</span>
                        <span className="text-[10px] font-mono px-1.5 py-0.5 rounded" style={{ background: "rgba(255,255,255,0.05)", color: "rgba(255,255,255,0.4)" }}>{log.target_type}</span>
                      </div>
                      <p className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>
                        por @{log.moderator?.username ?? "sistema"} · {new Date(log.created_at).toLocaleString("pt-BR")}
                      </p>
                    </div>
                    {log.severity && (
                      <span className="text-[10px] font-mono px-1.5 py-0.5 rounded" style={{
                        background: log.severity === "high" ? "rgba(239,68,68,0.1)" : log.severity === "medium" ? "rgba(245,158,11,0.1)" : "rgba(52,211,153,0.1)",
                        color: log.severity === "high" ? "#FCA5A5" : log.severity === "medium" ? "#FCD34D" : "#6EE7B7",
                      }}>{log.severity}</span>
                    )}
                  </div>
                ))}
              </div>
            )}
          </motion.div>
        )}
      </div>
    </>
  );
}
