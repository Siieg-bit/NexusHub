// ============================================================================
// Edge Function: delete-user-data
//
// Exclui todos os dados do usuário (LGPD compliance).
// Chamada pela RPC delete_user_account após confirmação dupla.
//
// Fluxo:
// 1. Verificar autenticação
// 2. Deletar dados de todas as tabelas relacionadas
// 3. Deletar arquivos do Storage
// 4. Deletar conta de autenticação
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
    // Verificar autenticação
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Cliente autenticado
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

    // Cliente com service role para deletar tudo
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // Ordem de deleção (respeitar foreign keys)
    const deletionOrder = [
      // Dependentes primeiro
      { table: "poll_votes", column: "user_id" },
      { table: "wiki_ratings", column: "user_id" },
      { table: "wiki_what_i_like", column: "user_id" },
      { table: "post_likes", column: "user_id" },
      { table: "comments", column: "author_id" },
      { table: "messages", column: "sender_id" },
      { table: "thread_participants", column: "user_id" },
      { table: "community_members", column: "user_id" },
      { table: "follows", column: "follower_id" },
      { table: "follows", column: "following_id" },
      { table: "notifications", column: "user_id" },
      { table: "flags", column: "reporter_id" },
      { table: "moderation_logs", column: "moderator_id" },
      { table: "wallet_transactions", column: "user_id" },
      { table: "user_achievements", column: "user_id" },
      { table: "user_inventory", column: "user_id" },
      { table: "device_fingerprints", column: "user_id" },
      { table: "check_in_streaks", column: "user_id" },
      { table: "security_logs", column: "user_id" },
      { table: "rate_limit_log", column: "user_id" },
      { table: "call_participants", column: "user_id" },
      // Entidades principais
      { table: "posts", column: "author_id" },
      { table: "wiki_entries", column: "author_id" },
      { table: "wallets", column: "user_id" },
      { table: "profiles", column: "id" },
    ];

    const results: Record<string, string> = {};

    for (const { table, column } of deletionOrder) {
      try {
        const { error } = await supabaseAdmin
          .from(table)
          .delete()
          .eq(column, userId);

        results[`${table}.${column}`] = error ? `error: ${error.message}` : "ok";
      } catch (e) {
        results[`${table}.${column}`] = `exception: ${e.message}`;
      }
    }

    // Deletar arquivos do Storage
    const buckets = ["avatars", "post_media", "chat_media", "wiki_media"];
    for (const bucket of buckets) {
      try {
        const { data: files } = await supabaseAdmin.storage
          .from(bucket)
          .list(userId);

        if (files && files.length > 0) {
          const paths = files.map((f: { name: string }) => `${userId}/${f.name}`);
          await supabaseAdmin.storage.from(bucket).remove(paths);
        }
        results[`storage.${bucket}`] = "ok";
      } catch (e) {
        results[`storage.${bucket}`] = `exception: ${e.message}`;
      }
    }

    // Deletar conta de autenticação
    try {
      const { error: deleteAuthError } = await supabaseAdmin.auth.admin.deleteUser(userId);
      results["auth.user"] = deleteAuthError ? `error: ${deleteAuthError.message}` : "ok";
    } catch (e) {
      results["auth.user"] = `exception: ${e.message}`;
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Todos os dados do usuário foram excluídos.",
        details: results,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
