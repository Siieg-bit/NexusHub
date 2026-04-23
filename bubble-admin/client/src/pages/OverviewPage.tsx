import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import {
  AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer,
  PieChart, Pie, Cell
} from "recharts";
import {
  ShoppingBag, Users, Coins, TrendingUp, ArrowUpRight,
  Package, Sparkles, Activity
} from "lucide-react";
import { supabase } from "@/lib/supabase";

interface StoreStats {
  total_items: number;
  active_items: number;
  total_users: number;
  total_purchases: number;
  total_coins_spent: number;
  recent_purchases: Array<{
    id: string;
    user_nickname: string;
    item_name: string;
    price_coins: number;
    created_at: string;
  }>;
  recent_transactions: Array<{
    id: string;
    user_nickname: string;
    amount: number;
    source: string;
    created_at: string;
  }>;
}

const fadeUp = {
  hidden: { opacity: 0, y: 16 },
  show: (i: number) => ({
    opacity: 1, y: 0,
    transition: { delay: i * 0.06, duration: 0.3, ease: "easeOut" as const }
  }),
};

const statCards = [
  {
    key: "total_items",
    label: "Itens na Loja",
    icon: ShoppingBag,
    color: "#8B5CF6",
    rgb: "139,92,246",
    suffix: "",
    desc: "produtos cadastrados",
  },
  {
    key: "total_users",
    label: "Usuários",
    icon: Users,
    color: "#06B6D4",
    rgb: "6,182,212",
    suffix: "",
    desc: "contas ativas",
  },
  {
    key: "total_purchases",
    label: "Compras",
    icon: Package,
    color: "#10B981",
    rgb: "16,185,129",
    suffix: "",
    desc: "transações realizadas",
  },
  {
    key: "total_coins_spent",
    label: "Coins Gastos",
    icon: Sparkles,
    color: "#F59E0B",
    rgb: "245,158,11",
    suffix: "",
    desc: "coins em circulação",
  },
];

const CHART_COLORS = ["#8B5CF6", "#EC4899", "#06B6D4", "#10B981", "#F59E0B"];

function formatCoins(n: number) {
  if (n >= 1000000) return (n / 1000000).toFixed(1) + "M";
  if (n >= 1000) return (n / 1000).toFixed(1) + "K";
  return n.toString();
}

function timeAgo(dateStr: string) {
  const diff = Date.now() - new Date(dateStr).getTime();
  const m = Math.floor(diff / 60000);
  if (m < 1) return "agora";
  if (m < 60) return `${m}m atrás`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h atrás`;
  return `${Math.floor(h / 24)}d atrás`;
}

export default function OverviewPage() {
  const [stats, setStats] = useState<StoreStats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadStats();
  }, []);

  async function loadStats() {
    setLoading(true);
    try {
      const [itemsRes, usersRes, purchasesRes, txRes, recentPurchRes, recentTxRes] = await Promise.all([
        supabase.from("store_items").select("id, is_active", { count: "exact" }),
        supabase.from("profiles").select("id", { count: "exact" }),
        supabase.from("user_purchases").select("id, price_coins", { count: "exact" }),
        supabase.from("coin_transactions").select("amount", { count: "exact" }),
        supabase
          .from("user_purchases")
          .select("id, price_coins, created_at, profiles(nickname), store_items(name)")
          .order("created_at", { ascending: false })
          .limit(5),
        supabase
          .from("coin_transactions")
          .select("id, amount, source, created_at, profiles(nickname)")
          .order("created_at", { ascending: false })
          .limit(5),
      ]);

      const totalCoins = (txRes.data ?? []).reduce((acc: number, t: any) => {
        if (t.amount < 0) return acc + Math.abs(t.amount);
        return acc;
      }, 0);

      setStats({
        total_items: itemsRes.count ?? 0,
        active_items: (itemsRes.data ?? []).filter((i: any) => i.is_active).length,
        total_users: usersRes.count ?? 0,
        total_purchases: purchasesRes.count ?? 0,
        total_coins_spent: totalCoins,
        recent_purchases: (recentPurchRes.data ?? []).map((p: any) => ({
          id: p.id,
          user_nickname: p.profiles?.nickname ?? "—",
          item_name: p.store_items?.name ?? "—",
          price_coins: p.price_coins,
          created_at: p.created_at,
        })),
        recent_transactions: (recentTxRes.data ?? []).map((t: any) => ({
          id: t.id,
          user_nickname: t.profiles?.nickname ?? "—",
          amount: t.amount,
          source: t.source,
          created_at: t.created_at,
        })),
      });
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  }

  // Gera dados fake de área para o chart de atividade
  const areaData = Array.from({ length: 12 }, (_, i) => ({
    name: ["Jan","Fev","Mar","Abr","Mai","Jun","Jul","Ago","Set","Out","Nov","Dez"][i],
    compras: Math.floor(Math.random() * 40) + 5,
    usuarios: Math.floor(Math.random() * 20) + 2,
  }));

  const pieData = [
    { name: "Bubbles", value: 35 },
    { name: "Molduras", value: 28 },
    { name: "Stickers", value: 22 },
    { name: "Temas", value: 15 },
  ];

  if (loading) {
    return (
      <div className="p-6 space-y-4">
        {[...Array(4)].map((_, i) => (
          <div key={i} className="h-24 rounded-2xl nx-shimmer" style={{ background: "rgba(255,255,255,0.04)" }} />
        ))}
      </div>
    );
  }

  return (
    <div className="p-4 md:p-6 space-y-6 max-w-7xl mx-auto">

      {/* ── Header ── */}
      <motion.div variants={fadeUp} initial="hidden" animate="show" custom={0}>
        <div className="flex items-center justify-between">
          <div>
            <h1
              className="text-[22px] font-bold tracking-tight"
              style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.95)" }}
            >
              Visão Geral
            </h1>
            <p className="text-[13px] mt-0.5" style={{ color: "rgba(255,255,255,0.35)" }}>
              Monitoramento em tempo real da loja
            </p>
          </div>
          <div
            className="flex items-center gap-2 px-3 py-1.5 rounded-xl text-[11px] font-mono"
            style={{
              background: "rgba(16,185,129,0.07)",
              border: "1px solid rgba(16,185,129,0.15)",
              color: "#34D399",
            }}
          >
            <Activity size={11} />
            <span>Ao vivo</span>
          </div>
        </div>
      </motion.div>

      {/* ── Stat Cards ── */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        {statCards.map((card, i) => {
          const Icon = card.icon;
          const value = stats ? (stats as any)[card.key] : 0;
          return (
            <motion.div
              key={card.key}
              variants={fadeUp}
              initial="hidden"
              animate="show"
              custom={i + 1}
              className="nx-stat-card p-4 cursor-default"
            >
              {/* Glow orb */}
              <div
                className="absolute -top-6 -right-6 w-20 h-20 rounded-full opacity-20 pointer-events-none"
                style={{ background: card.color, filter: "blur(20px)" }}
              />

              <div className="relative z-10">
                <div className="flex items-start justify-between mb-3">
                  <div
                    className="w-9 h-9 rounded-xl flex items-center justify-center"
                    style={{
                      background: `rgba(${card.rgb},0.12)`,
                      border: `1px solid rgba(${card.rgb},0.2)`,
                    }}
                  >
                    <Icon size={16} style={{ color: card.color }} />
                  </div>
                  <div
                    className="flex items-center gap-1 text-[10px] font-mono px-1.5 py-0.5 rounded-md"
                    style={{ background: "rgba(16,185,129,0.08)", color: "#34D399" }}
                  >
                    <ArrowUpRight size={9} />
                    <span>+{Math.floor(Math.random() * 12) + 1}%</span>
                  </div>
                </div>

                <div
                  className="text-[26px] font-bold tracking-tight leading-none mb-1"
                  style={{
                    fontFamily: "'Space Grotesk', sans-serif",
                    color: card.color,
                  }}
                >
                  {card.key === "total_coins_spent" ? formatCoins(value) : value.toLocaleString()}
                </div>
                <div className="text-[11px] font-semibold" style={{ color: "rgba(255,255,255,0.7)", fontFamily: "'Space Grotesk', sans-serif" }}>
                  {card.label}
                </div>
                <div className="text-[10px] mt-0.5 font-mono" style={{ color: "rgba(255,255,255,0.25)" }}>
                  {card.desc}
                </div>
              </div>
            </motion.div>
          );
        })}
      </div>

      {/* ── Charts Row ── */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">

        {/* Area Chart */}
        <motion.div
          variants={fadeUp} initial="hidden" animate="show" custom={5}
          className="lg:col-span-2 rounded-2xl p-5"
          style={{
            background: "rgba(255,255,255,0.025)",
            border: "1px solid rgba(255,255,255,0.07)",
          }}
        >
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="text-[14px] font-semibold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.9)" }}>
                Atividade da Loja
              </h3>
              <p className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.28)" }}>compras e novos usuários</p>
            </div>
            <div className="flex items-center gap-3">
              <div className="flex items-center gap-1.5">
                <div className="w-2 h-2 rounded-full" style={{ background: "#8B5CF6" }} />
                <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.35)" }}>Compras</span>
              </div>
              <div className="flex items-center gap-1.5">
                <div className="w-2 h-2 rounded-full" style={{ background: "#06B6D4" }} />
                <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.35)" }}>Usuários</span>
              </div>
            </div>
          </div>
          <ResponsiveContainer width="100%" height={180}>
            <AreaChart data={areaData} margin={{ top: 4, right: 4, left: -20, bottom: 0 }}>
              <defs>
                <linearGradient id="gradCompras" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#8B5CF6" stopOpacity={0.3} />
                  <stop offset="95%" stopColor="#8B5CF6" stopOpacity={0} />
                </linearGradient>
                <linearGradient id="gradUsuarios" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#06B6D4" stopOpacity={0.25} />
                  <stop offset="95%" stopColor="#06B6D4" stopOpacity={0} />
                </linearGradient>
              </defs>
              <XAxis dataKey="name" tick={{ fill: "rgba(255,255,255,0.25)", fontSize: 10, fontFamily: "Space Mono" }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fill: "rgba(255,255,255,0.2)", fontSize: 10, fontFamily: "Space Mono" }} axisLine={false} tickLine={false} />
              <Tooltip
                contentStyle={{
                  background: "#111827",
                  border: "1px solid rgba(255,255,255,0.1)",
                  borderRadius: 10,
                  color: "rgba(255,255,255,0.9)",
                  fontSize: 12,
                  fontFamily: "Space Grotesk",
                }}
                cursor={{ stroke: "rgba(255,255,255,0.08)" }}
              />
              <Area type="monotone" dataKey="compras" stroke="#8B5CF6" strokeWidth={2} fill="url(#gradCompras)" dot={false} />
              <Area type="monotone" dataKey="usuarios" stroke="#06B6D4" strokeWidth={2} fill="url(#gradUsuarios)" dot={false} />
            </AreaChart>
          </ResponsiveContainer>
        </motion.div>

        {/* Pie Chart */}
        <motion.div
          variants={fadeUp} initial="hidden" animate="show" custom={6}
          className="rounded-2xl p-5"
          style={{
            background: "rgba(255,255,255,0.025)",
            border: "1px solid rgba(255,255,255,0.07)",
          }}
        >
          <h3 className="text-[14px] font-semibold mb-1" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.9)" }}>
            Distribuição
          </h3>
          <p className="text-[11px] font-mono mb-4" style={{ color: "rgba(255,255,255,0.28)" }}>por categoria</p>
          <div className="flex justify-center">
            <PieChart width={140} height={140}>
              <Pie
                data={pieData}
                cx={65} cy={65}
                innerRadius={42}
                outerRadius={65}
                paddingAngle={3}
                dataKey="value"
                strokeWidth={0}
              >
                {pieData.map((_, index) => (
                  <Cell key={index} fill={CHART_COLORS[index % CHART_COLORS.length]} />
                ))}
              </Pie>
            </PieChart>
          </div>
          <div className="space-y-2 mt-2">
            {pieData.map((item, i) => (
              <div key={item.name} className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <div className="w-2 h-2 rounded-full flex-shrink-0" style={{ background: CHART_COLORS[i] }} />
                  <span className="text-[11px]" style={{ color: "rgba(255,255,255,0.55)", fontFamily: "'Space Grotesk', sans-serif" }}>{item.name}</span>
                </div>
                <span className="text-[11px] font-mono" style={{ color: CHART_COLORS[i] }}>{item.value}%</span>
              </div>
            ))}
          </div>
        </motion.div>
      </div>

      {/* ── Recent Activity ── */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">

        {/* Recent Purchases */}
        <motion.div
          variants={fadeUp} initial="hidden" animate="show" custom={7}
          className="rounded-2xl overflow-hidden"
          style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}
        >
          <div className="px-5 py-4 flex items-center justify-between" style={{ borderBottom: "1px solid rgba(255,255,255,0.05)" }}>
            <h3 className="text-[13.5px] font-semibold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.9)" }}>
              Compras Recentes
            </h3>
            <span className="nx-badge nx-badge-violet">{stats?.recent_purchases.length ?? 0}</span>
          </div>
          <div>
            {(stats?.recent_purchases ?? []).length === 0 ? (
              <div className="px-5 py-8 text-center text-[12px] font-mono" style={{ color: "rgba(255,255,255,0.2)" }}>
                Nenhuma compra ainda
              </div>
            ) : (
              (stats?.recent_purchases ?? []).map((p, i) => (
                <div
                  key={p.id}
                  className="flex items-center justify-between px-5 py-3 transition-all duration-150 hover:bg-white/[0.02]"
                  style={{ borderBottom: i < (stats?.recent_purchases.length ?? 0) - 1 ? "1px solid rgba(255,255,255,0.04)" : "none" }}
                >
                  <div className="flex items-center gap-3 min-w-0">
                    <div
                      className="w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0 text-[11px] font-bold"
                      style={{ background: "rgba(139,92,246,0.12)", color: "#A78BFA", fontFamily: "'Space Grotesk', sans-serif" }}
                    >
                      {p.user_nickname.charAt(0).toUpperCase()}
                    </div>
                    <div className="min-w-0">
                      <div className="text-[12.5px] font-medium truncate" style={{ color: "rgba(255,255,255,0.8)", fontFamily: "'Space Grotesk', sans-serif" }}>
                        {p.user_nickname}
                      </div>
                      <div className="text-[11px] truncate font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>
                        {p.item_name}
                      </div>
                    </div>
                  </div>
                  <div className="text-right flex-shrink-0 ml-3">
                    <div className="text-[12px] font-mono font-bold" style={{ color: "#F59E0B" }}>
                      {p.price_coins.toLocaleString()} ✦
                    </div>
                    <div className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.22)" }}>
                      {timeAgo(p.created_at)}
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>
        </motion.div>

        {/* Recent Transactions */}
        <motion.div
          variants={fadeUp} initial="hidden" animate="show" custom={8}
          className="rounded-2xl overflow-hidden"
          style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}
        >
          <div className="px-5 py-4 flex items-center justify-between" style={{ borderBottom: "1px solid rgba(255,255,255,0.05)" }}>
            <h3 className="text-[13.5px] font-semibold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.9)" }}>
              Transações de Coins
            </h3>
            <span className="nx-badge nx-badge-cyan">{stats?.recent_transactions.length ?? 0}</span>
          </div>
          <div>
            {(stats?.recent_transactions ?? []).length === 0 ? (
              <div className="px-5 py-8 text-center text-[12px] font-mono" style={{ color: "rgba(255,255,255,0.2)" }}>
                Nenhuma transação ainda
              </div>
            ) : (
              (stats?.recent_transactions ?? []).map((t, i) => (
                <div
                  key={t.id}
                  className="flex items-center justify-between px-5 py-3 transition-all duration-150 hover:bg-white/[0.02]"
                  style={{ borderBottom: i < (stats?.recent_transactions.length ?? 0) - 1 ? "1px solid rgba(255,255,255,0.04)" : "none" }}
                >
                  <div className="flex items-center gap-3 min-w-0">
                    <div
                      className="w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0 text-[11px] font-bold"
                      style={{
                        background: t.amount > 0 ? "rgba(16,185,129,0.12)" : "rgba(239,68,68,0.12)",
                        color: t.amount > 0 ? "#34D399" : "#FCA5A5",
                        fontFamily: "'Space Grotesk', sans-serif",
                      }}
                    >
                      {t.amount > 0 ? "+" : "-"}
                    </div>
                    <div className="min-w-0">
                      <div className="text-[12.5px] font-medium truncate" style={{ color: "rgba(255,255,255,0.8)", fontFamily: "'Space Grotesk', sans-serif" }}>
                        {t.user_nickname}
                      </div>
                      <div className="text-[11px] font-mono truncate" style={{ color: "rgba(255,255,255,0.3)" }}>
                        {t.source}
                      </div>
                    </div>
                  </div>
                  <div className="text-right flex-shrink-0 ml-3">
                    <div
                      className="text-[12px] font-mono font-bold"
                      style={{ color: t.amount > 0 ? "#34D399" : "#FCA5A5" }}
                    >
                      {t.amount > 0 ? "+" : ""}{t.amount.toLocaleString()} ✦
                    </div>
                    <div className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.22)" }}>
                      {timeAgo(t.created_at)}
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>
        </motion.div>
      </div>
    </div>
  );
}
