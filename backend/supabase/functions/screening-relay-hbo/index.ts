// =============================================================================
// screening-relay-hbo — Edge Function relay para HBO Max / Max
//
// Recebe o token de acesso do usuário e o contentId,
// chama a API Max playbackInfo e retorna HLS + licença Widevine.
//
// Baseado na engenharia reversa do Rave APK.
// Endpoint: https://comet.api.hbo.com/content/{contentId}/playbackInfo
// =============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ── Constantes HBO Max / Max ──────────────────────────────────────────────────
const HBO_API_BASE = "https://comet.api.hbo.com";
const HBO_CLIENT_ID = "585b02c8-dbe1-432f-b1bb-11cf670fbeb0"; // extraído do Rave APK

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { contentId, accessToken } = await req.json();

    if (!contentId || !accessToken) {
      return new Response(
        JSON.stringify({
          error: "Parâmetros obrigatórios: contentId, accessToken",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // ── Buscar playbackInfo ────────────────────────────────────────────────
    const playbackUrl = `${HBO_API_BASE}/content/${contentId}/playbackInfo`;

    const playbackBody = {
      deviceInfo: {
        deviceType: "ANDROID_TV",
        deviceId: "nexushub_" + Date.now(),
        appVersion: "52.50.0.14",
        sdkVersion: "1.0",
        platform: "android",
        osVersion: "13",
        model: "Pixel 7",
        manufacturer: "Google",
      },
      drmInfo: {
        drmType: "WIDEVINE",
        drmLevel: "L3",
      },
      contentPreferences: {
        colorimetry: ["SDR"],
        frameRates: ["SIXTY"],
        manifestType: "DASH",
        protocol: "HTTPS",
        videoCodecs: ["H264"],
        audioCodecs: ["AAC"],
        subtitleFormats: ["WEBVTT"],
      },
    };

    const playbackResponse = await fetch(playbackUrl, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-Client-Id": HBO_CLIENT_ID,
        "User-Agent":
          "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 "
          + "(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        "Referer": "https://www.max.com/",
        "Origin": "https://www.max.com",
      },
      body: JSON.stringify(playbackBody),
    });

    if (!playbackResponse.ok) {
      const errorText = await playbackResponse.text();
      return new Response(
        JSON.stringify({
          error: `HBO Max playback error: ${playbackResponse.status}`,
          detail: errorText.substring(0, 500),
        }),
        {
          status: playbackResponse.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const playbackData = await playbackResponse.json();

    // ── Extrair URL DASH/HLS e dados DRM ──────────────────────────────────
    const manifests = playbackData?.manifests ?? [];
    let hlsUrl: string | null = null;
    let licenseUrl: string | null = null;
    let pssh: string | null = null;

    // Preferir DASH
    for (const manifest of manifests) {
      if (manifest?.type === "DASH" || manifest?.url?.includes(".mpd")) {
        hlsUrl = manifest.url;
        break;
      }
    }

    // Fallback para HLS
    if (!hlsUrl) {
      for (const manifest of manifests) {
        if (manifest?.type === "HLS" || manifest?.url?.includes(".m3u8")) {
          hlsUrl = manifest.url;
          break;
        }
      }
    }

    // Extrair dados DRM
    const drm = playbackData?.drm ?? {};
    licenseUrl = drm?.widevine?.licenseUrl ?? null;
    pssh = drm?.widevine?.pssh ?? null;

    if (!hlsUrl) {
      return new Response(
        JSON.stringify({
          error: "Nenhum stream encontrado no manifest HBO Max",
          manifests: manifests.length,
        }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    return new Response(
      JSON.stringify({
        hlsUrl,
        licenseUrl,
        pssh,
        platform: "hbo",
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: String(error) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
