import { useAuth } from "@/contexts/AuthContext";
import { Button } from "@/components/ui/button";
import { ShieldOff } from "lucide-react";

export default function Unauthorized() {
  const { signOut } = useAuth();

  return (
    <div className="min-h-screen bg-[#111214] flex items-center justify-center px-4">
      <div
        className="fixed inset-0 pointer-events-none"
        style={{
          backgroundImage: "radial-gradient(circle, #2A2D34 1px, transparent 1px)",
          backgroundSize: "28px 28px",
          opacity: 0.5,
        }}
      />
      <div className="relative text-center max-w-sm">
        <div className="w-14 h-14 rounded-2xl bg-red-500/10 border border-red-500/30 flex items-center justify-center mx-auto mb-4">
          <ShieldOff className="w-7 h-7 text-red-400" />
        </div>
        <h1
          className="text-xl font-bold text-white mb-2"
          style={{ fontFamily: "'DM Sans', sans-serif" }}
        >
          Acesso negado
        </h1>
        <p
          className="text-[#9CA3AF] text-sm mb-6"
          style={{ fontFamily: "'DM Mono', monospace" }}
        >
          Sua conta não possui um cargo de equipe NexusHub. Entre em contato com o Founder para obter acesso.
        </p>
        <Button
          onClick={signOut}
          variant="outline"
          className="border-[#2A2D34] text-[#9CA3AF] hover:text-white hover:bg-[#2A2D34]"
        >
          Sair
        </Button>
      </div>
    </div>
  );
}
