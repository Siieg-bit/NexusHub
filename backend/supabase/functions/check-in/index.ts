// ============================================================================
// NEXUSHUB - Edge Function: Check-in Diário
// Endpoint: POST /functions/v1/check-in
// Rate Limiting: dinâmico via app_remote_config (key: rate_limits.checkin_edge)
// ============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Fallbacks caso o Remote Config não esteja disponível
const RATE_LIMIT_MAX_FALLBACK = 5;
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

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: { headers: { Authorization: authHeader } },
      }
    );

    // Obter user_id do token
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Token inválido ou expirado" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

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
        .eq("key", "rate_limits.checkin_edge")
        .single();

      if (configRow?.value) {
        const cfg = typeof configRow.value === "object"
          ? configRow.value as Record<string, number>
          : JSON.parse(configRow.value as string) as Record<string, number>;
        if (cfg.max)    rateLimitMax    = Number(cfg.max);
        if (cfg.window) rateLimitWindow = Number(cfg.window);
      }
    } catch {
      // Silencioso — usa fallback
    }

    // ========================================================================
    // RATE LIMITING via rate_limit_log
    // ========================================================================
    const windowStart = new Date(
      Date.now() - rateLimitWindow * 1000
    ).toISOString();

    const { count } = await supabaseAdmin
      .from("rate_limit_log")
      .select("id", { count: "exact", head: true })
      .eq("user_id", user.id)
      .eq("action", "check_in")
      .gte("created_at", windowStart);

    if ((count ?? 0) >= rateLimitMax) {
      return new Response(
        JSON.stringify({
          error: "Rate limit excedido. Tente novamente em breve.",
          retry_after_seconds: rateLimitWindow,
        }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    await supabaseAdmin.from("rate_limit_log").insert({
      user_id: user.id,
      action: "check_in",
    });

    // ========================================================================
    // CHAMAR RPC
    // ========================================================================
    const body = await req.json().catch(() => ({}));
    const communityId = body.community_id || null;

    const { data, error } = await supabase.rpc("daily_checkin", {
      p_community_id: communityId,
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
