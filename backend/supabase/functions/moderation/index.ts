// ============================================================================
// NEXUSHUB - Edge Function: Moderação
// Endpoint: POST /functions/v1/moderation
// Ações: warn, mute, ban, delete_content
// Rate Limiting: dinâmico via app_remote_config (key: rate_limits.moderation_edge)
// ============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface ModerationRequest {
  community_id: string;
  target_user_id: string;
  action: "warn" | "mute" | "ban" | "delete_content";
  reason?: string;
  duration_hours?: number;
}

// Fallbacks caso o Remote Config não esteja disponível
const RATE_LIMIT_MAX_FALLBACK = 10;
const RATE_LIMIT_WINDOW_FALLBACK = 60;

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Token de autenticação ausente" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Cliente autenticado (respeita RLS)
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: { headers: { Authorization: authHeader } },
      }
    );

    // Obter o user_id do token JWT
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Token inválido ou expirado" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Cliente service_role para rate_limit_log e Remote Config
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // ========================================================================
    // Carregar rate limit do Remote Config (com fallback)
    // ========================================================================
    let rateLimitMax = RATE_LIMIT_MAX_FALLBACK;
    let rateLimitWindow = RATE_LIMIT_WINDOW_FALLBACK;

    try {
      const { data: configRow } = await supabaseAdmin
        .from("app_remote_config")
        .select("value")
        .eq("key", "rate_limits.moderation_edge")
        .single();

      if (configRow?.value) {
        const cfg = typeof configRow.value === "object"
          ? configRow.value as Record<string, number>
          : JSON.parse(configRow.value as string) as Record<string, number>;
        if (cfg.max)    rateLimitMax    = Number(cfg.max);
        if (cfg.window) rateLimitWindow = Number(cfg.window);
      }
    } catch { /* usa fallback */ }

    // ========================================================================
    // RATE LIMITING via tabela rate_limit_log
    // ========================================================================
    const windowStart = new Date(
      Date.now() - rateLimitWindow * 1000
    ).toISOString();

    const { count, error: countError } = await supabaseAdmin
      .from("rate_limit_log")
      .select("id", { count: "exact", head: true })
      .eq("user_id", user.id)
      .eq("action", "moderation")
      .gte("created_at", windowStart);

    if (!countError && (count ?? 0) >= rateLimitMax) {
      return new Response(
        JSON.stringify({
          error: "Rate limit excedido. Tente novamente em breve.",
          retry_after_seconds: rateLimitWindow,
        }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Registrar esta requisição no rate_limit_log
    await supabaseAdmin.from("rate_limit_log").insert({
      user_id: user.id,
      action: "moderation",
    });

    // ========================================================================
    // VALIDAÇÃO DO BODY
    // ========================================================================
    const body: ModerationRequest = await req.json();

    if (!body.community_id || !body.target_user_id || !body.action) {
      return new Response(
        JSON.stringify({ error: "Campos obrigatórios: community_id, target_user_id, action" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const validActions = ["warn", "mute", "ban", "delete_content"];
    if (!validActions.includes(body.action)) {
      return new Response(
        JSON.stringify({ error: "Ação inválida. Use: warn, mute, ban, delete_content" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ========================================================================
    // CHAMAR RPC DE MODERAÇÃO
    // ========================================================================
    const { data, error } = await supabase.rpc("moderate_user", {
      p_community_id: body.community_id,
      p_target_user_id: body.target_user_id,
      p_action: body.action,
      p_reason: body.reason || null,
      p_duration_hours: body.duration_hours || null,
    });

    if (error) {
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify(data),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: "Erro interno do servidor", details: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
