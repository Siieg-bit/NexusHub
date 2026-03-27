// ============================================================================
// Edge Function: webhook-handler
//
// Processa webhooks de database triggers para:
// - Enviar push notifications quando notificação é criada
// - Atualizar contadores (member_count, like_count, etc.)
// - Processar eventos de moderação
// - Welcome message para novos membros
// ============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  record: Record<string, unknown>;
  old_record?: Record<string, unknown>;
  schema: string;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload: WebhookPayload = await req.json();
    const { type, table, record, old_record } = payload;

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const results: string[] = [];

    // ── Notificação criada → enviar push ──
    if (table === "notifications" && type === "INSERT") {
      const userId = record.user_id as string;
      const content = record.content as string;
      const notifType = record.notification_type as string;

      try {
        // Chamar a Edge Function de push notification
        const pushUrl = `${Deno.env.get("SUPABASE_URL")}/functions/v1/push-notification`;
        await fetch(pushUrl, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`,
          },
          body: JSON.stringify({
            user_id: userId,
            notification_type: notifType,
            content: content,
            title: record.title || "NexusHub",
          }),
        });
        results.push("push_notification_sent");
      } catch (e) {
        results.push(`push_error: ${e.message}`);
      }
    }

    // ── Novo membro → atualizar member_count e enviar welcome ──
    if (table === "community_members" && type === "INSERT") {
      const communityId = record.community_id as string;
      const userId = record.user_id as string;

      // Incrementar member_count
      const { data: community } = await supabase
        .from("communities")
        .select("member_count, name")
        .eq("id", communityId)
        .single();

      if (community) {
        await supabase
          .from("communities")
          .update({ member_count: (community.member_count || 0) + 1 })
          .eq("id", communityId);
        results.push("member_count_incremented");

        // Enviar welcome notification
        await supabase.from("notifications").insert({
          user_id: userId,
          notification_type: "system",
          content: `Bem-vindo à comunidade ${community.name}! Explore os posts e participe das conversas.`,
        });
        results.push("welcome_notification_sent");
      }
    }

    // ── Membro saiu → decrementar member_count ──
    if (table === "community_members" && type === "DELETE" && old_record) {
      const communityId = old_record.community_id as string;

      const { data: community } = await supabase
        .from("communities")
        .select("member_count")
        .eq("id", communityId)
        .single();

      if (community && community.member_count > 0) {
        await supabase
          .from("communities")
          .update({ member_count: community.member_count - 1 })
          .eq("id", communityId);
        results.push("member_count_decremented");
      }
    }

    // ── Novo post → notificar seguidores do autor ──
    if (table === "posts" && type === "INSERT") {
      const authorId = record.author_id as string;
      const communityId = record.community_id as string;
      const postTitle = record.title as string;

      // Buscar seguidores do autor que são membros da mesma comunidade
      const { data: followers } = await supabase
        .from("follows")
        .select("follower_id")
        .eq("following_id", authorId);

      if (followers && followers.length > 0) {
        const { data: author } = await supabase
          .from("profiles")
          .select("nickname")
          .eq("id", authorId)
          .single();

        const notifications = followers.slice(0, 100).map((f: { follower_id: string }) => ({
          user_id: f.follower_id,
          notification_type: "post",
          content: `${author?.nickname || "Alguém"} publicou: "${postTitle}"`,
          data: { post_id: record.id, community_id: communityId },
        }));

        if (notifications.length > 0) {
          await supabase.from("notifications").insert(notifications);
          results.push(`notified_${notifications.length}_followers`);
        }
      }
    }

    // ── Novo comentário → notificar autor do post ──
    if (table === "comments" && type === "INSERT") {
      const postId = record.post_id as string;
      const commentAuthorId = record.author_id as string;

      const { data: post } = await supabase
        .from("posts")
        .select("author_id, title")
        .eq("id", postId)
        .single();

      if (post && post.author_id !== commentAuthorId) {
        const { data: commenter } = await supabase
          .from("profiles")
          .select("nickname")
          .eq("id", commentAuthorId)
          .single();

        await supabase.from("notifications").insert({
          user_id: post.author_id,
          notification_type: "comment",
          content: `${commenter?.nickname || "Alguém"} comentou no seu post "${post.title}"`,
          data: { post_id: postId, comment_id: record.id },
        });
        results.push("comment_notification_sent");
      }

      // Incrementar comment_count
      await supabase.rpc("increment_comment_count", { p_post_id: postId });
      results.push("comment_count_incremented");
    }

    // ── Nova flag → notificar moderadores ──
    if (table === "flags" && type === "INSERT") {
      const communityId = record.community_id as string;

      // Buscar moderadores da comunidade
      const { data: mods } = await supabase
        .from("community_members")
        .select("user_id")
        .eq("community_id", communityId)
        .in("role", ["leader", "curator", "agent"]);

      if (mods && mods.length > 0) {
        const notifications = mods.map((m: { user_id: string }) => ({
          user_id: m.user_id,
          notification_type: "moderation",
          content: `Nova denúncia recebida: ${record.reason || "Conteúdo reportado"}`,
          data: { flag_id: record.id, community_id: communityId },
        }));

        await supabase.from("notifications").insert(notifications);
        results.push(`notified_${mods.length}_moderators`);
      }
    }

    // ── Novo follow → notificar o seguido ──
    if (table === "follows" && type === "INSERT") {
      const followerId = record.follower_id as string;
      const followingId = record.following_id as string;

      const { data: follower } = await supabase
        .from("profiles")
        .select("nickname")
        .eq("id", followerId)
        .single();

      await supabase.from("notifications").insert({
        user_id: followingId,
        notification_type: "follow",
        content: `${follower?.nickname || "Alguém"} começou a te seguir`,
        data: { follower_id: followerId },
      });
      results.push("follow_notification_sent");
    }

    return new Response(
      JSON.stringify({ success: true, processed: results }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
