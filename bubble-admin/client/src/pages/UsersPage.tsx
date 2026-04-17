import { useState, useEffect } from "react";
import { supabase, Profile, UserPurchase, CoinTransaction } from "@/lib/supabase";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Loader2,
  RefreshCw,
  Search,
  ChevronLeft,
  Users,
  Coins,
  ShoppingBag,
  ArrowLeftRight,
  Shield,
  User,
} from "lucide-react";

type ProfileWithStats = Profile & {
  coins?: number;
  amino_id?: string;
};

type PurchaseWithItem = UserPurchase & {
  store_items: { name: string; type: string; preview_url: string | null } | null;
};

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
};

export default function UsersPage() {
  const [users, setUsers] = useState<ProfileWithStats[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [selectedUser, setSelectedUser] = useState<ProfileWithStats | null>(null);
  const [purchases, setPurchases] = useState<PurchaseWithItem[]>([]);
  const [transactions, setTransactions] = useState<CoinTransaction[]>([]);
  const [loadingDetails, setLoadingDetails] = useState(false);
  const [activeTab, setActiveTab] = useState<"purchases" | "transactions">("purchases");

  async function loadUsers() {
    setLoading(true);
    const { data, error } = await supabase
      .from("profiles")
      .select("id, nickname, icon_url, is_team_admin, is_team_moderator, coins, amino_id, created_at")
      .order("created_at", { ascending: false })
      .limit(100);
    if (!error && data) setUsers(data as ProfileWithStats[]);
    setLoading(false);
  }

  async function loadUserDetails(userId: string) {
    setLoadingDetails(true);
    const [{ data: purchasesData }, { data: txData }] = await Promise.all([
      supabase
        .from("user_purchases")
        .select("*, store_items(name, type, preview_url)")
        .eq("user_id", userId)
        .order("purchased_at", { ascending: false })
        .limit(50),
      supabase
        .from("coin_transactions")
        .select("*")
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(50),
    ]);
    if (purchasesData) setPurchases(purchasesData as unknown as PurchaseWithItem[]);
    if (txData) setTransactions(txData as CoinTransaction[]);
    setLoadingDetails(false);
  }

  useEffect(() => {
    loadUsers();
  }, []);

  function selectUser(user: ProfileWithStats) {
    setSelectedUser(user);
    setActiveTab("purchases");
    loadUserDetails(user.id);
  }

  const filteredUsers = users.filter(
    (u) =>
      !search ||
      u.nickname.toLowerCase().includes(search.toLowerCase()) ||
      (u.amino_id ?? "").toLowerCase().includes(search.toLowerCase())
  );

  // User detail view
  if (selectedUser) {
    return (
      <div className="p-6 max-w-5xl mx-auto">
        <div className="flex items-center gap-3 mb-6">
          <button
            onClick={() => setSelectedUser(null)}
            className="p-1.5 rounded-md text-[#6B7280] hover:text-white hover:bg-[#2A2D34] transition-colors"
          >
            <ChevronLeft className="w-5 h-5" />
          </button>
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-[#E040FB]/20 border border-[#E040FB]/30 flex items-center justify-center overflow-hidden">
              {selectedUser.icon_url ? (
                <img
                  src={selectedUser.icon_url}
                  alt={selectedUser.nickname}
                  className="w-full h-full object-cover"
                />
              ) : (
                <span className="text-[#E040FB] font-bold text-sm">
                  {selectedUser.nickname[0]?.toUpperCase()}
                </span>
              )}
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h1 className="text-xl font-bold text-white">
                  {selectedUser.nickname}
                </h1>
                {selectedUser.is_team_admin && (
                  <span className="text-[10px] bg-[#E040FB]/20 text-[#E040FB] border border-[#E040FB]/30 px-1.5 py-0.5 rounded-full">
                    ADMIN
                  </span>
                )}
                {selectedUser.is_team_moderator && (
                  <span className="text-[10px] bg-[#60A5FA]/20 text-[#60A5FA] border border-[#60A5FA]/30 px-1.5 py-0.5 rounded-full">
                    MOD
                  </span>
                )}
              </div>
              <p className="text-[#6B7280] text-sm">
                {selectedUser.amino_id ? `@${selectedUser.amino_id}` : selectedUser.id.slice(0, 8)}
                {selectedUser.coins !== undefined && (
                  <span className="ml-2 text-[#FBBF24]">
                    · {selectedUser.coins} coins
                  </span>
                )}
              </p>
            </div>
          </div>
        </div>

        {/* Stats cards */}
        <div className="grid grid-cols-3 gap-4 mb-6">
          <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl p-4">
            <p className="text-[#6B7280] text-xs mb-1">Saldo de Coins</p>
            <p className="text-[#FBBF24] text-xl font-bold">
              {selectedUser.coins ?? "—"}
            </p>
          </div>
          <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl p-4">
            <p className="text-[#6B7280] text-xs mb-1">Compras</p>
            <p className="text-white text-xl font-bold">{purchases.length}</p>
          </div>
          <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl p-4">
            <p className="text-[#6B7280] text-xs mb-1">Transações</p>
            <p className="text-white text-xl font-bold">{transactions.length}</p>
          </div>
        </div>

        {/* Tabs */}
        <div className="flex gap-1 mb-4 border-b border-[#2A2D34]">
          <button
            onClick={() => setActiveTab("purchases")}
            className={`flex items-center gap-2 px-4 py-2.5 text-sm font-medium border-b-2 transition-all ${
              activeTab === "purchases"
                ? "border-[#E040FB] text-white"
                : "border-transparent text-[#6B7280] hover:text-[#9CA3AF]"
            }`}
          >
            <ShoppingBag className="w-3.5 h-3.5" />
            Compras ({purchases.length})
          </button>
          <button
            onClick={() => setActiveTab("transactions")}
            className={`flex items-center gap-2 px-4 py-2.5 text-sm font-medium border-b-2 transition-all ${
              activeTab === "transactions"
                ? "border-[#E040FB] text-white"
                : "border-transparent text-[#6B7280] hover:text-[#9CA3AF]"
            }`}
          >
            <ArrowLeftRight className="w-3.5 h-3.5" />
            Transações ({transactions.length})
          </button>
        </div>

        {loadingDetails ? (
          <div className="flex items-center justify-center h-32">
            <Loader2 className="w-5 h-5 text-[#E040FB] animate-spin" />
          </div>
        ) : activeTab === "purchases" ? (
          <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl overflow-hidden">
            {purchases.length === 0 ? (
              <div className="p-8 text-center text-[#4B5563] text-sm">
                Nenhuma compra registrada
              </div>
            ) : (
              <table className="w-full">
                <thead>
                  <tr className="border-b border-[#2A2D34]">
                    <th className="text-left px-4 py-3 text-[#6B7280] text-xs font-medium uppercase">Item</th>
                    <th className="text-left px-4 py-3 text-[#6B7280] text-xs font-medium uppercase">Tipo</th>
                    <th className="text-right px-4 py-3 text-[#6B7280] text-xs font-medium uppercase">Pago</th>
                    <th className="text-center px-4 py-3 text-[#6B7280] text-xs font-medium uppercase">Equipado</th>
                    <th className="text-right px-4 py-3 text-[#6B7280] text-xs font-medium uppercase">Data</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-[#2A2D34]">
                  {purchases.map((p) => (
                    <tr key={p.id} className="hover:bg-[#1F2126]">
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2">
                          {p.store_items?.preview_url && (
                            <img
                              src={p.store_items.preview_url}
                              alt=""
                              className="w-7 h-7 rounded object-cover"
                            />
                          )}
                          <span className="text-white text-sm">
                            {p.store_items?.name ?? "Item removido"}
                          </span>
                        </div>
                      </td>
                      <td className="px-4 py-3 text-[#9CA3AF] text-sm">
                        {p.store_items?.type ? TYPE_LABELS[p.store_items.type] ?? p.store_items.type : "—"}
                      </td>
                      <td className="px-4 py-3 text-right text-[#FBBF24] text-sm">
                        {p.price_paid} coins
                      </td>
                      <td className="px-4 py-3 text-center">
                        <span className={`text-xs ${p.is_equipped ? "text-[#4ADE80]" : "text-[#4B5563]"}`}>
                          {p.is_equipped ? "✓" : "—"}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-right text-[#6B7280] text-xs">
                        {new Date(p.purchased_at).toLocaleDateString("pt-BR")}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        ) : (
          <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl overflow-hidden">
            {transactions.length === 0 ? (
              <div className="p-8 text-center text-[#4B5563] text-sm">
                Nenhuma transação registrada
              </div>
            ) : (
              <table className="w-full">
                <thead>
                  <tr className="border-b border-[#2A2D34]">
                    <th className="text-left px-4 py-3 text-[#6B7280] text-xs font-medium uppercase">Origem</th>
                    <th className="text-left px-4 py-3 text-[#6B7280] text-xs font-medium uppercase">Descrição</th>
                    <th className="text-right px-4 py-3 text-[#6B7280] text-xs font-medium uppercase">Valor</th>
                    <th className="text-right px-4 py-3 text-[#6B7280] text-xs font-medium uppercase">Saldo Após</th>
                    <th className="text-right px-4 py-3 text-[#6B7280] text-xs font-medium uppercase">Data</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-[#2A2D34]">
                  {transactions.map((tx) => (
                    <tr key={tx.id} className="hover:bg-[#1F2126]">
                      <td className="px-4 py-3 text-white text-sm">
                        {SOURCE_LABELS[tx.source] ?? tx.source}
                      </td>
                      <td className="px-4 py-3 text-[#6B7280] text-sm truncate max-w-[200px]">
                        {tx.description || "—"}
                      </td>
                      <td className="px-4 py-3 text-right">
                        <span className={`text-sm font-medium ${tx.amount > 0 ? "text-[#4ADE80]" : "text-red-400"}`}>
                          {tx.amount > 0 ? "+" : ""}{tx.amount}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-right text-[#FBBF24] text-sm">
                        {tx.balance_after}
                      </td>
                      <td className="px-4 py-3 text-right text-[#6B7280] text-xs">
                        {new Date(tx.created_at).toLocaleDateString("pt-BR")}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        )}
      </div>
    );
  }

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-bold text-white">Usuários</h1>
          <p className="text-[#6B7280] text-sm mt-0.5">
            {users.length} usuários registrados
          </p>
        </div>
        <Button
          variant="ghost"
          size="sm"
          onClick={loadUsers}
          className="text-[#6B7280] hover:text-white hover:bg-[#2A2D34] h-9"
        >
          <RefreshCw className="w-3.5 h-3.5 mr-1.5" />
          Atualizar
        </Button>
      </div>

      <div className="flex gap-3 mb-5">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#4B5563]" />
          <Input
            placeholder="Buscar por nickname ou ID..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-9 bg-[#1C1E22] border-[#2A2D34] text-white placeholder:text-[#4B5563] h-9"
          />
        </div>
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-48">
          <Loader2 className="w-6 h-6 text-[#E040FB] animate-spin" />
        </div>
      ) : filteredUsers.length === 0 ? (
        <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl p-12 text-center">
          <Users className="w-10 h-10 text-[#2A2D34] mx-auto mb-3" />
          <p className="text-[#4B5563] text-sm">Nenhum usuário encontrado</p>
        </div>
      ) : (
        <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl overflow-hidden">
          <table className="w-full">
            <thead>
              <tr className="border-b border-[#2A2D34]">
                <th className="text-left px-4 py-3 text-[#6B7280] text-xs font-medium uppercase">Usuário</th>
                <th className="text-left px-4 py-3 text-[#6B7280] text-xs font-medium uppercase">ID/Amino</th>
                <th className="text-right px-4 py-3 text-[#6B7280] text-xs font-medium uppercase">Coins</th>
                <th className="text-center px-4 py-3 text-[#6B7280] text-xs font-medium uppercase">Função</th>
                <th className="text-right px-4 py-3 text-[#6B7280] text-xs font-medium uppercase">Cadastro</th>
                <th className="text-right px-4 py-3 text-[#6B7280] text-xs font-medium uppercase">Ações</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#2A2D34]">
              {filteredUsers.map((user) => (
                <tr key={user.id} className="hover:bg-[#1F2126] transition-colors">
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-full bg-[#E040FB]/20 border border-[#E040FB]/20 flex items-center justify-center overflow-hidden flex-shrink-0">
                        {user.icon_url ? (
                          <img
                            src={user.icon_url}
                            alt={user.nickname}
                            className="w-full h-full object-cover"
                          />
                        ) : (
                          <span className="text-[#E040FB] text-xs font-bold">
                            {user.nickname[0]?.toUpperCase()}
                          </span>
                        )}
                      </div>
                      <span className="text-white text-sm font-medium">
                        {user.nickname}
                      </span>
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    <span className="text-[#6B7280] text-xs font-mono">
                      {user.amino_id ? `@${user.amino_id}` : user.id.slice(0, 8) + "..."}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-right">
                    <span className="text-[#FBBF24] text-sm">
                      {user.coins ?? "—"}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-center">
                    {user.is_team_admin ? (
                      <span className="text-[10px] bg-[#E040FB]/20 text-[#E040FB] border border-[#E040FB]/30 px-1.5 py-0.5 rounded-full">
                        ADMIN
                      </span>
                    ) : user.is_team_moderator ? (
                      <span className="text-[10px] bg-[#60A5FA]/20 text-[#60A5FA] border border-[#60A5FA]/30 px-1.5 py-0.5 rounded-full">
                        MOD
                      </span>
                    ) : (
                      <span className="text-[#4B5563] text-xs">Usuário</span>
                    )}
                  </td>
                  <td className="px-4 py-3 text-right text-[#6B7280] text-xs">
                    {user.created_at
                      ? new Date(user.created_at).toLocaleDateString("pt-BR")
                      : "—"}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <button
                      onClick={() => selectUser(user)}
                      className="text-xs text-[#6B7280] hover:text-[#E040FB] transition-colors px-2 py-1 rounded hover:bg-[#E040FB]/10"
                    >
                      Ver detalhes
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
