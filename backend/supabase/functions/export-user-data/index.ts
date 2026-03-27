// ============================================================================
// Edge Function: export-user-data
//
// Exporta todos os dados do usuário em JSON (LGPD - direito de portabilidade).
// Retorna um JSON com todas as informações do usuário em todas as tabelas.
// ============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

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

    // Coletar dados de todas as tabelas
    const tables = [
      { name: "profiles", column: "id" },
      { name: "posts", column: "author_id" },
      { name: "comments", column: "author_id" },
      { name: "messages", column: "sender_id" },
      { name: "community_members", column: "user_id" },
      { name: "follows", column: "follower_id" },
      { name: "post_likes", column: "user_id" },
      { name: "notifications", column: "user_id" },
      { name: "wallets", column: "user_id" },
      { name: "wallet_transactions", column: "user_id" },
      { name: "user_achievements", column: "user_id" },
      { name: "user_inventory", column: "user_id" },
      { name: "check_in_streaks", column: "user_id" },
      { name: "wiki_entries", column: "author_id" },
      { name: "wiki_ratings", column: "user_id" },
      { name: "device_fingerprints", column: "user_id" },
      { name: "flags", column: "reporter_id" },
      { name: "poll_votes", column: "user_id" },
    ];

    const exportData: Record<string, unknown> = {
      export_date: new Date().toISOString(),
      user_id: userId,
      email: user.email,
    };

    for (const { name, column } of tables) {
      try {
        const { data, error } = await supabaseAdmin
          .from(name)
          .select("*")
          .eq(column, userId);

        exportData[name] = error ? { error: error.message } : data;
      } catch (e) {
        exportData[name] = { error: e.message };
      }
    }

    // Adicionar metadados
    exportData["_metadata"] = {
      format: "NexusHub User Data Export",
      version: "1.0",
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
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
