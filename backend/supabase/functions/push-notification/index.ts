// ============================================================================
// Edge Function: push-notification
//
// Envia push notifications via Firebase Cloud Messaging (FCM).
// Chamada por database webhooks quando uma notificação é inserida.
//
// Env vars necessárias:
// - FCM_SERVER_KEY: Firebase Cloud Messaging server key
// ============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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

    // Se tem settings e o tipo está desabilitado, não enviar
    if (settings) {
      const typeKey = `push_${notification_type}`;
      if (settings[typeKey] === false) {
        return new Response(
          JSON.stringify({ message: "Notification type disabled by user" }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // Enviar via FCM
    const fcmKey = Deno.env.get("FCM_SERVER_KEY");
    if (!fcmKey) {
      return new Response(
        JSON.stringify({ error: "FCM_SERVER_KEY not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

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

    const fcmPayload = {
      to: profile.fcm_token,
      notification: {
        title: title || "NexusHub",
        body: content,
        sound: "default",
        android_channel_id: androidChannel,
      },
      data: {
        type: notification_type,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        ...data,
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
    };

    const fcmResponse = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `key=${fcmKey}`,
      },
      body: JSON.stringify(fcmPayload),
    });

    const fcmResult = await fcmResponse.json();

    // Se o token é inválido, limpar do perfil
    if (fcmResult.failure === 1 && fcmResult.results?.[0]?.error === "NotRegistered") {
      await supabase
        .from("profiles")
        .update({ fcm_token: null })
        .eq("id", user_id);
    }

    return new Response(
      JSON.stringify({
        success: fcmResult.success === 1,
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
