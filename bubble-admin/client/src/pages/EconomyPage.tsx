import { useState, useEffect, useCallback } from "react";
import { motion } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { useAuth } from "@/contexts/AuthContext";
import { toast } from "sonner";
import {
  Coins, TrendingUp, TrendingDown, ArrowUpRight, ArrowDownRight,
  RefreshCw, Search, ShoppingBag, Gift, ArrowLeftRight, Zap,
  DollarSign, BarChart3, Users, Calendar, Filter, ChevronDown,
  Ticket, Heart, Star,
} from "lucide-react";

// ─── Tipos ────────────────────────────────────────────────────────────────────
type CoinTx = {
  id: string;
  user_id: string;
  amount: number;
  source: string;
  description: string | null;
  created_at: string;
  profile?: { nickname: string; amino_id: string; avatar_url: string | null };
};

type IapReceipt = {
  id: string;
  user_id: string;
  platform: string;
  store_product_id: string;
  amount_cents: number;
  currency: string;
  coins_credited: number;
  is_validated: boolean;
  created_at: string;
  profile?: { nickname: string; amino_id: string };
};

type Tip = {
  id: string;
  sender_id: string;
  receiver_id: string;
  amount: number;
  created_at: string;
  sender?: { nickname: string; amino_id: string };
  receiver?: { nickname: string; amino_id: string };
};

type LotteryLog = {
  id: string;
  user_id: string;
  award_type: string;
  coins_won: number;
  played_at: string;
  profile?: { nickname: string; amino_id: string };
};

type EconomyStats = {
  totalCoinsInCirculation: number;
  totalCoinsSpent: number;
  totalCoinsEarned: number;
  totalIapRevenueCents: number;
  totalTips: number;
  totalLotteryCoins: number;
  totalCheckinCoins: number;
  totalTransactions: number;
  activeUsers: number;
};

const SOURCE_CONFIG: Record<string, { label: string; color: string; icon: React.FC<{ size?: number; style?: React.CSSProperties }> }> = {
  purchase:           { label: "Compra na Loja",    color: "#EC4899", icon: ShoppingBag },
  checkin:            { label: "Check-in Diário",   color: "#22C55E", icon: Calendar },
  transfer_sent:      { label: "Transferência (Saída)", color: "#EF4444", icon: ArrowDownRight },
  transfer_received:  { label: "Transferência (Entrada)", color: "#22C55E", icon: ArrowUpRight },
  tip_sent:           { label: "Gorjeta Enviada",   color: "#F97316", icon: Heart },
  tip_received:       { label: "Gorjeta Recebida",  color: "#A855F7", icon: Heart },
  lottery:            { label: "Loteria",            color: "#F59E0B", icon: Ticket },
  admin_grant:        { label: "Concessão Admin",    color: "#60A5FA", icon: Zap },
  iap:                { label: "Compra Real (IAP)",  color: "#34D399", icon: DollarSign },
  achievement:        { label: "Conquista",          color: "#FBBF24", icon: Star },
  refund:             { label: "Reembolso",          color: "#94A3B8", icon: ArrowUpRight },
};

function getSourceConfig(source: string) {
  return SOURCE_CONFIG[source] ?? { label: source, color: "#94A3B8", icon: Coins };
}

function formatCurrency(cents: number, currency = "BRL") {
  return new Intl.NumberFormat("pt-BR", { style: "currency", currency }).format(cents / 100);
}

function formatCoins(n: number) {
  if (Math.abs(n) >= 1000000) return `${(n / 1000000).toFixed(1)}M`;
  if (Math.abs(n) >= 1000) return `${(n / 1000).toFixed(1)}K`;
  return n.toString();
}

function timeAgo(date: string) {
  const diff = Date.now() - new Date(date).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 60) return `${mins}min atrás`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h atrás`;
  const days = Math.floor(hrs / 24);
  return `${days}d atrás`;
}

const fadeUp = {
  hidden: { opacity: 0, y: 8 },
  show: (i: number) => ({ opacity: 1, y: 0, transition: { delay: i * 0.03, duration: 0.2 } }),
};

// ─── Componente: Stat Card ────────────────────────────────────────────────────
function StatCard({
  label, value, sub, icon: Icon, color, trend, index,
}: {
  label: string; value: string; sub?: string; icon: React.FC<{ size?: number; style?: React.CSSProperties }>;
  color: string; trend?: "up" | "down" | "neutral"; index: number;
}) {
  return (
    <motion.div
      custom={index}
      variants={fadeUp}
      initial="hidden"
      animate="show"
      className="rounded-xl p-4"
      style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.06)" }}
    >
      <div className="flex items-start justify-between mb-3">
        <div className="w-9 h-9 rounded-lg flex items-center justify-center" style={{ background: `${color}22` }}>
          <Icon size={16} style={{ color }} />
        </div>
        {trend && (
          <div
            className="flex items-center gap-1 text-[10px] font-mono px-2 py-0.5 rounded-full"
            style={{
              background: trend === "up" ? "rgba(34,197,94,0.12)" : trend === "down" ? "rgba(239,68,68,0.12)" : "rgba(255,255,255,0.05)",
              color: trend === "up" ? "#22C55E" : trend === "down" ? "#EF4444" : "rgba(255,255,255,0.3)",
            }}
          >
            {trend === "up" ? <TrendingUp size={9} /> : trend === "down" ? <TrendingDown size={9} /> : null}
          </div>
        )}
      </div>
      <p className="text-2xl font-bold text-white leading-none mb-1">{value}</p>
      <p className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.3)" }}>{label}</p>
      {sub && <p className="text-[10px] mt-1" style={{ color: "rgba(255,255,255,0.2)" }}>{sub}</p>}
    </motion.div>
  );
}

// ─── Página Principal ─────────────────────────────────────────────────────────
export default function EconomyPage() {
  const { isCoFounderOrAbove } = useAuth();
  const [tab, setTab] = useState<"overview" | "transactions" | "iap" | "tips" | "lottery">("overview");
  const [stats, setStats] = useState<EconomyStats | null>(null);
  const [transactions, setTransactions] = useState<CoinTx[]>([]);
  const [iapReceipts, setIapReceipts] = useState<IapReceipt[]>([]);
  const [tips, setTips] = useState<Tip[]>([]);
  const [lotteryLogs, setLotteryLogs] = useState<LotteryLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [sourceFilter, setSourceFilter] = useState("all");

  const loadAll = useCallback(async () => {
    setLoading(true);
    try {
      // Transactions via RPC (bypassa RLS)
      const { data: txData, error: txErr } = await supabase.rpc("admin_get_coin_transactions", {
        p_limit: 200, p_offset: 0,
      });
      if (txErr) console.error("Erro transactions:", txErr.message);

      const txList = (txData as CoinTx[]) ?? [];
      setTransactions(txList);

      const earned = txList.filter((t) => t.amount > 0).reduce((s, t) => s + t.amount, 0);
      const spent = Math.abs(txList.filter((t) => t.amount < 0).reduce((s, t) => s + t.amount, 0));
      const checkinCoins = txList.filter((t) => t.source === "checkin").reduce((s, t) => s + t.amount, 0);
      const lotteryCoins = txList.filter((t) => t.source === "lottery").reduce((s, t) => s + t.amount, 0);
      const uniqueUsers = new Set(txList.map((t) => t.user_id)).size;

      // Lottery via RPC
      const { data: lotteryResult } = await supabase.rpc("admin_get_lottery_stats");
      const lotteryLogs = (lotteryResult as { recent_logs?: LotteryLog[] })?.recent_logs ?? [];
      setLotteryLogs(lotteryLogs);

      // IAP e Tips — sem RPC dedicada ainda, tentativa direta
      const { data: iapData } = await supabase
        .from("iap_receipts")
        .select("id, user_id, platform, store_product_id, amount_cents, currency, coins_credited, is_validated, created_at")
        .order("created_at", { ascending: false })
        .limit(100);
      const iapList = (iapData as IapReceipt[]) ?? [];
      setIapReceipts(iapList);
      const iapRevenue = iapList.filter((r) => r.is_validated).reduce((s, r) => s + r.amount_cents, 0);

      const { data: tipsData } = await supabase
        .from("tips")
        .select("id, sender_id, receiver_id, amount, created_at")
        .order("created_at", { ascending: false })
        .limit(100);
      const tipsList = (tipsData as Tip[]) ?? [];
      setTips(tipsList);
      const totalTips = tipsList.reduce((s, t) => s + t.amount, 0);

      setStats({
        totalCoinsInCirculation: earned - spent,
        totalCoinsSpent: spent,
        totalCoinsEarned: earned,
        totalIapRevenueCents: iapRevenue,
        totalTips,
        totalLotteryCoins: lotteryCoins,
        totalCheckinCoins: checkinCoins,
        totalTransactions: txList.length,
        activeUsers: uniqueUsers,
      });
    } catch (e: unknown) {
      console.error("Erro ao carregar dados de economia:", e);
      toast.error("Erro ao carregar dados de economia.");
    }
    setLoading(false);
  }, []);

  useEffect(() => { loadAll(); }, [loadAll]);

  // Fontes únicas para o filtro
  const uniqueSources = [...new Set(transactions.map((t) => t.source))];

  const filteredTx = transactions.filter((t) => {
    const matchSearch =
      !search ||
      t.profile?.nickname.toLowerCase().includes(search.toLowerCase()) ||
      t.profile?.amino_id.toLowerCase().includes(search.toLowerCase()) ||
      (t.description ?? "").toLowerCase().includes(search.toLowerCase());
    const matchSource = sourceFilter === "all" || t.source === sourceFilter;
    return matchSearch && matchSource;
  });

  // Distribuição por fonte
  const sourceDistribution = uniqueSources.map((src) => {
    const txs = transactions.filter((t) => t.source === src);
    const total = txs.reduce((s, t) => s + Math.abs(t.amount), 0);
    const cfg = getSourceConfig(src);
    return { source: src, label: cfg.label, color: cfg.color, count: txs.length, total };
  }).sort((a, b) => b.total - a.total);

  const maxSourceTotal = Math.max(...sourceDistribution.map((s) => s.total), 1);

  if (!isCoFounderOrAbove) {
    return (
      <div className="flex items-center justify-center h-64">
        <p style={{ color: "rgba(255,255,255,0.3)" }}>Acesso restrito a Co-Founder e acima.</p>
      </div>
    );
  }

  return (
    <div className="p-6 space-y-6 max-w-5xl mx-auto">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <div className="flex items-center gap-3 mb-1">
            <div
              className="w-9 h-9 rounded-xl flex items-center justify-center"
              style={{ background: "rgba(34,197,94,0.2)", border: "1px solid rgba(34,197,94,0.4)" }}
            >
              <BarChart3 size={18} style={{ color: "#22C55E" }} />
            </div>
            <h1 className="text-xl font-bold text-white">Economy Dashboard</h1>
          </div>
          <p className="text-sm ml-12" style={{ color: "rgba(255,255,255,0.35)" }}>
            Fluxo de moedas, receita IAP, gorjetas e loterias da plataforma
          </p>
        </div>
        <button
          onClick={loadAll}
          className="w-9 h-9 rounded-xl flex items-center justify-center"
          style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}
        >
          <RefreshCw size={14} style={{ color: "rgba(255,255,255,0.4)" }} className={loading ? "animate-spin" : ""} />
        </button>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 rounded-xl p-1 w-fit" style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}>
        {([
          { id: "overview", label: "Visão Geral" },
          { id: "transactions", label: "Transações" },
          { id: "iap", label: "IAP" },
          { id: "tips", label: "Gorjetas" },
          { id: "lottery", label: "Loteria" },
        ] as const).map((t) => (
          <button
            key={t.id}
            onClick={() => setTab(t.id)}
            className="px-3 py-1.5 rounded-lg text-xs font-medium transition-all"
            style={{
              background: tab === t.id ? "rgba(34,197,94,0.2)" : "transparent",
              color: tab === t.id ? "#22C55E" : "rgba(255,255,255,0.35)",
              border: tab === t.id ? "1px solid rgba(34,197,94,0.3)" : "1px solid transparent",
            }}
          >
            {t.label}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-40">
          <RefreshCw size={20} className="animate-spin" style={{ color: "rgba(255,255,255,0.2)" }} />
        </div>
      ) : tab === "overview" && stats ? (
        <div className="space-y-6">
          {/* Stats Grid */}
          <div className="grid grid-cols-4 gap-3">
            <StatCard index={0} label="Em Circulação" value={formatCoins(stats.totalCoinsInCirculation)} icon={Coins} color="#22C55E" trend="up" />
            <StatCard index={1} label="Total Ganho" value={formatCoins(stats.totalCoinsEarned)} icon={TrendingUp} color="#60A5FA" />
            <StatCard index={2} label="Total Gasto" value={formatCoins(stats.totalCoinsSpent)} icon={TrendingDown} color="#EF4444" />
            <StatCard index={3} label="Receita IAP" value={formatCurrency(stats.totalIapRevenueCents)} icon={DollarSign} color="#34D399" trend="up" />
          </div>
          <div className="grid grid-cols-4 gap-3">
            <StatCard index={4} label="Check-ins" value={formatCoins(stats.totalCheckinCoins)} sub="moedas distribuídas" icon={Calendar} color="#F59E0B" />
            <StatCard index={5} label="Loterias" value={formatCoins(stats.totalLotteryCoins)} sub="moedas ganhas" icon={Ticket} color="#A855F7" />
            <StatCard index={6} label="Gorjetas" value={formatCoins(stats.totalTips)} sub="moedas trocadas" icon={Heart} color="#F97316" />
            <StatCard index={7} label="Usuários Ativos" value={stats.activeUsers.toString()} sub="com transações" icon={Users} color="#67E8F9" />
          </div>

          {/* Distribuição por fonte */}
          <div
            className="rounded-xl p-5"
            style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.06)" }}
          >
            <h3 className="text-sm font-semibold text-white mb-4">Distribuição por Fonte</h3>
            <div className="space-y-3">
              {sourceDistribution.map((s) => {
                const Ic = s.icon as React.FC<{ size?: number; style?: React.CSSProperties }>;
                return (
                  <div key={s.source} className="flex items-center gap-3">
                    <div className="w-6 h-6 rounded-md flex items-center justify-center flex-shrink-0" style={{ background: `${s.color}22` }}>
                      <Ic size={12} style={{ color: s.color }} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-xs text-white">{s.label}</span>
                        <div className="flex items-center gap-3">
                          <span className="text-[10px]" style={{ color: "rgba(255,255,255,0.3)" }}>{s.count} txs</span>
                          <span className="text-xs font-mono font-bold" style={{ color: s.color }}>{formatCoins(s.total)}</span>
                        </div>
                      </div>
                      <div className="h-1 rounded-full overflow-hidden" style={{ background: "rgba(255,255,255,0.06)" }}>
                        <motion.div
                          initial={{ width: 0 }}
                          animate={{ width: `${(s.total / maxSourceTotal) * 100}%` }}
                          transition={{ duration: 0.6, delay: 0.1 }}
                          className="h-full rounded-full"
                          style={{ background: s.color }}
                        />
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      ) : tab === "transactions" ? (
        <div className="space-y-3">
          {/* Filtros */}
          <div className="flex items-center gap-3">
            <div
              className="flex-1 flex items-center gap-2 rounded-xl px-3 py-2"
              style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}
            >
              <Search size={14} style={{ color: "rgba(255,255,255,0.3)" }} />
              <input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Buscar por usuário ou descrição..."
                className="flex-1 bg-transparent text-sm text-white placeholder-white/25 outline-none"
              />
            </div>
            <div className="relative">
              <select
                value={sourceFilter}
                onChange={(e) => setSourceFilter(e.target.value)}
                className="rounded-xl px-3 py-2 text-sm text-white outline-none appearance-none pr-8"
                style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}
              >
                <option value="all" style={{ background: "#1a1a2e" }}>Todas as fontes</option>
                {uniqueSources.map((s) => (
                  <option key={s} value={s} style={{ background: "#1a1a2e" }}>
                    {getSourceConfig(s).label}
                  </option>
                ))}
              </select>
              <ChevronDown size={12} className="absolute right-2.5 top-1/2 -translate-y-1/2 pointer-events-none" style={{ color: "rgba(255,255,255,0.3)" }} />
            </div>
          </div>

          {/* Lista */}
          <div className="space-y-1.5">
            {filteredTx.map((tx, i) => {
              const cfg = getSourceConfig(tx.source);
              const Ic = cfg.icon;
              return (
                <motion.div
                  key={tx.id}
                  custom={i}
                  variants={fadeUp}
                  initial="hidden"
                  animate="show"
                  className="flex items-center gap-3 p-3 rounded-xl"
                  style={{ background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.05)" }}
                >
                  <div className="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0" style={{ background: `${cfg.color}22` }}>
                    <Ic size={14} style={{ color: cfg.color }} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-medium text-white truncate">
                        {tx.profile?.nickname ?? "Usuário"}
                      </span>
                      <span className="text-[10px]" style={{ color: "rgba(255,255,255,0.3)" }}>
                        @{tx.profile?.amino_id ?? "—"}
                      </span>
                    </div>
                    <p className="text-[11px] truncate" style={{ color: "rgba(255,255,255,0.35)" }}>
                      {cfg.label}{tx.description ? ` · ${tx.description}` : ""}
                    </p>
                  </div>
                  <div className="text-right flex-shrink-0">
                    <p
                      className="text-sm font-bold font-mono"
                      style={{ color: tx.amount > 0 ? "#22C55E" : "#EF4444" }}
                    >
                      {tx.amount > 0 ? "+" : ""}{formatCoins(tx.amount)}
                    </p>
                    <p className="text-[10px]" style={{ color: "rgba(255,255,255,0.2)" }}>
                      {timeAgo(tx.created_at)}
                    </p>
                  </div>
                </motion.div>
              );
            })}
          </div>
        </div>
      ) : tab === "iap" ? (
        <div className="space-y-3">
          <div
            className="rounded-xl p-4 flex items-center gap-4"
            style={{ background: "rgba(34,197,94,0.06)", border: "1px solid rgba(34,197,94,0.2)" }}
          >
            <DollarSign size={20} style={{ color: "#22C55E" }} />
            <div>
              <p className="text-lg font-bold text-white">
                {formatCurrency(iapReceipts.filter((r) => r.is_validated).reduce((s, r) => s + r.amount_cents, 0))}
              </p>
              <p className="text-xs" style={{ color: "rgba(255,255,255,0.4)" }}>
                Receita total validada · {iapReceipts.filter((r) => r.is_validated).length} compras
              </p>
            </div>
          </div>
          <div className="space-y-1.5">
            {iapReceipts.map((r, i) => (
              <motion.div
                key={r.id}
                custom={i}
                variants={fadeUp}
                initial="hidden"
                animate="show"
                className="flex items-center gap-3 p-3 rounded-xl"
                style={{ background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.05)" }}
              >
                <div
                  className="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0"
                  style={{ background: r.platform === "ios" ? "rgba(0,122,255,0.15)" : "rgba(52,211,153,0.15)" }}
                >
                  <DollarSign size={14} style={{ color: r.platform === "ios" ? "#007AFF" : "#34D399" }} />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-medium text-white truncate">{r.profile?.nickname ?? "Usuário"}</span>
                    <span
                      className="text-[9px] font-mono px-1.5 py-0.5 rounded-full"
                      style={{
                        background: r.platform === "ios" ? "rgba(0,122,255,0.15)" : "rgba(52,211,153,0.15)",
                        color: r.platform === "ios" ? "#007AFF" : "#34D399",
                      }}
                    >
                      {r.platform?.toUpperCase()}
                    </span>
                    {!r.is_validated && (
                      <span className="text-[9px] font-mono px-1.5 py-0.5 rounded-full" style={{ background: "rgba(239,68,68,0.15)", color: "#EF4444" }}>
                        NÃO VALIDADO
                      </span>
                    )}
                  </div>
                  <p className="text-[11px]" style={{ color: "rgba(255,255,255,0.35)" }}>
                    {r.store_product_id} · +{formatCoins(r.coins_credited)} coins
                  </p>
                </div>
                <div className="text-right flex-shrink-0">
                  <p className="text-sm font-bold font-mono" style={{ color: "#22C55E" }}>
                    {formatCurrency(r.amount_cents, r.currency)}
                  </p>
                  <p className="text-[10px]" style={{ color: "rgba(255,255,255,0.2)" }}>{timeAgo(r.created_at)}</p>
                </div>
              </motion.div>
            ))}
            {iapReceipts.length === 0 && (
              <div className="rounded-xl p-10 text-center" style={{ background: "rgba(255,255,255,0.02)", border: "1px dashed rgba(255,255,255,0.08)" }}>
                <p className="text-sm" style={{ color: "rgba(255,255,255,0.25)" }}>Nenhuma compra IAP registrada.</p>
              </div>
            )}
          </div>
        </div>
      ) : tab === "tips" ? (
        <div className="space-y-1.5">
          {tips.map((tip, i) => (
            <motion.div
              key={tip.id}
              custom={i}
              variants={fadeUp}
              initial="hidden"
              animate="show"
              className="flex items-center gap-3 p-3 rounded-xl"
              style={{ background: "rgba(249,115,22,0.04)", border: "1px solid rgba(249,115,22,0.12)" }}
            >
              <div className="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0" style={{ background: "rgba(249,115,22,0.15)" }}>
                <Heart size={14} style={{ color: "#F97316" }} />
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-1.5 text-sm">
                  <span className="font-medium text-white">{tip.sender?.nickname ?? "?"}</span>
                  <ArrowLeftRight size={11} style={{ color: "rgba(255,255,255,0.3)" }} />
                  <span className="font-medium text-white">{tip.receiver?.nickname ?? "?"}</span>
                </div>
                <p className="text-[10px]" style={{ color: "rgba(255,255,255,0.3)" }}>
                  @{tip.sender?.amino_id} → @{tip.receiver?.amino_id}
                </p>
              </div>
              <div className="text-right flex-shrink-0">
                <p className="text-sm font-bold font-mono" style={{ color: "#F97316" }}>+{formatCoins(tip.amount)}</p>
                <p className="text-[10px]" style={{ color: "rgba(255,255,255,0.2)" }}>{timeAgo(tip.created_at)}</p>
              </div>
            </motion.div>
          ))}
          {tips.length === 0 && (
            <div className="rounded-xl p-10 text-center" style={{ background: "rgba(255,255,255,0.02)", border: "1px dashed rgba(255,255,255,0.08)" }}>
              <p className="text-sm" style={{ color: "rgba(255,255,255,0.25)" }}>Nenhuma gorjeta registrada.</p>
            </div>
          )}
        </div>
      ) : tab === "lottery" ? (
        <div className="space-y-1.5">
          {lotteryLogs.map((log, i) => (
            <motion.div
              key={log.id}
              custom={i}
              variants={fadeUp}
              initial="hidden"
              animate="show"
              className="flex items-center gap-3 p-3 rounded-xl"
              style={{ background: "rgba(245,158,11,0.04)", border: "1px solid rgba(245,158,11,0.12)" }}
            >
              <div className="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0" style={{ background: "rgba(245,158,11,0.15)" }}>
                <Ticket size={14} style={{ color: "#F59E0B" }} />
              </div>
              <div className="flex-1 min-w-0">
                <span className="text-sm font-medium text-white">{log.profile?.nickname ?? "Usuário"}</span>
                <p className="text-[11px]" style={{ color: "rgba(255,255,255,0.35)" }}>
                  @{log.profile?.amino_id} · {log.award_type}
                </p>
              </div>
              <div className="text-right flex-shrink-0">
                <p className="text-sm font-bold font-mono" style={{ color: "#F59E0B" }}>+{formatCoins(log.coins_won)}</p>
                <p className="text-[10px]" style={{ color: "rgba(255,255,255,0.2)" }}>{timeAgo(log.played_at)}</p>
              </div>
            </motion.div>
          ))}
          {lotteryLogs.length === 0 && (
            <div className="rounded-xl p-10 text-center" style={{ background: "rgba(255,255,255,0.02)", border: "1px dashed rgba(255,255,255,0.08)" }}>
              <p className="text-sm" style={{ color: "rgba(255,255,255,0.25)" }}>Nenhuma jogada de loteria registrada.</p>
            </div>
          )}
        </div>
      ) : null}
    </div>
  );
}
