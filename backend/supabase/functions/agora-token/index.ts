// ============================================================================
// NEXUSHUB - Edge Function: Agora RTC Token Generator
// Endpoint: POST /functions/v1/agora-token
//
// Gera tokens temporários para chamadas de voz/vídeo via Agora.io.
// O token expira em 1 hora (3600s) por padrão.
//
// Body: { "channelName": "string", "uid": number, "role": "publisher"|"subscriber" }
// Response: { "token": "string", "uid": number, "channelName": "string" }
// ============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ── Agora Credentials ──
const APP_ID = "SEU_AGORA_APP_ID_AQUI";
const APP_CERTIFICATE = "SEU_AGORA_APP_CERTIFICATE_AQUI";

// ── Token Builder (inline, Agora RtcTokenBuilder logic) ──
// Based on https://github.com/AgoraIO/Tools/tree/master/DynamicKey/AgoraDynamicKey

const VERSION = "007";
const VERSION_LENGTH = 3;

// Privileges
const kJoinChannel = 1;
const kPublishAudioStream = 2;
const kPublishVideoStream = 3;
const kPublishDataStream = 4;

function encodeHMac(key: Uint8Array, message: Uint8Array): Uint8Array {
  // HMAC-SHA256 implementation using Web Crypto API (sync workaround)
  // We'll use the async version wrapped
  throw new Error("Use async version");
}

async function hmacSha256(key: Uint8Array, message: Uint8Array): Promise<Uint8Array> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    key,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", cryptoKey, message);
  return new Uint8Array(sig);
}

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function hexToBytes(hex: string): Uint8Array {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    bytes[i / 2] = parseInt(hex.substring(i, i + 2), 16);
  }
  return bytes;
}

function packUint16(val: number): Uint8Array {
  const buf = new Uint8Array(2);
  buf[0] = val & 0xff;
  buf[1] = (val >> 8) & 0xff;
  return buf;
}

function packUint32(val: number): Uint8Array {
  const buf = new Uint8Array(4);
  buf[0] = val & 0xff;
  buf[1] = (val >> 8) & 0xff;
  buf[2] = (val >> 16) & 0xff;
  buf[3] = (val >> 24) & 0xff;
  return buf;
}

function packString(str: string): Uint8Array {
  const encoder = new TextEncoder();
  const strBytes = encoder.encode(str);
  const lenBytes = packUint16(strBytes.length);
  const result = new Uint8Array(lenBytes.length + strBytes.length);
  result.set(lenBytes);
  result.set(strBytes, lenBytes.length);
  return result;
}

function packMapUint32(map: Map<number, number>): Uint8Array {
  const parts: Uint8Array[] = [];
  parts.push(packUint16(map.size));
  for (const [key, value] of map) {
    parts.push(packUint16(key));
    parts.push(packUint32(value));
  }
  let totalLen = 0;
  for (const p of parts) totalLen += p.length;
  const result = new Uint8Array(totalLen);
  let offset = 0;
  for (const p of parts) {
    result.set(p, offset);
    offset += p.length;
  }
  return result;
}

function concat(...arrays: Uint8Array[]): Uint8Array {
  let totalLen = 0;
  for (const a of arrays) totalLen += a.length;
  const result = new Uint8Array(totalLen);
  let offset = 0;
  for (const a of arrays) {
    result.set(a, offset);
    offset += a.length;
  }
  return result;
}

function base64Encode(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

async function generateAccessToken(
  appId: string,
  appCertificate: string,
  channelName: string,
  uid: number,
  role: number, // 1 = publisher, 2 = subscriber
  privilegeExpiredTs: number
): Promise<string> {
  const encoder = new TextEncoder();

  // Build privileges map
  const privileges = new Map<number, number>();
  privileges.set(kJoinChannel, privilegeExpiredTs);
  if (role === 1) {
    privileges.set(kPublishAudioStream, privilegeExpiredTs);
    privileges.set(kPublishVideoStream, privilegeExpiredTs);
    privileges.set(kPublishDataStream, privilegeExpiredTs);
  }

  // Generate message
  const salt = Math.floor(Math.random() * 0xffffffff);
  const ts = Math.floor(Date.now() / 1000);
  const uidStr = uid === 0 ? "" : uid.toString();

  const messageBytes = concat(
    packUint32(salt),
    packUint32(ts),
    packMapUint32(privileges)
  );

  // Generate signature
  const toSign = concat(
    encoder.encode(appId),
    encoder.encode(channelName),
    encoder.encode(uidStr),
    messageBytes
  );

  const sign = await hmacSha256(hexToBytes(appCertificate), toSign);

  // Pack token content
  const content = concat(
    packString(bytesToHex(sign)),
    packUint32(0), // crc_channel_name placeholder
    packUint32(0), // crc_uid placeholder
    packString(base64Encode(messageBytes))
  );

  // Final token
  return `${VERSION}${appId}${base64Encode(content)}`;
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Verificar autenticação
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Token de autenticação ausente" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Verificar que o usuário está autenticado via Supabase
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: { headers: { Authorization: authHeader } },
      }
    );

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Não autenticado" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Parse body
    const body = await req.json();
    const channelName = body.channelName as string;
    const uid = (body.uid as number) || 0;
    const role = body.role === "subscriber" ? 2 : 1; // default publisher

    if (!channelName) {
      return new Response(
        JSON.stringify({ error: "channelName é obrigatório" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Token expira em 1 hora
    const expirationTimeInSeconds = 3600;
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

    const token = await generateAccessToken(
      APP_ID,
      APP_CERTIFICATE,
      channelName,
      uid,
      role,
      privilegeExpiredTs
    );

    return new Response(
      JSON.stringify({
        token,
        uid,
        channelName,
        expiresAt: privilegeExpiredTs,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: `Erro interno: ${error.message}` }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
