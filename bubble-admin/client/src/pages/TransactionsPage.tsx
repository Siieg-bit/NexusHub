import { useState, useEffect } from "react";
import { supabase, CoinTransaction } from "@/lib/supabase";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Loader2, RefreshCw, Search, ArrowLeftRight, TrendingUp, TrendingDown } from "lucide-react";

type TxWithProfile = CoinTransaction & {
  profiles: { nickname: string; icon_url: string | null } | null;
};

const SOURCE_LABELS: Record<string, string> = {
  checkin: "Check-in",
  lucky_draw: "Lucky Draw",
  iap: "Compra Real (IAP)",
  ad_reward: "Recompensa por Anúncio",
  tip_received: "Gorjeta Recebida",
  purchase: "Compra na Loja",
  tip_sent: "Gorjeta Enviada",
  streak_repair: "Reparo de Streak",
};

const SOURCE_COLORS: Record<string, string> = {
  checkin: "#4ADE80",
  lucky_draw: "#FBBF24",
  iap: "#60A5FA",
  ad_reward: "#A78BFA",
  tip_received: "#4ADE80",
  purchase: "#F87171",
  tip_sent: "#F87171",
  streak_repair: "#FB923C",
};

export default function TransactionsPage() {
  const [transactions, setTransactions] = useState<TxWithProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [filterSource, setFilterSource] = useState("all");
  const [filterType, setFilterType] = useState<"all" | "credit" | "debit">("all");
  const [page, setPage] = useState(0);
  const PAGE_SIZE = 50;

  async function loadTransactions() {
    setLoading(true);
    let query = supabase
      .from("coin_transactions")
      .select("*, profiles(nickname, icon_url)")
      .order("created_at", { ascending: false })
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1);

    if (filterSource !== "all") {
      query = query.eq("source", filterSource);
    }
    if (filterType === "credit") {
      query = query.gt("amount", 0);
    } else if (filterType === "debit") {
      query = query.lt("amount", 0);
    }

    const { data, error } = await query;
    if (!error && data) setTransactions(data as unknown as TxWithProfile[]);
    setLoading(false);
  }

  useEffect(() => {
    loadTransactions();
  }, [page, filterSource, filterType]);

  const filtered = transactions.filter(
    (tx) =>
      !search ||
      (tx.profiles?.nickname ?? "").toLowerCase().includes(search.toLowerCase()) ||
      tx.source.toLowerCase().includes(search.toLowerCase()) ||
      tx.description.toLowerCase().includes(search.toLowerCase())
  );

  const totalCredit = filtered
    .filter((tx) => tx.amount > 0)
    .reduce((sum, tx) => sum + tx.amount, 0);
  const totalDebit = filtered
    .filter((tx) => tx.amount < 0)
    .reduce((sum, tx) => sum + Math.abs(tx.amount), 0);

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-bold text-white">Transações de Coins</h1>
          <p className="text-[#6B7280] text-sm mt-0.5">
            Histórico de movimentações da plataforma
          </p>
        </div>
        <Button
          variant="ghost"
          size="sm"
          onClick={loadTransactions}
          className="text-[#6B7280] hover:text-white hover:bg-[#2A2D34] h-9"
        >
          <RefreshCw className="w-3.5 h-3.5 mr-1.5" />
          Atualizar
        </Button>
      </div>

      {/* Summary cards */}
      <div className="grid grid-cols-3 gap-4 mb-6">
        <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl p-4">
          <p className="text-[#6B7280] text-xs mb-1">Total Exibido</p>
          <p className="text-white text-xl font-bold">{filtered.length}</p>
          <p className="text-[#4B5563] text-xs">transações</p>
        </div>
        <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl p-4">
          <div className="flex items-center gap-1.5 mb-1">
            <TrendingUp className="w-3.5 h-3.5 text-[#4ADE80]" />
            <p className="text-[#6B7280] text-xs">Créditos</p>
          </div>
          <p className="text-[#4ADE80] text-xl font-bold">
            +{totalCredit.toLocaleString()}
          </p>
          <p className="text-[#4B5563] text-xs">coins ganhos</p>
        </div>
        <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl p-4">
          <div className="flex items-center gap-1.5 mb-1">
            <TrendingDown className="w-3.5 h-3.5 text-red-400" />
            <p className="text-[#6B7280] text-xs">Débitos</p>
          </div>
          <p className="text-red-400 text-xl font-bold">
            -{totalDebit.toLocaleString()}
          </p>
          <p className="text-[#4B5563] text-xs">coins gastos</p>
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3 mb-5">
        <div className="relative flex-1 min-w-48">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#4B5563]" />
          <Input
            placeholder="Buscar por usuário ou descrição..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-9 bg-[#1C1E22] border-[#2A2D34] text-white placeholder:text-[#4B5563] h-9"
          />
        </div>
        <select
          value={filterSource}
          onChange={(e) => {
            setFilterSource(e.target.value);
            setPage(0);
          }}
          className="bg-[#1C1E22] border border-[#2A2D34] text-[#9CA3AF] text-sm rounded-md px-3 h-9 focus:outline-none focus:border-[#E040FB]"
        >
          <option value="all">Todas as origens</option>
          {Object.entries(SOURCE_LABELS).map(([k, v]) => (
            <option key={k} value={k}>
              {v}
            </option>
          ))}
        </select>
        <select
          value={filterType}
          onChange={(e) => {
            setFilterType(e.target.value as "all" | "credit" | "debit");
            setPage(0);
          }}
          className="bg-[#1C1E22] border border-[#2A2D34] text-[#9CA3AF] text-sm rounded-md px-3 h-9 focus:outline-none focus:border-[#E040FB]"
        >
          <option value="all">Créditos e débitos</option>
          <option value="credit">Apenas créditos</option>
          <option value="debit">Apenas débitos</option>
        </select>
      </div>

      {/* Table */}
      {loading ? (
        <div className="flex items-center justify-center h-48">
          <Loader2 className="w-6 h-6 text-[#E040FB] animate-spin" />
        </div>
      ) : filtered.length === 0 ? (
        <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl p-12 text-center">
          <ArrowLeftRight className="w-10 h-10 text-[#2A2D34] mx-auto mb-3" />
          <p className="text-[#4B5563] text-sm">Nenhuma transação encontrada</p>
        </div>
      ) : (
        <>
          <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl overflow-hidden">
            <table className="w-full">
              <thead>
                <tr className="border-b border-[#2A2D34]">
                  <th className="text-left px-4 py-3 text-[#6B7280] text-xs font-medium uppercase">Usuário</th>
                  <th className="text-left px-4 py-3 text-[#6B7280] text-xs font-medium uppercase">Origem</th>
                  <th className="text-left px-4 py-3 text-[#6B7280] text-xs font-medium uppercase">Descrição</th>
                  <th className="text-right px-4 py-3 text-[#6B7280] text-xs font-medium uppercase">Valor</th>
                  <th className="text-right px-4 py-3 text-[#6B7280] text-xs font-medium uppercase">Saldo Após</th>
                  <th className="text-right px-4 py-3 text-[#6B7280] text-xs font-medium uppercase">Data</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[#2A2D34]">
                {filtered.map((tx) => (
                  <tr key={tx.id} className="hover:bg-[#1F2126] transition-colors">
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        <div className="w-6 h-6 rounded-full bg-[#2A2D34] flex items-center justify-center overflow-hidden flex-shrink-0">
                          {tx.profiles?.icon_url ? (
                            <img
                              src={tx.profiles.icon_url}
                              alt=""
                              className="w-full h-full object-cover"
                            />
                          ) : (
                            <span className="text-[#6B7280] text-[10px]">
                              {tx.profiles?.nickname?.[0]?.toUpperCase() ?? "?"}
                            </span>
                          )}
                        </div>
                        <span className="text-white text-sm">
                          {tx.profiles?.nickname ?? "Usuário"}
                        </span>
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className="text-xs px-2 py-0.5 rounded-full"
                        style={{
                          color: SOURCE_COLORS[tx.source] ?? "#9CA3AF",
                          background: `${SOURCE_COLORS[tx.source] ?? "#9CA3AF"}20`,
                          border: `1px solid ${SOURCE_COLORS[tx.source] ?? "#9CA3AF"}40`,
                        }}
                      >
                        {SOURCE_LABELS[tx.source] ?? tx.source}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-[#6B7280] text-sm truncate max-w-[200px]">
                      {tx.description || "—"}
                    </td>
                    <td className="px-4 py-3 text-right">
                      <span
                        className={`text-sm font-bold ${
                          tx.amount > 0 ? "text-[#4ADE80]" : "text-red-400"
                        }`}
                      >
                        {tx.amount > 0 ? "+" : ""}
                        {tx.amount}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-right text-[#FBBF24] text-sm">
                      {tx.balance_after}
                    </td>
                    <td className="px-4 py-3 text-right text-[#6B7280] text-xs">
                      {new Date(tx.created_at).toLocaleString("pt-BR", {
                        day: "2-digit",
                        month: "2-digit",
                        year: "2-digit",
                        hour: "2-digit",
                        minute: "2-digit",
                      })}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          <div className="flex items-center justify-between mt-4">
            <p className="text-[#6B7280] text-sm">
              Página {page + 1} · {filtered.length} resultados
            </p>
            <div className="flex gap-2">
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setPage(Math.max(0, page - 1))}
                disabled={page === 0}
                className="text-[#6B7280] hover:text-white hover:bg-[#2A2D34] h-8"
              >
                Anterior
              </Button>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setPage(page + 1)}
                disabled={transactions.length < PAGE_SIZE}
                className="text-[#6B7280] hover:text-white hover:bg-[#2A2D34] h-8"
              >
                Próxima
              </Button>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
