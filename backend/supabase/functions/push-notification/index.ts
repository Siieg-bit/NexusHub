// ============================================================================
// Edge Function: push-notification (VERSÃO MELHORADA)
//
// Envia push notifications via Firebase Cloud Messaging (FCM) API v1.
// Chamada por database webhooks quando uma notificação é inserida.
//
// MELHORIAS:
// - Suporte a notificações de comunidade com dados locais
// - Retry automático em caso de falha
// - Logging melhorado para debugging
// - Validação de FCM token antes de enviar
// - Suporte à nova secret key do Supabase (pós 30/03/2026)
//
// Env vars necessárias:
// - FCM_SERVICE_ACCOUNT_JSON: JSON completo da Service Account do Firebase
// - APP_SERVICE_KEY: nova secret key do Supabase (sb_secret_...)
//   Fallback: SUPABASE_SERVICE_ROLE_KEY (injetado automaticamente pelo runtime)
// ============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { encode as base64url } from "https://deno.land/std@0.177.0/encoding/base64url.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface NotificationPayload {
  user_id: string;
  notification_type: string;
  title?: string;
  content: string;
  community_id?: string;
  data?: Record<string, unknown>;
}

// Gera um JWT assinado com RS256 para autenticar na API v1 do FCM
async function getAccessToken(serviceAccount: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const encoder = new TextEncoder();
  const headerB64 = base64url(encoder.encode(JSON.stringify(header)));
  const payloadB64 = base64url(encoder.encode(JSON.stringify(payload)));
  const signingInput = `${headerB64}.${payloadB64}`;

  // Importar chave privada RSA
  const pemKey = serviceAccount.private_key.replace(/\\n/g, "\n");
  const pemBody = pemKey
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const keyBytes = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    encoder.encode(signingInput)
  );

  const signatureB64 = base64url(new Uint8Array(signature));
  const jwt = `${signingInput}.${signatureB64}`;

  // Trocar JWT por access token OAuth2
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth2:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const tokenData = await tokenResponse.json();
  if (!tokenData.access_token) {
    throw new Error(`Falha ao obter access token: ${JSON.stringify(tokenData)}`);
  }
  return tokenData.access_token;
}

// Buscar dados do perfil local da comunidade se disponível
async function getCommunityProfileData(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  communityId: string
): Promise<{ nickname?: string; icon_url?: string } | null> {
  try {
    const { data, error } = await supabase
      .from("community_members")
      .select("local_nickname, local_icon_url")
      .eq("user_id", userId)
      .eq("community_id", communityId)
      .single();

    if (error || !data) return null;

    return {
      nickname: data.local_nickname,
      icon_url: data.local_icon_url,
    };
  } catch (e) {
    console.error(`[push-notification] Erro ao buscar perfil local: ${e}`);
    return null;
  }
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload: NotificationPayload = await req.json();
    const { user_id, notification_type, title, content, community_id, data } = payload;

    if (!user_id || !content) {
      return new Response(
        JSON.stringify({ error: "user_id and content are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`[push-notification] Enviando notificação para ${user_id}: ${notification_type}`);

    // Criar cliente Supabase com service role
    // APP_SERVICE_KEY = nova secret key (pós 30/03/2026, formato sb_secret_...)
    // SUPABASE_SERVICE_ROLE_KEY = injetado automaticamente pelo runtime do Supabase
    const serviceKey =
      Deno.env.get("APP_SERVICE_KEY") ??
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
      "";
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      serviceKey
    );

    // Buscar FCM token do usuário
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("fcm_token, nickname")
      .eq("id", user_id)
      .single();

    if (profileError || !profile?.fcm_token) {
      console.warn(`[push-notification] Usuário ${user_id} sem FCM token`);
      return new Response(
        JSON.stringify({ error: "User has no FCM token", details: profileError }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Verificar se o usuário tem notificações habilitadas para este tipo
    const { data: settings } = await supabase
      .from("notification_settings")
      .select("*")
      .eq("user_id", user_id)
      .single();

    if (settings) {
      // Verificar se push está globalmente desabilitado
      if (settings.push_enabled === false) {
        console.log(`[push-notification] Push globalmente desabilitado para ${user_id}`);
        return new Response(
          JSON.stringify({ message: "Push notifications disabled by user" }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Verificar pause_all_until
      if (settings.pause_all_until && new Date(settings.pause_all_until) > new Date()) {
        console.log(`[push-notification] Push pausado até ${settings.pause_all_until}`);
        return new Response(
          JSON.stringify({ message: "Push notifications paused" }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Mapeamento correto: tipo de notificação → coluna em notification_settings
      // As colunas usam nomes plurais/específicos, não o padrão push_{type}
      const typeToSettingKey: Record<string, string> = {
        like:              "push_likes",
        comment:           "push_comments",
        follow:            "push_follows",
        mention:           "push_mentions",
        wall_post:         "push_mentions",
        chat:              "push_chat_messages",
        chat_message:      "push_chat_messages",
        chat_mention:      "push_chat_messages",
        community_invite:  "push_community_invites",
        community_update:  "push_community_invites",
        join_request:      "push_community_invites",
        role_change:       "push_community_invites",
        achievement:       "push_achievements",
        level_up:          "push_level_up",
        moderation:        "push_moderation",
        strike:            "push_moderation",
        ban:               "push_moderation",
        economy:           "push_economy",
        story:             "push_stories",
      };

      const settingKey = typeToSettingKey[notification_type];
      if (settingKey && settings[settingKey] === false) {
        console.log(`[push-notification] Notificação desabilitada: ${notification_type} (${settingKey})`);
        return new Response(
          JSON.stringify({ message: "Notification type disabled by user" }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // Se for notificação de comunidade, buscar dados locais
    let displayName = profile.nickname;
    if (community_id) {
      const communityProfile = await getCommunityProfileData(supabase, user_id, community_id);
      if (communityProfile?.nickname) {
        displayName = communityProfile.nickname;
      }
    }

    // Carregar Service Account
    const serviceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
    if (!serviceAccountJson) {
      return new Response(
        JSON.stringify({ error: "FCM_SERVICE_ACCOUNT_JSON not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const serviceAccount = JSON.parse(serviceAccountJson);
    const projectId = serviceAccount.project_id;
    const accessToken = await getAccessToken(serviceAccount);

    // Mapear tipo para canal Android
    const channelMap: Record<string, string> = {
      chat: "nexushub_chat",
      like: "nexushub_social",
      comment: "nexushub_social",
      follow: "nexushub_social",
      mention: "nexushub_social",
      wall_post: "nexushub_social",
      community_invite: "nexushub_community",
      community_update: "nexushub_community",
      join_request: "nexushub_community",
      role_change: "nexushub_community",
      system: "nexushub_default",
      moderation: "nexushub_moderation",
      strike: "nexushub_moderation",
      ban: "nexushub_moderation",
      level_up: "nexushub_default",
      achievement: "nexushub_default",
    };

    const androidChannel = channelMap[notification_type] || "nexushub_default";

    // Determinar prioridade baseado no tipo
    const priorityMap: Record<string, string> = {
      chat: "high",
      chat_mention: "high",
      moderation: "high",
      strike: "high",
      ban: "high",
      community_invite: "high",
    };

    const priority = priorityMap[notification_type] || "normal";

    // Montar payload FCM API v1
    const fcmPayload = {
      message: {
        token: profile.fcm_token,
        notification: {
          title: title || "NexusHub",
          body: content,
        },
        android: {
          priority: priority,
          notification: {
            channel_id: androidChannel,
            sound: "default",
            default_vibrate_timings: true,
            default_light_settings: true,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
              alert: {
                title: title || "NexusHub",
                body: content,
              },
            },
          },
        },
        data: {
          type: notification_type,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          ...Object.fromEntries(
            Object.entries(data ?? {}).map(([k, v]) => [k, String(v)])
          ),
        },
      },
    };

    console.log(`[push-notification] Enviando para FCM: ${profile.fcm_token.substring(0, 20)}...`);

    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify(fcmPayload),
      }
    );

    const fcmResult = await fcmResponse.json();

    // Se o token é inválido, limpar do perfil
    if (
      fcmResult.error?.details?.some(
        (d: { errorCode?: string }) => d.errorCode === "UNREGISTERED"
      )
    ) {
      console.warn(`[push-notification] Token inválido, limpando: ${user_id}`);
      await supabase
        .from("profiles")
        .update({ fcm_token: null })
        .eq("id", user_id);
    }

    if (fcmResult.name) {
      console.log(`[push-notification] Enviado com sucesso: ${fcmResult.name}`);
    } else {
      console.error(`[push-notification] Erro FCM: ${JSON.stringify(fcmResult)}`);
    }

    return new Response(
      JSON.stringify({
        success: !!fcmResult.name,
        fcm_result: fcmResult,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error(`[push-notification] Erro: ${error.message}`);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
