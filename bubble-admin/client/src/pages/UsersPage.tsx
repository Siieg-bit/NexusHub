import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { toast } from "sonner";
import { Search, Users, ShoppingBag, Coins, ArrowLeft, ChevronRight, Crown, Shield } from "lucide-react";

type Profile = {
  id: string; username: string; display_name: string | null;
  avatar_url: string | null; coins_balance: number; total_coins_earned: number;
  is_team_admin: boolean; is_team_moderator: boolean;
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

export default function UsersPage() {
  const [users, setUsers] = useState<Profile[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [selected, setSelected] = useState<Profile | null>(null);
  const [purchases, setPurchases] = useState<Purchase[]>([]);
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [loadingDetail, setLoadingDetail] = useState(false);

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

  const filtered = users.filter(u =>
    !search || u.username?.toLowerCase().includes(search.toLowerCase()) || (u.display_name ?? "").toLowerCase().includes(search.toLowerCase())
  );

  const totalCoins = users.reduce((s, u) => s + (u.coins_balance || 0), 0);
  const adminCount = users.filter(u => u.is_team_admin).length;

  return (
    <div className="p-4 md:p-6 max-w-7xl mx-auto space-y-5">
      <AnimatePresence mode="wait">
        {!selected ? (
          <motion.div key="list" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="space-y-5">
            {/* Header */}
            <motion.div variants={fadeUp} initial="hidden" animate="show" custom={0} className="flex items-start justify-between gap-3">
              <div>
                <h1 className="text-[20px] font-bold tracking-tight" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.95)" }}>
                  Usuários
                </h1>
                <p className="text-[12px] font-mono mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>
                  {users.length} cadastrados · {adminCount} admins
                </p>
              </div>
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
              <input
                placeholder="Buscar por username ou nome..."
                value={search} onChange={(e) => setSearch(e.target.value)}
                className="w-full pl-9 pr-3 py-2 rounded-xl text-[13px] outline-none"
                style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.85)", fontFamily: "'Space Grotesk', sans-serif" }}
              />
            </motion.div>

            {/* Users list */}
            {loading ? (
              <div className="space-y-2">{[...Array(6)].map((_, i) => <div key={i} className="h-14 rounded-xl nx-shimmer" style={{ background: "rgba(255,255,255,0.03)" }} />)}</div>
            ) : (
              <motion.div variants={fadeUp} initial="hidden" animate="show" custom={3} className="rounded-2xl overflow-hidden"
                style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}
              >
                {filtered.map((user, i) => (
                  <motion.div
                    key={user.id}
                    initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: i * 0.025 }}
                    onClick={() => selectUser(user)}
                    className="flex items-center gap-3 px-4 py-3 cursor-pointer transition-all duration-150 group"
                    style={{ borderBottom: i < filtered.length - 1 ? "1px solid rgba(255,255,255,0.04)" : "none" }}
                    onMouseEnter={e => (e.currentTarget.style.background = "rgba(255,255,255,0.03)")}
                    onMouseLeave={e => (e.currentTarget.style.background = "transparent")}
                  >
                    <div className="w-9 h-9 rounded-xl flex-shrink-0 overflow-hidden flex items-center justify-center"
                      style={{ background: "rgba(124,58,237,0.1)", border: "1px solid rgba(124,58,237,0.2)" }}
                    >
                      {user.avatar_url ? (
                        <img src={user.avatar_url} alt={user.username} className="w-full h-full object-cover" />
                      ) : (
                        <span className="text-[13px] font-bold" style={{ color: "#A78BFA" }}>
                          {(user.display_name || user.username || "?")[0].toUpperCase()}
                        </span>
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="text-[13px] font-semibold truncate" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.9)" }}>
                          {user.display_name || user.username}
                        </span>
                        {user.is_team_admin && (
                          <span className="nx-badge nx-badge-violet flex items-center gap-1">
                            <Crown size={8} /> ADMIN
                          </span>
                        )}
                        {user.is_team_moderator && !user.is_team_admin && (
                          <span className="nx-badge nx-badge-cyan flex items-center gap-1">
                            <Shield size={8} /> MOD
                          </span>
                        )}
                      </div>
                      <div className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>@{user.username}</div>
                    </div>
                    <div className="text-right flex-shrink-0">
                      <div className="text-[13px] font-mono font-bold" style={{ color: "#F59E0B" }}>{(user.coins_balance || 0).toLocaleString()} ✦</div>
                      <div className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.25)" }}>
                        {new Date(user.created_at).toLocaleDateString("pt-BR")}
                      </div>
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
                style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.6)" }}
              >
                <ArrowLeft size={14} />
              </button>
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl overflow-hidden flex items-center justify-center"
                  style={{ background: "rgba(124,58,237,0.1)", border: "1px solid rgba(124,58,237,0.2)" }}
                >
                  {selected.avatar_url ? (
                    <img src={selected.avatar_url} alt={selected.username} className="w-full h-full object-cover" />
                  ) : (
                    <span className="text-[16px] font-bold" style={{ color: "#A78BFA" }}>
                      {(selected.display_name || selected.username || "?")[0].toUpperCase()}
                    </span>
                  )}
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <h2 className="text-[16px] font-bold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.95)" }}>
                      {selected.display_name || selected.username}
                    </h2>
                    {selected.is_team_admin && <span className="nx-badge nx-badge-violet">ADMIN</span>}
                    {selected.is_team_moderator && !selected.is_team_admin && <span className="nx-badge nx-badge-cyan">MOD</span>}
                  </div>
                  <p className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>@{selected.username}</p>
                </div>
              </div>
            </div>

            {/* Stats */}
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
              {[
                { label: "Saldo Atual", value: `${(selected.coins_balance || 0).toLocaleString()} ✦`, color: "#F59E0B", rgb: "245,158,11" },
                { label: "Total Ganho", value: `${(selected.total_coins_earned || 0).toLocaleString()} ✦`, color: "#10B981", rgb: "16,185,129" },
                { label: "Compras", value: purchases.length, color: "#A78BFA", rgb: "167,139,250" },
              ].map(({ label, value, color, rgb }) => (
                <div key={label} className="p-3 rounded-2xl" style={{ background: `rgba(${rgb},0.06)`, border: `1px solid rgba(${rgb},0.15)` }}>
                  <div className="text-[10px] font-mono tracking-wider uppercase mb-1" style={{ color: "rgba(255,255,255,0.35)" }}>{label}</div>
                  <div className="text-[16px] font-bold font-mono" style={{ color }}>{value}</div>
                </div>
              ))}
            </div>

            {loadingDetail ? (
              <div className="space-y-2">{[...Array(4)].map((_, i) => <div key={i} className="h-12 rounded-xl nx-shimmer" style={{ background: "rgba(255,255,255,0.03)" }} />)}</div>
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
                                  style={{ background: t.amount > 0 ? "rgba(16,185,129,0.1)" : "rgba(239,68,68,0.1)", color: t.amount > 0 ? "#34D399" : "#FCA5A5" }}
                                >
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
  );
}
