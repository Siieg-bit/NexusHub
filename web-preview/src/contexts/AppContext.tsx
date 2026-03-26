import React, { createContext, useContext, useState, useCallback, ReactNode } from "react";

// ============ TYPES ============
export interface User {
  id: string;
  nickname: string;
  avatar: string;
  level: number;
  levelTitle: string;
  reputation: number;
  dailyRepEarned: number; // max 100 per day
  totalRepAllTime: number;
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

// ============ LEVEL SYSTEM ============
// Level is calculated from total reputation earned across all time
// Max 100 reputation per day (XP cap)
export const LEVEL_THRESHOLDS = [
  { level: 1, minRep: 0, title: "Newcomer" },
  { level: 2, minRep: 50, title: "Beginner" },
  { level: 3, minRep: 150, title: "Apprentice" },
  { level: 4, minRep: 350, title: "Regular" },
  { level: 5, minRep: 700, title: "Active" },
  { level: 6, minRep: 1200, title: "Contributor" },
  { level: 7, minRep: 2000, title: "Enthusiast" },
  { level: 8, minRep: 3200, title: "Dedicated" },
  { level: 9, minRep: 5000, title: "Veteran" },
  { level: 10, minRep: 7500, title: "Expert" },
  { level: 11, minRep: 11000, title: "Master" },
  { level: 12, minRep: 15500, title: "Elite" },
  { level: 13, minRep: 21000, title: "Champion" },
  { level: 14, minRep: 28000, title: "Hero" },
  { level: 15, minRep: 37000, title: "Legend" },
  { level: 16, minRep: 48000, title: "Mythic" },
  { level: 17, minRep: 62000, title: "Transcendent" },
  { level: 18, minRep: 80000, title: "Immortal" },
  { level: 19, minRep: 105000, title: "Ascended" },
  { level: 20, minRep: 140000, title: "Godlike" },
];

export const MAX_DAILY_REP = 100;

export function getLevelFromRep(totalRep: number): { level: number; title: string; currentRep: number; nextLevelRep: number; progress: number } {
  let currentLevel = LEVEL_THRESHOLDS[0];
  let nextLevel = LEVEL_THRESHOLDS[1];
  for (let i = LEVEL_THRESHOLDS.length - 1; i >= 0; i--) {
    if (totalRep >= LEVEL_THRESHOLDS[i].minRep) {
      currentLevel = LEVEL_THRESHOLDS[i];
      nextLevel = LEVEL_THRESHOLDS[i + 1] || { level: currentLevel.level + 1, minRep: currentLevel.minRep * 1.5, title: "Max" };
      break;
    }
  }
  const repInLevel = totalRep - currentLevel.minRep;
  const repNeeded = nextLevel.minRep - currentLevel.minRep;
  const progress = Math.min(repInLevel / repNeeded, 1);
  return { level: currentLevel.level, title: currentLevel.title, currentRep: repInLevel, nextLevelRep: repNeeded, progress };
}

export interface Badge {
  label: string;
  color: string;
}

/** Perfil do usuário DENTRO de uma comunidade específica - completamente independente */
export interface CommunityProfile {
  communityId: string;
  nickname: string;
  avatar: string;
  bio: string;
  backgroundImage: string;
  level: number;
  levelTitle: string;
  reputation: number;
  following: number;
  followers: number;
  badges: Badge[];
  streakDays: number;
  checkedIn: boolean;
  joinedAt: string;
  postsCount: number;
  role: "Leader" | "Curator" | "Member";
}

export interface Category {
  id: string;
  name: string;
  icon: string;
  color: string;
  description: string;
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
  categoryId: string;
  aminoId: string;
  guidelines: string[];
  language: string;
  createdAt: string;
  tags: string[];
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

// ============ CATEGORIES ============
const categories: Category[] = [
  { id: "anime", name: "Anime & Manga", icon: "🎌", color: "#E91E63", description: "Anime, manga, light novels and Japanese culture" },
  { id: "gaming", name: "Gaming", icon: "🎮", color: "#4CAF50", description: "Video games, esports, game development" },
  { id: "art", name: "Art & Design", icon: "🎨", color: "#FF9800", description: "Digital art, traditional art, graphic design" },
  { id: "music", name: "Music", icon: "🎵", color: "#9C27B0", description: "K-Pop, J-Pop, Rock, Hip-Hop and all genres" },
  { id: "movies", name: "Movies & TV", icon: "🎬", color: "#F44336", description: "Movies, TV shows, streaming, reviews" },
  { id: "books", name: "Books & Writing", icon: "📚", color: "#795548", description: "Books, fanfiction, creative writing" },
  { id: "cosplay", name: "Cosplay", icon: "🎭", color: "#E040FB", description: "Cosplay creation, conventions, tutorials" },
  { id: "science", name: "Science & Tech", icon: "🔬", color: "#00BCD4", description: "Science, technology, programming, space" },
  { id: "sports", name: "Sports & Fitness", icon: "⚽", color: "#8BC34A", description: "Sports, fitness, martial arts, outdoor" },
  { id: "food", name: "Food & Cooking", icon: "🍜", color: "#FF5722", description: "Recipes, restaurants, food culture" },
  { id: "pets", name: "Pets & Animals", icon: "🐾", color: "#607D8B", description: "Cats, dogs, exotic pets, wildlife" },
  { id: "fashion", name: "Fashion & Beauty", icon: "👗", color: "#EC407A", description: "Fashion trends, makeup, skincare" },
];

// ============ COMMUNITIES (organized by category, scalable) ============
const communities: Community[] = [
  // Anime & Manga
  { id: "c1", name: "Anime Amino", icon: "https://images.unsplash.com/photo-1578632767115-351597cf2477?w=200&h=200&fit=crop", cover: "https://images.unsplash.com/photo-1578632767115-351597cf2477?w=600&h=300&fit=crop", members: 3253749, onlineNow: 12430, description: "The biggest anime community! Share your love for anime and manga.", isJoined: true, checkedIn: false, categoryId: "anime", aminoId: "anime", guidelines: ["Be respectful to all members", "No NSFW content", "Credit artists", "No spam or self-promotion", "Use appropriate tags"], language: "en", createdAt: "2015-07-15", tags: ["Anime", "Manga", "Otaku", "Japanese"] },
  { id: "c9", name: "Naruto Amino", icon: "https://images.unsplash.com/photo-1601850494422-3cf14624b0b3?w=200&h=200&fit=crop", cover: "https://images.unsplash.com/photo-1601850494422-3cf14624b0b3?w=600&h=300&fit=crop", members: 1456000, onlineNow: 5670, description: "For all Naruto and Boruto fans!", isJoined: true, checkedIn: false, categoryId: "anime", aminoId: "naruto", guidelines: ["No spoilers without tags", "Respect all characters"], language: "en", createdAt: "2016-03-20", tags: ["Naruto", "Boruto", "Ninja", "Shonen"] },
  { id: "c10", name: "Dragon Ball Amino", icon: "https://images.unsplash.com/photo-1614583225154-5fcdda07019e?w=200&h=200&fit=crop", cover: "https://images.unsplash.com/photo-1614583225154-5fcdda07019e?w=600&h=300&fit=crop", members: 987000, onlineNow: 3200, description: "Kamehameha! The Dragon Ball community.", isJoined: false, checkedIn: false, categoryId: "anime", aminoId: "dragonball", guidelines: ["Power scaling debates are welcome", "Be respectful"], language: "en", createdAt: "2016-01-10", tags: ["Dragon Ball", "Goku", "Saiyan", "Shonen"] },
  { id: "c11", name: "One Piece Amino", icon: "https://images.unsplash.com/photo-1618336753974-aae8e04506aa?w=200&h=200&fit=crop", cover: "https://images.unsplash.com/photo-1618336753974-aae8e04506aa?w=600&h=300&fit=crop", members: 1890000, onlineNow: 7800, description: "Set sail with the Straw Hat crew!", isJoined: false, checkedIn: false, categoryId: "anime", aminoId: "onepiece", guidelines: ["Spoiler warnings required", "No piracy links"], language: "en", createdAt: "2015-12-05", tags: ["One Piece", "Luffy", "Pirates", "Manga"] },

  // Gaming
  { id: "c3", name: "Gaming Amino", icon: "https://images.unsplash.com/photo-1542751371-adc38448a05e?w=200&h=200&fit=crop", cover: "https://images.unsplash.com/photo-1542751371-adc38448a05e?w=600&h=300&fit=crop", members: 2134500, onlineNow: 8567, description: "The ultimate gaming community. PC, Console, Mobile.", isJoined: true, checkedIn: false, categoryId: "gaming", aminoId: "gaming", guidelines: ["No cheating discussions", "Be a good sport", "No piracy links"], language: "en", createdAt: "2015-08-20", tags: ["Gaming", "PC", "Console", "Esports"] },
  { id: "c6", name: "Pokemon Amino", icon: "https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?w=200&h=200&fit=crop", cover: "https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?w=600&h=300&fit=crop", members: 1512300, onlineNow: 4450, description: "Gotta catch 'em all! The Pokemon community.", isJoined: false, checkedIn: false, categoryId: "gaming", aminoId: "pokemon", guidelines: ["No ROM links", "Be kind to new trainers"], language: "en", createdAt: "2016-02-14", tags: ["Pokemon", "Nintendo", "RPG", "Catch"] },
  { id: "c12", name: "Minecraft Amino", icon: "https://images.unsplash.com/photo-1553481187-be93c21490a9?w=200&h=200&fit=crop", cover: "https://images.unsplash.com/photo-1553481187-be93c21490a9?w=600&h=300&fit=crop", members: 876000, onlineNow: 2340, description: "Build, explore, survive! Minecraft community.", isJoined: false, checkedIn: false, categoryId: "gaming", aminoId: "minecraft", guidelines: ["Share your builds", "No griefing promotion"], language: "en", createdAt: "2016-06-01", tags: ["Minecraft", "Sandbox", "Building", "Survival"] },

  // Music
  { id: "c2", name: "K-Pop Amino", icon: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=200&h=200&fit=crop", cover: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&h=300&fit=crop", members: 2185430, onlineNow: 8920, description: "For all K-Pop fans! BTS, BLACKPINK, Stray Kids and more.", isJoined: true, checkedIn: true, categoryId: "music", aminoId: "k-pop", guidelines: ["No fanwars", "Respect all groups", "Credit fansite photos"], language: "en", createdAt: "2015-09-10", tags: ["K-Pop", "BTS", "BLACKPINK", "Stray Kids"] },
  { id: "c13", name: "J-Rock Amino", icon: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=200&h=200&fit=crop", cover: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&h=300&fit=crop", members: 234000, onlineNow: 560, description: "Japanese Rock and Visual Kei community.", isJoined: false, checkedIn: false, categoryId: "music", aminoId: "jrock", guidelines: ["Share music respectfully", "Credit artists"], language: "en", createdAt: "2017-01-15", tags: ["J-Rock", "Visual Kei", "Japanese", "Rock"] },

  // Art & Design
  { id: "c4", name: "Art Amino", icon: "https://images.unsplash.com/photo-1513364776144-60967b0f800f?w=200&h=200&fit=crop", cover: "https://images.unsplash.com/photo-1513364776144-60967b0f800f?w=600&h=300&fit=crop", members: 1498200, onlineNow: 4234, description: "Share your art, get feedback, and improve your skills!", isJoined: false, checkedIn: false, categoryId: "art", aminoId: "art", guidelines: ["Credit original artists", "No art theft", "Constructive criticism only"], language: "en", createdAt: "2015-10-01", tags: ["Art", "Drawing", "Painting", "Creative"] },
  { id: "c14", name: "Digital Art Amino", icon: "https://images.unsplash.com/photo-1579783902614-a3fb3927b6a5?w=200&h=200&fit=crop", cover: "https://images.unsplash.com/photo-1579783902614-a3fb3927b6a5?w=600&h=300&fit=crop", members: 567000, onlineNow: 1230, description: "Procreate, Photoshop, Clip Studio - all digital art!", isJoined: false, checkedIn: false, categoryId: "art", aminoId: "digitalart", guidelines: ["Share your process", "No AI art without disclosure"], language: "en", createdAt: "2017-04-20", tags: ["Digital Art", "Procreate", "Photoshop", "Illustration"] },

  // Movies & TV
  { id: "c5", name: "Horror Amino", icon: "https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=200&h=200&fit=crop", cover: "https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=600&h=300&fit=crop", members: 867800, onlineNow: 2156, description: "For horror fans! Movies, books, games, creepypasta.", isJoined: true, checkedIn: false, categoryId: "movies", aminoId: "horror", guidelines: ["Use trigger warnings", "No real gore", "Spoiler tags required"], language: "en", createdAt: "2016-10-31", tags: ["Horror", "Movies", "Creepypasta", "Scary"] },
  { id: "c15", name: "Marvel Amino", icon: "https://images.unsplash.com/photo-1612036782180-6f0b6cd846fe?w=200&h=200&fit=crop", cover: "https://images.unsplash.com/photo-1612036782180-6f0b6cd846fe?w=600&h=300&fit=crop", members: 1234000, onlineNow: 3450, description: "Marvel Comics, MCU, and everything Marvel!", isJoined: false, checkedIn: false, categoryId: "movies", aminoId: "marvel", guidelines: ["Spoiler warnings for new releases", "Respect all opinions"], language: "en", createdAt: "2016-05-15", tags: ["Marvel", "MCU", "Comics", "Superheroes"] },

  // Cosplay
  { id: "c7", name: "Cosplay Amino", icon: "https://images.unsplash.com/photo-1608889825103-eb5ed706fc64?w=200&h=200&fit=crop", cover: "https://images.unsplash.com/photo-1608889825103-eb5ed706fc64?w=600&h=300&fit=crop", members: 754200, onlineNow: 890, description: "Show off your cosplays and get tips!", isJoined: false, checkedIn: false, categoryId: "cosplay", aminoId: "cosplay", guidelines: ["Credit cosplayers", "No body shaming", "Constructive feedback"], language: "en", createdAt: "2016-07-20", tags: ["Cosplay", "Convention", "Costume", "DIY"] },

  // Books & Writing
  { id: "c8", name: "Books Amino", icon: "https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=200&h=200&fit=crop", cover: "https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=600&h=300&fit=crop", members: 543100, onlineNow: 670, description: "For book lovers! Reviews, recommendations and discussions.", isJoined: false, checkedIn: false, categoryId: "books", aminoId: "books", guidelines: ["Use spoiler warnings", "Respect all genres"], language: "en", createdAt: "2016-04-23", tags: ["Books", "Reading", "Fanfiction", "Writing"] },
];

// ============ COMMUNITY PROFILES (per-community user profiles) ============
const communityProfiles: CommunityProfile[] = [
  { communityId: "c1", nickname: "AnimeNexus", avatar: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&h=200&fit=crop", bio: "Anime enthusiast since 2010! My top 3: Attack on Titan, One Piece, Demon Slayer.", backgroundImage: "https://images.unsplash.com/photo-1578632767115-351597cf2477?w=600&h=400&fit=crop", level: 16, levelTitle: "Otaku Master", reputation: 48914, following: 24, followers: 30190, badges: [{ label: "Leader", color: "#2dbe60" }, { label: "OG Member", color: "#FF9800" }], streakDays: 318, checkedIn: false, joinedAt: "Jul 3, 2018", postsCount: 156, role: "Leader" },
  { communityId: "c2", nickname: "MelodyLover", avatar: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&h=200&fit=crop", bio: "BTS ARMY forever! Also love Stray Kids and ATEEZ.", backgroundImage: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&h=400&fit=crop", level: 12, levelTitle: "Rising Star", reputation: 12340, following: 45, followers: 8900, badges: [{ label: "Curator", color: "#E040FB" }], streakDays: 45, checkedIn: true, joinedAt: "Jan 15, 2020", postsCount: 67, role: "Curator" },
  { communityId: "c3", nickname: "ProGamerX", avatar: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&h=200&fit=crop", bio: "Competitive Valorant player. Also love RPGs and retro games.", backgroundImage: "https://images.unsplash.com/photo-1542751371-adc38448a05e?w=600&h=400&fit=crop", level: 22, levelTitle: "Elite Gamer", reputation: 34500, following: 18, followers: 15600, badges: [{ label: "Curator", color: "#E040FB" }, { label: "Pro Player", color: "#2196F3" }], streakDays: 120, checkedIn: false, joinedAt: "Mar 8, 2019", postsCount: 89, role: "Curator" },
  { communityId: "c5", nickname: "DarkSoul", avatar: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&h=200&fit=crop", bio: "Horror movie collector. 500+ movies watched.", backgroundImage: "https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=600&h=400&fit=crop", level: 8, levelTitle: "Night Owl", reputation: 5670, following: 12, followers: 2340, badges: [{ label: "Member", color: "#666" }], streakDays: 30, checkedIn: false, joinedAt: "Oct 31, 2021", postsCount: 23, role: "Member" },
  { communityId: "c9", nickname: "HokageNexus", avatar: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&h=200&fit=crop", bio: "Believe it! Naruto changed my life.", backgroundImage: "https://images.unsplash.com/photo-1601850494422-3cf14624b0b3?w=600&h=400&fit=crop", level: 14, levelTitle: "Chunin", reputation: 23400, following: 30, followers: 12000, badges: [{ label: "Member", color: "#666" }, { label: "Naruto Fan", color: "#FF9800" }], streakDays: 200, checkedIn: false, joinedAt: "Sep 1, 2019", postsCount: 45, role: "Member" },
];

// ============ POSTS ============
const posts: Post[] = [
  { id: "p1", communityId: "c1", communityName: "Anime Amino", communityIcon: communities[0].icon, author: { id: "u2", nickname: "OtakuMaster", avatar: "https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=100&h=100&fit=crop", level: 32, role: "Leader" }, title: "Top 10 Animes da Temporada - Primavera 2026", content: "Pessoal, a temporada de primavera esta incrivel! Aqui vai minha lista dos melhores animes que estao passando agora. Comentem se concordam!", mediaUrl: "https://images.unsplash.com/photo-1578632767115-351597cf2477?w=600&h=400&fit=crop", likesCount: 234, commentsCount: 45, isLiked: true, isPinned: true, isFeatured: true, tags: ["anime", "temporada", "ranking"], createdAt: "2026-03-25T14:30:00Z", type: "blog" },
  { id: "p2", communityId: "c3", communityName: "Gaming Amino", communityIcon: communities.find(c => c.id === "c3")!.icon, author: { id: "u3", nickname: "ProGamer99", avatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop", level: 28, role: "Curator" }, title: "Guia Completo: Como subir de rank em Valorant", content: "Depois de muito estudo e pratica, compilei as melhores dicas para subir de rank.", mediaUrl: "https://images.unsplash.com/photo-1542751371-adc38448a05e?w=600&h=400&fit=crop", likesCount: 189, commentsCount: 67, isLiked: false, isPinned: false, isFeatured: true, tags: ["valorant", "guia", "ranked"], createdAt: "2026-03-25T10:15:00Z", type: "blog" },
  { id: "p3", communityId: "c1", communityName: "Anime Amino", communityIcon: communities[0].icon, author: { id: "u4", nickname: "ArtistaSoul", avatar: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop", level: 19, role: "Member" }, title: "Minha nova ilustracao digital - Feedback?", content: "Passei 3 semanas trabalhando nessa ilustracao. O que voces acham?", mediaUrl: "https://images.unsplash.com/photo-1579783902614-a3fb3927b6a5?w=600&h=400&fit=crop", likesCount: 456, commentsCount: 89, isLiked: true, isPinned: false, isFeatured: true, tags: ["arte", "digital", "ilustracao"], createdAt: "2026-03-24T18:00:00Z", type: "blog" },
  { id: "p4", communityId: "c2", communityName: "K-Pop Amino", communityIcon: communities.find(c => c.id === "c2")!.icon, author: { id: "u5", nickname: "MelodyKing", avatar: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop", level: 15, role: "Member" }, title: "Enquete: Melhor album de 2026 ate agora?", content: "Qual album lancado em 2026 e o seu favorito? Vote na enquete!", likesCount: 312, commentsCount: 234, isLiked: false, isPinned: false, isFeatured: false, tags: ["musica", "enquete", "2026"], createdAt: "2026-03-24T12:00:00Z", type: "poll", pollOptions: [{ id: "po1", text: "BLACKPINK - Born Pink II", votes: 145, percentage: 46.5, isVoted: false }, { id: "po2", text: "BTS - Beyond", votes: 98, percentage: 31.4, isVoted: false }, { id: "po3", text: "Stray Kids - MAXIDENT 2", votes: 45, percentage: 14.4, isVoted: false }, { id: "po4", text: "Other", votes: 24, percentage: 7.7, isVoted: false }] },
  { id: "p5", communityId: "c1", communityName: "Anime Amino", communityIcon: communities[0].icon, author: { id: "u6", nickname: "SakuraFan", avatar: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100&h=100&fit=crop", level: 21, role: "Curator" }, title: "Fan Art: Personagem original estilo Ghibli", content: "Criei esse personagem inspirado no estilo do Studio Ghibli.", mediaUrl: "https://images.unsplash.com/photo-1618336753974-aae8e04506aa?w=600&h=400&fit=crop", likesCount: 567, commentsCount: 123, isLiked: true, isPinned: false, isFeatured: true, tags: ["fanart", "ghibli", "original"], createdAt: "2026-03-23T20:00:00Z", type: "blog" },
  { id: "p6", communityId: "c3", communityName: "Gaming Amino", communityIcon: communities.find(c => c.id === "c3")!.icon, author: { id: "u7", nickname: "RetroGamer", avatar: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop", level: 24, role: "Member" }, title: "Quiz: Voce conhece os classicos do SNES?", content: "Teste seus conhecimentos sobre os jogos classicos do Super Nintendo!", likesCount: 178, commentsCount: 56, isLiked: false, isPinned: false, isFeatured: false, tags: ["quiz", "retro", "snes"], createdAt: "2026-03-23T15:00:00Z", type: "quiz" },
  { id: "p7", communityId: "c5", communityName: "Horror Amino", communityIcon: communities.find(c => c.id === "c5")!.icon, author: { id: "u8", nickname: "DarkWriter", avatar: "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=100&h=100&fit=crop", level: 18, role: "Member" }, title: "Creepypasta Original: O Corredor Sem Fim", content: "Era uma noite chuvosa quando decidi explorar o antigo hospital abandonado...", mediaUrl: "https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=600&h=400&fit=crop", likesCount: 89, commentsCount: 34, isLiked: false, isPinned: false, isFeatured: true, tags: ["creepypasta", "original", "horror"], createdAt: "2026-03-22T22:00:00Z", type: "blog" },
];

// ============ CHAT ROOMS ============
const chatRooms: ChatRoom[] = [
  { id: "ch1", communityId: "c1", communityIcon: communities[0].icon, name: "Anime General Chat", lastMessage: "Anyone watching the new season?", lastMessageBy: "OtakuMaster", lastMessageTime: "2 min", membersCount: 1245, isGroupChat: true, unreadCount: 3 },
  { id: "ch2", communityId: "c3", communityIcon: communities.find(c => c.id === "c3")!.icon, name: "Gaming Lounge", lastMessage: "GG everyone! That was intense", lastMessageBy: "ProGamer99", lastMessageTime: "5 min", membersCount: 890, isGroupChat: true, unreadCount: 0 },
  { id: "ch3", communityId: "c2", communityIcon: communities.find(c => c.id === "c2")!.icon, name: "K-Pop Fan Chat", lastMessage: "Did you see the new MV?!", lastMessageBy: "MelodyKing", lastMessageTime: "15 min", membersCount: 2100, isGroupChat: true, unreadCount: 12 },
  { id: "ch4", communityId: "c4", communityIcon: communities.find(c => c.id === "c4")!.icon, name: "Art Critique Room", lastMessage: "Love the color palette!", lastMessageBy: "ArtistaSoul", lastMessageTime: "1 hour", membersCount: 340, isGroupChat: true, unreadCount: 0 },
  { id: "ch5", communityId: "c5", communityIcon: communities.find(c => c.id === "c5")!.icon, name: "Horror Stories", lastMessage: "That ending was terrifying!", lastMessageBy: "DarkWriter", lastMessageTime: "30 min", membersCount: 567, isGroupChat: true, unreadCount: 7 },
  { id: "ch6", communityId: "c1", communityIcon: communities[0].icon, name: "Meggie3524", cover: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&h=100&fit=crop", lastMessage: "I want to know how to appeal...", lastMessageBy: "Meggie3524", lastMessageTime: "2 min", membersCount: 2, isGroupChat: false, unreadCount: 1 },
  { id: "ch7", communityId: "c3", communityIcon: communities.find(c => c.id === "c3")!.icon, name: "De Boeurs", cover: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop", lastMessage: "Want to play ranked later?", lastMessageBy: "De Boeurs", lastMessageTime: "1 hour", membersCount: 2, isGroupChat: false, unreadCount: 0 },
  { id: "ch8", communityId: "c1", communityIcon: communities[0].icon, name: "Anime Theatre", lastMessage: "Streaming starts at 8pm!", lastMessageBy: "SakuraFan", lastMessageTime: "10 min", membersCount: 525, isGroupChat: true, unreadCount: 0 },
  { id: "ch9", communityId: "c9", communityIcon: communities.find(c => c.id === "c9")!.icon, name: "Naruto Discussions", lastMessage: "Boruto manga is getting better", lastMessageBy: "HokageFan", lastMessageTime: "20 min", membersCount: 780, isGroupChat: true, unreadCount: 5 },
];

const chatMessages: ChatMessage[] = [
  { id: "m0", userId: "system", nickname: "", avatar: "", content: "Welcome to Anime General Chat! Be respectful and have fun.", time: "18:00", isSystem: true },
  { id: "m1", userId: "u2", nickname: "OtakuMaster", avatar: "https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=100&h=100&fit=crop", content: "Hey everyone! Who's watching the new anime season?", time: "18:50", badges: ["Lv.32"], role: "Leader" },
  { id: "m2", userId: "u6", nickname: "SakuraFan", avatar: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100&h=100&fit=crop", content: "Me! The new isekai is amazing!", time: "18:51", role: "Curator" },
  { id: "m3", userId: "u3", nickname: "ProGamer99", avatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop", content: "I prefer the action ones. MAPPA really outdid themselves!", time: "18:52", reactions: [{ emoji: "🔥", count: 5 }, { emoji: "👍", count: 3 }] },
  { id: "m4", userId: "u4", nickname: "ArtistaSoul", avatar: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop", content: "The art style is incredible. I've been studying their techniques.", time: "18:53" },
  { id: "m5", userId: "u1", nickname: "NexusUser", avatar: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&h=200&fit=crop", content: "Totally agree! What's everyone's top 3 this season?", time: "18:55" },
  { id: "m6", userId: "u5", nickname: "MelodyKing", avatar: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop", content: "Don't forget the OSTs! The music this season is fire 🔥🎵", time: "18:56", reactions: [{ emoji: "🎵", count: 4 }] },
];

const comments: Comment[] = [
  { id: "cm1", author: { id: "u3", nickname: "ProGamer99", avatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop", level: 28, role: "Curator" }, content: "Great list! I would add Solo Leveling Season 2 though.", likesCount: 23, isLiked: false, createdAt: "2026-03-25T15:00:00Z" },
  { id: "cm2", author: { id: "u4", nickname: "ArtistaSoul", avatar: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop", level: 19, role: "Member" }, content: "The animation quality this season is insane!", likesCount: 15, isLiked: true, createdAt: "2026-03-25T15:30:00Z" },
  { id: "cm3", author: { id: "u6", nickname: "SakuraFan", avatar: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100&h=100&fit=crop", level: 21, role: "Curator" }, content: "Where's the romance genre? There are some great ones too!", likesCount: 8, isLiked: false, createdAt: "2026-03-25T16:00:00Z" },
  { id: "cm4", author: { id: "u7", nickname: "RetroGamer", avatar: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop", level: 24, role: "Member" }, content: "Solid picks! I'd swap #7 and #5 personally.", likesCount: 5, isLiked: false, createdAt: "2026-03-25T17:00:00Z" },
];

const wikiEntries: WikiEntry[] = [
  { id: "w1", title: "Getting Started Guide", category: "General", author: "OtakuMaster", viewCount: 12450, cover: "https://images.unsplash.com/photo-1578632767115-351597cf2477?w=300&h=200&fit=crop" },
  { id: "w2", title: "Community Rules & Guidelines", category: "General", author: "Admin", viewCount: 8920 },
  { id: "w3", title: "Anime Tier List 2026", category: "Rankings", author: "SakuraFan", viewCount: 5670, cover: "https://images.unsplash.com/photo-1618336753974-aae8e04506aa?w=300&h=200&fit=crop" },
  { id: "w4", title: "Character Encyclopedia", category: "Database", author: "OtakuMaster", viewCount: 15230, cover: "https://images.unsplash.com/photo-1579783902614-a3fb3927b6a5?w=300&h=200&fit=crop" },
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
  categories: Category[];
  communityProfiles: CommunityProfile[];
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
  getCommunityProfile: (communityId: string) => CommunityProfile | undefined;
  getCommunitiesByCategory: (categoryId: string) => Community[];
  searchCommunities: (query: string) => Community[];
  earnReputation: (amount: number) => void;
}

const AppContext = createContext<AppContextType | null>(null);

const currentUser: User = {
  id: "u1",
  nickname: "NexusUser",
  avatar: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&h=200&fit=crop",
  level: 16,
  levelTitle: "Mythic",
  reputation: 48914,
  dailyRepEarned: 45,
  totalRepAllTime: 48914,
  following: 24,
  followers: 30190,
  coins: 68,
  streakDays: 318,
  bio: "Welcome to my profile! I love anime, gaming and art. Always looking for new friends and communities to join!",
  memberSince: "Jul 3, 2018",
  badges: [
    { label: "Verified", color: "#E040FB" },
    { label: "OG Member", color: "#FF9800" },
  ],
  isOnline: true,
  backgroundImage: "https://images.unsplash.com/photo-1534796636912-3b95b3ab5986?w=600&h=400&fit=crop",
};

export function AppProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState(currentUser);
  const [comms, setComms] = useState(communities);
  const [profiles] = useState(communityProfiles);
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

  const getCommunityProfile = useCallback((communityId: string) => {
    return profiles.find(p => p.communityId === communityId);
  }, [profiles]);

  const getCommunitiesByCategory = useCallback((categoryId: string) => {
    return comms.filter(c => c.categoryId === categoryId);
  }, [comms]);

  const searchCommunities = useCallback((query: string) => {
    if (!query.trim()) return [];
    const q = query.toLowerCase();
    return comms.filter(c =>
      c.name.toLowerCase().includes(q) ||
      c.aminoId.toLowerCase().includes(q) ||
      c.description.toLowerCase().includes(q) ||
      c.tags.some(t => t.toLowerCase().includes(q)) ||
      c.categoryId.toLowerCase().includes(q)
    );
  }, [comms]);

  const earnReputation = useCallback((amount: number) => {
    setUser(prev => {
      const canEarn = Math.min(amount, MAX_DAILY_REP - prev.dailyRepEarned);
      if (canEarn <= 0) return prev;
      const newTotalRep = prev.totalRepAllTime + canEarn;
      const levelInfo = getLevelFromRep(newTotalRep);
      return {
        ...prev,
        reputation: prev.reputation + canEarn,
        dailyRepEarned: prev.dailyRepEarned + canEarn,
        totalRepAllTime: newTotalRep,
        level: levelInfo.level,
        levelTitle: levelInfo.title,
      };
    });
  }, []);

  return (
    <AppContext.Provider value={{
      currentUser: user, communities: comms, categories, communityProfiles: profiles,
      posts: allPosts, chatRooms, chatMessages: msgs, comments, wikiEntries, communityMembers,
      activeTab, setActiveTab, currentScreen, setCurrentScreen, selectedCommunity, setSelectedCommunity,
      selectedPost, setSelectedPost, selectedChat, setSelectedChat, toggleLike, toggleJoinCommunity,
      checkIn, sendMessage, votePoll, screenHistory, goBack, navigateTo, getCommunityProfile, getCommunitiesByCategory, searchCommunities, earnReputation,
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
