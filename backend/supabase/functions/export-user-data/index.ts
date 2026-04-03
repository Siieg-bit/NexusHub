// ============================================================================
// NEXUSHUB - Edge Function: export-user-data
//
// Exporta todos os dados do usuário em JSON (LGPD - direito de portabilidade).
// Rate Limiting: 2 requisições por hora por usuário
// Otimização: consultas paralelas via Promise.allSettled
// ============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const RATE_LIMIT_MAX = 2;
const RATE_LIMIT_WINDOW_SECONDS = 3600; // 1 hora

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUser = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const userId = user.id;

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // ========================================================================
    // RATE LIMITING - 2 exports por hora
    // ========================================================================
    const windowStart = new Date(
      Date.now() - RATE_LIMIT_WINDOW_SECONDS * 1000
    ).toISOString();

    const { count } = await supabaseAdmin
      .from("rate_limit_log")
      .select("id", { count: "exact", head: true })
      .eq("user_id", userId)
      .eq("action", "export_user_data")
      .gte("created_at", windowStart);

    if ((count ?? 0) >= RATE_LIMIT_MAX) {
      return new Response(
        JSON.stringify({
          error: "Você já solicitou um export recentemente. Tente novamente em 1 hora.",
          retry_after_seconds: RATE_LIMIT_WINDOW_SECONDS,
        }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    await supabaseAdmin.from("rate_limit_log").insert({
      user_id: userId,
      action: "export_user_data",
    });

    // ========================================================================
    // COLETAR DADOS EM PARALELO (Promise.allSettled)
    // ========================================================================
    const tables = [
      { name: "profiles", column: "id" },
      { name: "posts", column: "author_id" },
      { name: "comments", column: "author_id" },
      { name: "chat_messages", column: "author_id" },
      { name: "community_members", column: "user_id" },
      { name: "follows", column: "follower_id" },
      { name: "post_likes", column: "user_id" },
      { name: "notifications", column: "user_id" },
      { name: "wallets", column: "user_id" },
      { name: "wallet_transactions", column: "user_id" },
      { name: "user_achievements", column: "user_id" },
      { name: "user_purchases", column: "user_id" },
      { name: "check_in_streaks", column: "user_id" },
      { name: "checkins", column: "user_id" },
      { name: "wiki_entries", column: "author_id" },
      { name: "wiki_ratings", column: "user_id" },
      { name: "device_fingerprints", column: "user_id" },
      { name: "flags", column: "reporter_id" },
      { name: "poll_votes", column: "user_id" },
      { name: "notification_settings", column: "user_id" },
      { name: "user_sticker_favorites", column: "user_id" },
      { name: "stories", column: "author_id" },
    ];

    // Executar todas as queries em paralelo
    const results = await Promise.allSettled(
      tables.map(({ name, column }) =>
        supabaseAdmin
          .from(name)
          .select("*")
          .eq(column, userId)
          .then((res) => ({ name, data: res.data, error: res.error }))
      )
    );

    const exportData: Record<string, unknown> = {
      export_date: new Date().toISOString(),
      user_id: userId,
      email: user.email,
    };

    for (const result of results) {
      if (result.status === "fulfilled") {
        const { name, data, error } = result.value;
        exportData[name] = error ? { error: error.message } : data;
      } else {
        // Promise rejeitada — registrar o erro
        exportData[`_error_${results.indexOf(result)}`] = {
          error: result.reason?.message ?? "Unknown error",
        };
      }
    }

    // Metadados
    exportData["_metadata"] = {
      format: "NexusHub User Data Export",
      version: "2.0",
      tables_exported: tables.length,
      generated_at: new Date().toISOString(),
      note: "Este arquivo contém todos os seus dados armazenados no NexusHub, conforme previsto pela LGPD (Lei Geral de Proteção de Dados).",
    };

    return new Response(
      JSON.stringify(exportData, null, 2),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
          "Content-Disposition": `attachment; filename="nexushub_data_export_${userId}.json"`,
        },
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
