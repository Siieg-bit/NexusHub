import { useState, useEffect, useRef } from "react";
import { useApp, Community, Post, ChatRoom as ChatRoomType, Badge, CommunityProfile } from "@/contexts/AppContext";
import { toast } from "sonner";
import { Search, Bell, Plus, ChevronLeft, ChevronRight, Heart, MessageCircle, Share2, Pin, Send, Smile, Mic, Users, Clock, Globe, Trophy, Star, BookOpen, MoreHorizontal, Check, Flame, Award, Bookmark, Menu, X, Home as HomeIcon, Zap, BarChart3, Image, FileText, HelpCircle, Settings, LogOut, Eye, TrendingUp, Crown, Shield, Hash, ArrowUp, PenSquare, ChevronDown, Link2, Compass, Grid3X3, ShoppingBag, User } from "lucide-react";

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

// ============ AMINO MAIN HEADER ============
function AminoMainHeader({ onBack, title, showSearch = true, rightContent }: {
  onBack?: () => void; title?: string; showSearch?: boolean; rightContent?: React.ReactNode;
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
        <div className="flex-1 flex items-center bg-[#1a1a2e] rounded-full px-3 py-1.5 mx-1" onClick={() => comingSoon("Search")}>
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
              <div className="absolute inset-y-0 left-0 bg-blue-500/20 transition-all" style={{ width: `${opt.percentage}%` }} />
              <div className="relative flex items-center justify-between px-3 py-2">
                <span className={`text-[12px] ${opt.isVoted ? "text-blue-400 font-semibold" : "text-gray-300"}`}>{opt.text}</span>
                <span className="text-gray-500 text-[11px]">{opt.percentage}%</span>
              </div>
            </button>
          ))}
          <p className="text-gray-600 text-[10px] text-center">{post.pollOptions.reduce((s, o) => s + o.votes, 0)} votes</p>
        </div>
      )}
      {post.tags.length > 0 && (
        <div className="flex gap-1 px-3 pb-2 flex-wrap">
          {post.tags.map(tag => <span key={tag} className="bg-[#1e1e38] text-gray-500 text-[10px] px-2 py-0.5 rounded-full">#{tag}</span>)}
        </div>
      )}
      <div className="flex items-center gap-5 px-3 py-2 border-t border-white/5">
        <button onClick={(e) => { e.stopPropagation(); toggleLike(post.id); }}
          className={`flex items-center gap-1 text-[12px] ${post.isLiked ? "text-red-400" : "text-gray-600"}`}>
          <Heart size={16} fill={post.isLiked ? "currentColor" : "none"} /><span>{post.likesCount}</span>
        </button>
        <div className="flex items-center gap-1 text-gray-600 text-[12px]"><MessageCircle size={16} /><span>{post.commentsCount}</span></div>
        <button onClick={(e) => { e.stopPropagation(); comingSoon("Share"); }} className="ml-auto text-gray-600"><Share2 size={16} /></button>
      </div>
    </div>
  );
}

// ============ DISCOVER TAB - Categories + Communities ============
function DiscoverTab() {
  const { communities, categories, posts, navigateTo, setSelectedCommunity, setSelectedPost, toggleJoinCommunity } = useApp();
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [bannerIdx, setBannerIdx] = useState(0);

  // Trending communities (top by members)
  const trending = [...communities].sort((a, b) => b.members - a.members).slice(0, 5);
  const banners = trending.slice(0, 3);

  useEffect(() => {
    if (banners.length === 0) return;
    const t = setInterval(() => setBannerIdx(i => (i + 1) % banners.length), 4000);
    return () => clearInterval(t);
  }, [banners.length]);

  // Filter by category
  const filteredCommunities = selectedCategory
    ? communities.filter(c => c.categoryId === selectedCategory)
    : communities;

  // Group communities by category for "Browse by Category" view
  const categoriesWithCommunities = categories.filter(cat =>
    communities.some(c => c.categoryId === cat.id)
  );

  return (
    <div className="amino-scroll">
      {/* Banner Carousel */}
      {banners.length > 0 && (
        <div className="relative h-[170px] overflow-hidden">
          {banners.map((c, i) => (
            <div key={c.id} className={`absolute inset-0 transition-opacity duration-700 ${i === bannerIdx ? "opacity-100" : "opacity-0 pointer-events-none"}`}
              onClick={() => { setSelectedCommunity(c); navigateTo("community"); }}>
              <img src={c.cover} className="w-full h-full object-cover" alt="" />
              <div className="absolute inset-0 bg-gradient-to-t from-[#0f0f1e] via-[#0f0f1e]/30 to-transparent" />
              <div className="absolute bottom-3 left-3 right-3">
                <h2 className="text-white font-bold text-[16px] drop-shadow-lg">{c.name}</h2>
                <p className="text-white/60 text-[11px]">{formatNumber(c.members)} Members · {formatNumber(c.onlineNow)} Online</p>
              </div>
            </div>
          ))}
          <div className="absolute bottom-1.5 left-1/2 -translate-x-1/2 flex gap-1 z-10">
            {banners.map((_, i) => <div key={i} className={`h-1 rounded-full transition-all ${i === bannerIdx ? "bg-white w-4" : "bg-white/30 w-1"}`} />)}
          </div>
        </div>
      )}

      {/* Category Pills - Horizontal Scroll */}
      <div className="px-3 pt-3 pb-1">
        <div className="flex gap-2 overflow-x-auto pb-2 amino-scroll">
          <button onClick={() => setSelectedCategory(null)}
            className={`shrink-0 flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[11px] font-semibold transition-all ${!selectedCategory ? "bg-[#2dbe60] text-white" : "bg-[#1a1a2e] text-gray-400"}`}>
            <Grid3X3 size={12} />All
          </button>
          {categories.map(cat => (
            <button key={cat.id} onClick={() => setSelectedCategory(selectedCategory === cat.id ? null : cat.id)}
              className={`shrink-0 flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[11px] font-semibold transition-all ${selectedCategory === cat.id ? "text-white" : "bg-[#1a1a2e] text-gray-400"}`}
              style={selectedCategory === cat.id ? { backgroundColor: cat.color } : {}}>
              <span className="text-[13px]">{cat.icon}</span>{cat.name}
            </button>
          ))}
        </div>
      </div>

      {/* If category selected, show filtered communities */}
      {selectedCategory ? (
        <div className="px-3 pt-1 pb-20">
          <div className="flex items-center gap-2 mb-3">
            <span className="text-[18px]">{categories.find(c => c.id === selectedCategory)?.icon}</span>
            <h3 className="text-white font-bold text-[16px]">{categories.find(c => c.id === selectedCategory)?.name}</h3>
            <span className="text-gray-600 text-[12px] ml-auto">{filteredCommunities.length} communities</span>
          </div>
          {filteredCommunities.map(c => (
            <div key={c.id} className="flex items-center gap-3 mb-3 bg-[#16162a] rounded-lg p-3" onClick={() => { setSelectedCommunity(c); navigateTo("community"); }}>
              <img src={c.icon} className="w-14 h-14 rounded-lg object-cover shrink-0" alt="" />
              <div className="flex-1 min-w-0">
                <p className="text-white text-[14px] font-semibold truncate">{c.name}</p>
                <p className="text-gray-500 text-[11px] line-clamp-1 mb-1">{c.description}</p>
                <p className="text-gray-600 text-[10px]">{formatNumber(c.members)} Members · {formatNumber(c.onlineNow)} Online</p>
              </div>
              {c.isJoined ? (
                <span className="text-[#2dbe60] text-[10px] font-bold border border-[#2dbe60]/30 px-2.5 py-1 rounded-full">Joined</span>
              ) : (
                <button onClick={(e) => { e.stopPropagation(); toggleJoinCommunity(c.id); }}
                  className="bg-[#2dbe60] text-white text-[11px] font-bold px-3.5 py-1.5 rounded-full">Join</button>
              )}
            </div>
          ))}
        </div>
      ) : (
        <>
          {/* Trending Communities */}
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

          {/* Latest Posts from All Communities */}
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

// ============ COMMUNITIES TAB - Larger Cards (Amino Faithful) ============
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
      {/* Larger vertical cards - Amino faithful */}
      <div className="px-3 grid grid-cols-2 gap-2.5 mb-4">
        {joined.map(c => (
          <div key={c.id} className="relative rounded-xl overflow-hidden bg-[#16162a]"
            onClick={() => { setSelectedCommunity(c); navigateTo("community"); }}>
            {/* Cover image - taller */}
            <div className="relative h-[100px]">
              <img src={c.cover} className="w-full h-full object-cover" alt="" />
              <div className="absolute inset-0 bg-gradient-to-t from-[#16162a] via-transparent to-transparent" />
              {/* Notification badge */}
              <div className="absolute top-1.5 right-1.5 min-w-[20px] h-[20px] bg-red-500 rounded-full text-[9px] text-white flex items-center justify-center font-bold px-1">
                {Math.floor(Math.random() * 15) + 1}
              </div>
            </div>
            {/* Community icon overlapping */}
            <div className="flex justify-center -mt-6 relative z-10">
              <img src={c.icon} className="w-12 h-12 rounded-lg object-cover border-2 border-[#16162a] shadow-lg" alt="" />
            </div>
            {/* Info */}
            <div className="px-2 pt-1.5 pb-2.5 text-center">
              <p className="text-white text-[12px] font-bold leading-tight mb-0.5 line-clamp-1">{c.name}</p>
              <p className="text-gray-600 text-[9px] mb-2">{formatNumber(c.members)} Members</p>
              {c.checkedIn ? (
                <div className="bg-gray-600/40 text-white/40 text-[9px] font-bold py-1 px-2 rounded-md text-center uppercase flex items-center justify-center gap-1">
                  <Check size={10} />Checked In
                </div>
              ) : (
                <button onClick={(e) => { e.stopPropagation(); checkIn(c.id); }}
                  className="w-full bg-[#2dbe60] text-white text-[9px] font-bold py-1.5 rounded-md text-center uppercase tracking-wider hover:bg-[#25a854] transition-colors">
                  CHECK IN
                </button>
              )}
            </div>
          </div>
        ))}
        {/* Create/Join More card */}
        <div className="rounded-xl border border-dashed border-white/15 flex flex-col items-center justify-center gap-2 min-h-[180px]"
          onClick={() => comingSoon("Create Community")}>
          <Plus size={28} className="text-white/20" />
          <span className="text-white/20 text-[10px] font-medium">Join More</span>
        </div>
      </div>
      {/* Create button */}
      <div className="px-3 mb-5">
        <button onClick={() => comingSoon("Create Community")}
          className="w-full py-2.5 border border-[#2dbe60] rounded-lg text-[#2dbe60] font-bold text-[13px] tracking-wide hover:bg-[#2dbe60]/10 transition-colors">
          CREATE YOUR OWN
        </button>
      </div>
      {/* Recommended */}
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
                  <p className="text-white text-[11px] font-semibold">{chat.name}</p>
                  <p className="text-white/50 text-[9px] flex items-center gap-1"><Users size={9} />{chat.membersCount} online</p>
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
      <h3 className="text-white font-bold text-[16px] mb-3">Amino+ Store</h3>
      <div className="bg-gradient-to-r from-[#2dbe60] to-[#1a9e4a] rounded-xl p-4 mb-4 relative overflow-hidden">
        <div className="absolute top-0 right-0 w-24 h-24 bg-white/10 rounded-full -translate-y-1/2 translate-x-1/2" />
        <div className="flex items-center gap-2 mb-2"><Star size={20} className="text-yellow-300" fill="currentColor" /><span className="text-white font-bold text-[16px]">Amino+</span></div>
        <p className="text-white/80 text-[11px] mb-3 leading-relaxed">Ad-free experience, custom profiles, exclusive chat bubbles and more!</p>
        <button onClick={() => comingSoon("Amino+ Subscription")} className="bg-white text-[#2dbe60] font-bold text-[12px] px-5 py-1.5 rounded-full">Subscribe Now</button>
      </div>
      <h4 className="text-white font-semibold text-[14px] mb-2">Chat Bubbles</h4>
      <div className="grid grid-cols-3 gap-2 mb-4">
        {[{ name: "Galaxy", gradient: "from-purple-600 to-blue-500" }, { name: "Neon", gradient: "from-green-400 to-cyan-500" }, { name: "Fire", gradient: "from-red-500 to-orange-400" }, { name: "Ice", gradient: "from-blue-300 to-blue-600" }, { name: "Gold", gradient: "from-yellow-400 to-amber-600" }, { name: "Rainbow", gradient: "from-red-400 via-green-400 to-blue-400" }].map(item => (
          <div key={item.name} className="bg-[#16162a] rounded-lg p-2.5 flex flex-col items-center gap-1.5" onClick={() => comingSoon("Purchase " + item.name)}>
            <div className={`w-10 h-10 rounded-full bg-gradient-to-br ${item.gradient}`} />
            <span className="text-white text-[10px] font-medium">{item.name}</span>
            <span className="text-[#2dbe60] text-[9px] font-bold flex items-center gap-0.5">🪙 50</span>
          </div>
        ))}
      </div>
      <h4 className="text-white font-semibold text-[14px] mb-2">Profile Frames</h4>
      <div className="grid grid-cols-3 gap-2">
        {[{ name: "Crown", color: "border-yellow-400" }, { name: "Wings", color: "border-blue-400" }, { name: "Flames", color: "border-red-400" }, { name: "Stars", color: "border-purple-400" }].map(item => (
          <div key={item.name} className="bg-[#16162a] rounded-lg p-2.5 flex flex-col items-center gap-1.5" onClick={() => comingSoon("Purchase " + item.name)}>
            <div className={`w-10 h-10 rounded-full border-2 ${item.color}`} />
            <span className="text-white text-[10px] font-medium">{item.name}</span>
            <span className="text-[#2dbe60] text-[9px] font-bold flex items-center gap-0.5">🪙 100</span>
          </div>
        ))}
      </div>
    </div>
  );
}

// ============ COMMUNITY DETAIL SCREEN ============
function CommunityDetailScreen() {
  const { selectedCommunity, communities, currentUser, posts, chatRooms, wikiEntries, communityMembers, goBack, navigateTo, setSelectedPost, setSelectedChat, setSelectedCommunity, toggleJoinCommunity, checkIn, getCommunityProfile } = useApp();
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [communityTab, setCommunityTab] = useState("featured");
  const [showFab, setShowFab] = useState(false);
  const [checkInDismissed, setCheckInDismissed] = useState(false);

  if (!selectedCommunity) return null;

  const communityPosts = posts.filter(p => p.communityId === selectedCommunity.id);
  const featuredPosts = communityPosts.filter(p => p.isFeatured);
  const commChats = chatRooms.filter(ch => ch.communityId === selectedCommunity.id);
  const joinedComms = communities.filter(c => c.isJoined);
  const onlineCount = selectedCommunity.onlineNow;
  const profile = getCommunityProfile(selectedCommunity.id);

  // Use community profile nickname/avatar if available, otherwise fallback to global
  const displayName = profile?.nickname || currentUser.nickname;
  const displayAvatar = profile?.avatar || currentUser.avatar;

  const drawerMenuItems = [
    { id: "home", label: "Home", iconBg: "bg-[#4FC3F7]", icon: <HomeIcon size={18} className="text-white" />, action: () => { setCommunityTab("featured"); setDrawerOpen(false); } },
    { id: "chats", label: "My Chats", iconBg: "bg-[#66BB6A]", icon: <MessageCircle size={18} className="text-white" />, badge: commChats.reduce((s, c) => s + c.unreadCount, 0), action: () => { setCommunityTab("chat"); setDrawerOpen(false); } },
    { id: "catalog", label: "Catalog", iconBg: "bg-[#FFA726]", icon: <Star size={18} className="text-white" />, action: () => comingSoon("Catalog") },
    { id: "public-chats", label: "Public Chatrooms", iconBg: "bg-[#66BB6A]", icon: <Users size={18} className="text-white" />, action: () => { setCommunityTab("chat"); setDrawerOpen(false); } },
    { id: "latest", label: "Latest Feed", iconBg: "bg-[#42A5F5]", icon: <Clock size={18} className="text-white" />, action: () => { setCommunityTab("latest"); setDrawerOpen(false); } },
    { id: "guidelines", label: "Guidelines", iconBg: "bg-[#42A5F5]", icon: <Globe size={18} className="text-white" />, action: () => { setCommunityTab("guidelines"); setDrawerOpen(false); } },
    { id: "resources", label: "Resource Links", iconBg: "bg-[#FFA726]", icon: <Link2 size={18} className="text-white" />, action: () => comingSoon("Resource Links") },
  ];

  return (
    <div className="relative h-full flex">
      {/* ===== SIDE DRAWER ===== */}
      {drawerOpen && (
        <div className="absolute inset-0 z-50 flex animate-in fade-in duration-150">
          <div className="w-[60px] bg-[#0a0a16] flex flex-col items-center py-3 gap-2 border-r border-white/5 overflow-y-auto amino-scroll shrink-0">
            <button onClick={() => { setDrawerOpen(false); goBack(); }} className="flex flex-col items-center gap-0.5 mb-2">
              <LogOut size={18} className="text-white/60 rotate-180" /><span className="text-white/40 text-[8px]">Exit</span>
            </button>
            <div className="w-6 h-px bg-white/10 mb-1" />
            {joinedComms.map(c => (
              <button key={c.id} onClick={() => { setSelectedCommunity(c); setDrawerOpen(false); setCommunityTab("featured"); }}
                className={`relative w-10 h-10 rounded-lg overflow-hidden shrink-0 border-2 transition-all ${c.id === selectedCommunity.id ? "border-[#2dbe60]" : "border-transparent"}`}>
                <img src={c.icon} className="w-full h-full object-cover" alt="" />
                <span className="absolute -top-1 -right-1 min-w-[16px] h-[16px] bg-red-500 rounded-full text-[8px] text-white flex items-center justify-center font-bold px-0.5">
                  {Math.floor(Math.random() * 9) + 1}
                </span>
              </button>
            ))}
            <button onClick={() => comingSoon("Join More")} className="w-10 h-10 rounded-lg bg-[#1a1a2e] flex items-center justify-center text-gray-600 shrink-0 mt-1 border border-dashed border-white/10">
              <Plus size={18} />
            </button>
          </div>
          <div className="w-[calc(100%-120px)] max-w-[280px] bg-[#0f0f1e] h-full overflow-y-auto amino-scroll animate-in slide-in-from-left duration-200">
            <div className="relative h-[200px]">
              <img src={selectedCommunity.cover} className="w-full h-full object-cover" alt="" />
              <div className="absolute inset-0 bg-gradient-to-t from-[#0f0f1e] via-[#0f0f1e]/60 to-[#0f0f1e]/30" />
              <div className="absolute top-4 left-0 right-0 text-center">
                <p className="text-white/50 text-[10px] tracking-[3px] uppercase">Welcome To</p>
                <h2 className="text-white font-bold text-[18px] mt-0.5 drop-shadow-lg">{selectedCommunity.name.toUpperCase()}</h2>
              </div>
              <div className="absolute bottom-8 left-0 right-0 flex flex-col items-center">
                <div className="relative mb-1">
                  <div className="w-16 h-16 rounded-full p-[2px] bg-gradient-to-br from-blue-400 to-blue-600">
                    <img src={displayAvatar} className="w-full h-full rounded-full object-cover border-2 border-[#0f0f1e]" alt="" />
                  </div>
                  <div className="absolute -top-1 -right-1 w-6 h-6 rounded-full bg-[#42A5F5] flex items-center justify-center border-2 border-[#0f0f1e]">
                    <Plus size={12} className="text-white" />
                  </div>
                </div>
                <span className="text-white text-[13px] font-semibold">{displayName}</span>
              </div>
            </div>
            <div className="px-6 -mt-2 mb-3">
              {selectedCommunity.checkedIn ? (
                <div className="bg-gray-600/40 text-white/40 font-bold text-[13px] py-2.5 rounded-lg text-center uppercase flex items-center justify-center gap-1"><Check size={14} />Checked In</div>
              ) : (
                <button onClick={() => checkIn(selectedCommunity.id)}
                  className="w-full bg-[#2dbe60] text-white font-bold text-[14px] py-2.5 rounded-lg text-center uppercase tracking-wider shadow-lg shadow-[#2dbe60]/20 hover:bg-[#25a854] transition-colors">
                  Check In
                </button>
              )}
            </div>
            <div className="px-2">
              {drawerMenuItems.map(item => (
                <button key={item.id} onClick={item.action}
                  className="w-full flex items-center gap-3 px-3 py-3 rounded-lg hover:bg-white/5 transition-colors border-b border-white/3">
                  <div className={`w-9 h-9 rounded-full ${item.iconBg} flex items-center justify-center shrink-0`}>{item.icon}</div>
                  <span className="text-white text-[14px] font-medium flex-1 text-left">{item.label}</span>
                  {item.badge && item.badge > 0 && <span className="min-w-[22px] h-[22px] bg-red-500 rounded-md text-[10px] text-white flex items-center justify-center font-bold px-1">{item.badge}</span>}
                </button>
              ))}
              <button onClick={() => comingSoon("More Options")} className="w-full flex items-center gap-3 px-3 py-3 mt-1">
                <span className="text-gray-500 text-[13px]">See More...</span>
                <ChevronRight size={14} className="text-gray-600 ml-auto" />
              </button>
            </div>
          </div>
          <div className="flex-1 bg-black/40" onClick={() => setDrawerOpen(false)} />
        </div>
      )}

      {/* ===== MAIN CONTENT ===== */}
      <div className="flex-1 flex flex-col h-full overflow-hidden">
        <div className="flex-1 overflow-y-auto amino-scroll">
          {/* Header with cover */}
          <div className="relative h-[200px]">
            <img src={selectedCommunity.cover} className="w-full h-full object-cover" alt="" />
            <div className="absolute inset-0 bg-gradient-to-t from-[#0f0f1e] via-transparent to-[#0f0f1e]/40" />
            <div className="absolute top-9 left-2">
              <button onClick={goBack} className="p-1.5 bg-black/40 rounded-full"><ChevronLeft size={20} className="text-white" /></button>
            </div>
            <div className="absolute top-9 right-2 flex gap-2">
              <button onClick={() => comingSoon("Claim Gifts")} className="bg-[#2dbe60] text-white text-[10px] font-bold px-3 py-1 rounded-full flex items-center gap-1">🎁 Claim gifts</button>
              <button onClick={() => comingSoon("Search")} className="p-1.5 bg-black/40 rounded-full"><Search size={18} className="text-white" /></button>
              <button onClick={() => comingSoon("Notifications")} className="p-1.5 bg-black/40 rounded-full relative"><Bell size={18} className="text-white" /><span className="absolute top-0 right-0 w-2 h-2 bg-red-500 rounded-full" /></button>
            </div>
            <div className="absolute bottom-3 left-3 right-3 flex items-end gap-3">
              <img src={selectedCommunity.icon} className="w-16 h-16 rounded-xl object-cover border-2 border-[#0f0f1e] shadow-lg shrink-0" alt="" />
              <div className="flex-1 min-w-0">
                <h2 className="text-white font-bold text-[20px] drop-shadow-lg leading-tight">{selectedCommunity.name.split(" ")[0]}</h2>
                <div className="flex items-center gap-2 mt-0.5">
                  <span className="text-white/70 text-[11px]">{formatNumber(selectedCommunity.members)} Members</span>
                  <button onClick={() => comingSoon("Leaderboards")} className="bg-[#2dbe60] text-white text-[9px] font-bold px-2 py-0.5 rounded-full">Leaderboards</button>
                </div>
              </div>
            </div>
          </div>

          {/* Check-in banner (per community) */}
          {!selectedCommunity.checkedIn && !checkInDismissed && (
            <div className="mx-3 mt-2 bg-[#16162a] rounded-lg p-3 relative">
              <button onClick={() => setCheckInDismissed(true)} className="absolute top-2 right-2 text-gray-600"><X size={14} /></button>
              <p className="text-white text-[13px] font-semibold text-center mb-2">Check In to earn a prize</p>
              <div className="flex items-center justify-center gap-1.5 mb-2">
                {[1, 2, 3, 4, 5, 6, 7].map(day => (
                  <div key={day} className={`w-5 h-5 rounded-full border-2 ${day === 1 ? "border-[#2dbe60] bg-[#2dbe60]" : "border-gray-600"} flex items-center justify-center`}>
                    {day === 1 && <Check size={10} className="text-white" />}
                  </div>
                ))}
              </div>
              <button onClick={() => checkIn(selectedCommunity.id)}
                className="w-full bg-[#2dbe60] text-white font-bold text-[12px] py-2 rounded-lg text-center uppercase tracking-wider">Check In</button>
            </div>
          )}

          {/* Live chatrooms horizontal */}
          {commChats.filter(c => c.isGroupChat).length > 0 && (
            <div className="px-3 pt-3 pb-1">
              <div className="flex gap-2 overflow-x-auto amino-scroll pb-1">
                {commChats.filter(c => c.isGroupChat).map(chat => (
                  <div key={chat.id} className="shrink-0 w-[160px] rounded-lg overflow-hidden bg-[#16162a]" onClick={() => { setSelectedChat(chat); navigateTo("chatroom"); }}>
                    <div className="relative h-[80px]">
                      <img src={selectedCommunity.cover} className="w-full h-full object-cover opacity-60" alt="" />
                      <div className="absolute inset-0 bg-gradient-to-t from-[#16162a] to-transparent" />
                      <div className="absolute top-1.5 left-1.5 flex items-center gap-1">
                        <img src={communityMembers[0]?.avatar || currentUser.avatar} className="w-5 h-5 rounded-full object-cover" alt="" />
                        <span className="bg-red-500 text-white text-[8px] font-bold px-1.5 py-0.5 rounded flex items-center gap-0.5">● Live</span>
                      </div>
                    </div>
                    <div className="px-2 py-1.5">
                      <p className="text-white text-[11px] font-semibold truncate">{chat.name}</p>
                      <p className="text-gray-600 text-[9px] flex items-center gap-1"><Users size={8} />{chat.membersCount}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Tabs */}
          <div className="flex border-b border-white/5 mx-0 mt-1 overflow-x-auto amino-scroll">
            {[
              { id: "guidelines", label: "Guidelines" },
              { id: "featured", label: "Featured" },
              { id: "latest", label: "Latest Feed" },
              { id: "chat", label: "Public Chatrooms" },
            ].map(tab => (
              <button key={tab.id} onClick={() => setCommunityTab(tab.id)}
                className={`shrink-0 px-4 py-3 text-[12px] font-semibold transition-colors relative whitespace-nowrap ${communityTab === tab.id ? "text-white" : "text-gray-600"}`}>
                {tab.label}
                {communityTab === tab.id && <div className="absolute bottom-0 left-2 right-2 h-[2px] bg-white rounded-full" />}
              </button>
            ))}
          </div>

          {/* Tab Content */}
          <div className="pb-16">
            {communityTab === "guidelines" && (
              <div className="px-3 pt-3">
                <h4 className="text-white font-bold text-[15px] mb-3">Community Guidelines</h4>
                {selectedCommunity.guidelines.map((rule, i) => (
                  <div key={i} className="flex gap-3 mb-3 bg-[#16162a] rounded-lg p-3">
                    <div className="w-6 h-6 rounded-full bg-[#2dbe60]/20 flex items-center justify-center shrink-0">
                      <span className="text-[#2dbe60] text-[11px] font-bold">{i + 1}</span>
                    </div>
                    <p className="text-gray-300 text-[12px] leading-relaxed">{rule}</p>
                  </div>
                ))}
              </div>
            )}
            {communityTab === "featured" && (
              <div className="px-3 pt-3">
                {featuredPosts.length > 0 && (
                  <div className="mb-3">
                    {featuredPosts.map(post => (
                      <button key={post.id} onClick={() => { setSelectedPost(post); navigateTo("post"); }}
                        className="w-full text-left py-2 border-b border-white/3 flex items-start gap-2">
                        <span className="text-[#2dbe60] text-[8px] mt-1.5">●</span>
                        <span className="text-white text-[13px] leading-snug">{post.title}</span>
                      </button>
                    ))}
                  </div>
                )}
                {communityPosts.map(post => (
                  <PostCard key={post.id} post={post} showCommunity={false} onPress={() => { setSelectedPost(post); navigateTo("post"); }} />
                ))}
                {communityPosts.length === 0 && (
                  <div className="text-center py-12"><Star size={36} className="text-gray-700 mx-auto mb-2" /><p className="text-gray-600 text-[13px]">No featured posts yet</p></div>
                )}
              </div>
            )}
            {communityTab === "latest" && (
              <div className="px-3 pt-3">
                {communityPosts.length > 0 ? communityPosts.map(post => (
                  <PostCard key={post.id} post={post} showCommunity={false} onPress={() => { setSelectedPost(post); navigateTo("post"); }} />
                )) : (
                  <div className="text-center py-12"><FileText size={36} className="text-gray-700 mx-auto mb-2" /><p className="text-gray-600 text-[13px]">No posts yet</p><p className="text-gray-700 text-[11px]">Be the first to post!</p></div>
                )}
              </div>
            )}
            {communityTab === "chat" && (
              <div className="px-3 pt-3">
                {commChats.filter(c => c.isGroupChat).map(chat => (
                  <div key={chat.id} className="mb-2 rounded-lg overflow-hidden bg-[#16162a]" onClick={() => { setSelectedChat(chat); navigateTo("chatroom"); }}>
                    <div className="flex items-center gap-3 p-3">
                      <div className="w-11 h-11 rounded-full bg-[#1e1e38] flex items-center justify-center shrink-0"><Hash size={18} className="text-[#2dbe60]" /></div>
                      <div className="flex-1 min-w-0">
                        <p className="text-white text-[13px] font-semibold truncate">{chat.name}</p>
                        <p className="text-gray-600 text-[10px] flex items-center gap-1"><Users size={9} />{chat.membersCount} members</p>
                      </div>
                      <div className="w-2 h-2 rounded-full bg-[#2dbe60]" />
                    </div>
                  </div>
                ))}
                <button onClick={() => comingSoon("Create Chat")} className="w-full mt-3 py-2.5 border border-dashed border-white/10 rounded-lg text-gray-600 text-[12px] flex items-center justify-center gap-2">
                  <Plus size={14} />Create a New Chat
                </button>
              </div>
            )}
          </div>
        </div>

        {/* ===== COMMUNITY BOTTOM NAV ===== */}
        <div className="sticky bottom-0 z-30 flex items-center bg-[#0b0b18] border-t border-white/5" style={{ paddingBottom: 4 }}>
          <button onClick={() => setDrawerOpen(true)} className="flex-1 flex flex-col items-center py-2 gap-0.5 text-gray-500 relative">
            <Menu size={22} /><span className="text-[9px] font-medium">Menu</span>
            <span className="absolute top-1 right-[calc(50%-14px)] w-2 h-2 bg-red-500 rounded-full" />
          </button>
          <button onClick={() => comingSoon("Online Members")} className="flex-1 flex flex-col items-center py-2 gap-0.5 text-gray-500 relative">
            <div className="relative">
              <img src={communityMembers[0]?.avatar || currentUser.avatar} className="w-6 h-6 rounded-full object-cover" alt="" />
              <span className="absolute -top-2 -right-3 min-w-[18px] h-[14px] bg-[#2dbe60] rounded-full text-[8px] text-white flex items-center justify-center font-bold px-0.5">{onlineCount > 999 ? "999+" : onlineCount}</span>
            </div>
            <span className="text-[9px] font-medium">Online</span>
          </button>
          <button onClick={() => setShowFab(!showFab)}
            className="relative -mt-4 w-14 h-14 rounded-full bg-[#2563EB] shadow-lg shadow-blue-500/30 flex items-center justify-center z-10 border-4 border-[#0b0b18]"
            style={{ transform: showFab ? "rotate(45deg)" : "none", transition: "transform 0.2s" }}>
            <Plus size={28} className="text-white" />
          </button>
          <button onClick={() => setCommunityTab("chat")} className="flex-1 flex flex-col items-center py-2 gap-0.5 text-gray-500 relative">
            <MessageCircle size={22} /><span className="text-[9px] font-medium">Chats</span>
            <span className="absolute top-1 right-[calc(50%-14px)] w-2 h-2 bg-red-500 rounded-full" />
          </button>
          <button onClick={() => navigateTo("communityProfile")} className="flex-1 flex flex-col items-center py-2 gap-0.5 text-gray-500">
            <div className="w-6 h-6 rounded-full overflow-hidden border border-white/20">
              <img src={displayAvatar} className="w-full h-full object-cover" alt="" />
            </div>
            <span className="text-[9px] font-medium">Me</span>
          </button>
        </div>

        {/* FAB Menu */}
        {showFab && (
          <div className="absolute bottom-20 left-1/2 -translate-x-1/2 z-40 flex flex-col gap-2 animate-in fade-in slide-in-from-bottom-4 duration-200">
            {[
              { icon: <FileText size={16} />, label: "Blog Post", color: "bg-blue-500" },
              { icon: <Image size={16} />, label: "Image Post", color: "bg-purple-500" },
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
    </div>
  );
}

// ============ POST DETAIL ============
function PostDetailScreen() {
  const { selectedPost, comments, goBack, toggleLike } = useApp();
  const [newComment, setNewComment] = useState("");
  if (!selectedPost) return null;
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
              <span className="bg-gradient-to-r from-blue-600 to-blue-400 text-white text-[9px] font-bold px-1.5 py-0.5 rounded-full">Lv.{selectedPost.author.level}</span>
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

// ============ GLOBAL PROFILE SCREEN (Main App - before entering community) ============
function GlobalProfileScreen() {
  const { currentUser, communities, goBack, navigateTo, setSelectedCommunity } = useApp();
  const [activeProfileTab, setActiveProfileTab] = useState("communities");
  const joinedComms = communities.filter(c => c.isJoined);

  return (
    <div className="amino-scroll pb-20">
      <div className="relative h-[280px]">
        <img src={currentUser.backgroundImage} className="w-full h-full object-cover" alt="" />
        <div className="absolute inset-0 bg-gradient-to-t from-[#0f0f1e] via-[#0f0f1e]/30 to-transparent" />
        <button onClick={goBack} className="absolute top-10 left-3 p-1.5 bg-black/40 rounded-full z-10"><ChevronLeft size={20} className="text-white" /></button>
        <div className="absolute top-10 right-3 flex items-center gap-2 z-10">
          <span className="bg-[#2dbe60]/90 text-white text-[10px] font-semibold px-2 py-1 rounded-full flex items-center gap-1"><span className="w-1.5 h-1.5 rounded-full bg-white" />Online</span>
          <button onClick={() => comingSoon("Settings")} className="p-1.5 bg-black/40 rounded-full"><Settings size={18} className="text-white" /></button>
        </div>
        <div className="absolute bottom-4 left-0 right-0 flex flex-col items-center">
          <div className="relative mb-2">
            <div className="w-20 h-20 rounded-full p-[2.5px] bg-gradient-to-br from-red-500 via-yellow-500 via-green-500 via-blue-500 to-purple-500">
              <img src={currentUser.avatar} className="w-full h-full rounded-full object-cover border-2 border-[#0f0f1e]" alt="" />
            </div>
          </div>
          <h2 className="text-white font-bold text-[18px] mb-1">{currentUser.nickname}</h2>
          <div className="bg-gradient-to-r from-blue-600 to-blue-400 text-white text-[10px] font-bold px-2.5 py-0.5 rounded-full mb-2 flex items-center gap-1">
            <span className="bg-blue-800 rounded-full px-1.5 py-px text-[9px]">Lv{currentUser.level}</span>
            <span>{currentUser.levelTitle}</span>
          </div>
          <div className="flex flex-wrap justify-center gap-1 mb-2 px-8">
            {currentUser.badges.map((badge: Badge, i: number) => (
              <span key={i} className="text-[9px] font-bold px-2 py-0.5 rounded" style={{ backgroundColor: badge.color, color: "white" }}>{badge.label}</span>
            ))}
          </div>
        </div>
      </div>
      {/* Global stats */}
      <div className="px-3 py-2 flex gap-2">
        <div className="flex-1 bg-gradient-to-r from-[#FF6F00] to-[#FFB300] rounded-lg px-3 py-2 flex items-center gap-2">
          <Flame size={16} className="text-white" />
          <span className="text-white text-[11px] font-bold">{currentUser.streakDays} Day Streak</span>
        </div>
        <div className="flex items-center gap-1">
          <div className="flex items-center bg-[#2dbe60] rounded-full px-2.5 py-1 gap-1">
            <span className="text-[10px]">🪙</span>
            <span className="text-white text-[11px] font-bold">{currentUser.coins}</span>
          </div>
        </div>
      </div>
      <div className="flex items-center py-3 mx-3 border-b border-white/5">
        <div className="flex-1 text-center"><p className="text-white font-bold text-[18px]">{formatNumber(currentUser.reputation)}</p><p className="text-gray-600 text-[10px]">Reputation</p></div>
        <div className="flex-1 text-center border-x border-white/5"><p className="text-white font-bold text-[18px]">{currentUser.following}</p><p className="text-gray-600 text-[10px]">Following</p></div>
        <div className="flex-1 text-center"><p className="text-white font-bold text-[18px]">{formatNumber(currentUser.followers)}</p><p className="text-gray-600 text-[10px]">Followers</p></div>
      </div>
      <div className="px-3 py-3">
        <p className="text-gray-400 text-[12px] leading-relaxed">{currentUser.bio}</p>
        <p className="text-gray-700 text-[10px] mt-1">Member since {currentUser.memberSince}</p>
      </div>
      {/* Tabs: Communities, Wall, Media */}
      <div className="flex border-b border-white/5 mx-3">
        {["communities", "wall", "media"].map(tab => (
          <button key={tab} onClick={() => setActiveProfileTab(tab)}
            className={`flex-1 py-2.5 text-[12px] font-semibold text-center capitalize transition-colors relative ${activeProfileTab === tab ? "text-[#2dbe60]" : "text-gray-600"}`}>
            {tab}
            {activeProfileTab === tab && <div className="absolute bottom-0 left-1/4 right-1/4 h-[2px] bg-[#2dbe60] rounded-full" />}
          </button>
        ))}
      </div>
      {activeProfileTab === "communities" ? (
        <div className="px-3 pt-3">
          <h4 className="text-white font-semibold text-[14px] mb-2">My Communities ({joinedComms.length})</h4>
          {joinedComms.map(c => (
            <div key={c.id} className="flex items-center gap-3 mb-2.5" onClick={() => { setSelectedCommunity(c); navigateTo("community"); }}>
              <img src={c.icon} className="w-11 h-11 rounded-lg object-cover shrink-0" alt="" />
              <div className="flex-1 min-w-0">
                <p className="text-white text-[13px] font-semibold truncate">{c.name}</p>
                <p className="text-gray-600 text-[10px]">{formatNumber(c.members)} Members</p>
              </div>
              <ChevronRight size={16} className="text-gray-600" />
            </div>
          ))}
        </div>
      ) : (
        <div className="px-3 py-8 text-center"><p className="text-gray-700 text-[12px]">No {activeProfileTab} yet</p></div>
      )}
    </div>
  );
}

// ============ COMMUNITY PROFILE SCREEN (Inside community - separate from global) ============
function CommunityProfileScreen() {
  const { selectedCommunity, currentUser, goBack, getCommunityProfile } = useApp();
  const [activeTab, setActiveTab] = useState("posts");

  if (!selectedCommunity) return null;

  const profile = getCommunityProfile(selectedCommunity.id);
  const displayName = profile?.nickname || currentUser.nickname;
  const displayAvatar = profile?.avatar || currentUser.avatar;
  const displayBio = profile?.bio || "No bio set for this community yet.";
  const displayBg = profile?.backgroundImage || selectedCommunity.cover;
  const displayLevel = profile?.level || 1;
  const displayLevelTitle = profile?.levelTitle || "Newcomer";
  const displayRep = profile?.reputation || 0;
  const displayFollowing = profile?.following || 0;
  const displayFollowers = profile?.followers || 0;
  const displayBadges = profile?.badges || [];
  const displayStreak = profile?.streakDays || 0;
  const displayRole = profile?.role || "Member";
  const displayJoinedAt = profile?.joinedAt || "Recently";
  const displayPostsCount = profile?.postsCount || 0;

  return (
    <div className="amino-scroll pb-20">
      <div className="relative h-[280px]">
        <img src={displayBg} className="w-full h-full object-cover" alt="" />
        <div className="absolute inset-0 bg-gradient-to-t from-[#0f0f1e] via-[#0f0f1e]/30 to-transparent" />
        <button onClick={goBack} className="absolute top-10 left-3 p-1.5 bg-black/40 rounded-full z-10"><ChevronLeft size={20} className="text-white" /></button>
        <div className="absolute top-10 right-3 flex items-center gap-2 z-10">
          <button onClick={() => comingSoon("Edit Community Profile")} className="p-1.5 bg-black/40 rounded-full"><Settings size={18} className="text-white" /></button>
        </div>
        <div className="absolute bottom-4 left-0 right-0 flex flex-col items-center">
          <div className="relative mb-2">
            <div className="w-20 h-20 rounded-full p-[2.5px] bg-gradient-to-br from-blue-400 to-blue-600">
              <img src={displayAvatar} className="w-full h-full rounded-full object-cover border-2 border-[#0f0f1e]" alt="" />
            </div>
            {displayRole === "Leader" && <div className="absolute -bottom-1 left-1/2 -translate-x-1/2 bg-[#2dbe60] text-white text-[7px] font-bold px-2 py-0.5 rounded-full">Leader</div>}
            {displayRole === "Curator" && <div className="absolute -bottom-1 left-1/2 -translate-x-1/2 bg-[#E040FB] text-white text-[7px] font-bold px-2 py-0.5 rounded-full">Curator</div>}
          </div>
          <h2 className="text-white font-bold text-[18px] mb-1">{displayName}</h2>
          <div className="bg-gradient-to-r from-blue-600 to-blue-400 text-white text-[10px] font-bold px-2.5 py-0.5 rounded-full mb-1.5 flex items-center gap-1">
            <span className="bg-blue-800 rounded-full px-1.5 py-px text-[9px]">Lv{displayLevel}</span>
            <span>{displayLevelTitle}</span>
          </div>
          <div className="flex flex-wrap justify-center gap-1 mb-1 px-8">
            {displayBadges.map((badge: Badge, i: number) => (
              <span key={i} className="text-[9px] font-bold px-2 py-0.5 rounded" style={{ backgroundColor: badge.color, color: "white" }}>{badge.label}</span>
            ))}
          </div>
          <p className="text-gray-500 text-[10px]">in {selectedCommunity.name}</p>
        </div>
      </div>
      {/* Community-specific stats */}
      <div className="px-3 py-2 flex gap-2">
        <div className="flex-1 bg-gradient-to-r from-[#FF6F00] to-[#FFB300] rounded-lg px-3 py-2 flex items-center gap-2">
          <Flame size={16} className="text-white" />
          <span className="text-white text-[11px] font-bold">{displayStreak} Day Streak</span>
        </div>
        <div className="bg-[#16162a] rounded-lg px-3 py-2 flex items-center gap-1">
          <FileText size={14} className="text-gray-500" />
          <span className="text-white text-[11px] font-bold">{displayPostsCount} Posts</span>
        </div>
      </div>
      <div className="flex items-center py-3 mx-3 border-b border-white/5">
        <div className="flex-1 text-center"><p className="text-white font-bold text-[18px]">{formatNumber(displayRep)}</p><p className="text-gray-600 text-[10px]">Reputation</p></div>
        <div className="flex-1 text-center border-x border-white/5"><p className="text-white font-bold text-[18px]">{displayFollowing}</p><p className="text-gray-600 text-[10px]">Following</p></div>
        <div className="flex-1 text-center"><p className="text-white font-bold text-[18px]">{formatNumber(displayFollowers)}</p><p className="text-gray-600 text-[10px]">Followers</p></div>
      </div>
      <div className="px-3 py-3">
        <p className="text-gray-400 text-[12px] leading-relaxed">{displayBio}</p>
        <p className="text-gray-700 text-[10px] mt-1">Joined {displayJoinedAt}</p>
      </div>
      <div className="flex border-b border-white/5 mx-3">
        {["posts", "wall", "media"].map(tab => (
          <button key={tab} onClick={() => setActiveTab(tab)}
            className={`flex-1 py-2.5 text-[12px] font-semibold text-center capitalize transition-colors relative ${activeTab === tab ? "text-[#2dbe60]" : "text-gray-600"}`}>
            {tab}
            {activeTab === tab && <div className="absolute bottom-0 left-1/4 right-1/4 h-[2px] bg-[#2dbe60] rounded-full" />}
          </button>
        ))}
      </div>
      <div className="px-3 py-8 text-center"><p className="text-gray-700 text-[12px]">No {activeTab} yet</p></div>
    </div>
  );
}

// ============ MAIN HOME COMPONENT ============
export default function Home() {
  const { activeTab, currentScreen } = useApp();

  if (currentScreen === "community") return <CommunityDetailScreen />;
  if (currentScreen === "communityProfile") return <CommunityProfileScreen />;
  if (currentScreen === "post") return <PostDetailScreen />;
  if (currentScreen === "chatroom") return <ChatRoomScreen />;
  if (currentScreen === "profile") return <GlobalProfileScreen />;

  return (
    <div className="flex flex-col h-full">
      <AminoMainHeader />
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
