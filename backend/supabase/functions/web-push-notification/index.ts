// ============================================================================
// Edge Function: web-push-notification
//
// Envia Web Push Notifications via Web Push Protocol (RFC 8030)
// Chamada por database webhooks quando uma notificação é inserida
//
// Protocolo:
// - Usa VAPID (Voluntary Application Server Identification)
// - Criptografa payload com chaves da subscription
// - Envia para endpoint do navegador
//
// Env vars necessárias:
// - VAPID_PUBLIC_KEY: Chave pública VAPID
// - VAPID_PRIVATE_KEY: Chave privada VAPID
// - VAPID_SUBJECT: Identificador do servidor (mailto:email@example.com)
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
  body: string;
  data?: Record<string, unknown>;
}

interface PushSubscription {
  endpoint: string;
  auth: string;
  p256dh: string;
}

// ─── Gerar JWT VAPID ─────────────────────────────────────────────────────
async function generateVAPIDJWT(
  publicKey: string,
  privateKey: string,
  subject: string,
  audience: string
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { typ: "JWT", alg: "ES256" };
  const payload = {
    aud: audience,
    exp: now + 3600,
    sub: subject,
  };

  const encoder = new TextEncoder();
  const headerB64 = base64url(encoder.encode(JSON.stringify(header)));
  const payloadB64 = base64url(encoder.encode(JSON.stringify(payload)));
  const signingInput = `${headerB64}.${payloadB64}`;

  // Importar chave privada
  const pemKey = privateKey.replace(/\\n/g, "\n");
  const pemBody = pemKey
    .replace("-----BEGIN EC PRIVATE KEY-----", "")
    .replace("-----END EC PRIVATE KEY-----", "")
    .replace(/\s/g, "");

  const keyBytes = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes,
    { name: "ECDSA", namedCurve: "P-256", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "ECDSA",
    cryptoKey,
    encoder.encode(signingInput)
  );

  const signatureB64 = base64url(new Uint8Array(signature));
  return `${signingInput}.${signatureB64}`;
}

// ─── Criptografar payload com chaves da subscription ──────────────────────
async function encryptPayload(
  payload: string,
  p256dh: string,
  auth: string
): Promise<{ ciphertext: Uint8Array; salt: Uint8Array; serverPublicKey: Uint8Array }> {
  const encoder = new TextEncoder();
  const payloadBytes = encoder.encode(payload);

  // Gerar salt aleatório (16 bytes)
  const salt = crypto.getRandomValues(new Uint8Array(16));

  // Importar chaves
  const p256dhKey = await crypto.subtle.importKey(
    "raw",
    Uint8Array.from(atob(p256dh), (c) => c.charCodeAt(0)),
    { name: "ECDH", namedCurve: "P-256" },
    false,
    []
  );

  const authKey = Uint8Array.from(atob(auth), (c) => c.charCodeAt(0));

  // Gerar par de chaves do servidor
  const serverKeyPair = await crypto.subtle.generateKey(
    { name: "ECDH", namedCurve: "P-256" },
    true,
    ["deriveBits"]
  );

  // Derivar bits compartilhados
  const sharedBits = await crypto.subtle.deriveBits(
    { name: "ECDH", public: p256dhKey },
    serverKeyPair.privateKey,
    256
  );

  // Derivar chaves de criptografia
  const ikm = new Uint8Array(sharedBits);
  const prk = await crypto.subtle.sign("HMAC", authKey, ikm);

  // Usar HKDF para derivar chaves
  const info = encoder.encode("WebPush: info\x00");
  const infoWithLength = new Uint8Array(info.length + 1);
  infoWithLength.set(info);
  infoWithLength[info.length] = 1;

  const keyMaterial = await crypto.subtle.sign(
    "HMAC",
    new Uint8Array(prk),
    infoWithLength
  );

  // Usar primeiros 16 bytes como chave AES-GCM
  const encryptionKey = keyMaterial.slice(0, 16);
  const key = await crypto.subtle.importKey(
    "raw",
    encryptionKey,
    "AES-GCM",
    false,
    ["encrypt"]
  );

  // Gerar IV (12 bytes)
  const iv = crypto.getRandomValues(new Uint8Array(12));

  // Criptografar
  const ciphertext = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    key,
    payloadBytes
  );

  // Exportar chave pública do servidor
  const serverPublicKey = await crypto.subtle.exportKey(
    "raw",
    serverKeyPair.publicKey
  );

  return {
    ciphertext: new Uint8Array(ciphertext),
    salt,
    serverPublicKey: new Uint8Array(serverPublicKey),
  };
}

// ─── Enviar Web Push ──────────────────────────────────────────────────────
async function sendWebPush(
  subscription: PushSubscription,
  payload: string,
  vapidJWT: string
): Promise<boolean> {
  try {
    // Criptografar payload
    const encrypted = await encryptPayload(
      payload,
      subscription.p256dh,
      subscription.auth
    );

    // Preparar corpo da requisição
    const body = new Uint8Array(
      encrypted.salt.length +
        1 +
        encrypted.serverPublicKey.length +
        encrypted.ciphertext.length
    );

    let offset = 0;
    body.set(encrypted.salt, offset);
    offset += encrypted.salt.length;
    body[offset] = encrypted.serverPublicKey.length;
    offset += 1;
    body.set(encrypted.serverPublicKey, offset);
    offset += encrypted.serverPublicKey.length;
    body.set(encrypted.ciphertext, offset);

    // Enviar para endpoint
    const response = await fetch(subscription.endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/octet-stream",
        "Content-Encoding": "aes128gcm",
        "Authorization": `vapid t=${vapidJWT}`,
        "TTL": "24",
      },
      body,
    });

    if (response.status === 201 || response.status === 200) {
      console.log(`[web-push] Push enviado com sucesso para ${subscription.endpoint.substring(0, 50)}...`);
      return true;
    } else if (response.status === 410) {
      console.warn(`[web-push] Subscription expirada: ${subscription.endpoint.substring(0, 50)}...`);
      return false;
    } else {
      console.error(`[web-push] Erro ao enviar: ${response.status} ${response.statusText}`);
      return false;
    }
  } catch (error) {
    console.error(`[web-push] Erro ao enviar Web Push: ${error}`);
    return false;
  }
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload: NotificationPayload = await req.json();
    const { user_id, notification_type, title, body, data } = payload;

    if (!user_id || !body) {
      return new Response(
        JSON.stringify({ error: "user_id and body are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`[web-push] Enviando notificação para ${user_id}: ${notification_type}`);

    // Criar cliente Supabase
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // Buscar subscriptions do usuário (plataforma web)
    const { data: subscriptions, error: subscriptionError } = await supabase
      .from("push_subscriptions")
      .select("*")
      .eq("user_id", user_id)
      .eq("platform", "web")
      .eq("is_active", true);

    if (subscriptionError || !subscriptions || subscriptions.length === 0) {
      console.warn(`[web-push] Usuário ${user_id} sem subscriptions web`);
      return new Response(
        JSON.stringify({ message: "No web push subscriptions" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Carregar VAPID keys
    const vapidPublicKey = Deno.env.get("VAPID_PUBLIC_KEY");
    const vapidPrivateKey = Deno.env.get("VAPID_PRIVATE_KEY");
    const vapidSubject = Deno.env.get("VAPID_SUBJECT");

    if (!vapidPublicKey || !vapidPrivateKey || !vapidSubject) {
      return new Response(
        JSON.stringify({ error: "VAPID keys not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Preparar payload de notificação
    const notificationPayload = JSON.stringify({
      notification: {
        title: title || "NexusHub",
        body,
      },
      data: {
        type: notification_type,
        ...data,
      },
    });

    // Gerar VAPID JWT
    const vapidJWT = await generateVAPIDJWT(
      vapidPublicKey,
      vapidPrivateKey,
      vapidSubject,
      subscriptions[0].endpoint.split("/").slice(0, 3).join("/") // Audience é origin
    );

    // Enviar para cada subscription
    const results = await Promise.all(
      subscriptions.map(async (subscription) => {
        const success = await sendWebPush(
          {
            endpoint: subscription.endpoint,
            auth: subscription.auth,
            p256dh: subscription.p256dh,
          },
          notificationPayload,
          vapidJWT
        );

        if (success) {
          // Atualizar last_used_at
          await supabase
            .from("push_subscriptions")
            .update({ last_used_at: new Date().toISOString() })
            .eq("id", subscription.id);
        } else if (subscription.endpoint.includes("fcm.googleapis.com")) {
          // Se falhar, marcar como inativa
          await supabase
            .from("push_subscriptions")
            .update({ is_active: false })
            .eq("id", subscription.id);
        }

        return { subscription_id: subscription.id, success };
      })
    );

    const successCount = results.filter((r) => r.success).length;

    console.log(`[web-push] ${successCount}/${results.length} notificações enviadas`);

    return new Response(
      JSON.stringify({
        success: successCount > 0,
        sent: successCount,
        total: results.length,
        results,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error(`[web-push] Erro: ${error.message}`);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
