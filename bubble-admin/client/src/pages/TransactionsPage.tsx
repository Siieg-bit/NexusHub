import { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { supabaseAdmin } from "@/lib/supabase";
import { ArrowUpRight, ArrowDownLeft, Filter, TrendingUp, TrendingDown, Activity } from "lucide-react";

type Transaction = {
  id: string; user_id: string; amount: number; source: string;
  description: string | null; created_at: string;
  profiles?: { nickname: string; amino_id: string | null };
};

const SOURCE_COLORS: Record<string, { color: string; rgb: string }> = {
  purchase: { color: "#FCA5A5", rgb: "252,165,165" },
  daily_reward: { color: "#34D399", rgb: "52,211,153" },
  achievement: { color: "#A78BFA", rgb: "167,139,250" },
  gift: { color: "#F9A8D4", rgb: "249,168,212" },
  admin_grant: { color: "#67E8F9", rgb: "103,232,249" },
  refund: { color: "#FCD34D", rgb: "252,211,77" },
};

const fadeUp = {
  hidden: { opacity: 0, y: 12 },
  show: (i: number) => ({ opacity: 1, y: 0, transition: { delay: i * 0.04, duration: 0.25, ease: "easeOut" as const } }),
};

const PAGE_SIZE = 25;

export default function TransactionsPage() {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [filterSource, setFilterSource] = useState("all");
  const [filterType, setFilterType] = useState<"all" | "credit" | "debit">("all");
  const [page, setPage] = useState(0);
  const [total, setTotal] = useState(0);

  const totalCredits = transactions.filter(t => t.amount > 0).reduce((s, t) => s + t.amount, 0);
  const totalDebits = transactions.filter(t => t.amount < 0).reduce((s, t) => s + Math.abs(t.amount), 0);

  async function loadTransactions() {
    setLoading(true);
    let query = supabaseAdmin
      .from("coin_transactions")
      .select("id, user_id, amount, source, description, created_at, profiles:profiles!user_id(nickname, amino_id)", { count: "exact" })
      .order("created_at", { ascending: false })
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1);

    if (filterSource !== "all") query = query.eq("source", filterSource);
    if (filterType === "credit") query = query.gt("amount", 0);
    if (filterType === "debit") query = query.lt("amount", 0);

    const { data, error, count } = await query;
    if (!error && data) setTransactions(data as unknown as Transaction[]);
    if (count !== null) setTotal(count);
    setLoading(false);
  }

  useEffect(() => { loadTransactions(); }, [page, filterSource, filterType]);

  const sources = ["all", "purchase", "daily_reward", "achievement", "gift", "admin_grant", "refund"];

  return (
    <div className="p-4 md:p-6 max-w-7xl mx-auto space-y-5">
      {/* Header */}
      <motion.div variants={fadeUp} initial="hidden" animate="show" custom={0}>
        <h1 className="text-[20px] font-bold tracking-tight" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.95)" }}>
          Transações
        </h1>
        <p className="text-[12px] font-mono mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>
          {total.toLocaleString()} registros
        </p>
      </motion.div>

      {/* Stats */}
      <motion.div variants={fadeUp} initial="hidden" animate="show" custom={1} className="grid grid-cols-3 gap-3">
        {[
          { label: "Total Registros", value: total.toLocaleString(), icon: Activity, color: "#A78BFA", rgb: "167,139,250" },
          { label: "Créditos (pág.)", value: `+${totalCredits.toLocaleString()} ✦`, icon: TrendingUp, color: "#34D399", rgb: "52,211,153" },
          { label: "Débitos (pág.)", value: `-${totalDebits.toLocaleString()} ✦`, icon: TrendingDown, color: "#FCA5A5", rgb: "252,165,165" },
        ].map(({ label, value, icon: Icon, color, rgb }) => (
          <div key={label} className="p-3 md:p-4 rounded-2xl" style={{ background: `rgba(${rgb},0.06)`, border: `1px solid rgba(${rgb},0.15)` }}>
            <div className="flex items-center gap-2 mb-1">
              <Icon size={12} style={{ color }} />
              <span className="text-[10px] font-mono tracking-wider uppercase" style={{ color: "rgba(255,255,255,0.35)" }}>{label}</span>
            </div>
            <div className="text-[16px] font-bold font-mono" style={{ color }}>{value}</div>
          </div>
        ))}
      </motion.div>

      {/* Filters */}
      <motion.div variants={fadeUp} initial="hidden" animate="show" custom={2} className="flex flex-col sm:flex-row gap-2">
        <select
          value={filterSource} onChange={(e) => { setFilterSource(e.target.value); setPage(0); }}
          className="px-3 py-2 rounded-xl text-[12px] outline-none flex-1"
          style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.6)", fontFamily: "'Space Mono', monospace" }}
        >
          {sources.map(s => <option key={s} value={s}>{s === "all" ? "Todas as fontes" : s}</option>)}
        </select>
        <select
          value={filterType} onChange={(e) => { setFilterType(e.target.value as "all" | "credit" | "debit"); setPage(0); }}
          className="px-3 py-2 rounded-xl text-[12px] outline-none"
          style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.6)", fontFamily: "'Space Mono', monospace" }}
        >
          <option value="all">Todos os tipos</option>
          <option value="credit">Créditos</option>
          <option value="debit">Débitos</option>
        </select>
      </motion.div>

      {/* Table */}
      {loading ? (
        <div className="space-y-2">{[...Array(8)].map((_, i) => <div key={i} className="h-12 rounded-xl nx-shimmer" style={{ background: "rgba(255,255,255,0.03)" }} />)}</div>
      ) : (
        <motion.div variants={fadeUp} initial="hidden" animate="show" custom={3} className="rounded-2xl overflow-hidden"
          style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}
        >
          <div className="overflow-x-auto">
            <table className="w-full nx-table">
              <thead>
                <tr>
                  <th className="text-left">Usuário</th>
                  <th className="text-left hidden sm:table-cell">Fonte</th>
                  <th className="text-right">Valor</th>
                  <th className="text-right hidden md:table-cell">Data</th>
                </tr>
              </thead>
              <tbody>
                {transactions.map((t, i) => {
                  const sc = SOURCE_COLORS[t.source] ?? { color: "#94A3B8", rgb: "148,163,184" };
                  const isCredit = t.amount > 0;
                  return (
                    <motion.tr key={t.id} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: i * 0.02 }}>
                      <td>
                        <div className="flex items-center gap-2">
                          <div className="w-6 h-6 rounded-lg flex items-center justify-center flex-shrink-0"
                            style={{ background: isCredit ? "rgba(52,211,153,0.1)" : "rgba(252,165,165,0.1)" }}
                          >
                            {isCredit ? <ArrowUpRight size={10} style={{ color: "#34D399" }} /> : <ArrowDownLeft size={10} style={{ color: "#FCA5A5" }} />}
                          </div>
                          <div>
                            <div className="text-[12px] font-semibold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.8)" }}>
                              {(t.profiles as any)?.nickname || (t.profiles as any)?.amino_id || t.user_id.slice(0, 8) + "…"}
                            </div>
                            {t.description && <div className="text-[10px] font-mono truncate max-w-[140px]" style={{ color: "rgba(255,255,255,0.3)" }}>{t.description}</div>}
                          </div>
                        </div>
                      </td>
                      <td className="hidden sm:table-cell">
                        <span className="text-[10px] font-mono px-2 py-0.5 rounded-lg"
                          style={{ background: `rgba(${sc.rgb},0.1)`, color: sc.color, border: `1px solid rgba(${sc.rgb},0.2)` }}
                        >
                          {t.source}
                        </span>
                      </td>
                      <td className="text-right">
                        <span className="font-mono font-bold text-[13px]" style={{ color: isCredit ? "#34D399" : "#FCA5A5" }}>
                          {isCredit ? "+" : ""}{t.amount} ✦
                        </span>
                      </td>
                      <td className="text-right hidden md:table-cell">
                        <span className="font-mono text-[11px]" style={{ color: "rgba(255,255,255,0.3)" }}>
                          {new Date(t.created_at).toLocaleDateString("pt-BR")}
                        </span>
                      </td>
                    </motion.tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          <div className="flex items-center justify-between px-4 py-3" style={{ borderTop: "1px solid rgba(255,255,255,0.07)" }}>
            <span className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>
              {page * PAGE_SIZE + 1}–{Math.min((page + 1) * PAGE_SIZE, total)} de {total}
            </span>
            <div className="flex gap-2">
              <button
                disabled={page === 0} onClick={() => setPage(p => p - 1)}
                className="px-3 py-1.5 rounded-lg text-[11px] font-mono transition-all duration-150 disabled:opacity-30"
                style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.6)" }}
              >
                ← Anterior
              </button>
              <button
                disabled={(page + 1) * PAGE_SIZE >= total} onClick={() => setPage(p => p + 1)}
                className="px-3 py-1.5 rounded-lg text-[11px] font-mono transition-all duration-150 disabled:opacity-30"
                style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.6)" }}
              >
                Próxima →
              </button>
            </div>
          </div>
        </motion.div>
      )}
    </div>
  );
}
