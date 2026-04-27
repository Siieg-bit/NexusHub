// =============================================================================
// screening-relay-amazon — Edge Function relay para Amazon Prime Video
//
// Recebe os cookies de sessão do usuário e o ASIN do conteúdo,
// chama GetPlaybackResources da API Amazon e retorna HLS + licença Widevine.
//
// Baseado na engenharia reversa do Rave APK.
// deviceTypeID: A28RQHJKHM2A2W (extraído do Rave APK — Android TV)
// Endpoint: https://atv-ps.amazon.com/cdp/catalog/GetPlaybackResources
// =============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ── Constantes Amazon ─────────────────────────────────────────────────────────
const AMAZON_DEVICE_TYPE_ID = "A28RQHJKHM2A2W"; // Android TV (extraído do Rave APK)
const AMAZON_FIRMWARE = "fmw:22010451392-prod:1";

// Endpoints regionais (extraídos do Rave APK)
const AMAZON_ENDPOINTS: Record<string, string> = {
  us: "https://atv-ps.amazon.com",
  uk: "https://atv-ps.amazon.co.uk",
  de: "https://atv-ps.amazon.de",
  jp: "https://atv-ps.amazon.co.jp",
  br: "https://atv-ps.primevideo.com",
  default: "https://atv-ps.primevideo.com",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { asin, cookies, region = "default", deviceId } = await req.json();

    if (!asin || !cookies) {
      return new Response(
        JSON.stringify({
          error: "Parâmetros obrigatórios: asin, cookies",
          note: "cookies deve ser a string completa de cookies da sessão Amazon",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const baseUrl = AMAZON_ENDPOINTS[region] ?? AMAZON_ENDPOINTS.default;
    const endpoint = `${baseUrl}/cdp/catalog/GetPlaybackResources`;

    // ── Parâmetros de playback (extraídos do Rave APK) ─────────────────────
    const params = new URLSearchParams({
      asin,
      consumptionType: "Streaming",
      desiredResources: "PlaybackUrls,AudioVideoUrls,CatalogMetadata,ForcedNarratives,SubtitlePresets,SubtitleUrls,TransitionTimecodes,TrickplayUrls,CuepointPlaylist,XRayMetadata,PlaybackSettings",
      deviceID: deviceId ?? "nexushub_android_" + Date.now(),
      deviceTypeID: AMAZON_DEVICE_TYPE_ID,
      firmware: AMAZON_FIRMWARE,
      gascEnabled: "false",
      marketplaceID: "ATVPDKIKX0DER",
      resourceUsage: "ImmediateConsumption",
      videoMaterialType: "Feature",
      operatingSystemName: "Android",
      operatingSystemVersion: "13",
      customerID: "", // será preenchido via cookie
      token: "", // será preenchido via cookie
      deviceDrmOverride: "CENC",
      deviceStreamingTechnologyOverride: "DASH",
      deviceProtocolOverride: "Https",
      deviceBitrateAdaptationsOverride: "CVBR%2CCBR",
      audioTrackId: "all",
    });

    const playbackResponse = await fetch(`${endpoint}?${params.toString()}`, {
      method: "GET",
      headers: {
        Cookie: cookies,
        "User-Agent":
          "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 "
          + "(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        "Accept": "application/json",
        "Accept-Language": "pt-BR,pt;q=0.9,en;q=0.8",
        "Referer": "https://www.primevideo.com/",
        "Origin": "https://www.primevideo.com",
      },
    });

    if (!playbackResponse.ok) {
      const errorText = await playbackResponse.text();
      return new Response(
        JSON.stringify({
          error: `Amazon playback error: ${playbackResponse.status}`,
          detail: errorText.substring(0, 500),
        }),
        {
          status: playbackResponse.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const playbackData = await playbackResponse.json();

    // ── Extrair URL HLS/DASH e dados DRM ──────────────────────────────────
    const audioVideoUrls = playbackData?.audioVideoUrls ?? {};
    const avUrlSets = audioVideoUrls?.avUrlInfoList ?? [];

    let hlsUrl: string | null = null;
    let licenseUrl: string | null = null;

    // Preferir DASH (melhor qualidade com DRM)
    for (const urlSet of avUrlSets) {
      const url = urlSet?.url;
      if (url?.includes(".mpd") || urlSet?.streamingTechnology === "DASH") {
        hlsUrl = url;
        break;
      }
    }

    // Fallback para HLS
    if (!hlsUrl) {
      for (const urlSet of avUrlSets) {
        const url = urlSet?.url;
        if (url?.includes(".m3u8")) {
          hlsUrl = url;
          break;
        }
      }
    }

    // Extrair URL de licença Widevine
    const widevineLicense = playbackData?.widevineLicense ?? {};
    licenseUrl = widevineLicense?.licenseURL ?? null;

    if (!hlsUrl) {
      return new Response(
        JSON.stringify({
          error: "Nenhum stream encontrado no manifest Amazon",
          urlSets: avUrlSets.length,
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
        platform: "amazon",
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
