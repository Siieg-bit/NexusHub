import { useState, ReactNode, useEffect } from "react";
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
  Menu,
  X,
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

  // Desktop: sidebar colapsável. Mobile: drawer (oculto por padrão)
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  // Fechar drawer ao redimensionar para desktop
  useEffect(() => {
    const handleResize = () => {
      if (window.innerWidth >= 768) setMobileOpen(false);
    };
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  // Fechar drawer ao trocar de seção no mobile
  function handleSectionChange(section: AdminSection) {
    onSectionChange(section);
    setMobileOpen(false);
  }

  const SidebarContent = ({ mobile = false }: { mobile?: boolean }) => (
    <>
      {/* Logo */}
      <div className="flex items-center gap-3 px-4 h-14 border-b border-[#2A2D34] flex-shrink-0">
        <div className="w-7 h-7 rounded-lg bg-[#E040FB]/20 border border-[#E040FB]/40 flex items-center justify-center flex-shrink-0">
          <Sparkles className="w-3.5 h-3.5 text-[#E040FB]" />
        </div>
        {(mobile || !collapsed) && (
          <div className="flex flex-col min-w-0 flex-1">
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
        {/* Botão fechar no drawer mobile */}
        {mobile && (
          <button
            onClick={() => setMobileOpen(false)}
            className="ml-auto text-[#6B7280] hover:text-white p-1 rounded-md hover:bg-[#1C1E22] transition-colors"
          >
            <X className="w-4 h-4" />
          </button>
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
              onClick={() => handleSectionChange(item.id)}
              className={`flex items-center gap-3 px-2.5 py-2.5 rounded-md text-sm font-medium transition-all duration-150 w-full text-left ${
                isActive
                  ? "bg-[#E040FB]/15 text-[#E040FB] border border-[#E040FB]/25"
                  : "text-[#6B7280] hover:text-[#9CA3AF] hover:bg-[#1C1E22]"
              }`}
              title={!mobile && collapsed ? item.label : undefined}
            >
              <Icon className="w-4 h-4 flex-shrink-0" />
              {(mobile || !collapsed) && (
                <span className="truncate">{item.label}</span>
              )}
              {(mobile || !collapsed) && item.badge && (
                <span className="ml-auto text-[10px] bg-[#E040FB]/20 text-[#E040FB] px-1.5 py-0.5 rounded-full">
                  {item.badge}
                </span>
              )}
            </button>
          );
        })}
      </nav>

      {/* User + ações */}
      <div className="border-t border-[#2A2D34] p-2 flex-shrink-0">
        {(mobile || !collapsed) && profile && (
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
            {(mobile || !collapsed) && (
              <span className="ml-1.5 text-xs">Sair</span>
            )}
          </Button>
          {/* Botão colapsar — apenas desktop */}
          {!mobile && (
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
          )}
        </div>
      </div>
    </>
  );

  return (
    <div
      className="min-h-screen bg-[#111214] text-white flex flex-col md:flex-row"
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

      {/* ── MOBILE: Overlay escuro ao abrir o drawer ── */}
      {mobileOpen && (
        <div
          className="fixed inset-0 z-30 bg-black/60 backdrop-blur-sm md:hidden"
          onClick={() => setMobileOpen(false)}
        />
      )}

      {/* ── MOBILE: Drawer lateral ── */}
      <aside
        className={`fixed top-0 left-0 h-full z-40 flex flex-col border-r border-[#2A2D34] bg-[#111214]/98 backdrop-blur-sm transition-transform duration-250 w-64 md:hidden ${
          mobileOpen ? "translate-x-0" : "-translate-x-full"
        }`}
      >
        <SidebarContent mobile />
      </aside>

      {/* ── DESKTOP: Sidebar fixa colapsável ── */}
      <aside
        className={`hidden md:flex relative z-20 flex-col border-r border-[#2A2D34] bg-[#111214]/95 backdrop-blur-sm transition-all duration-200 flex-shrink-0 ${
          collapsed ? "w-16" : "w-56"
        }`}
        style={{ minHeight: "100vh" }}
      >
        <SidebarContent />
      </aside>

      {/* ── MOBILE: Header fixo com hambúrguer ── */}
      <header className="md:hidden sticky top-0 z-20 flex items-center gap-3 px-4 h-14 border-b border-[#2A2D34] bg-[#111214]/95 backdrop-blur-sm flex-shrink-0">
        <button
          onClick={() => setMobileOpen(true)}
          className="text-[#6B7280] hover:text-white p-1.5 rounded-md hover:bg-[#1C1E22] transition-colors"
          aria-label="Abrir menu"
        >
          <Menu className="w-5 h-5" />
        </button>
        <div className="w-6 h-6 rounded-lg bg-[#E040FB]/20 border border-[#E040FB]/40 flex items-center justify-center flex-shrink-0">
          <Sparkles className="w-3 h-3 text-[#E040FB]" />
        </div>
        <span className="font-bold text-white text-sm tracking-tight">
          NexusHub Admin
        </span>
        <Badge
          className="text-[9px] px-1 py-0 h-3.5 bg-[#E040FB]/15 text-[#E040FB] border-[#E040FB]/30"
          style={{ fontFamily: "'DM Mono', monospace" }}
        >
          TEAM ONLY
        </Badge>
        {/* Seção ativa no header mobile */}
        <span className="ml-auto text-[#6B7280] text-xs truncate max-w-[120px]">
          {NAV_ITEMS.find((n) => n.id === activeSection)?.label ?? ""}
        </span>
      </header>

      {/* ── Conteúdo principal ── */}
      <main className="flex-1 relative z-10 overflow-auto min-h-0">
        {children}
      </main>
    </div>
  );
}
