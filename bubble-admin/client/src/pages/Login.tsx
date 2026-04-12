/**
 * Login — Stark Admin Precision
 * Dark neutral bg #111214, accent rosa #E040FB, DM Sans + DM Mono
 */
import { useState } from "react";
import { useAuth } from "@/contexts/AuthContext";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Loader2, Sparkles } from "lucide-react";

export default function Login() {
  const { signIn } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    const err = await signIn(email, password);
    if (err) setError(err);
    setLoading(false);
  }

  return (
    <div className="min-h-screen bg-[#111214] flex items-center justify-center px-4">
      {/* Background grid dots */}
      <div
        className="fixed inset-0 pointer-events-none"
        style={{
          backgroundImage:
            "radial-gradient(circle, #2A2D34 1px, transparent 1px)",
          backgroundSize: "28px 28px",
          opacity: 0.5,
        }}
      />

      <div className="relative w-full max-w-sm">
        {/* Logo / Brand */}
        <div className="mb-8 text-center">
          <div className="inline-flex items-center gap-2 mb-3">
            <div className="w-8 h-8 rounded-lg bg-[#E040FB]/20 border border-[#E040FB]/40 flex items-center justify-center">
              <Sparkles className="w-4 h-4 text-[#E040FB]" />
            </div>
            <span
              className="text-white font-bold text-lg tracking-tight"
              style={{ fontFamily: "'DM Sans', sans-serif" }}
            >
              NexusHub
            </span>
          </div>
          <h1
            className="text-2xl font-bold text-white mb-1"
            style={{ fontFamily: "'DM Sans', sans-serif" }}
          >
            Bubble Studio
          </h1>
          <p
            className="text-[#9CA3AF] text-sm"
            style={{ fontFamily: "'DM Mono', monospace" }}
          >
            Acesso restrito — Team Members
          </p>
        </div>

        {/* Card */}
        <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl p-6 shadow-2xl">
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-1.5">
              <Label
                htmlFor="email"
                className="text-[#9CA3AF] text-xs uppercase tracking-widest"
                style={{ fontFamily: "'DM Mono', monospace" }}
              >
                Email
              </Label>
              <Input
                id="email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="seu@email.com"
                required
                className="bg-[#111214] border-[#2A2D34] text-white placeholder:text-[#4B5563] focus:border-[#E040FB] focus:ring-[#E040FB]/20 h-10"
                style={{ fontFamily: "'DM Mono', monospace", fontSize: "13px" }}
              />
            </div>

            <div className="space-y-1.5">
              <Label
                htmlFor="password"
                className="text-[#9CA3AF] text-xs uppercase tracking-widest"
                style={{ fontFamily: "'DM Mono', monospace" }}
              >
                Senha
              </Label>
              <Input
                id="password"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                required
                className="bg-[#111214] border-[#2A2D34] text-white placeholder:text-[#4B5563] focus:border-[#E040FB] focus:ring-[#E040FB]/20 h-10"
              />
            </div>

            {error && (
              <div className="bg-red-500/10 border border-red-500/30 rounded-lg px-3 py-2">
                <p
                  className="text-red-400 text-xs"
                  style={{ fontFamily: "'DM Mono', monospace" }}
                >
                  {error}
                </p>
              </div>
            )}

            <Button
              type="submit"
              disabled={loading}
              className="w-full h-10 bg-[#E040FB] hover:bg-[#CE39E0] text-white font-semibold border-0 transition-all duration-200"
              style={{ fontFamily: "'DM Sans', sans-serif" }}
            >
              {loading ? (
                <Loader2 className="w-4 h-4 animate-spin" />
              ) : (
                "Entrar"
              )}
            </Button>
          </form>
        </div>

        <p
          className="text-center text-[#4B5563] text-xs mt-4"
          style={{ fontFamily: "'DM Mono', monospace" }}
        >
          Apenas is_team_admin ou is_team_moderator
        </p>
      </div>
    </div>
  );
}
