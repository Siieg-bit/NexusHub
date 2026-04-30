import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = "https://ylvzqqvcanzzswjkqeya.supabase.co";
// Usando a nova publishable key do Supabase (substitui a anon key legada)
const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_HYsYzaF8DuBgXpqJAICJ1Q_b73GLUeb";
export const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
  },
});

// supabaseAdmin usa a mesma publishable key — as políticas RLS das tabelas
// admin permitem acesso total para a role anon (painel admin público).
export const supabaseAdmin = supabase;

// ─── Hierarquia de Team Members ───────────────────────────────────────────────
export type TeamRole =
  | "founder"
  | "co_founder"
  | "team_admin"
  | "trust_safety"
  | "team_mod"
  | "support"
  | "community_manager"
  | "bug_bounty"
  | null;

export const TEAM_ROLE_CONFIG: Record<
  NonNullable<TeamRole>,
  { label: string; rank: number; color: string; borderColor: string; description: string }
> = {
  founder:           { label: "Founder",           rank: 100, color: "#FFFFFF", borderColor: "#FFFFFF", description: "Fundador da plataforma. Acesso total e irrestrito." },
  co_founder:        { label: "Co-Founder",        rank: 90,  color: "#FFD700", borderColor: "#FFD700", description: "Co-Fundador. Pode gerenciar Team Admins e abaixo." },
  team_admin:        { label: "Team Admin",        rank: 80,  color: "#FF4444", borderColor: "#FF4444", description: "Administrador. Gerencia moderadores e equipe de suporte." },
  trust_safety:      { label: "Trust & Safety",    rank: 75,  color: "#3B82F6", borderColor: "#3B82F6", description: "Segurança e confiança. Moderação de conteúdo sensível." },
  team_mod:          { label: "Team Mod",          rank: 70,  color: "#60A5FA", borderColor: "#60A5FA", description: "Moderador global. Pode moderar qualquer comunidade." },
  support:           { label: "Support",           rank: 65,  color: "#22C55E", borderColor: "#22C55E", description: "Suporte ao usuário. Sem poder de moderação." },
  community_manager: { label: "Community Manager", rank: 60,  color: "#A855F7", borderColor: "#A855F7", description: "Gerencia comunidades e conteúdo da plataforma." },
  bug_bounty:        { label: "Bug Bounty",        rank: 50,  color: "#F97316", borderColor: "#F97316", description: "Programa de recompensa por bugs. Acesso limitado." },
};

export function getTeamRoleRank(role: TeamRole): number {
  if (!role) return 0;
  return TEAM_ROLE_CONFIG[role]?.rank ?? 0;
}

export function canManageRole(callerRole: TeamRole, targetRole: TeamRole): boolean {
  return getTeamRoleRank(callerRole) > getTeamRoleRank(targetRole);
}

// ─── Tipos da Loja ─────────────────────────────────────────────────────────────

export type StoreItemType =
  | "avatar_frame"
  | "chat_bubble"
  | "sticker_pack"
  | "profile_background"
  | "chat_background";

export type Rarity = "common" | "rare" | "epic" | "legendary";

export type StoreItem = {
  id: string;
  type: StoreItemType;
  name: string;
  description: string | null;
  preview_url: string | null;
  asset_url: string | null;
  asset_config: Record<string, unknown>;
  price_coins: number;
  price_real_cents: number | null;
  is_premium_only: boolean;
  is_limited_edition: boolean;
  is_active: boolean;
  sort_order: number;
  rarity: Rarity | null;
  tags: string[] | null;
  available_until: string | null;
  max_purchases: number | null;
  current_purchases: number;
  created_at: string;
  updated_at: string | null;
};

export type StickerPack = {
  id: string;
  name: string;
  description: string;
  icon_url: string | null;
  cover_url: string | null;
  author_name: string;
  price_coins: number;
  is_free: boolean;
  is_premium_only: boolean;
  is_active: boolean;
  sort_order: number;
  is_user_created: boolean;
  is_public: boolean;
  tags: string[];
  sticker_count: number;
  saves_count: number;
  creator_id: string | null;
  created_at: string;
  updated_at: string | null;
};

export type Sticker = {
  id: string;
  pack_id: string;
  name: string;
  image_url: string;
  thumbnail_url: string | null;
  is_animated: boolean;
  sort_order: number;
  tags: string[];
  uses_count: number;
  created_at: string;
};

export type AvatarFrame = {
  id: string;
  name: string;
  description: string;
  frame_url: string;
  frame_config: Record<string, unknown>;
  is_animated: boolean;
  price_coins: number;
  is_premium_only: boolean;
  is_active: boolean;
  sort_order: number;
  created_at: string;
};

export type AppTheme = {
  id: string;
  slug: string;
  name: string;
  description: string;
  base_mode: "dark" | "light";
  colors: Record<string, string>;
  gradients: Record<string, unknown>;
  shadows: Record<string, unknown>;
  opacities: Record<string, number>;
  is_active: boolean;
  is_builtin: boolean;
  sort_order: number;
  created_by: string | null;
  created_at: string;
  updated_at: string;
};

export type UserPurchase = {
  id: string;
  user_id: string;
  item_id: string;
  price_paid: number;
  is_equipped: boolean;
  equipped_in_community: string | null;
  purchased_at: string;
  expires_at: string | null;
};

export type CoinTransaction = {
  id: string;
  user_id: string;
  amount: number;
  balance_after: number;
  source: string;
  reference_id: string | null;
  description: string;
  created_at: string;
};

export type Profile = {
  id: string;
  nickname: string;
  icon_url: string | null;
  is_team_admin: boolean;
  is_team_moderator: boolean;
  team_role: TeamRole;
  team_rank: number;
  coins?: number;
  amino_id?: string;
  bio?: string | null;
  created_at?: string;
};

export type StoreStats = {
  active_items: number;
  total_items: number;
  official_packs: number;
  total_purchases: number;
  total_coins_spent: number;
  active_themes: number;
  total_users: number;
};
