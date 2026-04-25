import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { supabase, supabaseAdmin } from "@/lib/supabase";
import { toast } from "sonner";
import {
  Shield, Flag, AlertTriangle, CheckCircle2, XCircle, Clock,
  RefreshCw, ChevronDown, FileText, Eye, Hash, Calendar, Filter,
  User, ArrowRight, Swords, Camera, Bot, Image as ImageIcon,
  MessageSquare, X, ChevronRight, Loader2,
} from "lucide-react";

// ─── Tipos ────────────────────────────────────────────────────────────────────
type FlagStatus = "pending" | "resolved" | "dismissed" | "all";
type FlagType = "spam" | "harassment" | "hate_speech" | "nsfw" | "misinformation" | "other";

type Flag = {
  id: string;
  community_id: string;
  reporter_id: string;
  target_user_id: string | null;
  target_post_id: string | null;
  target_wiki_id: string | null;
  target_comment_id: string | null;
  target_chat_message_id: string | null;
  target_chat_thread_id: string | null;
  target_story_id: string | null;
  flag_type: FlagType;
  reason: string | null;
  evidence_urls: string[];
  status: string;
  resolved_by: string | null;
  resolution_note: string | null;
  resolved_at: string | null;
  created_at: string;
  bot_analyzed: boolean;
  bot_verdict: string | null;
  auto_actioned: boolean;
  reporter?: { nickname: string | null; amino_id: string | null };
};

type Strike = {
  id: string;
  community_id: string;
  user_id: string;
  issued_by: string | null;
  reason: string;
  is_active: boolean;
  created_at: string;
  expires_at: string | null;
  user?: { nickname: string | null; amino_id: string | null };
};

type ModerationLog = {
  id: string;
  community_id: string | null;
  moderator_id: string | null;
  action: string;
  severity: string | null;
  target_user_id: string | null;
  target_post_id: string | null;
  target_wiki_id: string | null;
  target_comment_id: string | null;
  target_chat_thread_id: string | null;
  reason: string | null;
  details: Record<string, unknown> | null;
  duration_hours: number | null;
  created_at: string;
  moderator?: { nickname: string | null; amino_id: string | null };
  target_user?: { nickname: string | null; amino_id: string | null };
};

// Snapshot retornado pelo RPC get_flag_detail
type FlagDetail = {
  flag: Record<string, unknown>;
  snapshot: {
    id: string;
    content_type: string;
    captured_at: string;
    bot_verdict: string | null;
    bot_score: number | null;
    snapshot_data: Record<string, unknown>;
  } | null;
  bot_actions: Record<string, unknown>[];
};

// ─── Constantes ───────────────────────────────────────────────────────────────
const FLAG_TYPE_LABELS: Record<string, string> = {
  spam: "Spam",
  harassment: "Assédio",
  hate_speech: "Discurso de Ódio",
  nsfw: "Conteúdo NSFW",
  misinformation: "Desinformação",
  other: "Outro",
};

const FLAG_TYPE_COLORS: Record<string, string> = {
  spam: "#F59E0B",
  harassment: "#EF4444",
  hate_speech: "#DC2626",
  nsfw: "#EC4899",
  misinformation: "#8B5CF6",
  other: "#6B7280",
};

const CONTENT_TYPE_LABELS: Record<string, string> = {
  post: "Post",
  comment: "Comentário",
  chat_message: "Mensagem de Chat",
  profile: "Perfil",
  wiki: "Wiki",
  story: "Story",
};

const STATUS_CONFIG = {
  pending:   { label: "Pendente",   color: "#F59E0B", bg: "rgba(245,158,11,0.1)",  border: "rgba(245,158,11,0.2)",  icon: Clock },
  resolved:  { label: "Resolvida",  color: "#34D399", bg: "rgba(52,211,153,0.1)",  border: "rgba(52,211,153,0.2)",  icon: CheckCircle2 },
  dismissed: { label: "Descartada", color: "#6B7280", bg: "rgba(107,114,128,0.1)", border: "rgba(107,114,128,0.2)", icon: XCircle },
  all:       { label: "Todas",      color: "#A78BFA", bg: "rgba(167,139,250,0.1)", border: "rgba(167,139,250,0.2)", icon: Filter },
};

const BOT_VERDICT_CONFIG: Record<string, { label: string; color: string; bg: string }> = {
  clean:        { label: "Limpo",        color: "#34D399", bg: "rgba(52,211,153,0.1)" },
  suspicious:   { label: "Suspeito",     color: "#F59E0B", bg: "rgba(245,158,11,0.1)" },
  auto_removed: { label: "Auto-removido",color: "#EF4444", bg: "rgba(239,68,68,0.1)" },
  escalated:    { label: "Escalado",     color: "#A78BFA", bg: "rgba(167,139,250,0.1)" },
};

const fadeUp = {
  hidden: { opacity: 0, y: 12 },
  show: (i: number) => ({ opacity: 1, y: 0, transition: { delay: i * 0.04, duration: 0.25, ease: "easeOut" as const } }),
};

function displayUser(u: { nickname: string | null; amino_id: string | null } | undefined, fallback: string) {
  if (!u) return fallback.slice(0, 8);
  return u.nickname || u.amino_id || fallback.slice(0, 8);
}

function fmtDate(iso: string | null | undefined) {
  if (!iso) return "—";
  try {
    return new Date(iso).toLocaleString("pt-BR");
  } catch { return iso; }
}

// ─── Drawer de detalhes da denúncia (snapshot) ───────────────────────────────
function FlagDetailDrawer({
  flagId,
  flag,
  onClose,
  onResolved,
}: {
  flagId: string;
  flag: Flag;
  onClose: () => void;
  onResolved: (id: string, status: "resolved" | "dismissed", note: string) => void;
}) {
  const [detail, setDetail] = useState<FlagDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [resolveAction, setResolveAction] = useState<"resolved" | "dismissed">("resolved");
  const [note, setNote] = useState("");
  const [resolving, setResolving] = useState(false);
  const [showResolveForm, setShowResolveForm] = useState(false);

  useEffect(() => {
    async function load() {
      setLoading(true);
      try {
        const { data, error } = await supabaseAdmin.rpc("get_flag_detail", { p_flag_id: flagId });
        if (error) throw error;
        setDetail(data as FlagDetail);
      } catch (err) {
        toast.error("Erro ao carregar detalhes da denúncia.");
        console.error(err);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, [flagId]);

  async function handleResolve() {
    setResolving(true);
    try {
      const { data: { user } } = await supabase.auth.getUser();
      const { error } = await supabaseAdmin.from("flags").update({
        status: resolveAction,
        resolved_by: user?.id ?? null,
        resolution_note: note.trim() || null,
        resolved_at: new Date().toISOString(),
      }).eq("id", flagId);
      if (error) throw error;

      if (flag.community_id) {
        await supabaseAdmin.from("moderation_logs").insert({
          community_id: flag.community_id,
          moderator_id: user?.id,
          action: resolveAction === "resolved" ? "flag_resolved" : "flag_dismissed",
          severity: "low",
          target_user_id: flag.target_user_id ?? null,
          reason: note.trim() || null,
          details: { flag_type: flag.flag_type, flag_id: flagId },
        });
      }

      toast.success(`Denúncia ${resolveAction === "resolved" ? "resolvida" : "descartada"} com sucesso.`);
      onResolved(flagId, resolveAction, note);
      onClose();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Erro ao resolver denúncia.");
    } finally {
      setResolving(false);
    }
  }

  const snapshot = detail?.snapshot;
  const data = snapshot?.snapshot_data ?? {};
  const contentType = snapshot?.content_type ?? "";
  const hasError = data && typeof data === "object" && "error" in data;
  const botVerdict = snapshot?.bot_verdict;
  const botCfg = botVerdict ? BOT_VERDICT_CONFIG[botVerdict] : null;
  const isPending = flag.status === "pending";

  return (
    // Overlay
    <div
      className="fixed inset-0 z-50 flex"
      style={{ background: "rgba(0,0,0,0.6)", backdropFilter: "blur(4px)" }}
      onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}
    >
      {/* Drawer lateral */}
      <motion.div
        initial={{ x: "100%" }}
        animate={{ x: 0 }}
        exit={{ x: "100%" }}
        transition={{ type: "spring", damping: 28, stiffness: 280 }}
        className="ml-auto h-full w-full max-w-xl flex flex-col overflow-hidden"
        style={{ background: "#13151A", borderLeft: "1px solid rgba(255,255,255,0.07)" }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header do drawer */}
        <div className="flex items-center gap-3 px-5 py-4" style={{ borderBottom: "1px solid rgba(255,255,255,0.06)" }}>
          <div className="w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0"
            style={{ background: `${FLAG_TYPE_COLORS[flag.flag_type] ?? "#6B7280"}18` }}>
            <Flag size={16} style={{ color: FLAG_TYPE_COLORS[flag.flag_type] ?? "#6B7280" }} />
          </div>
          <div className="flex-1 min-w-0">
            <h2 className="text-[15px] font-bold truncate" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.95)" }}>
              {FLAG_TYPE_LABELS[flag.flag_type] ?? flag.flag_type}
            </h2>
            <p className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>
              {fmtDate(flag.created_at)} · por {displayUser(flag.reporter, flag.reporter_id ?? "anônimo")}
            </p>
          </div>
          <button onClick={onClose}
            className="w-8 h-8 rounded-xl flex items-center justify-center transition-all"
            style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.4)" }}>
            <X size={14} />
          </button>
        </div>

        {/* Conteúdo rolável */}
        <div className="flex-1 overflow-y-auto p-5 space-y-4">
          {loading ? (
            <div className="flex flex-col items-center justify-center py-20 gap-3">
              <Loader2 size={24} className="animate-spin" style={{ color: "#A78BFA" }} />
              <p className="text-[12px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>Carregando snapshot...</p>
            </div>
          ) : (
            <>
              {/* ── Informações da denúncia ── */}
              <section className="rounded-xl p-4 space-y-3" style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}>
                <p className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.3)" }}>Informações da Denúncia</p>
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <p className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>Tipo</p>
                    <p className="text-[13px] font-semibold mt-0.5" style={{ color: FLAG_TYPE_COLORS[flag.flag_type] ?? "#fff", fontFamily: "'Space Grotesk', sans-serif" }}>
                      {FLAG_TYPE_LABELS[flag.flag_type] ?? flag.flag_type}
                    </p>
                  </div>
                  <div>
                    <p className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>Status</p>
                    <div className="flex items-center gap-1.5 mt-0.5">
                      {(() => {
                        const sk = (flag.status as FlagStatus) in STATUS_CONFIG ? (flag.status as FlagStatus) : "pending";
                        const cfg = STATUS_CONFIG[sk];
                        const Icon = cfg.icon;
                        return (
                          <span className="flex items-center gap-1 text-[11px] px-2 py-0.5 rounded-full font-mono"
                            style={{ background: cfg.bg, color: cfg.color, border: `1px solid ${cfg.border}` }}>
                            <Icon size={10} />{cfg.label}
                          </span>
                        );
                      })()}
                    </div>
                  </div>
                  <div>
                    <p className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>Tipo de Conteúdo</p>
                    <p className="text-[12px] font-mono mt-0.5" style={{ color: "rgba(255,255,255,0.6)" }}>
                      {contentType ? (CONTENT_TYPE_LABELS[contentType] ?? contentType) : (
                        flag.target_post_id ? "Post" :
                        flag.target_comment_id ? "Comentário" :
                        flag.target_chat_message_id ? "Mensagem" :
                        flag.target_wiki_id ? "Wiki" :
                        flag.target_story_id ? "Story" :
                        flag.target_user_id ? "Perfil" : "—"
                      )}
                    </p>
                  </div>
                  <div>
                    <p className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>Bot</p>
                    <div className="mt-0.5">
                      {botCfg ? (
                        <span className="text-[11px] px-2 py-0.5 rounded-full font-mono"
                          style={{ background: botCfg.bg, color: botCfg.color }}>
                          {botCfg.label}
                          {snapshot?.bot_score != null ? ` · ${Math.round(snapshot.bot_score * 100)}%` : ""}
                        </span>
                      ) : (
                        <span className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.25)" }}>Não analisado</span>
                      )}
                    </div>
                  </div>
                </div>
                {flag.reason && (
                  <div className="pt-2" style={{ borderTop: "1px solid rgba(255,255,255,0.05)" }}>
                    <p className="text-[10px] font-mono tracking-widest uppercase mb-1" style={{ color: "rgba(255,255,255,0.3)" }}>Motivo do Denunciante</p>
                    <p className="text-[13px]" style={{ color: "rgba(255,255,255,0.75)", fontFamily: "'Space Grotesk', sans-serif", lineHeight: 1.5 }}>{flag.reason}</p>
                  </div>
                )}
              </section>

              {/* ── Snapshot do conteúdo ── */}
              {snapshot ? (
                <section className="rounded-xl overflow-hidden" style={{ border: hasError ? "1px solid rgba(245,158,11,0.3)" : "1px solid rgba(167,139,250,0.2)" }}>
                  {/* Header do snapshot */}
                  <div className="flex items-center gap-2 px-4 py-2.5"
                    style={{ background: hasError ? "rgba(245,158,11,0.08)" : "rgba(167,139,250,0.08)" }}>
                    <Camera size={13} style={{ color: hasError ? "#F59E0B" : "#A78BFA" }} />
                    <p className="text-[11px] font-semibold tracking-wide uppercase"
                      style={{ color: hasError ? "#F59E0B" : "#A78BFA", fontFamily: "'DM Mono', monospace" }}>
                      {hasError
                        ? "Snapshot Parcial — conteúdo excluído antes da captura"
                        : `Snapshot do Conteúdo (${CONTENT_TYPE_LABELS[contentType] ?? contentType})`}
                    </p>
                    {botCfg && (
                      <span className="ml-auto text-[10px] px-2 py-0.5 rounded-full font-mono flex items-center gap-1"
                        style={{ background: botCfg.bg, color: botCfg.color }}>
                        <Bot size={9} />
                        {botCfg.label}
                      </span>
                    )}
                  </div>

                  <div className="p-4 space-y-3" style={{ background: "rgba(255,255,255,0.015)" }}>
                    {hasError ? (
                      <p className="text-[13px]" style={{ color: "#F59E0B", fontFamily: "'Space Grotesk', sans-serif" }}>
                        {(data as Record<string, unknown>)["note"] as string ?? "O conteúdo foi excluído antes do snapshot ser capturado."}
                      </p>
                    ) : (
                      <>
                        {/* Autor */}
                        {((data["author_nickname"] ?? data["sender_nickname"]) as string | undefined) && (
                          <div className="flex items-center gap-2">
                            <div className="w-7 h-7 rounded-full flex items-center justify-center flex-shrink-0"
                              style={{ background: "rgba(167,139,250,0.15)" }}>
                              <User size={12} style={{ color: "#A78BFA" }} />
                            </div>
                            <div>
                              <p className="text-[13px] font-semibold" style={{ color: "rgba(255,255,255,0.9)", fontFamily: "'Space Grotesk', sans-serif" }}>
                                {(data["author_nickname"] ?? data["sender_nickname"]) as string}
                              </p>
                              {data["created_at"] && (
                                <p className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>
                                  {fmtDate(data["created_at"] as string)}
                                </p>
                              )}
                            </div>
                          </div>
                        )}

                        {/* Título */}
                        {(data["title"] as string | undefined) && (
                          <p className="text-[15px] font-bold" style={{ color: "rgba(255,255,255,0.95)", fontFamily: "'Space Grotesk', sans-serif" }}>
                            {data["title"] as string}
                          </p>
                        )}

                        {/* Corpo / conteúdo / texto de story */}
                        {((data["body"] ?? data["content"] ?? data["text_content"]) as string | undefined) && (
                          <p className="text-[13px] leading-relaxed" style={{ color: "rgba(255,255,255,0.75)", fontFamily: "'Space Grotesk', sans-serif", whiteSpace: "pre-wrap" }}>
                            {(data["body"] ?? data["content"] ?? data["text_content"]) as string}
                          </p>
                        )}

                        {/* Imagem de capa (wiki) */}
                        {(data["cover_image_url"] as string | undefined) && (
                          <div className="rounded-xl overflow-hidden" style={{ border: "1px solid rgba(255,255,255,0.07)" }}>
                            <img src={data["cover_image_url"] as string} alt="Capa" className="w-full object-cover" style={{ maxHeight: 200 }} />
                          </div>
                        )}

                        {/* Mídia de story */}
                        {contentType === "story" && (data["media_url"] as string | undefined) && (
                          <div className="rounded-xl overflow-hidden" style={{ border: "1px solid rgba(255,255,255,0.07)" }}>
                            <img src={data["media_url"] as string} alt="Mídia do Story" className="w-full object-cover" style={{ maxHeight: 280 }}
                              onError={(e) => { (e.target as HTMLImageElement).style.display = "none"; }} />
                          </div>
                        )}

                        {/* Imagens do post */}
                        {Array.isArray(data["image_urls"]) && (data["image_urls"] as string[]).length > 0 && (
                          <div className="flex gap-2 flex-wrap">
                            {(data["image_urls"] as string[]).map((url, i) => (
                              <a key={i} href={url} target="_blank" rel="noopener noreferrer"
                                className="rounded-xl overflow-hidden flex-shrink-0 group relative"
                                style={{ border: "1px solid rgba(255,255,255,0.07)" }}>
                                <img src={url} alt={`Imagem ${i + 1}`} className="w-28 h-28 object-cover" />
                                <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity"
                                  style={{ background: "rgba(0,0,0,0.5)" }}>
                                  <ImageIcon size={16} style={{ color: "#fff" }} />
                                </div>
                              </a>
                            ))}
                          </div>
                        )}

                        {/* Tags (wiki) */}
                        {Array.isArray(data["tags"]) && (data["tags"] as string[]).length > 0 && (
                          <div className="flex gap-1.5 flex-wrap">
                            {(data["tags"] as string[]).map((tag) => (
                              <span key={tag} className="text-[10px] font-mono px-2 py-0.5 rounded-full"
                                style={{ background: "rgba(167,139,250,0.1)", color: "#A78BFA", border: "1px solid rgba(167,139,250,0.2)" }}>
                                #{tag}
                              </span>
                            ))}
                          </div>
                        )}
                      </>
                    )}

                    {/* Data de captura */}
                    <p className="text-[10px] font-mono pt-2" style={{ color: "rgba(255,255,255,0.2)", borderTop: "1px solid rgba(255,255,255,0.04)" }}>
                      Capturado em: {fmtDate(snapshot.captured_at)}
                    </p>
                  </div>
                </section>
              ) : (
                <section className="rounded-xl p-5 text-center" style={{ background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.06)" }}>
                  <Camera size={24} className="mx-auto mb-2 opacity-30" style={{ color: "rgba(255,255,255,0.4)" }} />
                  <p className="text-[12px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>
                    Nenhum snapshot disponível para esta denúncia.
                  </p>
                  <p className="text-[11px] font-mono mt-1" style={{ color: "rgba(255,255,255,0.2)" }}>
                    O conteúdo pode ter sido excluído antes da captura.
                  </p>
                </section>
              )}

              {/* ── Ações do bot ── */}
              {detail?.bot_actions && detail.bot_actions.length > 0 && (
                <section className="rounded-xl overflow-hidden" style={{ border: "1px solid rgba(255,255,255,0.07)" }}>
                  <div className="flex items-center gap-2 px-4 py-2.5" style={{ background: "rgba(255,255,255,0.03)" }}>
                    <Bot size={13} style={{ color: "#A78BFA" }} />
                    <p className="text-[11px] font-semibold tracking-wide uppercase font-mono" style={{ color: "#A78BFA" }}>
                      Ações do Bot ({detail.bot_actions.length})
                    </p>
                  </div>
                  <div style={{ background: "rgba(255,255,255,0.015)" }}>
                    {detail.bot_actions.map((action, i) => (
                      <div key={i} className="px-4 py-2.5 flex items-center gap-2"
                        style={{ borderBottom: i < detail.bot_actions.length - 1 ? "1px solid rgba(255,255,255,0.04)" : "none" }}>
                        <div className="w-1.5 h-1.5 rounded-full flex-shrink-0" style={{ background: "#A78BFA" }} />
                        <span className="text-[12px] font-mono" style={{ color: "rgba(255,255,255,0.6)" }}>
                          {action["action"] as string ?? "—"}
                        </span>
                        <span className="ml-auto text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.2)" }}>
                          {fmtDate(action["created_at"] as string)}
                        </span>
                      </div>
                    ))}
                  </div>
                </section>
              )}

              {/* ── Nota de resolução (se já resolvida) ── */}
              {flag.resolution_note && (
                <section className="rounded-xl p-4" style={{
                  background: STATUS_CONFIG[(flag.status as FlagStatus) in STATUS_CONFIG ? (flag.status as FlagStatus) : "pending"].bg,
                  border: `1px solid ${STATUS_CONFIG[(flag.status as FlagStatus) in STATUS_CONFIG ? (flag.status as FlagStatus) : "pending"].border}`,
                }}>
                  <p className="text-[10px] font-mono tracking-widest uppercase mb-1.5"
                    style={{ color: STATUS_CONFIG[(flag.status as FlagStatus) in STATUS_CONFIG ? (flag.status as FlagStatus) : "pending"].color }}>
                    Nota de Resolução
                  </p>
                  <p className="text-[13px]" style={{ color: "rgba(255,255,255,0.8)", fontFamily: "'Space Grotesk', sans-serif" }}>
                    {flag.resolution_note}
                  </p>
                </section>
              )}
            </>
          )}
        </div>

        {/* Footer com ações */}
        {isPending && !loading && (
          <div className="p-5 space-y-3" style={{ borderTop: "1px solid rgba(255,255,255,0.06)" }}>
            {!showResolveForm ? (
              <button onClick={() => setShowResolveForm(true)}
                className="w-full py-2.5 rounded-xl text-[13px] font-semibold transition-all flex items-center justify-center gap-2"
                style={{ background: "rgba(167,139,250,0.12)", border: "1px solid rgba(167,139,250,0.25)", color: "#A78BFA", fontFamily: "'Space Grotesk', sans-serif" }}>
                <Swords size={14} />
                Tomar Ação sobre esta Denúncia
                <ChevronRight size={14} />
              </button>
            ) : (
              <div className="space-y-3">
                <div className="flex gap-2">
                  {(["resolved", "dismissed"] as const).map((opt) => (
                    <button key={opt} onClick={() => setResolveAction(opt)}
                      className="flex-1 py-2 rounded-xl text-[13px] font-semibold transition-all flex items-center justify-center gap-1.5"
                      style={{
                        background: resolveAction === opt ? (opt === "resolved" ? "rgba(52,211,153,0.15)" : "rgba(107,114,128,0.15)") : "rgba(255,255,255,0.04)",
                        border: `1px solid ${resolveAction === opt ? (opt === "resolved" ? "rgba(52,211,153,0.3)" : "rgba(107,114,128,0.3)") : "rgba(255,255,255,0.07)"}`,
                        color: resolveAction === opt ? (opt === "resolved" ? "#34D399" : "#9CA3AF") : "rgba(255,255,255,0.3)",
                        fontFamily: "'Space Grotesk', sans-serif",
                      }}>
                      {opt === "resolved" ? <><CheckCircle2 size={13} />Resolver</> : <><XCircle size={13} />Descartar</>}
                    </button>
                  ))}
                </div>
                <textarea value={note} onChange={(e) => setNote(e.target.value)}
                  placeholder="Nota de resolução (opcional)..." rows={2}
                  className="w-full px-3 py-2 rounded-xl text-[13px] outline-none resize-none"
                  style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.8)", fontFamily: "'Space Grotesk', sans-serif" }} />
                <div className="flex gap-2">
                  <button onClick={() => setShowResolveForm(false)}
                    className="flex-1 py-2 rounded-xl text-[12px] font-mono transition-all"
                    style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)", color: "rgba(255,255,255,0.3)" }}>
                    Cancelar
                  </button>
                  <button onClick={handleResolve} disabled={resolving}
                    className="flex-1 py-2 rounded-xl text-[13px] font-semibold transition-all disabled:opacity-50 flex items-center justify-center gap-1.5"
                    style={{
                      background: resolveAction === "resolved" ? "rgba(52,211,153,0.15)" : "rgba(107,114,128,0.15)",
                      border: `1px solid ${resolveAction === "resolved" ? "rgba(52,211,153,0.3)" : "rgba(107,114,128,0.3)"}`,
                      color: resolveAction === "resolved" ? "#34D399" : "#9CA3AF",
                      fontFamily: "'Space Grotesk', sans-serif",
                    }}>
                    {resolving ? <Loader2 size={13} className="animate-spin" /> : null}
                    {resolving ? "Processando..." : `Confirmar — ${resolveAction === "resolved" ? "Resolver" : "Descartar"}`}
                  </button>
                </div>
              </div>
            )}
          </div>
        )}
      </motion.div>
    </div>
  );
}

// ─── Modal legado de resolução (mantido para compatibilidade) ─────────────────
function ResolveModal({
  flag,
  onClose,
  onResolved,
}: {
  flag: Flag;
  onClose: () => void;
  onResolved: (id: string, status: "resolved" | "dismissed", note: string) => void;
}) {
  const [action, setAction] = useState<"resolved" | "dismissed">("resolved");
  const [note, setNote] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleResolve() {
    setLoading(true);
    try {
      const { data: { user } } = await supabase.auth.getUser();
      const { error } = await supabaseAdmin.from("flags").update({
        status: action,
        resolved_by: user?.id ?? null,
        resolution_note: note.trim() || null,
        resolved_at: new Date().toISOString(),
      }).eq("id", flag.id);
      if (error) throw error;

      if (flag.community_id) {
        await supabaseAdmin.from("moderation_logs").insert({
          community_id: flag.community_id,
          moderator_id: user?.id,
          action: action === "resolved" ? "flag_resolved" : "flag_dismissed",
          severity: "low",
          target_user_id: flag.target_user_id ?? null,
          reason: note.trim() || null,
          details: { flag_type: flag.flag_type, flag_id: flag.id },
        });
      }

      toast.success(`Denúncia ${action === "resolved" ? "resolvida" : "descartada"} com sucesso.`);
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
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-xl flex items-center justify-center" style={{ background: "rgba(239,68,68,0.1)" }}>
            <Flag size={16} style={{ color: "#EF4444" }} />
          </div>
          <div>
            <h3 className="text-[15px] font-bold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.95)" }}>Resolver Denúncia</h3>
            <p className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>
              {FLAG_TYPE_LABELS[flag.flag_type] ?? flag.flag_type} · {flag.target_user_id ? 'usuário' : flag.target_post_id ? 'post' : flag.target_wiki_id ? 'wiki' : flag.target_comment_id ? 'comentário' : flag.target_chat_message_id ? 'mensagem' : flag.target_chat_thread_id ? 'thread' : 'desconhecido'}
            </p>
          </div>
        </div>

        {flag.reason && (
          <div className="p-3 rounded-xl" style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)" }}>
            <p className="text-[10px] font-mono tracking-widest uppercase mb-1" style={{ color: "rgba(255,255,255,0.3)" }}>Motivo do Denunciante</p>
            <p className="text-[13px]" style={{ color: "rgba(255,255,255,0.7)", fontFamily: "'Space Grotesk', sans-serif" }}>{flag.reason}</p>
          </div>
        )}

        <div className="flex gap-2">
          {(["resolved", "dismissed"] as const).map((opt) => (
            <button key={opt} onClick={() => setAction(opt)}
              className="flex-1 py-2.5 rounded-xl text-[13px] font-semibold transition-all flex items-center justify-center gap-2"
              style={{
                background: action === opt ? (opt === "resolved" ? "rgba(52,211,153,0.15)" : "rgba(107,114,128,0.15)") : "rgba(255,255,255,0.04)",
                border: `1px solid ${action === opt ? (opt === "resolved" ? "rgba(52,211,153,0.3)" : "rgba(107,114,128,0.3)") : "rgba(255,255,255,0.07)"}`,
                color: action === opt ? (opt === "resolved" ? "#34D399" : "#9CA3AF") : "rgba(255,255,255,0.3)",
                fontFamily: "'Space Grotesk', sans-serif",
              }}>
              {opt === "resolved" ? <><CheckCircle2 size={14} />Resolver</> : <><XCircle size={14} />Descartar</>}
            </button>
          ))}
        </div>

        <div>
          <label className="text-[10px] font-mono tracking-widest uppercase mb-1.5 block" style={{ color: "rgba(255,255,255,0.3)" }}>Nota de Resolução (opcional)</label>
          <textarea value={note} onChange={(e) => setNote(e.target.value)} placeholder="Descreva a decisão tomada..." rows={3}
            className="w-full px-3 py-2 rounded-xl text-[13px] outline-none resize-none"
            style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.8)", fontFamily: "'Space Grotesk', sans-serif" }} />
        </div>

        <button onClick={handleResolve} disabled={loading}
          className="w-full py-2.5 rounded-xl text-[13px] font-semibold transition-all disabled:opacity-50"
          style={{
            background: action === "resolved" ? "rgba(52,211,153,0.15)" : "rgba(107,114,128,0.15)",
            border: `1px solid ${action === "resolved" ? "rgba(52,211,153,0.3)" : "rgba(107,114,128,0.3)"}`,
            color: action === "resolved" ? "#34D399" : "#9CA3AF",
            fontFamily: "'Space Grotesk', sans-serif",
          }}>
          {loading ? "Processando..." : `Confirmar — ${action === "resolved" ? "Resolver" : "Descartar"}`}
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
  const [detailDrawer, setDetailDrawer] = useState<Flag | null>(null);
  const [expandedFlag, setExpandedFlag] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function loadFlags() {
    setLoading(true);
    setError(null);
    try {
      let query = supabaseAdmin
        .from("flags")
        .select("id, community_id, reporter_id, target_user_id, target_post_id, target_wiki_id, target_comment_id, target_chat_message_id, target_chat_thread_id, target_story_id, flag_type, reason, evidence_urls, status, resolved_by, resolution_note, resolved_at, created_at, bot_analyzed, bot_verdict, auto_actioned, reporter:profiles!reporter_id(nickname, amino_id)")
        .order("created_at", { ascending: false })
        .limit(50);
      if (flagFilter !== "all") query = query.eq("status", flagFilter);
      const { data, error } = await query;
      if (error) throw error;
      setFlags((data as unknown as Flag[]) ?? []);
    } catch (err: unknown) {
      console.error('[ModerationPage] loadFlags error:', err);
      const msg = err instanceof Error ? err.message : (typeof err === 'object' && err !== null ? JSON.stringify(err) : "Erro ao carregar denúncias.");
      setError(msg);
      toast.error(msg);
    } finally { setLoading(false); }
  }

  async function loadStrikes() {
    setLoading(true);
    setError(null);
    try {
      const { data, error } = await supabaseAdmin
        .from("strikes")
        .select("id, community_id, user_id, issued_by, reason, is_active, created_at, expires_at, user:profiles!user_id(nickname, amino_id)")
        .order("created_at", { ascending: false })
        .limit(50);
      if (error) throw error;
      setStrikes((data as unknown as Strike[]) ?? []);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Erro ao carregar strikes.";
      setError(msg);
      toast.error(msg);
    } finally { setLoading(false); }
  }

  async function loadLogs() {
    setLoading(true);
    setError(null);
    try {
      const { data, error } = await supabaseAdmin
        .from("moderation_logs")
        .select("id, community_id, moderator_id, action, severity, target_user_id, target_post_id, target_wiki_id, target_comment_id, target_chat_thread_id, reason, details, duration_hours, created_at, moderator:profiles!moderator_id(nickname, amino_id), target_user:profiles!target_user_id(nickname, amino_id)")
        .order("created_at", { ascending: false })
        .limit(50);
      if (error) throw error;
      setLogs((data as unknown as ModerationLog[]) ?? []);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Erro ao carregar logs.";
      setError(msg);
      toast.error(msg);
    } finally { setLoading(false); }
  }

  useEffect(() => {
    if (tab === "flags") loadFlags();
    else if (tab === "strikes") loadStrikes();
    else loadLogs();
  }, [tab, flagFilter]);

  async function revokeStrike(strike: Strike) {
    const name = displayUser(strike.user, strike.user_id);
    if (!confirm(`Revogar strike de ${name}?`)) return;
    const { data: { user } } = await supabase.auth.getUser();
    const { error } = await supabaseAdmin.from("strikes").update({
      is_active: false,
      revoked_by: user?.id ?? null,
      revoked_at: new Date().toISOString(),
    }).eq("id", strike.id);
    if (error) { toast.error("Erro ao revogar strike."); return; }
    setStrikes((prev) => prev.map((s) => s.id === strike.id ? { ...s, is_active: false } : s));
    toast.success("Strike revogado.");
  }

  function handleFlagResolved(id: string, status: "resolved" | "dismissed", note: string) {
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
        {detailDrawer && (
          <FlagDetailDrawer
            flagId={detailDrawer.id}
            flag={detailDrawer}
            onClose={() => setDetailDrawer(null)}
            onResolved={(id, status, note) => {
              handleFlagResolved(id, status, note);
              setDetailDrawer(null);
            }}
          />
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

        {/* Error */}
        {error && (
          <div className="p-3 rounded-xl" style={{ background: "rgba(239,68,68,0.08)", border: "1px solid rgba(239,68,68,0.2)" }}>
            <p className="text-[12px] font-mono" style={{ color: "#FCA5A5" }}>Erro: {error}</p>
          </div>
        )}

        {/* ── Flags Tab ── */}
        {tab === "flags" && (
          <motion.div key="flags" initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-4">
            <div className="flex gap-2 flex-wrap">
              {(["pending", "resolved", "dismissed", "all"] as FlagStatus[]).map((s) => {
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
              <div className="space-y-2">{[...Array(5)].map((_, i) => <div key={i} className="h-16 rounded-xl animate-pulse" style={{ background: "rgba(255,255,255,0.03)" }} />)}</div>
            ) : flags.length === 0 ? (
              <div className="rounded-2xl p-10 text-center" style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}>
                <CheckCircle2 className="w-10 h-10 text-[#34D399] mx-auto mb-3 opacity-40" />
                <p className="text-[#4B5563] text-sm">Nenhuma denúncia {flagFilter !== "all" ? STATUS_CONFIG[flagFilter].label.toLowerCase() : ""}</p>
              </div>
            ) : (
              <div className="space-y-2">
                {flags.map((flag, i) => {
                  const statusKey = (flag.status as FlagStatus) in STATUS_CONFIG ? (flag.status as FlagStatus) : "pending";
                  const cfg = STATUS_CONFIG[statusKey];
                  const StatusIcon = cfg.icon;
                  const isExpanded = expandedFlag === flag.id;
                  const typeColor = FLAG_TYPE_COLORS[flag.flag_type] ?? "#6B7280";
                  const typeLabel = FLAG_TYPE_LABELS[flag.flag_type] ?? flag.flag_type;
                  const reporterName = displayUser(flag.reporter, flag.reporter_id ?? "anônimo");
                  const targetId = flag.target_user_id ?? flag.target_post_id ?? flag.target_comment_id ?? flag.target_wiki_id ?? flag.target_chat_message_id ?? flag.target_chat_thread_id ?? flag.target_story_id;
                  const targetType = flag.target_user_id ? "usuário" : flag.target_post_id ? "post" : flag.target_comment_id ? "comentário" : flag.target_wiki_id ? "wiki" : flag.target_chat_message_id ? "mensagem" : flag.target_chat_thread_id ? "thread" : flag.target_story_id ? "story" : "desconhecido";

                  return (
                    <motion.div key={flag.id} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.02 }}
                      className="rounded-xl overflow-hidden"
                      style={{ background: "rgba(255,255,255,0.025)", border: `1px solid ${isExpanded ? cfg.border : "rgba(255,255,255,0.07)"}` }}>
                      <div className="flex items-center gap-3 px-4 py-3 cursor-pointer"
                        onClick={() => setExpandedFlag(isExpanded ? null : flag.id)}>
                        <div className="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0"
                          style={{ background: `${typeColor}15` }}>
                          <Flag size={14} style={{ color: typeColor }} />
                        </div>
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2 flex-wrap">
                            <span className="text-[13px] font-semibold" style={{ color: "rgba(255,255,255,0.9)", fontFamily: "'Space Grotesk', sans-serif" }}>
                              {typeLabel}
                            </span>
                            <span className="text-[10px] px-1.5 py-0.5 rounded font-mono"
                              style={{ background: `${typeColor}15`, color: typeColor }}>
                              {targetType}
                            </span>
                            {flag.auto_actioned && (
                              <span className="text-[10px] px-1.5 py-0.5 rounded font-mono" style={{ background: "rgba(239,68,68,0.1)", color: "#FCA5A5" }}>AUTO</span>
                            )}
                            {flag.bot_analyzed && flag.bot_verdict && (
                              <span className="text-[10px] px-1.5 py-0.5 rounded font-mono" style={{ background: "rgba(167,139,250,0.1)", color: "#A78BFA" }}>BOT: {flag.bot_verdict}</span>
                            )}
                          </div>
                          <p className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>
                            por {reporterName} · {new Date(flag.created_at).toLocaleDateString("pt-BR")}
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

                      <AnimatePresence>
                        {isExpanded && (
                          <motion.div initial={{ height: 0, opacity: 0 }} animate={{ height: "auto", opacity: 1 }} exit={{ height: 0, opacity: 0 }}
                            className="overflow-hidden">
                            <div className="px-4 pb-4 space-y-3" style={{ borderTop: "1px solid rgba(255,255,255,0.05)" }}>
                              <div className="pt-3 grid grid-cols-2 gap-3">
                                <div className="space-y-1">
                                  <p className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.3)" }}>Target ({targetType})</p>
                                  <div className="flex items-center gap-1.5">
                                    <Hash size={11} style={{ color: "rgba(255,255,255,0.3)" }} />
                                    <p className="text-[11px] font-mono truncate" style={{ color: "rgba(255,255,255,0.5)" }}>{targetId ?? "—"}</p>
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
                                <div className="p-3 rounded-xl" style={{ background: cfg.bg, border: `1px solid ${cfg.border}` }}>
                                  <p className="text-[10px] font-mono tracking-widest uppercase mb-1" style={{ color: cfg.color }}>Nota de Resolução</p>
                                  <p className="text-[13px]" style={{ color: "rgba(255,255,255,0.7)", fontFamily: "'Space Grotesk', sans-serif" }}>{flag.resolution_note}</p>
                                </div>
                              )}

                              {/* Botão principal: Ver conteúdo original */}
                              <button onClick={() => setDetailDrawer(flag)}
                                className="flex items-center gap-2 px-4 py-2 rounded-xl text-[13px] font-semibold transition-all"
                                style={{ background: "rgba(167,139,250,0.1)", border: "1px solid rgba(167,139,250,0.2)", color: "#A78BFA", fontFamily: "'Space Grotesk', sans-serif" }}>
                                <Camera size={14} />
                                Ver Conteúdo Original (Snapshot)
                                <ChevronRight size={13} />
                              </button>

                              {flag.status === "pending" && (
                                <button onClick={() => setResolveModal(flag)}
                                  className="flex items-center gap-2 px-4 py-2 rounded-xl text-[13px] font-semibold transition-all"
                                  style={{ background: "rgba(52,211,153,0.08)", border: "1px solid rgba(52,211,153,0.2)", color: "#34D399", fontFamily: "'Space Grotesk', sans-serif" }}>
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
              <div className="space-y-2">{[...Array(5)].map((_, i) => <div key={i} className="h-16 rounded-xl animate-pulse" style={{ background: "rgba(255,255,255,0.03)" }} />)}</div>
            ) : strikes.length === 0 ? (
              <div className="rounded-2xl p-10 text-center" style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}>
                <AlertTriangle className="w-10 h-10 text-[#4B5563] mx-auto mb-3 opacity-40" />
                <p className="text-[#4B5563] text-sm">Nenhum strike registrado</p>
              </div>
            ) : (
              strikes.map((strike, i) => {
                const name = displayUser(strike.user, strike.user_id);
                return (
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
                          {name}
                        </span>
                        <span className={`text-[10px] px-1.5 py-0.5 rounded font-mono ${strike.is_active ? "text-[#F97316]" : "text-[#6B7280]"}`}
                          style={{ background: strike.is_active ? "rgba(249,115,22,0.1)" : "rgba(107,114,128,0.1)" }}>
                          {strike.is_active ? "ATIVO" : "REVOGADO"}
                        </span>
                      </div>
                      <p className="text-[11px] font-mono truncate" style={{ color: "rgba(255,255,255,0.4)" }}>{strike.reason}</p>
                      <p className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.2)" }}>
                        {new Date(strike.created_at).toLocaleDateString("pt-BR")}
                        {strike.expires_at ? ` · Expira: ${new Date(strike.expires_at).toLocaleDateString("pt-BR")}` : ""}
                      </p>
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
                );
              })
            )}
          </motion.div>
        )}

        {/* ── Logs Tab ── */}
        {tab === "logs" && (
          <motion.div key="logs" initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-3">
            {loading ? (
              <div className="space-y-2">{[...Array(5)].map((_, i) => <div key={i} className="h-14 rounded-xl animate-pulse" style={{ background: "rgba(255,255,255,0.03)" }} />)}</div>
            ) : logs.length === 0 ? (
              <div className="rounded-2xl p-10 text-center" style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}>
                <FileText className="w-10 h-10 text-[#4B5563] mx-auto mb-3 opacity-40" />
                <p className="text-[#4B5563] text-sm">Nenhum log de moderação</p>
              </div>
            ) : (
              <div className="rounded-2xl overflow-hidden" style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}>
                {logs.map((log, i) => {
                  const modName = displayUser(log.moderator, log.moderator_id ?? "sistema");
                  const targetName = log.target_user_id
                    ? displayUser(log.target_user, log.target_user_id)
                    : log.target_post_id ? `post:${log.target_post_id.slice(0,8)}`
                    : log.target_wiki_id ? `wiki:${log.target_wiki_id.slice(0,8)}`
                    : log.target_comment_id ? `comentário:${log.target_comment_id.slice(0,8)}`
                    : log.target_chat_thread_id ? `thread:${log.target_chat_thread_id.slice(0,8)}`
                    : null;
                  const severityColor = log.severity === "high" ? "#FCA5A5" : log.severity === "medium" ? "#FCD34D" : "#6EE7B7";
                  const severityBg   = log.severity === "high" ? "rgba(239,68,68,0.1)" : log.severity === "medium" ? "rgba(245,158,11,0.1)" : "rgba(52,211,153,0.1)";
                  return (
                    <div key={log.id} className="px-4 py-3 space-y-1.5"
                      style={{ borderBottom: i < logs.length - 1 ? "1px solid rgba(255,255,255,0.04)" : "none" }}>
                      <div className="flex items-center gap-2 flex-wrap">
                        <div className="w-5 h-5 rounded flex items-center justify-center flex-shrink-0"
                          style={{ background: "rgba(167,139,250,0.12)" }}>
                          <Shield size={10} style={{ color: "#A78BFA" }} />
                        </div>
                        <span className="text-[12px] font-mono font-semibold" style={{ color: "#A78BFA" }}>{log.action}</span>
                        {log.severity && (
                          <span className="text-[9px] font-mono px-1.5 py-0.5 rounded-full" style={{ background: severityBg, color: severityColor }}>
                            {log.severity}
                          </span>
                        )}
                        {log.duration_hours != null && (
                          <span className="text-[9px] font-mono px-1.5 py-0.5 rounded-full" style={{ background: "rgba(99,102,241,0.1)", color: "#818CF8" }}>
                            {log.duration_hours}h
                          </span>
                        )}
                        <span className="ml-auto text-[9px] font-mono flex-shrink-0" style={{ color: "rgba(255,255,255,0.2)" }}>
                          {new Date(log.created_at).toLocaleString("pt-BR")}
                        </span>
                      </div>
                      <div className="flex items-center gap-1.5 flex-wrap">
                        <div className="flex items-center gap-1">
                          <Shield size={9} style={{ color: "rgba(167,139,250,0.6)" }} />
                          <span className="text-[10px] font-mono" style={{ color: "rgba(167,139,250,0.8)" }}>{modName}</span>
                        </div>
                        {targetName && (
                          <>
                            <ArrowRight size={9} style={{ color: "rgba(255,255,255,0.2)" }} />
                            <div className="flex items-center gap-1">
                              <User size={9} style={{ color: "rgba(251,191,36,0.6)" }} />
                              <span className="text-[10px] font-mono" style={{ color: "rgba(251,191,36,0.8)" }}>{targetName}</span>
                            </div>
                          </>
                        )}
                      </div>
                      {log.reason && (
                        <p className="text-[10px] pl-1 truncate" style={{ color: "rgba(255,255,255,0.35)", fontFamily: "'Space Grotesk', sans-serif", borderLeft: "2px solid rgba(255,255,255,0.08)", paddingLeft: "6px" }}>
                          {log.reason}
                        </p>
                      )}
                    </div>
                  );
                })}
              </div>
            )}
          </motion.div>
        )}
      </div>
    </>
  );
}
