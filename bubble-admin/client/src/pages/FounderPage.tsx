import { useState, useEffect, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { supabase, TEAM_ROLE_CONFIG, TeamRole, getTeamRoleRank, canManageRole } from "@/lib/supabase";
import { useAuth } from "@/contexts/AuthContext";
import { toast } from "sonner";
import {
  Crown, Users, Shield, Settings, Activity, Search, RefreshCw,
  ChevronDown, Trash2, UserCheck, AlertTriangle, Lock, Unlock,
  Eye, BarChart3, Zap, Globe, Bell, Database, Key, Plus,
  CheckCircle2, XCircle, Clock, Edit3, Save, X,
} from "lucide-react";

// ─── Tipos ────────────────────────────────────────────────────────────────────
type TeamMember = {
  id: string;
  nickname: string | null;
  amino_id: string | null;
  icon_url: string | null;
  team_role: TeamRole;
  team_rank: number;
  is_team_admin: boolean;
  is_team_moderator: boolean;
  created_at: string;
  last_seen_at: string | null;
};

type SecurityLog = {
  id: string;
  user_id: string | null;
  event_type: string;
  ip_address: string | null;
  created_at: string;
  details: Record<string, unknown> | null;
  user?: { nickname: string | null; amino_id: string | null };
};

type PlatformStats = {
  total_users: number;
  active_today: number;
  total_communities: number;
  total_posts: number;
  total_transactions: number;
  team_members: number;
};

const fadeUp = {
  hidden: { opacity: 0, y: 12 },
  show: (i: number) => ({
    opacity: 1, y: 0,
    transition: { delay: i * 0.05, duration: 0.25, ease: "easeOut" as const },
  }),
};

// ─── Badge de Cargo ───────────────────────────────────────────────────────────
function TeamRoleBadge({ role }: { role: TeamRole }) {
  if (!role) return <span className="text-[10px] font-mono px-2 py-0.5 rounded" style={{ background: "rgba(255,255,255,0.04)", color: "rgba(255,255,255,0.3)", border: "1px solid rgba(255,255,255,0.08)" }}>Sem cargo</span>;
  const cfg = TEAM_ROLE_CONFIG[role];
  return (
    <span
      className="text-[10px] font-mono px-2 py-0.5 rounded-full"
      style={{
        background: "transparent",
        color: cfg.color,
        border: `1px solid ${cfg.borderColor}`,
      }}
    >
      {cfg.label}
    </span>
  );
}

// ─── Modal de Atribuição de Cargo ─────────────────────────────────────────────
function AssignRoleModal({
  member,
  callerRole,
  onClose,
  onSuccess,
}: {
  member: TeamMember;
  callerRole: TeamRole;
  onClose: () => void;
  onSuccess: () => void;
}) {
  const [selectedRole, setSelectedRole] = useState<TeamRole>(member.team_role);
  const [loading, setLoading] = useState(false);
  const displayName = member.nickname || member.amino_id || member.id.slice(0, 8);

  // Apenas roles com rank menor que o caller podem ser atribuídas
  const availableRoles = Object.entries(TEAM_ROLE_CONFIG)
    .filter(([, cfg]) => cfg.rank < getTeamRoleRank(callerRole))
    .sort((a, b) => b[1].rank - a[1].rank);

  async function handleSave() {
    if (!canManageRole(callerRole, member.team_role) && member.team_role !== null) {
      toast.error("Você não pode modificar o cargo de alguém de rank igual ou superior ao seu.");
      return;
    }
    setLoading(true);
    try {
      const { error } = await supabase.rpc("set_team_role", {
        p_target_user_id: member.id,
        p_new_role: selectedRole,
      });
      if (error) throw error;
      toast.success(`Cargo de ${displayName} atualizado para ${selectedRole ? TEAM_ROLE_CONFIG[selectedRole].label : "Nenhum"}`);
      onSuccess();
      onClose();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      toast.error(`Erro: ${msg}`);
    } finally {
      setLoading(false);
    }
  }

  async function handleRemove() {
    if (!canManageRole(callerRole, member.team_role)) {
      toast.error("Você não pode remover o cargo de alguém de rank igual ou superior ao seu.");
      return;
    }
    setLoading(true);
    try {
      const { error } = await supabase.rpc("set_team_role", {
        p_target_user_id: member.id,
        p_new_role: null,
      });
      if (error) throw error;
      toast.success(`Cargo de ${displayName} removido.`);
      onSuccess();
      onClose();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      toast.error(`Erro: ${msg}`);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center" style={{ background: "rgba(0,0,0,0.75)", backdropFilter: "blur(8px)" }}>
      <motion.div
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        exit={{ opacity: 0, scale: 0.95 }}
        className="w-full max-w-md mx-4 rounded-2xl overflow-hidden"
        style={{ background: "#111318", border: "1px solid rgba(255,255,255,0.08)" }}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-5 py-4" style={{ borderBottom: "1px solid rgba(255,255,255,0.06)" }}>
          <div className="flex items-center gap-3">
            {member.icon_url ? (
              <img src={member.icon_url} alt="" className="w-9 h-9 rounded-full object-cover" style={{ border: `1px solid ${member.team_role ? TEAM_ROLE_CONFIG[member.team_role].borderColor : "rgba(255,255,255,0.1)"}` }} />
            ) : (
              <div className="w-9 h-9 rounded-full flex items-center justify-center text-sm font-bold" style={{ background: "rgba(139,92,246,0.2)", color: "#A78BFA" }}>
                {(member.nickname || "?")[0].toUpperCase()}
              </div>
            )}
            <div>
              <p className="text-[13px] font-semibold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.9)" }}>{displayName}</p>
              <p className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>@{member.amino_id || "—"}</p>
            </div>
          </div>
          <button onClick={onClose} className="w-7 h-7 rounded-lg flex items-center justify-center" style={{ background: "rgba(255,255,255,0.05)", color: "rgba(255,255,255,0.4)" }}>
            <X size={13} />
          </button>
        </div>

        {/* Cargo atual */}
        <div className="px-5 py-3" style={{ borderBottom: "1px solid rgba(255,255,255,0.04)" }}>
          <p className="text-[10px] font-mono mb-1.5" style={{ color: "rgba(255,255,255,0.3)" }}>CARGO ATUAL</p>
          <TeamRoleBadge role={member.team_role} />
        </div>

        {/* Seletor de cargo */}
        <div className="px-5 py-4">
          <p className="text-[10px] font-mono mb-3" style={{ color: "rgba(255,255,255,0.3)" }}>ATRIBUIR CARGO</p>
          <div className="space-y-2 max-h-64 overflow-y-auto pr-1">
            {availableRoles.map(([roleKey, cfg]) => (
              <button
                key={roleKey}
                onClick={() => setSelectedRole(roleKey as TeamRole)}
                className="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-left transition-all duration-150"
                style={{
                  background: selectedRole === roleKey ? `${cfg.color}10` : "rgba(255,255,255,0.02)",
                  border: `1px solid ${selectedRole === roleKey ? `${cfg.borderColor}40` : "rgba(255,255,255,0.06)"}`,
                }}
              >
                <div className="w-3 h-3 rounded-full flex-shrink-0" style={{ background: "transparent", border: `1.5px solid ${cfg.borderColor}` }} />
                <div className="min-w-0 flex-1">
                  <p className="text-[12px] font-semibold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: selectedRole === roleKey ? cfg.color : "rgba(255,255,255,0.8)" }}>{cfg.label}</p>
                  <p className="text-[10px] font-mono truncate mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>{cfg.description}</p>
                </div>
                {selectedRole === roleKey && <div className="w-1.5 h-1.5 rounded-full flex-shrink-0" style={{ background: cfg.color }} />}
              </button>
            ))}
          </div>
        </div>

        {/* Ações */}
        <div className="flex gap-2 px-5 pb-5">
          {member.team_role && canManageRole(callerRole, member.team_role) && (
            <button
              onClick={handleRemove}
              disabled={loading}
              className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-[12px] font-semibold transition-all duration-150"
              style={{ background: "rgba(239,68,68,0.08)", color: "#FCA5A5", border: "1px solid rgba(239,68,68,0.2)" }}
            >
              <Trash2 size={12} />
              Remover
            </button>
          )}
          <button
            onClick={handleSave}
            disabled={loading || selectedRole === member.team_role}
            className="flex-1 flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl text-[12px] font-semibold transition-all duration-150"
            style={{
              background: loading ? "rgba(139,92,246,0.1)" : "rgba(139,92,246,0.15)",
              color: "#A78BFA",
              border: "1px solid rgba(139,92,246,0.25)",
              opacity: selectedRole === member.team_role ? 0.4 : 1,
            }}
          >
            {loading ? <RefreshCw size={12} className="animate-spin" /> : <Save size={12} />}
            Salvar
          </button>
        </div>
      </motion.div>
    </div>
  );
}

// ─── Seção: Equipe ────────────────────────────────────────────────────────────
function TeamSection({ callerRole }: { callerRole: TeamRole }) {
  const [members, setMembers] = useState<TeamMember[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [editTarget, setEditTarget] = useState<TeamMember | null>(null);
  const [addSearch, setAddSearch] = useState("");
  const [addResults, setAddResults] = useState<TeamMember[]>([]);
  const [addLoading, setAddLoading] = useState(false);

  const loadMembers = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from("profiles")
        .select("id, nickname, amino_id, icon_url, team_role, team_rank, is_team_admin, is_team_moderator, created_at, last_seen_at")
        .gt("team_rank", 0)
        .order("team_rank", { ascending: false });
      if (error) throw error;
      setMembers((data as TeamMember[]) || []);
    } catch (err: unknown) {
      toast.error("Erro ao carregar equipe");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadMembers(); }, [loadMembers]);

  async function searchUsers(q: string) {
    if (!q.trim()) { setAddResults([]); return; }
    setAddLoading(true);
    try {
      const { data } = await supabase
        .from("profiles")
        .select("id, nickname, amino_id, icon_url, team_role, team_rank, is_team_admin, is_team_moderator, created_at, last_seen_at")
        .or(`nickname.ilike.%${q}%,amino_id.ilike.%${q}%`)
        .eq("team_rank", 0)
        .limit(8);
      setAddResults((data as TeamMember[]) || []);
    } finally {
      setAddLoading(false);
    }
  }

  const filtered = members.filter(m =>
    !search || (m.nickname || "").toLowerCase().includes(search.toLowerCase()) || (m.amino_id || "").toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div>
      <AnimatePresence>
        {editTarget && (
          <AssignRoleModal
            member={editTarget}
            callerRole={callerRole}
            onClose={() => setEditTarget(null)}
            onSuccess={loadMembers}
          />
        )}
      </AnimatePresence>

      {/* Adicionar membro */}
      <div className="mb-6 p-4 rounded-2xl" style={{ background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.06)" }}>
        <p className="text-[11px] font-mono mb-3" style={{ color: "rgba(255,255,255,0.35)" }}>ADICIONAR MEMBRO À EQUIPE</p>
        <div className="relative">
          <Search size={13} className="absolute left-3 top-1/2 -translate-y-1/2" style={{ color: "rgba(255,255,255,0.3)" }} />
          <input
            value={addSearch}
            onChange={e => { setAddSearch(e.target.value); searchUsers(e.target.value); }}
            placeholder="Buscar por nickname ou @amino_id..."
            className="w-full pl-9 pr-4 py-2.5 rounded-xl text-[12px] outline-none"
            style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.8)", fontFamily: "'Space Mono', monospace" }}
          />
        </div>
        {addResults.length > 0 && (
          <div className="mt-2 rounded-xl overflow-hidden" style={{ border: "1px solid rgba(255,255,255,0.06)" }}>
            {addResults.map(u => (
              <button
                key={u.id}
                onClick={() => { setEditTarget(u); setAddSearch(""); setAddResults([]); }}
                className="w-full flex items-center gap-3 px-3 py-2.5 text-left transition-all duration-150 hover:bg-white/5"
                style={{ borderBottom: "1px solid rgba(255,255,255,0.04)" }}
              >
                {u.icon_url ? (
                  <img src={u.icon_url} alt="" className="w-7 h-7 rounded-full object-cover" />
                ) : (
                  <div className="w-7 h-7 rounded-full flex items-center justify-center text-[11px] font-bold" style={{ background: "rgba(139,92,246,0.2)", color: "#A78BFA" }}>
                    {(u.nickname || "?")[0].toUpperCase()}
                  </div>
                )}
                <div>
                  <p className="text-[12px] font-semibold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.85)" }}>{u.nickname || "—"}</p>
                  <p className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>@{u.amino_id || "—"}</p>
                </div>
                <Plus size={12} className="ml-auto" style={{ color: "rgba(255,255,255,0.3)" }} />
              </button>
            ))}
          </div>
        )}
      </div>

      {/* Busca na equipe */}
      <div className="relative mb-4">
        <Search size={13} className="absolute left-3 top-1/2 -translate-y-1/2" style={{ color: "rgba(255,255,255,0.3)" }} />
        <input
          value={search}
          onChange={e => setSearch(e.target.value)}
          placeholder="Filtrar equipe..."
          className="w-full pl-9 pr-4 py-2.5 rounded-xl text-[12px] outline-none"
          style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)", color: "rgba(255,255,255,0.8)", fontFamily: "'Space Mono', monospace" }}
        />
      </div>

      {/* Lista de membros */}
      {loading ? (
        <div className="flex items-center justify-center py-12">
          <RefreshCw size={18} className="animate-spin" style={{ color: "rgba(255,255,255,0.2)" }} />
        </div>
      ) : (
        <div className="space-y-2">
          {filtered.map((m, i) => {
            const cfg = m.team_role ? TEAM_ROLE_CONFIG[m.team_role] : null;
            const canEdit = canManageRole(callerRole, m.team_role);
            return (
              <motion.div
                key={m.id}
                custom={i}
                variants={fadeUp}
                initial="hidden"
                animate="show"
                className="flex items-center gap-3 px-4 py-3 rounded-xl"
                style={{ background: "rgba(255,255,255,0.02)", border: `1px solid ${cfg ? `${cfg.borderColor}18` : "rgba(255,255,255,0.05)"}` }}
              >
                {m.icon_url ? (
                  <img src={m.icon_url} alt="" className="w-9 h-9 rounded-full object-cover flex-shrink-0" style={{ border: `1.5px solid ${cfg?.borderColor ?? "rgba(255,255,255,0.1)"}` }} />
                ) : (
                  <div className="w-9 h-9 rounded-full flex items-center justify-center text-sm font-bold flex-shrink-0" style={{ background: "rgba(139,92,246,0.15)", color: "#A78BFA", border: `1.5px solid ${cfg?.borderColor ?? "rgba(255,255,255,0.1)"}` }}>
                    {(m.nickname || "?")[0].toUpperCase()}
                  </div>
                )}
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2 flex-wrap">
                    <p className="text-[13px] font-semibold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.9)" }}>{m.nickname || "—"}</p>
                    <TeamRoleBadge role={m.team_role} />
                  </div>
                  <p className="text-[10px] font-mono mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>@{m.amino_id || "—"} · rank {m.team_rank}</p>
                </div>
                {canEdit && (
                  <button
                    onClick={() => setEditTarget(m)}
                    className="w-8 h-8 rounded-xl flex items-center justify-center flex-shrink-0 transition-all duration-150"
                    style={{ background: "rgba(255,255,255,0.04)", color: "rgba(255,255,255,0.3)" }}
                    onMouseEnter={e => { e.currentTarget.style.background = "rgba(139,92,246,0.12)"; e.currentTarget.style.color = "#A78BFA"; }}
                    onMouseLeave={e => { e.currentTarget.style.background = "rgba(255,255,255,0.04)"; e.currentTarget.style.color = "rgba(255,255,255,0.3)"; }}
                  >
                    <Edit3 size={13} />
                  </button>
                )}
              </motion.div>
            );
          })}
          {filtered.length === 0 && !loading && (
            <div className="text-center py-10" style={{ color: "rgba(255,255,255,0.2)" }}>
              <Users size={28} className="mx-auto mb-2 opacity-30" />
              <p className="text-[12px] font-mono">Nenhum membro encontrado</p>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

// ─── Seção: Estatísticas da Plataforma ────────────────────────────────────────
function PlatformStatsSection() {
  const [stats, setStats] = useState<PlatformStats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      try {
        const [usersRes, commRes, postsRes, txRes, teamRes] = await Promise.all([
          supabase.from("profiles").select("id", { count: "exact", head: true }),
          supabase.from("communities").select("id", { count: "exact", head: true }),
          supabase.from("posts").select("id", { count: "exact", head: true }),
          supabase.from("coin_transactions").select("id", { count: "exact", head: true }),
          supabase.from("profiles").select("id", { count: "exact", head: true }).gt("team_rank", 0),
        ]);
        // Usuários ativos hoje (last_seen_at >= hoje)
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const { count: activeToday } = await supabase
          .from("profiles")
          .select("id", { count: "exact", head: true })
          .gte("last_seen_at", today.toISOString());

        setStats({
          total_users: usersRes.count ?? 0,
          active_today: activeToday ?? 0,
          total_communities: commRes.count ?? 0,
          total_posts: postsRes.count ?? 0,
          total_transactions: txRes.count ?? 0,
          team_members: teamRes.count ?? 0,
        });
      } catch {
        toast.error("Erro ao carregar estatísticas");
      } finally {
        setLoading(false);
      }
    }
    load();
  }, []);

  const cards = [
    { label: "Total de Usuários", value: stats?.total_users, icon: Users, color: "#8B5CF6", rgb: "139,92,246" },
    { label: "Ativos Hoje", value: stats?.active_today, icon: Activity, color: "#10B981", rgb: "16,185,129" },
    { label: "Comunidades", value: stats?.total_communities, icon: Globe, color: "#06B6D4", rgb: "6,182,212" },
    { label: "Posts", value: stats?.total_posts, icon: BarChart3, color: "#F59E0B", rgb: "245,158,11" },
    { label: "Transações", value: stats?.total_transactions, icon: Zap, color: "#EC4899", rgb: "236,72,153" },
    { label: "Team Members", value: stats?.team_members, icon: Shield, color: "#FFFFFF", rgb: "255,255,255" },
  ];

  return (
    <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
      {cards.map((card, i) => {
        const Icon = card.icon;
        return (
          <motion.div
            key={card.label}
            custom={i}
            variants={fadeUp}
            initial="hidden"
            animate="show"
            className="p-4 rounded-2xl"
            style={{ background: `rgba(${card.rgb},0.05)`, border: `1px solid rgba(${card.rgb},0.12)` }}
          >
            <div className="flex items-center gap-2 mb-3">
              <div className="w-7 h-7 rounded-lg flex items-center justify-center" style={{ background: `rgba(${card.rgb},0.12)` }}>
                <Icon size={14} style={{ color: card.color }} />
              </div>
              <p className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.35)" }}>{card.label.toUpperCase()}</p>
            </div>
            {loading ? (
              <div className="h-7 w-16 rounded-lg animate-pulse" style={{ background: "rgba(255,255,255,0.05)" }} />
            ) : (
              <p className="text-[22px] font-bold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: card.color }}>
                {(card.value ?? 0).toLocaleString("pt-BR")}
              </p>
            )}
          </motion.div>
        );
      })}
    </div>
  );
}

// ─── Seção: Logs de Segurança ─────────────────────────────────────────────────
function SecurityLogsSection() {
  const [logs, setLogs] = useState<SecurityLog[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      try {
        const { data, error } = await supabase
          .from("security_logs")
          .select("id, user_id, event_type, ip_address, created_at, details")
          .order("created_at", { ascending: false })
          .limit(30);
        if (error) throw error;
        setLogs(data || []);
      } catch {
        // Tentar auth_audit_log como fallback
        try {
          const { data } = await supabase
            .from("auth_audit_log")
            .select("id, user_id, event_type, ip_address, created_at, details")
            .order("created_at", { ascending: false })
            .limit(30);
          setLogs((data as SecurityLog[]) || []);
        } catch {
          setLogs([]);
        }
      } finally {
        setLoading(false);
      }
    }
    load();
  }, []);

  const eventColors: Record<string, string> = {
    login: "#10B981",
    logout: "#6B7280",
    failed_login: "#EF4444",
    password_change: "#F59E0B",
    role_change: "#8B5CF6",
    ban: "#EF4444",
    default: "#60A5FA",
  };

  return (
    <div>
      {loading ? (
        <div className="flex items-center justify-center py-12">
          <RefreshCw size={18} className="animate-spin" style={{ color: "rgba(255,255,255,0.2)" }} />
        </div>
      ) : logs.length === 0 ? (
        <div className="text-center py-10" style={{ color: "rgba(255,255,255,0.2)" }}>
          <Lock size={28} className="mx-auto mb-2 opacity-30" />
          <p className="text-[12px] font-mono">Nenhum log disponível</p>
        </div>
      ) : (
        <div className="space-y-2">
          {logs.map((log, i) => {
            const color = eventColors[log.event_type] ?? eventColors.default;
            return (
              <motion.div
                key={log.id}
                custom={i}
                variants={fadeUp}
                initial="hidden"
                animate="show"
                className="flex items-start gap-3 px-4 py-3 rounded-xl"
                style={{ background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.05)" }}
              >
                <div className="w-2 h-2 rounded-full mt-1.5 flex-shrink-0" style={{ background: color }} />
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2 flex-wrap">
                    <span className="text-[11px] font-mono px-2 py-0.5 rounded" style={{ background: `${color}15`, color, border: `1px solid ${color}30` }}>{log.event_type}</span>
                    {log.ip_address && <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.25)" }}>{log.ip_address}</span>}
                  </div>
                  <p className="text-[10px] font-mono mt-1" style={{ color: "rgba(255,255,255,0.25)" }}>
                    {new Date(log.created_at).toLocaleString("pt-BR")}
                    {log.user_id && ` · ${log.user_id.slice(0, 8)}...`}
                  </p>
                </div>
              </motion.div>
            );
          })}
        </div>
      )}
    </div>
  );
}

// ─── Seção: Configurações da Plataforma ──────────────────────────────────────
function PlatformConfigSection() {
  return (
    <div className="space-y-4">
      <div className="p-5 rounded-2xl" style={{ background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.06)" }}>
        <div className="flex items-center gap-2 mb-4">
          <Database size={15} style={{ color: "#8B5CF6" }} />
          <p className="text-[13px] font-semibold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.85)" }}>Banco de Dados</p>
        </div>
        <div className="space-y-3">
          {[
            { label: "Projeto Supabase", value: "ylvzqqvcanzzswjkqeya", icon: Database },
            { label: "URL", value: "https://ylvzqqvcanzzswjkqeya.supabase.co", icon: Globe },
            { label: "Região", value: "South America (São Paulo)", icon: Globe },
          ].map(item => {
            const Icon = item.icon;
            return (
              <div key={item.label} className="flex items-center justify-between gap-4">
                <div className="flex items-center gap-2">
                  <Icon size={12} style={{ color: "rgba(255,255,255,0.3)" }} />
                  <span className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.4)" }}>{item.label}</span>
                </div>
                <span className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.65)", fontFamily: "'Space Mono', monospace" }}>{item.value}</span>
              </div>
            );
          })}
        </div>
      </div>

      <div className="p-5 rounded-2xl" style={{ background: "rgba(255,200,0,0.03)", border: "1px solid rgba(255,200,0,0.1)" }}>
        <div className="flex items-center gap-2 mb-2">
          <AlertTriangle size={14} style={{ color: "#F59E0B" }} />
          <p className="text-[12px] font-semibold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "#F59E0B" }}>Zona de Perigo</p>
        </div>
        <p className="text-[11px] font-mono mb-4" style={{ color: "rgba(255,255,255,0.3)" }}>Ações irreversíveis que afetam toda a plataforma.</p>
        <div className="space-y-2">
          {[
            { label: "Modo de Manutenção", desc: "Bloqueia acesso de usuários comuns", icon: Lock, color: "#F59E0B" },
            { label: "Broadcast Global", desc: "Envia notificação para todos os usuários", icon: Bell, color: "#EC4899" },
          ].map(action => {
            const Icon = action.icon;
            return (
              <button
                key={action.label}
                className="w-full flex items-center gap-3 px-4 py-3 rounded-xl text-left transition-all duration-150"
                style={{ background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.06)" }}
                onMouseEnter={e => { e.currentTarget.style.background = "rgba(255,255,255,0.04)"; }}
                onMouseLeave={e => { e.currentTarget.style.background = "rgba(255,255,255,0.02)"; }}
                onClick={() => toast.info("Em desenvolvimento")}
              >
                <Icon size={14} style={{ color: action.color }} />
                <div>
                  <p className="text-[12px] font-semibold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.8)" }}>{action.label}</p>
                  <p className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>{action.desc}</p>
                </div>
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}

// ─── Página Principal do Founder ──────────────────────────────────────────────
type FounderTab = "team" | "stats" | "security" | "config";

export default function FounderPage() {
  const { isFounder, isCoFounderOrAbove, canManageTeamRoles, teamRole, teamRank } = useAuth();
  const [activeTab, setActiveTab] = useState<FounderTab>("team");

  // Apenas Founder e Co-Founder têm acesso total; Team Admin tem acesso parcial
  if (!canManageTeamRoles) {
    return (
      <div className="flex items-center justify-center h-full min-h-[60vh]">
        <div className="text-center">
          <Lock size={32} className="mx-auto mb-3" style={{ color: "rgba(255,255,255,0.15)" }} />
          <p className="text-[14px] font-semibold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.4)" }}>Acesso Restrito</p>
          <p className="text-[11px] font-mono mt-1" style={{ color: "rgba(255,255,255,0.2)" }}>Apenas Team Admin+ pode acessar esta área.</p>
        </div>
      </div>
    );
  }

  const tabs: { id: FounderTab; label: string; icon: React.ElementType; founderOnly?: boolean }[] = [
    { id: "team", label: "Equipe", icon: Users },
    { id: "stats", label: "Estatísticas", icon: BarChart3 },
    { id: "security", label: "Segurança", icon: Shield, founderOnly: true },
    { id: "config", label: "Configurações", icon: Settings, founderOnly: true },
  ];

  const visibleTabs = tabs.filter(t => !t.founderOnly || isFounder || isCoFounderOrAbove);

  return (
    <div className="p-5 md:p-7 max-w-5xl mx-auto">
      {/* Header */}
      <motion.div
        initial={{ opacity: 0, y: -8 }}
        animate={{ opacity: 1, y: 0 }}
        className="flex items-center gap-4 mb-8"
      >
        <div
          className="w-12 h-12 rounded-2xl flex items-center justify-center flex-shrink-0"
          style={{
            background: isFounder ? "rgba(255,255,255,0.06)" : "rgba(255,215,0,0.06)",
            border: `1.5px solid ${isFounder ? "rgba(255,255,255,0.2)" : "rgba(255,215,0,0.25)"}`,
          }}
        >
          <Crown size={22} style={{ color: isFounder ? "#FFFFFF" : "#FFD700" }} />
        </div>
        <div>
          <h1
            className="text-[20px] font-bold"
            style={{
              fontFamily: "'Space Grotesk', sans-serif",
              color: isFounder ? "#FFFFFF" : "#FFD700",
            }}
          >
            {isFounder ? "Founder Panel" : isCoFounderOrAbove ? "Co-Founder Panel" : "Admin Panel"}
          </h1>
          <p className="text-[11px] font-mono mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>
            {teamRole ? TEAM_ROLE_CONFIG[teamRole].description : "Painel de administração"}
            {" · "}rank {teamRank}
          </p>
        </div>
        {isFounder && (
          <div
            className="ml-auto px-3 py-1.5 rounded-full text-[10px] font-mono"
            style={{ background: "rgba(255,255,255,0.06)", color: "#FFFFFF", border: "1px solid rgba(255,255,255,0.15)" }}
          >
            ACESSO TOTAL
          </div>
        )}
      </motion.div>

      {/* Tabs */}
      <div className="flex gap-1 mb-6 p-1 rounded-xl" style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.06)" }}>
        {visibleTabs.map(tab => {
          const Icon = tab.icon;
          const isActive = activeTab === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className="flex-1 flex items-center justify-center gap-1.5 py-2 rounded-lg text-[11px] font-semibold transition-all duration-150"
              style={{
                background: isActive ? "rgba(255,255,255,0.07)" : "transparent",
                color: isActive ? "rgba(255,255,255,0.9)" : "rgba(255,255,255,0.35)",
                border: isActive ? "1px solid rgba(255,255,255,0.1)" : "1px solid transparent",
                fontFamily: "'Space Grotesk', sans-serif",
              }}
            >
              <Icon size={13} />
              <span className="hidden sm:inline">{tab.label}</span>
            </button>
          );
        })}
      </div>

      {/* Conteúdo */}
      <AnimatePresence mode="wait">
        <motion.div
          key={activeTab}
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -8 }}
          transition={{ duration: 0.18 }}
        >
          {activeTab === "team" && <TeamSection callerRole={teamRole} />}
          {activeTab === "stats" && <PlatformStatsSection />}
          {activeTab === "security" && <SecurityLogsSection />}
          {activeTab === "config" && <PlatformConfigSection />}
        </motion.div>
      </AnimatePresence>
    </div>
  );
}
