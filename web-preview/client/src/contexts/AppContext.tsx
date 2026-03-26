import React, { createContext, useContext, useState, useCallback, ReactNode } from "react";

// ============ TYPES ============
export interface User {
  id: string;
  nickname: string;
  avatar: string;
  level: number;
  levelTitle: string;
  reputation: number;
  following: number;
  followers: number;
  coins: number;
  streakDays: number;
  bio: string;
  memberSince: string;
  badges: Badge[];
  isOnline: boolean;
  backgroundImage: string;
}

export interface Badge {
  label: string;
  color: string;
}

export interface Community {
  id: string;
  name: string;
  icon: string;
  cover: string;
  members: number;
  onlineNow: number;
  description: string;
  isJoined: boolean;
  checkedIn: boolean;
  category: string;
  aminoId: string;
  guidelines: string[];
  sideNavItems: SideNavItem[];
}

export interface SideNavItem {
  id: string;
  label: string;
  icon: string; // emoji or icon name
  badge?: number;
}

export interface Post {
  id: string;
  communityId: string;
  communityName: string;
  communityIcon: string;
  author: PostAuthor;
  title: string;
  content: string;
  mediaUrl?: string;
  likesCount: number;
  commentsCount: number;
  isLiked: boolean;
  isPinned: boolean;
  isFeatured: boolean;
  tags: string[];
  createdAt: string;
  type: "blog" | "poll" | "quiz" | "wiki" | "image";
  pollOptions?: PollOption[];
}

export interface PostAuthor {
  id: string;
  nickname: string;
  avatar: string;
  level: number;
  role?: "Leader" | "Curator" | "Member";
}

export interface PollOption {
  id: string;
  text: string;
  votes: number;
  percentage: number;
  isVoted: boolean;
}

export interface ChatRoom {
  id: string;
  communityId: string;
  communityIcon: string;
  name: string;
  cover?: string;
  lastMessage: string;
  lastMessageBy: string;
  lastMessageTime: string;
  membersCount: number;
  isGroupChat: boolean;
  unreadCount: number;
}

export interface ChatMessage {
  id: string;
  userId: string;
  nickname: string;
  avatar: string;
  content: string;
  time: string;
  badges?: string[];
  role?: string;
  reactions?: { emoji: string; count: number }[];
  imageUrl?: string;
  isSystem?: boolean;
}

export interface Comment {
  id: string;
  author: PostAuthor;
  content: string;
  likesCount: number;
  isLiked: boolean;
  createdAt: string;
}

export interface WikiEntry {
  id: string;
  title: string;
  cover?: string;
  category: string;
  author: string;
  viewCount: number;
}

export interface CommunityMember {
  id: string;
  nickname: string;
  avatar: string;
  level: number;
  role: "Leader" | "Curator" | "Member";
  isOnline: boolean;
  reputation: number;
  lastSeen: string;
}

// ============ MOCK DATA ============
const defaultSideNav: SideNavItem[] = [
  { id: "home", label: "Home", icon: "🏠" },
  { id: "featured", label: "Featured", icon: "⭐" },
  { id: "latest", label: "Latest", icon: "🕐" },
  { id: "chat", label: "Chat", icon: "💬", badge: 5 },
  { id: "members", label: "Members", icon: "👥" },
  { id: "wiki", label: "Wiki", icon: "📖" },
  { id: "guidelines", label: "Guidelines", icon: "📋" },
  { id: "leaderboard", label: "Leaderboard", icon: "🏆" },
];

const currentUser: User = {
  id: "u1",
  nickname: "NexusUser",
  avatar: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&h=200&fit=crop",
  level: 16,
  levelTitle: "Keep A Straight Face",
  reputation: 48914,
  following: 24,
  followers: 30190,
  coins: 68,
  streakDays: 318,
  bio: "Welcome to my profile! I love anime, gaming and art. Always looking for new friends and communities to join!",
  memberSince: "Jul 3, 2018",
  badges: [
    { label: "Leader", color: "#2dbe60" },
    { label: "She/Her", color: "#666" },
    { label: "Verified", color: "#E040FB" },
    { label: "19+", color: "#9C27B0" },
    { label: "OG Member", color: "#FF9800" },
  ],
  isOnline: true,
  backgroundImage: "https://images.unsplash.com/photo-1534796636912-3b95b3ab5986?w=600&h=400&fit=crop",
};

const communities: Community[] = [
  {
    id: "c1", name: "Anime Amino", icon: "https://images.unsplash.com/photo-1578632767115-351597cf2477?w=200&h=200&fit=crop",
    cover: "https://images.unsplash.com/photo-1578632767115-351597cf2477?w=600&h=300&fit=crop",
    members: 216862, onlineNow: 1243, description: "The biggest anime community! Share your love for anime and manga with fans from around the world.",
    isJoined: true, checkedIn: false, category: "Anime & Manga", aminoId: "anime",
    guidelines: ["Be respectful to all members", "No NSFW content", "Credit artists", "No spam or self-promotion", "Use appropriate tags"],
    sideNavItems: defaultSideNav,
  },
  {
    id: "c2", name: "K-Pop Amino", icon: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=200&h=200&fit=crop",
    cover: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&h=300&fit=crop",
    members: 185430, onlineNow: 892, description: "For all K-Pop fans! BTS, BLACKPINK, Stray Kids, ATEEZ and more.",
    isJoined: true, checkedIn: true, category: "Music", aminoId: "k-pop",
    guidelines: ["No fanwars", "Respect all groups", "Credit fansite photos", "No leaks"],
    sideNavItems: defaultSideNav,
  },
  {
    id: "c3", name: "Gaming Amino", icon: "https://images.unsplash.com/photo-1542751371-adc38448a05e?w=200&h=200&fit=crop",
    cover: "https://images.unsplash.com/photo-1542751371-adc38448a05e?w=600&h=300&fit=crop",
    members: 134500, onlineNow: 567, description: "The ultimate gaming community. PC, Console, Mobile - all gamers welcome!",
    isJoined: true, checkedIn: false, category: "Gaming", aminoId: "gaming",
    guidelines: ["No cheating discussions", "Be a good sport", "No piracy links"],
    sideNavItems: defaultSideNav,
  },
  {
    id: "c4", name: "Art Amino", icon: "https://images.unsplash.com/photo-1513364776144-60967b0f800f?w=200&h=200&fit=crop",
    cover: "https://images.unsplash.com/photo-1513364776144-60967b0f800f?w=600&h=300&fit=crop",
    members: 98200, onlineNow: 234, description: "Share your art, get feedback, and improve your skills!",
    isJoined: false, checkedIn: false, category: "Art", aminoId: "art",
    guidelines: ["Credit original artists", "No art theft", "Constructive criticism only"],
    sideNavItems: defaultSideNav,
  },
  {
    id: "c5", name: "Horror Amino", icon: "https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=200&h=200&fit=crop",
    cover: "https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=600&h=300&fit=crop",
    members: 67800, onlineNow: 156, description: "For horror fans! Movies, books, games, creepypasta and more.",
    isJoined: true, checkedIn: false, category: "Movies & TV", aminoId: "horror",
    guidelines: ["Use trigger warnings", "No real gore", "Spoiler tags required"],
    sideNavItems: defaultSideNav,
  },
  {
    id: "c6", name: "Pokemon Amino", icon: "https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?w=200&h=200&fit=crop",
    cover: "https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?w=600&h=300&fit=crop",
    members: 112300, onlineNow: 445, description: "Gotta catch 'em all! The Pokemon community.",
    isJoined: false, checkedIn: false, category: "Gaming", aminoId: "pokemon",
    guidelines: ["No ROM links", "Be kind to new trainers"],
    sideNavItems: defaultSideNav,
  },
  {
    id: "c7", name: "Cosplay Amino", icon: "https://images.unsplash.com/photo-1608889825103-eb5ed706fc64?w=200&h=200&fit=crop",
    cover: "https://images.unsplash.com/photo-1608889825103-eb5ed706fc64?w=600&h=300&fit=crop",
    members: 54200, onlineNow: 89, description: "Show off your cosplays and get tips from the community!",
    isJoined: false, checkedIn: false, category: "Cosplay", aminoId: "cosplay",
    guidelines: ["Credit cosplayers", "No body shaming", "Constructive feedback"],
    sideNavItems: defaultSideNav,
  },
  {
    id: "c8", name: "Books Amino", icon: "https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=200&h=200&fit=crop",
    cover: "https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=600&h=300&fit=crop",
    members: 43100, onlineNow: 67, description: "For book lovers! Reviews, recommendations and discussions.",
    isJoined: false, checkedIn: false, category: "Books", aminoId: "books",
    guidelines: ["Use spoiler warnings", "Respect all genres"],
    sideNavItems: defaultSideNav,
  },
];

const posts: Post[] = [
  {
    id: "p1", communityId: "c1", communityName: "Anime Amino", communityIcon: communities[0].icon,
    author: { id: "u2", nickname: "OtakuMaster", avatar: "https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=100&h=100&fit=crop", level: 32, role: "Leader" },
    title: "Top 10 Animes da Temporada - Primavera 2026",
    content: "Pessoal, a temporada de primavera esta incrivel! Aqui vai minha lista dos melhores animes que estao passando agora. Comentem se concordam! A qualidade de animacao este ano superou todas as expectativas.",
    mediaUrl: "https://images.unsplash.com/photo-1578632767115-351597cf2477?w=600&h=400&fit=crop",
    likesCount: 234, commentsCount: 45, isLiked: true, isPinned: true, isFeatured: true, tags: ["anime", "temporada", "ranking"],
    createdAt: "2026-03-25T14:30:00Z", type: "blog",
  },
  {
    id: "p2", communityId: "c3", communityName: "Gaming Amino", communityIcon: communities[2].icon,
    author: { id: "u3", nickname: "ProGamer99", avatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop", level: 28, role: "Curator" },
    title: "Guia Completo: Como subir de rank em Valorant",
    content: "Depois de muito estudo e pratica, compilei as melhores dicas para subir de rank. Vamos la! Desde aim training ate game sense, tudo que voce precisa saber.",
    mediaUrl: "https://images.unsplash.com/photo-1542751371-adc38448a05e?w=600&h=400&fit=crop",
    likesCount: 189, commentsCount: 67, isLiked: false, isPinned: false, isFeatured: true, tags: ["valorant", "guia", "ranked"],
    createdAt: "2026-03-25T10:15:00Z", type: "blog",
  },
  {
    id: "p3", communityId: "c1", communityName: "Anime Amino", communityIcon: communities[0].icon,
    author: { id: "u4", nickname: "ArtistaSoul", avatar: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop", level: 19, role: "Member" },
    title: "Minha nova ilustracao digital - Feedback?",
    content: "Passei 3 semanas trabalhando nessa ilustracao. O que voces acham? Aceito criticas construtivas! Usei Procreate no iPad.",
    mediaUrl: "https://images.unsplash.com/photo-1579783902614-a3fb3927b6a5?w=600&h=400&fit=crop",
    likesCount: 456, commentsCount: 89, isLiked: true, isPinned: false, isFeatured: true, tags: ["arte", "digital", "ilustracao"],
    createdAt: "2026-03-24T18:00:00Z", type: "blog",
  },
  {
    id: "p4", communityId: "c2", communityName: "K-Pop Amino", communityIcon: communities[1].icon,
    author: { id: "u5", nickname: "MelodyKing", avatar: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop", level: 15, role: "Member" },
    title: "Enquete: Melhor album de 2026 ate agora?",
    content: "Qual album lancado em 2026 e o seu favorito? Vote na enquete!",
    likesCount: 312, commentsCount: 234, isLiked: false, isPinned: false, isFeatured: false, tags: ["musica", "enquete", "2026"],
    createdAt: "2026-03-24T12:00:00Z", type: "poll",
    pollOptions: [
      { id: "po1", text: "BLACKPINK - Born Pink II", votes: 145, percentage: 46.5, isVoted: false },
      { id: "po2", text: "BTS - Beyond", votes: 98, percentage: 31.4, isVoted: false },
      { id: "po3", text: "Stray Kids - MAXIDENT 2", votes: 45, percentage: 14.4, isVoted: false },
      { id: "po4", text: "Other", votes: 24, percentage: 7.7, isVoted: false },
    ],
  },
  {
    id: "p5", communityId: "c1", communityName: "Anime Amino", communityIcon: communities[0].icon,
    author: { id: "u6", nickname: "SakuraFan", avatar: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100&h=100&fit=crop", level: 21, role: "Curator" },
    title: "Fan Art: Personagem original estilo Ghibli",
    content: "Criei esse personagem inspirado no estilo do Studio Ghibli. Espero que gostem! Levei cerca de 20 horas para finalizar.",
    mediaUrl: "https://images.unsplash.com/photo-1618336753974-aae8e04506aa?w=600&h=400&fit=crop",
    likesCount: 567, commentsCount: 123, isLiked: true, isPinned: false, isFeatured: true, tags: ["fanart", "ghibli", "original"],
    createdAt: "2026-03-23T20:00:00Z", type: "blog",
  },
  {
    id: "p6", communityId: "c3", communityName: "Gaming Amino", communityIcon: communities[2].icon,
    author: { id: "u7", nickname: "RetroGamer", avatar: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop", level: 24, role: "Member" },
    title: "Quiz: Voce conhece os classicos do SNES?",
    content: "Teste seus conhecimentos sobre os jogos classicos do Super Nintendo! 20 perguntas para verdadeiros gamers.",
    likesCount: 178, commentsCount: 56, isLiked: false, isPinned: false, isFeatured: false, tags: ["quiz", "retro", "snes"],
    createdAt: "2026-03-23T15:00:00Z", type: "quiz",
  },
  {
    id: "p7", communityId: "c5", communityName: "Horror Amino", communityIcon: communities[4].icon,
    author: { id: "u8", nickname: "DarkWriter", avatar: "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=100&h=100&fit=crop", level: 18, role: "Member" },
    title: "Creepypasta Original: O Corredor Sem Fim",
    content: "Era uma noite chuvosa quando decidi explorar o antigo hospital abandonado na periferia da cidade. O que encontrei la dentro mudou minha vida para sempre...",
    mediaUrl: "https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=600&h=400&fit=crop",
    likesCount: 89, commentsCount: 34, isLiked: false, isPinned: false, isFeatured: true, tags: ["creepypasta", "original", "horror"],
    createdAt: "2026-03-22T22:00:00Z", type: "blog",
  },
];

const chatRooms: ChatRoom[] = [
  { id: "ch1", communityId: "c1", communityIcon: communities[0].icon, name: "Anime General Chat", lastMessage: "Anyone watching the new season?", lastMessageBy: "OtakuMaster", lastMessageTime: "2 min", membersCount: 1245, isGroupChat: true, unreadCount: 3 },
  { id: "ch2", communityId: "c3", communityIcon: communities[2].icon, name: "Gaming Lounge", lastMessage: "GG everyone! That was intense", lastMessageBy: "ProGamer99", lastMessageTime: "5 min", membersCount: 890, isGroupChat: true, unreadCount: 0 },
  { id: "ch3", communityId: "c2", communityIcon: communities[1].icon, name: "K-Pop Fan Chat", lastMessage: "Did you see the new MV?!", lastMessageBy: "MelodyKing", lastMessageTime: "15 min", membersCount: 2100, isGroupChat: true, unreadCount: 12 },
  { id: "ch4", communityId: "c4", communityIcon: communities[3].icon, name: "Art Critique Room", lastMessage: "Love the color palette!", lastMessageBy: "ArtistaSoul", lastMessageTime: "1 hour", membersCount: 340, isGroupChat: true, unreadCount: 0 },
  { id: "ch5", communityId: "c5", communityIcon: communities[4].icon, name: "Horror Stories", lastMessage: "That ending was terrifying!", lastMessageBy: "DarkWriter", lastMessageTime: "30 min", membersCount: 567, isGroupChat: true, unreadCount: 7 },
  { id: "ch6", communityId: "c1", communityIcon: communities[0].icon, name: "Meggie3524", cover: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&h=100&fit=crop", lastMessage: "I want to know how to appeal...", lastMessageBy: "Meggie3524", lastMessageTime: "2 min", membersCount: 2, isGroupChat: false, unreadCount: 1 },
  { id: "ch7", communityId: "c3", communityIcon: communities[2].icon, name: "De Boeurs", cover: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop", lastMessage: "Want to play ranked later?", lastMessageBy: "De Boeurs", lastMessageTime: "1 hour", membersCount: 2, isGroupChat: false, unreadCount: 0 },
];

const chatMessages: ChatMessage[] = [
  { id: "m0", userId: "system", nickname: "", avatar: "", content: "Welcome to Anime General Chat! Be respectful and have fun.", time: "18:00", isSystem: true },
  { id: "m1", userId: "u2", nickname: "OtakuMaster", avatar: "https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=100&h=100&fit=crop", content: "Hey everyone! Who's watching the new anime season? The lineup is insane this time!", time: "18:50", badges: ["Lv.32"], role: "Leader" },
  { id: "m2", userId: "u6", nickname: "SakuraFan", avatar: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100&h=100&fit=crop", content: "Me! The new isekai is amazing! The world-building is next level.", time: "18:51", role: "Curator" },
  { id: "m3", userId: "u3", nickname: "ProGamer99", avatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop", content: "I prefer the action ones this season. The animation quality is insane! MAPPA really outdid themselves.", time: "18:52", reactions: [{ emoji: "🔥", count: 5 }, { emoji: "👍", count: 3 }, { emoji: "❤️", count: 2 }] },
  { id: "m4", userId: "u4", nickname: "ArtistaSoul", avatar: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop", content: "The art style in the new Studio MAPPA show is incredible. I've been studying their techniques for my own work.", time: "18:53" },
  { id: "m5", userId: "u1", nickname: "NexusUser", avatar: currentUser.avatar, content: "Totally agree! What's everyone's top 3 this season?", time: "18:55" },
  { id: "m6", userId: "u5", nickname: "MelodyKing", avatar: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop", content: "Don't forget the OSTs! The music this season is fire 🔥🎵", time: "18:56", reactions: [{ emoji: "🎵", count: 4 }] },
  { id: "m7", userId: "u8", nickname: "DarkWriter", avatar: "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=100&h=100&fit=crop", content: "Anyone else watching that dark fantasy one? The horror elements are chef's kiss 👨‍🍳", time: "18:58" },
];

const comments: Comment[] = [
  { id: "cm1", author: { id: "u3", nickname: "ProGamer99", avatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop", level: 28, role: "Curator" }, content: "Great list! I would add Solo Leveling Season 2 though. The animation upgrade is massive.", likesCount: 23, isLiked: false, createdAt: "2026-03-25T15:00:00Z" },
  { id: "cm2", author: { id: "u4", nickname: "ArtistaSoul", avatar: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop", level: 19, role: "Member" }, content: "The animation quality this season is insane! MAPPA outdid themselves once again.", likesCount: 15, isLiked: true, createdAt: "2026-03-25T15:30:00Z" },
  { id: "cm3", author: { id: "u6", nickname: "SakuraFan", avatar: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100&h=100&fit=crop", level: 21, role: "Curator" }, content: "Where's the romance genre? There are some great ones this season too! Don't sleep on them.", likesCount: 8, isLiked: false, createdAt: "2026-03-25T16:00:00Z" },
  { id: "cm4", author: { id: "u7", nickname: "RetroGamer", avatar: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop", level: 24, role: "Member" }, content: "Solid picks! I'd swap #7 and #5 personally but overall great taste.", likesCount: 5, isLiked: false, createdAt: "2026-03-25T17:00:00Z" },
];

const wikiEntries: WikiEntry[] = [
  { id: "w1", title: "Getting Started Guide", category: "General", author: "OtakuMaster", viewCount: 12450, cover: "https://images.unsplash.com/photo-1578632767115-351597cf2477?w=300&h=200&fit=crop" },
  { id: "w2", title: "Community Rules & Guidelines", category: "General", author: "Admin", viewCount: 8920, cover: undefined },
  { id: "w3", title: "Anime Tier List 2026", category: "Rankings", author: "SakuraFan", viewCount: 5670, cover: "https://images.unsplash.com/photo-1618336753974-aae8e04506aa?w=300&h=200&fit=crop" },
  { id: "w4", title: "Character Encyclopedia", category: "Database", author: "OtakuMaster", viewCount: 15230, cover: "https://images.unsplash.com/photo-1579783902614-a3fb3927b6a5?w=300&h=200&fit=crop" },
  { id: "w5", title: "FAQ - Frequently Asked Questions", category: "General", author: "Admin", viewCount: 3450 },
  { id: "w6", title: "Art Submission Guidelines", category: "Art", author: "ArtistaSoul", viewCount: 2340 },
];

const communityMembers: CommunityMember[] = [
  { id: "u2", nickname: "OtakuMaster", avatar: "https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=100&h=100&fit=crop", level: 32, role: "Leader", isOnline: true, reputation: 125600, lastSeen: "now" },
  { id: "u6", nickname: "SakuraFan", avatar: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100&h=100&fit=crop", level: 21, role: "Curator", isOnline: true, reputation: 67800, lastSeen: "now" },
  { id: "u3", nickname: "ProGamer99", avatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop", level: 28, role: "Curator", isOnline: true, reputation: 89400, lastSeen: "now" },
  { id: "u4", nickname: "ArtistaSoul", avatar: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop", level: 19, role: "Member", isOnline: true, reputation: 34200, lastSeen: "now" },
  { id: "u5", nickname: "MelodyKing", avatar: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop", level: 15, role: "Member", isOnline: false, reputation: 21300, lastSeen: "2h ago" },
  { id: "u7", nickname: "RetroGamer", avatar: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop", level: 24, role: "Member", isOnline: false, reputation: 45600, lastSeen: "5h ago" },
  { id: "u8", nickname: "DarkWriter", avatar: "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=100&h=100&fit=crop", level: 18, role: "Member", isOnline: true, reputation: 28900, lastSeen: "now" },
  { id: "u9", nickname: "CosplayQueen", avatar: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&h=100&fit=crop", level: 26, role: "Member", isOnline: false, reputation: 56700, lastSeen: "1d ago" },
];

// ============ CONTEXT ============
interface AppContextType {
  currentUser: User;
  communities: Community[];
  posts: Post[];
  chatRooms: ChatRoom[];
  chatMessages: ChatMessage[];
  comments: Comment[];
  wikiEntries: WikiEntry[];
  communityMembers: CommunityMember[];
  activeTab: string;
  setActiveTab: (tab: string) => void;
  currentScreen: string;
  setCurrentScreen: (screen: string) => void;
  selectedCommunity: Community | null;
  setSelectedCommunity: (c: Community | null) => void;
  selectedPost: Post | null;
  setSelectedPost: (p: Post | null) => void;
  selectedChat: ChatRoom | null;
  setSelectedChat: (c: ChatRoom | null) => void;
  toggleLike: (postId: string) => void;
  toggleJoinCommunity: (communityId: string) => void;
  checkIn: (communityId: string) => void;
  sendMessage: (content: string) => void;
  votePoll: (postId: string, optionId: string) => void;
  screenHistory: string[];
  goBack: () => void;
  navigateTo: (screen: string) => void;
}

const AppContext = createContext<AppContextType | null>(null);

export function AppProvider({ children }: { children: ReactNode }) {
  const [user] = useState(currentUser);
  const [comms, setComms] = useState(communities);
  const [allPosts, setAllPosts] = useState(posts);
  const [msgs, setMsgs] = useState(chatMessages);
  const [activeTab, setActiveTab] = useState("discover");
  const [currentScreen, setCurrentScreen] = useState("main");
  const [selectedCommunity, setSelectedCommunity] = useState<Community | null>(null);
  const [selectedPost, setSelectedPost] = useState<Post | null>(null);
  const [selectedChat, setSelectedChat] = useState<ChatRoom | null>(null);
  const [screenHistory, setScreenHistory] = useState<string[]>(["main"]);

  const navigateTo = useCallback((screen: string) => {
    setScreenHistory(prev => [...prev, screen]);
    setCurrentScreen(screen);
  }, []);

  const goBack = useCallback(() => {
    setScreenHistory(prev => {
      if (prev.length <= 1) return prev;
      const newHistory = prev.slice(0, -1);
      setCurrentScreen(newHistory[newHistory.length - 1]);
      return newHistory;
    });
  }, []);

  const toggleLike = useCallback((postId: string) => {
    setAllPosts(prev => prev.map(p => p.id === postId ? { ...p, isLiked: !p.isLiked, likesCount: p.isLiked ? p.likesCount - 1 : p.likesCount + 1 } : p));
  }, []);

  const toggleJoinCommunity = useCallback((communityId: string) => {
    setComms(prev => prev.map(c => c.id === communityId ? { ...c, isJoined: !c.isJoined, members: c.isJoined ? c.members - 1 : c.members + 1 } : c));
  }, []);

  const checkIn = useCallback((communityId: string) => {
    setComms(prev => prev.map(c => c.id === communityId ? { ...c, checkedIn: true } : c));
  }, []);

  const sendMessage = useCallback((content: string) => {
    const newMsg: ChatMessage = {
      id: `m${Date.now()}`, userId: user.id, nickname: user.nickname,
      avatar: user.avatar, content, time: new Date().toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" }),
    };
    setMsgs(prev => [...prev, newMsg]);
  }, [user]);

  const votePoll = useCallback((postId: string, optionId: string) => {
    setAllPosts(prev => prev.map(p => {
      if (p.id !== postId || !p.pollOptions) return p;
      const totalVotes = p.pollOptions.reduce((sum, o) => sum + o.votes, 0) + 1;
      return {
        ...p,
        pollOptions: p.pollOptions.map(o => ({
          ...o,
          votes: o.id === optionId ? o.votes + 1 : o.votes,
          isVoted: o.id === optionId ? true : o.isVoted,
          percentage: Math.round(((o.id === optionId ? o.votes + 1 : o.votes) / totalVotes) * 1000) / 10,
        })),
      };
    }));
  }, []);

  return (
    <AppContext.Provider value={{
      currentUser: user, communities: comms, posts: allPosts, chatRooms, chatMessages: msgs, comments,
      wikiEntries, communityMembers,
      activeTab, setActiveTab, currentScreen, setCurrentScreen, selectedCommunity, setSelectedCommunity,
      selectedPost, setSelectedPost, selectedChat, setSelectedChat, toggleLike, toggleJoinCommunity,
      checkIn, sendMessage, votePoll, screenHistory, goBack, navigateTo,
    }}>
      {children}
    </AppContext.Provider>
  );
}

export function useApp() {
  const ctx = useContext(AppContext);
  if (!ctx) throw new Error("useApp must be used within AppProvider");
  return ctx;
}
