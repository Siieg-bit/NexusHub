import { useState, useEffect, useRef } from "react";
import { useApp, Community, Post, ChatRoom as ChatRoomType, Badge, CommunityProfile } from "@/contexts/AppContext";
import { toast } from "sonner";
import { Search, Bell, Plus, ChevronLeft, ChevronRight, Heart, MessageCircle, Share2, Pin, Send, Smile, Mic, Users, Clock, Globe, Trophy, Star, BookOpen, MoreHorizontal, Check, Flame, Award, Bookmark, Menu, X, Home as HomeIcon, Zap, BarChart3, Image, FileText, HelpCircle, Settings, LogOut, Eye, TrendingUp, Crown, Shield, Hash, ArrowUp, PenSquare, ChevronDown, Link2, Compass, Grid3X3, ShoppingBag, User, Edit, ExternalLink } from "lucide-react";

// ============ HELPERS ============
function getTimeAgo(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return "now";
  if (mins < 60) return `${mins}m`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days}d`;
  return `${Math.floor(days / 7)}w`;
}

function formatNumber(n: number): string {
  if (n >= 1000000) return `${(n / 1000000).toFixed(1)}M`;
  if (n >= 1000) return `${(n / 1000).toFixed(n >= 10000 ? 0 : 1)}K`;
  return n.toString();
}

function comingSoon(feature: string) {
  toast(`${feature} - Coming soon!`, { duration: 2000 });
}

function getLevelFromRep(totalRep: number): { level: number; title: string; progress: number; nextLevelRep: number } {
  const levels = [
    { level: 1, title: "Newcomer", minRep: 0 },
    { level: 2, title: "Beginner", minRep: 200 },
    { level: 3, title: "Apprentice", minRep: 500 },
    { level: 4, title: "Regular", minRep: 1000 },
    { level: 5, title: "Active", minRep: 2000 },
    { level: 6, title: "Contributor", minRep: 3500 },
    { level: 7, title: "Veteran", minRep: 5500 },
    { level: 8, title: "Expert", minRep: 8000 },
    { level: 9, title: "Master", minRep: 11000 },
    { level: 10, title: "Elite", minRep: 15000 },
    { level: 11, title: "Champion", minRep: 20000 },
    { level: 12, title: "Legend", minRep: 26000 },
    { level: 13, title: "Mythic", minRep: 33000 },
    { level: 14, title: "Immortal", minRep: 41000 },
    { level: 15, title: "Transcendent", minRep: 50000 },
    { level: 16, title: "Ascended", minRep: 60000 },
    { level: 17, title: "Celestial", minRep: 72000 },
    { level: 18, title: "Divine", minRep: 86000 },
    { level: 19, title: "Omniscient", minRep: 102000 },
    { level: 20, title: "Supreme", minRep: 120000 },
  ];
  let current = levels[0];
  let next = levels[1];
  for (let i = levels.length - 1; i >= 0; i--) {
    if (totalRep >= levels[i].minRep) {
      current = levels[i];
      next = levels[Math.min(i + 1, levels.length - 1)];
      break;
    }
  }
  const progress = next.minRep > current.minRep
    ? ((totalRep - current.minRep) / (next.minRep - current.minRep)) * 100
    : 100;
  return { level: current.level, title: current.title, progress: Math.min(progress, 100), nextLevelRep: next.minRep };
}

// ============ AMINO MAIN HEADER ============
function AminoMainHeader({ onBack, title, showSearch = true, rightContent, onSearchClick }: {
  onBack?: () => void; title?: string; showSearch?: boolean; rightContent?: React.ReactNode; onSearchClick?: () => void;
}) {
  const { currentUser, navigateTo } = useApp();
  return (
    <div className="sticky top-0 z-40 flex items-center gap-2 px-3 py-2 bg-[#0f0f1e]/95 backdrop-blur-sm border-b border-white/5" style={{ paddingTop: 38 }}>
      {onBack ? (
        <button onClick={onBack} className="p-1"><ChevronLeft size={22} className="text-white" /></button>
      ) : (
        <button onClick={() => navigateTo("profile")} className="shrink-0">
          <img src={currentUser.avatar} className="w-8 h-8 rounded-full object-cover border-2 border-[#2dbe60]/50" alt="" />
        </button>
      )}
      {title ? (
        <span className="text-white font-semibold text-[15px] flex-1 truncate">{title}</span>
      ) : showSearch ? (
        <div className="flex-1 flex items-center bg-[#1a1a2e] rounded-full px-3 py-1.5 mx-1 cursor-pointer" onClick={onSearchClick}>
          <Search size={14} className="text-gray-500 mr-2" />
          <span className="text-gray-500 text-[13px]">Search Amino</span>
        </div>
      ) : <div className="flex-1" />}
      {rightContent || (
        <>
          <div className="flex items-center bg-[#2dbe60] rounded-full px-2 py-0.5 gap-1 shrink-0">
            <span className="text-[11px]">🪙</span>
            <span className="text-white text-[11px] font-bold">{currentUser.coins}</span>
          </div>
          <button onClick={() => comingSoon("Notifications")} className="relative p-1">
            <Bell size={20} className="text-white/70" />
            <span className="absolute top-0 right-0 w-2 h-2 bg-red-500 rounded-full" />
          </button>
        </>
      )}
    </div>
  );
}

// ============ BOTTOM NAV (Main App) ============
function BottomNav() {
  const { activeTab, setActiveTab, setCurrentScreen, setSelectedCommunity, setSelectedPost, setSelectedChat } = useApp();
  const tabs = [
    { id: "discover", label: "Discover", icon: (a: boolean) => <Compass size={22} strokeWidth={a ? 2.5 : 1.5} /> },
    { id: "communities", label: "Communities", icon: (a: boolean) => (
      <svg viewBox="0 0 24 24" fill={a ? "currentColor" : "none"} stroke="currentColor" strokeWidth={a ? 0 : 1.5} className="w-[22px] h-[22px]">
        <rect x="3" y="3" width="7" height="7" rx="1.5" /><rect x="14" y="3" width="7" height="7" rx="1.5" />
        <rect x="3" y="14" width="7" height="7" rx="1.5" /><rect x="14" y="14" width="7" height="7" rx="1.5" />
      </svg>
    )},
    { id: "chats", label: "Chats", icon: (a: boolean) => <MessageCircle size={22} strokeWidth={a ? 2.5 : 1.5} fill={a ? "currentColor" : "none"} /> },
    { id: "store", label: "Store", icon: (a: boolean) => <ShoppingBag size={22} strokeWidth={a ? 2.5 : 1.5} /> },
  ];
  return (
    <div className="sticky bottom-0 z-40 flex items-center bg-[#0b0b18] border-t border-white/5" style={{ paddingBottom: 4 }}>
      {tabs.map(tab => (
        <button key={tab.id} onClick={() => {
          setActiveTab(tab.id); setCurrentScreen("main");
          setSelectedCommunity(null); setSelectedPost(null); setSelectedChat(null);
        }}
          className={`flex-1 flex flex-col items-center py-2 gap-0.5 transition-colors ${activeTab === tab.id ? "text-[#2dbe60]" : "text-gray-600"}`}>
          {tab.icon(activeTab === tab.id)}
          <span className="text-[9px] font-medium">{tab.label}</span>
        </button>
      ))}
    </div>
  );
}

// ============ POST CARD ============
function PostCard({ post, onPress, showCommunity = true }: { post: Post; onPress: () => void; showCommunity?: boolean }) {
  const { toggleLike, votePoll } = useApp();
  return (
    <div className="mb-2.5 bg-[#16162a] rounded-lg overflow-hidden" onClick={onPress}>
      {showCommunity && (
        <div className="flex items-center gap-2 px-3 pt-2.5 pb-1">
          <img src={post.communityIcon} className="w-5 h-5 rounded object-cover" alt="" />
          <span className="text-[#2dbe60] text-[11px] font-semibold">{post.communityName}</span>
          {post.isPinned && <span className="ml-auto bg-[#2dbe60]/15 text-[#2dbe60] text-[8px] px-1.5 py-0.5 rounded font-bold flex items-center gap-0.5"><Pin size={7} />PINNED</span>}
          {post.isFeatured && !post.isPinned && <span className="ml-auto bg-yellow-500/15 text-yellow-400 text-[8px] px-1.5 py-0.5 rounded font-bold flex items-center gap-0.5"><Star size={7} />FEATURED</span>}
        </div>
      )}
      <div className="flex items-center gap-2 px-3 pb-2">
        <img src={post.author.avatar} className="w-7 h-7 rounded-full object-cover" alt="" />
        <div className="flex items-center gap-1.5 flex-1 min-w-0">
          <span className="text-white text-[12px] font-semibold truncate">{post.author.nickname}</span>
          {post.author.role === "Leader" && <span className="bg-[#2dbe60] text-white text-[7px] px-1 py-px rounded font-bold shrink-0">Leader</span>}
          {post.author.role === "Curator" && <span className="bg-[#E040FB] text-white text-[7px] px-1 py-px rounded font-bold shrink-0">Curator</span>}
        </div>
        <span className="text-gray-600 text-[10px] shrink-0">{getTimeAgo(post.createdAt)}</span>
      </div>
      <div className="px-3 pb-2">
        {post.type === "poll" && <div className="flex items-center gap-1 mb-1.5"><BarChart3 size={12} className="text-blue-400" /><span className="text-blue-400 text-[10px] font-semibold uppercase">Poll</span></div>}
        {post.type === "quiz" && <div className="flex items-center gap-1 mb-1.5"><HelpCircle size={12} className="text-purple-400" /><span className="text-purple-400 text-[10px] font-semibold uppercase">Quiz</span></div>}
        <h4 className="text-white font-bold text-[14px] leading-snug mb-1">{post.title}</h4>
        <p className="text-gray-400 text-[12px] leading-relaxed line-clamp-2">{post.content}</p>
      </div>
      {post.mediaUrl && <div className="px-3 pb-2"><img src={post.mediaUrl} className="w-full h-[160px] object-cover rounded-md" alt="" /></div>}
      {post.type === "poll" && post.pollOptions && (
        <div className="px-3 pb-2 space-y-1.5">
          {post.pollOptions.map(opt => (
            <button key={opt.id} onClick={(e) => { e.stopPropagation(); votePoll(post.id, opt.id); }}
              className="w-full relative overflow-hidden rounded-md bg-[#1e1e38] text-left">
              <div className="absolute inset-y-0 left-0 bg-blue-500/15 transition-all" style={{ width: `${opt.percentage}%` }} />
              <div className="relative flex items-center justify-between px-3 py-2">
                <span className={`text-[12px] ${opt.isVoted ? "text-blue-400 font-semibold" : "text-gray-400"}`}>{opt.text}</span>
                <span className="text-gray-600 text-[11px]">{opt.percentage}%</span>
              </div>
            </button>
          ))}
        </div>
      )}
      <div className="flex items-center gap-4 px-3 pb-2.5 pt-1 border-t border-white/3 mt-1">
        <button onClick={(e) => { e.stopPropagation(); toggleLike(post.id); }}
          className={`flex items-center gap-1 text-[11px] ${post.isLiked ? "text-red-400" : "text-gray-600"}`}>
          <Heart size={14} fill={post.isLiked ? "currentColor" : "none"} />{post.likesCount}
        </button>
        <span className="flex items-center gap-1 text-gray-600 text-[11px]"><MessageCircle size={14} />{post.commentsCount}</span>
      </div>
    </div>
  );
}

// ============ SEARCH SCREEN (Amino faithful) ============
function SearchScreen({ onClose }: { onClose: () => void }) {
  const { communities, navigateTo, setSelectedCommunity, toggleJoinCommunity } = useApp();
  const [query, setQuery] = useState("");
  const [searchTab, setSearchTab] = useState("communities");
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    setTimeout(() => inputRef.current?.focus(), 100);
  }, []);

  const filtered = query.trim()
    ? communities.filter(c =>
        c.name.toLowerCase().includes(query.toLowerCase()) ||
        c.id.toLowerCase().includes(query.toLowerCase()) ||
        c.description.toLowerCase().includes(query.toLowerCase()) ||
        (c.tags && c.tags.some(t => t.toLowerCase().includes(query.toLowerCase())))
      )
    : [];

  // Exact match by ID
  const exactMatch = query.trim()
    ? communities.find(c => c.id.toLowerCase() === query.toLowerCase() || c.name.toLowerCase() === query.toLowerCase())
    : null;

  // Keyword matches (excluding exact match)
  const keywordMatches = filtered.filter(c => c !== exactMatch);

  // Tag colors for search results
  const tagColors = ["#FF9800", "#4CAF50", "#E91E63", "#9E9E9E", "#03A9F4", "#FF5722", "#8BC34A", "#673AB7"];

  const tabs = [
    { id: "communities", label: "Communities" },
    { id: "users", label: "Users" },
    { id: "chats", label: "Chats" },
    { id: "others", label: "Others" },
  ];

  return (
    <div className="flex flex-col h-full bg-[#0f0f1e]">
      {/* Search Header */}
      <div className="flex items-center gap-2 px-3 py-2 bg-[#0f0f1e] border-b border-white/5" style={{ paddingTop: 38 }}>
        <div className="flex-1 flex items-center bg-[#2a2a40] rounded-full px-3 py-2">
          <Search size={16} className="text-gray-500 mr-2 shrink-0" />
          <input
            ref={inputRef}
            value={query}
            onChange={e => setQuery(e.target.value)}
            placeholder="Search communities, users..."
            className="flex-1 bg-transparent text-white text-[14px] outline-none placeholder:text-gray-600"
          />
          {query && (
            <button onClick={() => setQuery("")} className="p-0.5 ml-1">
              <X size={16} className="text-gray-500" />
            </button>
          )}
        </div>
        <button onClick={onClose} className="text-gray-400 text-[14px] font-medium shrink-0 pl-1">Cancel</button>
      </div>

      {/* Search Tabs */}
      <div className="flex border-b border-white/5">
        {tabs.map(tab => (
          <button key={tab.id} onClick={() => setSearchTab(tab.id)}
            className={`flex-1 py-2.5 text-[13px] font-semibold text-center transition-colors relative ${searchTab === tab.id ? "text-white" : "text-gray-600"}`}>
            {tab.label}
            {searchTab === tab.id && <div className="absolute bottom-0 left-2 right-2 h-[2px] bg-white rounded-full" />}
          </button>
        ))}
      </div>

      {/* Search Results */}
      <div className="flex-1 overflow-y-auto amino-scroll">
        {!query.trim() ? (
          <div className="px-4 pt-8 text-center">
            <Search size={40} className="text-gray-700 mx-auto mb-3" />
            <p className="text-gray-600 text-[14px]">Search for communities, users, and chats</p>
          </div>
        ) : searchTab === "communities" ? (
          <div>
            {/* Exact match by ID */}
            {exactMatch && (
              <div className="px-3 pt-3">
                <p className="text-gray-500 text-[11px] mb-2 font-medium">Identified by Amino ID / Link</p>
                <button onClick={() => { setSelectedCommunity(exactMatch); navigateTo("community"); onClose(); }}
                  className="w-full flex items-center gap-3 py-2 text-left">
                  <img src={exactMatch.icon} className="w-12 h-12 rounded-full object-cover shrink-0" alt="" />
                  <div>
                    <p className="text-white text-[15px] font-bold">{exactMatch.name}</p>
                    <p className="text-gray-500 text-[12px]">@{exactMatch.id}</p>
                  </div>
                </button>
                <div className="h-px bg-white/5 mt-2" />
              </div>
            )}

            {/* Keyword results */}
            {keywordMatches.length > 0 && (
              <div className="px-3 pt-3">
                <p className="text-gray-500 text-[11px] mb-3 font-medium">Search Results by Keywords</p>
                {keywordMatches.map(c => (
                  <button key={c.id} onClick={() => { setSelectedCommunity(c); navigateTo("community"); onClose(); }}
                    className="w-full flex gap-3 mb-4 text-left">
                    {/* Community image - square, rounded */}
                    <img src={c.cover} className="w-[110px] h-[110px] rounded-xl object-cover shrink-0" alt="" />
                    {/* Info */}
                    <div className="flex-1 min-w-0 py-0.5">
                      <h4 className="text-white font-bold text-[15px] leading-tight mb-1">{c.name}</h4>
                      <div className="inline-flex items-center bg-[#2a2a40] rounded px-1.5 py-0.5 mb-1">
                        <span className="text-gray-400 text-[10px]">ID Amino: {c.id}</span>
                      </div>
                      <p className="text-gray-400 text-[11px] mb-1.5">{formatNumber(c.members)} Members | {c.language || "English"}</p>
                      {/* Tags with colored borders */}
                      {c.tags && c.tags.length > 0 && (
                        <div className="flex flex-wrap gap-1 mb-1.5">
                          {c.tags.slice(0, 4).map((tag, i) => (
                            <span key={tag} className="text-[9px] font-semibold px-2 py-0.5 rounded-full border"
                              style={{ borderColor: tagColors[i % tagColors.length], color: tagColors[i % tagColors.length] }}>
                              {tag}
                            </span>
                          ))}
                        </div>
                      )}
                      <p className="text-gray-500 text-[11px] line-clamp-2 leading-snug">{c.description}</p>
                    </div>
                  </button>
                ))}
              </div>
            )}

            {!exactMatch && keywordMatches.length === 0 && (
              <div className="px-4 pt-8 text-center">
                <p className="text-gray-600 text-[13px]">No communities found for "{query}"</p>
              </div>
            )}
          </div>
        ) : (
          <div className="px-4 pt-8 text-center">
            <p className="text-gray-600 text-[13px]">{searchTab === "users" ? "User" : searchTab === "chats" ? "Chat" : "Other"} search coming soon</p>
          </div>
        )}
      </div>
    </div>
  );
}

// ============ DISCOVER TAB ============
function DiscoverTab() {
  const { communities, categories, posts, navigateTo, setSelectedCommunity, setSelectedPost, toggleJoinCommunity } = useApp();
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [bannerIdx, setBannerIdx] = useState(0);
  const trending = [...communities].sort((a, b) => b.members - a.members).slice(0, 5);
  const banners = trending.slice(0, 3);

  useEffect(() => {
    if (banners.length === 0) return;
    const t = setInterval(() => setBannerIdx(i => (i + 1) % banners.length), 4000);
    return () => clearInterval(t);
  }, [banners.length]);

  const filteredCommunities = selectedCategory
    ? communities.filter(c => c.categoryId === selectedCategory)
    : communities;

  const categoriesWithCommunities = categories.filter(cat =>
    communities.some(c => c.categoryId === cat.id)
  );

  return (
    <div className="amino-scroll">
      {/* Category Pills */}
      <div className="flex gap-1.5 px-3 py-2 overflow-x-auto amino-scroll">
        <button onClick={() => setSelectedCategory(null)}
          className={`shrink-0 px-3 py-1.5 rounded-full text-[11px] font-semibold transition-colors ${!selectedCategory ? "bg-[#2dbe60] text-white" : "bg-[#1a1a2e] text-gray-400"}`}>
          All
        </button>
        {categories.map(cat => (
          <button key={cat.id} onClick={() => setSelectedCategory(selectedCategory === cat.id ? null : cat.id)}
            className={`shrink-0 px-3 py-1.5 rounded-full text-[11px] font-semibold transition-colors flex items-center gap-1 ${selectedCategory === cat.id ? "bg-[#2dbe60] text-white" : "bg-[#1a1a2e] text-gray-400"}`}>
            <span className="text-[13px]">{cat.icon}</span>{cat.name}
          </button>
        ))}
      </div>

      {selectedCategory ? (
        <div className="px-3 pt-2 pb-20">
          <h3 className="text-white font-bold text-[16px] mb-3">{categories.find(c => c.id === selectedCategory)?.name}</h3>
          {/* Amino-style search results for category */}
          {filteredCommunities.map(c => (
            <button key={c.id} className="w-full flex gap-3 mb-4 text-left"
              onClick={() => { setSelectedCommunity(c); navigateTo("community"); }}>
              <img src={c.cover} className="w-[100px] h-[100px] rounded-xl object-cover shrink-0" alt="" />
              <div className="flex-1 min-w-0 py-0.5">
                <h4 className="text-white font-bold text-[14px] leading-tight mb-0.5">{c.name}</h4>
                <div className="inline-flex items-center bg-[#2a2a40] rounded px-1.5 py-0.5 mb-1">
                  <span className="text-gray-400 text-[9px]">ID: {c.id}</span>
                </div>
                <p className="text-gray-400 text-[10px] mb-1">{formatNumber(c.members)} Members</p>
                {c.tags && c.tags.length > 0 && (
                  <div className="flex flex-wrap gap-1 mb-1">
                    {c.tags.slice(0, 3).map((tag, i) => {
                      const colors = ["#FF9800", "#4CAF50", "#E91E63", "#03A9F4"];
                      return (
                        <span key={tag} className="text-[8px] font-semibold px-1.5 py-0.5 rounded-full border"
                          style={{ borderColor: colors[i % colors.length], color: colors[i % colors.length] }}>
                          {tag}
                        </span>
                      );
                    })}
                  </div>
                )}
                <p className="text-gray-500 text-[10px] line-clamp-1">{c.description}</p>
              </div>
            </button>
          ))}
        </div>
      ) : (
        <>
          {/* Banner Carousel */}
          {banners.length > 0 && (
            <div className="relative h-[170px] overflow-hidden">
              {banners.map((c, i) => (
                <div key={c.id} className={`absolute inset-0 transition-opacity duration-700 ${i === bannerIdx ? "opacity-100" : "opacity-0 pointer-events-none"}`}
                  onClick={() => { setSelectedCommunity(c); navigateTo("community"); }}>
                  <img src={c.cover} className="w-full h-full object-cover" alt="" />
                  <div className="absolute inset-0 bg-gradient-to-t from-[#0f0f1e] via-black/30 to-transparent" />
                  <div className="absolute bottom-3 left-3 right-3">
                    <div className="flex items-center gap-2 mb-1">
                      <img src={c.icon} className="w-8 h-8 rounded-lg object-cover border border-white/20" alt="" />
                      <div>
                        <p className="text-white font-bold text-[14px] leading-tight">{c.name}</p>
                        <p className="text-white/60 text-[10px]">{formatNumber(c.members)} Members</p>
                      </div>
                    </div>
                  </div>
                </div>
              ))}
              <div className="absolute bottom-1.5 left-1/2 -translate-x-1/2 flex gap-1.5 z-10">
                {banners.map((_, i) => <div key={i} className={`w-1.5 h-1.5 rounded-full transition-colors ${i === bannerIdx ? "bg-[#2dbe60]" : "bg-white/30"}`} />)}
              </div>
            </div>
          )}

          {/* Trending */}
          <div className="px-3 pt-2 pb-1">
            <div className="flex items-center justify-between mb-2">
              <h3 className="text-white font-bold text-[15px] flex items-center gap-1.5"><TrendingUp size={16} className="text-[#2dbe60]" />Trending</h3>
            </div>
            <div className="flex gap-2.5 overflow-x-auto pb-2 amino-scroll">
              {trending.map(c => (
                <div key={c.id} className="shrink-0 w-[120px] relative rounded-lg overflow-hidden"
                  onClick={() => { setSelectedCommunity(c); navigateTo("community"); }}>
                  <img src={c.cover} className="w-full h-[140px] object-cover" alt="" />
                  <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/20 to-transparent" />
                  <div className="absolute bottom-0 left-0 right-0 p-2">
                    <p className="text-white text-[10px] font-semibold leading-tight mb-0.5 line-clamp-2">{c.name}</p>
                    <p className="text-white/50 text-[8px]">{formatNumber(c.members)} members</p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Browse by Category */}
          <div className="px-3 pt-3 pb-2">
            <h3 className="text-white font-bold text-[15px] mb-3">Browse by Category</h3>
            {categoriesWithCommunities.map(cat => {
              const catComms = communities.filter(c => c.categoryId === cat.id);
              return (
                <div key={cat.id} className="mb-4">
                  <button onClick={() => setSelectedCategory(cat.id)}
                    className="flex items-center gap-2 mb-2 w-full">
                    <div className="w-8 h-8 rounded-lg flex items-center justify-center" style={{ backgroundColor: cat.color + "20" }}>
                      <span className="text-[16px]">{cat.icon}</span>
                    </div>
                    <span className="text-white font-semibold text-[14px] flex-1 text-left">{cat.name}</span>
                    <span className="text-gray-600 text-[11px]">{catComms.length}</span>
                    <ChevronRight size={14} className="text-gray-600" />
                  </button>
                  <div className="flex gap-2 overflow-x-auto amino-scroll pb-1">
                    {catComms.slice(0, 4).map(c => (
                      <div key={c.id} className="shrink-0 w-[80px]" onClick={() => { setSelectedCommunity(c); navigateTo("community"); }}>
                        <img src={c.icon} className="w-[80px] h-[80px] rounded-lg object-cover mb-1" alt="" />
                        <p className="text-white text-[9px] font-medium leading-tight truncate">{c.name}</p>
                        <p className="text-gray-600 text-[8px]">{formatNumber(c.members)}</p>
                      </div>
                    ))}
                  </div>
                </div>
              );
            })}
          </div>

          {/* Latest Posts */}
          <div className="px-3 pt-1 pb-20">
            <h3 className="text-white font-bold text-[15px] mb-2">Latest Posts</h3>
            {posts.map(post => (
              <PostCard key={post.id} post={post} onPress={() => { setSelectedPost(post); navigateTo("post"); }} />
            ))}
          </div>
        </>
      )}
    </div>
  );
}

// ============ COMMUNITIES TAB (Amino faithful - vertical compact cards) ============
function CommunitiesTab() {
  const { communities, navigateTo, setSelectedCommunity, checkIn, toggleJoinCommunity } = useApp();
  const joined = communities.filter(c => c.isJoined);
  const notJoined = communities.filter(c => !c.isJoined);

  return (
    <div className="amino-scroll pb-20">
      <div className="px-3 pt-3">
        <h3 className="text-white font-bold text-[16px] mb-0.5">My Communities</h3>
        <p className="text-gray-600 text-[11px] mb-3">Long press to reorder</p>
      </div>
      {/* Amino-style vertical compact cards - 3 columns */}
      <div className="px-3 grid grid-cols-3 gap-2 mb-4">
        {joined.map(c => {
          const notifCount = Math.floor(Math.random() * 15) + 1;
          return (
            <div key={c.id} className="relative rounded-xl overflow-hidden bg-[#16162a]"
              onClick={() => { setSelectedCommunity(c); navigateTo("community"); }}>
              {/* Tall cover image */}
              <div className="relative h-[130px]">
                <img src={c.cover} className="w-full h-full object-cover" alt="" />
                <div className="absolute inset-0 bg-gradient-to-t from-[#16162a] via-transparent to-transparent" />
                {/* Community icon - top left overlaid */}
                <div className="absolute top-1.5 left-1.5">
                  <img src={c.icon} className="w-7 h-7 rounded-md object-cover border border-white/20 shadow" alt="" />
                </div>
                {/* Notification badge - top right */}
                {notifCount > 0 && (
                  <div className="absolute top-1 right-1 min-w-[18px] h-[18px] bg-red-500 rounded-full text-[8px] text-white flex items-center justify-center font-bold px-1">
                    {notifCount > 9 ? "9+" : notifCount}
                  </div>
                )}
              </div>
              {/* Community name */}
              <div className="px-1.5 pt-1 pb-2 text-center">
                <p className="text-white text-[10px] font-semibold leading-tight line-clamp-2">•{c.name}•</p>
              </div>
            </div>
          );
        })}
        {/* Join more card */}
        <div className="rounded-xl border border-dashed border-white/15 flex flex-col items-center justify-center gap-1.5 min-h-[160px]"
          onClick={() => comingSoon("Join Community")}>
          <Plus size={24} className="text-white/20" />
          <span className="text-white/20 text-[9px] font-medium">Join More</span>
        </div>
      </div>

      <div className="px-3 mb-5">
        <button onClick={() => comingSoon("Create Community")}
          className="w-full py-2.5 border border-[#2dbe60] rounded-lg text-[#2dbe60] font-bold text-[13px] tracking-wide hover:bg-[#2dbe60]/10 transition-colors">
          CREATE YOUR OWN
        </button>
      </div>

      {notJoined.length > 0 && (
        <div className="px-3">
          <h3 className="text-white font-bold text-[14px] mb-2.5">Recommended for You</h3>
          {notJoined.map(c => (
            <div key={c.id} className="flex items-center gap-3 mb-2.5" onClick={() => { setSelectedCommunity(c); navigateTo("community"); }}>
              <img src={c.icon} className="w-12 h-12 rounded-lg object-cover shrink-0" alt="" />
              <div className="flex-1 min-w-0">
                <p className="text-white text-[13px] font-semibold truncate">{c.name}</p>
                <p className="text-gray-500 text-[10px] line-clamp-1">{c.description}</p>
                <p className="text-gray-600 text-[9px]">{formatNumber(c.members)} Members</p>
              </div>
              <button onClick={(e) => { e.stopPropagation(); toggleJoinCommunity(c.id); }}
                className="bg-[#2dbe60] text-white text-[11px] font-bold px-3.5 py-1.5 rounded-full shrink-0">Join</button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ============ CHATS TAB ============
function ChatsTab() {
  const { communities, chatRooms, navigateTo, setSelectedChat } = useApp();
  const [sidebarFilter, setSidebarFilter] = useState("recent");
  const joinedComms = communities.filter(c => c.isJoined);
  const filteredChats = sidebarFilter === "recent" ? chatRooms :
    sidebarFilter === "global" ? chatRooms :
    chatRooms.filter(ch => ch.communityId === sidebarFilter);

  return (
    <div className="flex h-full" style={{ paddingBottom: 48 }}>
      <div className="w-[52px] bg-[#0a0a16] flex flex-col items-center py-2 gap-1.5 border-r border-white/5 overflow-y-auto amino-scroll shrink-0">
        <button onClick={() => setSidebarFilter("recent")}
          className={`w-9 h-9 rounded-full flex items-center justify-center transition-colors ${sidebarFilter === "recent" ? "bg-[#2dbe60]/20 text-[#2dbe60]" : "bg-[#1a1a2e] text-gray-600"}`}>
          <Clock size={16} />
        </button>
        <button onClick={() => setSidebarFilter("global")}
          className={`w-9 h-9 rounded-full flex items-center justify-center relative transition-colors ${sidebarFilter === "global" ? "bg-[#2dbe60]/20 text-[#2dbe60]" : "bg-[#1a1a2e] text-gray-600"}`}>
          <Globe size={16} />
          <span className="absolute -top-0.5 -right-0.5 w-3.5 h-3.5 bg-red-500 rounded-full text-[7px] text-white flex items-center justify-center font-bold">5</span>
        </button>
        <div className="w-5 h-px bg-white/8 my-0.5" />
        {joinedComms.map(c => (
          <button key={c.id} onClick={() => setSidebarFilter(c.id)}
            className={`w-9 h-9 rounded-full overflow-hidden shrink-0 border-2 transition-all ${sidebarFilter === c.id ? "border-[#2dbe60] scale-105" : "border-transparent opacity-70"}`}>
            <img src={c.icon} className="w-full h-full object-cover" alt="" />
          </button>
        ))}
        <button onClick={() => comingSoon("New Chat")} className="w-9 h-9 rounded-full bg-[#1a1a2e] flex items-center justify-center text-gray-600 shrink-0 mt-1">
          <Plus size={16} />
        </button>
      </div>
      <div className="flex-1 overflow-y-auto amino-scroll">
        <button onClick={() => comingSoon("New Chat")} className="w-full flex items-center gap-3 px-3 py-3 border-b border-white/5 hover:bg-white/3 transition-colors">
          <div className="w-10 h-10 rounded-full bg-[#1e1e38] flex items-center justify-center"><PenSquare size={16} className="text-gray-500" /></div>
          <span className="text-gray-500 text-[13px]">New Chat</span>
        </button>
        {filteredChats.map(chat => (
          <button key={chat.id} onClick={() => { setSelectedChat(chat); navigateTo("chatroom"); }}
            className="w-full flex items-center gap-3 px-3 py-2.5 border-b border-white/3 hover:bg-white/3 transition-colors text-left">
            <div className="relative shrink-0">
              {chat.isGroupChat ? (
                <div className="w-11 h-11 rounded-full bg-[#1e1e38] flex items-center justify-center"><Hash size={18} className="text-gray-500" /></div>
              ) : (
                <img src={chat.cover || chat.communityIcon} className="w-11 h-11 rounded-full object-cover" alt="" />
              )}
              {chat.unreadCount > 0 && <span className="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] bg-red-500 rounded-full text-[9px] text-white flex items-center justify-center font-bold px-1">{chat.unreadCount}</span>}
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-center justify-between mb-0.5">
                <span className="text-white text-[13px] font-semibold truncate">{chat.name}</span>
                <span className="text-gray-600 text-[10px] shrink-0 ml-2">{chat.lastMessageTime}</span>
              </div>
              <p className={`text-[11px] truncate ${chat.unreadCount > 0 ? "text-gray-400" : "text-gray-600"}`}>
                {chat.isGroupChat && <span className="text-gray-500">{chat.lastMessageBy}: </span>}{chat.lastMessage}
              </p>
            </div>
          </button>
        ))}
        <div className="px-3 pt-4 pb-2">
          <h4 className="text-gray-500 text-[11px] font-semibold mb-2 uppercase tracking-wider">Public Chats</h4>
          {chatRooms.filter(c => c.isGroupChat).slice(0, 2).map(chat => (
            <div key={`rec-${chat.id}`} className="mb-2 rounded-lg overflow-hidden" onClick={() => { setSelectedChat(chat); navigateTo("chatroom"); }}>
              <div className="relative h-[80px]">
                <img src={communities.find(c => c.id === chat.communityId)?.cover || ""} className="w-full h-full object-cover" alt="" />
                <div className="absolute inset-0 bg-gradient-to-t from-black/80 to-transparent" />
                <div className="absolute bottom-2 left-2 right-2">
                  <p className="text-white text-[12px] font-semibold">{chat.name}</p>
                  <p className="text-white/50 text-[9px]">{chat.membersCount} members online</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// ============ STORE TAB ============
function StoreTab() {
  return (
    <div className="amino-scroll pb-20 px-3 pt-3">
      <div className="bg-gradient-to-r from-yellow-600 to-yellow-400 rounded-xl p-4 mb-4">
        <div className="flex items-center gap-2 mb-2">
          <div className="bg-yellow-300 text-yellow-900 font-black text-[12px] px-2 py-0.5 rounded">Amino+</div>
          <span className="text-white font-bold text-[16px]">Go Premium</span>
        </div>
        <p className="text-white/80 text-[12px] mb-3">Ad-free, custom profiles, exclusive badges & more!</p>
        <button onClick={() => comingSoon("Amino+")} className="bg-white text-yellow-700 font-bold text-[13px] px-5 py-2 rounded-full">Try Free for 7 Days</button>
      </div>
      <h3 className="text-white font-bold text-[15px] mb-3">Shop</h3>
      <div className="grid grid-cols-2 gap-2.5">
        {[
          { name: "Chat Bubble - Neon", price: 50, icon: "💬" },
          { name: "Profile Frame - Gold", price: 100, icon: "🖼️" },
          { name: "Title - VIP", price: 75, icon: "👑" },
          { name: "Sticker Pack - Anime", price: 30, icon: "🎨" },
        ].map(item => (
          <div key={item.name} className="bg-[#16162a] rounded-lg p-3 text-center" onClick={() => comingSoon("Purchase " + item.name)}>
            <span className="text-[32px] block mb-2">{item.icon}</span>
            <p className="text-white text-[11px] font-semibold mb-1">{item.name}</p>
            <div className="flex items-center justify-center gap-1">
              <span className="text-[10px]">🪙</span>
              <span className="text-yellow-400 text-[12px] font-bold">{item.price}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ============ COMMUNITY DETAIL SCREEN ============
function CommunityDetailScreen() {
  const { selectedCommunity, communities, posts, chatRooms, currentUser, goBack, navigateTo,
    setSelectedCommunity, setSelectedPost, setSelectedChat, checkIn, getCommunityProfile } = useApp();
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [activeTab, setActiveTab] = useState("featured");
  const [showFab, setShowFab] = useState(false);
  const joinedComms = communities.filter(c => c.isJoined);

  if (!selectedCommunity) return null;

  const communityPosts = posts.filter(p => p.communityId === selectedCommunity.id);
  const commChats = chatRooms.filter(ch => ch.communityId === selectedCommunity.id);
  const profile = getCommunityProfile(selectedCommunity.id);
  const displayName = profile?.nickname || currentUser.nickname;
  const displayAvatar = profile?.avatar || currentUser.avatar;

  const drawerItems = [
    { icon: <HomeIcon size={18} />, label: "Home", color: "bg-[#2dbe60]", action: () => { setDrawerOpen(false); setActiveTab("featured"); } },
    { icon: <MessageCircle size={18} />, label: "My Chats", color: "bg-[#2dbe60]", badge: 2, action: () => { setDrawerOpen(false); setActiveTab("chats"); } },
    { icon: <Star size={18} />, label: "Catalog", color: "bg-[#FF9800]", action: () => { setDrawerOpen(false); setActiveTab("wiki"); } },
    { icon: <MessageCircle size={18} />, label: "Public Chatrooms", color: "bg-[#2dbe60]", action: () => { setDrawerOpen(false); setActiveTab("chats"); } },
    { icon: <Clock size={18} />, label: "Latest Feed", color: "bg-[#03A9F4]", action: () => { setDrawerOpen(false); setActiveTab("latest"); } },
    { icon: <Globe size={18} />, label: "Guidelines", color: "bg-[#FF9800]", action: () => { setDrawerOpen(false); setActiveTab("guidelines"); } },
    { icon: <Star size={18} />, label: "Resource Links", color: "bg-[#FF9800]", action: () => comingSoon("Resource Links") },
  ];

  return (
    <div className="flex flex-col h-full relative">
      {/* Drawer Overlay */}
      {drawerOpen && (
        <div className="absolute inset-0 z-50 flex">
          <div className="w-[56px] bg-[#080812] flex flex-col items-center py-3 gap-2 border-r border-white/5">
            <button onClick={goBack} className="flex flex-col items-center gap-0.5 mb-2">
              <LogOut size={18} className="text-gray-400 rotate-180" />
              <span className="text-gray-500 text-[8px]">Exit</span>
            </button>
            <div className="w-6 h-px bg-white/10 mb-1" />
            {joinedComms.map(c => (
              <button key={c.id} onClick={() => { setSelectedCommunity(c); setDrawerOpen(false); }}
                className={`relative w-10 h-10 rounded-lg overflow-hidden shrink-0 border-2 transition-all ${c.id === selectedCommunity.id ? "border-[#2dbe60]" : "border-transparent opacity-60"}`}>
                <img src={c.icon} className="w-full h-full object-cover" alt="" />
                <span className="absolute -top-0.5 -right-0.5 min-w-[14px] h-[14px] bg-red-500 rounded-full text-[7px] text-white flex items-center justify-center font-bold">{Math.floor(Math.random() * 9) + 1}</span>
              </button>
            ))}
            <button onClick={() => comingSoon("Join Community")} className="w-10 h-10 rounded-lg bg-[#1a1a2e] flex items-center justify-center text-gray-600 shrink-0 mt-1">
              <Plus size={16} />
            </button>
          </div>
          <div className="flex-1 bg-[#0f0f1e]/98 backdrop-blur-md overflow-y-auto amino-scroll" onClick={(e) => e.stopPropagation()}>
            <div className="relative h-[260px]">
              <img src={selectedCommunity.cover} className="w-full h-full object-cover" alt="" />
              <div className="absolute inset-0 bg-gradient-to-t from-[#0f0f1e] via-[#0f0f1e]/40 to-transparent" />
              <div className="absolute top-6 left-0 right-0 text-center">
                <p className="text-white/60 text-[10px] tracking-[3px] uppercase mb-0.5">WELCOME TO</p>
                <h2 className="text-white font-black text-[20px] tracking-wider uppercase">{selectedCommunity.name}</h2>
              </div>
              <div className="absolute bottom-6 left-0 right-0 flex flex-col items-center">
                <div className="relative mb-2">
                  <img src={displayAvatar} className="w-16 h-16 rounded-full object-cover border-3 border-white/20 shadow-lg" alt="" />
                  <button onClick={() => comingSoon("Change Avatar")} className="absolute -top-1 -right-1 w-6 h-6 bg-[#2dbe60] rounded-full flex items-center justify-center border-2 border-[#0f0f1e]">
                    <Plus size={12} className="text-white" />
                  </button>
                </div>
                <p className="text-white font-semibold text-[14px] mb-2">{displayName}</p>
                <button onClick={() => checkIn(selectedCommunity.id)}
                  className="bg-[#2dbe60] text-white font-bold text-[14px] px-8 py-2 rounded-lg shadow-lg hover:bg-[#25a854] transition-colors">
                  Check In
                </button>
              </div>
            </div>
            <div className="px-2 pt-2 pb-4">
              {drawerItems.map((item, i) => (
                <button key={i} onClick={item.action}
                  className="w-full flex items-center gap-3 px-3 py-3 rounded-lg hover:bg-white/5 transition-colors border-b border-white/3">
                  <div className={`w-8 h-8 rounded-full ${item.color} flex items-center justify-center text-white`}>{item.icon}</div>
                  <span className="text-white text-[15px] font-medium flex-1 text-left">{item.label}</span>
                  {item.badge && <span className="min-w-[22px] h-[22px] bg-red-500 rounded-md text-[11px] text-white flex items-center justify-center font-bold">{item.badge}</span>}
                </button>
              ))}
              <button onClick={() => comingSoon("More Options")} className="w-full flex items-center gap-3 px-3 py-3">
                <span className="text-gray-500 text-[14px]">See More...</span>
                <ChevronRight size={16} className="text-gray-600 ml-auto" />
              </button>
            </div>
          </div>
          <div className="w-[60px] bg-transparent" onClick={() => setDrawerOpen(false)} />
        </div>
      )}

      {/* Community Header */}
      <div className="relative">
        <div className="relative h-[180px]">
          <img src={selectedCommunity.cover} className="w-full h-full object-cover" alt="" />
          <div className="absolute inset-0 bg-gradient-to-b from-black/40 via-transparent to-[#0f0f1e]" />
          <div className="absolute top-8 left-3 right-3 flex items-center justify-between z-10">
            <button onClick={goBack} className="p-1"><ChevronLeft size={22} className="text-white" /></button>
            <div className="flex items-center gap-2">
              <button onClick={() => comingSoon("Claim Gifts")} className="bg-[#2dbe60] text-white text-[10px] font-bold px-3 py-1 rounded-full flex items-center gap-1">🎁 Claim gifts</button>
              <button onClick={() => comingSoon("Gallery")} className="p-1.5 bg-black/30 rounded-full"><Image size={16} className="text-white" /></button>
              <button onClick={() => comingSoon("Notifications")} className="relative p-1.5 bg-black/30 rounded-full">
                <Bell size={16} className="text-white" /><span className="absolute top-0 right-0 w-2 h-2 bg-red-500 rounded-full" />
              </button>
            </div>
          </div>
          <div className="absolute bottom-3 left-3 right-3 flex items-end gap-3">
            <img src={selectedCommunity.icon} className="w-14 h-14 rounded-lg object-cover border-2 border-white/20 shadow-lg shrink-0" alt="" />
            <div className="flex-1 min-w-0">
              <h2 className="text-white font-black text-[20px] leading-tight">{selectedCommunity.name}</h2>
              <div className="flex items-center gap-2 mt-0.5">
                <span className="text-white/70 text-[11px]">{formatNumber(selectedCommunity.members)} Members</span>
                <button onClick={() => setActiveTab("leaderboard")} className="bg-[#2dbe60] text-white text-[8px] font-bold px-2 py-0.5 rounded-full">Leaderboards</button>
              </div>
            </div>
          </div>
        </div>

        {/* Check-in progress bar */}
        {!selectedCommunity.checkedIn && (
          <div className="bg-[#1a1a2e] px-3 py-2.5 border-b border-white/5">
            <div className="flex items-center justify-between mb-1.5">
              <span className="text-white text-[12px] font-semibold">Check In to earn a prize</span>
              <button onClick={() => checkIn(selectedCommunity.id)} className="text-gray-600"><X size={14} /></button>
            </div>
            <div className="flex items-center gap-1 mb-2">
              {[1,2,3,4,5,6,7].map(d => (
                <div key={d} className="flex-1 flex items-center">
                  <div className={`w-3 h-3 rounded-full ${d === 1 ? "bg-[#2dbe60] ring-2 ring-[#2dbe60]/30" : "bg-gray-700"}`} />
                  {d < 7 && <div className="flex-1 h-[2px] bg-gray-700" />}
                </div>
              ))}
            </div>
            <button onClick={() => checkIn(selectedCommunity.id)}
              className="w-full bg-[#2dbe60] text-white font-bold text-[13px] py-2 rounded-lg">Check In</button>
          </div>
        )}
      </div>

      {/* Live Chatrooms */}
      {commChats.length > 0 && (
        <div className="px-3 py-2">
          <div className="flex gap-2 overflow-x-auto amino-scroll pb-1">
            {commChats.map(chat => (
              <div key={chat.id} className="shrink-0 w-[160px] rounded-lg overflow-hidden bg-[#16162a]"
                onClick={() => { setSelectedChat(chat); navigateTo("chatroom"); }}>
                <div className="relative h-[80px]">
                  <img src={chat.cover || selectedCommunity.cover} className="w-full h-full object-cover" alt="" />
                  <div className="absolute inset-0 bg-gradient-to-t from-black/70 to-transparent" />
                  <div className="absolute top-1.5 left-1.5 flex items-center gap-1">
                    <img src={chat.communityIcon} className="w-5 h-5 rounded-full object-cover" alt="" />
                    <span className="text-white text-[9px] font-semibold truncate">{chat.lastMessageBy}</span>
                  </div>
                  <div className="absolute top-1.5 right-1.5 bg-red-500 text-white text-[8px] font-bold px-1.5 py-0.5 rounded flex items-center gap-0.5">
                    <span className="w-1.5 h-1.5 bg-white rounded-full animate-pulse" />Live
                  </div>
                  <div className="absolute bottom-1.5 left-1.5 right-1.5">
                    <p className="text-white text-[11px] font-semibold leading-tight truncate">{chat.name}</p>
                    <p className="text-white/50 text-[9px] flex items-center gap-0.5"><Users size={8} />{chat.membersCount}</p>
                  </div>
                </div>
              </div>
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
            {activeTab === tab && <div className="absolute bottom-0 left-2 right-2 h-[2px] bg-white rounded-full" />}
          </button>
        ))}
      </div>

      {/* Tab Content */}
      <div className="flex-1 overflow-y-auto amino-scroll px-3 pt-2 pb-20">
        {activeTab === "guidelines" && (
          <div className="bg-[#16162a] rounded-lg p-4">
            <h3 className="text-white font-bold text-[16px] mb-3 flex items-center gap-2"><Globe size={18} className="text-[#FF9800]" />Community Guidelines</h3>
            <div className="space-y-3 text-gray-300 text-[13px] leading-relaxed">
              <p>1. Be respectful to all members. No harassment, bullying, or hate speech.</p>
              <p>2. Stay on topic. Posts should be relevant to {selectedCommunity.name}.</p>
              <p>3. No spam, self-promotion, or advertising without permission.</p>
              <p>4. Use appropriate content warnings for sensitive topics.</p>
              <p>5. Follow the Amino Community Guidelines at all times.</p>
              <p>6. Leaders and Curators have final say on content moderation.</p>
            </div>
          </div>
        )}
        {(activeTab === "featured" || activeTab === "latest") && (
          <div>
            {communityPosts.length > 0 ? communityPosts.map(post => (
              <PostCard key={post.id} post={post} onPress={() => { setSelectedPost(post); navigateTo("post"); }} showCommunity={false} />
            )) : (
              <div className="text-center py-8"><p className="text-gray-600 text-[13px]">No posts yet. Be the first to post!</p></div>
            )}
          </div>
        )}
        {activeTab === "chats" && (
          <div>
            {commChats.map(chat => (
              <button key={chat.id} onClick={() => { setSelectedChat(chat); navigateTo("chatroom"); }}
                className="w-full flex items-center gap-3 py-3 border-b border-white/5 text-left">
                <div className="w-11 h-11 rounded-full bg-[#1e1e38] flex items-center justify-center shrink-0"><Hash size={18} className="text-gray-500" /></div>
                <div className="flex-1 min-w-0">
                  <p className="text-white text-[13px] font-semibold truncate">{chat.name}</p>
                  <p className="text-gray-600 text-[10px]">{chat.membersCount} members</p>
                </div>
                <ChevronRight size={16} className="text-gray-600" />
              </button>
            ))}
            {commChats.length === 0 && <div className="text-center py-8"><p className="text-gray-600 text-[13px]">No public chatrooms yet</p></div>}
          </div>
        )}
        {activeTab === "members" && (
          <div>
            {[
              { name: "CommunityAdmin", role: "Leader", level: 20, rep: 120000, avatar: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100" },
              { name: "ModeratorX", role: "Curator", level: 15, rep: 50000, avatar: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100" },
              { name: "ActiveUser99", role: "Member", level: 8, rep: 8000, avatar: "https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=100" },
            ].map((m, i) => {
              const lvl = getLevelFromRep(m.rep);
              return (
                <div key={i} className="flex items-center gap-3 py-2.5 border-b border-white/5">
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
                </div>
              );
            })}
          </div>
        )}
        {activeTab === "wiki" && (
          <div className="text-center py-8">
            <BookOpen size={32} className="text-gray-700 mx-auto mb-2" />
            <p className="text-gray-600 text-[13px]">Wiki/Catalog entries will appear here</p>
            <button onClick={() => comingSoon("Create Wiki Entry")} className="mt-3 bg-[#2dbe60] text-white text-[12px] font-bold px-4 py-2 rounded-full">Create Entry</button>
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
                <div key={m.rank} className="flex items-center gap-3 py-2.5 border-b border-white/5">
                  <span className={`w-7 h-7 rounded-full flex items-center justify-center font-bold text-[12px] ${m.rank === 1 ? "bg-yellow-500 text-black" : m.rank === 2 ? "bg-gray-400 text-black" : "bg-orange-700 text-white"}`}>{m.rank}</span>
                  <img src={m.avatar} className="w-9 h-9 rounded-full object-cover" alt="" />
                  <div className="flex-1">
                    <div className="flex items-center gap-1.5">
                      <span className="text-white text-[13px] font-semibold">{m.name}</span>
                      <span className="bg-gradient-to-r from-blue-700 to-blue-500 text-white text-[8px] font-bold px-1.5 py-px rounded">Lv{lvl.level}</span>
                    </div>
                    <div className="flex items-center gap-2 mt-0.5">
                      <span className="text-gray-500 text-[10px]">{lvl.title}</span>
                      <span className="text-gray-600 text-[10px]">{formatNumber(m.rep)} reputation</span>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Community Bottom Nav */}
      <div className="sticky bottom-0 z-40 flex items-center bg-[#0b0b18] border-t border-white/5" style={{ paddingBottom: 4 }}>
        <button onClick={() => setDrawerOpen(true)} className="flex-1 flex flex-col items-center py-2 gap-0.5 text-gray-500 relative">
          <Menu size={20} /><span className="text-[9px]">Menu</span>
          <span className="absolute top-1 right-[30%] w-2 h-2 bg-red-500 rounded-full" />
        </button>
        <button onClick={() => comingSoon("Online Members")} className="flex-1 flex flex-col items-center py-2 gap-0.5 text-gray-500 relative">
          <Users size={20} /><span className="text-[9px]">Online</span>
          <span className="absolute top-0 right-[25%] min-w-[16px] h-[16px] bg-[#2dbe60] rounded-full text-[8px] text-white flex items-center justify-center font-bold">{selectedCommunity.onlineNow || 42}</span>
        </button>
        <button onClick={() => setShowFab(!showFab)} className="flex items-center justify-center -mt-4">
          <div className="w-12 h-12 rounded-full bg-[#2563eb] flex items-center justify-center shadow-lg shadow-blue-500/30">
            <Plus size={24} className="text-white" />
          </div>
        </button>
        <button onClick={() => setActiveTab("chats")} className="flex-1 flex flex-col items-center py-2 gap-0.5 text-gray-500 relative">
          <MessageCircle size={20} /><span className="text-[9px]">Chats</span>
          <span className="absolute top-0 right-[25%] w-2 h-2 bg-red-500 rounded-full" />
        </button>
        <button onClick={() => navigateTo("communityProfile")} className="flex-1 flex flex-col items-center py-2 gap-0.5 text-gray-500">
          <img src={displayAvatar} className="w-5 h-5 rounded-full object-cover" alt="" /><span className="text-[9px]">Me</span>
        </button>
      </div>

      {/* FAB Options */}
      {showFab && (
        <div className="absolute bottom-16 right-3 z-50 flex flex-col items-end gap-2 animate-in fade-in slide-in-from-bottom-3 duration-200">
          {[
            { icon: <FileText size={16} />, label: "Blog", color: "bg-blue-500" },
            { icon: <Image size={16} />, label: "Image", color: "bg-green-500" },
            { icon: <BarChart3 size={16} />, label: "Poll", color: "bg-orange-500" },
            { icon: <HelpCircle size={16} />, label: "Quiz", color: "bg-pink-500" },
          ].map(item => (
            <div key={item.label} className="flex items-center gap-2 justify-center" onClick={() => { comingSoon("Create " + item.label); setShowFab(false); }}>
              <span className="text-white text-[11px] font-medium bg-black/70 px-2 py-1 rounded">{item.label}</span>
              <button className={`w-10 h-10 rounded-full ${item.color} flex items-center justify-center text-white shadow-lg`}>{item.icon}</button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ============ POST DETAIL ============
function PostDetailScreen() {
  const { selectedPost, comments, goBack, toggleLike } = useApp();
  const [newComment, setNewComment] = useState("");
  if (!selectedPost) return null;

  const authorLevel = getLevelFromRep(selectedPost.author.level * 500);

  return (
    <div className="flex flex-col h-full">
      <AminoMainHeader onBack={goBack} title={selectedPost.communityName} />
      <div className="flex-1 overflow-y-auto amino-scroll px-3 pt-2 pb-4">
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
          <button onClick={() => comingSoon("Post Options")} className="p-1"><MoreHorizontal size={18} className="text-gray-600" /></button>
        </div>
        <h2 className="text-white font-bold text-[18px] mb-2 leading-snug">{selectedPost.title}</h2>
        <p className="text-gray-300 text-[13px] leading-relaxed mb-3 whitespace-pre-line">{selectedPost.content}</p>
        {selectedPost.mediaUrl && <img src={selectedPost.mediaUrl} className="w-full rounded-lg mb-3" alt="" />}
        {selectedPost.type === "poll" && selectedPost.pollOptions && (
          <div className="mb-3 space-y-1.5">
            {selectedPost.pollOptions.map(opt => (
              <div key={opt.id} className="relative overflow-hidden rounded-md bg-[#1e1e38]">
                <div className="absolute inset-y-0 left-0 bg-blue-500/20 transition-all" style={{ width: `${opt.percentage}%` }} />
                <div className="relative flex items-center justify-between px-3 py-2.5">
                  <span className={`text-[13px] ${opt.isVoted ? "text-blue-400 font-semibold" : "text-gray-300"}`}>{opt.text}</span>
                  <span className="text-gray-500 text-[12px]">{opt.percentage}%</span>
                </div>
              </div>
            ))}
          </div>
        )}
        <div className="flex gap-1.5 mb-4 flex-wrap">
          {selectedPost.tags.map(tag => <span key={tag} className="bg-[#1e1e38] text-gray-500 text-[11px] px-2.5 py-1 rounded-full">#{tag}</span>)}
        </div>
        <div className="flex items-center gap-6 py-3 border-y border-white/5 mb-4">
          <button onClick={() => toggleLike(selectedPost.id)}
            className={`flex items-center gap-1.5 text-[13px] ${selectedPost.isLiked ? "text-red-400" : "text-gray-600"}`}>
            <Heart size={20} fill={selectedPost.isLiked ? "currentColor" : "none"} /><span>{selectedPost.likesCount}</span>
          </button>
          <div className="flex items-center gap-1.5 text-gray-600 text-[13px]"><MessageCircle size={20} /><span>{selectedPost.commentsCount}</span></div>
          <button onClick={() => comingSoon("Bookmark")} className="ml-auto text-gray-600"><Bookmark size={20} /></button>
          <button onClick={() => comingSoon("Share")} className="text-gray-600"><Share2 size={20} /></button>
        </div>
        <h4 className="text-white font-bold text-[14px] mb-3">Comments ({comments.length})</h4>
        {comments.map(comment => (
          <div key={comment.id} className="flex gap-2.5 mb-4">
            <img src={comment.author.avatar} className="w-8 h-8 rounded-full object-cover shrink-0" alt="" />
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-1.5 mb-0.5">
                <span className="text-white text-[12px] font-semibold">{comment.author.nickname}</span>
                {comment.author.role === "Leader" && <span className="bg-[#2dbe60] text-white text-[6px] px-1 rounded font-bold">Leader</span>}
                {comment.author.role === "Curator" && <span className="bg-[#E040FB] text-white text-[6px] px-1 rounded font-bold">Curator</span>}
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
          </div>
        ))}
      </div>
      <div className="flex items-center gap-2 px-3 py-2 bg-[#0b0b18] border-t border-white/5">
        <input value={newComment} onChange={e => setNewComment(e.target.value)}
          placeholder="Write a comment..."
          className="flex-1 bg-[#1e1e38] text-white text-[13px] px-3 py-2 rounded-full placeholder:text-gray-700 outline-none" />
        <button onClick={() => { if (newComment.trim()) { comingSoon("Post Comment"); setNewComment(""); } }} className="p-1.5"><Send size={18} className="text-[#2dbe60]" /></button>
      </div>
    </div>
  );
}

// ============ CHAT ROOM ============
function ChatRoomScreen() {
  const { selectedChat, chatMessages, goBack, sendMessage, currentUser } = useApp();
  const [input, setInput] = useState("");
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [chatMessages]);

  if (!selectedChat) return null;

  const handleSend = () => {
    if (!input.trim()) return;
    sendMessage(input.trim());
    setInput("");
  };

  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center gap-2 px-3 py-2 bg-[#0f0f1e]/95 backdrop-blur-sm border-b border-white/5" style={{ paddingTop: 38 }}>
        <button onClick={goBack} className="p-1"><ChevronLeft size={20} className="text-white" /></button>
        <div className="w-8 h-8 rounded-full bg-[#1e1e38] flex items-center justify-center"><Hash size={14} className="text-[#2dbe60]" /></div>
        <div className="flex-1 min-w-0">
          <span className="text-white font-semibold text-[13px] truncate block">{selectedChat.name}</span>
          <span className="text-gray-600 text-[10px]">{selectedChat.membersCount} members</span>
        </div>
        <button onClick={() => comingSoon("Members")} className="p-1"><Users size={18} className="text-white/60" /></button>
        <button onClick={() => comingSoon("Chat Options")} className="p-1"><MoreHorizontal size={18} className="text-white/60" /></button>
      </div>
      <div className="flex-1 overflow-y-auto amino-scroll px-3 py-2">
        {chatMessages.map(msg => {
          if (msg.isSystem) {
            return <div key={msg.id} className="text-center py-2 mb-2"><span className="text-gray-600 text-[10px] bg-[#1e1e38] px-3 py-1 rounded-full">{msg.content}</span></div>;
          }
          const isMe = msg.userId === currentUser.id;
          return (
            <div key={msg.id} className={`mb-2.5 ${isMe ? "flex flex-col items-end" : ""}`}>
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
                      {msg.reactions.map((r, i) => <span key={i} className="bg-[#1e1e38] text-[10px] px-1.5 py-0.5 rounded-full border border-white/5">{r.emoji} {r.count}</span>)}
                    </div>
                  )}
                </div>
              </div>
            </div>
          );
        })}
        <div ref={messagesEndRef} />
      </div>
      <div className="flex items-center gap-1.5 px-2 py-2 bg-[#0b0b18] border-t border-white/5">
        <button onClick={() => comingSoon("Attach")} className="p-1.5"><Plus size={18} className="text-gray-600" /></button>
        <button onClick={() => comingSoon("Stickers")} className="p-1.5"><Smile size={18} className="text-gray-600" /></button>
        <input value={input} onChange={e => setInput(e.target.value)}
          onKeyDown={e => e.key === "Enter" && handleSend()}
          placeholder="Type a message..."
          className="flex-1 bg-[#1e1e38] text-white text-[13px] px-3 py-2 rounded-full placeholder:text-gray-700 outline-none" />
        {input.trim() ? (
          <button onClick={handleSend} className="p-1.5"><Send size={18} className="text-[#2dbe60]" /></button>
        ) : (
          <button onClick={() => comingSoon("Voice Message")} className="p-1.5"><Mic size={18} className="text-gray-600" /></button>
        )}
      </div>
    </div>
  );
}

// ============ GLOBAL PROFILE SCREEN (Amino faithful - Print 2) ============
function GlobalProfileScreen() {
  const { currentUser, communities, goBack, navigateTo, setSelectedCommunity } = useApp();
  const [activeProfileTab, setActiveProfileTab] = useState("stories");
  const joinedComms = communities.filter(c => c.isJoined);

  return (
    <div className="flex flex-col h-full bg-[#1a1a2e]">
      <div className="flex items-center justify-between px-3 py-2 bg-[#0f0f1e] border-b border-white/5" style={{ paddingTop: 38 }}>
        <button onClick={goBack} className="p-1"><ChevronLeft size={22} className="text-white" /></button>
        <div className="flex items-center bg-[#2dbe60] rounded-full px-2.5 py-1 gap-1">
          <span className="text-[11px]">🪙</span>
          <span className="text-white text-[12px] font-bold">{currentUser.coins}</span>
          <Plus size={12} className="text-white ml-0.5" />
        </div>
        <button onClick={() => comingSoon("Share Profile")} className="p-1"><Share2 size={20} className="text-white/70" /></button>
        <button onClick={() => comingSoon("Settings Menu")} className="p-1"><Menu size={20} className="text-white/70" /></button>
      </div>

      <div className="flex-1 overflow-y-auto amino-scroll">
        <div className="px-4 pt-4 pb-3">
          <div className="flex items-start justify-between mb-3">
            <img src={currentUser.avatar} className="w-20 h-20 rounded-full object-cover border-2 border-white/10" alt="" />
            <button onClick={() => comingSoon("Edit Profile")}
              className="flex items-center gap-1.5 bg-[#2a2a40] text-white text-[12px] font-medium px-3 py-1.5 rounded-md border border-white/10">
              <Edit size={14} />Edit Profile
            </button>
          </div>
          <div className="flex items-center gap-2 mb-1">
            <h2 className="text-white font-bold text-[20px]">{currentUser.nickname}</h2>
            <div className="bg-gradient-to-r from-blue-500 to-blue-600 text-white text-[8px] font-bold px-1.5 py-0.5 rounded">A+</div>
          </div>
          <p className="text-gray-500 text-[12px] mb-3">@{currentUser.nickname.toLowerCase().replace(/\s/g, "_")}</p>
          <div className="flex border border-white/10 rounded-lg overflow-hidden mb-4">
            <button onClick={() => comingSoon("Followers")} className="flex-1 py-3 text-center border-r border-white/10 hover:bg-white/3 transition-colors">
              <p className="text-white font-bold text-[18px]">{formatNumber(currentUser.followers)}</p>
              <p className="text-gray-500 text-[11px]">Followers</p>
            </button>
            <button onClick={() => comingSoon("Following")} className="flex-1 py-3 text-center hover:bg-white/3 transition-colors">
              <p className="text-white font-bold text-[18px]">{currentUser.following}</p>
              <p className="text-gray-500 text-[11px]">Following</p>
            </button>
          </div>
          <p className="text-gray-300 text-[13px] leading-relaxed mb-4">{currentUser.bio}</p>
          <div className="flex items-center gap-3 bg-[#2a2a40] rounded-lg px-3 py-2.5 mb-4 border border-white/5">
            <div className="bg-yellow-400 text-black font-black text-[10px] px-2 py-1 rounded shrink-0">Amino+</div>
            <span className="text-white text-[13px] font-medium">Try Amino+ for free today!</span>
          </div>
          <div className="mb-4">
            <div className="flex items-center gap-1 mb-2 pb-2 border-b border-white/5">
              <Link2 size={14} className="text-gray-500" />
              <span className="text-gray-400 text-[12px] font-medium">Linked Communities</span>
            </div>
            <div className="grid grid-cols-2 gap-3">
              {joinedComms.slice(0, 4).map(c => (
                <button key={c.id} onClick={() => { setSelectedCommunity(c); navigateTo("community"); }}
                  className="text-left hover:bg-white/3 rounded-lg p-1.5 transition-colors">
                  <p className="text-white text-[13px] font-semibold leading-tight">{c.name}</p>
                  <p className="text-gray-600 text-[10px]">ID:{c.id}</p>
                </button>
              ))}
            </div>
          </div>
        </div>
        <div className="flex border-b border-white/10 bg-[#16162a]">
          {[
            { id: "stories", label: "Stories" },
            { id: "wall", label: "Wall" },
          ].map(tab => (
            <button key={tab.id} onClick={() => setActiveProfileTab(tab.id)}
              className={`flex-1 py-3 text-[13px] font-bold text-center transition-colors relative ${activeProfileTab === tab.id ? "text-white" : "text-gray-600"}`}>
              {tab.label}
              {activeProfileTab === tab.id && <div className="absolute bottom-0 left-0 right-0 h-[2px] bg-white" />}
            </button>
          ))}
        </div>
        <div className="bg-[#16162a] min-h-[200px]">
          {activeProfileTab === "stories" ? (
            <div className="p-4">
              <p className="text-gray-600 text-[12px] mb-1">-</p>
              <div className="grid grid-cols-2 gap-2">
                <div className="bg-[#1e1e38] rounded-lg h-[120px] flex items-center justify-center">
                  <div className="text-center">
                    <div className="w-10 h-10 rounded-full border-2 border-dashed border-white/20 flex items-center justify-center mx-auto mb-2">
                      <Plus size={18} className="text-white/30" />
                    </div>
                    <p className="text-gray-600 text-[10px]">Add Story</p>
                  </div>
                </div>
              </div>
            </div>
          ) : (
            <div className="p-4 text-center">
              <p className="text-gray-600 text-[13px]">No wall posts yet</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// ============ COMMUNITY PROFILE SCREEN (Amino faithful - Print 1) ============
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

  // Calculate level from reputation
  const lvl = getLevelFromRep(displayRep);

  return (
    <div className="flex flex-col h-full">
      <div className="flex-1 overflow-y-auto amino-scroll">
        <div className="relative h-[320px]">
          <img src={displayBg} className="w-full h-full object-cover" alt="" />
          <div className="absolute inset-0 bg-gradient-to-t from-[#0f0f1e] via-transparent to-black/20" />
          <button onClick={goBack} className="absolute top-10 left-3 p-1.5 bg-black/40 rounded-full z-10"><ChevronLeft size={20} className="text-white" /></button>
          <button onClick={() => comingSoon("Profile Options")} className="absolute top-10 right-3 p-1.5 bg-black/40 rounded-full z-10"><MoreHorizontal size={20} className="text-white" /></button>
          <div className="absolute bottom-4 left-0 right-0 flex flex-col items-center">
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
            {/* Level progress bar */}
            <div className="w-32 h-1.5 bg-gray-700 rounded-full overflow-hidden mb-2">
              <div className="h-full bg-gradient-to-r from-blue-500 to-blue-400 rounded-full transition-all" style={{ width: `${lvl.progress}%` }} />
            </div>
            <div className="flex flex-wrap justify-center gap-1.5 px-6 mb-2">
              {displayRole !== "Member" && (
                <span className={`text-[10px] font-bold px-2.5 py-1 rounded-full ${displayRole === "Leader" ? "bg-[#2dbe60] text-white" : "bg-[#E040FB] text-white"}`}>
                  {displayRole}
                </span>
              )}
              {displayBadges.map((badge: Badge, i: number) => (
                <span key={i} className="text-[10px] font-bold px-2.5 py-1 rounded-full" style={{ backgroundColor: badge.color, color: "white" }}>
                  {badge.label}
                </span>
              ))}
            </div>
            <div className="flex items-center gap-3">
              <button onClick={() => comingSoon("Follow")} className="w-10 h-10 rounded-full bg-[#2dbe60] flex items-center justify-center shadow-lg">
                <User size={18} className="text-white" />
              </button>
              <button onClick={() => comingSoon("Chat")} className="flex items-center gap-1.5 bg-white text-[#0f0f1e] font-bold text-[13px] px-4 py-2 rounded-full shadow-lg">
                <MessageCircle size={16} />Chat
              </button>
            </div>
          </div>
        </div>
        {displayStreak > 0 && (
          <div className="bg-gradient-to-r from-[#FF6F00] to-[#FFB300] px-4 py-2 flex items-center gap-2">
            <Trophy size={16} className="text-white" />
            <span className="text-white text-[13px] font-bold">{displayStreak} Day Streak</span>
          </div>
        )}
        <div className="flex items-center py-4 px-4 bg-[#0f0f1e]">
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
        </div>
        {/* Daily XP info */}
        <div className="px-4 py-2 bg-[#16162a] border-t border-white/5">
          <div className="flex items-center justify-between">
            <span className="text-gray-400 text-[11px]">Daily XP (max 100/day)</span>
            <span className="text-[#2dbe60] text-[11px] font-bold">+{Math.min(Math.floor(Math.random() * 100), 100)} today</span>
          </div>
          <div className="w-full h-1.5 bg-gray-700 rounded-full overflow-hidden mt-1">
            <div className="h-full bg-[#2dbe60] rounded-full" style={{ width: `${Math.floor(Math.random() * 100)}%` }} />
          </div>
        </div>
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
              {activeTab === tab && <div className="absolute bottom-0 left-0 right-0 h-[2px] bg-white" />}
            </button>
          ))}
        </div>
        <div className="bg-[#0f0f1e] min-h-[200px] px-4 py-4">
          {activeTab === "posts" ? (
            displayPostsCount > 0 ? (
              <p className="text-gray-600 text-[12px]">{displayPostsCount} posts in this community</p>
            ) : (
              <div className="text-center py-6">
                <FileText size={28} className="text-gray-700 mx-auto mb-2" />
                <p className="text-gray-600 text-[13px]">No posts yet</p>
              </div>
            )
          ) : (
            <div className="text-center py-6">
              <p className="text-gray-600 text-[13px]">No {activeTab} content yet</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// ============ MAIN HOME COMPONENT ============
export default function Home() {
  const { activeTab, currentScreen } = useApp();
  const [showSearch, setShowSearch] = useState(false);

  if (showSearch) return <SearchScreen onClose={() => setShowSearch(false)} />;
  if (currentScreen === "community") return <CommunityDetailScreen />;
  if (currentScreen === "communityProfile") return <CommunityProfileScreen />;
  if (currentScreen === "post") return <PostDetailScreen />;
  if (currentScreen === "chatroom") return <ChatRoomScreen />;
  if (currentScreen === "profile") return <GlobalProfileScreen />;

  return (
    <div className="flex flex-col h-full">
      <AminoMainHeader onSearchClick={() => setShowSearch(true)} />
      <div className="flex-1 overflow-y-auto">
        {activeTab === "discover" && <DiscoverTab />}
        {activeTab === "communities" && <CommunitiesTab />}
        {activeTab === "chats" && <ChatsTab />}
        {activeTab === "store" && <StoreTab />}
      </div>
      <BottomNav />
    </div>
  );
}
