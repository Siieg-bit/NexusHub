import { useState, ReactNode } from "react";
import { useAuth } from "@/contexts/AuthContext";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  LogOut,
  Sparkles,
  LayoutDashboard,
  ShoppingBag,
  MessageCircle,
  Frame,
  Palette,
  Package,
  Users,
  ArrowLeftRight,
  Settings,
  ChevronLeft,
  ChevronRight,
  Sticker,
} from "lucide-react";

export type AdminSection =
  | "overview"
  | "store-items"
  | "bubbles"
  | "frames"
  | "stickers"
  | "themes"
  | "users"
  | "transactions"
  | "settings";

type NavItem = {
  id: AdminSection;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  badge?: string;
};

const NAV_ITEMS: NavItem[] = [
  { id: "overview", label: "Visão Geral", icon: LayoutDashboard },
  { id: "store-items", label: "Produtos", icon: ShoppingBag },
  { id: "bubbles", label: "Chat Bubbles", icon: MessageCircle },
  { id: "frames", label: "Molduras", icon: Frame },
  { id: "stickers", label: "Stickers", icon: Sticker },
  { id: "themes", label: "Temas", icon: Palette },
  { id: "users", label: "Usuários", icon: Users },
  { id: "transactions", label: "Transações", icon: ArrowLeftRight },
  { id: "settings", label: "Configurações", icon: Settings },
];

type AdminLayoutProps = {
  activeSection: AdminSection;
  onSectionChange: (section: AdminSection) => void;
  children: ReactNode;
};

export default function AdminLayout({
  activeSection,
  onSectionChange,
  children,
}: AdminLayoutProps) {
  const { auth, signOut } = useAuth();
  const profile = auth.status === "authenticated" ? auth.profile : null;
  const [collapsed, setCollapsed] = useState(false);

  return (
    <div
      className="min-h-screen bg-[#111214] text-white flex"
      style={{ fontFamily: "'DM Sans', sans-serif" }}
    >
      {/* Background grid */}
      <div
        className="fixed inset-0 pointer-events-none"
        style={{
          backgroundImage:
            "radial-gradient(circle, #2A2D34 1px, transparent 1px)",
          backgroundSize: "28px 28px",
          opacity: 0.25,
        }}
      />

      {/* Sidebar */}
      <aside
        className={`relative z-20 flex flex-col border-r border-[#2A2D34] bg-[#111214]/95 backdrop-blur-sm transition-all duration-200 ${
          collapsed ? "w-16" : "w-56"
        }`}
        style={{ minHeight: "100vh" }}
      >
        {/* Logo */}
        <div className="flex items-center gap-3 px-4 h-14 border-b border-[#2A2D34] flex-shrink-0">
          <div className="w-7 h-7 rounded-lg bg-[#E040FB]/20 border border-[#E040FB]/40 flex items-center justify-center flex-shrink-0">
            <Sparkles className="w-3.5 h-3.5 text-[#E040FB]" />
          </div>
          {!collapsed && (
            <div className="flex flex-col min-w-0">
              <span className="font-bold text-white text-sm tracking-tight truncate">
                NexusHub Admin
              </span>
              <Badge
                className="text-[9px] px-1 py-0 h-3.5 bg-[#E040FB]/15 text-[#E040FB] border-[#E040FB]/30 w-fit"
                style={{ fontFamily: "'DM Mono', monospace" }}
              >
                TEAM ONLY
              </Badge>
            </div>
          )}
        </div>

        {/* Nav items */}
        <nav className="flex-1 py-3 px-2 flex flex-col gap-0.5 overflow-y-auto">
          {NAV_ITEMS.map((item) => {
            const Icon = item.icon;
            const isActive = activeSection === item.id;
            return (
              <button
                key={item.id}
                onClick={() => onSectionChange(item.id)}
                className={`flex items-center gap-3 px-2.5 py-2 rounded-md text-sm font-medium transition-all duration-150 w-full text-left ${
                  isActive
                    ? "bg-[#E040FB]/15 text-[#E040FB] border border-[#E040FB]/25"
                    : "text-[#6B7280] hover:text-[#9CA3AF] hover:bg-[#1C1E22]"
                }`}
                title={collapsed ? item.label : undefined}
              >
                <Icon className="w-4 h-4 flex-shrink-0" />
                {!collapsed && (
                  <span className="truncate">{item.label}</span>
                )}
                {!collapsed && item.badge && (
                  <span className="ml-auto text-[10px] bg-[#E040FB]/20 text-[#E040FB] px-1.5 py-0.5 rounded-full">
                    {item.badge}
                  </span>
                )}
              </button>
            );
          })}
        </nav>

        {/* User + collapse */}
        <div className="border-t border-[#2A2D34] p-2 flex-shrink-0">
          {!collapsed && profile && (
            <div className="flex items-center gap-2 px-2 py-1.5 mb-1">
              <div className="w-6 h-6 rounded-full bg-[#E040FB]/20 border border-[#E040FB]/30 flex items-center justify-center flex-shrink-0">
                {profile.icon_url ? (
                  <img
                    src={profile.icon_url}
                    alt={profile.nickname}
                    className="w-6 h-6 rounded-full object-cover"
                  />
                ) : (
                  <span className="text-[10px] text-[#E040FB] font-bold">
                    {profile.nickname[0]?.toUpperCase()}
                  </span>
                )}
              </div>
              <span
                className="text-[#9CA3AF] text-xs truncate"
                style={{ fontFamily: "'DM Mono', monospace" }}
              >
                {profile.nickname}
              </span>
            </div>
          )}
          <div className="flex gap-1">
            <Button
              variant="ghost"
              size="sm"
              onClick={signOut}
              className="text-[#4B5563] hover:text-red-400 hover:bg-red-500/10 h-8 px-2 flex-1"
              title="Sair"
            >
              <LogOut className="w-3.5 h-3.5" />
              {!collapsed && <span className="ml-1.5 text-xs">Sair</span>}
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setCollapsed(!collapsed)}
              className="text-[#4B5563] hover:text-[#9CA3AF] hover:bg-[#1C1E22] h-8 px-2"
              title={collapsed ? "Expandir" : "Recolher"}
            >
              {collapsed ? (
                <ChevronRight className="w-3.5 h-3.5" />
              ) : (
                <ChevronLeft className="w-3.5 h-3.5" />
              )}
            </Button>
          </div>
        </div>
      </aside>

      {/* Main content */}
      <main className="flex-1 relative z-10 overflow-auto min-h-screen">
        {children}
      </main>
    </div>
  );
}
