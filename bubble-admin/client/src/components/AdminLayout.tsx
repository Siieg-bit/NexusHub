import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  LayoutDashboard, ShoppingBag, MessageSquare, Frame, Smile,
  Palette, Users, ArrowLeftRight, Settings, LogOut, Menu, X,
  Zap, ChevronRight, Search, Shield, Globe, Trophy, Bell, Crown,
  Bot, Fingerprint, BarChart3
} from "lucide-react";
import { useAuth } from "@/contexts/AuthContext";
import { TEAM_ROLE_CONFIG } from "@/lib/supabase";

export type AdminSection =
  | "overview"
  | "store-items"
  | "bubbles"
  | "frames"
  | "stickers"
  | "themes"
  | "users"
  | "moderation"
  | "communities"
  | "achievements"
  | "broadcast"
  | "transactions"
  | "settings"
  | "founder"
  | "ai-characters"
  | "device-security"
  | "economy";

interface AdminLayoutProps {
  activeSection: AdminSection;
  onSectionChange: (section: AdminSection) => void;
  children: React.ReactNode;
}

const navGroups = [
  {
    label: "Principal",
    items: [
      { id: "overview" as AdminSection, icon: LayoutDashboard, label: "Visão Geral", hex: "#8B5CF6", rgb: "139,92,246" },
    ],
  },
  {
    label: "Loja",
    items: [
      { id: "store-items" as AdminSection, icon: ShoppingBag, label: "Produtos", hex: "#EC4899", rgb: "236,72,153" },
      { id: "transactions" as AdminSection, icon: ArrowLeftRight, label: "Transações", hex: "#06B6D4", rgb: "6,182,212" },
    ],
  },
  {
    label: "Cosméticos",
    items: [
      { id: "bubbles" as AdminSection, icon: MessageSquare, label: "Chat Bubbles", hex: "#A78BFA", rgb: "167,139,250" },
      { id: "frames" as AdminSection, icon: Frame, label: "Molduras", hex: "#F59E0B", rgb: "245,158,11" },
      { id: "stickers" as AdminSection, icon: Smile, label: "Stickers", hex: "#10B981", rgb: "16,185,129" },
      { id: "themes" as AdminSection, icon: Palette, label: "Temas", hex: "#F472B6", rgb: "244,114,182" },
    ],
  },
  {
    label: "Gestão",
    items: [
      { id: "users" as AdminSection, icon: Users, label: "Usuários", hex: "#67E8F9", rgb: "103,232,249" },
      { id: "moderation" as AdminSection, icon: Shield, label: "Moderação", hex: "#EF4444", rgb: "239,68,68" },
      { id: "communities" as AdminSection, icon: Globe, label: "Comunidades", hex: "#34D399", rgb: "52,211,153" },
      { id: "achievements" as AdminSection, icon: Trophy, label: "Conquistas", hex: "#FBBF24", rgb: "251,191,36" },
      { id: "broadcast" as AdminSection, icon: Bell, label: "Broadcast", hex: "#F97316", rgb: "249,115,22" },
      { id: "settings" as AdminSection, icon: Settings, label: "Configurações", hex: "#94A3B8", rgb: "148,163,184" },
    ],
  },
  {
    label: "Avançado",
    items: [
      { id: "ai-characters" as AdminSection, icon: Bot, label: "AI Studio", hex: "#8B5CF6", rgb: "139,92,246" },
      { id: "device-security" as AdminSection, icon: Fingerprint, label: "Device Security", hex: "#EF4444", rgb: "239,68,68" },
      { id: "economy" as AdminSection, icon: BarChart3, label: "Economy", hex: "#22C55E", rgb: "34,197,94" },
    ],
  },
];

export default function AdminLayout({ activeSection, onSectionChange, children }: AdminLayoutProps) {
  const { auth, signOut, isFounder, isCoFounderOrAbove, canManageTeamRoles, teamRole } = useAuth();
  const [mobileOpen, setMobileOpen] = useState(false);
  const [collapsed, setCollapsed] = useState(false);

  useEffect(() => { setMobileOpen(false); }, [activeSection]);

  useEffect(() => {
    const handler = () => { if (window.innerWidth >= 1024) setMobileOpen(false); };
    window.addEventListener("resize", handler);
    return () => window.removeEventListener("resize", handler);
  }, []);

  // Grupo exclusivo do Founder/Co-Founder/Team Admin
  const founderGroup = canManageTeamRoles ? [{
    label: isFounder ? "Founder" : isCoFounderOrAbove ? "Co-Founder" : "Admin",
    items: [
      { id: "founder" as AdminSection, icon: Crown, label: isFounder ? "Founder Panel" : isCoFounderOrAbove ? "Co-Founder Panel" : "Admin Panel", hex: isFounder ? "#FFFFFF" : isCoFounderOrAbove ? "#FFD700" : "#FF4444", rgb: isFounder ? "255,255,255" : isCoFounderOrAbove ? "255,215,0" : "255,68,68" },
    ],
  }] : [];
  const allNavGroups = [...founderGroup, ...navGroups];
  const activeItem = allNavGroups.flatMap(g => g.items).find(i => i.id === activeSection);

  const SidebarInner = () => (
    <div className="flex flex-col h-full overflow-hidden">
      {/* Logo */}
      <div className="px-4 pt-5 pb-4 flex-shrink-0">
        <div className="flex items-center gap-3">
          <div className="relative flex-shrink-0">
            <div
              className="w-8 h-8 rounded-xl flex items-center justify-center"
              style={{
                background: "linear-gradient(135deg, #7C3AED, #EC4899)",
                boxShadow: "0 0 16px rgba(124,58,237,0.5), 0 0 32px rgba(124,58,237,0.2)",
              }}
            >
              <Zap size={14} className="text-white" fill="white" />
            </div>
            <div
              className="absolute -top-0.5 -right-0.5 w-2 h-2 rounded-full"
              style={{ background: "#10B981", border: "1.5px solid #080B12", boxShadow: "0 0 6px rgba(16,185,129,0.6)" }}
            />
          </div>
          {!collapsed && (
            <div>
              <div
                className="text-[14px] font-bold tracking-tight leading-none"
                style={{
                  fontFamily: "'Space Grotesk', sans-serif",
                  background: "linear-gradient(135deg, #C4B5FD, #7C3AED)",
                  WebkitBackgroundClip: "text",
                  WebkitTextFillColor: "transparent",
                  backgroundClip: "text",
                }}
              >
                NexusHub
              </div>
              <div className="text-[9px] font-mono tracking-[0.18em] mt-0.5" style={{ color: "rgba(255,255,255,0.22)" }}>
                ADMIN PANEL
              </div>
            </div>
          )}
        </div>
      </div>

      <div className="nx-divider mx-3 mb-3 flex-shrink-0" />

      {/* Nav */}
      <nav className="flex-1 px-2 overflow-y-auto space-y-4 pb-2">
        {allNavGroups.map((group) => (
          <div key={group.label}>
            {!collapsed && (
              <div className="text-[9px] font-mono tracking-[0.16em] uppercase mb-1 px-2" style={{ color: "rgba(255,255,255,0.18)" }}>
                {group.label}
              </div>
            )}
            <div className="space-y-0.5">
              {group.items.map((item) => {
                const Icon = item.icon;
                const isActive = activeSection === item.id;
                return (
                  <motion.button
                    key={item.id}
                    onClick={() => onSectionChange(item.id)}
                    className="w-full"
                    whileTap={{ scale: 0.97 }}
                  >
                    <div
                      className="relative flex items-center gap-2.5 px-2.5 py-2 rounded-xl transition-all duration-150"
                      style={{
                        background: isActive ? `rgba(${item.rgb},0.1)` : "transparent",
                        border: isActive ? `1px solid rgba(${item.rgb},0.22)` : "1px solid transparent",
                      }}
                    >
                      {isActive && (
                        <motion.div
                          layoutId="sidebarActive"
                          className="absolute left-0 top-1/4 bottom-1/4 w-0.5 rounded-r"
                          style={{ background: item.hex }}
                          transition={{ type: "spring", stiffness: 500, damping: 35 }}
                        />
                      )}
                      <div
                        className="flex-shrink-0 w-6 h-6 rounded-lg flex items-center justify-center"
                        style={{
                          background: isActive ? `rgba(${item.rgb},0.18)` : "rgba(255,255,255,0.05)",
                        }}
                      >
                        <Icon size={13} style={{ color: isActive ? item.hex : "rgba(255,255,255,0.35)" }} />
                      </div>
                      {!collapsed && (
                        <span
                          className="text-[12.5px] font-medium flex-1 text-left"
                          style={{
                            fontFamily: "'Space Grotesk', sans-serif",
                            color: isActive ? item.hex : "rgba(255,255,255,0.5)",
                          }}
                        >
                          {item.label}
                        </span>
                      )}
                      {!collapsed && isActive && (
                        <ChevronRight size={11} style={{ color: item.hex, opacity: 0.6 }} />
                      )}
                    </div>
                  </motion.button>
                );
              })}
            </div>
          </div>
        ))}
      </nav>

      {/* User */}
      <div className="p-2 flex-shrink-0">
        <div className="nx-divider mb-2" />
        <div
          className="flex items-center gap-2.5 p-2 rounded-xl cursor-pointer transition-all duration-150 hover:bg-white/5"
          style={{ border: "1px solid rgba(255,255,255,0.05)" }}
          onClick={signOut}
          title="Sair"
        >
          <div
            className="w-6 h-6 rounded-lg flex items-center justify-center flex-shrink-0 text-[11px] font-bold"
            style={{
              background: "linear-gradient(135deg, rgba(124,58,237,0.35), rgba(236,72,153,0.25))",
              color: "#C4B5FD",
              fontFamily: "'Space Grotesk', sans-serif",
            }}
          >
            {("user" in auth ? auth.user : undefined)?.email?.charAt(0).toUpperCase() ?? "A"}
          </div>
          {!collapsed && (
            <>
              <div className="flex-1 min-w-0">
                <div className="text-[11.5px] font-medium truncate" style={{ color: "rgba(255,255,255,0.75)", fontFamily: "'Space Grotesk', sans-serif" }}>
                  {("user" in auth ? auth.user : undefined)?.email?.split("@")[0] ?? "Admin"}
                </div>
                <div className="text-[9px] font-mono tracking-wider" style={{ color: teamRole && TEAM_ROLE_CONFIG[teamRole] ? TEAM_ROLE_CONFIG[teamRole].color + "99" : "rgba(255,255,255,0.22)" }}>{teamRole && TEAM_ROLE_CONFIG[teamRole] ? TEAM_ROLE_CONFIG[teamRole].label.toUpperCase() : "TEAM MEMBER"}</div>
              </div>
              <LogOut size={12} style={{ color: "rgba(255,255,255,0.2)", flexShrink: 0 }} />
            </>
          )}
        </div>
      </div>
    </div>
  );

  return (
    <div className="flex h-screen overflow-hidden" style={{ background: "#05060A" }}>

      {/* Sidebar Desktop */}
      <motion.aside
        animate={{ width: collapsed ? 60 : 210 }}
        transition={{ type: "spring", stiffness: 400, damping: 35 }}
        className="hidden lg:flex flex-col flex-shrink-0 relative z-20"
        style={{
          background: "rgba(8,11,18,0.97)",
          borderRight: "1px solid rgba(255,255,255,0.055)",
          backdropFilter: "blur(20px)",
        }}
      >
        {/* Collapse toggle */}
        <button
          onClick={() => setCollapsed(!collapsed)}
          className="absolute -right-3 top-7 z-30 w-6 h-6 rounded-full flex items-center justify-center transition-all duration-150 hover:scale-110"
          style={{
            background: "#111827",
            border: "1px solid rgba(255,255,255,0.1)",
            color: "rgba(255,255,255,0.4)",
          }}
        >
          <motion.div animate={{ rotate: collapsed ? 0 : 180 }} transition={{ duration: 0.2 }}>
            <ChevronRight size={10} />
          </motion.div>
        </button>
        <SidebarInner />
      </motion.aside>

      {/* Sidebar Mobile Overlay */}
      <AnimatePresence>
        {mobileOpen && (
          <>
            <motion.div
              key="overlay"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.18 }}
              className="fixed inset-0 z-40 lg:hidden"
              style={{ background: "rgba(0,0,0,0.75)", backdropFilter: "blur(4px)" }}
              onClick={() => setMobileOpen(false)}
            />
            <motion.aside
              key="mobile-sidebar"
              initial={{ x: -220 }}
              animate={{ x: 0 }}
              exit={{ x: -220 }}
              transition={{ type: "spring", stiffness: 400, damping: 35 }}
              className="fixed left-0 top-0 bottom-0 z-50 w-[210px] lg:hidden"
              style={{
                background: "rgba(8,11,18,0.99)",
                borderRight: "1px solid rgba(255,255,255,0.06)",
                backdropFilter: "blur(20px)",
              }}
            >
              <button
                onClick={() => setMobileOpen(false)}
                className="absolute top-4 right-3 w-6 h-6 rounded-lg flex items-center justify-center"
                style={{ background: "rgba(255,255,255,0.06)", color: "rgba(255,255,255,0.5)" }}
              >
                <X size={12} />
              </button>
              <SidebarInner />
            </motion.aside>
          </>
        )}
      </AnimatePresence>

      {/* Main */}
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">

        {/* Top Bar */}
        <header
          className="flex-shrink-0 flex items-center justify-between px-4 md:px-5 h-13"
          style={{
            background: "rgba(5,6,10,0.85)",
            borderBottom: "1px solid rgba(255,255,255,0.05)",
            backdropFilter: "blur(20px)",
            height: "52px",
          }}
        >
          <div className="flex items-center gap-3">
            <button
              onClick={() => setMobileOpen(true)}
              className="lg:hidden w-7 h-7 rounded-lg flex items-center justify-center"
              style={{ background: "rgba(255,255,255,0.05)", color: "rgba(255,255,255,0.55)" }}
            >
              <Menu size={14} />
            </button>
            <div className="flex items-center gap-1.5">
              <span className="text-[10px] font-mono tracking-widest hidden sm:block" style={{ color: "rgba(255,255,255,0.18)" }}>
                NEXUSHUB
              </span>
              <span className="hidden sm:block" style={{ color: "rgba(255,255,255,0.12)" }}>/</span>
              <span
                className="text-[13px] font-semibold"
                style={{ fontFamily: "'Space Grotesk', sans-serif", color: activeItem?.hex ?? "#A78BFA" }}
              >
                {activeItem?.label ?? "Dashboard"}
              </span>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <div
              className="hidden sm:flex items-center gap-2 px-2.5 py-1.5 rounded-lg text-[11px] cursor-pointer transition-all duration-150 hover:bg-white/5"
              style={{
                background: "rgba(255,255,255,0.03)",
                border: "1px solid rgba(255,255,255,0.06)",
                color: "rgba(255,255,255,0.22)",
                fontFamily: "'Space Mono', monospace",
              }}
            >
              <Search size={10} />
              <span>Buscar...</span>
            </div>
            <div
              className="flex items-center gap-1.5 px-2 py-1.5 rounded-lg"
              style={{ background: "rgba(16,185,129,0.07)", border: "1px solid rgba(16,185,129,0.13)" }}
            >
              <div className="nx-pulse-dot" />
              <span className="text-[9.5px] font-mono hidden sm:block" style={{ color: "#34D399" }}>ONLINE</span>
            </div>
          </div>
        </header>

        {/* Page Content */}
        <main
          className="flex-1 overflow-y-auto"
          style={{
            background: "radial-gradient(ellipse 80% 50% at 20% -10%, rgba(124,58,237,0.055) 0%, transparent 60%), radial-gradient(ellipse 60% 40% at 80% 110%, rgba(236,72,153,0.035) 0%, transparent 50%), #05060A",
          }}
        >
          <motion.div
            key={activeSection}
            initial={{ opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.18, ease: "easeOut" }}
            className="h-full"
          >
            {children}
          </motion.div>
        </main>
      </div>
    </div>
  );
}
