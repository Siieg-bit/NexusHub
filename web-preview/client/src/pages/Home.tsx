import { useState, useRef, useEffect } from "react";
import { useApp, Community, Post, ChatRoom as ChatRoomType, Badge, PostAuthor, WikiEntry, CommunityMember } from "@/contexts/AppContext";
import { Search, Bell, Plus, ChevronLeft, ChevronRight, Heart, MessageCircle, Share2, Pin, Send, Smile, Mic, Users, Clock, Globe, Trophy, Star, BookOpen, MoreHorizontal, Check, Flame, Award, Bookmark, Menu, X, Home as HomeIcon, Zap, BarChart3, Image, FileText, HelpCircle, Settings, LogOut, Eye, TrendingUp, Crown, Shield, Hash, ArrowUp, PenSquare, Vote, CircleDot } from "lucide-react";

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

// ============ AMINO MAIN HEADER (Discover/Communities/Chats) ============
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
        <div className="flex-1 flex items-center bg-[#1a1a2e] rounded-full px-3 py-1.5 mx-1">
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
          <button className="p-1 shrink-0"><Plus size={20} className="text-[#2dbe60]" /></button>
          <button className="p-1 relative shrink-0">
            <Bell size={19} className="text-white/60" />
            <span className="absolute -top-0.5 -right-0.5 w-4 h-4 bg-red-500 rounded-full text-[8px] text-white flex items-center justify-center font-bold">3</span>
          </button>
        </>
      )}
    </div>
  );
}

// ============ BOTTOM NAV (Amino exact) ============
function BottomNav() {
  const { activeTab, setActiveTab, setCurrentScreen, setSelectedCommunity, setSelectedPost, setSelectedChat } = useApp();
  const tabs = [
    { id: "discover", label: "Discover", icon: (active: boolean) => <Globe size={22} strokeWidth={active ? 2.5 : 1.5} /> },
    { id: "communities", label: "Communities", icon: (active: boolean) => (
      <svg viewBox="0 0 24 24" fill={active ? "currentColor" : "none"} stroke="currentColor" strokeWidth={active ? 0 : 1.5} className="w-[22px] h-[22px]">
        <rect x="3" y="3" width="7" height="7" rx="1.5" /><rect x="14" y="3" width="7" height="7" rx="1.5" />
        <rect x="3" y="14" width="7" height="7" rx="1.5" /><rect x="14" y="14" width="7" height="7" rx="1.5" />
      </svg>
    )},
    { id: "chats", label: "Chats", icon: (active: boolean) => <MessageCircle size={22} strokeWidth={active ? 2.5 : 1.5} fill={active ? "currentColor" : "none"} /> },
    { id: "store", label: "Store", icon: (active: boolean) => <Star size={22} strokeWidth={active ? 2.5 : 1.5} fill={active ? "currentColor" : "none"} /> },
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

// ============ POST CARD (Amino Faithful) ============
function PostCard({ post, onPress, showCommunity = true }: { post: Post; onPress: () => void; showCommunity?: boolean }) {
  const { toggleLike, votePoll } = useApp();

  return (
    <div className="mb-2.5 bg-[#16162a] rounded-lg overflow-hidden" onClick={onPress}>
      {/* Community badge */}
      {showCommunity && (
        <div className="flex items-center gap-2 px-3 pt-2.5 pb-1">
          <img src={post.communityIcon} className="w-5 h-5 rounded object-cover" alt="" />
          <span className="text-[#2dbe60] text-[11px] font-semibold">{post.communityName}</span>
          {post.isPinned && <span className="ml-auto bg-[#2dbe60]/15 text-[#2dbe60] text-[8px] px-1.5 py-0.5 rounded font-bold flex items-center gap-0.5"><Pin size={7} />PINNED</span>}
          {post.isFeatured && !post.isPinned && <span className="ml-auto bg-yellow-500/15 text-yellow-400 text-[8px] px-1.5 py-0.5 rounded font-bold flex items-center gap-0.5"><Star size={7} />FEATURED</span>}
        </div>
      )}
      {/* Author row */}
      <div className="flex items-center gap-2 px-3 pb-2">
        <img src={post.author.avatar} className="w-7 h-7 rounded-full object-cover" alt="" />
        <div className="flex items-center gap-1.5 flex-1 min-w-0">
          <span className="text-white text-[12px] font-semibold truncate">{post.author.nickname}</span>
          {post.author.role === "Leader" && <span className="bg-[#2dbe60] text-white text-[7px] px-1 py-px rounded font-bold shrink-0">Leader</span>}
          {post.author.role === "Curator" && <span className="bg-[#E040FB] text-white text-[7px] px-1 py-px rounded font-bold shrink-0">Curator</span>}
        </div>
        <span className="text-gray-600 text-[10px] shrink-0">{getTimeAgo(post.createdAt)}</span>
      </div>
      {/* Content */}
      <div className="px-3 pb-2">
        {/* Type indicator */}
        {post.type === "poll" && (
          <div className="flex items-center gap-1 mb-1.5">
            <BarChart3 size={12} className="text-blue-400" />
            <span className="text-blue-400 text-[10px] font-semibold uppercase">Poll</span>
          </div>
        )}
        {post.type === "quiz" && (
          <div className="flex items-center gap-1 mb-1.5">
            <HelpCircle size={12} className="text-purple-400" />
            <span className="text-purple-400 text-[10px] font-semibold uppercase">Quiz</span>
          </div>
        )}
        <h4 className="text-white font-bold text-[14px] leading-snug mb-1">{post.title}</h4>
        <p className="text-gray-400 text-[12px] leading-relaxed line-clamp-2">{post.content}</p>
      </div>
      {/* Media */}
      {post.mediaUrl && (
        <div className="px-3 pb-2">
          <img src={post.mediaUrl} className="w-full h-[160px] object-cover rounded-md" alt="" />
        </div>
      )}
      {/* Poll options */}
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
      {/* Tags */}
      {post.tags.length > 0 && (
        <div className="flex gap-1 px-3 pb-2 flex-wrap">
          {post.tags.map(tag => (
            <span key={tag} className="bg-[#1e1e38] text-gray-500 text-[10px] px-2 py-0.5 rounded-full">#{tag}</span>
          ))}
        </div>
      )}
      {/* Actions bar */}
      <div className="flex items-center gap-5 px-3 py-2 border-t border-white/5">
        <button onClick={(e) => { e.stopPropagation(); toggleLike(post.id); }}
          className={`flex items-center gap-1 text-[12px] ${post.isLiked ? "text-red-400" : "text-gray-600"}`}>
          <Heart size={16} fill={post.isLiked ? "currentColor" : "none"} />
          <span>{post.likesCount}</span>
        </button>
        <div className="flex items-center gap-1 text-gray-600 text-[12px]">
          <MessageCircle size={16} />
          <span>{post.commentsCount}</span>
        </div>
        <button className="ml-auto text-gray-600"><Share2 size={16} /></button>
      </div>
    </div>
  );
}

// ============ DISCOVER TAB ============
function DiscoverTab() {
  const { communities, posts, navigateTo, setSelectedCommunity, setSelectedPost, checkIn } = useApp();
  const joinedComms = communities.filter(c => c.isJoined);
  const [bannerIdx, setBannerIdx] = useState(0);
  const banners = joinedComms.slice(0, 3);

  useEffect(() => {
    if (banners.length === 0) return;
    const t = setInterval(() => setBannerIdx(i => (i + 1) % banners.length), 4000);
    return () => clearInterval(t);
  }, [banners.length]);

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
                <p className="text-white/60 text-[11px]">{formatNumber(c.members)} Members</p>
              </div>
            </div>
          ))}
          <div className="absolute bottom-1.5 left-1/2 -translate-x-1/2 flex gap-1 z-10">
            {banners.map((_, i) => (
              <div key={i} className={`h-1 rounded-full transition-all ${i === bannerIdx ? "bg-white w-4" : "bg-white/30 w-1"}`} />
            ))}
          </div>
        </div>
      )}

      {/* Check In streak banner */}
      <div className="px-3 pt-3 pb-1">
        <div className="bg-gradient-to-r from-[#FF6F00] to-[#FFB300] rounded-lg px-3 py-2 flex items-center gap-2">
          <Flame size={18} className="text-white" />
          <div className="flex-1">
            <span className="text-white text-[12px] font-bold">Check-in Streak: 318 Days</span>
            <p className="text-white/70 text-[10px]">Keep your streak going!</p>
          </div>
          <ChevronRight size={16} className="text-white/60" />
        </div>
      </div>

      {/* My Communities - horizontal scroll */}
      <div className="px-3 pt-3 pb-1">
        <div className="flex items-center justify-between mb-2">
          <h3 className="text-white font-bold text-[15px]">My Communities</h3>
          <button className="text-[#2dbe60] text-[12px] font-semibold">See All</button>
        </div>
        <div className="flex gap-2.5 overflow-x-auto pb-2 amino-scroll">
          {joinedComms.map(c => (
            <div key={c.id} className="shrink-0 w-[110px] relative rounded-lg overflow-hidden"
              onClick={() => { setSelectedCommunity(c); navigateTo("community"); }}>
              <img src={c.cover} className="w-full h-[130px] object-cover" alt="" />
              <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/20 to-transparent" />
              <div className="absolute bottom-0 left-0 right-0 p-1.5">
                <p className="text-white text-[10px] font-semibold leading-tight mb-1.5 line-clamp-2">{c.name}</p>
                {c.checkedIn ? (
                  <div className="bg-gray-600/60 text-white/50 text-[8px] font-bold py-0.5 px-2 rounded text-center uppercase">Checked In</div>
                ) : (
                  <button onClick={(e) => { e.stopPropagation(); checkIn(c.id); }}
                    className="w-full bg-[#2dbe60] text-white text-[8px] font-bold py-0.5 px-2 rounded text-center uppercase">CHECK IN</button>
                )}
              </div>
            </div>
          ))}
          <div className="shrink-0 w-[110px] h-[130px] rounded-lg border border-dashed border-white/15 flex flex-col items-center justify-center gap-1.5">
            <Plus size={22} className="text-white/25" />
            <span className="text-white/25 text-[9px] text-center px-2">Join More</span>
          </div>
        </div>
      </div>

      {/* Recommended Communities */}
      <div className="px-3 pt-2 pb-1">
        <h3 className="text-white font-bold text-[15px] mb-2">Recommended</h3>
        <div className="flex gap-2 overflow-x-auto pb-2 amino-scroll">
          {communities.filter(c => !c.isJoined).map(c => (
            <div key={c.id} className="shrink-0 w-[90px]" onClick={() => { setSelectedCommunity(c); navigateTo("community"); }}>
              <img src={c.icon} className="w-[90px] h-[90px] rounded-lg object-cover mb-1" alt="" />
              <p className="text-white text-[10px] font-medium leading-tight truncate">{c.name}</p>
              <p className="text-gray-600 text-[9px]">{formatNumber(c.members)}</p>
            </div>
          ))}
        </div>
      </div>

      {/* Latest Posts Feed */}
      <div className="px-3 pt-2 pb-20">
        <h3 className="text-white font-bold text-[15px] mb-2">Latest Posts</h3>
        {posts.map(post => (
          <PostCard key={post.id} post={post} onPress={() => { setSelectedPost(post); navigateTo("post"); }} />
        ))}
      </div>
    </div>
  );
}

// ============ COMMUNITIES TAB ============
function CommunitiesTab() {
  const { communities, navigateTo, setSelectedCommunity, checkIn } = useApp();
  const joined = communities.filter(c => c.isJoined);

  return (
    <div className="amino-scroll pb-20">
      <div className="px-3 pt-3">
        <h3 className="text-white font-bold text-[16px] mb-0.5">My Communities</h3>
        <p className="text-gray-600 text-[11px] mb-3">Long press to reorder</p>
      </div>
      {/* Grid of joined communities */}
      <div className="px-3 grid grid-cols-2 gap-2.5 mb-4">
        {joined.map(c => (
          <div key={c.id} className="relative rounded-lg overflow-hidden"
            onClick={() => { setSelectedCommunity(c); navigateTo("community"); }}>
            <img src={c.cover} className="w-full h-[130px] object-cover" alt="" />
            <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/20 to-transparent" />
            <div className="absolute bottom-0 left-0 right-0 p-2">
              <p className="text-white text-[11px] font-semibold leading-tight mb-1.5">{c.name}</p>
              {c.checkedIn ? (
                <div className="bg-gray-600/60 text-white/50 text-[9px] font-bold py-0.5 px-2 rounded text-center uppercase">Checked In</div>
              ) : (
                <button onClick={(e) => { e.stopPropagation(); checkIn(c.id); }}
                  className="w-full bg-[#2dbe60] text-white text-[9px] font-bold py-1 rounded text-center uppercase tracking-wider">CHECK IN</button>
              )}
            </div>
          </div>
        ))}
        <div className="h-[130px] rounded-lg border border-dashed border-white/15 flex flex-col items-center justify-center gap-2">
          <Plus size={26} className="text-white/25" />
          <span className="text-white/25 text-[10px]">Join More</span>
        </div>
      </div>

      {/* Create your own */}
      <div className="px-3 mb-5">
        <button className="w-full py-2.5 border border-[#2dbe60] rounded-lg text-[#2dbe60] font-bold text-[13px] tracking-wide hover:bg-[#2dbe60]/10 transition-colors">
          CREATE YOUR OWN
        </button>
      </div>

      {/* Recommended */}
      <div className="px-3">
        <h3 className="text-white font-bold text-[14px] mb-2.5">Recommended for You</h3>
        {communities.filter(c => !c.isJoined).map(c => (
          <div key={c.id} className="flex items-center gap-3 mb-2.5" onClick={() => { setSelectedCommunity(c); navigateTo("community"); }}>
            <img src={c.icon} className="w-11 h-11 rounded-lg object-cover shrink-0" alt="" />
            <div className="flex-1 min-w-0">
              <p className="text-white text-[13px] font-semibold truncate">{c.name}</p>
              <p className="text-gray-600 text-[10px]">{formatNumber(c.members)} Members</p>
            </div>
            <button className="bg-[#2dbe60] text-white text-[11px] font-bold px-3.5 py-1.5 rounded-full">Join</button>
          </div>
        ))}
      </div>
    </div>
  );
}

// ============ CHATS TAB (Amino Style with Left Sidebar) ============
function ChatsTab() {
  const { communities, chatRooms, navigateTo, setSelectedChat } = useApp();
  const [sidebarFilter, setSidebarFilter] = useState("recent");
  const joinedComms = communities.filter(c => c.isJoined);

  const filteredChats = sidebarFilter === "recent" ? chatRooms :
    sidebarFilter === "global" ? chatRooms :
    chatRooms.filter(ch => ch.communityId === sidebarFilter);

  return (
    <div className="flex h-full" style={{ paddingBottom: 48 }}>
      {/* Left Sidebar - Community Icons (Amino exact) */}
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
        <button className="w-9 h-9 rounded-full bg-[#1a1a2e] flex items-center justify-center text-gray-600 shrink-0 mt-1">
          <Plus size={16} />
        </button>
      </div>

      {/* Chat List */}
      <div className="flex-1 overflow-y-auto amino-scroll">
        {/* New chat button */}
        <button className="w-full flex items-center gap-3 px-3 py-3 border-b border-white/5 hover:bg-white/3 transition-colors">
          <div className="w-10 h-10 rounded-full bg-[#1e1e38] flex items-center justify-center">
            <PenSquare size={16} className="text-gray-500" />
          </div>
          <span className="text-gray-500 text-[13px]">New Chat</span>
        </button>

        {/* Chat items */}
        {filteredChats.map(chat => (
          <button key={chat.id} onClick={() => { setSelectedChat(chat); navigateTo("chatroom"); }}
            className="w-full flex items-center gap-3 px-3 py-2.5 border-b border-white/3 hover:bg-white/3 transition-colors text-left">
            <div className="relative shrink-0">
              {chat.isGroupChat ? (
                <div className="w-11 h-11 rounded-full bg-[#1e1e38] flex items-center justify-center">
                  <Hash size={18} className="text-gray-500" />
                </div>
              ) : (
                <img src={chat.cover || chat.communityIcon} className="w-11 h-11 rounded-full object-cover" alt="" />
              )}
              {chat.unreadCount > 0 && (
                <span className="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] bg-red-500 rounded-full text-[9px] text-white flex items-center justify-center font-bold px-1">{chat.unreadCount}</span>
              )}
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-center justify-between mb-0.5">
                <span className="text-white text-[13px] font-semibold truncate">{chat.name}</span>
                <span className="text-gray-600 text-[10px] shrink-0 ml-2">{chat.lastMessageTime}</span>
              </div>
              <p className={`text-[11px] truncate ${chat.unreadCount > 0 ? "text-gray-400" : "text-gray-600"}`}>
                {chat.isGroupChat && <span className="text-gray-500">{chat.lastMessageBy}: </span>}
                {chat.lastMessage}
              </p>
            </div>
          </button>
        ))}

        {/* Recommended public chats */}
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
      {/* Amino+ card */}
      <div className="bg-gradient-to-r from-[#2dbe60] to-[#1a9e4a] rounded-xl p-4 mb-4 relative overflow-hidden">
        <div className="absolute top-0 right-0 w-24 h-24 bg-white/10 rounded-full -translate-y-1/2 translate-x-1/2" />
        <div className="flex items-center gap-2 mb-2">
          <Star size={20} className="text-yellow-300" fill="currentColor" />
          <span className="text-white font-bold text-[16px]">Amino+</span>
        </div>
        <p className="text-white/80 text-[11px] mb-3 leading-relaxed">Ad-free experience, custom profiles, exclusive chat bubbles and more!</p>
        <button className="bg-white text-[#2dbe60] font-bold text-[12px] px-5 py-1.5 rounded-full">Subscribe Now</button>
      </div>
      {/* Chat Bubbles */}
      <h4 className="text-white font-semibold text-[14px] mb-2">Chat Bubbles</h4>
      <div className="grid grid-cols-3 gap-2 mb-4">
        {[
          { name: "Galaxy", gradient: "from-purple-600 to-blue-500" },
          { name: "Neon", gradient: "from-green-400 to-cyan-500" },
          { name: "Fire", gradient: "from-red-500 to-orange-400" },
          { name: "Ice", gradient: "from-blue-300 to-blue-600" },
          { name: "Gold", gradient: "from-yellow-400 to-amber-600" },
          { name: "Rainbow", gradient: "from-red-400 via-green-400 to-blue-400" },
        ].map(item => (
          <div key={item.name} className="bg-[#16162a] rounded-lg p-2.5 flex flex-col items-center gap-1.5">
            <div className={`w-10 h-10 rounded-full bg-gradient-to-br ${item.gradient}`} />
            <span className="text-white text-[10px] font-medium">{item.name}</span>
            <span className="text-[#2dbe60] text-[9px] font-bold flex items-center gap-0.5">🪙 50</span>
          </div>
        ))}
      </div>
      {/* Profile Frames */}
      <h4 className="text-white font-semibold text-[14px] mb-2">Profile Frames</h4>
      <div className="grid grid-cols-3 gap-2">
        {[
          { name: "Crown", color: "border-yellow-400" },
          { name: "Wings", color: "border-blue-400" },
          { name: "Flames", color: "border-red-400" },
          { name: "Stars", color: "border-purple-400" },
        ].map(item => (
          <div key={item.name} className="bg-[#16162a] rounded-lg p-2.5 flex flex-col items-center gap-1.5">
            <div className={`w-10 h-10 rounded-full border-2 ${item.color}`} />
            <span className="text-white text-[10px] font-medium">{item.name}</span>
            <span className="text-[#2dbe60] text-[9px] font-bold flex items-center gap-0.5">🪙 100</span>
          </div>
        ))}
      </div>
    </div>
  );
}

// ============ COMMUNITY DETAIL (Amino Internal - COMPLETELY REDESIGNED) ============
function CommunityDetailScreen() {
  const { selectedCommunity, posts, chatRooms, wikiEntries, communityMembers, goBack, navigateTo, setSelectedPost, setSelectedChat, toggleJoinCommunity, checkIn } = useApp();
  const [sideDrawerOpen, setSideDrawerOpen] = useState(false);
  const [activeSection, setActiveSection] = useState("featured");
  const [showFab, setShowFab] = useState(false);

  if (!selectedCommunity) return null;

  const communityPosts = posts.filter(p => p.communityId === selectedCommunity.id);
  const featuredPosts = communityPosts.filter(p => p.isFeatured);
  const commChats = chatRooms.filter(ch => ch.communityId === selectedCommunity.id);

  return (
    <div className="relative h-full flex">
      {/* Side Drawer Overlay */}
      {sideDrawerOpen && (
        <div className="absolute inset-0 z-50 flex">
          {/* Drawer */}
          <div className="w-[260px] bg-[#0f0f1e] h-full overflow-y-auto amino-scroll border-r border-white/5 animate-in slide-in-from-left duration-200">
            {/* Community header in drawer */}
            <div className="relative h-[120px]">
              <img src={selectedCommunity.cover} className="w-full h-full object-cover" alt="" />
              <div className="absolute inset-0 bg-gradient-to-t from-[#0f0f1e] via-[#0f0f1e]/50 to-transparent" />
              <div className="absolute bottom-3 left-3 right-3 flex items-center gap-2">
                <img src={selectedCommunity.icon} className="w-10 h-10 rounded-lg object-cover border border-white/20" alt="" />
                <div>
                  <h3 className="text-white font-bold text-[13px]">{selectedCommunity.name}</h3>
                  <p className="text-white/50 text-[10px]">{formatNumber(selectedCommunity.members)} Members</p>
                </div>
              </div>
            </div>
            {/* Nav items */}
            <div className="py-2">
              {selectedCommunity.sideNavItems.map(item => (
                <button key={item.id} onClick={() => { setActiveSection(item.id); setSideDrawerOpen(false); }}
                  className={`w-full flex items-center gap-3 px-4 py-2.5 text-left transition-colors ${activeSection === item.id ? "bg-[#2dbe60]/10 text-[#2dbe60]" : "text-gray-400 hover:bg-white/3"}`}>
                  <span className="text-[16px] w-6 text-center">{item.icon}</span>
                  <span className="text-[13px] font-medium flex-1">{item.label}</span>
                  {item.badge && <span className="bg-red-500 text-white text-[8px] w-4 h-4 rounded-full flex items-center justify-center font-bold">{item.badge}</span>}
                </button>
              ))}
            </div>
            <div className="border-t border-white/5 py-2 px-4">
              <button className="flex items-center gap-3 py-2 text-gray-500 text-[12px]">
                <Settings size={14} />
                <span>Community Settings</span>
              </button>
            </div>
          </div>
          {/* Overlay backdrop */}
          <div className="flex-1 bg-black/50" onClick={() => setSideDrawerOpen(false)} />
        </div>
      )}

      {/* Main Content */}
      <div className="flex-1 flex flex-col h-full overflow-hidden">
        {/* Community Header */}
        <div className="sticky top-0 z-40 bg-[#0f0f1e]/95 backdrop-blur-sm border-b border-white/5" style={{ paddingTop: 36 }}>
          <div className="flex items-center gap-2 px-3 py-2">
            <button onClick={() => setSideDrawerOpen(true)} className="p-1">
              <Menu size={20} className="text-white" />
            </button>
            <img src={selectedCommunity.icon} className="w-7 h-7 rounded-md object-cover" alt="" />
            <span className="text-white font-semibold text-[14px] flex-1 truncate">{selectedCommunity.name}</span>
            <button className="p-1"><Search size={18} className="text-white/60" /></button>
            <button onClick={goBack} className="p-1"><X size={18} className="text-white/60" /></button>
          </div>
          {/* Section tabs */}
          <div className="flex overflow-x-auto amino-scroll px-1">
            {["featured", "latest", "chat", "members", "wiki"].map(tab => (
              <button key={tab} onClick={() => setActiveSection(tab)}
                className={`px-3 py-2 text-[12px] font-semibold whitespace-nowrap transition-colors relative capitalize ${activeSection === tab ? "text-[#2dbe60]" : "text-gray-600"}`}>
                {tab}
                {activeSection === tab && <div className="absolute bottom-0 left-2 right-2 h-[2px] bg-[#2dbe60] rounded-full" />}
              </button>
            ))}
          </div>
        </div>

        {/* Content Area */}
        <div className="flex-1 overflow-y-auto amino-scroll">
          {/* HOME / FEATURED section */}
          {activeSection === "home" && (
            <div>
              {/* Cover banner */}
              <div className="relative h-[160px]">
                <img src={selectedCommunity.cover} className="w-full h-full object-cover" alt="" />
                <div className="absolute inset-0 bg-gradient-to-t from-[#0f0f1e] via-transparent to-transparent" />
                <div className="absolute bottom-3 left-3 right-3">
                  <div className="flex items-center gap-2">
                    <img src={selectedCommunity.icon} className="w-12 h-12 rounded-xl object-cover border-2 border-white/20" alt="" />
                    <div>
                      <h2 className="text-white font-bold text-[16px]">{selectedCommunity.name}</h2>
                      <p className="text-white/60 text-[11px]">{formatNumber(selectedCommunity.members)} Members  ·  {formatNumber(selectedCommunity.onlineNow)} Online</p>
                    </div>
                  </div>
                </div>
              </div>
              {/* Quick actions */}
              <div className="px-3 py-3 flex gap-2">
                {selectedCommunity.isJoined ? (
                  <>
                    {!selectedCommunity.checkedIn && (
                      <button onClick={() => checkIn(selectedCommunity.id)} className="flex-1 bg-[#2dbe60] text-white font-bold text-[12px] py-2 rounded-lg uppercase tracking-wider">CHECK IN</button>
                    )}
                    <button className="flex-1 bg-[#1e1e38] text-white font-medium text-[12px] py-2 rounded-lg">Invite Friends</button>
                  </>
                ) : (
                  <button onClick={() => toggleJoinCommunity(selectedCommunity.id)} className="flex-1 bg-[#2dbe60] text-white font-bold text-[12px] py-2 rounded-lg">Join Community</button>
                )}
              </div>
              {/* Description */}
              <div className="px-3 pb-3">
                <p className="text-gray-400 text-[12px] leading-relaxed">{selectedCommunity.description}</p>
              </div>
              {/* Featured posts */}
              <div className="px-3 pb-20">
                <h4 className="text-white font-bold text-[14px] mb-2">Featured Posts</h4>
                {featuredPosts.map(post => (
                  <PostCard key={post.id} post={post} showCommunity={false} onPress={() => { setSelectedPost(post); navigateTo("post"); }} />
                ))}
              </div>
            </div>
          )}

          {/* FEATURED section */}
          {activeSection === "featured" && (
            <div className="px-3 pt-3 pb-20">
              {featuredPosts.length > 0 ? featuredPosts.map(post => (
                <PostCard key={post.id} post={post} showCommunity={false} onPress={() => { setSelectedPost(post); navigateTo("post"); }} />
              )) : (
                <div className="text-center py-12">
                  <Star size={36} className="text-gray-700 mx-auto mb-2" />
                  <p className="text-gray-600 text-[13px]">No featured posts yet</p>
                </div>
              )}
            </div>
          )}

          {/* LATEST section */}
          {activeSection === "latest" && (
            <div className="px-3 pt-3 pb-20">
              {communityPosts.length > 0 ? communityPosts.map(post => (
                <PostCard key={post.id} post={post} showCommunity={false} onPress={() => { setSelectedPost(post); navigateTo("post"); }} />
              )) : (
                <div className="text-center py-12">
                  <FileText size={36} className="text-gray-700 mx-auto mb-2" />
                  <p className="text-gray-600 text-[13px]">No posts yet</p>
                  <p className="text-gray-700 text-[11px]">Be the first to post!</p>
                </div>
              )}
            </div>
          )}

          {/* CHAT section */}
          {activeSection === "chat" && (
            <div className="px-3 pt-3 pb-20">
              {/* Public chats */}
              <h4 className="text-gray-500 text-[11px] font-semibold mb-2 uppercase tracking-wider">Public Chats</h4>
              {commChats.filter(c => c.isGroupChat).map(chat => (
                <div key={chat.id} className="mb-2 rounded-lg overflow-hidden bg-[#16162a]" onClick={() => { setSelectedChat(chat); navigateTo("chatroom"); }}>
                  <div className="flex items-center gap-3 p-3">
                    <div className="w-11 h-11 rounded-full bg-[#1e1e38] flex items-center justify-center shrink-0">
                      <Hash size={18} className="text-[#2dbe60]" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-white text-[13px] font-semibold truncate">{chat.name}</p>
                      <p className="text-gray-600 text-[10px] flex items-center gap-1"><Users size={9} />{chat.membersCount} members</p>
                    </div>
                    <div className="w-2 h-2 rounded-full bg-[#2dbe60]" />
                  </div>
                </div>
              ))}
              {/* Create chat */}
              <button className="w-full mt-3 py-2.5 border border-dashed border-white/10 rounded-lg text-gray-600 text-[12px] flex items-center justify-center gap-2">
                <Plus size={14} />
                Create a New Chat
              </button>
            </div>
          )}

          {/* MEMBERS section */}
          {activeSection === "members" && (
            <div className="px-3 pt-3 pb-20">
              {/* Online count */}
              <div className="flex items-center gap-2 mb-3">
                <div className="w-2 h-2 rounded-full bg-[#2dbe60]" />
                <span className="text-gray-500 text-[12px]">{formatNumber(selectedCommunity.onlineNow)} Online Now</span>
              </div>
              {/* Staff section */}
              <h4 className="text-gray-500 text-[11px] font-semibold mb-2 uppercase tracking-wider">Staff</h4>
              {communityMembers.filter(m => m.role !== "Member").map(member => (
                <div key={member.id} className="flex items-center gap-3 py-2.5 border-b border-white/3">
                  <div className="relative">
                    <img src={member.avatar} className="w-10 h-10 rounded-full object-cover" alt="" />
                    {member.isOnline && <div className="absolute bottom-0 right-0 w-3 h-3 rounded-full bg-[#2dbe60] border-2 border-[#0f0f1e]" />}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-1.5">
                      <span className="text-white text-[13px] font-semibold truncate">{member.nickname}</span>
                      <span className={`text-[8px] font-bold px-1.5 py-0.5 rounded ${member.role === "Leader" ? "bg-[#2dbe60] text-white" : "bg-[#E040FB] text-white"}`}>{member.role}</span>
                    </div>
                    <div className="flex items-center gap-2 mt-0.5">
                      <span className="text-gray-600 text-[10px]">Lv.{member.level}</span>
                      <span className="text-gray-600 text-[10px]">Rep: {formatNumber(member.reputation)}</span>
                    </div>
                  </div>
                </div>
              ))}
              {/* Regular members */}
              <h4 className="text-gray-500 text-[11px] font-semibold mb-2 mt-4 uppercase tracking-wider">Members</h4>
              {communityMembers.filter(m => m.role === "Member").map(member => (
                <div key={member.id} className="flex items-center gap-3 py-2.5 border-b border-white/3">
                  <div className="relative">
                    <img src={member.avatar} className="w-10 h-10 rounded-full object-cover" alt="" />
                    {member.isOnline && <div className="absolute bottom-0 right-0 w-3 h-3 rounded-full bg-[#2dbe60] border-2 border-[#0f0f1e]" />}
                  </div>
                  <div className="flex-1 min-w-0">
                    <span className="text-white text-[13px] font-medium truncate block">{member.nickname}</span>
                    <span className="text-gray-600 text-[10px]">Lv.{member.level}  ·  {member.isOnline ? "Online" : member.lastSeen}</span>
                  </div>
                </div>
              ))}
            </div>
          )}

          {/* WIKI section */}
          {activeSection === "wiki" && (
            <div className="px-3 pt-3 pb-20">
              <h4 className="text-gray-500 text-[11px] font-semibold mb-2 uppercase tracking-wider">Wiki Entries</h4>
              {wikiEntries.map(entry => (
                <div key={entry.id} className="mb-2 bg-[#16162a] rounded-lg overflow-hidden flex">
                  {entry.cover && (
                    <img src={entry.cover} className="w-20 h-20 object-cover shrink-0" alt="" />
                  )}
                  <div className="flex-1 p-3 min-w-0">
                    <h5 className="text-white text-[13px] font-semibold truncate">{entry.title}</h5>
                    <p className="text-gray-600 text-[10px] mt-0.5">{entry.category}  ·  by {entry.author}</p>
                    <p className="text-gray-600 text-[10px] flex items-center gap-1 mt-1"><Eye size={9} />{formatNumber(entry.viewCount)} views</p>
                  </div>
                </div>
              ))}
            </div>
          )}

          {/* GUIDELINES section */}
          {activeSection === "guidelines" && (
            <div className="px-3 pt-3 pb-20">
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

          {/* LEADERBOARD section */}
          {activeSection === "leaderboard" && (
            <div className="px-3 pt-3 pb-20">
              <h4 className="text-white font-bold text-[15px] mb-3">Leaderboard</h4>
              {communityMembers.sort((a, b) => b.reputation - a.reputation).map((member, i) => (
                <div key={member.id} className="flex items-center gap-3 py-2.5 border-b border-white/3">
                  <span className={`w-7 text-center font-bold text-[14px] ${i === 0 ? "text-yellow-400" : i === 1 ? "text-gray-300" : i === 2 ? "text-amber-600" : "text-gray-600"}`}>
                    {i < 3 ? ["🥇", "🥈", "🥉"][i] : `#${i + 1}`}
                  </span>
                  <img src={member.avatar} className="w-9 h-9 rounded-full object-cover" alt="" />
                  <div className="flex-1 min-w-0">
                    <span className="text-white text-[13px] font-semibold truncate block">{member.nickname}</span>
                    <span className="text-gray-600 text-[10px]">Lv.{member.level}</span>
                  </div>
                  <span className="text-[#2dbe60] text-[12px] font-bold">{formatNumber(member.reputation)}</span>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Floating Action Button */}
        <button onClick={() => setShowFab(!showFab)}
          className="absolute bottom-4 right-4 w-12 h-12 rounded-full bg-[#2dbe60] shadow-lg shadow-[#2dbe60]/30 flex items-center justify-center z-30 transition-transform"
          style={{ transform: showFab ? "rotate(45deg)" : "none" }}>
          <Plus size={24} className="text-white" />
        </button>
        {/* FAB Menu */}
        {showFab && (
          <div className="absolute bottom-20 right-4 z-30 flex flex-col gap-2 animate-in fade-in slide-in-from-bottom-4 duration-200">
            {[
              { icon: <FileText size={16} />, label: "Blog Post", color: "bg-blue-500" },
              { icon: <Image size={16} />, label: "Image Post", color: "bg-purple-500" },
              { icon: <BarChart3 size={16} />, label: "Poll", color: "bg-orange-500" },
              { icon: <HelpCircle size={16} />, label: "Quiz", color: "bg-pink-500" },
            ].map(item => (
              <div key={item.label} className="flex items-center gap-2 justify-end">
                <span className="text-white text-[11px] font-medium bg-black/60 px-2 py-1 rounded">{item.label}</span>
                <button className={`w-10 h-10 rounded-full ${item.color} flex items-center justify-center text-white shadow-lg`}>
                  {item.icon}
                </button>
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
        {/* Author */}
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
          <button className="p-1"><MoreHorizontal size={18} className="text-gray-600" /></button>
        </div>
        {/* Title & Content */}
        <h2 className="text-white font-bold text-[18px] mb-2 leading-snug">{selectedPost.title}</h2>
        <p className="text-gray-300 text-[13px] leading-relaxed mb-3 whitespace-pre-line">{selectedPost.content}</p>
        {selectedPost.mediaUrl && (
          <img src={selectedPost.mediaUrl} className="w-full rounded-lg mb-3" alt="" />
        )}
        {/* Poll in detail */}
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
        {/* Tags */}
        <div className="flex gap-1.5 mb-4 flex-wrap">
          {selectedPost.tags.map(tag => (
            <span key={tag} className="bg-[#1e1e38] text-gray-500 text-[11px] px-2.5 py-1 rounded-full">#{tag}</span>
          ))}
        </div>
        {/* Actions */}
        <div className="flex items-center gap-6 py-3 border-y border-white/5 mb-4">
          <button onClick={() => toggleLike(selectedPost.id)}
            className={`flex items-center gap-1.5 text-[13px] ${selectedPost.isLiked ? "text-red-400" : "text-gray-600"}`}>
            <Heart size={20} fill={selectedPost.isLiked ? "currentColor" : "none"} />
            <span>{selectedPost.likesCount}</span>
          </button>
          <div className="flex items-center gap-1.5 text-gray-600 text-[13px]">
            <MessageCircle size={20} />
            <span>{selectedPost.commentsCount}</span>
          </div>
          <button className="ml-auto text-gray-600"><Bookmark size={20} /></button>
          <button className="text-gray-600"><Share2 size={20} /></button>
        </div>
        {/* Comments */}
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
                  <Heart size={12} fill={comment.isLiked ? "currentColor" : "none"} />
                  <span>{comment.likesCount}</span>
                </button>
                <button className="text-gray-700 text-[11px]">Reply</button>
              </div>
            </div>
          </div>
        ))}
      </div>
      {/* Comment input */}
      <div className="flex items-center gap-2 px-3 py-2 bg-[#0b0b18] border-t border-white/5">
        <input value={newComment} onChange={e => setNewComment(e.target.value)}
          placeholder="Write a comment..."
          className="flex-1 bg-[#1e1e38] text-white text-[13px] px-3 py-2 rounded-full placeholder:text-gray-700 outline-none" />
        <button className="p-1.5 text-[#2dbe60]"><Send size={18} /></button>
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
      {/* Header */}
      <div className="flex items-center gap-2 px-3 py-2 bg-[#0f0f1e]/95 backdrop-blur-sm border-b border-white/5" style={{ paddingTop: 38 }}>
        <button onClick={goBack} className="p-1"><ChevronLeft size={20} className="text-white" /></button>
        <div className="w-8 h-8 rounded-full bg-[#1e1e38] flex items-center justify-center">
          <Hash size={14} className="text-[#2dbe60]" />
        </div>
        <div className="flex-1 min-w-0">
          <span className="text-white font-semibold text-[13px] truncate block">{selectedChat.name}</span>
          <span className="text-gray-600 text-[10px]">{selectedChat.membersCount} members</span>
        </div>
        <button className="p-1"><Users size={18} className="text-white/60" /></button>
        <button className="p-1"><MoreHorizontal size={18} className="text-white/60" /></button>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto amino-scroll px-3 py-2">
        {chatMessages.map(msg => {
          if (msg.isSystem) {
            return (
              <div key={msg.id} className="text-center py-2 mb-2">
                <span className="text-gray-600 text-[10px] bg-[#1e1e38] px-3 py-1 rounded-full">{msg.content}</span>
              </div>
            );
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
                  <div className={`rounded-2xl px-3 py-2 text-[13px] leading-relaxed ${isMe ? "bg-[#2dbe60] text-white rounded-tr-sm" : "bg-[#1e1e38] text-gray-200 rounded-tl-sm"}`}>
                    {msg.content}
                  </div>
                  {msg.reactions && msg.reactions.length > 0 && (
                    <div className={`flex gap-1 mt-1 ${isMe ? "justify-end" : ""}`}>
                      {msg.reactions.map((r, i) => (
                        <span key={i} className="bg-[#1e1e38] text-[10px] px-1.5 py-0.5 rounded-full border border-white/5">{r.emoji} {r.count}</span>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            </div>
          );
        })}
        <div ref={messagesEndRef} />
      </div>

      {/* Input */}
      <div className="flex items-center gap-1.5 px-2 py-2 bg-[#0b0b18] border-t border-white/5">
        <button className="p-1.5"><Plus size={18} className="text-gray-600" /></button>
        <button className="p-1.5"><Smile size={18} className="text-gray-600" /></button>
        <input value={input} onChange={e => setInput(e.target.value)}
          onKeyDown={e => e.key === "Enter" && handleSend()}
          placeholder="Type a message..."
          className="flex-1 bg-[#1e1e38] text-white text-[13px] px-3 py-2 rounded-full placeholder:text-gray-700 outline-none" />
        {input.trim() ? (
          <button onClick={handleSend} className="p-1.5"><Send size={18} className="text-[#2dbe60]" /></button>
        ) : (
          <button className="p-1.5"><Mic size={18} className="text-gray-600" /></button>
        )}
      </div>
    </div>
  );
}

// ============ PROFILE SCREEN ============
function ProfileScreen() {
  const { currentUser, goBack } = useApp();
  const [activeProfileTab, setActiveProfileTab] = useState("posts");

  return (
    <div className="amino-scroll pb-20">
      {/* Background + Header */}
      <div className="relative h-[300px]">
        <img src={currentUser.backgroundImage} className="w-full h-full object-cover" alt="" />
        <div className="absolute inset-0 bg-gradient-to-t from-[#0f0f1e] via-[#0f0f1e]/30 to-transparent" />
        <button onClick={goBack} className="absolute top-10 left-3 p-1.5 bg-black/40 rounded-full z-10">
          <ChevronLeft size={20} className="text-white" />
        </button>
        <div className="absolute top-10 right-3 flex items-center gap-2 z-10">
          <span className="bg-[#2dbe60]/90 text-white text-[10px] font-semibold px-2 py-1 rounded-full flex items-center gap-1">
            <span className="w-1.5 h-1.5 rounded-full bg-white" />Online
          </span>
          <button className="p-1.5 bg-black/40 rounded-full"><MoreHorizontal size={18} className="text-white" /></button>
        </div>

        {/* Avatar + Info */}
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
          {/* Badges */}
          <div className="flex flex-wrap justify-center gap-1 mb-2 px-8">
            {currentUser.badges.map((badge: Badge, i: number) => (
              <span key={i} className="text-[9px] font-bold px-2 py-0.5 rounded" style={{ backgroundColor: badge.color, color: "white" }}>{badge.label}</span>
            ))}
          </div>
          {/* Action buttons */}
          <div className="flex gap-2 mt-1">
            <button className="bg-[#2dbe60] text-white font-bold text-[11px] px-4 py-1.5 rounded-full flex items-center gap-1">
              <Plus size={12} />Follow
            </button>
            <button className="bg-[#333] text-white font-bold text-[11px] px-4 py-1.5 rounded-full flex items-center gap-1">
              <MessageCircle size={12} />Chat
            </button>
          </div>
        </div>
      </div>

      {/* Streak + Achievements */}
      <div className="px-3 py-2 flex gap-2">
        <div className="flex-1 bg-gradient-to-r from-[#FF6F00] to-[#FFB300] rounded-lg px-3 py-2 flex items-center gap-2">
          <Flame size={16} className="text-white" />
          <div>
            <span className="text-white text-[11px] font-bold">{currentUser.streakDays} Day Streak</span>
          </div>
        </div>
        <div className="flex items-center gap-1">
          <div className="flex items-center bg-[#2dbe60] rounded-full px-2.5 py-1 gap-1">
            <span className="text-[10px]">🪙</span>
            <span className="text-white text-[11px] font-bold">{currentUser.coins}</span>
          </div>
          <button className="w-7 h-7 bg-blue-500 rounded-md flex items-center justify-center text-white font-bold text-[12px]">+</button>
        </div>
      </div>

      {/* Stats */}
      <div className="flex items-center py-3 mx-3 border-b border-white/5">
        <div className="flex-1 text-center">
          <p className="text-white font-bold text-[18px]">{formatNumber(currentUser.reputation)}</p>
          <p className="text-gray-600 text-[10px]">Reputation</p>
        </div>
        <div className="flex-1 text-center border-x border-white/5">
          <p className="text-white font-bold text-[18px]">{currentUser.following}</p>
          <p className="text-gray-600 text-[10px]">Following</p>
        </div>
        <div className="flex-1 text-center">
          <p className="text-white font-bold text-[18px]">{formatNumber(currentUser.followers)}</p>
          <p className="text-gray-600 text-[10px]">Followers</p>
        </div>
      </div>

      {/* Bio */}
      <div className="px-3 py-3">
        <p className="text-gray-400 text-[12px] leading-relaxed">{currentUser.bio}</p>
        <p className="text-gray-700 text-[10px] mt-1">Member since {currentUser.memberSince}</p>
      </div>

      {/* Profile Tabs */}
      <div className="flex border-b border-white/5 mx-3">
        {["posts", "wall", "media"].map(tab => (
          <button key={tab} onClick={() => setActiveProfileTab(tab)}
            className={`flex-1 py-2.5 text-[12px] font-semibold text-center capitalize transition-colors relative ${activeProfileTab === tab ? "text-[#2dbe60]" : "text-gray-600"}`}>
            {tab}
            {activeProfileTab === tab && <div className="absolute bottom-0 left-1/4 right-1/4 h-[2px] bg-[#2dbe60] rounded-full" />}
          </button>
        ))}
      </div>

      <div className="px-3 py-8 text-center">
        <p className="text-gray-700 text-[12px]">No {activeProfileTab} yet</p>
      </div>
    </div>
  );
}

// ============ MAIN HOME COMPONENT ============
export default function Home() {
  const { activeTab, currentScreen } = useApp();

  // Sub-screens
  if (currentScreen === "community") return <CommunityDetailScreen />;
  if (currentScreen === "post") return <PostDetailScreen />;
  if (currentScreen === "chatroom") return <ChatRoomScreen />;
  if (currentScreen === "profile") return <ProfileScreen />;

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
