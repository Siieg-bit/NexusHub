// ============================================================================
// NEXUSHUB - Edge Function: Agora RTC Token Generator (AccessToken2 / Token 007)
// Endpoint: POST /functions/v1/agora-token
//
// Gera tokens temporários para chamadas de voz/vídeo via Agora.io.
// Implementação correta do formato Token 007 com zlib deflate.
//
// Body: { "channelName": "string", "uid": number, "role": "publisher"|"subscriber" }
// Response: { "token": "string", "uid": number, "channelName": "string" }
// ============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { deflate } from "https://deno.land/x/compress@v0.4.5/zlib/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ── Agora Credentials (via env vars) ──
const APP_ID = Deno.env.get("AGORA_APP_ID") ?? "";
const APP_CERTIFICATE = Deno.env.get("AGORA_APP_CERTIFICATE") ?? "";

const RATE_LIMIT_MAX = 10;
const RATE_LIMIT_WINDOW_SECONDS = 60;

// ── Token 007 constants ──
const VERSION = "007";

// Service types
const kRtcServiceType = 1;

// RTC Privileges
const kPrivilegeJoinChannel = 1;
const kPrivilegePublishAudioStream = 2;
const kPrivilegePublishVideoStream = 3;
const kPrivilegePublishDataStream = 4;

// ── ByteBuf (Little-Endian binary serializer) ──
class ByteBuf {
  private buf: Uint8Array;
  private pos: number;

  constructor(size = 2048) {
    this.buf = new Uint8Array(size);
    this.pos = 0;
  }

  putUint16(v: number): this {
    this.buf[this.pos++] = v & 0xff;
    this.buf[this.pos++] = (v >> 8) & 0xff;
    return this;
  }

  putUint32(v: number): this {
    this.buf[this.pos++] = v & 0xff;
    this.buf[this.pos++] = (v >> 8) & 0xff;
    this.buf[this.pos++] = (v >> 16) & 0xff;
    this.buf[this.pos++] = (v >> 24) & 0xff;
    return this;
  }

  putBytes(bytes: Uint8Array): this {
    this.putUint16(bytes.length);
    this.buf.set(bytes, this.pos);
    this.pos += bytes.length;
    return this;
  }

  putString(s: string): this {
    return this.putBytes(new TextEncoder().encode(s));
  }

  putTreeMapUint32(map: Record<number, number>): this {
    const keys = Object.keys(map).map(Number).sort((a, b) => a - b);
    this.putUint16(keys.length);
    for (const k of keys) {
      this.putUint16(k);
      this.putUint32(map[k]);
    }
    return this;
  }

  pack(): Uint8Array {
    return this.buf.slice(0, this.pos);
  }
}

// ── HMAC-SHA256 ──
async function hmacSha256(key: Uint8Array, msg: Uint8Array): Promise<Uint8Array> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw", key, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]
  );
  return new Uint8Array(await crypto.subtle.sign("HMAC", cryptoKey, msg));
}

// ── Hex helpers ──
function hexToBytes(hex: string): Uint8Array {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    bytes[i / 2] = parseInt(hex.substring(i, i + 2), 16);
  }
  return bytes;
}

// ── Concat Uint8Arrays ──
function concat(...arrays: Uint8Array[]): Uint8Array {
  const total = arrays.reduce((s, a) => s + a.length, 0);
  const out = new Uint8Array(total);
  let offset = 0;
  for (const a of arrays) { out.set(a, offset); offset += a.length; }
  return out;
}

// ── Base64 encode ──
function base64(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary);
}

// ── Generate Agora AccessToken2 (Token 007) ──
async function generateToken007(
  appId: string,
  appCertificate: string,
  channelName: string,
  uid: number,
  role: number, // 1 = publisher, 2 = subscriber
  tokenExpireSeconds: number,
  privilegeExpireSeconds: number,
): Promise<string> {
  const issueTs = Math.floor(Date.now() / 1000);
  const expire = tokenExpireSeconds;
  const salt = Math.floor(Math.random() * 99999998) + 1;
  const privilegeExpireTs = issueTs + privilegeExpireSeconds;

  // ── Signing key: HMAC(HMAC(appCertificate, issueTs), salt) ──
  const certBytes = hexToBytes(appCertificate);
  const issueTsBuf = new ByteBuf().putUint32(issueTs).pack();
  const saltBuf = new ByteBuf().putUint32(salt).pack();
  const signing1 = await hmacSha256(certBytes, issueTsBuf);
  const signing = await hmacSha256(signing1, saltBuf);

  // ── Build RTC service payload ──
  const uidStr = uid === 0 ? "" : `${uid}`;
  const privileges: Record<number, number> = {
    [kPrivilegeJoinChannel]: privilegeExpireTs,
  };
  if (role === 1) {
    privileges[kPrivilegePublishAudioStream] = privilegeExpireTs;
    privileges[kPrivilegePublishVideoStream] = privilegeExpireTs;
    privileges[kPrivilegePublishDataStream] = privilegeExpireTs;
  }

  // Service type (uint16) + privileges map + channel_name (string) + uid (string)
  const servicePrivilegesBuf = new ByteBuf().putTreeMapUint32(privileges).pack();
  const serviceChannelBuf = new ByteBuf().putString(channelName).putString(uidStr).pack();
  const serviceBuf = concat(
    new ByteBuf().putUint16(kRtcServiceType).pack(),
    servicePrivilegesBuf,
    serviceChannelBuf,
  );

  // ── signing_info: appId + issueTs + expire + salt + numServices + service ──
  const signingInfo = new ByteBuf()
    .putString(appId)
    .putUint32(issueTs)
    .putUint32(expire)
    .putUint32(salt)
    .putUint16(1) // number of services
    .pack();

  const signingInfoFull = concat(signingInfo, serviceBuf);

  // ── Signature: HMAC(signing, signingInfoFull) ──
  const signature = await hmacSha256(signing, signingInfoFull);

  // ── Content: putString(signature) + signingInfoFull ──
  const content = concat(
    new ByteBuf().putBytes(signature).pack(),
    signingInfoFull,
  );

  // ── Compress with zlib deflate ──
  const compressed = deflate(content);

  return `${VERSION}${base64(compressed)}`;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ── Auth ──
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Token de autenticação ausente" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Não autenticado" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── Rate limiting ──
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const windowStart = new Date(Date.now() - RATE_LIMIT_WINDOW_SECONDS * 1000).toISOString();
    const { count } = await supabaseAdmin
      .from("rate_limit_log")
      .select("id", { count: "exact", head: true })
      .eq("user_id", user.id)
      .eq("action", "agora_token")
      .gte("created_at", windowStart);

    if ((count ?? 0) >= RATE_LIMIT_MAX) {
      return new Response(
        JSON.stringify({ error: "Rate limit excedido. Tente novamente em 1 minuto.", retry_after_seconds: RATE_LIMIT_WINDOW_SECONDS }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    await supabaseAdmin.from("rate_limit_log").insert({ user_id: user.id, action: "agora_token" });

    // ── Parse body ──
    const body = await req.json();
    const channelName = body.channelName as string;
    const uid = (body.uid as number) || 0;
    const role = body.role === "subscriber" ? 2 : 1;

    if (!channelName) {
      return new Response(
        JSON.stringify({ error: "channelName é obrigatório" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!APP_ID || !APP_CERTIFICATE) {
      return new Response(
        JSON.stringify({ error: "Credenciais Agora não configuradas" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const tokenExpireSeconds = 3600;
    const privilegeExpireSeconds = 3600;

    const token = await generateToken007(
      APP_ID,
      APP_CERTIFICATE,
      channelName,
      uid,
      role,
      tokenExpireSeconds,
      privilegeExpireSeconds,
    );

    const expiresAt = Math.floor(Date.now() / 1000) + tokenExpireSeconds;

    return new Response(
      JSON.stringify({ token, uid, channelName, expiresAt }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: `Erro interno: ${error.message}` }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
