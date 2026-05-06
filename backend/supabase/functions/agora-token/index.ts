// Agora Token Edge Function
// Uses the official agora-token library via esm.sh for correct Token 007 generation.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { RtcTokenBuilder, RtcRole } from "https://esm.sh/agora-token@2.0.5";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const APP_ID = Deno.env.get("AGORA_APP_ID");
    const APP_CERTIFICATE = Deno.env.get("AGORA_APP_CERTIFICATE");

    if (!APP_ID || !APP_CERTIFICATE) {
      console.error("[agora-token] Missing AGORA_APP_ID or AGORA_APP_CERTIFICATE");
      return new Response(
        JSON.stringify({ error: "Server configuration error: missing Agora credentials" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const body = await req.json();
    const { channelName, uid, role, tokenType, expireTime } = body;

    if (!channelName) {
      return new Response(
        JSON.stringify({ error: "channelName is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Token expiry: default 3600 seconds (1 hour)
    const tokenExpireTime = expireTime ?? 3600;
    const privilegeExpireTime = tokenExpireTime;

    // UID: 0 means any user can join (token is not bound to a specific UID)
    const agoraUid = uid ?? 0;

    // Role: publisher (broadcaster) by default
    const agoraRole = role === "subscriber" ? RtcRole.SUBSCRIBER : RtcRole.PUBLISHER;

    let token: string;

    if (tokenType === "userAccount" || typeof agoraUid === "string") {
      // Generate token with user account (string UID)
      token = RtcTokenBuilder.buildTokenWithUserAccount(
        APP_ID,
        APP_CERTIFICATE,
        channelName,
        String(agoraUid),
        agoraRole,
        tokenExpireTime,
        privilegeExpireTime
      );
    } else {
      // Generate token with numeric UID
      token = RtcTokenBuilder.buildTokenWithUid(
        APP_ID,
        APP_CERTIFICATE,
        channelName,
        Number(agoraUid),
        agoraRole,
        tokenExpireTime,
        privilegeExpireTime
      );
    }

    console.log(`[agora-token] Generated token for channel=${channelName} uid=${agoraUid} role=${agoraRole} starts=${token.substring(0, 10)}...`);

    return new Response(
      JSON.stringify({ token }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("[agora-token] Error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
