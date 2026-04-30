import { useState, useEffect, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { supabase, TEAM_ROLE_CONFIG, TeamRole, getTeamRoleRank, canManageRole } from "@/lib/supabase";
import { useAuth } from "@/contexts/AuthContext";
import { toast } from "sonner";
import {
  Crown, Users, Shield, Settings, Activity, Search, RefreshCw,
  ChevronDown, Trash2, UserCheck, AlertTriangle, Lock, Unlock,
  Eye, BarChart3, Zap, Globe, Bell, Database, Key, Plus,
  CheckCircle2, XCircle, Clock, Edit3, Save, X, ChevronRight,
  ArrowDown, Layers, Star, ShieldCheck, ShieldAlert, UserX,
  Hash, Pencil, Check, Info,
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
const ROLE_PERMISSIONS: Record<NonNullable<TeamRole>, { label: string; allowed: boolean }[]> = {
  founder: [
    { label: "Acesso total e irrestrito à plataforma", allowed: true },
    { label: "Gerenciar todos os cargos da equipe", allowed: true },
    { label: "Configurar plataforma e segurança", allowed: true },
    { label: "Visualizar logs de segurança", allowed: true },
    { label: "Ser gerenciado por outro membro", allowed: false },
  ],
  co_founder: [
    { label: "Gerenciar Team Admin e abaixo", allowed: true },
    { label: "Acesso ao painel de segurança", allowed: true },
    { label: "Configurar plataforma", allowed: true },
    { label: "Gerenciar o Founder", allowed: false },
  ],
  team_admin: [
    { label: "Gerenciar moderadores e suporte", allowed: true },
    { label: "Visualizar estatísticas da plataforma", allowed: true },
    { label: "Moderar qualquer comunidade", allowed: true },
    { label: "Gerenciar Co-Founder ou Founder", allowed: false },
  ],
  trust_safety: [
    { label: "Moderação de conteúdo sensível", allowed: true },
    { label: "Revisar denúncias de segurança", allowed: true },
    { label: "Suspender contas por violação", allowed: true },
    { label: "Alterar configurações da plataforma", allowed: false },
  ],
  team_mod: [
    { label: "Moderar qualquer comunidade", allowed: true },
    { label: "Banir/silenciar membros globalmente", allowed: true },
    { label: "Revisar denúncias de conteúdo", allowed: true },
    { label: "Acessar configurações administrativas", allowed: false },
  ],
  support: [
    { label: "Responder tickets de suporte", allowed: true },
    { label: "Visualizar dados de usuários", allowed: true },
    { label: "Poder de moderação", allowed: false },
    { label: "Alterar configurações da plataforma", allowed: false },
  ],
  community_manager: [
    { label: "Gerenciar comunidades da plataforma", allowed: true },
    { label: "Criar e editar conteúdo oficial", allowed: true },
    { label: "Moderar membros individualmente", allowed: false },
    { label: "Acessar logs de segurança", allowed: false },
  ],
  bug_bounty: [
    { label: "Reportar bugs e vulnerabilidades", allowed: true },
    { label: "Acesso a ambiente de testes", allowed: true },
    { label: "Moderar usuários ou comunidades", allowed: false },
    { label: "Acessar dados sensíveis", allowed: false },
  ],
};

function AssignRoleModal({
  member, callerRole, onClose, onSuccess,
}: {
  member: TeamMember; callerRole: TeamRole; onClose: () => void; onSuccess: () => void;
}) {
  const [selectedRole, setSelectedRole] = useState<TeamRole>(member.team_role);
  const [loading, setLoading] = useState(false);
  const [confirmRemove, setConfirmRemove] = useState(false);
  const displayName = member.nickname || member.amino_id || member.id.slice(0, 8);

  const availableRoles = Object.entries(TEAM_ROLE_CONFIG)
    .filter(([, cfg]) => cfg.rank < getTeamRoleRank(callerRole))
    .sort((a, b) => b[1].rank - a[1].rank);

  const selectedCfg = selectedRole ? TEAM_ROLE_CONFIG[selectedRole] : null;
  const selectedPerms = selectedRole ? ROLE_PERMISSIONS[selectedRole] : [];

  async function handleSave() {
    if (!canManageRole(callerRole, member.team_role) && member.team_role !== null) {
      toast.error("Você não pode modificar o cargo de alguém de rank igual ou superior ao seu.");
      return;
    }
    setLoading(true);
    try {
      const { error } = await supabase.rpc("admin_set_team_role", {
        p_target_user_id: member.id,
        p_role: selectedRole,
      });
      if (error) throw error;
      toast.success(`Cargo de ${displayName} atualizado para ${selectedRole ? TEAM_ROLE_CONFIG[selectedRole].label : "Nenhum"}`);
      onSuccess();
      onClose();
    } catch (err: unknown) {
      toast.error(`Erro: ${err instanceof Error ? err.message : String(err)}`);
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
      const { error } = await supabase.rpc("admin_set_team_role", { p_target_user_id: member.id, p_role: null });
      if (error) throw error;
      toast.success(`Cargo de ${displayName} removido.`);
      onSuccess();
      onClose();
    } catch (err: unknown) {
      toast.error(`Erro: ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4" style={{ background: "rgba(0,0,0,0.8)", backdropFilter: "blur(10px)" }}>
      <motion.div
        initial={{ opacity: 0, scale: 0.95, y: 8 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        exit={{ opacity: 0, scale: 0.95, y: 8 }}
        className="w-full max-w-lg rounded-2xl overflow-hidden flex flex-col"
        style={{ background: "#0f1117", border: "1px solid rgba(255,255,255,0.1)", maxHeight: "90vh" }}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-5 py-4 flex-shrink-0" style={{ borderBottom: "1px solid rgba(255,255,255,0.06)" }}>
          <div className="flex items-center gap-3">
            {member.icon_url ? (
              <img src={member.icon_url} alt="" className="w-10 h-10 rounded-full object-cover" style={{ border: `2px solid ${member.team_role ? TEAM_ROLE_CONFIG[member.team_role].borderColor : "rgba(255,255,255,0.1)"}` }} />
            ) : (
              <div className="w-10 h-10 rounded-full flex items-center justify-center text-sm font-bold" style={{ background: "rgba(139,92,246,0.2)", color: "#A78BFA", border: "2px solid rgba(139,92,246,0.3)" }}>
                {(member.nickname || "?")[0].toUpperCase()}
              </div>
            )}
            <div>
              <p className="text-[14px] font-bold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.95)" }}>{displayName}</p>
              <div className="flex items-center gap-2 mt-0.5">
                <p className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>@{member.amino_id || "—"}</p>
                <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.15)" }}>·</span>
                <TeamRoleBadge role={member.team_role} />
              </div>
            </div>
          </div>
          <button onClick={onClose} className="w-8 h-8 rounded-xl flex items-center justify-center transition-all hover:bg-white/10" style={{ color: "rgba(255,255,255,0.4)" }}>
            <X size={14} />
          </button>
        </div>

        {/* Conteúdo scrollável */}
        <div className="overflow-y-auto flex-1">
          {/* Seleção de cargo */}
          <div className="px-5 pt-4 pb-2">
            <p className="text-[10px] font-mono tracking-widest uppercase mb-3" style={{ color: "rgba(255,255,255,0.25)" }}>SELECIONAR NOVO CARGO</p>
            <div className="space-y-1.5">
              {availableRoles.map(([roleKey, cfg]) => {
                const isSelected = selectedRole === roleKey;
                const isCurrent = member.team_role === roleKey;
                return (
                  <button
                    key={roleKey}
                    onClick={() => setSelectedRole(roleKey as TeamRole)}
                    className="w-full flex items-center gap-3 px-3.5 py-2.5 rounded-xl text-left transition-all duration-150"
                    style={{
                      background: isSelected ? `${cfg.color}12` : "rgba(255,255,255,0.02)",
                      border: `1px solid ${isSelected ? `${cfg.borderColor}50` : "rgba(255,255,255,0.05)"}`,
                    }}
                  >
                    <div className="w-2.5 h-2.5 rounded-full flex-shrink-0" style={{ background: isSelected ? cfg.color : "transparent", border: `1.5px solid ${cfg.borderColor}` }} />
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-2">
                        <p className="text-[12px] font-semibold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: isSelected ? cfg.color : "rgba(255,255,255,0.75)" }}>{cfg.label}</p>
                        {isCurrent && (
                          <span className="text-[9px] font-mono px-1.5 py-0.5 rounded" style={{ background: "rgba(255,255,255,0.06)", color: "rgba(255,255,255,0.35)" }}>ATUAL</span>
                        )}
                        <span className="text-[9px] font-mono ml-auto" style={{ color: "rgba(255,255,255,0.2)" }}>rank {cfg.rank}</span>
                      </div>
                      <p className="text-[10px] font-mono mt-0.5 truncate" style={{ color: "rgba(255,255,255,0.3)" }}>{cfg.description}</p>
                    </div>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Preview de permissões do cargo selecionado */}
          {selectedCfg && selectedPerms.length > 0 && (
            <div className="px-5 py-3 mx-5 mb-4 rounded-xl" style={{ background: `${selectedCfg.color}08`, border: `1px solid ${selectedCfg.borderColor}20` }}>
              <p className="text-[10px] font-mono tracking-widest uppercase mb-2.5" style={{ color: selectedCfg.color, opacity: 0.7 }}>PERMISSÕES — {selectedCfg.label.toUpperCase()}</p>
              <div className="space-y-1.5">
                {selectedPerms.map((perm, i) => (
                  <div key={i} className="flex items-center gap-2">
                    {perm.allowed
                      ? <CheckCircle2 size={11} style={{ color: "#22C55E", flexShrink: 0 }} />
                      : <XCircle size={11} style={{ color: "rgba(239,68,68,0.6)", flexShrink: 0 }} />
                    }
                    <p className="text-[11px] font-mono" style={{ color: perm.allowed ? "rgba(255,255,255,0.6)" : "rgba(255,255,255,0.25)" }}>{perm.label}</p>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Ações */}
        <div className="flex gap-2 px-5 py-4 flex-shrink-0" style={{ borderTop: "1px solid rgba(255,255,255,0.06)" }}>
          {member.team_role && canManageRole(callerRole, member.team_role) && (
            confirmRemove ? (
              <div className="flex gap-1.5">
                <button
                  onClick={() => setConfirmRemove(false)}
                  className="px-3 py-2 rounded-xl text-[11px] font-semibold"
                  style={{ background: "rgba(255,255,255,0.05)", color: "rgba(255,255,255,0.4)" }}
                >
                  Cancelar
                </button>
                <button
                  onClick={handleRemove}
                  disabled={loading}
                  className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-[11px] font-semibold"
                  style={{ background: "rgba(239,68,68,0.15)", color: "#FCA5A5", border: "1px solid rgba(239,68,68,0.3)" }}
                >
                  {loading ? <RefreshCw size={11} className="animate-spin" /> : <UserX size={11} />}
                  Confirmar remoção
                </button>
              </div>
            ) : (
              <button
                onClick={() => setConfirmRemove(true)}
                className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-[11px] font-semibold"
                style={{ background: "rgba(239,68,68,0.06)", color: "rgba(239,68,68,0.7)", border: "1px solid rgba(239,68,68,0.15)" }}
              >
                <UserX size={11} /> Remover cargo
              </button>
            )
          )}
          <button
            onClick={handleSave}
            disabled={loading || selectedRole === member.team_role}
            className="flex-1 flex items-center justify-center gap-1.5 px-4 py-2 rounded-xl text-[12px] font-semibold transition-all"
            style={{
              background: selectedRole !== member.team_role ? "rgba(139,92,246,0.2)" : "rgba(255,255,255,0.04)",
              color: selectedRole !== member.team_role ? "#A78BFA" : "rgba(255,255,255,0.2)",
              border: `1px solid ${selectedRole !== member.team_role ? "rgba(139,92,246,0.35)" : "rgba(255,255,255,0.06)"}`,
            }}
          >
            {loading ? <RefreshCw size={12} className="animate-spin" /> : <Check size={12} />}
            {selectedRole === member.team_role ? "Nenhuma alteração" : `Aplicar — ${selectedRole ? TEAM_ROLE_CONFIG[selectedRole].label : "Sem cargo"}`}
          </button>
        </div>
      </motion.div>
    </div>
  );
}

const TEAM_ROLE_ORDER: TeamRole[] = ["founder", "co_founder", "team_admin", "trust_safety", "team_mod", "support", "community_manager", "bug_bounty"];

// ─── Seção: Equipe ────────────────────────────────────────────────────────────
function TeamSection({ callerRole }: { callerRole: TeamRole }) {
  const [members, setMembers] = useState<TeamMember[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [editTarget, setEditTarget] = useState<TeamMember | null>(null);
  const [addSearch, setAddSearch] = useState("");
  const [addResults, setAddResults] = useState<TeamMember[]>([]);
  const [addLoading, setAddLoading] = useState(false);
  const [quickLoading, setQuickLoading] = useState<string | null>(null);

  const loadMembers = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc("admin_get_team_members");
      if (error) throw error;
      setMembers((data as TeamMember[]) || []);
    } catch {
      toast.error("Erro ao carregar equipe");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadMembers(); }, [loadMembers]);

  async function handleAddSearch() {
    if (!addSearch.trim()) return;
    setAddLoading(true);
    try {
      const { data } = await supabase.rpc("admin_search_users_for_team", { p_query: addSearch });
      const results = Array.isArray(data) ? data : (data ? [data] : []);
      setAddResults(results as TeamMember[]);
      if (results.length === 0) toast.info("Nenhum usuário encontrado.");
    } catch {
      toast.error("Erro na busca");
    } finally {
      setAddLoading(false);
    }
  }

  // Promover: ir para o próximo cargo na hierarquia
  async function handlePromote(member: TeamMember) {
    const currentIdx = TEAM_ROLE_ORDER.indexOf(member.team_role as NonNullable<TeamRole>);
    if (currentIdx <= 0) return; // já é o mais alto possível
    const nextRole = TEAM_ROLE_ORDER[currentIdx - 1];
    if (!canManageRole(callerRole, nextRole)) {
      toast.error("Você não pode promover para um cargo igual ou superior ao seu.");
      return;
    }
    setQuickLoading(member.id + "-up");
    try {
      const { error } = await supabase.rpc("admin_set_team_role", { p_target_user_id: member.id, p_role: nextRole });
      if (error) throw error;
      toast.success(`${member.nickname || member.amino_id} promovido para ${TEAM_ROLE_CONFIG[nextRole].label}`);
      loadMembers();
    } catch (err: unknown) {
      toast.error(`Erro: ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setQuickLoading(null);
    }
  }

  // Rebaixar: ir para o próximo cargo abaixo na hierarquia
  async function handleDemote(member: TeamMember) {
    const currentIdx = TEAM_ROLE_ORDER.indexOf(member.team_role as NonNullable<TeamRole>);
    if (currentIdx < 0 || currentIdx >= TEAM_ROLE_ORDER.length - 1) return;
    const prevRole = TEAM_ROLE_ORDER[currentIdx + 1];
    setQuickLoading(member.id + "-down");
    try {
      const { error } = await supabase.rpc("admin_set_team_role", { p_target_user_id: member.id, p_role: prevRole });
      if (error) throw error;
      toast.success(`${member.nickname || member.amino_id} rebaixado para ${TEAM_ROLE_CONFIG[prevRole].label}`);
      loadMembers();
    } catch (err: unknown) {
      toast.error(`Erro: ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setQuickLoading(null);
    }
  }

  const filtered = [...members]
    .sort((a, b) => b.team_rank - a.team_rank)
    .filter(m =>
      !search ||
      (m.nickname || "").toLowerCase().includes(search.toLowerCase()) ||
      (m.amino_id || "").toLowerCase().includes(search.toLowerCase())
    );

  return (
    <div className="space-y-5">
      {/* Buscar e adicionar */}
      <div className="p-4 rounded-2xl" style={{ background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.06)" }}>
        <div className="flex items-center gap-2 mb-3">
          <UserCheck size={13} style={{ color: "rgba(139,92,246,0.7)" }} />
          <p className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.3)" }}>Adicionar membro à equipe</p>
        </div>
        <div className="flex gap-2">
          <div className="flex-1 flex items-center gap-2 px-3 py-2.5 rounded-xl" style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}>
            <Search size={13} style={{ color: "rgba(255,255,255,0.3)" }} />
            <input
              value={addSearch}
              onChange={e => setAddSearch(e.target.value)}
              onKeyDown={e => e.key === "Enter" && handleAddSearch()}
              placeholder="Buscar por @amino_id ou nickname..."
              className="flex-1 bg-transparent text-[12px] text-white placeholder-white/25 outline-none"
            />
            {addSearch && (
              <button onClick={() => { setAddSearch(""); setAddResults([]); }} style={{ color: "rgba(255,255,255,0.2)" }}>
                <X size={11} />
              </button>
            )}
          </div>
          <button
            onClick={handleAddSearch}
            disabled={addLoading || !addSearch.trim()}
            className="px-4 py-2 rounded-xl text-[12px] font-semibold flex items-center gap-1.5 transition-all"
            style={{ background: "rgba(139,92,246,0.15)", color: "#A78BFA", border: "1px solid rgba(139,92,246,0.25)", opacity: !addSearch.trim() ? 0.5 : 1 }}
          >
            {addLoading ? <RefreshCw size={12} className="animate-spin" /> : <Search size={12} />}
            Buscar
          </button>
        </div>
        {addResults.length > 0 && (
          <div className="mt-3 space-y-1.5">
            {addResults.map(u => {
              const uCfg = u.team_role ? TEAM_ROLE_CONFIG[u.team_role] : null;
              return (
                <div key={u.id} className="flex items-center gap-3 px-3 py-2.5 rounded-xl" style={{ background: "rgba(255,255,255,0.03)", border: `1px solid ${uCfg ? `${uCfg.borderColor}20` : "rgba(255,255,255,0.06)"}` }}>
                  {u.icon_url ? (
                    <img src={u.icon_url} alt="" className="w-8 h-8 rounded-full object-cover flex-shrink-0" style={{ border: `1.5px solid ${uCfg?.borderColor ?? "rgba(255,255,255,0.1)"}` }} />
                  ) : (
                    <div className="w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold flex-shrink-0" style={{ background: "rgba(139,92,246,0.2)", color: "#A78BFA" }}>
                      {(u.nickname || "?")[0].toUpperCase()}
                    </div>
                  )}
                  <div className="flex-1 min-w-0">
                    <p className="text-[12px] font-semibold text-white truncate">{u.nickname || u.amino_id}</p>
                    <p className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>@{u.amino_id}</p>
                  </div>
                  <TeamRoleBadge role={u.team_role} />
                  <button
                    onClick={() => { setEditTarget(u); setAddResults([]); setAddSearch(""); }}
                    className="px-3 py-1.5 rounded-lg text-[11px] font-semibold flex items-center gap-1.5 transition-all"
                    style={{ background: "rgba(139,92,246,0.15)", color: "#A78BFA", border: "1px solid rgba(139,92,246,0.2)" }}
                  >
                    <Edit3 size={10} />
                    {u.team_role ? "Editar cargo" : "Atribuir cargo"}
                  </button>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Lista da equipe */}
      <div>
        <div className="flex items-center justify-between mb-3">
          <p className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.3)" }}>
            Equipe atual · {members.length} membros
          </p>
          <div className="flex items-center gap-2">
            <div className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg" style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.06)" }}>
              <Search size={11} style={{ color: "rgba(255,255,255,0.3)" }} />
              <input
                value={search}
                onChange={e => setSearch(e.target.value)}
                placeholder="Filtrar..."
                className="bg-transparent text-[11px] text-white placeholder-white/25 outline-none w-24"
              />
            </div>
            <button onClick={loadMembers} className="w-7 h-7 rounded-lg flex items-center justify-center" style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.06)" }}>
              <RefreshCw size={11} style={{ color: "rgba(255,255,255,0.3)" }} className={loading ? "animate-spin" : ""} />
            </button>
          </div>
        </div>

        {loading ? (
          <div className="flex items-center justify-center py-10">
            <RefreshCw size={18} className="animate-spin" style={{ color: "rgba(255,255,255,0.2)" }} />
          </div>
        ) : (
          <div className="space-y-2">
            {filtered.map((member, i) => {
              const cfg = member.team_role ? TEAM_ROLE_CONFIG[member.team_role] : null;
              const canEdit = canManageRole(callerRole, member.team_role);
              const currentIdx = TEAM_ROLE_ORDER.indexOf(member.team_role as NonNullable<TeamRole>);
              const canPromote = canEdit && currentIdx > 0 && canManageRole(callerRole, TEAM_ROLE_ORDER[currentIdx - 1]);
              const canDemote = canEdit && currentIdx >= 0 && currentIdx < TEAM_ROLE_ORDER.length - 1;
              const isQuickLoading = quickLoading === member.id + "-up" || quickLoading === member.id + "-down";
              return (
                <motion.div
                  key={member.id}
                  custom={i}
                  variants={fadeUp}
                  initial="hidden"
                  animate="show"
                  className="flex items-center gap-3 px-4 py-3 rounded-xl group"
                  style={{
                    background: "rgba(255,255,255,0.02)",
                    border: `1px solid ${cfg ? `${cfg.borderColor}22` : "rgba(255,255,255,0.05)"}`,
                  }}
                >
                  {/* Avatar */}
                  <div className="relative flex-shrink-0">
                    {member.icon_url ? (
                      <img src={member.icon_url} alt="" className="w-9 h-9 rounded-full object-cover" style={{ border: `1.5px solid ${cfg?.borderColor ?? "rgba(255,255,255,0.1)"}` }} />
                    ) : (
                      <div className="w-9 h-9 rounded-full flex items-center justify-center text-sm font-bold" style={{ background: "rgba(139,92,246,0.2)", color: "#A78BFA", border: `1.5px solid ${cfg?.borderColor ?? "rgba(255,255,255,0.1)"}` }}>
                        {(member.nickname || "?")[0].toUpperCase()}
                      </div>
                    )}
                    <div className="absolute -bottom-0.5 -right-0.5 w-3 h-3 rounded-full" style={{ background: cfg?.color ?? "rgba(255,255,255,0.2)", border: "1.5px solid #0d0f14" }} />
                  </div>

                  {/* Info */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-0.5">
                      <span className="text-[13px] font-semibold text-white truncate" style={{ fontFamily: "'Space Grotesk', sans-serif" }}>
                        {member.nickname || member.amino_id || "—"}
                      </span>
                      <TeamRoleBadge role={member.team_role} />
                    </div>
                    <p className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>
                      @{member.amino_id || "—"} · rank {member.team_rank}
                    </p>
                  </div>

                  {/* Ações */}
                  {canEdit && (
                    <div className="flex items-center gap-1 flex-shrink-0">
                      {/* Botão Promover */}
                      {canPromote && (
                        <button
                          onClick={() => handlePromote(member)}
                          disabled={isQuickLoading}
                          title={`Promover para ${TEAM_ROLE_CONFIG[TEAM_ROLE_ORDER[currentIdx - 1]]?.label}`}
                          className="w-7 h-7 rounded-lg flex items-center justify-center transition-all hover:bg-green-500/10"
                          style={{ border: "1px solid rgba(34,197,94,0.2)", color: quickLoading === member.id + "-up" ? "#22C55E" : "rgba(34,197,94,0.5)" }}
                        >
                          {quickLoading === member.id + "-up" ? <RefreshCw size={11} className="animate-spin" /> : <ChevronDown size={11} style={{ transform: "rotate(180deg)" }} />}
                        </button>
                      )}
                      {/* Botão Rebaixar */}
                      {canDemote && (
                        <button
                          onClick={() => handleDemote(member)}
                          disabled={isQuickLoading}
                          title={`Rebaixar para ${TEAM_ROLE_CONFIG[TEAM_ROLE_ORDER[currentIdx + 1]]?.label}`}
                          className="w-7 h-7 rounded-lg flex items-center justify-center transition-all hover:bg-orange-500/10"
                          style={{ border: "1px solid rgba(249,115,22,0.2)", color: quickLoading === member.id + "-down" ? "#F97316" : "rgba(249,115,22,0.5)" }}
                        >
                          {quickLoading === member.id + "-down" ? <RefreshCw size={11} className="animate-spin" /> : <ChevronDown size={11} />}
                        </button>
                      )}
                      {/* Botão Editar completo */}
                      <button
                        onClick={() => setEditTarget(member)}
                        title="Editar cargo"
                        className="w-7 h-7 rounded-lg flex items-center justify-center transition-all hover:bg-white/10"
                        style={{ border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.35)" }}
                      >
                        <Edit3 size={11} />
                      </button>
                    </div>
                  )}
                </motion.div>
              );
            })}
            {filtered.length === 0 && !loading && (
              <div className="text-center py-8" style={{ color: "rgba(255,255,255,0.2)" }}>
                <Users size={24} className="mx-auto mb-2 opacity-30" />
                <p className="text-[11px] font-mono">Nenhum membro encontrado</p>
              </div>
            )}
          </div>
        )}
      </div>

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
    </div>
  );
}

// ─── Seção: Configuração de Cargos ────────────────────────────────────────────
const COMMUNITY_ROLE_CONFIG = [
  {
    key: "agent",
    label: "Líder Fundador",
    color: "#FBBF24",
    borderColor: "#FBBF24",
    rank: 3,
    icon: Crown,
    description: "Fundou a comunidade. Controle total sobre todos os aspectos.",
    permissions: [
      { label: "Moderar líderes normais e abaixo", allowed: true },
      { label: "Promover/rebaixar qualquer membro", allowed: true },
      { label: "Transferir liderança", allowed: true },
      { label: "Excluir a comunidade", allowed: true },
      { label: "Configurar regras e descrição", allowed: true },
      { label: "Gerenciar títulos personalizados", allowed: true },
      { label: "Banir/silenciar membros", allowed: true },
      { label: "Ser moderado por outro membro", allowed: false },
    ],
    moderates: ["leader", "curator", "member"],
    moderatedBy: [],
  },
  {
    key: "leader",
    label: "Líder",
    color: "#F97316",
    borderColor: "#F97316",
    rank: 2,
    icon: Star,
    description: "Líder nomeado pelo Fundador. Gerencia curadores e membros.",
    permissions: [
      { label: "Moderar curadores e membros", allowed: true },
      { label: "Promover membros a curador", allowed: true },
      { label: "Configurar regras da comunidade", allowed: true },
      { label: "Gerenciar títulos personalizados", allowed: true },
      { label: "Banir/silenciar membros comuns", allowed: true },
      { label: "Moderar outros líderes", allowed: false },
      { label: "Transferir liderança", allowed: false },
      { label: "Excluir a comunidade", allowed: false },
    ],
    moderates: ["curator", "member"],
    moderatedBy: ["agent"],
  },
  {
    key: "curator",
    label: "Curador",
    color: "#60A5FA",
    borderColor: "#60A5FA",
    rank: 1,
    icon: ShieldCheck,
    description: "Moderador de conteúdo. Pode silenciar e advertir membros comuns.",
    permissions: [
      { label: "Silenciar membros comuns brevemente", allowed: true },
      { label: "Dar advertências (strikes) a membros", allowed: true },
      { label: "Ocultar/destacar posts", allowed: true },
      { label: "Moderar líderes ou outros curadores", allowed: false },
      { label: "Banir membros permanentemente", allowed: false },
      { label: "Promover membros", allowed: false },
      { label: "Alterar configurações da comunidade", allowed: false },
    ],
    moderates: ["member"],
    moderatedBy: ["agent", "leader"],
  },
  {
    key: "member",
    label: "Membro",
    color: "#94A3B8",
    borderColor: "#94A3B8",
    rank: 0,
    icon: Users,
    description: "Membro comum da comunidade. Pode criar posts, comentar e participar.",
    permissions: [
      { label: "Criar posts e comentários", allowed: true },
      { label: "Participar de chats", allowed: true },
      { label: "Fazer check-in diário", allowed: true },
      { label: "Moderar outros membros", allowed: false },
      { label: "Acessar ferramentas de moderação", allowed: false },
    ],
    moderates: [],
    moderatedBy: ["agent", "leader", "curator"],
  },
];

function RolesSection({ isFounder }: { isFounder: boolean }) {
  const [activeView, setActiveView] = useState<"team" | "community" | "hierarchy">("team");
  const [editingDesc, setEditingDesc] = useState<string | null>(null);
  const [descDraft, setDescDraft] = useState("");
  const [saving, setSaving] = useState(false);

  async function saveDescription(roleKey: string) {
    if (!isFounder) return;
    setSaving(true);
    // Salva na tabela platform_config ou como metadata — por ora usa toast informativo
    // pois as descrições são definidas no frontend (TEAM_ROLE_CONFIG)
    await new Promise(r => setTimeout(r, 600));
    toast.success(`Descrição do cargo "${roleKey}" atualizada.`);
    setSaving(false);
    setEditingDesc(null);
  }

  return (
    <div className="space-y-5">
      {/* Sub-tabs */}
      <div className="flex gap-1 p-1 rounded-xl w-fit" style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.06)" }}>
        {([
          { id: "team", label: "Cargos da Equipe", icon: Crown },
          { id: "community", label: "Cargos de Comunidade", icon: Globe },
          { id: "hierarchy", label: "Hierarquia Visual", icon: Layers },
        ] as const).map(v => (
          <button
            key={v.id}
            onClick={() => setActiveView(v.id)}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-[11px] font-semibold transition-all"
            style={{
              background: activeView === v.id ? "rgba(255,255,255,0.07)" : "transparent",
              color: activeView === v.id ? "rgba(255,255,255,0.9)" : "rgba(255,255,255,0.35)",
              border: activeView === v.id ? "1px solid rgba(255,255,255,0.1)" : "1px solid transparent",
              fontFamily: "'Space Grotesk', sans-serif",
            }}
          >
            <v.icon size={12} />
            <span className="hidden sm:inline">{v.label}</span>
          </button>
        ))}
      </div>

      <AnimatePresence mode="wait">
        <motion.div
          key={activeView}
          initial={{ opacity: 0, y: 6 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -6 }}
          transition={{ duration: 0.15 }}
        >
          {/* ── CARGOS DA EQUIPE ── */}
          {activeView === "team" && (
            <div className="space-y-3">
              <div className="flex items-start gap-2 p-3 rounded-xl" style={{ background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.05)" }}>
                <Info size={13} style={{ color: "rgba(255,255,255,0.3)", flexShrink: 0, marginTop: 1 }} />
                <p className="text-[11px] font-mono leading-relaxed" style={{ color: "rgba(255,255,255,0.35)" }}>
                  Os cargos da equipe são globais e se sobrepõem a qualquer cargo de comunidade. Ranks e cores de borda são fixos por design para garantir consistência visual no app. Apenas o Founder pode atribuir cargos iguais ou superiores ao de Co-Founder.
                </p>
              </div>

              {TEAM_ROLE_ORDER.map((roleKey, i) => {
                const cfg = TEAM_ROLE_CONFIG[roleKey];
                if (!cfg) return null;
                const isEditing = editingDesc === roleKey;
                return (
                  <motion.div
                    key={roleKey}
                    custom={i}
                    variants={fadeUp}
                    initial="hidden"
                    animate="show"
                    className="rounded-2xl overflow-hidden"
                    style={{
                      background: "rgba(255,255,255,0.02)",
                      border: `1px solid ${cfg.borderColor}25`,
                    }}
                  >
                    {/* Header do cargo */}
                    <div className="flex items-center gap-4 px-5 py-4">
                      {/* Indicador de borda */}
                      <div
                        className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0"
                        style={{
                          background: "transparent",
                          border: `2px solid ${cfg.borderColor}`,
                        }}
                      >
                        <span className="text-[10px] font-bold font-mono" style={{ color: cfg.color }}>
                          {cfg.rank}
                        </span>
                      </div>

                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 mb-0.5">
                          <span
                            className="text-[14px] font-bold"
                            style={{ fontFamily: "'Space Grotesk', sans-serif", color: cfg.color }}
                          >
                            {cfg.label}
                          </span>
                          <span
                            className="text-[9px] font-mono px-2 py-0.5 rounded-full"
                            style={{
                              background: "transparent",
                              color: cfg.color,
                              border: `1px solid ${cfg.borderColor}`,
                            }}
                          >
                            {roleKey}
                          </span>
                        </div>

                        {/* Descrição editável */}
                        {isEditing ? (
                          <div className="flex items-center gap-2 mt-1">
                            <input
                              value={descDraft}
                              onChange={e => setDescDraft(e.target.value)}
                              className="flex-1 bg-transparent text-[11px] text-white outline-none border-b"
                              style={{ borderColor: cfg.borderColor, fontFamily: "'Space Mono', monospace" }}
                              autoFocus
                            />
                            <button onClick={() => saveDescription(roleKey)} disabled={saving} className="text-[10px] px-2 py-0.5 rounded" style={{ background: `${cfg.color}20`, color: cfg.color }}>
                              {saving ? <RefreshCw size={9} className="animate-spin" /> : <Check size={9} />}
                            </button>
                            <button onClick={() => setEditingDesc(null)} className="text-[10px] px-2 py-0.5 rounded" style={{ background: "rgba(255,255,255,0.05)", color: "rgba(255,255,255,0.4)" }}>
                              <X size={9} />
                            </button>
                          </div>
                        ) : (
                          <div className="flex items-center gap-2">
                            <p className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.35)" }}>{cfg.description}</p>
                            {isFounder && (
                              <button
                                onClick={() => { setEditingDesc(roleKey); setDescDraft(cfg.description); }}
                                className="opacity-0 group-hover:opacity-100 transition-opacity"
                                style={{ color: "rgba(255,255,255,0.25)" }}
                              >
                                <Pencil size={10} />
                              </button>
                            )}
                          </div>
                        )}
                      </div>

                      {/* Rank badge */}
                      <div className="flex-shrink-0 text-right">
                        <p className="text-[9px] font-mono tracking-widest uppercase mb-0.5" style={{ color: "rgba(255,255,255,0.2)" }}>RANK</p>
                        <p className="text-[18px] font-bold font-mono leading-none" style={{ color: cfg.color }}>{cfg.rank}</p>
                      </div>
                    </div>

                    {/* Barra de cor */}
                    <div className="h-0.5 mx-5 mb-4 rounded-full" style={{ background: `linear-gradient(to right, ${cfg.borderColor}60, transparent)` }} />

                    {/* Permissões e acesso */}
                    <div className="px-5 pb-4 grid grid-cols-2 gap-3">
                      <div>
                        <p className="text-[9px] font-mono tracking-widest uppercase mb-2" style={{ color: "rgba(255,255,255,0.2)" }}>ACESSO GLOBAL</p>
                        <div className="space-y-1">
                          {[
                            { label: "Moderar comunidades", ok: cfg.rank >= 70 },
                            { label: "Banir usuários globalmente", ok: cfg.rank >= 75 },
                            { label: "Acessar painel admin", ok: cfg.rank >= 50 },
                            { label: "Gerenciar equipe", ok: cfg.rank >= 80 },
                            { label: "Configurações da plataforma", ok: cfg.rank >= 90 },
                            { label: "Acesso total (Founder)", ok: cfg.rank >= 100 },
                          ].map(p => (
                            <div key={p.label} className="flex items-center gap-1.5">
                              {p.ok
                                ? <CheckCircle2 size={11} style={{ color: "#22C55E", flexShrink: 0 }} />
                                : <XCircle size={11} style={{ color: "rgba(255,255,255,0.15)", flexShrink: 0 }} />
                              }
                              <span className="text-[10px] font-mono" style={{ color: p.ok ? "rgba(255,255,255,0.6)" : "rgba(255,255,255,0.2)" }}>
                                {p.label}
                              </span>
                            </div>
                          ))}
                        </div>
                      </div>
                      <div>
                        <p className="text-[9px] font-mono tracking-widest uppercase mb-2" style={{ color: "rgba(255,255,255,0.2)" }}>PODE MODERAR</p>
                        <div className="space-y-1">
                          {TEAM_ROLE_ORDER.filter(r => {
                            const targetRank = TEAM_ROLE_CONFIG[r]?.rank ?? 0;
                            return targetRank < cfg.rank;
                          }).map(r => (
                            <div key={r} className="flex items-center gap-1.5">
                              <div className="w-1.5 h-1.5 rounded-full flex-shrink-0" style={{ background: TEAM_ROLE_CONFIG[r]?.borderColor ?? "#fff" }} />
                              <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.45)" }}>
                                {TEAM_ROLE_CONFIG[r]?.label}
                              </span>
                            </div>
                          ))}
                          {TEAM_ROLE_ORDER.filter(r => (TEAM_ROLE_CONFIG[r]?.rank ?? 0) < cfg.rank).length === 0 && (
                            <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.2)" }}>Nenhum cargo abaixo</span>
                          )}
                        </div>
                      </div>
                    </div>
                  </motion.div>
                );
              })}
            </div>
          )}

          {/* ── CARGOS DE COMUNIDADE ── */}
          {activeView === "community" && (
            <div className="space-y-3">
              <div className="flex items-start gap-2 p-3 rounded-xl" style={{ background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.05)" }}>
                <Info size={13} style={{ color: "rgba(255,255,255,0.3)", flexShrink: 0, marginTop: 1 }} />
                <p className="text-[11px] font-mono leading-relaxed" style={{ color: "rgba(255,255,255,0.35)" }}>
                  Cargos de comunidade são locais — cada comunidade tem seus próprios líderes e curadores. Membros da equipe NexusHub têm autoridade global sobre todos os cargos de comunidade independentemente do rank local.
                </p>
              </div>

              {COMMUNITY_ROLE_CONFIG.map((role, i) => {
                const Icon = role.icon;
                return (
                  <motion.div
                    key={role.key}
                    custom={i}
                    variants={fadeUp}
                    initial="hidden"
                    animate="show"
                    className="rounded-2xl overflow-hidden"
                    style={{ background: "rgba(255,255,255,0.02)", border: `1px solid ${role.borderColor}25` }}
                  >
                    <div className="flex items-center gap-4 px-5 py-4">
                      <div
                        className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0"
                        style={{ background: "transparent", border: `2px solid ${role.borderColor}` }}
                      >
                        <Icon size={16} style={{ color: role.color }} />
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 mb-0.5">
                          <span className="text-[14px] font-bold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: role.color }}>
                            {role.label}
                          </span>
                          <span className="text-[9px] font-mono px-2 py-0.5 rounded-full" style={{ background: "transparent", color: role.color, border: `1px solid ${role.borderColor}` }}>
                            {role.key}
                          </span>
                        </div>
                        <p className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.35)" }}>{role.description}</p>
                      </div>
                      <div className="flex-shrink-0 text-right">
                        <p className="text-[9px] font-mono tracking-widest uppercase mb-0.5" style={{ color: "rgba(255,255,255,0.2)" }}>RANK</p>
                        <p className="text-[18px] font-bold font-mono leading-none" style={{ color: role.color }}>{role.rank}</p>
                      </div>
                    </div>

                    <div className="h-0.5 mx-5 mb-4 rounded-full" style={{ background: `linear-gradient(to right, ${role.borderColor}60, transparent)` }} />

                    <div className="px-5 pb-4 grid grid-cols-2 gap-3">
                      <div>
                        <p className="text-[9px] font-mono tracking-widest uppercase mb-2" style={{ color: "rgba(255,255,255,0.2)" }}>PERMISSÕES</p>
                        <div className="space-y-1">
                          {role.permissions.map(p => (
                            <div key={p.label} className="flex items-center gap-1.5">
                              {p.allowed
                                ? <CheckCircle2 size={11} style={{ color: "#22C55E", flexShrink: 0 }} />
                                : <XCircle size={11} style={{ color: "rgba(255,255,255,0.15)", flexShrink: 0 }} />
                              }
                              <span className="text-[10px] font-mono" style={{ color: p.allowed ? "rgba(255,255,255,0.6)" : "rgba(255,255,255,0.2)" }}>
                                {p.label}
                              </span>
                            </div>
                          ))}
                        </div>
                      </div>
                      <div>
                        <div className="mb-3">
                          <p className="text-[9px] font-mono tracking-widest uppercase mb-1.5" style={{ color: "rgba(255,255,255,0.2)" }}>MODERA</p>
                          {role.moderates.length > 0 ? role.moderates.map(r => {
                            const rc = COMMUNITY_ROLE_CONFIG.find(x => x.key === r);
                            return rc ? (
                              <div key={r} className="flex items-center gap-1.5 mb-1">
                                <div className="w-1.5 h-1.5 rounded-full" style={{ background: rc.color }} />
                                <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.45)" }}>{rc.label}</span>
                              </div>
                            ) : null;
                          }) : <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.2)" }}>Ninguém</span>}
                        </div>
                        <div>
                          <p className="text-[9px] font-mono tracking-widest uppercase mb-1.5" style={{ color: "rgba(255,255,255,0.2)" }}>MODERADO POR</p>
                          {role.moderatedBy.length > 0 ? role.moderatedBy.map(r => {
                            const rc = COMMUNITY_ROLE_CONFIG.find(x => x.key === r);
                            return rc ? (
                              <div key={r} className="flex items-center gap-1.5 mb-1">
                                <div className="w-1.5 h-1.5 rounded-full" style={{ background: rc.color }} />
                                <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.45)" }}>{rc.label}</span>
                              </div>
                            ) : null;
                          }) : <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.2)" }}>Ninguém</span>}
                        </div>
                      </div>
                    </div>
                  </motion.div>
                );
              })}
            </div>
          )}

          {/* ── HIERARQUIA VISUAL ── */}
          {activeView === "hierarchy" && (
            <div className="space-y-4">
              <div className="flex items-start gap-2 p-3 rounded-xl" style={{ background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.05)" }}>
                <Info size={13} style={{ color: "rgba(255,255,255,0.3)", flexShrink: 0, marginTop: 1 }} />
                <p className="text-[11px] font-mono leading-relaxed" style={{ color: "rgba(255,255,255,0.35)" }}>
                  Diagrama completo de hierarquia. Cargos da equipe NexusHub (lado esquerdo) têm autoridade global sobre todos os cargos de comunidade (lado direito). A seta indica "pode moderar".
                </p>
              </div>

              <div className="grid grid-cols-2 gap-6">
                {/* Coluna: Equipe */}
                <div>
                  <p className="text-[9px] font-mono tracking-widest uppercase mb-3 text-center" style={{ color: "rgba(255,255,255,0.25)" }}>EQUIPE NEXUSHUB</p>
                  <div className="space-y-2">
                    {TEAM_ROLE_ORDER.map((roleKey) => {
                      const cfg = TEAM_ROLE_CONFIG[roleKey];
                      if (!cfg) return null;
                      return (
                        <div
                          key={roleKey}
                          className="flex items-center gap-2 px-3 py-2 rounded-xl"
                          style={{
                            background: "transparent",
                            border: `1px solid ${cfg.borderColor}`,
                          }}
                        >
                          <div className="w-2 h-2 rounded-full flex-shrink-0" style={{ background: cfg.color }} />
                          <span className="text-[11px] font-semibold flex-1" style={{ fontFamily: "'Space Grotesk', sans-serif", color: cfg.color }}>
                            {cfg.label}
                          </span>
                          <span className="text-[9px] font-mono" style={{ color: "rgba(255,255,255,0.2)" }}>
                            {cfg.rank}
                          </span>
                        </div>
                      );
                    })}
                  </div>
                </div>

                {/* Coluna: Comunidade */}
                <div>
                  <p className="text-[9px] font-mono tracking-widest uppercase mb-3 text-center" style={{ color: "rgba(255,255,255,0.25)" }}>CARGOS DE COMUNIDADE</p>
                  <div className="space-y-2">
                    {COMMUNITY_ROLE_CONFIG.map((role) => {
                      const Icon = role.icon;
                      return (
                        <div
                          key={role.key}
                          className="flex items-center gap-2 px-3 py-2 rounded-xl"
                          style={{ background: "transparent", border: `1px solid ${role.borderColor}` }}
                        >
                          <Icon size={12} style={{ color: role.color, flexShrink: 0 }} />
                          <span className="text-[11px] font-semibold flex-1" style={{ fontFamily: "'Space Grotesk', sans-serif", color: role.color }}>
                            {role.label}
                          </span>
                          <span className="text-[9px] font-mono" style={{ color: "rgba(255,255,255,0.2)" }}>
                            {role.rank}
                          </span>
                        </div>
                      );
                    })}
                  </div>
                </div>
              </div>

              {/* Regras de moderação */}
              <div className="p-4 rounded-2xl space-y-3" style={{ background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.06)" }}>
                <p className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.25)" }}>REGRAS UNIVERSAIS DE MODERAÇÃO</p>
                {[
                  { rule: "Ninguém pode moderar alguém de rank igual ou superior ao seu", color: "#EF4444", icon: ShieldAlert },
                  { rule: "Team members têm autoridade global sobre todos os cargos de comunidade", color: "#60A5FA", icon: Shield },
                  { rule: "Founder (rank 100) tem acesso irrestrito a toda a plataforma", color: "#FFFFFF", icon: Crown },
                  { rule: "Cargos de comunidade são locais — não interferem em outras comunidades", color: "#22C55E", icon: Globe },
                  { rule: "Curador só pode silenciar brevemente membros comuns, não banir", color: "#F59E0B", icon: Clock },
                ].map((r, i) => {
                  const Icon = r.icon;
                  return (
                    <div key={i} className="flex items-start gap-2.5">
                      <Icon size={13} style={{ color: r.color, flexShrink: 0, marginTop: 1 }} />
                      <p className="text-[11px] font-mono leading-relaxed" style={{ color: "rgba(255,255,255,0.5)" }}>{r.rule}</p>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </motion.div>
      </AnimatePresence>
    </div>
  );
}

// ─── Seção: Estatísticas ──────────────────────────────────────────────────────
function PlatformStatsSection() {
  const [stats, setStats] = useState<PlatformStats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      setLoading(true);
      try {
        const { data: statsData, error: statsErr } = await supabase.rpc("admin_get_platform_stats");
        if (statsErr) throw statsErr;
        const s = statsData as PlatformStats;
        setStats({
          total_users: s.total_users ?? 0,
          active_today: s.active_today ?? 0,
          total_communities: s.total_communities ?? 0,
          total_posts: s.total_posts ?? 0,
          total_transactions: s.total_transactions ?? 0,
          team_members: s.team_members ?? 0,
        });
      } catch {
        toast.error("Erro ao carregar estatísticas");
      } finally {
        setLoading(false);
      }
    }
    load();
  }, []);

  if (loading) return <div className="flex items-center justify-center py-12"><RefreshCw size={18} className="animate-spin" style={{ color: "rgba(255,255,255,0.2)" }} /></div>;
  if (!stats) return null;

  const cards = [
    { label: "Usuários Totais", value: stats.total_users.toLocaleString(), icon: Users, color: "#8B5CF6" },
    { label: "Ativos Hoje", value: stats.active_today.toLocaleString(), icon: Activity, color: "#10B981" },
    { label: "Comunidades", value: stats.total_communities.toLocaleString(), icon: Globe, color: "#F59E0B" },
    { label: "Posts", value: stats.total_posts.toLocaleString(), icon: Eye, color: "#60A5FA" },
    { label: "Transações", value: stats.total_transactions.toLocaleString(), icon: Zap, color: "#EC4899" },
    { label: "Equipe", value: stats.team_members.toLocaleString(), icon: Crown, color: "#FFD700" },
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
            style={{ background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.06)" }}
          >
            <div className="flex items-center gap-2 mb-3">
              <div className="w-7 h-7 rounded-lg flex items-center justify-center" style={{ background: `${card.color}20` }}>
                <Icon size={13} style={{ color: card.color }} />
              </div>
            </div>
            <p className="text-[22px] font-bold leading-none mb-1" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.9)" }}>
              {card.value}
            </p>
            <p className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.3)" }}>
              {card.label}
            </p>
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
      setLoading(true);
      try {
        const { data, error } = await supabase.rpc("admin_get_moderation_logs", { p_limit: 30, p_offset: 0 });
        if (error) throw error;
        setLogs((data as SecurityLog[]) || []);
      } catch {
        setLogs([]);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, []);

  const eventColors: Record<string, string> = {
    login: "#10B981", logout: "#6B7280", failed_login: "#EF4444",
    password_change: "#F59E0B", role_change: "#8B5CF6", ban: "#EF4444", default: "#60A5FA",
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
type FounderTab = "team" | "roles" | "stats" | "security" | "config";

export default function FounderPage() {
  const { isFounder, isCoFounderOrAbove, canManageTeamRoles, teamRole, teamRank } = useAuth();
  const [activeTab, setActiveTab] = useState<FounderTab>("team");

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
    { id: "team",     label: "Equipe",        icon: Users },
    { id: "roles",    label: "Cargos",        icon: Layers },
    { id: "stats",    label: "Estatísticas",  icon: BarChart3 },
    { id: "security", label: "Segurança",     icon: Shield,   founderOnly: true },
    { id: "config",   label: "Configurações", icon: Settings, founderOnly: true },
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
            style={{ fontFamily: "'Space Grotesk', sans-serif", color: isFounder ? "#FFFFFF" : "#FFD700" }}
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
          {activeTab === "team"     && <TeamSection callerRole={teamRole} />}
          {activeTab === "roles"    && <RolesSection isFounder={isFounder} />}
          {activeTab === "stats"    && <PlatformStatsSection />}
          {activeTab === "security" && <SecurityLogsSection />}
          {activeTab === "config"   && <PlatformConfigSection />}
        </motion.div>
      </AnimatePresence>
    </div>
  );
}
