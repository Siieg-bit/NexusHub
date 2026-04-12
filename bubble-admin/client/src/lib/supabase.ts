import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = "https://ylvzqqvcanzzswjkqeya.supabase.co";
const SUPABASE_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlsdnpxcXZjYW56enN3amtxZXlhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ1NTk3MDYsImV4cCI6MjA5MDEzNTcwNn0.eoHEl-w8bac2Q-jxjBvmXr118ZzuGC0uwmsCES7r7hA";

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

export type StoreItem = {
  id: string;
  type: string;
  name: string;
  description: string | null;
  preview_url: string | null;
  asset_url: string | null;
  asset_config: Record<string, unknown>;
  price_coins: number;
  price_real_cents: number;
  is_premium_only: boolean;
  is_limited_edition: boolean;
  is_active: boolean;
  sort_order: number;
  created_at: string;
};

export type Profile = {
  id: string;
  nickname: string;
  icon_url: string | null;
  is_team_admin: boolean;
  is_team_moderator: boolean;
};
