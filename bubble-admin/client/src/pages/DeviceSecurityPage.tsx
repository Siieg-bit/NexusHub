import { useState, useEffect, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { useAuth } from "@/contexts/AuthContext";
import { toast } from "sonner";
import {
  Shield, Search, Smartphone, AlertTriangle, Ban, CheckCircle,
  RefreshCw, X, ChevronRight, Users, Fingerprint, Wifi,
  Clock, Eye, ShieldAlert, ShieldCheck, Hash, Copy, ExternalLink,
} from "lucide-react";

// ─── Tipos ────────────────────────────────────────────────────────────────────
type DeviceFingerprint = {
  id: string;
  user_id: string;
  device_id: string;
  device_model: string;
  os_version: string;
  ip_address: string | null;
  is_banned: boolean;
  banned_reason: string | null;
  first_seen_at: string;
  last_seen_at: string;
  profile?: {
    nickname: string;
    amino_id: string;
    avatar_url: string | null;
    is_banned: boolean;
  };
};

type DeviceGroup = {
  device_id: string;
  device_model: string;
  os_version: string;
  fingerprints: DeviceFingerprint[];
  has_banned: boolean;
  account_count: number;
};

type BanRecord = {
  id: string;
  user_id: string;
  community_id: string | null;
  reason: string;
  is_permanent: boolean;
  is_active: boolean;
  created_at: string;
  profile?: { nickname: string; amino_id: string };
  community?: { name: string } | null;
};

const fadeUp = {
  hidden: { opacity: 0, y: 8 },
  show: (i: number) => ({ opacity: 1, y: 0, transition: { delay: i * 0.03, duration: 0.2 } }),
};

function timeAgo(date: string) {
  const diff = Date.now() - new Date(date).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 60) return `${mins}min atrás`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h atrás`;
  const days = Math.floor(hrs / 24);
  return `${days}d atrás`;
}

function copyToClipboard(text: string) {
  navigator.clipboard.writeText(text);
  toast.success("Copiado!");
}

// ─── Componente: Card de Dispositivo ─────────────────────────────────────────
function DeviceGroupCard({
  group,
  index,
  onBanDevice,
}: {
  group: DeviceGroup;
  index: number;
  onBanDevice: (deviceId: string) => void;
}) {
  const [expanded, setExpanded] = useState(false);

  return (
    <motion.div
      custom={index}
      variants={fadeUp}
      initial="hidden"
      animate="show"
      className="rounded-xl overflow-hidden"
      style={{
        background: group.has_banned
          ? "rgba(239,68,68,0.04)"
          : group.account_count > 1
          ? "rgba(245,158,11,0.04)"
          : "rgba(255,255,255,0.03)",
        border: group.has_banned
          ? "1px solid rgba(239,68,68,0.2)"
          : group.account_count > 1
          ? "1px solid rgba(245,158,11,0.2)"
          : "1px solid rgba(255,255,255,0.06)",
      }}
    >
      <div
        className="p-4 flex items-center gap-3 cursor-pointer"
        onClick={() => setExpanded((e) => !e)}
      >
        {/* Ícone */}
        <div
          className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0"
          style={{
            background: group.has_banned
              ? "rgba(239,68,68,0.15)"
              : group.account_count > 1
              ? "rgba(245,158,11,0.15)"
              : "rgba(255,255,255,0.05)",
          }}
        >
          {group.has_banned ? (
            <ShieldAlert size={18} style={{ color: "#EF4444" }} />
          ) : group.account_count > 1 ? (
            <AlertTriangle size={18} style={{ color: "#F59E0B" }} />
          ) : (
            <Smartphone size={18} style={{ color: "rgba(255,255,255,0.3)" }} />
          )}
        </div>

        {/* Info */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 mb-0.5">
            <span className="font-mono text-xs text-white truncate">{group.device_id}</span>
            <button
              onClick={(e) => { e.stopPropagation(); copyToClipboard(group.device_id); }}
              className="opacity-40 hover:opacity-80 transition-opacity"
            >
              <Copy size={10} style={{ color: "rgba(255,255,255,0.5)" }} />
            </button>
          </div>
          <p className="text-[11px]" style={{ color: "rgba(255,255,255,0.35)" }}>
            {group.device_model} · {group.os_version.split(" ").slice(0, 2).join(" ")}
          </p>
        </div>

        {/* Badges */}
        <div className="flex items-center gap-2">
          {group.has_banned && (
            <span
              className="text-[9px] font-mono px-2 py-0.5 rounded-full"
              style={{ background: "rgba(239,68,68,0.15)", color: "#EF4444", border: "1px solid rgba(239,68,68,0.25)" }}
            >
              BANIDO
            </span>
          )}
          <span
            className="text-[9px] font-mono px-2 py-0.5 rounded-full flex items-center gap-1"
            style={{
              background: group.account_count > 1 ? "rgba(245,158,11,0.15)" : "rgba(255,255,255,0.05)",
              color: group.account_count > 1 ? "#F59E0B" : "rgba(255,255,255,0.3)",
              border: `1px solid ${group.account_count > 1 ? "rgba(245,158,11,0.25)" : "rgba(255,255,255,0.08)"}`,
            }}
          >
            <Users size={9} />
            {group.account_count} conta{group.account_count !== 1 ? "s" : ""}
          </span>
          <ChevronRight
            size={14}
            style={{
              color: "rgba(255,255,255,0.2)",
              transform: expanded ? "rotate(90deg)" : "rotate(0deg)",
              transition: "transform 0.2s",
            }}
          />
        </div>
      </div>

      {/* Contas vinculadas */}
      <AnimatePresence>
        {expanded && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.2 }}
            className="overflow-hidden"
          >
            <div className="px-4 pb-4" style={{ borderTop: "1px solid rgba(255,255,255,0.06)" }}>
              <p className="text-[10px] font-mono tracking-widest uppercase mt-3 mb-2" style={{ color: "rgba(255,255,255,0.25)" }}>
                Contas vinculadas a este dispositivo
              </p>
              <div className="space-y-2">
                {group.fingerprints.map((fp) => (
                  <div
                    key={fp.id}
                    className="flex items-center gap-3 p-2.5 rounded-lg"
                    style={{
                      background: fp.profile?.is_banned
                        ? "rgba(239,68,68,0.08)"
                        : "rgba(255,255,255,0.03)",
                      border: fp.profile?.is_banned
                        ? "1px solid rgba(239,68,68,0.15)"
                        : "1px solid rgba(255,255,255,0.05)",
                    }}
                  >
                    {fp.profile?.avatar_url ? (
                      <img
                        src={fp.profile.avatar_url}
                        alt={fp.profile.nickname}
                        className="w-8 h-8 rounded-full object-cover flex-shrink-0"
                      />
                    ) : (
                      <div
                        className="w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0"
                        style={{ background: "rgba(255,255,255,0.08)" }}
                      >
                        <span className="text-xs text-white/40">?</span>
                      </div>
                    )}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="text-sm font-medium text-white truncate">
                          {fp.profile?.nickname ?? "Usuário desconhecido"}
                        </span>
                        {fp.profile?.is_banned && (
                          <span
                            className="text-[9px] font-mono px-1.5 py-0.5 rounded-full"
                            style={{ background: "rgba(239,68,68,0.15)", color: "#EF4444" }}
                          >
                            BANIDO
                          </span>
                        )}
                      </div>
                      <div className="flex items-center gap-2 mt-0.5">
                        <span className="text-[10px]" style={{ color: "rgba(255,255,255,0.3)" }}>
                          @{fp.profile?.amino_id ?? "—"}
                        </span>
                        <span className="text-[10px]" style={{ color: "rgba(255,255,255,0.2)" }}>·</span>
                        <span className="text-[10px]" style={{ color: "rgba(255,255,255,0.25)" }}>
                          Último acesso: {timeAgo(fp.last_seen_at)}
                        </span>
                      </div>
                    </div>
                    <div className="flex items-center gap-1">
                      {fp.is_banned ? (
                        <span
                          className="text-[9px] font-mono px-2 py-0.5 rounded-full"
                          style={{ background: "rgba(239,68,68,0.15)", color: "#EF4444", border: "1px solid rgba(239,68,68,0.2)" }}
                        >
                          DISPOSITIVO BANIDO
                        </span>
                      ) : null}
                    </div>
                  </div>
                ))}
              </div>

              {/* Ação: banir dispositivo */}
              {!group.fingerprints.every((fp) => fp.is_banned) && (
                <button
                  onClick={() => onBanDevice(group.device_id)}
                  className="mt-3 w-full py-2 rounded-lg text-xs font-semibold flex items-center justify-center gap-2 transition-all"
                  style={{
                    background: "rgba(239,68,68,0.1)",
                    border: "1px solid rgba(239,68,68,0.25)",
                    color: "#EF4444",
                  }}
                >
                  <Ban size={13} />
                  Banir dispositivo (bloqueia todas as contas vinculadas)
                </button>
              )}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
}

// ─── Página Principal ─────────────────────────────────────────────────────────
export default function DeviceSecurityPage() {
  const { canModerate } = useAuth();
  const [tab, setTab] = useState<"devices" | "bans" | "suspicious">("suspicious");
  const [devices, setDevices] = useState<DeviceGroup[]>([]);
  const [bans, setBans] = useState<BanRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [banTarget, setBanTarget] = useState<string | null>(null);
  const [banReason, setBanReason] = useState("");
  const [banning, setBanning] = useState(false);

  const loadDevices = useCallback(async () => {
    setLoading(true);
    const { data, error } = await supabase.rpc("admin_get_device_fingerprints");
    if (!error && data) {
      setDevices((data as DeviceGroup[]).sort((a, b) => b.account_count - a.account_count));
    } else if (error) {
      console.error("Erro ao carregar dispositivos:", error.message);
    }
    setLoading(false);
  }, []);

  const loadBans = useCallback(async () => {
    const { data, error } = await supabase.rpc("admin_get_active_bans");
    if (!error && data) setBans(data as BanRecord[]);
    else if (error) console.error("Erro ao carregar bans:", error.message);
  }, []);

  useEffect(() => {
    loadDevices();
    loadBans();
  }, [loadDevices, loadBans]);

  async function handleBanDevice(deviceId: string) {
    if (!banReason.trim()) { toast.error("Informe o motivo do ban."); return; }
    setBanning(true);
    const { error } = await supabase.rpc("admin_ban_device", {
      p_device_id: deviceId,
      p_reason: banReason,
    });
    if (error) { toast.error("Erro ao banir dispositivo."); setBanning(false); return; }
    toast.success("Dispositivo banido com sucesso!");
    setBanTarget(null);
    setBanReason("");
    setBanning(false);
    loadDevices();
  }

  const suspicious = devices.filter((d) => d.account_count > 1 || d.has_banned);
  const multiAccount = devices.filter((d) => d.account_count > 1);

  const filteredDevices = (tab === "suspicious" ? suspicious : tab === "devices" ? devices : []).filter(
    (d) =>
      !search ||
      d.device_id.toLowerCase().includes(search.toLowerCase()) ||
      d.device_model.toLowerCase().includes(search.toLowerCase()) ||
      d.fingerprints.some(
        (fp) =>
          fp.profile?.nickname.toLowerCase().includes(search.toLowerCase()) ||
          fp.profile?.amino_id.toLowerCase().includes(search.toLowerCase())
      )
  );

  const filteredBans = bans.filter(
    (b) =>
      !search ||
      b.profile?.nickname.toLowerCase().includes(search.toLowerCase()) ||
      b.profile?.amino_id.toLowerCase().includes(search.toLowerCase()) ||
      b.reason.toLowerCase().includes(search.toLowerCase())
  );

  if (!canModerate) {
    return (
      <div className="flex items-center justify-center h-64">
        <p style={{ color: "rgba(255,255,255,0.3)" }}>Acesso restrito.</p>
      </div>
    );
  }

  return (
    <div className="p-6 space-y-6 max-w-5xl mx-auto">
      {/* Header */}
      <div>
        <div className="flex items-center gap-3 mb-1">
          <div
            className="w-9 h-9 rounded-xl flex items-center justify-center"
            style={{ background: "rgba(239,68,68,0.2)", border: "1px solid rgba(239,68,68,0.4)" }}
          >
            <Fingerprint size={18} style={{ color: "#EF4444" }} />
          </div>
          <h1 className="text-xl font-bold text-white">Device Security</h1>
        </div>
        <p className="text-sm ml-12" style={{ color: "rgba(255,255,255,0.35)" }}>
          Rastreie dispositivos, detecte contas múltiplas e gerencie bans globais
        </p>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-4 gap-3">
        {[
          { label: "Dispositivos", value: devices.length, icon: Smartphone, color: "#60A5FA" },
          { label: "Multi-conta", value: multiAccount.length, icon: AlertTriangle, color: "#F59E0B" },
          { label: "Com banidos", value: devices.filter((d) => d.has_banned).length, icon: ShieldAlert, color: "#EF4444" },
          { label: "Bans ativos", value: bans.length, icon: Ban, color: "#F97316" },
        ].map((s) => (
          <div
            key={s.label}
            className="rounded-xl p-4 flex items-center gap-3"
            style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.06)" }}
          >
            <div
              className="w-9 h-9 rounded-lg flex items-center justify-center flex-shrink-0"
              style={{ background: `${s.color}22` }}
            >
              <s.icon size={16} style={{ color: s.color }} />
            </div>
            <div>
              <p className="text-xl font-bold text-white leading-none">{s.value}</p>
              <p className="text-[10px] font-mono tracking-widest uppercase mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>
                {s.label}
              </p>
            </div>
          </div>
        ))}
      </div>

      {/* Tabs + Search */}
      <div className="flex items-center gap-3">
        <div className="flex gap-1 rounded-xl p-1" style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}>
          {([
            { id: "suspicious", label: "Suspeitos", count: suspicious.length },
            { id: "devices", label: "Todos os Dispositivos", count: devices.length },
            { id: "bans", label: "Bans Ativos", count: bans.length },
          ] as const).map((t) => (
            <button
              key={t.id}
              onClick={() => setTab(t.id)}
              className="px-3 py-1.5 rounded-lg text-xs font-medium transition-all flex items-center gap-1.5"
              style={{
                background: tab === t.id ? "rgba(239,68,68,0.2)" : "transparent",
                color: tab === t.id ? "#F87171" : "rgba(255,255,255,0.35)",
                border: tab === t.id ? "1px solid rgba(239,68,68,0.3)" : "1px solid transparent",
              }}
            >
              {t.label}
              <span
                className="text-[9px] px-1.5 py-0.5 rounded-full"
                style={{
                  background: tab === t.id ? "rgba(239,68,68,0.25)" : "rgba(255,255,255,0.06)",
                  color: tab === t.id ? "#F87171" : "rgba(255,255,255,0.3)",
                }}
              >
                {t.count}
              </span>
            </button>
          ))}
        </div>
        <div
          className="flex-1 flex items-center gap-2 rounded-xl px-3 py-2"
          style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}
        >
          <Search size={14} style={{ color: "rgba(255,255,255,0.3)" }} />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Buscar por @amino_id, nickname ou device_id..."
            className="flex-1 bg-transparent text-sm text-white placeholder-white/25 outline-none"
          />
        </div>
        <button
          onClick={() => { loadDevices(); loadBans(); }}
          className="w-9 h-9 rounded-xl flex items-center justify-center"
          style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}
        >
          <RefreshCw size={14} style={{ color: "rgba(255,255,255,0.4)" }} className={loading ? "animate-spin" : ""} />
        </button>
      </div>

      {/* Conteúdo */}
      {loading ? (
        <div className="flex items-center justify-center h-40">
          <RefreshCw size={20} className="animate-spin" style={{ color: "rgba(255,255,255,0.2)" }} />
        </div>
      ) : tab === "bans" ? (
        /* Lista de Bans */
        <div className="space-y-2">
          {filteredBans.length === 0 ? (
            <div
              className="rounded-xl p-12 flex flex-col items-center justify-center gap-3"
              style={{ background: "rgba(255,255,255,0.02)", border: "1px dashed rgba(255,255,255,0.08)" }}
            >
              <ShieldCheck size={36} style={{ color: "rgba(255,255,255,0.1)" }} />
              <p className="text-sm" style={{ color: "rgba(255,255,255,0.25)" }}>Nenhum ban ativo encontrado.</p>
            </div>
          ) : (
            filteredBans.map((ban, i) => (
              <motion.div
                key={ban.id}
                custom={i}
                variants={fadeUp}
                initial="hidden"
                animate="show"
                className="rounded-xl p-4 flex items-center gap-3"
                style={{
                  background: "rgba(239,68,68,0.04)",
                  border: "1px solid rgba(239,68,68,0.15)",
                }}
              >
                <div
                  className="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0"
                  style={{ background: "rgba(239,68,68,0.15)" }}
                >
                  <Ban size={14} style={{ color: "#EF4444" }} />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-0.5">
                    <span className="text-sm font-medium text-white">
                      {ban.profile?.nickname ?? "Usuário"}
                    </span>
                    <span className="text-xs" style={{ color: "rgba(255,255,255,0.3)" }}>
                      @{ban.profile?.amino_id ?? "—"}
                    </span>
                    {ban.is_permanent && (
                      <span
                        className="text-[9px] font-mono px-1.5 py-0.5 rounded-full"
                        style={{ background: "rgba(239,68,68,0.2)", color: "#EF4444" }}
                      >
                        PERMANENTE
                      </span>
                    )}
                  </div>
                  <p className="text-xs truncate" style={{ color: "rgba(255,255,255,0.4)" }}>
                    {ban.community ? `Comunidade: ${ban.community.name}` : "Ban Global"} · {ban.reason}
                  </p>
                </div>
                <span className="text-[10px] flex-shrink-0" style={{ color: "rgba(255,255,255,0.25)" }}>
                  {timeAgo(ban.created_at)}
                </span>
              </motion.div>
            ))
          )}
        </div>
      ) : (
        /* Lista de Dispositivos */
        <div className="space-y-2">
          {filteredDevices.length === 0 ? (
            <div
              className="rounded-xl p-12 flex flex-col items-center justify-center gap-3"
              style={{ background: "rgba(255,255,255,0.02)", border: "1px dashed rgba(255,255,255,0.08)" }}
            >
              <ShieldCheck size={36} style={{ color: "rgba(255,255,255,0.1)" }} />
              <p className="text-sm" style={{ color: "rgba(255,255,255,0.25)" }}>
                {tab === "suspicious" ? "Nenhum dispositivo suspeito encontrado." : "Nenhum dispositivo encontrado."}
              </p>
            </div>
          ) : (
            filteredDevices.map((group, i) => (
              <DeviceGroupCard
                key={group.device_id}
                group={group}
                index={i}
                onBanDevice={(deviceId) => setBanTarget(deviceId)}
              />
            ))
          )}
        </div>
      )}

      {/* Modal de Ban de Dispositivo */}
      <AnimatePresence>
        {banTarget && (
          <div
            className="fixed inset-0 z-50 flex items-center justify-center p-4"
            style={{ background: "rgba(0,0,0,0.75)", backdropFilter: "blur(6px)" }}
          >
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.95 }}
              className="rounded-2xl p-6 w-full max-w-sm"
              style={{ background: "#1a1a2e", border: "1px solid rgba(239,68,68,0.3)" }}
            >
              <div className="flex items-center gap-3 mb-4">
                <div
                  className="w-10 h-10 rounded-xl flex items-center justify-center"
                  style={{ background: "rgba(239,68,68,0.15)" }}
                >
                  <Ban size={18} style={{ color: "#EF4444" }} />
                </div>
                <div>
                  <h3 className="text-white font-semibold text-sm">Banir Dispositivo</h3>
                  <p className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>{banTarget}</p>
                </div>
              </div>
              <p className="text-xs mb-4" style={{ color: "rgba(255,255,255,0.4)" }}>
                Isso marcará o dispositivo como banido. Todas as contas vinculadas a ele serão impedidas de acessar a plataforma.
              </p>
              <div className="mb-4">
                <label className="block text-[10px] font-mono tracking-widest uppercase mb-1.5" style={{ color: "rgba(255,255,255,0.3)" }}>
                  Motivo *
                </label>
                <textarea
                  value={banReason}
                  onChange={(e) => setBanReason(e.target.value)}
                  placeholder="Ex: Multi-conta de usuário banido..."
                  rows={3}
                  className="w-full rounded-lg px-3 py-2 text-sm text-white placeholder-white/25 outline-none resize-none"
                  style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }}
                />
              </div>
              <div className="flex gap-3">
                <button
                  onClick={() => { setBanTarget(null); setBanReason(""); }}
                  className="flex-1 py-2 rounded-lg text-sm"
                  style={{ background: "rgba(255,255,255,0.06)", color: "rgba(255,255,255,0.5)" }}
                >
                  Cancelar
                </button>
                <button
                  onClick={() => handleBanDevice(banTarget)}
                  disabled={banning}
                  className="flex-1 py-2 rounded-lg text-sm font-semibold flex items-center justify-center gap-2"
                  style={{ background: "rgba(239,68,68,0.8)", color: "white", opacity: banning ? 0.7 : 1 }}
                >
                  {banning ? <RefreshCw size={13} className="animate-spin" /> : <Ban size={13} />}
                  {banning ? "Banindo..." : "Confirmar Ban"}
                </button>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
}
