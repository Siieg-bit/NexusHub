// ============================================================================
// AMINO CLONE - Edge Function: Moderação
// Endpoint: POST /functions/v1/moderation
// Ações: warn, mute, ban, delete_content
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

    const body: ModerationRequest = await req.json();

    // Validação dos campos obrigatórios
    if (!body.community_id || !body.target_user_id || !body.action) {
      return new Response(
        JSON.stringify({ error: "Campos obrigatórios: community_id, target_user_id, action" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Validar ação
    const validActions = ["warn", "mute", "ban", "delete_content"];
    if (!validActions.includes(body.action)) {
      return new Response(
        JSON.stringify({ error: "Ação inválida. Use: warn, mute, ban, delete_content" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Rate limiting simples (baseado no header)
    // Em produção, usar Redis ou similar
    const rateLimitKey = `mod:${authHeader.slice(-10)}`;

    // Chamar RPC de moderação
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
      JSON.stringify({ error: "Erro interno do servidor", details: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
