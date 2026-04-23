import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { toast } from "sonner";
import {
  Search, Users, ShoppingBag, ArrowLeft, ChevronRight, Crown, Shield,
  Ban, Coins, UserCheck, UserX, AlertTriangle, Plus, Minus, RefreshCw,
  Activity, Calendar, Hash,
} from "lucide-react";

type Profile = {
  id: string; username: string; display_name: string | null;
  avatar_url: string | null; coins_balance: number; total_coins_earned: number;
  is_team_admin: boolean; is_team_moderator: boolean; is_banned?: boolean;
  created_at: string; last_seen_at: string | null;
};

type Purchase = {
  id: string; item_name: string; price_coins: number;
  purchased_at: string; item_type: string;
};

type Transaction = {
  id: string; amount: number; source: string;
  description: string | null; created_at: string;
};

const fadeUp = {
  hidden: { opacity: 0, y: 12 },
  show: (i: number) => ({ opacity: 1, y: 0, transition: { delay: i * 0.04, duration: 0.25, ease: "easeOut" } }),
};

// ─── Modal de ação ────────────────────────────────────────────────────────────
function ActionModal({
  type,
  user,
  onClose,
  onSuccess,
}: {
  type: "coins" | "ban" | "role" | "strike";
  user: Profile;
  onClose: () => void;
  onSuccess: (updated: Partial<Profile>) => void;
}) {
  const [loading, setLoading] = useState(false);
  const [coinsAmount, setCoinsAmount] = useState(100);
  const [coinsOp, setCoinsOp] = useState<"add" | "remove">("add");
  const [coinsReason, setCoinsReason] = useState("");
  const [banReason, setBanReason] = useState("");
  const [strikeReason, setStrikeReason] = useState("");
  const [roleTarget, setRoleTarget] = useState<"admin" | "mod" | "none">(
    user.is_team_admin ? "admin" : user.is_team_moderator ? "mod" : "none"
  );

  async function handleCoins() {
    if (!coinsAmount || coinsAmount <= 0) { toast.error("Informe um valor válido."); return; }
    setLoading(true);
    try {
      const delta = coinsOp === "add" ? coinsAmount : -coinsAmount;
      const newBalance = Math.max(0, (user.coins_balance || 0) + delta);
      const { error } = await supabase
        .from("profiles")
        .update({ coins_balance: newBalance })
        .eq("id", user.id);
      if (error) throw error;

      // Registrar transação
      await supabase.from("coin_transactions").insert({
        user_id: user.id,
        amount: delta,
        source: "admin_adjustment",
        description: coinsReason.trim() || `Ajuste manual pelo admin (${coinsOp === "add" ? "+" : "-"}${coinsAmount})`,
      });

      toast.success(`${coinsOp === "add" ? "+" : "-"}${coinsAmount} coins aplicados a @${user.username}`);
      onSuccess({ coins_balance: newBalance });
      onClose();
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : "Erro ao ajustar coins.");
    } finally { setLoading(false); }
  }

  async function handleBan() {
    setLoading(true);
    try {
      const isBanned = !!user.is_banned;
      if (!isBanned && !banReason.trim()) { toast.error("Informe o motivo do banimento."); setLoading(false); return; }

      if (!isBanned) {
        // Banir: inserir em bans + marcar perfil
        await supabase.from("bans").insert({
          user_id: user.id,
          banned_by: (await supabase.auth.getUser()).data.user?.id,
          reason: banReason.trim(),
          is_active: true,
        });
      } else {
        // Desbanir: desativar ban ativo
        await supabase.from("bans").update({ is_active: false }).eq("user_id", user.id).eq("is_active", true);
      }

      toast.success(`@${user.username} foi ${isBanned ? "desbanido" : "banido"}.`);
      onSuccess({ is_banned: !isBanned });
      onClose();
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : "Erro ao processar banimento.");
    } finally { setLoading(false); }
  }

  async function handleRole() {
    setLoading(true);
    try {
      const update = {
        is_team_admin: roleTarget === "admin",
        is_team_moderator: roleTarget === "mod" || roleTarget === "admin",
      };
      const { error } = await supabase.from("profiles").update(update).eq("id", user.id);
      if (error) throw error;
      toast.success(`Cargo de @${user.username} atualizado para ${roleTarget === "none" ? "Usuário" : roleTarget === "mod" ? "Moderador" : "Admin"}.`);
      onSuccess(update);
      onClose();
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : "Erro ao atualizar cargo.");
    } finally { setLoading(false); }
  }

  async function handleStrike() {
    if (!strikeReason.trim()) { toast.error("Informe o motivo do strike."); return; }
    setLoading(true);
    try {
      await supabase.from("strikes").insert({
        user_id: user.id,
        issued_by: (await supabase.auth.getUser()).data.user?.id,
        reason: strikeReason.trim(),
        is_active: true,
      });
      toast.success(`Strike aplicado a @${user.username}.`);
      onClose();
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : "Erro ao aplicar strike.");
    } finally { setLoading(false); }
  }

  const titles: Record<string, string> = {
    coins: "Ajustar Coins",
    ban: user.is_banned ? "Desbanir Usuário" : "Banir Usuário",
    role: "Gerenciar Cargo",
    strike: "Aplicar Strike",
  };

  const colors: Record<string, string> = {
    coins: "#F59E0B",
    ban: "#EF4444",
    role: "#A78BFA",
    strike: "#F97316",
  };

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
        style={{ background: "#1C1E22", border: `1px solid ${colors[type]}30` }}
      >
        {/* Header */}
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-xl flex items-center justify-center" style={{ background: `${colors[type]}15` }}>
            {type === "coins" && <Coins size={16} style={{ color: colors[type] }} />}
            {type === "ban" && <Ban size={16} style={{ color: colors[type] }} />}
            {type === "role" && <Crown size={16} style={{ color: colors[type] }} />}
            {type === "strike" && <AlertTriangle size={16} style={{ color: colors[type] }} />}
          </div>
          <div>
            <h3 className="text-[15px] font-bold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.95)" }}>{titles[type]}</h3>
            <p className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>@{user.username}</p>
          </div>
        </div>

        {/* Coins */}
        {type === "coins" && (
          <div className="space-y-4">
            <div className="flex gap-2">
              {(["add", "remove"] as const).map((op) => (
                <button key={op} onClick={() => setCoinsOp(op)}
                  className="flex-1 py-2 rounded-xl text-[13px] font-semibold transition-all"
                  style={{
                    background: coinsOp === op ? (op === "add" ? "rgba(16,185,129,0.15)" : "rgba(239,68,68,0.15)") : "rgba(255,255,255,0.04)",
                    border: `1px solid ${coinsOp === op ? (op === "add" ? "rgba(16,185,129,0.3)" : "rgba(239,68,68,0.3)") : "rgba(255,255,255,0.07)"}`,
                    color: coinsOp === op ? (op === "add" ? "#34D399" : "#FCA5A5") : "rgba(255,255,255,0.4)",
                    fontFamily: "'Space Grotesk', sans-serif",
                  }}
                >
                  {op === "add" ? <span className="flex items-center justify-center gap-1"><Plus size={12} />Adicionar</span> : <span className="flex items-center justify-center gap-1"><Minus size={12} />Remover</span>}
                </button>
              ))}
            </div>
            <div>
              <label className="text-[10px] font-mono tracking-widest uppercase mb-1.5 block" style={{ color: "rgba(255,255,255,0.3)" }}>Quantidade ✦</label>
              <input type="number" min={1} value={coinsAmount} onChange={(e) => setCoinsAmount(parseInt(e.target.value) || 0)}
                className="w-full px-3 py-2 rounded-xl text-[14px] font-mono outline-none"
                style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "#F59E0B", fontFamily: "'DM Mono', monospace" }} />
            </div>
            <div>
              <label className="text-[10px] font-mono tracking-widest uppercase mb-1.5 block" style={{ color: "rgba(255,255,255,0.3)" }}>Motivo (opcional)</label>
              <input value={coinsReason} onChange={(e) => setCoinsReason(e.target.value)} placeholder="Ex: Compensação por bug, prêmio de evento..."
                className="w-full px-3 py-2 rounded-xl text-[13px] outline-none"
                style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.8)", fontFamily: "'Space Grotesk', sans-serif" }} />
            </div>
            <div className="p-3 rounded-xl" style={{ background: "rgba(245,158,11,0.06)", border: "1px solid rgba(245,158,11,0.15)" }}>
              <p className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.4)" }}>Saldo atual: <span style={{ color: "#F59E0B" }}>{(user.coins_balance || 0).toLocaleString()} ✦</span></p>
              <p className="text-[11px] font-mono mt-0.5" style={{ color: "rgba(255,255,255,0.4)" }}>
                Novo saldo: <span style={{ color: coinsOp === "add" ? "#34D399" : "#FCA5A5" }}>
                  {Math.max(0, (user.coins_balance || 0) + (coinsOp === "add" ? coinsAmount : -coinsAmount)).toLocaleString()} ✦
                </span>
              </p>
            </div>
            <button onClick={handleCoins} disabled={loading}
              className="w-full py-2.5 rounded-xl text-[13px] font-semibold transition-all disabled:opacity-50"
              style={{ background: coinsOp === "add" ? "rgba(16,185,129,0.15)" : "rgba(239,68,68,0.15)", border: `1px solid ${coinsOp === "add" ? "rgba(16,185,129,0.3)" : "rgba(239,68,68,0.3)"}`, color: coinsOp === "add" ? "#34D399" : "#FCA5A5", fontFamily: "'Space Grotesk', sans-serif" }}>
              {loading ? "Aplicando..." : `${coinsOp === "add" ? "Adicionar" : "Remover"} ${coinsAmount} coins`}
            </button>
          </div>
        )}

        {/* Ban */}
        {type === "ban" && (
          <div className="space-y-4">
            {!user.is_banned ? (
              <>
                <div className="p-3 rounded-xl" style={{ background: "rgba(239,68,68,0.06)", border: "1px solid rgba(239,68,68,0.15)" }}>
                  <p className="text-[12px]" style={{ color: "rgba(255,255,255,0.6)", fontFamily: "'Space Grotesk', sans-serif" }}>
                    O usuário será impedido de acessar a plataforma. Esta ação pode ser revertida.
                  </p>
                </div>
                <div>
                  <label className="text-[10px] font-mono tracking-widest uppercase mb-1.5 block" style={{ color: "rgba(255,255,255,0.3)" }}>Motivo *</label>
                  <textarea value={banReason} onChange={(e) => setBanReason(e.target.value)} placeholder="Descreva o motivo do banimento..." rows={3}
                    className="w-full px-3 py-2 rounded-xl text-[13px] outline-none resize-none"
                    style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.8)", fontFamily: "'Space Grotesk', sans-serif" }} />
                </div>
                <button onClick={handleBan} disabled={loading || !banReason.trim()}
                  className="w-full py-2.5 rounded-xl text-[13px] font-semibold transition-all disabled:opacity-50"
                  style={{ background: "rgba(239,68,68,0.15)", border: "1px solid rgba(239,68,68,0.3)", color: "#FCA5A5", fontFamily: "'Space Grotesk', sans-serif" }}>
                  {loading ? "Banindo..." : "Confirmar Banimento"}
                </button>
              </>
            ) : (
              <>
                <div className="p-3 rounded-xl" style={{ background: "rgba(16,185,129,0.06)", border: "1px solid rgba(16,185,129,0.15)" }}>
                  <p className="text-[12px]" style={{ color: "rgba(255,255,255,0.6)", fontFamily: "'Space Grotesk', sans-serif" }}>
                    O usuário terá acesso restaurado à plataforma.
                  </p>
                </div>
                <button onClick={handleBan} disabled={loading}
                  className="w-full py-2.5 rounded-xl text-[13px] font-semibold transition-all disabled:opacity-50"
                  style={{ background: "rgba(16,185,129,0.15)", border: "1px solid rgba(16,185,129,0.3)", color: "#34D399", fontFamily: "'Space Grotesk', sans-serif" }}>
                  {loading ? "Processando..." : "Confirmar Desbanimento"}
                </button>
              </>
            )}
          </div>
        )}

        {/* Role */}
        {type === "role" && (
          <div className="space-y-4">
            <div className="space-y-2">
              {([
                { value: "none", label: "Usuário Comum", desc: "Sem privilégios especiais", color: "#9CA3AF" },
                { value: "mod", label: "Moderador", desc: "Pode moderar conteúdo e aplicar strikes", color: "#67E8F9" },
                { value: "admin", label: "Admin", desc: "Acesso total ao painel administrativo", color: "#A78BFA" },
              ] as const).map((opt) => (
                <button key={opt.value} onClick={() => setRoleTarget(opt.value)}
                  className="w-full flex items-center gap-3 p-3 rounded-xl transition-all text-left"
                  style={{
                    background: roleTarget === opt.value ? `${opt.color}10` : "rgba(255,255,255,0.03)",
                    border: `1px solid ${roleTarget === opt.value ? `${opt.color}30` : "rgba(255,255,255,0.07)"}`,
                  }}>
                  <div className="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0" style={{ background: `${opt.color}15` }}>
                    {opt.value === "none" && <Users size={14} style={{ color: opt.color }} />}
                    {opt.value === "mod" && <Shield size={14} style={{ color: opt.color }} />}
                    {opt.value === "admin" && <Crown size={14} style={{ color: opt.color }} />}
                  </div>
                  <div>
                    <p className="text-[13px] font-semibold" style={{ color: roleTarget === opt.value ? opt.color : "rgba(255,255,255,0.8)", fontFamily: "'Space Grotesk', sans-serif" }}>{opt.label}</p>
                    <p className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>{opt.desc}</p>
                  </div>
                  {roleTarget === opt.value && <div className="ml-auto w-2 h-2 rounded-full" style={{ background: opt.color }} />}
                </button>
              ))}
            </div>
            <button onClick={handleRole} disabled={loading}
              className="w-full py-2.5 rounded-xl text-[13px] font-semibold transition-all disabled:opacity-50"
              style={{ background: "rgba(167,139,250,0.15)", border: "1px solid rgba(167,139,250,0.3)", color: "#A78BFA", fontFamily: "'Space Grotesk', sans-serif" }}>
              {loading ? "Salvando..." : "Confirmar Cargo"}
            </button>
          </div>
        )}

        {/* Strike */}
        {type === "strike" && (
          <div className="space-y-4">
            <div className="p-3 rounded-xl" style={{ background: "rgba(249,115,22,0.06)", border: "1px solid rgba(249,115,22,0.15)" }}>
              <p className="text-[12px]" style={{ color: "rgba(255,255,255,0.6)", fontFamily: "'Space Grotesk', sans-serif" }}>
                Um strike é um aviso formal registrado no histórico do usuário. Múltiplos strikes podem resultar em banimento.
              </p>
            </div>
            <div>
              <label className="text-[10px] font-mono tracking-widest uppercase mb-1.5 block" style={{ color: "rgba(255,255,255,0.3)" }}>Motivo *</label>
              <textarea value={strikeReason} onChange={(e) => setStrikeReason(e.target.value)} placeholder="Descreva o motivo do strike..." rows={3}
                className="w-full px-3 py-2 rounded-xl text-[13px] outline-none resize-none"
                style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.8)", fontFamily: "'Space Grotesk', sans-serif" }} />
            </div>
            <button onClick={handleStrike} disabled={loading || !strikeReason.trim()}
              className="w-full py-2.5 rounded-xl text-[13px] font-semibold transition-all disabled:opacity-50"
              style={{ background: "rgba(249,115,22,0.15)", border: "1px solid rgba(249,115,22,0.3)", color: "#FB923C", fontFamily: "'Space Grotesk', sans-serif" }}>
              {loading ? "Aplicando..." : "Aplicar Strike"}
            </button>
          </div>
        )}

        <button onClick={onClose} className="w-full py-2 rounded-xl text-[12px] font-mono transition-all"
          style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)", color: "rgba(255,255,255,0.3)" }}>
          Cancelar
        </button>
      </motion.div>
    </div>
  );
}

// ─── Página principal ─────────────────────────────────────────────────────────
export default function UsersPage() {
  const [users, setUsers] = useState<Profile[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [selected, setSelected] = useState<Profile | null>(null);
  const [purchases, setPurchases] = useState<Purchase[]>([]);
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [loadingDetail, setLoadingDetail] = useState(false);
  const [modal, setModal] = useState<{ type: "coins" | "ban" | "role" | "strike"; user: Profile } | null>(null);

  async function loadUsers() {
    setLoading(true);
    const { data, error } = await supabase
      .from("profiles")
      .select("id, username, display_name, avatar_url, coins_balance, total_coins_earned, is_team_admin, is_team_moderator, created_at, last_seen_at")
      .order("created_at", { ascending: false });
    if (!error && data) setUsers(data as Profile[]);
    setLoading(false);
  }

  useEffect(() => { loadUsers(); }, []);

  async function selectUser(user: Profile) {
    setSelected(user);
    setLoadingDetail(true);
    const [{ data: pData }, { data: tData }] = await Promise.all([
      supabase.from("user_purchases").select("id, item_name:store_items(name), price_coins, purchased_at, item_type:store_items(type)").eq("user_id", user.id).order("purchased_at", { ascending: false }).limit(20),
      supabase.from("coin_transactions").select("id, amount, source, description, created_at").eq("user_id", user.id).order("created_at", { ascending: false }).limit(20),
    ]);
    if (pData) setPurchases(pData.map((p: any) => ({ id: p.id, item_name: p.item_name?.name ?? "—", price_coins: p.price_coins, purchased_at: p.purchased_at, item_type: p.item_type?.type ?? "" })));
    if (tData) setTransactions(tData as Transaction[]);
    setLoadingDetail(false);
  }

  function handleModalSuccess(updated: Partial<Profile>) {
    if (selected) {
      const newSelected = { ...selected, ...updated };
      setSelected(newSelected);
      setUsers((prev) => prev.map((u) => u.id === selected.id ? newSelected : u));
    }
  }

  const filtered = users.filter(u =>
    !search || u.username?.toLowerCase().includes(search.toLowerCase()) || (u.display_name ?? "").toLowerCase().includes(search.toLowerCase())
  );

  const totalCoins = users.reduce((s, u) => s + (u.coins_balance || 0), 0);
  const adminCount = users.filter(u => u.is_team_admin).length;

  return (
    <>
      <AnimatePresence>
        {modal && (
          <ActionModal
            type={modal.type}
            user={modal.user}
            onClose={() => setModal(null)}
            onSuccess={handleModalSuccess}
          />
        )}
      </AnimatePresence>

      <div className="p-4 md:p-6 max-w-7xl mx-auto space-y-5">
        <AnimatePresence mode="wait">
          {!selected ? (
            <motion.div key="list" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="space-y-5">
              {/* Header */}
              <motion.div variants={fadeUp} initial="hidden" animate="show" custom={0} className="flex items-start justify-between gap-3">
                <div>
                  <h1 className="text-[20px] font-bold tracking-tight" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.95)" }}>Usuários</h1>
                  <p className="text-[12px] font-mono mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>{users.length} cadastrados · {adminCount} admins</p>
                </div>
                <button onClick={loadUsers} className="w-8 h-8 rounded-xl flex items-center justify-center transition-all"
                  style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.4)" }}>
                  <RefreshCw size={13} />
                </button>
              </motion.div>

              {/* Stats */}
              <motion.div variants={fadeUp} initial="hidden" animate="show" custom={1} className="grid grid-cols-3 gap-3">
                {[
                  { label: "Total", value: users.length, icon: Users, color: "#A78BFA", rgb: "167,139,250" },
                  { label: "Coins em Circulação", value: totalCoins.toLocaleString() + " ✦", icon: Coins, color: "#F59E0B", rgb: "245,158,11" },
                  { label: "Admins/Mods", value: adminCount, icon: Crown, color: "#EC4899", rgb: "236,72,153" },
                ].map(({ label, value, icon: Icon, color, rgb }) => (
                  <div key={label} className="p-3 md:p-4 rounded-2xl" style={{ background: `rgba(${rgb},0.06)`, border: `1px solid rgba(${rgb},0.15)` }}>
                    <div className="flex items-center gap-2 mb-1">
                      <Icon size={12} style={{ color }} />
                      <span className="text-[10px] font-mono tracking-wider uppercase" style={{ color: "rgba(255,255,255,0.35)" }}>{label}</span>
                    </div>
                    <div className="text-[18px] font-bold font-mono" style={{ color }}>{value}</div>
                  </div>
                ))}
              </motion.div>

              {/* Search */}
              <motion.div variants={fadeUp} initial="hidden" animate="show" custom={2} className="relative">
                <Search size={13} className="absolute left-3 top-1/2 -translate-y-1/2" style={{ color: "rgba(255,255,255,0.25)" }} />
                <input placeholder="Buscar por username ou nome..." value={search} onChange={(e) => setSearch(e.target.value)}
                  className="w-full pl-9 pr-3 py-2 rounded-xl text-[13px] outline-none"
                  style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.85)", fontFamily: "'Space Grotesk', sans-serif" }} />
              </motion.div>

              {/* Users list */}
              {loading ? (
                <div className="space-y-2">{[...Array(6)].map((_, i) => <div key={i} className="h-14 rounded-xl" style={{ background: "rgba(255,255,255,0.03)" }} />)}</div>
              ) : (
                <motion.div variants={fadeUp} initial="hidden" animate="show" custom={3} className="rounded-2xl overflow-hidden"
                  style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}>
                  {filtered.map((user, i) => (
                    <motion.div key={user.id} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: i * 0.025 }}
                      onClick={() => selectUser(user)}
                      className="flex items-center gap-3 px-4 py-3 cursor-pointer transition-all duration-150 group"
                      style={{ borderBottom: i < filtered.length - 1 ? "1px solid rgba(255,255,255,0.04)" : "none" }}
                      onMouseEnter={e => (e.currentTarget.style.background = "rgba(255,255,255,0.03)")}
                      onMouseLeave={e => (e.currentTarget.style.background = "transparent")}
                    >
                      <div className="w-9 h-9 rounded-xl flex-shrink-0 overflow-hidden flex items-center justify-center"
                        style={{ background: "rgba(124,58,237,0.1)", border: "1px solid rgba(124,58,237,0.2)" }}>
                        {user.avatar_url ? <img src={user.avatar_url} alt={user.username} className="w-full h-full object-cover" /> : (
                          <span className="text-[13px] font-bold" style={{ color: "#A78BFA" }}>{(user.display_name || user.username || "?")[0].toUpperCase()}</span>
                        )}
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2">
                          <span className="text-[13px] font-semibold truncate" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.9)" }}>
                            {user.display_name || user.username}
                          </span>
                          {user.is_team_admin && <span className="nx-badge nx-badge-violet flex items-center gap-1"><Crown size={8} /> ADMIN</span>}
                          {user.is_team_moderator && !user.is_team_admin && <span className="nx-badge nx-badge-cyan flex items-center gap-1"><Shield size={8} /> MOD</span>}
                          {user.is_banned && <span className="nx-badge flex items-center gap-1" style={{ background: "rgba(239,68,68,0.1)", color: "#FCA5A5", border: "1px solid rgba(239,68,68,0.2)" }}><Ban size={8} /> BAN</span>}
                        </div>
                        <div className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>@{user.username}</div>
                      </div>
                      <div className="text-right flex-shrink-0">
                        <div className="text-[13px] font-mono font-bold" style={{ color: "#F59E0B" }}>{(user.coins_balance || 0).toLocaleString()} ✦</div>
                        <div className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.25)" }}>{new Date(user.created_at).toLocaleDateString("pt-BR")}</div>
                      </div>
                      <ChevronRight size={14} className="flex-shrink-0 transition-transform group-hover:translate-x-0.5" style={{ color: "rgba(255,255,255,0.2)" }} />
                    </motion.div>
                  ))}
                </motion.div>
              )}
            </motion.div>
          ) : (
            <motion.div key="detail" initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -20 }} className="space-y-5">
              {/* Back + Header */}
              <div className="flex items-center gap-3">
                <button onClick={() => setSelected(null)}
                  className="w-8 h-8 rounded-xl flex items-center justify-center transition-all duration-150"
                  style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.6)" }}>
                  <ArrowLeft size={14} />
                </button>
                <div className="flex items-center gap-3 flex-1">
                  <div className="w-10 h-10 rounded-xl overflow-hidden flex items-center justify-center"
                    style={{ background: "rgba(124,58,237,0.1)", border: "1px solid rgba(124,58,237,0.2)" }}>
                    {selected.avatar_url ? <img src={selected.avatar_url} alt={selected.username} className="w-full h-full object-cover" /> : (
                      <span className="text-[16px] font-bold" style={{ color: "#A78BFA" }}>{(selected.display_name || selected.username || "?")[0].toUpperCase()}</span>
                    )}
                  </div>
                  <div className="flex-1">
                    <div className="flex items-center gap-2 flex-wrap">
                      <h2 className="text-[16px] font-bold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.95)" }}>
                        {selected.display_name || selected.username}
                      </h2>
                      {selected.is_team_admin && <span className="nx-badge nx-badge-violet">ADMIN</span>}
                      {selected.is_team_moderator && !selected.is_team_admin && <span className="nx-badge nx-badge-cyan">MOD</span>}
                      {selected.is_banned && <span className="nx-badge" style={{ background: "rgba(239,68,68,0.1)", color: "#FCA5A5", border: "1px solid rgba(239,68,68,0.2)" }}>BANIDO</span>}
                    </div>
                    <p className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>@{selected.username}</p>
                  </div>
                </div>
              </div>

              {/* Stats */}
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                {[
                  { label: "Saldo Atual", value: `${(selected.coins_balance || 0).toLocaleString()} ✦`, color: "#F59E0B", rgb: "245,158,11" },
                  { label: "Total Ganho", value: `${(selected.total_coins_earned || 0).toLocaleString()} ✦`, color: "#10B981", rgb: "16,185,129" },
                  { label: "Compras", value: purchases.length, color: "#A78BFA", rgb: "167,139,250" },
                  { label: "Transações", value: transactions.length, color: "#67E8F9", rgb: "103,232,249" },
                ].map(({ label, value, color, rgb }) => (
                  <div key={label} className="p-3 rounded-2xl" style={{ background: `rgba(${rgb},0.06)`, border: `1px solid rgba(${rgb},0.15)` }}>
                    <div className="text-[10px] font-mono tracking-wider uppercase mb-1" style={{ color: "rgba(255,255,255,0.35)" }}>{label}</div>
                    <div className="text-[15px] font-bold font-mono" style={{ color }}>{value}</div>
                  </div>
                ))}
              </div>

              {/* ── Ações Diretas ── */}
              <div className="rounded-2xl p-4 space-y-3" style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}>
                <p className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.3)" }}>Ações Diretas</p>
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
                  {/* Coins */}
                  <button onClick={() => setModal({ type: "coins", user: selected })}
                    className="flex flex-col items-center gap-2 p-3 rounded-xl transition-all"
                    style={{ background: "rgba(245,158,11,0.06)", border: "1px solid rgba(245,158,11,0.15)" }}
                    onMouseEnter={e => (e.currentTarget.style.background = "rgba(245,158,11,0.12)")}
                    onMouseLeave={e => (e.currentTarget.style.background = "rgba(245,158,11,0.06)")}>
                    <Coins size={18} style={{ color: "#F59E0B" }} />
                    <span className="text-[11px] font-semibold" style={{ color: "#F59E0B", fontFamily: "'Space Grotesk', sans-serif" }}>Coins</span>
                  </button>

                  {/* Strike */}
                  <button onClick={() => setModal({ type: "strike", user: selected })}
                    className="flex flex-col items-center gap-2 p-3 rounded-xl transition-all"
                    style={{ background: "rgba(249,115,22,0.06)", border: "1px solid rgba(249,115,22,0.15)" }}
                    onMouseEnter={e => (e.currentTarget.style.background = "rgba(249,115,22,0.12)")}
                    onMouseLeave={e => (e.currentTarget.style.background = "rgba(249,115,22,0.06)")}>
                    <AlertTriangle size={18} style={{ color: "#F97316" }} />
                    <span className="text-[11px] font-semibold" style={{ color: "#F97316", fontFamily: "'Space Grotesk', sans-serif" }}>Strike</span>
                  </button>

                  {/* Cargo */}
                  <button onClick={() => setModal({ type: "role", user: selected })}
                    className="flex flex-col items-center gap-2 p-3 rounded-xl transition-all"
                    style={{ background: "rgba(167,139,250,0.06)", border: "1px solid rgba(167,139,250,0.15)" }}
                    onMouseEnter={e => (e.currentTarget.style.background = "rgba(167,139,250,0.12)")}
                    onMouseLeave={e => (e.currentTarget.style.background = "rgba(167,139,250,0.06)")}>
                    <Crown size={18} style={{ color: "#A78BFA" }} />
                    <span className="text-[11px] font-semibold" style={{ color: "#A78BFA", fontFamily: "'Space Grotesk', sans-serif" }}>Cargo</span>
                  </button>

                  {/* Banir/Desbanir */}
                  <button onClick={() => setModal({ type: "ban", user: selected })}
                    className="flex flex-col items-center gap-2 p-3 rounded-xl transition-all"
                    style={{
                      background: selected.is_banned ? "rgba(16,185,129,0.06)" : "rgba(239,68,68,0.06)",
                      border: `1px solid ${selected.is_banned ? "rgba(16,185,129,0.15)" : "rgba(239,68,68,0.15)"}`,
                    }}
                    onMouseEnter={e => (e.currentTarget.style.background = selected.is_banned ? "rgba(16,185,129,0.12)" : "rgba(239,68,68,0.12)")}
                    onMouseLeave={e => (e.currentTarget.style.background = selected.is_banned ? "rgba(16,185,129,0.06)" : "rgba(239,68,68,0.06)")}>
                    {selected.is_banned ? <UserCheck size={18} style={{ color: "#34D399" }} /> : <UserX size={18} style={{ color: "#FCA5A5" }} />}
                    <span className="text-[11px] font-semibold" style={{ color: selected.is_banned ? "#34D399" : "#FCA5A5", fontFamily: "'Space Grotesk', sans-serif" }}>
                      {selected.is_banned ? "Desbanir" : "Banir"}
                    </span>
                  </button>
                </div>
              </div>

              {/* Info adicional */}
              <div className="grid grid-cols-2 gap-3">
                <div className="p-3 rounded-2xl space-y-1.5" style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}>
                  <p className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.3)" }}>Conta</p>
                  <div className="flex items-center gap-2">
                    <Calendar size={11} style={{ color: "rgba(255,255,255,0.3)" }} />
                    <span className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.5)" }}>Criado em {new Date(selected.created_at).toLocaleDateString("pt-BR")}</span>
                  </div>
                  {selected.last_seen_at && (
                    <div className="flex items-center gap-2">
                      <Activity size={11} style={{ color: "rgba(255,255,255,0.3)" }} />
                      <span className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.5)" }}>Visto em {new Date(selected.last_seen_at).toLocaleDateString("pt-BR")}</span>
                    </div>
                  )}
                  <div className="flex items-center gap-2">
                    <Hash size={11} style={{ color: "rgba(255,255,255,0.3)" }} />
                    <span className="text-[11px] font-mono truncate" style={{ color: "rgba(255,255,255,0.3)" }}>{selected.id.slice(0, 16)}...</span>
                  </div>
                </div>
                <div className="p-3 rounded-2xl space-y-1.5" style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}>
                  <p className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.3)" }}>Permissões</p>
                  <div className="flex items-center gap-2">
                    <Crown size={11} style={{ color: selected.is_team_admin ? "#A78BFA" : "rgba(255,255,255,0.2)" }} />
                    <span className="text-[11px] font-mono" style={{ color: selected.is_team_admin ? "#A78BFA" : "rgba(255,255,255,0.3)" }}>Team Admin: {selected.is_team_admin ? "Sim" : "Não"}</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <Shield size={11} style={{ color: selected.is_team_moderator ? "#67E8F9" : "rgba(255,255,255,0.2)" }} />
                    <span className="text-[11px] font-mono" style={{ color: selected.is_team_moderator ? "#67E8F9" : "rgba(255,255,255,0.3)" }}>Moderador: {selected.is_team_moderator ? "Sim" : "Não"}</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <Ban size={11} style={{ color: selected.is_banned ? "#FCA5A5" : "rgba(255,255,255,0.2)" }} />
                    <span className="text-[11px] font-mono" style={{ color: selected.is_banned ? "#FCA5A5" : "rgba(255,255,255,0.3)" }}>Banido: {selected.is_banned ? "Sim" : "Não"}</span>
                  </div>
                </div>
              </div>

              {loadingDetail ? (
                <div className="space-y-2">{[...Array(4)].map((_, i) => <div key={i} className="h-12 rounded-xl" style={{ background: "rgba(255,255,255,0.03)" }} />)}</div>
              ) : (
                <>
                  {/* Purchases */}
                  <div className="rounded-2xl overflow-hidden" style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}>
                    <div className="px-4 py-3 flex items-center gap-2" style={{ borderBottom: "1px solid rgba(255,255,255,0.07)" }}>
                      <ShoppingBag size={13} style={{ color: "#A78BFA" }} />
                      <span className="text-[11px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.4)" }}>Compras ({purchases.length})</span>
                    </div>
                    {purchases.length === 0 ? (
                      <div className="py-8 text-center text-[12px] font-mono" style={{ color: "rgba(255,255,255,0.2)" }}>Nenhuma compra</div>
                    ) : (
                      <div className="overflow-x-auto">
                        <table className="w-full nx-table">
                          <thead><tr><th className="text-left">Item</th><th className="text-right">Preço</th><th className="text-right hidden sm:table-cell">Data</th></tr></thead>
                          <tbody>
                            {purchases.map(p => (
                              <tr key={p.id}>
                                <td><span style={{ color: "rgba(255,255,255,0.8)", fontFamily: "'Space Grotesk', sans-serif" }}>{p.item_name}</span></td>
                                <td className="text-right"><span className="font-mono" style={{ color: "#F59E0B" }}>{p.price_coins} ✦</span></td>
                                <td className="text-right hidden sm:table-cell"><span className="font-mono text-[11px]" style={{ color: "rgba(255,255,255,0.3)" }}>{new Date(p.purchased_at).toLocaleDateString("pt-BR")}</span></td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    )}
                  </div>

                  {/* Transactions */}
                  <div className="rounded-2xl overflow-hidden" style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}>
                    <div className="px-4 py-3 flex items-center gap-2" style={{ borderBottom: "1px solid rgba(255,255,255,0.07)" }}>
                      <Coins size={13} style={{ color: "#F59E0B" }} />
                      <span className="text-[11px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.4)" }}>Transações ({transactions.length})</span>
                    </div>
                    {transactions.length === 0 ? (
                      <div className="py-8 text-center text-[12px] font-mono" style={{ color: "rgba(255,255,255,0.2)" }}>Nenhuma transação</div>
                    ) : (
                      <div className="overflow-x-auto">
                        <table className="w-full nx-table">
                          <thead><tr><th className="text-left">Fonte</th><th className="text-right">Valor</th><th className="text-right hidden sm:table-cell">Data</th></tr></thead>
                          <tbody>
                            {transactions.map(t => (
                              <tr key={t.id}>
                                <td>
                                  <span className="text-[11px] font-mono px-2 py-0.5 rounded-lg"
                                    style={{ background: t.amount > 0 ? "rgba(16,185,129,0.1)" : "rgba(239,68,68,0.1)", color: t.amount > 0 ? "#34D399" : "#FCA5A5" }}>
                                    {t.source}
                                  </span>
                                </td>
                                <td className="text-right">
                                  <span className="font-mono font-bold" style={{ color: t.amount > 0 ? "#34D399" : "#FCA5A5" }}>
                                    {t.amount > 0 ? "+" : ""}{t.amount} ✦
                                  </span>
                                </td>
                                <td className="text-right hidden sm:table-cell"><span className="font-mono text-[11px]" style={{ color: "rgba(255,255,255,0.3)" }}>{new Date(t.created_at).toLocaleDateString("pt-BR")}</span></td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    )}
                  </div>
                </>
              )}
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </>
  );
}
