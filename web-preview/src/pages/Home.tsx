import { useState, useRef, useEffect, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useApp, getLevelFromRep, type Community, type Badge } from "../contexts/AppContext";
import {
  Search, Bell, ShoppingBag, ChevronLeft, ChevronRight, Heart, MessageCircle,
  Send, Plus, Menu, Users, Hash, MoreHorizontal, Star, Trophy, Crown,
  BookOpen, Globe, Share2, Edit, User, Bookmark, FileText, Image,
  BarChart3, HelpCircle, Smile, Mic, X, LogOut, Flame, Link2, Lock,
  Check, Eye, Settings, Shield, Zap, TrendingUp, Clock, MapPin
} from "lucide-react";
import { toast } from "sonner";

// ============ ANIMATION VARIANTS ============
import type { Variants } from "framer-motion";
const pageVariants: Variants = {
  initial: { opacity: 0, x: 60 },
  animate: { opacity: 1, x: 0 },
  exit: { opacity: 0, x: -60 },
};
const pageTransition = { duration: 0.3, ease: [0.25, 0.1, 0.25, 1] as [number, number, number, number] };
const fadeUp: Variants = {
  initial: { opacity: 0, y: 20 },
  animate: { opacity: 1, y: 0 },
  exit: { opacity: 0, y: -10 },
};
const fadeUpTransition = { duration: 0.35, ease: [0, 0, 0.2, 1] as [number, number, number, number] };
const fadeIn: Variants = {
  initial: { opacity: 0 },
  animate: { opacity: 1 },
  exit: { opacity: 0 },
};
const scaleIn: Variants = {
  initial: { opacity: 0, scale: 0.9 },
  animate: { opacity: 1, scale: 1 },
  exit: { opacity: 0, scale: 0.95 },
};
const slideUp: Variants = {
  initial: { opacity: 0, y: "100%" },
  animate: { opacity: 1, y: 0 },
  exit: { opacity: 0, y: "100%" },
};
const springTransition = { type: "spring" as const, damping: 25, stiffness: 300 };
const stagger: Variants = {
  animate: { transition: { staggerChildren: 0.05 } },
};
const cardItem: Variants = {
  initial: { opacity: 0, y: 15 },
  animate: { opacity: 1, y: 0 },
};

// ============ HELPERS ============
function comingSoon(feature: string) {
  toast(`${feature} - Em breve!`, { description: "Esta funcionalidade será implementada em breve." });
}
function formatNumber(n: number): string {
  if (n >= 1000000) return (n / 1000000).toFixed(1) + "M";
  if (n >= 1000) return (n / 1000).toFixed(1) + "K";
  return n.toString();
}
function getTimeAgo(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

// ============ AMINO MAIN HEADER ============
function AminoMainHeader({ onSearchClick, onBack, title }: { onSearchClick?: () => void; onBack?: () => void; title?: string }) {
  const { currentUser, navigateTo } = useApp();
  return (
    <motion.div initial={{ y: -20, opacity: 0 }} animate={{ y: 0, opacity: 1 }} transition={{ duration: 0.3 }}
      className="flex items-center gap-2 px-3 py-2 bg-[#0f0f1e]/95 backdrop-blur-sm border-b border-white/5 shrink-0" style={{ paddingTop: 38 }}>
      {onBack ? (
        <button onClick={onBack} className="p-1 active:scale-90 transition-transform"><ChevronLeft size={22} className="text-white" /></button>
      ) : (
        <button onClick={() => navigateTo("profile")} className="active:scale-95 transition-transform">
          <img src={currentUser.avatar} className="w-8 h-8 rounded-full object-cover border border-white/10" alt="" />
        </button>
      )}
      {title ? (
        <span className="text-white font-bold text-[15px] flex-1 truncate">{title}</span>
      ) : (
        <div className="flex-1 flex items-center justify-center">
          <span className="text-white font-black text-[16px] tracking-wider">NEXUSHUB</span>
        </div>
      )}
      <button onClick={onSearchClick || (() => comingSoon("Search"))} className="p-1.5 active:scale-90 transition-transform"><Search size={20} className="text-white/70" /></button>
      <div className="flex items-center bg-[#2dbe60] rounded-full px-2 py-0.5 gap-0.5">
        <span className="text-[10px]">🪙</span>
        <span className="text-white text-[11px] font-bold">{currentUser.coins}</span>
      </div>
      <button onClick={() => comingSoon("Notifications")} className="p-1.5 relative active:scale-90 transition-transform">
        <Bell size={20} className="text-white/70" />
        <span className="absolute top-0.5 right-0.5 w-2.5 h-2.5 bg-red-500 rounded-full border border-[#0f0f1e]" />
      </button>
    </motion.div>
  );
}

// ============ BOTTOM NAV ============
function BottomNav() {
  const { activeTab, setActiveTab } = useApp();
  const tabs = [
    { id: "discover", icon: <Search size={22} />, label: "Discover" },
    { id: "communities", icon: <Users size={22} />, label: "Communities" },
    { id: "chats", icon: <MessageCircle size={22} />, label: "Chats" },
    { id: "store", icon: <ShoppingBag size={22} />, label: "Store" },
  ];
  return (
    <div className="sticky bottom-0 z-40 flex bg-[#0b0b18] border-t border-white/5 shrink-0" style={{ paddingBottom: 4 }}>
      {tabs.map(tab => (
        <button key={tab.id} onClick={() => setActiveTab(tab.id)}
          className={`flex-1 flex flex-col items-center py-1.5 gap-0.5 transition-all duration-200 active:scale-90 ${activeTab === tab.id ? "text-[#2dbe60]" : "text-gray-600"}`}>
          <motion.div animate={activeTab === tab.id ? { scale: 1.1, y: -2 } : { scale: 1, y: 0 }} transition={{ type: "spring", stiffness: 400, damping: 20 }}>
            {tab.icon}
          </motion.div>
          <span className="text-[9px] font-medium">{tab.label}</span>
        </button>
      ))}
    </div>
  );
}

// ============ POST CARD ============
function PostCard({ post, onPress, showCommunity = true }: { post: any; onPress: () => void; showCommunity?: boolean }) {
  const { toggleLike } = useApp();
  const authorLevel = getLevelFromRep(post.author.level * 500);
  return (
    <motion.div variants={cardItem} className="bg-[#16162a] rounded-xl mb-2.5 overflow-hidden border border-white/3 active:scale-[0.98] transition-transform">
      <button onClick={onPress} className="w-full text-left p-3">
        {showCommunity && (
          <div className="flex items-center gap-1.5 mb-2">
            <img src={post.communityIcon} className="w-4 h-4 rounded object-cover" alt="" />
            <span className="text-gray-500 text-[10px] font-medium">{post.communityName}</span>
            {post.isPinned && <span className="text-yellow-400 text-[8px] ml-auto">📌 Pinned</span>}
          </div>
        )}
        <div className="flex items-center gap-2.5 mb-2">
          <img src={post.author.avatar} className="w-9 h-9 rounded-full object-cover" alt="" />
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-1.5">
              <span className="text-white text-[13px] font-semibold">{post.author.nickname}</span>
              {post.author.role === "Leader" && <span className="bg-[#2dbe60] text-white text-[7px] px-1 py-px rounded font-bold">Leader</span>}
              {post.author.role === "Curator" && <span className="bg-[#E040FB] text-white text-[7px] px-1 py-px rounded font-bold">Curator</span>}
            </div>
            <div className="flex items-center gap-2">
              <span className="bg-gradient-to-r from-blue-600 to-blue-400 text-white text-[8px] font-bold px-1.5 py-0.5 rounded-full">Lv.{authorLevel.level}</span>
              <span className="text-gray-600 text-[10px]">{getTimeAgo(post.createdAt)}</span>
            </div>
          </div>
        </div>
        <h3 className="text-white font-bold text-[14px] mb-1 leading-snug">{post.title}</h3>
        <p className="text-gray-400 text-[12px] leading-relaxed line-clamp-2">{post.content}</p>
        {post.mediaUrl && <img src={post.mediaUrl} className="w-full rounded-lg mt-2 max-h-[180px] object-cover" alt="" />}
      </button>
      <div className="flex items-center gap-4 px-3 pb-2.5 pt-0.5">
        <button onClick={(e) => { e.stopPropagation(); toggleLike(post.id); }}
          className={`flex items-center gap-1 text-[12px] transition-colors active:scale-90 ${post.isLiked ? "text-red-400" : "text-gray-600"}`}>
          <motion.div animate={post.isLiked ? { scale: [1, 1.3, 1] } : {}} transition={{ duration: 0.3 }}>
            <Heart size={16} fill={post.isLiked ? "currentColor" : "none"} />
          </motion.div>
          <span>{post.likesCount}</span>
        </button>
        <div className="flex items-center gap-1 text-gray-600 text-[12px]"><MessageCircle size={16} /><span>{post.commentsCount}</span></div>
        <div className="flex gap-1.5 ml-auto flex-wrap justify-end">
          {post.tags.slice(0, 2).map((tag: string) => <span key={tag} className="bg-[#1e1e38] text-gray-600 text-[9px] px-2 py-0.5 rounded-full">#{tag}</span>)}
        </div>
      </div>
    </motion.div>
  );
}

// ============ JOIN COMMUNITY SCREEN (First time - like Amino print) ============
function JoinCommunityScreen({ community, onJoin, onClose }: { community: Community; onJoin: () => void; onClose: () => void }) {
  const { categories } = useApp();
  const cat = categories.find(c => c.id === community.categoryId);

  return (
    <motion.div {...pageVariants} className="flex flex-col h-full bg-[#1a1a2e]">
      {/* Header */}
      <div className="flex items-center justify-between px-3 py-2 bg-[#0f0f1e] border-b border-white/5" style={{ paddingTop: 38 }}>
        <button onClick={onClose} className="p-1 active:scale-90 transition-transform"><ChevronLeft size={22} className="text-white" /></button>
        <div className="flex items-center gap-3">
          <button onClick={() => comingSoon("Share Community")} className="p-1 active:scale-90 transition-transform"><Share2 size={20} className="text-white/70" /></button>
          <button onClick={() => comingSoon("Community Options")} className="p-1 active:scale-90 transition-transform"><MoreHorizontal size={20} className="text-white/70" /></button>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto amino-scroll">
        {/* Community Info */}
        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }} className="px-4 pt-5 pb-4">
          <div className="flex items-start gap-4 mb-4">
            <motion.img initial={{ scale: 0.8, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} transition={{ delay: 0.2, type: "spring" }}
              src={community.icon} className="w-24 h-24 rounded-xl object-cover border-2 border-white/10 shadow-lg" alt="" />
            <div className="flex-1 pt-1">
              <h1 className="text-white font-black text-[20px] leading-tight mb-1">{community.name}</h1>
              <p className="text-gray-400 text-[14px] mb-1">{formatNumber(community.members)} Members</p>
              <span className="bg-[#2a2a40] text-gray-300 text-[11px] px-2 py-0.5 rounded font-medium">{community.language.toUpperCase()}</span>
            </div>
          </div>

          {/* Amino ID */}
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.25 }}
            className="bg-[#0f0f1e] rounded-lg px-3 py-2 mb-4 border border-white/5">
            <span className="text-gray-500 text-[11px]">Amino ID: </span>
            <span className="text-white font-bold text-[14px]">{community.aminoId}</span>
          </motion.div>

          {/* Description preview */}
          {community.description && (
            <motion.p initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.3 }}
              className="text-gray-400 text-[13px] leading-relaxed mb-4">{community.description}</motion.p>
          )}

          {/* Tags */}
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.35 }}
            className="flex flex-wrap gap-2 mb-5">
            {community.tags.map(tag => (
              <span key={tag} className="text-[12px] font-semibold px-3 py-1 rounded-full border"
                style={{ borderColor: cat?.color || "#666", color: cat?.color || "#aaa" }}>
                {tag}
              </span>
            ))}
          </motion.div>

          {/* JOIN BUTTON */}
          <motion.button
            initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.4, type: "spring" }}
            whileTap={{ scale: 0.95 }}
            onClick={onJoin}
            className="w-full flex items-center justify-center gap-2 bg-[#00e5c3] text-[#0f0f1e] font-black text-[16px] py-3.5 rounded-lg shadow-lg shadow-[#00e5c3]/20 active:bg-[#00d4b4] transition-colors">
            <Lock size={18} />
            JOIN COMMUNITY
          </motion.button>
        </motion.div>

        {/* Description Section */}
        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.5 }}
          className="px-4 py-4 border-t border-white/5">
          <h3 className="text-white font-bold text-[16px] mb-2">Description</h3>
          <p className="text-gray-300 text-[13px] leading-relaxed">{community.description}</p>
        </motion.div>

        {/* Category */}
        {cat && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.55 }}
            className="px-4 py-3 border-t border-white/5 flex items-center gap-2">
            <span className="text-[16px]">{cat.icon}</span>
            <span className="text-gray-400 text-[13px]">{cat.name}</span>
          </motion.div>
        )}

        {/* Guidelines Preview */}
        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.6 }}
          className="px-4 py-4 border-t border-white/5">
          <h3 className="text-white font-bold text-[14px] mb-2 flex items-center gap-2"><Shield size={16} className="text-[#FF9800]" />Community Guidelines</h3>
          <div className="space-y-1.5">
            {community.guidelines.map((g, i) => (
              <p key={i} className="text-gray-400 text-[12px]">{i + 1}. {g}</p>
            ))}
          </div>
        </motion.div>

        {/* Created date */}
        <div className="px-4 py-3 border-t border-white/5 flex items-center gap-2">
          <Clock size={14} className="text-gray-600" />
          <span className="text-gray-600 text-[11px]">Created {community.createdAt}</span>
        </div>
      </div>
    </motion.div>
  );
}

// ============ COMMUNITY DETAILS MODAL (for long-press on already joined communities) ============
function CommunityDetailsModal({ community, onClose, onEnter }: { community: Community; onClose: () => void; onEnter: () => void }) {
  const { categories } = useApp();
  const cat = categories.find(c => c.id === community.categoryId);

  return (
    <motion.div {...fadeIn} className="absolute inset-0 z-50 bg-black/70 flex items-end" onClick={onClose}>
      <motion.div {...slideUp} onClick={e => e.stopPropagation()}
        className="w-full bg-[#1a1a2e] rounded-t-2xl max-h-[80%] overflow-y-auto amino-scroll">
        <div className="w-10 h-1 bg-gray-600 rounded-full mx-auto mt-3 mb-4" />
        <div className="px-4 pb-6">
          <div className="flex items-start gap-4 mb-4">
            <img src={community.icon} className="w-20 h-20 rounded-xl object-cover border-2 border-white/10" alt="" />
            <div className="flex-1 pt-1">
              <h2 className="text-white font-black text-[18px] leading-tight mb-1">{community.name}</h2>
              <p className="text-gray-400 text-[13px] mb-1">{formatNumber(community.members)} Members</p>
              <span className="bg-[#2a2a40] text-gray-300 text-[10px] px-2 py-0.5 rounded">{community.language.toUpperCase()}</span>
            </div>
          </div>
          <div className="bg-[#0f0f1e] rounded-lg px-3 py-2 mb-3 border border-white/5">
            <span className="text-gray-500 text-[11px]">Amino ID: </span>
            <span className="text-white font-bold text-[13px]">{community.aminoId}</span>
          </div>
          <p className="text-gray-400 text-[12px] leading-relaxed mb-3">{community.description}</p>
          <div className="flex flex-wrap gap-1.5 mb-4">
            {community.tags.map(tag => (
              <span key={tag} className="text-[11px] font-semibold px-2.5 py-0.5 rounded-full border"
                style={{ borderColor: cat?.color || "#666", color: cat?.color || "#aaa" }}>{tag}</span>
            ))}
          </div>
          <motion.button whileTap={{ scale: 0.95 }} onClick={onEnter}
            className="w-full bg-[#2dbe60] text-white font-bold text-[14px] py-3 rounded-lg active:bg-[#28a854] transition-colors">
            Enter Community
          </motion.button>
        </div>
      </motion.div>
    </motion.div>
  );
}

// ============ SEARCH SCREEN ============
function SearchScreen({ onClose }: { onClose: () => void }) {
  const { searchCommunities, categories, setSelectedCommunity, navigateTo, toggleJoinCommunity } = useApp();
  const [query, setQuery] = useState("");
  const [searchTab, setSearchTab] = useState("communities");
  const results = searchCommunities(query);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => { inputRef.current?.focus(); }, []);

  const handleCommunityClick = (c: Community) => {
    if (!c.isJoined) {
      setSelectedCommunity(c);
      navigateTo("joinCommunity");
    } else {
      setSelectedCommunity(c);
      navigateTo("community");
    }
    onClose();
  };

  return (
    <motion.div {...fadeIn} className="flex flex-col h-full bg-[#0f0f1e]">
      <motion.div initial={{ y: -10, opacity: 0 }} animate={{ y: 0, opacity: 1 }}
        className="flex items-center gap-2 px-3 py-2 bg-[#0f0f1e] border-b border-white/5" style={{ paddingTop: 38 }}>
        <div className="flex-1 flex items-center bg-[#1e1e38] rounded-full px-3 py-2 gap-2">
          <Search size={16} className="text-gray-500 shrink-0" />
          <input ref={inputRef} value={query} onChange={e => setQuery(e.target.value)}
            placeholder="Search communities, users..."
            className="flex-1 bg-transparent text-white text-[14px] outline-none placeholder:text-gray-600" />
          {query && <button onClick={() => setQuery("")} className="active:scale-90 transition-transform"><X size={16} className="text-gray-500" /></button>}
        </div>
        <button onClick={onClose} className="text-white text-[13px] font-medium px-1 active:opacity-70">Cancel</button>
      </motion.div>
      <div className="flex border-b border-white/5">
        {["communities", "users", "chats", "others"].map(tab => (
          <button key={tab} onClick={() => setSearchTab(tab)}
            className={`flex-1 py-2.5 text-[12px] font-semibold capitalize transition-colors relative ${searchTab === tab ? "text-white" : "text-gray-600"}`}>
            {tab === "communities" ? "Comunidades" : tab === "users" ? "Usuários" : tab === "chats" ? "Chats" : "Outros"}
            {searchTab === tab && <motion.div layoutId="searchTab" className="absolute bottom-0 left-2 right-2 h-[2px] bg-white rounded-full" />}
          </button>
        ))}
      </div>
      <div className="flex-1 overflow-y-auto amino-scroll px-3 pt-2">
        {searchTab === "communities" && (
          <AnimatePresence mode="popLayout">
            {query && results.length > 0 && (
              <motion.div {...fadeUp}>
                <p className="text-gray-600 text-[11px] mb-2 font-medium">Resultado da Pesquisa por Palavras-Chave</p>
                {results.map((c, i) => {
                  const cat = categories.find(ct => ct.id === c.categoryId);
                  return (
                    <motion.button key={c.id} initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.05 }}
                      onClick={() => handleCommunityClick(c)}
                      className="w-full flex gap-3 py-3 border-b border-white/5 text-left active:bg-white/3 transition-colors rounded-lg">
                      <img src={c.icon} className="w-24 h-28 rounded-lg object-cover shrink-0" alt="" />
                      <div className="flex-1 min-w-0 py-0.5">
                        <h3 className="text-white font-bold text-[15px] mb-0.5 leading-tight">{c.name}</h3>
                        <div className="bg-[#2a2a40] inline-block rounded px-1.5 py-0.5 mb-1">
                          <span className="text-gray-400 text-[10px]">ID Amino: </span>
                          <span className="text-white text-[11px] font-bold">{c.aminoId}</span>
                        </div>
                        <p className="text-gray-400 text-[11px] mb-1.5">{formatNumber(c.members)} Membros | {c.language === "en" ? "English" : c.language === "pt" ? "Português" : c.language}</p>
                        <div className="flex flex-wrap gap-1 mb-1.5">
                          {c.tags.map(tag => (
                            <span key={tag} className="text-[10px] font-semibold px-2 py-0.5 rounded-full border"
                              style={{ borderColor: cat?.color || "#666", color: cat?.color || "#aaa" }}>{tag}</span>
                          ))}
                        </div>
                        <p className="text-gray-500 text-[11px] line-clamp-2">{c.description}</p>
                      </div>
                    </motion.button>
                  );
                })}
              </motion.div>
            )}
            {query && results.length === 0 && (
              <motion.div {...fadeUp} className="text-center py-12">
                <Search size={32} className="text-gray-700 mx-auto mb-3" />
                <p className="text-gray-600 text-[13px]">Nenhum resultado para "{query}"</p>
              </motion.div>
            )}
            {!query && (
              <motion.div {...fadeUp} className="py-4">
                <p className="text-gray-500 text-[12px] mb-3 font-medium">Categorias Populares</p>
                <div className="grid grid-cols-2 gap-2">
                  {categories.slice(0, 8).map(cat => (
                    <button key={cat.id} onClick={() => setQuery(cat.name)}
                      className="flex items-center gap-2 bg-[#16162a] rounded-lg px-3 py-2.5 border border-white/5 active:scale-95 transition-transform">
                      <span className="text-[18px]">{cat.icon}</span>
                      <span className="text-white text-[12px] font-medium">{cat.name}</span>
                    </button>
                  ))}
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        )}
        {searchTab !== "communities" && (
          <motion.div {...fadeUp} className="text-center py-12">
            <Search size={32} className="text-gray-700 mx-auto mb-3" />
            <p className="text-gray-600 text-[13px]">Busca por {searchTab} - Em breve!</p>
          </motion.div>
        )}
      </div>
    </motion.div>
  );
}

// ============ DISCOVER TAB ============
function DiscoverTab() {
  const { communities, categories, setSelectedCommunity, navigateTo, toggleJoinCommunity } = useApp();
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);

  const filteredComms = selectedCategory ? communities.filter(c => c.categoryId === selectedCategory) : communities;
  const trendingComms = [...communities].sort((a, b) => b.onlineNow - a.onlineNow).slice(0, 5);

  const handleCommunityClick = (c: Community) => {
    setSelectedCommunity(c);
    if (c.isJoined) {
      navigateTo("community");
    } else {
      navigateTo("joinCommunity");
    }
  };

  return (
    <motion.div {...fadeUp} className="overflow-y-auto amino-scroll pb-4">
      {/* Categories horizontal scroll */}
      <div className="px-3 pt-3 pb-2">
        <h3 className="text-white font-bold text-[15px] mb-2">Categories</h3>
        <div className="flex gap-2 overflow-x-auto amino-scroll pb-2">
          <button onClick={() => setSelectedCategory(null)}
            className={`shrink-0 px-3 py-1.5 rounded-full text-[11px] font-semibold transition-all active:scale-95 ${!selectedCategory ? "bg-[#2dbe60] text-white" : "bg-[#1e1e38] text-gray-400 border border-white/5"}`}>
            All
          </button>
          {categories.map(cat => (
            <motion.button key={cat.id} whileTap={{ scale: 0.95 }}
              onClick={() => setSelectedCategory(selectedCategory === cat.id ? null : cat.id)}
              className={`shrink-0 flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[11px] font-semibold transition-all ${selectedCategory === cat.id ? "text-white" : "bg-[#1e1e38] text-gray-400 border border-white/5"}`}
              style={selectedCategory === cat.id ? { backgroundColor: cat.color } : {}}>
              <span className="text-[13px]">{cat.icon}</span>
              {cat.name}
            </motion.button>
          ))}
        </div>
      </div>

      {/* Trending Now */}
      {!selectedCategory && (
        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.1 }} className="px-3 mb-4">
          <div className="flex items-center gap-2 mb-2">
            <TrendingUp size={16} className="text-[#FF9800]" />
            <h3 className="text-white font-bold text-[15px]">Trending Now</h3>
          </div>
          <div className="flex gap-2.5 overflow-x-auto amino-scroll pb-1">
            {trendingComms.map((c, i) => (
              <motion.button key={c.id} initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: i * 0.08 }}
                whileTap={{ scale: 0.95 }}
                onClick={() => handleCommunityClick(c)}
                className="shrink-0 w-[130px] text-left">
                <div className="relative rounded-xl overflow-hidden mb-1.5">
                  <img src={c.cover} className="w-full h-[90px] object-cover" alt="" />
                  <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent" />
                  <div className="absolute bottom-1.5 left-1.5 flex items-center gap-1">
                    <div className="w-2 h-2 bg-[#2dbe60] rounded-full animate-pulse" />
                    <span className="text-white text-[9px] font-bold">{formatNumber(c.onlineNow)} online</span>
                  </div>
                </div>
                <p className="text-white text-[11px] font-semibold truncate">{c.name}</p>
                <p className="text-gray-600 text-[9px]">{formatNumber(c.members)} members</p>
              </motion.button>
            ))}
          </div>
        </motion.div>
      )}

      {/* Browse by Category or Filtered Results */}
      <div className="px-3">
        <h3 className="text-white font-bold text-[15px] mb-2">
          {selectedCategory ? categories.find(c => c.id === selectedCategory)?.name || "Communities" : "Browse Communities"}
        </h3>
        <motion.div variants={stagger} initial="initial" animate="animate" className="space-y-2">
          {filteredComms.map(c => {
            const cat = categories.find(ct => ct.id === c.categoryId);
            return (
              <motion.button key={c.id} variants={cardItem} whileTap={{ scale: 0.98 }}
                onClick={() => handleCommunityClick(c)}
                className="w-full flex gap-3 bg-[#16162a] rounded-xl p-3 border border-white/3 text-left transition-colors active:bg-[#1a1a30]">
                <img src={c.icon} className="w-16 h-16 rounded-lg object-cover shrink-0" alt="" />
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-1.5 mb-0.5">
                    <h4 className="text-white font-bold text-[13px] truncate">{c.name}</h4>
                    {c.isJoined && <Check size={12} className="text-[#2dbe60] shrink-0" />}
                  </div>
                  <p className="text-gray-500 text-[10px] mb-1">{formatNumber(c.members)} members · {formatNumber(c.onlineNow)} online</p>
                  <div className="flex flex-wrap gap-1">
                    {c.tags.slice(0, 3).map(tag => (
                      <span key={tag} className="text-[9px] font-medium px-1.5 py-0.5 rounded-full border"
                        style={{ borderColor: cat?.color || "#444", color: cat?.color || "#888" }}>{tag}</span>
                    ))}
                  </div>
                </div>
              </motion.button>
            );
          })}
        </motion.div>
      </div>
    </motion.div>
  );
}

// ============ COMMUNITIES TAB ============
function CommunitiesTab() {
  const { communities, setSelectedCommunity, navigateTo } = useApp();
  const joinedComms = communities.filter(c => c.isJoined);
  const [longPressComm, setLongPressComm] = useState<Community | null>(null);
  const longPressTimer = useRef<NodeJS.Timeout | null>(null);

  const handlePointerDown = useCallback((c: Community) => {
    longPressTimer.current = setTimeout(() => {
      setLongPressComm(c);
    }, 500);
  }, []);

  const handlePointerUp = useCallback(() => {
    if (longPressTimer.current) {
      clearTimeout(longPressTimer.current);
      longPressTimer.current = null;
    }
  }, []);

  const handleTap = useCallback((c: Community) => {
    if (longPressComm) return;
    setSelectedCommunity(c);
    navigateTo("community");
  }, [longPressComm, setSelectedCommunity, navigateTo]);

  return (
    <motion.div {...fadeUp} className="overflow-y-auto amino-scroll px-3 pt-3 pb-4">
      <h3 className="text-white font-bold text-[15px] mb-3">My Communities ({joinedComms.length})</h3>
      {joinedComms.length === 0 ? (
        <motion.div {...scaleIn} className="text-center py-12">
          <Users size={40} className="text-gray-700 mx-auto mb-3" />
          <p className="text-gray-500 text-[14px] font-medium mb-1">No communities yet</p>
          <p className="text-gray-600 text-[12px]">Explore and join communities to get started!</p>
        </motion.div>
      ) : (
        <motion.div variants={stagger} initial="initial" animate="animate" className="grid grid-cols-2 gap-2.5">
          {joinedComms.map(c => (
            <motion.div key={c.id} variants={cardItem}
              onPointerDown={() => handlePointerDown(c)}
              onPointerUp={handlePointerUp}
              onPointerLeave={handlePointerUp}
              onClick={() => handleTap(c)}
              className="cursor-pointer active:scale-[0.97] transition-transform">
              <div className="relative rounded-xl overflow-hidden bg-[#16162a] border border-white/5">
                <img src={c.cover} className="w-full h-[120px] object-cover" alt="" />
                <div className="absolute inset-0 bg-gradient-to-t from-[#16162a] via-transparent to-transparent" />
                <div className="absolute top-2 right-2">
                  {c.checkedIn ? (
                    <span className="bg-[#2dbe60] text-white text-[8px] font-bold px-1.5 py-0.5 rounded-full flex items-center gap-0.5"><Check size={8} />Done</span>
                  ) : (
                    <span className="bg-[#FF9800] text-white text-[8px] font-bold px-1.5 py-0.5 rounded-full animate-pulse">CHECK IN</span>
                  )}
                </div>
                <div className="absolute bottom-0 left-0 right-0 p-2.5">
                  <div className="flex items-center gap-2">
                    <img src={c.icon} className="w-10 h-10 rounded-lg object-cover border border-white/10 shadow" alt="" />
                    <div className="flex-1 min-w-0">
                      <p className="text-white font-bold text-[12px] truncate leading-tight">{c.name}</p>
                      <p className="text-gray-400 text-[9px]">{formatNumber(c.members)} members</p>
                    </div>
                  </div>
                </div>
              </div>
            </motion.div>
          ))}
        </motion.div>
      )}

      {/* Long press details modal */}
      <AnimatePresence>
        {longPressComm && (
          <CommunityDetailsModal
            community={longPressComm}
            onClose={() => setLongPressComm(null)}
            onEnter={() => {
              setSelectedCommunity(longPressComm);
              setLongPressComm(null);
              navigateTo("community");
            }}
          />
        )}
      </AnimatePresence>
    </motion.div>
  );
}

// ============ CHATS TAB ============
function ChatsTab() {
  const { chatRooms, communities, setSelectedChat, setSelectedCommunity, navigateTo } = useApp();
  const joinedComms = communities.filter(c => c.isJoined);
  const [selectedCommFilter, setSelectedCommFilter] = useState<string | null>(null);
  const filteredRooms = selectedCommFilter ? chatRooms.filter(r => r.communityId === selectedCommFilter) : chatRooms;

  return (
    <motion.div {...fadeUp} className="flex h-full">
      {/* Community sidebar */}
      <div className="w-[60px] bg-[#0b0b18] border-r border-white/5 flex flex-col items-center pt-2 gap-2 overflow-y-auto amino-scroll shrink-0">
        <motion.button whileTap={{ scale: 0.9 }}
          onClick={() => setSelectedCommFilter(null)}
          className={`w-10 h-10 rounded-full flex items-center justify-center transition-all ${!selectedCommFilter ? "bg-[#2dbe60] ring-2 ring-[#2dbe60]/30" : "bg-[#1e1e38]"}`}>
          <MessageCircle size={18} className="text-white" />
        </motion.button>
        {joinedComms.map(c => (
          <motion.button key={c.id} whileTap={{ scale: 0.9 }}
            onClick={() => setSelectedCommFilter(c.id)}
            className={`relative shrink-0 transition-all ${selectedCommFilter === c.id ? "ring-2 ring-[#2dbe60] rounded-xl" : ""}`}>
            <img src={c.icon} className="w-10 h-10 rounded-xl object-cover" alt="" />
            {c.checkedIn === false && <span className="absolute -top-0.5 -right-0.5 w-3 h-3 bg-red-500 rounded-full border-2 border-[#0b0b18]" />}
          </motion.button>
        ))}
        <motion.button whileTap={{ scale: 0.9 }}
          onClick={() => comingSoon("Join Community")}
          className="w-10 h-10 rounded-full bg-[#1e1e38] flex items-center justify-center border border-dashed border-white/10 mt-1">
          <Plus size={16} className="text-gray-600" />
        </motion.button>
      </div>

      {/* Chat list */}
      <div className="flex-1 overflow-y-auto amino-scroll">
        <div className="px-3 pt-3 pb-1">
          <h3 className="text-white font-bold text-[15px] mb-2">
            {selectedCommFilter ? communities.find(c => c.id === selectedCommFilter)?.name || "Chats" : "All Chats"}
          </h3>
        </div>
        <motion.div variants={stagger} initial="initial" animate="animate">
          {filteredRooms.map(chat => (
            <motion.button key={chat.id} variants={cardItem} whileTap={{ scale: 0.98 }}
              onClick={() => { setSelectedChat(chat); const comm = communities.find(c => c.id === chat.communityId); if (comm) setSelectedCommunity(comm); navigateTo("chatroom"); }}
              className="w-full flex items-center gap-3 px-3 py-2.5 border-b border-white/3 text-left active:bg-white/3 transition-colors">
              <div className="relative shrink-0">
                <div className="w-12 h-12 rounded-full bg-[#1e1e38] flex items-center justify-center overflow-hidden">
                  {chat.cover ? <img src={chat.cover} className="w-full h-full object-cover" alt="" /> : <Hash size={20} className="text-gray-500" />}
                </div>
                <img src={chat.communityIcon} className="absolute -bottom-0.5 -right-0.5 w-5 h-5 rounded-full border-2 border-[#0f0f1e] object-cover" alt="" />
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center justify-between mb-0.5">
                  <span className="text-white text-[13px] font-semibold truncate">{chat.name}</span>
                  <span className="text-gray-600 text-[10px] shrink-0 ml-2">{chat.lastMessageTime}</span>
                </div>
                <div className="flex items-center justify-between">
                  <p className="text-gray-500 text-[11px] truncate flex-1">
                    <span className="text-gray-400 font-medium">{chat.lastMessageBy}: </span>{chat.lastMessage}
                  </p>
                  {chat.unreadCount > 0 && (
                    <span className="ml-2 min-w-[18px] h-[18px] bg-red-500 rounded-full text-white text-[9px] font-bold flex items-center justify-center px-1">{chat.unreadCount}</span>
                  )}
                </div>
              </div>
            </motion.button>
          ))}
        </motion.div>
      </div>
    </motion.div>
  );
}

// ============ STORE TAB ============
function StoreTab() {
  return (
    <motion.div {...fadeUp} className="overflow-y-auto amino-scroll px-3 pt-3 pb-4">
      <div className="bg-gradient-to-br from-[#FFD700] to-[#FF8C00] rounded-xl p-4 mb-4">
        <h2 className="text-black font-black text-[20px] mb-1">Amino+</h2>
        <p className="text-black/70 text-[12px] mb-3">Unlock exclusive features, custom profiles, and more!</p>
        <motion.button whileTap={{ scale: 0.95 }} onClick={() => comingSoon("Amino+ Subscription")}
          className="bg-black text-white font-bold text-[13px] px-5 py-2 rounded-full active:bg-gray-900 transition-colors">
          Try Free for 7 Days
        </motion.button>
      </div>
      <h3 className="text-white font-bold text-[15px] mb-3">Coin Shop</h3>
      <motion.div variants={stagger} initial="initial" animate="animate" className="grid grid-cols-2 gap-2.5">
        {[
          { coins: 40, price: "$0.99", popular: false },
          { coins: 110, price: "$1.99", popular: false },
          { coins: 350, price: "$4.99", popular: true },
          { coins: 700, price: "$9.99", popular: false },
          { coins: 1400, price: "$19.99", popular: false },
          { coins: 3500, price: "$49.99", popular: false },
        ].map(item => (
          <motion.button key={item.coins} variants={cardItem} whileTap={{ scale: 0.95 }}
            onClick={() => comingSoon("Purchase Coins")}
            className={`relative bg-[#16162a] rounded-xl p-3 border text-center transition-colors active:bg-[#1a1a30] ${item.popular ? "border-[#FFD700]" : "border-white/5"}`}>
            {item.popular && <span className="absolute -top-2 left-1/2 -translate-x-1/2 bg-[#FFD700] text-black text-[8px] font-bold px-2 py-0.5 rounded-full">POPULAR</span>}
            <span className="text-[24px] block mb-1">🪙</span>
            <p className="text-white font-bold text-[16px]">{item.coins}</p>
            <p className="text-[#2dbe60] font-bold text-[13px]">{item.price}</p>
          </motion.button>
        ))}
      </motion.div>
    </motion.div>
  );
}

// ============ COMMUNITY DETAIL SCREEN (Inside community) ============
function CommunityDetailScreen() {
  const {
    selectedCommunity, communities, posts, chatRooms, currentUser,
    goBack, navigateTo, setSelectedCommunity, setSelectedPost, setSelectedChat,
    toggleJoinCommunity, checkIn, getCommunityProfile, toggleLike,
  } = useApp();
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [activeTab, setActiveTab] = useState("featured");
  const [showFab, setShowFab] = useState(false);

  if (!selectedCommunity) return null;

  const profile = getCommunityProfile(selectedCommunity.id);
  const displayAvatar = profile?.avatar || currentUser.avatar;
  const displayName = profile?.nickname || currentUser.nickname;
  const communityPosts = posts.filter(p => p.communityId === selectedCommunity.id);
  const commChats = chatRooms.filter(r => r.communityId === selectedCommunity.id);
  const joinedComms = communities.filter(c => c.isJoined);
  const isLeader = profile?.role === "Leader";

  return (
    <motion.div {...pageVariants} className="flex flex-col h-full bg-[#0f0f1e] relative overflow-hidden">
      {/* Drawer Overlay */}
      <AnimatePresence>
        {drawerOpen && (
          <>
            <motion.div {...fadeIn} className="absolute inset-0 z-40 bg-black/60" onClick={() => setDrawerOpen(false)} />
            <div className="absolute inset-0 z-50 flex">
              {/* Community sidebar */}
              <motion.div initial={{ x: -60 }} animate={{ x: 0 }} exit={{ x: -60 }} transition={{ type: "spring", damping: 25 }}
                className="w-[60px] bg-[#070710] flex flex-col items-center pt-10 gap-2 overflow-y-auto amino-scroll border-r border-white/5">
                <button onClick={() => { setDrawerOpen(false); goBack(); }}
                  className="flex flex-col items-center gap-0.5 mb-2 active:scale-90 transition-transform">
                  <LogOut size={18} className="text-gray-400" />
                  <span className="text-gray-500 text-[8px]">Exit</span>
                </button>
                <div className="w-8 h-px bg-white/10 mb-1" />
                {joinedComms.map(c => (
                  <motion.button key={c.id} whileTap={{ scale: 0.9 }}
                    onClick={() => { setSelectedCommunity(c); setDrawerOpen(false); }}
                    className={`relative shrink-0 ${c.id === selectedCommunity.id ? "ring-2 ring-white rounded-xl" : ""}`}>
                    <img src={c.icon} className="w-10 h-10 rounded-xl object-cover" alt="" />
                    {!c.checkedIn && <span className="absolute -top-0.5 -right-0.5 min-w-[14px] h-[14px] bg-red-500 rounded-full text-white text-[7px] flex items-center justify-center font-bold border border-[#070710]">!</span>}
                  </motion.button>
                ))}
                <button onClick={() => { setDrawerOpen(false); goBack(); comingSoon("Browse Communities"); }}
                  className="w-10 h-10 rounded-full bg-[#1e1e38] flex items-center justify-center border border-dashed border-white/10 mt-1 active:scale-90 transition-transform">
                  <Plus size={14} className="text-gray-600" />
                </button>
              </motion.div>

              {/* Main drawer panel */}
              <motion.div initial={{ x: -280 }} animate={{ x: 0 }} exit={{ x: -280 }} transition={{ type: "spring", damping: 25 }}
                className="w-[280px] bg-[#0f0f1e] overflow-y-auto amino-scroll">
                {/* Cover + Profile */}
                <div className="relative h-[220px]">
                  <img src={selectedCommunity.cover} className="w-full h-full object-cover" alt="" />
                  <div className="absolute inset-0 bg-gradient-to-t from-[#0f0f1e] via-[#0f0f1e]/40 to-transparent" />
                  <div className="absolute top-3 left-0 right-0 text-center">
                    <p className="text-white/60 text-[10px] tracking-[3px] uppercase">Welcome to</p>
                    <h2 className="text-white font-black text-[18px] tracking-wider">{selectedCommunity.name.toUpperCase()}</h2>
                  </div>
                  <div className="absolute bottom-4 left-0 right-0 flex flex-col items-center">
                    <div className="relative mb-1">
                      <div className="w-16 h-16 rounded-full p-[2px] bg-gradient-to-br from-blue-400 to-purple-500">
                        <img src={displayAvatar} className="w-full h-full rounded-full object-cover border-2 border-[#0f0f1e]" alt="" />
                      </div>
                      <div className="absolute -top-1 -right-1 w-6 h-6 bg-[#2563eb] rounded-full flex items-center justify-center border-2 border-[#0f0f1e]">
                        <Plus size={12} className="text-white" />
                      </div>
                    </div>
                    <p className="text-white text-[13px] font-semibold">{displayName}</p>
                    <motion.button whileTap={{ scale: 0.95 }}
                      onClick={() => { checkIn(selectedCommunity.id); toast.success("Checked in! +5 XP"); }}
                      className={`mt-2 px-6 py-1.5 rounded-lg font-bold text-[13px] transition-all ${selectedCommunity.checkedIn ? "bg-gray-600 text-gray-400" : "bg-[#2dbe60] text-white shadow-lg shadow-[#2dbe60]/20"}`}
                      disabled={selectedCommunity.checkedIn}>
                      {selectedCommunity.checkedIn ? "Checked In ✓" : "Check In"}
                    </motion.button>
                  </div>
                </div>

                {/* Menu Items */}
                <div className="px-2 py-2 space-y-0.5">
                  {[
                    { icon: <Star size={18} />, label: "Home", color: "#2dbe60", action: () => { setDrawerOpen(false); setActiveTab("featured"); } },
                    { icon: <MessageCircle size={18} />, label: "My Chats", color: "#2dbe60", badge: commChats.length, action: () => { setDrawerOpen(false); setActiveTab("chats"); } },
                    { icon: <BookOpen size={18} />, label: "Catalog", color: "#FF9800", action: () => { setDrawerOpen(false); setActiveTab("wiki"); } },
                    { icon: <MessageCircle size={18} />, label: "Public Chatrooms", color: "#2dbe60", action: () => { setDrawerOpen(false); setActiveTab("chats"); } },
                    { icon: <Clock size={18} />, label: "Latest Feed", color: "#2196F3", action: () => { setDrawerOpen(false); setActiveTab("latest"); } },
                    { icon: <Globe size={18} />, label: "Guidelines", color: "#FF9800", action: () => { setDrawerOpen(false); setActiveTab("guidelines"); } },
                    { icon: <Star size={18} />, label: "Resource Links", color: "#FF9800", action: () => comingSoon("Resource Links") },
                  ].map((item, i) => (
                    <motion.button key={i} initial={{ opacity: 0, x: -10 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: 0.3 + i * 0.05 }}
                      onClick={item.action}
                      className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg hover:bg-white/3 active:bg-white/5 transition-colors">
                      <div className="w-8 h-8 rounded-full flex items-center justify-center" style={{ backgroundColor: item.color }}>{item.icon}</div>
                      <span className="text-white text-[14px] font-medium flex-1 text-left">{item.label}</span>
                      {item.badge && item.badge > 0 && <span className="bg-red-500 text-white text-[10px] font-bold min-w-[20px] h-[20px] rounded-full flex items-center justify-center px-1">{item.badge}</span>}
                    </motion.button>
                  ))}
                  <button onClick={() => comingSoon("See More")} className="w-full flex items-center justify-between px-3 py-2.5">
                    <span className="text-gray-400 text-[13px]">See More...</span>
                    <ChevronRight size={16} className="text-gray-500" />
                  </button>

                  {/* Leader Edit Community */}
                  {isLeader && (
                    <motion.button initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.8 }}
                      onClick={() => comingSoon("Edit Community (Leader Only)")}
                      className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg bg-[#2dbe60]/10 border border-[#2dbe60]/20 mt-2">
                      <div className="w-8 h-8 rounded-full bg-[#2dbe60] flex items-center justify-center"><Settings size={16} className="text-white" /></div>
                      <div className="flex-1 text-left">
                        <span className="text-[#2dbe60] text-[13px] font-bold">Edit Community</span>
                        <p className="text-gray-500 text-[9px]">Name, description, tags, cover, icon</p>
                      </div>
                    </motion.button>
                  )}
                </div>
              </motion.div>
              <div className="flex-1" onClick={() => setDrawerOpen(false)} />
            </div>
          </>
        )}
      </AnimatePresence>

      {/* Main Content */}
      <div className="flex-1 overflow-y-auto amino-scroll">
        {/* Header with cover */}
        <div className="relative">
          <img src={selectedCommunity.cover} className="w-full h-[140px] object-cover" alt="" />
          <div className="absolute inset-0 bg-gradient-to-b from-black/40 to-[#0f0f1e]" />
          <div className="absolute top-0 left-0 right-0 flex items-center justify-between px-3" style={{ paddingTop: 38 }}>
            <button onClick={goBack} className="p-1.5 bg-black/30 rounded-full active:scale-90 transition-transform"><ChevronLeft size={20} className="text-white" /></button>
            <div className="flex items-center gap-2">
              <motion.button whileTap={{ scale: 0.9 }} onClick={() => comingSoon("Claim Gifts")}
                className="bg-[#2dbe60] text-white text-[10px] font-bold px-2.5 py-1 rounded-full flex items-center gap-1">
                🎁 Claim gifts
              </motion.button>
              <button className="p-1.5 bg-black/30 rounded-full active:scale-90 transition-transform"><Bell size={18} className="text-white" /></button>
            </div>
          </div>
          <div className="absolute bottom-2 left-3 right-3">
            <div className="flex items-end gap-3">
              <img src={selectedCommunity.icon} className="w-16 h-16 rounded-xl object-cover border-2 border-white/10 shadow-lg" alt="" />
              <div className="flex-1 min-w-0 pb-0.5">
                <h1 className="text-white font-black text-[18px] leading-tight truncate">{selectedCommunity.name}</h1>
                <div className="flex items-center gap-2">
                  <p className="text-gray-300 text-[11px]">{formatNumber(selectedCommunity.members)} Members</p>
                  <motion.button whileTap={{ scale: 0.95 }} onClick={() => { setActiveTab("leaderboard"); }}
                    className="bg-[#2dbe60] text-white text-[9px] font-bold px-2 py-0.5 rounded-full">Leaderboards</motion.button>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Check-in bar */}
        {!selectedCommunity.checkedIn && (
          <motion.div initial={{ height: 0, opacity: 0 }} animate={{ height: "auto", opacity: 1 }} transition={{ delay: 0.2 }}
            className="bg-[#16162a] px-4 py-3 border-b border-white/5">
            <p className="text-white text-[13px] font-semibold text-center mb-2">Check In to earn a prize</p>
            <div className="flex items-center gap-1 mb-2 px-2">
              {[1, 2, 3, 4, 5, 6, 7].map(day => (
                <div key={day} className="flex-1 flex flex-col items-center gap-1">
                  <div className={`w-full h-2 rounded-full ${day <= (profile?.streakDays || 0) % 7 ? "bg-[#2dbe60]" : "bg-gray-700"}`} />
                </div>
              ))}
            </div>
            <motion.button whileTap={{ scale: 0.95 }}
              onClick={() => { checkIn(selectedCommunity.id); toast.success("Checked in! +5 XP"); }}
              className="w-full bg-[#2dbe60] text-white font-bold text-[14px] py-2 rounded-lg shadow-lg shadow-[#2dbe60]/20 active:bg-[#28a854] transition-colors">
              Check In
            </motion.button>
          </motion.div>
        )}

        {/* Live Chatrooms */}
        {commChats.length > 0 && (
          <div className="px-3 py-2.5">
            <div className="flex gap-2.5 overflow-x-auto amino-scroll">
              {commChats.slice(0, 4).map(chat => (
                <motion.button key={chat.id} whileTap={{ scale: 0.95 }}
                  onClick={() => { setSelectedChat(chat); navigateTo("chatroom"); }}
                  className="shrink-0 w-[140px] bg-[#16162a] rounded-xl overflow-hidden border border-white/5">
                  <div className="relative h-[70px]">
                    <img src={chat.cover || selectedCommunity.cover} className="w-full h-full object-cover" alt="" />
                    <div className="absolute inset-0 bg-gradient-to-t from-[#16162a] to-transparent" />
                    <div className="absolute top-1.5 left-1.5 flex items-center gap-1 bg-black/50 rounded-full px-1.5 py-0.5">
                      <div className="w-1.5 h-1.5 bg-[#2dbe60] rounded-full animate-pulse" />
                      <span className="text-white text-[8px] font-bold">Live</span>
                    </div>
                  </div>
                  <div className="p-2">
                    <p className="text-white text-[11px] font-semibold truncate">{chat.name}</p>
                    <p className="text-gray-600 text-[9px]">👥 {chat.membersCount}</p>
                  </div>
                </motion.button>
              ))}
            </div>
          </div>
        )}

        {/* Tabs */}
        <div className="flex overflow-x-auto amino-scroll border-b border-white/5 px-1">
          {["guidelines", "featured", "latest", "chats", "members", "wiki", "leaderboard"].map(tab => (
            <button key={tab} onClick={() => setActiveTab(tab)}
              className={`shrink-0 px-3 py-2.5 text-[12px] font-semibold capitalize transition-colors relative whitespace-nowrap ${activeTab === tab ? "text-white" : "text-gray-600"}`}>
              {tab === "chats" ? "Public Chatrooms" : tab === "latest" ? "Latest Feed" : tab}
              {activeTab === tab && <motion.div layoutId="communityTab" className="absolute bottom-0 left-2 right-2 h-[2px] bg-white rounded-full" />}
            </button>
          ))}
        </div>

        {/* Tab Content */}
        <AnimatePresence mode="wait">
          <motion.div key={activeTab} {...fadeUp} className="px-3 pt-2 pb-20">
            {activeTab === "guidelines" && (
              <div className="bg-[#16162a] rounded-lg p-4">
                <h3 className="text-white font-bold text-[16px] mb-3 flex items-center gap-2"><Globe size={18} className="text-[#FF9800]" />Community Guidelines</h3>
                <div className="space-y-3 text-gray-300 text-[13px] leading-relaxed">
                  {selectedCommunity.guidelines.map((g, i) => <p key={i}>{i + 1}. {g}</p>)}
                </div>
              </div>
            )}
            {(activeTab === "featured" || activeTab === "latest") && (
              <motion.div variants={stagger} initial="initial" animate="animate">
                {communityPosts.length > 0 ? communityPosts.map(post => (
                  <PostCard key={post.id} post={post} onPress={() => { setSelectedPost(post); navigateTo("post"); }} showCommunity={false} />
                )) : (
                  <div className="text-center py-8"><p className="text-gray-600 text-[13px]">No posts yet. Be the first to post!</p></div>
                )}
              </motion.div>
            )}
            {activeTab === "chats" && (
              <div>
                {commChats.map(chat => (
                  <motion.button key={chat.id} whileTap={{ scale: 0.98 }}
                    onClick={() => { setSelectedChat(chat); navigateTo("chatroom"); }}
                    className="w-full flex items-center gap-3 py-3 border-b border-white/5 text-left active:bg-white/3 transition-colors">
                    <div className="w-11 h-11 rounded-full bg-[#1e1e38] flex items-center justify-center shrink-0"><Hash size={18} className="text-gray-500" /></div>
                    <div className="flex-1 min-w-0">
                      <p className="text-white text-[13px] font-semibold truncate">{chat.name}</p>
                      <p className="text-gray-600 text-[10px]">{chat.membersCount} members</p>
                    </div>
                    <ChevronRight size={16} className="text-gray-600" />
                  </motion.button>
                ))}
                {commChats.length === 0 && <div className="text-center py-8"><p className="text-gray-600 text-[13px]">No public chatrooms yet</p></div>}
              </div>
            )}
            {activeTab === "members" && (
              <div>
                {[
                  { name: "CommunityAdmin", role: "Leader", rep: 120000, avatar: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100" },
                  { name: "ModeratorX", role: "Curator", rep: 50000, avatar: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100" },
                  { name: "ActiveUser99", role: "Member", rep: 8000, avatar: "https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=100" },
                ].map((m, i) => {
                  const lvl = getLevelFromRep(m.rep);
                  return (
                    <motion.div key={i} initial={{ opacity: 0, x: -10 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: i * 0.1 }}
                      className="flex items-center gap-3 py-2.5 border-b border-white/5">
                      <img src={m.avatar} className="w-10 h-10 rounded-full object-cover" alt="" />
                      <div className="flex-1">
                        <div className="flex items-center gap-1.5">
                          <span className="text-white text-[13px] font-semibold">{m.name}</span>
                          {m.role === "Leader" && <span className="bg-[#2dbe60] text-white text-[7px] px-1 py-px rounded font-bold">Leader</span>}
                          {m.role === "Curator" && <span className="bg-[#E040FB] text-white text-[7px] px-1 py-px rounded font-bold">Curator</span>}
                        </div>
                        <div className="flex items-center gap-1.5 mt-0.5">
                          <span className="bg-gradient-to-r from-blue-700 to-blue-500 text-white text-[8px] font-bold px-1.5 py-px rounded">Lv{lvl.level}</span>
                          <span className="text-gray-600 text-[10px]">{lvl.title} · {formatNumber(m.rep)} rep</span>
                        </div>
                      </div>
                    </motion.div>
                  );
                })}
              </div>
            )}
            {activeTab === "wiki" && (
              <div className="text-center py-8">
                <BookOpen size={32} className="text-gray-700 mx-auto mb-2" />
                <p className="text-gray-600 text-[13px]">Wiki/Catalog entries will appear here</p>
                <motion.button whileTap={{ scale: 0.95 }} onClick={() => comingSoon("Create Wiki Entry")}
                  className="mt-3 bg-[#2dbe60] text-white text-[12px] font-bold px-4 py-2 rounded-full">Create Entry</motion.button>
              </div>
            )}
            {activeTab === "leaderboard" && (
              <div>
                <h4 className="text-white font-bold text-[14px] mb-3 flex items-center gap-1.5"><Trophy size={16} className="text-yellow-400" />Top Members</h4>
                {[
                  { rank: 1, name: "TopUser", rep: 120000, avatar: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100" },
                  { rank: 2, name: "ProMember", rep: 50000, avatar: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100" },
                  { rank: 3, name: "ActiveFan", rep: 33000, avatar: "https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=100" },
                ].map(m => {
                  const lvl = getLevelFromRep(m.rep);
                  return (
                    <motion.div key={m.rank} initial={{ opacity: 0, x: -10 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: m.rank * 0.1 }}
                      className="flex items-center gap-3 py-2.5 border-b border-white/5">
                      <span className={`w-7 h-7 rounded-full flex items-center justify-center font-bold text-[12px] ${m.rank === 1 ? "bg-yellow-500 text-black" : m.rank === 2 ? "bg-gray-400 text-black" : "bg-orange-700 text-white"}`}>{m.rank}</span>
                      <img src={m.avatar} className="w-9 h-9 rounded-full object-cover" alt="" />
                      <div className="flex-1">
                        <div className="flex items-center gap-1.5">
                          <span className="text-white text-[13px] font-semibold">{m.name}</span>
                          <span className="bg-gradient-to-r from-blue-700 to-blue-500 text-white text-[8px] font-bold px-1.5 py-px rounded">Lv{lvl.level}</span>
                        </div>
                        <span className="text-gray-500 text-[10px]">{lvl.title} · {formatNumber(m.rep)} reputation</span>
                      </div>
                    </motion.div>
                  );
                })}
              </div>
            )}
          </motion.div>
        </AnimatePresence>
      </div>

      {/* Community Bottom Nav */}
      <div className="sticky bottom-0 z-30 flex items-center bg-[#0b0b18] border-t border-white/5 shrink-0" style={{ paddingBottom: 4 }}>
        <button onClick={() => setDrawerOpen(true)} className="flex-1 flex flex-col items-center py-2 gap-0.5 text-gray-500 relative active:scale-90 transition-transform">
          <Menu size={20} /><span className="text-[9px]">Menu</span>
          <span className="absolute top-1 right-[30%] w-2 h-2 bg-red-500 rounded-full" />
        </button>
        <button onClick={() => comingSoon("Online Members")} className="flex-1 flex flex-col items-center py-2 gap-0.5 text-gray-500 relative active:scale-90 transition-transform">
          <Users size={20} /><span className="text-[9px]">Online</span>
          <span className="absolute top-0 right-[25%] min-w-[16px] h-[16px] bg-[#2dbe60] rounded-full text-[8px] text-white flex items-center justify-center font-bold">{selectedCommunity.onlineNow > 999 ? "999+" : selectedCommunity.onlineNow}</span>
        </button>
        <motion.button whileTap={{ scale: 0.85 }} onClick={() => setShowFab(!showFab)} className="flex items-center justify-center -mt-4">
          <motion.div animate={{ rotate: showFab ? 45 : 0 }} transition={{ duration: 0.2 }}
            className="w-12 h-12 rounded-full bg-[#2563eb] flex items-center justify-center shadow-lg shadow-blue-500/30">
            <Plus size={24} className="text-white" />
          </motion.div>
        </motion.button>
        <button onClick={() => setActiveTab("chats")} className="flex-1 flex flex-col items-center py-2 gap-0.5 text-gray-500 relative active:scale-90 transition-transform">
          <MessageCircle size={20} /><span className="text-[9px]">Chats</span>
          <span className="absolute top-0 right-[25%] w-2 h-2 bg-red-500 rounded-full" />
        </button>
        <button onClick={() => navigateTo("communityProfile")} className="flex-1 flex flex-col items-center py-2 gap-0.5 text-gray-500 active:scale-90 transition-transform">
          <img src={displayAvatar} className="w-5 h-5 rounded-full object-cover" alt="" /><span className="text-[9px]">Me</span>
        </button>
      </div>

      {/* FAB Options */}
      <AnimatePresence>
        {showFab && (
          <motion.div {...fadeIn} className="absolute bottom-16 right-3 z-40 flex flex-col items-end gap-2">
            {[
              { icon: <FileText size={16} />, label: "Blog", color: "bg-blue-500" },
              { icon: <Image size={16} />, label: "Image", color: "bg-green-500" },
              { icon: <BarChart3 size={16} />, label: "Poll", color: "bg-orange-500" },
              { icon: <HelpCircle size={16} />, label: "Quiz", color: "bg-pink-500" },
            ].map((item, i) => (
              <motion.div key={item.label} initial={{ opacity: 0, x: 20, scale: 0.8 }} animate={{ opacity: 1, x: 0, scale: 1 }} exit={{ opacity: 0, x: 20, scale: 0.8 }}
                transition={{ delay: i * 0.05 }}
                className="flex items-center gap-2" onClick={() => { comingSoon("Create " + item.label); setShowFab(false); }}>
                <span className="text-white text-[11px] font-medium bg-black/80 px-2 py-1 rounded">{item.label}</span>
                <button className={`w-10 h-10 rounded-full ${item.color} flex items-center justify-center text-white shadow-lg active:scale-90 transition-transform`}>{item.icon}</button>
              </motion.div>
            ))}
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
}

// ============ POST DETAIL ============
function PostDetailScreen() {
  const { selectedPost, comments, goBack, toggleLike } = useApp();
  const [newComment, setNewComment] = useState("");
  if (!selectedPost) return null;
  const authorLevel = getLevelFromRep(selectedPost.author.level * 500);

  return (
    <motion.div {...pageVariants} className="flex flex-col h-full">
      <AminoMainHeader onBack={goBack} title={selectedPost.communityName} />
      <div className="flex-1 overflow-y-auto amino-scroll px-3 pt-2 pb-4">
        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }}>
          <div className="flex items-center gap-3 mb-3">
            <img src={selectedPost.author.avatar} className="w-10 h-10 rounded-full object-cover" alt="" />
            <div className="flex-1">
              <div className="flex items-center gap-1.5">
                <span className="text-white text-[14px] font-semibold">{selectedPost.author.nickname}</span>
                {selectedPost.author.role === "Leader" && <span className="bg-[#2dbe60] text-white text-[7px] px-1 py-px rounded font-bold">Leader</span>}
                {selectedPost.author.role === "Curator" && <span className="bg-[#E040FB] text-white text-[7px] px-1 py-px rounded font-bold">Curator</span>}
              </div>
              <div className="flex items-center gap-2 mt-0.5">
                <span className="bg-gradient-to-r from-blue-600 to-blue-400 text-white text-[9px] font-bold px-1.5 py-0.5 rounded-full">Lv.{authorLevel.level}</span>
                <span className="text-gray-600 text-[10px]">{getTimeAgo(selectedPost.createdAt)}</span>
              </div>
            </div>
            <button onClick={() => comingSoon("Post Options")} className="p-1 active:scale-90 transition-transform"><MoreHorizontal size={18} className="text-gray-600" /></button>
          </div>
          <h2 className="text-white font-bold text-[18px] mb-2 leading-snug">{selectedPost.title}</h2>
          <p className="text-gray-300 text-[13px] leading-relaxed mb-3 whitespace-pre-line">{selectedPost.content}</p>
          {selectedPost.mediaUrl && <img src={selectedPost.mediaUrl} className="w-full rounded-lg mb-3" alt="" />}
        </motion.div>
        <div className="flex gap-1.5 mb-4 flex-wrap">
          {selectedPost.tags.map(tag => <span key={tag} className="bg-[#1e1e38] text-gray-500 text-[11px] px-2.5 py-1 rounded-full">#{tag}</span>)}
        </div>
        <div className="flex items-center gap-6 py-3 border-y border-white/5 mb-4">
          <button onClick={() => toggleLike(selectedPost.id)}
            className={`flex items-center gap-1.5 text-[13px] active:scale-90 transition-all ${selectedPost.isLiked ? "text-red-400" : "text-gray-600"}`}>
            <motion.div animate={selectedPost.isLiked ? { scale: [1, 1.4, 1] } : {}} transition={{ duration: 0.3 }}>
              <Heart size={20} fill={selectedPost.isLiked ? "currentColor" : "none"} />
            </motion.div>
            <span>{selectedPost.likesCount}</span>
          </button>
          <div className="flex items-center gap-1.5 text-gray-600 text-[13px]"><MessageCircle size={20} /><span>{selectedPost.commentsCount}</span></div>
          <button onClick={() => comingSoon("Bookmark")} className="ml-auto text-gray-600 active:scale-90 transition-transform"><Bookmark size={20} /></button>
          <button onClick={() => comingSoon("Share")} className="text-gray-600 active:scale-90 transition-transform"><Share2 size={20} /></button>
        </div>
        <h4 className="text-white font-bold text-[14px] mb-3">Comments ({comments.length})</h4>
        {comments.map((comment, i) => (
          <motion.div key={comment.id} initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.05 }}
            className="flex gap-2.5 mb-4">
            <img src={comment.author.avatar} className="w-8 h-8 rounded-full object-cover shrink-0" alt="" />
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-1.5 mb-0.5">
                <span className="text-white text-[12px] font-semibold">{comment.author.nickname}</span>
                {comment.author.role === "Leader" && <span className="bg-[#2dbe60] text-white text-[6px] px-1 rounded font-bold">Leader</span>}
                <span className="text-gray-700 text-[10px] ml-auto">{getTimeAgo(comment.createdAt)}</span>
              </div>
              <p className="text-gray-300 text-[12px] leading-relaxed">{comment.content}</p>
              <div className="flex items-center gap-3 mt-1.5">
                <button className={`flex items-center gap-1 text-[11px] ${comment.isLiked ? "text-red-400" : "text-gray-700"}`}>
                  <Heart size={12} fill={comment.isLiked ? "currentColor" : "none"} /><span>{comment.likesCount}</span>
                </button>
                <button onClick={() => comingSoon("Reply")} className="text-gray-700 text-[11px]">Reply</button>
              </div>
            </div>
          </motion.div>
        ))}
      </div>
      <div className="flex items-center gap-2 px-3 py-2 bg-[#0b0b18] border-t border-white/5 shrink-0">
        <input value={newComment} onChange={e => setNewComment(e.target.value)}
          placeholder="Write a comment..."
          className="flex-1 bg-[#1e1e38] text-white text-[13px] px-3 py-2 rounded-full placeholder:text-gray-700 outline-none" />
        <motion.button whileTap={{ scale: 0.85 }} onClick={() => { if (newComment.trim()) { comingSoon("Post Comment"); setNewComment(""); } }} className="p-1.5"><Send size={18} className="text-[#2dbe60]" /></motion.button>
      </div>
    </motion.div>
  );
}

// ============ CHAT ROOM ============
function ChatRoomScreen() {
  const { selectedChat, chatMessages, goBack, sendMessage, currentUser } = useApp();
  const [input, setInput] = useState("");
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => { messagesEndRef.current?.scrollIntoView({ behavior: "smooth" }); }, [chatMessages]);

  if (!selectedChat) return null;

  const handleSend = () => {
    if (!input.trim()) return;
    sendMessage(input.trim());
    setInput("");
  };

  return (
    <motion.div {...pageVariants} className="flex flex-col h-full">
      <motion.div initial={{ y: -10, opacity: 0 }} animate={{ y: 0, opacity: 1 }}
        className="flex items-center gap-2 px-3 py-2 bg-[#0f0f1e]/95 backdrop-blur-sm border-b border-white/5 shrink-0" style={{ paddingTop: 38 }}>
        <button onClick={goBack} className="p-1 active:scale-90 transition-transform"><ChevronLeft size={20} className="text-white" /></button>
        <div className="w-8 h-8 rounded-full bg-[#1e1e38] flex items-center justify-center"><Hash size={14} className="text-[#2dbe60]" /></div>
        <div className="flex-1 min-w-0">
          <span className="text-white font-semibold text-[13px] truncate block">{selectedChat.name}</span>
          <span className="text-gray-600 text-[10px]">{selectedChat.membersCount} members</span>
        </div>
        <button onClick={() => comingSoon("Members")} className="p-1 active:scale-90 transition-transform"><Users size={18} className="text-white/60" /></button>
        <button onClick={() => comingSoon("Chat Options")} className="p-1 active:scale-90 transition-transform"><MoreHorizontal size={18} className="text-white/60" /></button>
      </motion.div>
      <div className="flex-1 overflow-y-auto amino-scroll px-3 py-2">
        {chatMessages.map((msg, i) => {
          if (msg.isSystem) {
            return <motion.div key={msg.id} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: i * 0.02 }}
              className="text-center py-2 mb-2"><span className="text-gray-600 text-[10px] bg-[#1e1e38] px-3 py-1 rounded-full">{msg.content}</span></motion.div>;
          }
          const isMe = msg.userId === currentUser.id;
          return (
            <motion.div key={msg.id} initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.02 }}
              className={`mb-2.5 ${isMe ? "flex flex-col items-end" : ""}`}>
              <div className={`flex gap-2 max-w-[85%] ${isMe ? "flex-row-reverse" : ""}`}>
                <img src={msg.avatar} className="w-8 h-8 rounded-full object-cover shrink-0 mt-0.5" alt="" />
                <div>
                  <div className={`flex items-center gap-1.5 mb-0.5 ${isMe ? "flex-row-reverse" : ""}`}>
                    <span className={`text-[11px] font-semibold ${isMe ? "text-[#2dbe60]" : msg.role === "Leader" ? "text-[#2dbe60]" : msg.role === "Curator" ? "text-[#E040FB]" : "text-white"}`}>{msg.nickname}</span>
                    {msg.role === "Leader" && <span className="bg-[#2dbe60] text-white text-[7px] px-1 rounded font-bold">L</span>}
                    {msg.role === "Curator" && <span className="bg-[#E040FB] text-white text-[7px] px-1 rounded font-bold">C</span>}
                    <span className="text-gray-700 text-[9px]">{msg.time}</span>
                  </div>
                  <div className={`rounded-2xl px-3 py-2 text-[13px] leading-relaxed ${isMe ? "bg-[#2dbe60] text-white rounded-tr-sm" : "bg-[#1e1e38] text-gray-200 rounded-tl-sm"}`}>{msg.content}</div>
                  {msg.reactions && msg.reactions.length > 0 && (
                    <div className={`flex gap-1 mt-1 ${isMe ? "justify-end" : ""}`}>
                      {msg.reactions.map((r, ri) => <span key={ri} className="bg-[#1e1e38] text-[10px] px-1.5 py-0.5 rounded-full border border-white/5">{r.emoji} {r.count}</span>)}
                    </div>
                  )}
                </div>
              </div>
            </motion.div>
          );
        })}
        <div ref={messagesEndRef} />
      </div>
      <div className="flex items-center gap-1.5 px-2 py-2 bg-[#0b0b18] border-t border-white/5 shrink-0">
        <button onClick={() => comingSoon("Attach")} className="p-1.5 active:scale-90 transition-transform"><Plus size={18} className="text-gray-600" /></button>
        <button onClick={() => comingSoon("Stickers")} className="p-1.5 active:scale-90 transition-transform"><Smile size={18} className="text-gray-600" /></button>
        <input value={input} onChange={e => setInput(e.target.value)}
          onKeyDown={e => e.key === "Enter" && handleSend()}
          placeholder="Type a message..."
          className="flex-1 bg-[#1e1e38] text-white text-[13px] px-3 py-2 rounded-full placeholder:text-gray-700 outline-none" />
        {input.trim() ? (
          <motion.button whileTap={{ scale: 0.85 }} onClick={handleSend} className="p-1.5"><Send size={18} className="text-[#2dbe60]" /></motion.button>
        ) : (
          <button onClick={() => comingSoon("Voice Message")} className="p-1.5 active:scale-90 transition-transform"><Mic size={18} className="text-gray-600" /></button>
        )}
      </div>
    </motion.div>
  );
}

// ============ GLOBAL PROFILE SCREEN ============
function GlobalProfileScreen() {
  const { currentUser, communities, goBack, navigateTo, setSelectedCommunity } = useApp();
  const [activeProfileTab, setActiveProfileTab] = useState("stories");
  const joinedComms = communities.filter(c => c.isJoined);

  return (
    <motion.div {...pageVariants} className="flex flex-col h-full bg-[#1a1a2e]">
      <motion.div initial={{ y: -10, opacity: 0 }} animate={{ y: 0, opacity: 1 }}
        className="flex items-center justify-between px-3 py-2 bg-[#0f0f1e] border-b border-white/5 shrink-0" style={{ paddingTop: 38 }}>
        <button onClick={goBack} className="p-1 active:scale-90 transition-transform"><ChevronLeft size={22} className="text-white" /></button>
        <div className="flex items-center bg-[#2dbe60] rounded-full px-2.5 py-1 gap-1">
          <span className="text-[11px]">🪙</span>
          <span className="text-white text-[12px] font-bold">{currentUser.coins}</span>
          <Plus size={12} className="text-white ml-0.5" />
        </div>
        <button onClick={() => comingSoon("Share Profile")} className="p-1 active:scale-90 transition-transform"><Share2 size={20} className="text-white/70" /></button>
        <button onClick={() => comingSoon("Settings Menu")} className="p-1 active:scale-90 transition-transform"><Menu size={20} className="text-white/70" /></button>
      </motion.div>

      <div className="flex-1 overflow-y-auto amino-scroll">
        <motion.div initial={{ opacity: 0, y: 15 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }} className="px-4 pt-4 pb-3">
          <div className="flex items-start justify-between mb-3">
            <img src={currentUser.avatar} className="w-20 h-20 rounded-full object-cover border-2 border-white/10" alt="" />
            <motion.button whileTap={{ scale: 0.95 }} onClick={() => comingSoon("Edit Profile")}
              className="flex items-center gap-1.5 bg-[#2a2a40] text-white text-[12px] font-medium px-3 py-1.5 rounded-md border border-white/10">
              <Edit size={14} />Edit Profile
            </motion.button>
          </div>
          <div className="flex items-center gap-2 mb-1">
            <h2 className="text-white font-bold text-[20px]">{currentUser.nickname}</h2>
            <div className="bg-gradient-to-r from-blue-500 to-blue-600 text-white text-[8px] font-bold px-1.5 py-0.5 rounded">A+</div>
          </div>
          <p className="text-gray-500 text-[12px] mb-3">@{currentUser.nickname.toLowerCase().replace(/\s/g, "_")}</p>
          <div className="flex border border-white/10 rounded-lg overflow-hidden mb-4">
            <button onClick={() => comingSoon("Followers")} className="flex-1 py-3 text-center border-r border-white/10 active:bg-white/3 transition-colors">
              <p className="text-white font-bold text-[18px]">{formatNumber(currentUser.followers)}</p>
              <p className="text-gray-500 text-[11px]">Followers</p>
            </button>
            <button onClick={() => comingSoon("Following")} className="flex-1 py-3 text-center active:bg-white/3 transition-colors">
              <p className="text-white font-bold text-[18px]">{currentUser.following}</p>
              <p className="text-gray-500 text-[11px]">Following</p>
            </button>
          </div>
          <p className="text-gray-300 text-[13px] leading-relaxed mb-4">{currentUser.bio}</p>
          <motion.div whileTap={{ scale: 0.98 }}
            className="flex items-center gap-3 bg-[#2a2a40] rounded-lg px-3 py-2.5 mb-4 border border-white/5 active:bg-[#333350] transition-colors">
            <div className="bg-yellow-400 text-black font-black text-[10px] px-2 py-1 rounded shrink-0">Amino+</div>
            <span className="text-white text-[13px] font-medium">Try Amino+ for free today!</span>
          </motion.div>
          <div className="mb-4">
            <div className="flex items-center gap-1 mb-2 pb-2 border-b border-white/5">
              <Link2 size={14} className="text-gray-500" />
              <span className="text-gray-400 text-[12px] font-medium">Linked Communities</span>
            </div>
            <div className="grid grid-cols-2 gap-3">
              {joinedComms.slice(0, 4).map((c, i) => (
                <motion.button key={c.id} initial={{ opacity: 0, y: 5 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 + i * 0.05 }}
                  whileTap={{ scale: 0.95 }}
                  onClick={() => { setSelectedCommunity(c); navigateTo("community"); }}
                  className="text-left active:bg-white/3 rounded-lg p-1.5 transition-colors">
                  <p className="text-white text-[13px] font-semibold leading-tight">{c.name}</p>
                  <p className="text-gray-600 text-[10px]">ID:{c.aminoId}</p>
                </motion.button>
              ))}
            </div>
          </div>
        </motion.div>
        <div className="flex border-b border-white/10 bg-[#16162a]">
          {[{ id: "stories", label: "Stories" }, { id: "wall", label: "Wall" }].map(tab => (
            <button key={tab.id} onClick={() => setActiveProfileTab(tab.id)}
              className={`flex-1 py-3 text-[13px] font-bold text-center transition-colors relative ${activeProfileTab === tab.id ? "text-white" : "text-gray-600"}`}>
              {tab.label}
              {activeProfileTab === tab.id && <motion.div layoutId="profileTab" className="absolute bottom-0 left-0 right-0 h-[2px] bg-white" />}
            </button>
          ))}
        </div>
        <div className="bg-[#16162a] min-h-[200px]">
          {activeProfileTab === "stories" ? (
            <motion.div {...fadeUp} className="p-4">
              <div className="grid grid-cols-2 gap-2">
                <div className="bg-[#1e1e38] rounded-lg h-[120px] flex items-center justify-center active:bg-[#252548] transition-colors cursor-pointer">
                  <div className="text-center">
                    <div className="w-10 h-10 rounded-full border-2 border-dashed border-white/20 flex items-center justify-center mx-auto mb-2">
                      <Plus size={18} className="text-white/30" />
                    </div>
                    <p className="text-gray-600 text-[10px]">Add Story</p>
                  </div>
                </div>
              </div>
            </motion.div>
          ) : (
            <motion.div {...fadeUp} className="p-4 text-center">
              <p className="text-gray-600 text-[13px]">No wall posts yet</p>
            </motion.div>
          )}
        </div>
      </div>
    </motion.div>
  );
}

// ============ COMMUNITY PROFILE SCREEN ============
function CommunityProfileScreen() {
  const { selectedCommunity, currentUser, goBack, getCommunityProfile } = useApp();
  const [activeTab, setActiveTab] = useState("posts");

  if (!selectedCommunity) return null;

  const profile = getCommunityProfile(selectedCommunity.id);
  const displayName = profile?.nickname || currentUser.nickname;
  const displayAvatar = profile?.avatar || currentUser.avatar;
  const displayBio = profile?.bio || "No bio set for this community yet.";
  const displayBg = profile?.backgroundImage || selectedCommunity.cover;
  const displayRep = profile?.reputation || 0;
  const displayFollowing = profile?.following || 0;
  const displayFollowers = profile?.followers || 0;
  const displayBadges = profile?.badges || [];
  const displayStreak = profile?.streakDays || 0;
  const displayRole = profile?.role || "Member";
  const displayJoinedAt = profile?.joinedAt || "Recently";
  const displayPostsCount = profile?.postsCount || 0;
  const lvl = getLevelFromRep(displayRep);

  return (
    <motion.div {...pageVariants} className="flex flex-col h-full">
      <div className="flex-1 overflow-y-auto amino-scroll">
        <div className="relative h-[320px]">
          <img src={displayBg} className="w-full h-full object-cover" alt="" />
          <div className="absolute inset-0 bg-gradient-to-t from-[#0f0f1e] via-transparent to-black/20" />
          <button onClick={goBack} className="absolute top-10 left-3 p-1.5 bg-black/40 rounded-full z-10 active:scale-90 transition-transform"><ChevronLeft size={20} className="text-white" /></button>
          <button onClick={() => comingSoon("Profile Options")} className="absolute top-10 right-3 p-1.5 bg-black/40 rounded-full z-10 active:scale-90 transition-transform"><MoreHorizontal size={20} className="text-white" /></button>
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }}
            className="absolute bottom-4 left-0 right-0 flex flex-col items-center">
            <div className="relative mb-2">
              <div className="w-20 h-20 rounded-full p-[3px] bg-gradient-to-br from-pink-400 via-purple-400 to-blue-400 shadow-lg">
                <img src={displayAvatar} className="w-full h-full rounded-full object-cover border-2 border-[#0f0f1e]" alt="" />
              </div>
            </div>
            <h2 className="text-white font-bold text-[18px] mb-1 text-center px-4">{displayName}</h2>
            <div className="flex items-center gap-1 mb-2">
              <span className="bg-gradient-to-r from-blue-700 to-blue-500 text-white text-[10px] font-bold px-2 py-0.5 rounded-md">Lv{lvl.level}</span>
              <span className="text-white/70 text-[11px]">{lvl.title}</span>
            </div>
            <div className="w-32 h-1.5 bg-gray-700 rounded-full overflow-hidden mb-2">
              <motion.div initial={{ width: 0 }} animate={{ width: `${lvl.progress * 100}%` }} transition={{ delay: 0.5, duration: 0.8 }}
                className="h-full bg-gradient-to-r from-blue-500 to-blue-400 rounded-full" />
            </div>
            <div className="flex flex-wrap justify-center gap-1.5 px-6 mb-2">
              {displayRole !== "Member" && (
                <span className={`text-[10px] font-bold px-2.5 py-1 rounded-full ${displayRole === "Leader" ? "bg-[#2dbe60] text-white" : "bg-[#E040FB] text-white"}`}>{displayRole}</span>
              )}
              {displayBadges.map((badge: Badge, i: number) => (
                <span key={i} className="text-[10px] font-bold px-2.5 py-1 rounded-full" style={{ backgroundColor: badge.color, color: "white" }}>{badge.label}</span>
              ))}
            </div>
            <div className="flex items-center gap-3">
              <motion.button whileTap={{ scale: 0.9 }} onClick={() => comingSoon("Follow")}
                className="w-10 h-10 rounded-full bg-[#2dbe60] flex items-center justify-center shadow-lg"><User size={18} className="text-white" /></motion.button>
              <motion.button whileTap={{ scale: 0.95 }} onClick={() => comingSoon("Chat")}
                className="flex items-center gap-1.5 bg-white text-[#0f0f1e] font-bold text-[13px] px-4 py-2 rounded-full shadow-lg">
                <MessageCircle size={16} />Chat
              </motion.button>
            </div>
          </motion.div>
        </div>
        {displayStreak > 0 && (
          <div className="bg-gradient-to-r from-[#FF6F00] to-[#FFB300] px-4 py-2 flex items-center gap-2">
            <Trophy size={16} className="text-white" />
            <span className="text-white text-[13px] font-bold">{displayStreak} Day Streak</span>
          </div>
        )}
        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.3 }}
          className="flex items-center py-4 px-4 bg-[#0f0f1e]">
          <div className="flex-1 text-center">
            <p className="text-white font-black text-[22px]">{formatNumber(displayRep)}</p>
            <p className="text-gray-500 text-[11px]">Reputation</p>
          </div>
          <div className="w-px h-8 bg-white/10" />
          <div className="flex-1 text-center">
            <p className="text-white font-black text-[22px]">{displayFollowing}</p>
            <p className="text-gray-500 text-[11px]">Following</p>
          </div>
          <div className="w-px h-8 bg-white/10" />
          <div className="flex-1 text-center">
            <p className="text-white font-black text-[22px]">{formatNumber(displayFollowers)}</p>
            <p className="text-gray-500 text-[11px]">Followers</p>
          </div>
        </motion.div>
        <div className="px-4 py-3 bg-[#0f0f1e] border-t border-white/5">
          <div className="flex items-baseline gap-2 mb-1">
            <h3 className="text-white font-bold text-[15px]">Biography</h3>
            <span className="text-gray-600 text-[11px]">Member since {displayJoinedAt}</span>
          </div>
          <p className="text-gray-300 text-[13px] leading-relaxed">{displayBio}</p>
        </div>
        <div className="px-4 py-2 bg-[#16162a] border-t border-white/5 flex items-center gap-2">
          <img src={selectedCommunity.icon} className="w-5 h-5 rounded object-cover" alt="" />
          <span className="text-gray-500 text-[11px]">in <span className="text-[#2dbe60] font-semibold">{selectedCommunity.name}</span></span>
        </div>
        <div className="flex border-b border-white/10 bg-[#0f0f1e]">
          {["posts", "wall", "media"].map(tab => (
            <button key={tab} onClick={() => setActiveTab(tab)}
              className={`flex-1 py-3 text-[13px] font-bold text-center capitalize transition-colors relative ${activeTab === tab ? "text-white" : "text-gray-600"}`}>
              {tab}
              {activeTab === tab && <motion.div layoutId="commProfileTab" className="absolute bottom-0 left-0 right-0 h-[2px] bg-white" />}
            </button>
          ))}
        </div>
        <div className="bg-[#0f0f1e] min-h-[200px] px-4 py-4">
          {activeTab === "posts" ? (
            displayPostsCount > 0 ? (
              <p className="text-gray-600 text-[12px]">{displayPostsCount} posts in this community</p>
            ) : (
              <motion.div {...fadeUp} className="text-center py-6">
                <FileText size={28} className="text-gray-700 mx-auto mb-2" />
                <p className="text-gray-600 text-[13px]">No posts yet</p>
              </motion.div>
            )
          ) : (
            <motion.div {...fadeUp} className="text-center py-6">
              <p className="text-gray-600 text-[13px]">No {activeTab} content yet</p>
            </motion.div>
          )}
        </div>
      </div>
    </motion.div>
  );
}

// ============ MAIN HOME COMPONENT ============
export default function Home() {
  const { activeTab, currentScreen, selectedCommunity, toggleJoinCommunity, setSelectedCommunity, navigateTo } = useApp();
  const [showSearch, setShowSearch] = useState(false);

  // Join Community screen handler
  const handleJoinAndEnter = () => {
    if (selectedCommunity) {
      toggleJoinCommunity(selectedCommunity.id);
      // Navigate to community after joining
      navigateTo("community");
    }
  };

  return (
    <AnimatePresence mode="wait">
      {showSearch ? (
        <motion.div key="search" {...fadeIn} className="h-full">
          <SearchScreen onClose={() => setShowSearch(false)} />
        </motion.div>
      ) : currentScreen === "joinCommunity" && selectedCommunity ? (
        <motion.div key="join" className="h-full">
          <JoinCommunityScreen
            community={selectedCommunity}
            onJoin={handleJoinAndEnter}
            onClose={() => navigateTo("main")}
          />
        </motion.div>
      ) : currentScreen === "community" ? (
        <motion.div key="community" className="h-full"><CommunityDetailScreen /></motion.div>
      ) : currentScreen === "communityProfile" ? (
        <motion.div key="commProfile" className="h-full"><CommunityProfileScreen /></motion.div>
      ) : currentScreen === "post" ? (
        <motion.div key="post" className="h-full"><PostDetailScreen /></motion.div>
      ) : currentScreen === "chatroom" ? (
        <motion.div key="chatroom" className="h-full"><ChatRoomScreen /></motion.div>
      ) : currentScreen === "profile" ? (
        <motion.div key="profile" className="h-full"><GlobalProfileScreen /></motion.div>
      ) : (
        <motion.div key="main" {...fadeIn} className="flex flex-col h-full">
          <AminoMainHeader onSearchClick={() => setShowSearch(true)} />
          <div className="flex-1 overflow-y-auto">
            <AnimatePresence mode="wait">
              {activeTab === "discover" && <motion.div key="discover" {...fadeUp}><DiscoverTab /></motion.div>}
              {activeTab === "communities" && <motion.div key="communities" {...fadeUp}><CommunitiesTab /></motion.div>}
              {activeTab === "chats" && <motion.div key="chats" {...fadeUp}><ChatsTab /></motion.div>}
              {activeTab === "store" && <motion.div key="store" {...fadeUp}><StoreTab /></motion.div>}
            </AnimatePresence>
          </div>
          <BottomNav />
        </motion.div>
      )}
    </AnimatePresence>
  );
}
