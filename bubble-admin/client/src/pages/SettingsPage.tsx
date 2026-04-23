import { useState, useEffect } from "react";
import { supabase } from "@/lib/supabase";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { toast } from "sonner";
import { useAuth } from "@/contexts/AuthContext";
import {
  Settings,
  Shield,
  Database,
  CheckCircle2,
  Loader2,
  RefreshCw,
  ExternalLink,
  Copy,
  Eye,
  EyeOff,
} from "lucide-react";

type StorageBucket = {
  id: string;
  name: string;
  public: boolean;
  file_size_limit: number | null;
  allowed_mime_types: string[] | null;
};

export default function SettingsPage() {
  const { auth } = useAuth();
  const profile = auth.status === "authenticated" ? auth.profile : null;
  const [buckets, setBuckets] = useState<StorageBucket[]>([]);
  const [loadingBuckets, setLoadingBuckets] = useState(true);
  const [showAnonKey, setShowAnonKey] = useState(false);
  const [testingConnection, setTestingConnection] = useState(false);
  const [connectionOk, setConnectionOk] = useState<boolean | null>(null);

  const SUPABASE_URL = "https://ylvzqqvcanzzswjkqeya.supabase.co";
  const ANON_KEY = "sb_publishable_HYsYzaF8DuBgXpqJAICJ1Q_b73GLUeb";

  async function loadBuckets() {
    setLoadingBuckets(true);
    const { data, error } = await supabase.storage.listBuckets();
    if (!error && data) setBuckets(data as StorageBucket[]);
    setLoadingBuckets(false);
  }

  async function testConnection() {
    setTestingConnection(true);
    try {
      const { data, error } = await supabase
        .from("store_stats")
        .select("*")
        .single();
      setConnectionOk(!error && !!data);
    } catch {
      setConnectionOk(false);
    } finally {
      setTestingConnection(false);
    }
  }

  useEffect(() => {
    loadBuckets();
    testConnection();
  }, []);

  function copyToClipboard(text: string, label: string) {
    navigator.clipboard.writeText(text).then(() => {
      toast.success(`${label} copiado!`);
    });
  }

  return (
    <div className="p-4 md:p-6 max-w-4xl mx-auto">
      <div className="mb-6">
        <h1 className="text-xl font-bold text-white">Configurações</h1>
        <p className="text-[#6B7280] text-sm mt-0.5">
          Configurações do painel e informações do sistema
        </p>
      </div>

      <div className="space-y-6">
        {/* Perfil do admin */}
        <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl overflow-hidden">
          <div className="flex items-center gap-2 px-5 py-4 border-b border-[#2A2D34]">
            <Shield className="w-4 h-4 text-[#E040FB]" />
            <h2 className="font-semibold text-white text-sm">
              Perfil Administrativo
            </h2>
          </div>
          <div className="p-5 space-y-4">
            {profile && (
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-full bg-[#E040FB]/20 border border-[#E040FB]/30 flex items-center justify-center overflow-hidden">
                  {profile.icon_url ? (
                    <img
                      src={profile.icon_url}
                      alt={profile.nickname}
                      className="w-full h-full object-cover"
                    />
                  ) : (
                    <span className="text-[#E040FB] font-bold">
                      {profile.nickname[0]?.toUpperCase()}
                    </span>
                  )}
                </div>
                <div>
                  <p className="text-white font-medium">{profile.nickname}</p>
                  <div className="flex gap-2 mt-1">
                    {profile.is_team_admin && (
                      <span className="text-[10px] bg-[#E040FB]/20 text-[#E040FB] border border-[#E040FB]/30 px-1.5 py-0.5 rounded-full">
                        ADMIN
                      </span>
                    )}
                    {profile.is_team_moderator && (
                      <span className="text-[10px] bg-[#60A5FA]/20 text-[#60A5FA] border border-[#60A5FA]/30 px-1.5 py-0.5 rounded-full">
                        MODERADOR
                      </span>
                    )}
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Conexão Supabase */}
        <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl overflow-hidden">
          <div className="flex items-center gap-2 px-5 py-4 border-b border-[#2A2D34]">
            <Database className="w-4 h-4 text-[#60A5FA]" />
            <h2 className="font-semibold text-white text-sm">
              Conexão com Supabase
            </h2>
            <div className="ml-auto flex items-center gap-2">
              {connectionOk === true && (
                <span className="flex items-center gap-1 text-[#4ADE80] text-xs">
                  <CheckCircle2 className="w-3.5 h-3.5" />
                  Conectado
                </span>
              )}
              {connectionOk === false && (
                <span className="text-red-400 text-xs">Erro de conexão</span>
              )}
              <Button
                variant="ghost"
                size="sm"
                onClick={testConnection}
                disabled={testingConnection}
                className="text-[#6B7280] hover:text-white hover:bg-[#2A2D34] h-7 px-2"
              >
                {testingConnection ? (
                  <Loader2 className="w-3.5 h-3.5 animate-spin" />
                ) : (
                  <RefreshCw className="w-3.5 h-3.5" />
                )}
              </Button>
            </div>
          </div>
          <div className="p-5 space-y-4">
            <div className="space-y-1.5">
              <Label className="text-[#9CA3AF] text-xs">URL do Projeto</Label>
              <div className="flex gap-2">
                <Input
                  value={SUPABASE_URL}
                  readOnly
                  className="bg-[#111214] border-[#2A2D34] text-[#9CA3AF] h-9 font-mono text-xs"
                />
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => copyToClipboard(SUPABASE_URL, "URL")}
                  className="text-[#6B7280] hover:text-white hover:bg-[#2A2D34] h-9 px-3"
                >
                  <Copy className="w-3.5 h-3.5" />
                </Button>
                <a
                  href="https://supabase.com/dashboard/project/ylvzqqvcanzzswjkqeya"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <Button
                    variant="ghost"
                    size="sm"
                    className="text-[#6B7280] hover:text-white hover:bg-[#2A2D34] h-9 px-3"
                  >
                    <ExternalLink className="w-3.5 h-3.5" />
                  </Button>
                </a>
              </div>
            </div>
            <div className="space-y-1.5">
              <Label className="text-[#9CA3AF] text-xs">Anon Key</Label>
              <div className="flex gap-2">
                <Input
                  value={showAnonKey ? ANON_KEY : "•".repeat(40)}
                  readOnly
                  className="bg-[#111214] border-[#2A2D34] text-[#9CA3AF] h-9 font-mono text-xs"
                />
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setShowAnonKey(!showAnonKey)}
                  className="text-[#6B7280] hover:text-white hover:bg-[#2A2D34] h-9 px-3"
                >
                  {showAnonKey ? (
                    <EyeOff className="w-3.5 h-3.5" />
                  ) : (
                    <Eye className="w-3.5 h-3.5" />
                  )}
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => copyToClipboard(ANON_KEY, "Anon Key")}
                  className="text-[#6B7280] hover:text-white hover:bg-[#2A2D34] h-9 px-3"
                >
                  <Copy className="w-3.5 h-3.5" />
                </Button>
              </div>
            </div>
          </div>
        </div>

        {/* Storage Buckets */}
        <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl overflow-hidden">
          <div className="flex items-center gap-2 px-5 py-4 border-b border-[#2A2D34]">
            <Settings className="w-4 h-4 text-[#A78BFA]" />
            <h2 className="font-semibold text-white text-sm">
              Storage Buckets
            </h2>
            <Button
              variant="ghost"
              size="sm"
              onClick={loadBuckets}
              className="ml-auto text-[#6B7280] hover:text-white hover:bg-[#2A2D34] h-7 px-2"
            >
              <RefreshCw className="w-3.5 h-3.5" />
            </Button>
          </div>
          <div className="p-5">
            {loadingBuckets ? (
              <div className="flex items-center justify-center h-16">
                <Loader2 className="w-5 h-5 text-[#E040FB] animate-spin" />
              </div>
            ) : buckets.length === 0 ? (
              <p className="text-[#4B5563] text-sm text-center py-4">
                Nenhum bucket encontrado
              </p>
            ) : (
              <div className="space-y-2">
                {buckets.map((bucket) => (
                  <div
                    key={bucket.id}
                    className="flex items-center justify-between p-3 bg-[#111214] rounded-lg border border-[#2A2D34]"
                  >
                    <div>
                      <p className="text-white text-sm font-medium">
                        {bucket.name}
                      </p>
                      <p className="text-[#6B7280] text-xs">
                        {bucket.public ? "Público" : "Privado"}
                        {bucket.file_size_limit
                          ? ` · Limite: ${(bucket.file_size_limit / 1024 / 1024).toFixed(0)}MB`
                          : ""}
                      </p>
                    </div>
                    <span
                      className={`text-xs px-2 py-0.5 rounded-full ${
                        bucket.public
                          ? "bg-[#4ADE80]/10 text-[#4ADE80] border border-[#4ADE80]/30"
                          : "bg-[#6B7280]/10 text-[#6B7280] border border-[#6B7280]/30"
                      }`}
                    >
                      {bucket.public ? "Público" : "Privado"}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Info do sistema */}
        <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl overflow-hidden">
          <div className="flex items-center gap-2 px-5 py-4 border-b border-[#2A2D34]">
            <CheckCircle2 className="w-4 h-4 text-[#4ADE80]" />
            <h2 className="font-semibold text-white text-sm">
              Informações do Sistema
            </h2>
          </div>
          <div className="p-4 md:p-5 grid grid-cols-1 sm:grid-cols-2 gap-3 md:gap-4">
            {[
              { label: "Projeto", value: "NexusHub" },
              { label: "Ref. Supabase", value: "ylvzqqvcanzzswjkqeya" },
              { label: "Região", value: "us-east-1" },
              { label: "Versão do Painel", value: "1.0.0" },
              { label: "Stack Frontend", value: "React 19 + Vite + TailwindCSS 4" },
              { label: "Stack Backend", value: "Supabase (PostgreSQL + RLS)" },
            ].map(({ label, value }) => (
              <div key={label}>
                <p className="text-[#6B7280] text-xs">{label}</p>
                <p className="text-white text-sm font-medium mt-0.5">{value}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
