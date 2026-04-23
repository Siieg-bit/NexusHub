import { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { toast } from "sonner";
import { Database, HardDrive, Shield, Zap, CheckCircle2, XCircle, Loader2, ExternalLink } from "lucide-react";

const fadeUp = {
  hidden: { opacity: 0, y: 12 },
  show: (i: number) => ({ opacity: 1, y: 0, transition: { delay: i * 0.06, duration: 0.3, ease: "easeOut" } }),
};

export default function SettingsPage() {
  const [buckets, setBuckets] = useState<{ name: string; public: boolean }[]>([]);
  const [dbStatus, setDbStatus] = useState<"idle" | "loading" | "ok" | "error">("idle");
  const [storageStatus, setStorageStatus] = useState<"idle" | "loading" | "ok" | "error">("idle");
  const [tableCount, setTableCount] = useState<number | null>(null);

  useEffect(() => { checkAll(); }, []);

  async function checkAll() {
    // DB check
    setDbStatus("loading");
    try {
      const { data, error } = await supabase.from("store_items").select("id", { count: "exact", head: true });
      setDbStatus(error ? "error" : "ok");
    } catch { setDbStatus("error"); }

    // Storage check
    setStorageStatus("loading");
    try {
      const { data, error } = await supabase.storage.listBuckets();
      if (!error && data) { setBuckets(data.map(b => ({ name: b.name, public: b.public }))); setStorageStatus("ok"); }
      else setStorageStatus("error");
    } catch { setStorageStatus("error"); }
  }

  async function testConnection() {
    toast.loading("Testando conexão...", { id: "conn" });
    try {
      const { error } = await supabase.from("profiles").select("id", { count: "exact", head: true });
      if (error) throw error;
      toast.success("Conexão OK!", { id: "conn" });
    } catch (e: any) {
      toast.error(`Falha: ${e.message}`, { id: "conn" });
    }
  }

  const StatusIcon = ({ status }: { status: string }) => {
    if (status === "loading") return <Loader2 size={14} className="animate-spin" style={{ color: "#F59E0B" }} />;
    if (status === "ok") return <CheckCircle2 size={14} style={{ color: "#34D399" }} />;
    if (status === "error") return <XCircle size={14} style={{ color: "#FCA5A5" }} />;
    return <div className="w-3.5 h-3.5 rounded-full" style={{ background: "rgba(255,255,255,0.15)" }} />;
  };

  const projectRef = "ylvzqqvcanzzsw jkqeya";

  return (
    <div className="p-4 md:p-6 max-w-4xl mx-auto space-y-5">
      {/* Header */}
      <motion.div variants={fadeUp} initial="hidden" animate="show" custom={0}>
        <h1 className="text-[20px] font-bold tracking-tight" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.95)" }}>
          Configurações
        </h1>
        <p className="text-[12px] font-mono mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>
          Diagnóstico e informações do sistema
        </p>
      </motion.div>

      {/* Status Cards */}
      <motion.div variants={fadeUp} initial="hidden" animate="show" custom={1} className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        {[
          { label: "Banco de Dados", desc: "Supabase PostgreSQL", status: dbStatus, icon: Database, color: "#A78BFA", rgb: "167,139,250" },
          { label: "Storage", desc: `${buckets.length} buckets`, status: storageStatus, icon: HardDrive, color: "#06B6D4", rgb: "6,182,212" },
        ].map(({ label, desc, status, icon: Icon, color, rgb }) => (
          <div key={label} className="p-4 rounded-2xl flex items-center gap-4"
            style={{ background: `rgba(${rgb},0.05)`, border: `1px solid rgba(${rgb},0.15)` }}
          >
            <div className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0"
              style={{ background: `rgba(${rgb},0.1)`, border: `1px solid rgba(${rgb},0.2)` }}
            >
              <Icon size={18} style={{ color }} />
            </div>
            <div className="flex-1">
              <div className="text-[13px] font-semibold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.9)" }}>{label}</div>
              <div className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.35)" }}>{desc}</div>
            </div>
            <StatusIcon status={status} />
          </div>
        ))}
      </motion.div>

      {/* Project Info */}
      <motion.div variants={fadeUp} initial="hidden" animate="show" custom={2}
        className="p-5 rounded-2xl space-y-3"
        style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}
      >
        <div className="flex items-center gap-2 mb-3">
          <Zap size={13} style={{ color: "#A78BFA" }} />
          <span className="text-[11px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.4)" }}>Projeto Supabase</span>
        </div>
        {[
          { label: "Project Ref", value: "ylvzqqvcanzzsw jkqeya" },
          { label: "URL", value: "https://ylvzqqvcanzzsw jkqeya.supabase.co" },
          { label: "Region", value: "us-east-1" },
          { label: "Auth Provider", value: "Email + Google OAuth" },
        ].map(({ label, value }) => (
          <div key={label} className="flex items-center justify-between py-2" style={{ borderBottom: "1px solid rgba(255,255,255,0.05)" }}>
            <span className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.35)" }}>{label}</span>
            <span className="text-[12px] font-mono" style={{ color: "rgba(255,255,255,0.7)" }}>{value}</span>
          </div>
        ))}
      </motion.div>

      {/* Storage Buckets */}
      {buckets.length > 0 && (
        <motion.div variants={fadeUp} initial="hidden" animate="show" custom={3}
          className="p-5 rounded-2xl"
          style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}
        >
          <div className="flex items-center gap-2 mb-4">
            <HardDrive size={13} style={{ color: "#06B6D4" }} />
            <span className="text-[11px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.4)" }}>Storage Buckets ({buckets.length})</span>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
            {buckets.map(b => (
              <div key={b.name} className="flex items-center gap-2 p-2.5 rounded-xl"
                style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.06)" }}
              >
                <div className="w-1.5 h-1.5 rounded-full flex-shrink-0" style={{ background: b.public ? "#34D399" : "#F59E0B" }} />
                <span className="text-[11px] font-mono truncate" style={{ color: "rgba(255,255,255,0.6)" }}>{b.name}</span>
              </div>
            ))}
          </div>
        </motion.div>
      )}

      {/* Actions */}
      <motion.div variants={fadeUp} initial="hidden" animate="show" custom={4} className="flex flex-col sm:flex-row gap-3">
        <button
          onClick={testConnection}
          className="flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl text-[13px] font-semibold transition-all duration-150"
          style={{ background: "rgba(124,58,237,0.1)", border: "1px solid rgba(124,58,237,0.25)", color: "#A78BFA", fontFamily: "'Space Grotesk', sans-serif" }}
        >
          <Zap size={13} />
          Testar Conexão
        </button>
        <a
          href="https://supabase.com/dashboard/project/ylvzqqvcanzzsw jkqeya"
          target="_blank" rel="noopener noreferrer"
          className="flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl text-[13px] font-semibold transition-all duration-150"
          style={{ background: "rgba(6,182,212,0.08)", border: "1px solid rgba(6,182,212,0.2)", color: "#67E8F9", fontFamily: "'Space Grotesk', sans-serif" }}
        >
          <ExternalLink size={13} />
          Supabase Dashboard
        </a>
        <a
          href="https://github.com/Siieg-bit/NexusHub"
          target="_blank" rel="noopener noreferrer"
          className="flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl text-[13px] font-semibold transition-all duration-150"
          style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.5)", fontFamily: "'Space Grotesk', sans-serif" }}
        >
          <Shield size={13} />
          GitHub Repository
        </a>
      </motion.div>
    </div>
  );
}
