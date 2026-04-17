import { useEffect, useState } from "react";
import { supabase, StoreStats } from "@/lib/supabase";
import {
  ShoppingBag,
  Package,
  Users,
  Coins,
  TrendingUp,
  Palette,
  Loader2,
  RefreshCw,
  ArrowUpRight,
  CheckCircle2,
} from "lucide-react";
import { Button } from "@/components/ui/button";

type RecentPurchase = {
  id: string;
  price_paid: number;
  purchased_at: string;
  profiles: { nickname: string } | null;
  store_items: { name: string; type: string } | null;
};

type RecentTransaction = {
  id: string;
  amount: number;
  source: string;
  description: string;
  created_at: string;
  profiles: { nickname: string } | null;
};

function StatCard({
  label,
  value,
  icon: Icon,
  color,
  sub,
}: {
  label: string;
  value: string | number;
  icon: React.ComponentType<{ className?: string }>;
  color: string;
  sub?: string;
}) {
  return (
    <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl p-5 flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <span className="text-[#6B7280] text-sm">{label}</span>
        <div
          className="w-8 h-8 rounded-lg flex items-center justify-center"
          style={{ background: `${color}20`, border: `1px solid ${color}40` }}
        >
          <Icon className="w-4 h-4" style={{ color }} />
        </div>
      </div>
      <div>
        <span className="text-2xl font-bold text-white">{value}</span>
        {sub && <p className="text-[#6B7280] text-xs mt-0.5">{sub}</p>}
      </div>
    </div>
  );
}

const SOURCE_LABELS: Record<string, string> = {
  checkin: "Check-in",
  lucky_draw: "Lucky Draw",
  iap: "Compra Real",
  ad_reward: "Anúncio",
  tip_received: "Gorjeta Recebida",
  purchase: "Compra na Loja",
  tip_sent: "Gorjeta Enviada",
  streak_repair: "Reparo de Streak",
};

const TYPE_LABELS: Record<string, string> = {
  avatar_frame: "Moldura",
  chat_bubble: "Chat Bubble",
  sticker_pack: "Pack de Stickers",
  profile_background: "Fundo de Perfil",
  chat_background: "Fundo de Chat",
};

export default function OverviewPage() {
  const [stats, setStats] = useState<StoreStats | null>(null);
  const [recentPurchases, setRecentPurchases] = useState<RecentPurchase[]>([]);
  const [recentTransactions, setRecentTransactions] = useState<
    RecentTransaction[]
  >([]);
  const [loading, setLoading] = useState(true);

  async function loadData() {
    setLoading(true);
    try {
      // Stats
      const { data: statsData } = await supabase
        .from("store_stats")
        .select("*")
        .single();
      if (statsData) setStats(statsData as StoreStats);

      // Recent purchases
      const { data: purchases } = await supabase
        .from("user_purchases")
        .select(
          "id, price_paid, purchased_at, profiles(nickname), store_items(name, type)"
        )
        .order("purchased_at", { ascending: false })
        .limit(8);
      if (purchases) setRecentPurchases(purchases as unknown as RecentPurchase[]);

      // Recent transactions
      const { data: txs } = await supabase
        .from("coin_transactions")
        .select("id, amount, source, description, created_at, profiles(nickname)")
        .order("created_at", { ascending: false })
        .limit(8);
      if (txs) setRecentTransactions(txs as unknown as RecentTransaction[]);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadData();
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader2 className="w-6 h-6 text-[#E040FB] animate-spin" />
      </div>
    );
  }

  return (
    <div className="p-6 max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-bold text-white">Visão Geral da Loja</h1>
          <p className="text-[#6B7280] text-sm mt-0.5">
            Estatísticas e atividade recente
          </p>
        </div>
        <Button
          variant="ghost"
          size="sm"
          onClick={loadData}
          className="text-[#6B7280] hover:text-white hover:bg-[#2A2D34] h-8"
        >
          <RefreshCw className="w-3.5 h-3.5 mr-1.5" />
          Atualizar
        </Button>
      </div>

      {/* Stats Grid */}
      {stats && (
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          <StatCard
            label="Itens Ativos"
            value={stats.active_items}
            icon={ShoppingBag}
            color="#E040FB"
            sub={`${stats.total_items} total`}
          />
          <StatCard
            label="Packs Oficiais"
            value={stats.official_packs}
            icon={Package}
            color="#60A5FA"
            sub="packs de stickers"
          />
          <StatCard
            label="Total de Usuários"
            value={stats.total_users}
            icon={Users}
            color="#4ADE80"
            sub={`${stats.total_purchases} compras`}
          />
          <StatCard
            label="Coins Gastos"
            value={stats.total_coins_spent.toLocaleString()}
            icon={TrendingUp}
            color="#FBBF24"
            sub="total na loja"
          />
        </div>
      )}

      {/* Second row */}
      {stats && (
        <div className="grid grid-cols-2 lg:grid-cols-3 gap-4 mb-6">
          <StatCard
            label="Temas Ativos"
            value={stats.active_themes}
            icon={Palette}
            color="#A78BFA"
            sub="temas do app"
          />
          <StatCard
            label="Total de Compras"
            value={stats.total_purchases}
            icon={Coins}
            color="#FB923C"
            sub="na plataforma"
          />
          <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl p-5 flex flex-col gap-2">
            <span className="text-[#6B7280] text-sm">Status do Sistema</span>
            <div className="flex items-center gap-2 mt-1">
              <CheckCircle2 className="w-4 h-4 text-[#4ADE80]" />
              <span className="text-white text-sm">Supabase Online</span>
            </div>
            <div className="flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-[#4ADE80]" />
              <span className="text-white text-sm">Storage Ativo</span>
            </div>
            <div className="flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-[#4ADE80]" />
              <span className="text-white text-sm">RLS Configurado</span>
            </div>
          </div>
        </div>
      )}

      {/* Recent activity */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent purchases */}
        <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl overflow-hidden">
          <div className="flex items-center justify-between px-5 py-4 border-b border-[#2A2D34]">
            <h2 className="font-semibold text-white text-sm">
              Compras Recentes
            </h2>
            <ArrowUpRight className="w-4 h-4 text-[#4B5563]" />
          </div>
          <div className="divide-y divide-[#2A2D34]">
            {recentPurchases.length === 0 ? (
              <div className="px-5 py-8 text-center text-[#4B5563] text-sm">
                Nenhuma compra ainda
              </div>
            ) : (
              recentPurchases.map((p) => (
                <div
                  key={p.id}
                  className="flex items-center justify-between px-5 py-3"
                >
                  <div>
                    <p className="text-white text-sm font-medium">
                      {p.store_items?.name ?? "Item removido"}
                    </p>
                    <p className="text-[#6B7280] text-xs">
                      {p.profiles?.nickname ?? "Usuário"} ·{" "}
                      {p.store_items?.type
                        ? TYPE_LABELS[p.store_items.type] ?? p.store_items.type
                        : ""}
                    </p>
                  </div>
                  <div className="text-right">
                    <p className="text-[#FBBF24] text-sm font-medium">
                      {p.price_paid} coins
                    </p>
                    <p className="text-[#4B5563] text-xs">
                      {new Date(p.purchased_at).toLocaleDateString("pt-BR")}
                    </p>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Recent transactions */}
        <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl overflow-hidden">
          <div className="flex items-center justify-between px-5 py-4 border-b border-[#2A2D34]">
            <h2 className="font-semibold text-white text-sm">
              Transações Recentes
            </h2>
            <ArrowUpRight className="w-4 h-4 text-[#4B5563]" />
          </div>
          <div className="divide-y divide-[#2A2D34]">
            {recentTransactions.length === 0 ? (
              <div className="px-5 py-8 text-center text-[#4B5563] text-sm">
                Nenhuma transação ainda
              </div>
            ) : (
              recentTransactions.map((tx) => (
                <div
                  key={tx.id}
                  className="flex items-center justify-between px-5 py-3"
                >
                  <div>
                    <p className="text-white text-sm font-medium">
                      {SOURCE_LABELS[tx.source] ?? tx.source}
                    </p>
                    <p className="text-[#6B7280] text-xs">
                      {tx.profiles?.nickname ?? "Usuário"}
                      {tx.description ? ` · ${tx.description}` : ""}
                    </p>
                  </div>
                  <div className="text-right">
                    <p
                      className={`text-sm font-medium ${
                        tx.amount > 0 ? "text-[#4ADE80]" : "text-red-400"
                      }`}
                    >
                      {tx.amount > 0 ? "+" : ""}
                      {tx.amount} coins
                    </p>
                    <p className="text-[#4B5563] text-xs">
                      {new Date(tx.created_at).toLocaleDateString("pt-BR")}
                    </p>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
