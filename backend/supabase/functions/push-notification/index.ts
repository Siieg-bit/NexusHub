// ============================================================================
// Edge Function: push-notification
//
// Envia push notifications via Firebase Cloud Messaging (FCM) API v1.
// Chamada por database webhooks quando uma notificação é inserida.
//
// Env vars necessárias:
// - FCM_SERVICE_ACCOUNT_JSON: JSON completo da Service Account do Firebase
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

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload: NotificationPayload = await req.json();
    const { user_id, notification_type, title, content, data } = payload;

    if (!user_id || !content) {
      return new Response(
        JSON.stringify({ error: "user_id and content are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Criar cliente Supabase com service role
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // Buscar FCM token do usuário
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("fcm_token, nickname")
      .eq("id", user_id)
      .single();

    if (profileError || !profile?.fcm_token) {
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
      const typeKey = `push_${notification_type}`;
      if (settings[typeKey] === false) {
        return new Response(
          JSON.stringify({ message: "Notification type disabled by user" }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
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
      chat: "chat_messages",
      like: "social_interactions",
      comment: "social_interactions",
      follow: "social_interactions",
      mention: "social_interactions",
      system: "system_alerts",
      moderation: "moderation_alerts",
      economy: "economy_updates",
    };

    const androidChannel = channelMap[notification_type] || "social_interactions";

    // Montar payload FCM API v1
    const fcmPayload = {
      message: {
        token: profile.fcm_token,
        notification: {
          title: title || "NexusHub",
          body: content,
        },
        android: {
          priority: "high",
          notification: {
            channel_id: androidChannel,
            sound: "default",
            default_vibrate_timings: true,
            default_light_settings: true,
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
        data: {
          type: notification_type,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          ...Object.fromEntries(
            Object.entries(data ?? {}).map(([k, v]) => [k, String(v)])
          ),
        },
      },
    };

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
      await supabase
        .from("profiles")
        .update({ fcm_token: null })
        .eq("id", user_id);
    }

    return new Response(
      JSON.stringify({
        success: !!fcmResult.name,
        fcm_result: fcmResult,
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
