// ============================================================================
// Edge Function: push-notification
//
// Envia push notifications via Firebase Admin SDK (FCM API v1).
// Chamada pelo trigger do banco via pg_net quando uma notificação é inserida.
//
// Env vars necessárias:
// - FCM_SERVICE_ACCOUNT_JSON: JSON completo da Service Account do Firebase
// - APP_SERVICE_KEY: nova secret key do Supabase (sb_secret_...)
//   Fallback: SUPABASE_SERVICE_ROLE_KEY (injetado automaticamente pelo runtime)
// ============================================================================

import { createClient } from "npm:@supabase/supabase-js@2";
import { initializeApp, cert, getApps, deleteApp } from "npm:firebase-admin/app";
import { getMessaging } from "npm:firebase-admin/messaging";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Mapeamento tipo de notificação → coluna em notification_settings
const TYPE_TO_SETTINGS_COL: Record<string, string> = {
  // Likes
  like: "push_likes",
  // Comentários e menções
  comment: "push_comments",
  mention: "push_mentions",
  wall_post: "push_mentions",
  // Follows
  follow: "push_follows",
  repost: "push_mentions",
  // Chat
  chat: "push_chat_messages",
  chat_message: "push_chat_messages",
  chat_mention: "push_chat_messages",
  chat_invite: "push_chat_messages",
  dm_invite: "push_chat_messages",
  // Comunidade
  community_invite: "push_community_invites",
  community_update: "push_community_invites",
  join_request: "push_community_invites",
  role_change: "push_community_invites",
  // Conquistas
  achievement: "push_achievements",
  level_up: "push_level_up",
  // Moderação
  moderation: "push_moderation",
  strike: "push_moderation",
  ban: "push_moderation",
  // Economia
  economy: "push_economy",
  // Histórias
  story: "push_stories",
  // Wiki
  wiki_approved: "push_achievements",
  // Broadcast (sem filtro de settings)
  broadcast: "",
};

// Mapeamento tipo → canal Android
const TYPE_TO_CHANNEL: Record<string, string> = {
  // Chat
  chat: "nexushub_chat",
  chat_message: "nexushub_chat",
  chat_mention: "nexushub_chat",
  chat_invite: "nexushub_chat",
  dm_invite: "nexushub_chat",
  // Social
  like: "nexushub_social",
  comment: "nexushub_social",
  follow: "nexushub_social",
  mention: "nexushub_social",
  wall_post: "nexushub_social",
  repost: "nexushub_social",
  wiki_approved: "nexushub_social",
  // Comunidade
  community_invite: "nexushub_community",
  community_update: "nexushub_community",
  join_request: "nexushub_community",
  role_change: "nexushub_community",
  // Moderação
  moderation: "nexushub_moderation",
  strike: "nexushub_moderation",
  ban: "nexushub_moderation",
};

const HIGH_PRIORITY_TYPES = new Set([
  "chat", "chat_message", "chat_mention", "chat_invite", "dm_invite",
  "moderation", "strike", "ban", "community_invite",
]);

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  let firebaseApp: ReturnType<typeof initializeApp> | null = null;

  try {
    const payload = await req.json();
    const {
      user_id,
      notification_type,
      title,
      content,
      community_id,
      data: extraData,
    } = payload;

    if (!user_id || !content) {
      return new Response(
        JSON.stringify({ error: "user_id and content are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`[push] Processando ${notification_type} para ${user_id}`);

    // ── Criar cliente Supabase ──────────────────────────────────────────────
    const serviceKey =
      Deno.env.get("APP_SERVICE_KEY") ??
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
      "";
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      serviceKey
    );

    // ── Buscar FCM token e nickname ─────────────────────────────────────────
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("fcm_token, nickname")
      .eq("id", user_id)
      .single();

    if (profileError || !profile?.fcm_token) {
      console.warn(`[push] Usuário ${user_id} sem FCM token`);
      return new Response(
        JSON.stringify({ error: "User has no FCM token" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── Verificar preferências de notificação ───────────────────────────────
    const { data: settings } = await supabase
      .from("notification_settings")
      .select("*")
      .eq("user_id", user_id)
      .single();

    if (settings) {
      if (settings.push_enabled === false) {
        console.log(`[push] Push globalmente desabilitado para ${user_id}`);
        return new Response(
          JSON.stringify({ message: "Push disabled by user" }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      if (settings.pause_all_until && new Date(settings.pause_all_until) > new Date()) {
        return new Response(
          JSON.stringify({ message: "Push paused" }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const col = TYPE_TO_SETTINGS_COL[notification_type];
      // col vazio = broadcast, sem filtro de settings
      if (col && settings[col] === false) {
        console.log(`[push] Tipo ${notification_type} desabilitado pelo usuário`);
        return new Response(
          JSON.stringify({ message: "Notification type disabled" }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // ── Resolver nome de exibição (perfil local da comunidade) ──────────────
    let displayName = profile.nickname ?? "";
    if (community_id) {
      try {
        const { data: cm } = await supabase
          .from("community_members")
          .select("local_nickname")
          .eq("user_id", user_id)
          .eq("community_id", community_id)
          .single();
        if (cm?.local_nickname) displayName = cm.local_nickname;
      } catch {
        // fallback para nickname global
      }
    }

    // ── Inicializar Firebase Admin ──────────────────────────────────────────
    const serviceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
    if (!serviceAccountJson) {
      console.error("[push] FCM_SERVICE_ACCOUNT_JSON não configurado");
      return new Response(
        JSON.stringify({ error: "FCM_SERVICE_ACCOUNT_JSON not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const serviceAccount = JSON.parse(serviceAccountJson);

    // Usar app único por invocação para evitar conflitos
    const appName = `push-${Date.now()}`;
    firebaseApp = initializeApp({ credential: cert(serviceAccount) }, appName);
    const messaging = getMessaging(firebaseApp);

    // ── Montar mensagem FCM ─────────────────────────────────────────────────
    const androidChannel = TYPE_TO_CHANNEL[notification_type] ?? "nexushub_default";
    const isHighPriority = HIGH_PRIORITY_TYPES.has(notification_type);

    const messageData: Record<string, string> = {
      type: notification_type ?? "",
      display_name: displayName,
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    };

    if (extraData) {
      for (const [k, v] of Object.entries(extraData)) {
        messageData[k] = String(v);
      }
    }

    const message = {
      token: profile.fcm_token,
      notification: {
        title: title ?? "NexusHub",
        body: content,
      },
      android: {
        priority: isHighPriority ? ("high" as const) : ("normal" as const),
        notification: {
          channelId: androidChannel,
          sound: "default",
          defaultVibrateTimings: true,
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
      data: messageData,
    };

    console.log(`[push] Enviando para token: ${profile.fcm_token.substring(0, 20)}...`);

    const messageId = await messaging.send(message);
    console.log(`[push] Enviado com sucesso: ${messageId}`);

    return new Response(
      JSON.stringify({ success: true, message_id: messageId }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    const err = error as Error & { code?: string };
    console.error(`[push] Erro: ${err.message} (code: ${err.code})`);

    // Limpar token inválido
    if (
      err.code === "messaging/invalid-registration-token" ||
      err.code === "messaging/registration-token-not-registered"
    ) {
      try {
        const serviceKey =
          Deno.env.get("APP_SERVICE_KEY") ??
          Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
          "";
        const supabase = createClient(
          Deno.env.get("SUPABASE_URL") ?? "",
          serviceKey
        );
        const payload = await req.clone().json().catch(() => ({}));
        if (payload.user_id) {
          await supabase
            .from("profiles")
            .update({ fcm_token: null })
            .eq("id", payload.user_id);
          console.log(`[push] Token inválido removido para ${payload.user_id}`);
        }
      } catch {
        // ignorar erro ao limpar token
      }
    }

    return new Response(
      JSON.stringify({ error: err.message, code: err.code }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } finally {
    // Limpar app Firebase para evitar memory leak
    if (firebaseApp) {
      try {
        await deleteApp(firebaseApp);
      } catch {
        // ignorar erro ao deletar app
      }
    }
  }
});
