// =============================================================================
// screening-relay-netflix — Edge Function relay para Netflix
//
// Recebe os cookies de sessão do usuário (NetflixId + SecureNetflixId)
// e o movieId, e retorna o manifest HLS + URL do servidor de licença Widevine.
//
// Baseado na engenharia reversa do Rave APK (wemesh.ca relay).
// Endpoints Netflix: pbo_manifests, pbo_licenses (Shakti API)
// =============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ── Constantes Netflix ────────────────────────────────────────────────────────
const NETFLIX_API_BASE = "https://www.netflix.com/nq/website/memberapi";
const NETFLIX_MANIFEST_ENDPOINT =
  "https://www.netflix.com/api/shakti/mre/manifest";
const NETFLIX_LICENSE_ENDPOINT =
  "https://www.netflix.com/api/shakti/mre/license";

// Parâmetros de playback (extraídos do Rave APK)
const PLAYBACK_PARAMS = {
  type: "standard",
  viewableId: 0, // será substituído pelo movieId
  profiles: [
    "playready-h264mpl30-dash",
    "playready-h264mpl31-dash",
    "playready-h264mpl40-dash",
    "heaac-2-dash",
    "BIF240",
    "BIF320",
  ],
  flavor: "STANDARD",
  drmType: "widevine",
  drmVersion: 25,
  usePsshBox: true,
  isBranching: false,
  useHttpsStreams: true,
  imageSubtitleHeight: 513,
  uiVersion: "shakti-v25e4d3fa",
  uiPlatform: "SHAKTI",
  clientVersion: "6.0034.414.911",
  desiredVmaf: "plus_lts",
  supportsPreReleasePin: true,
  supportsWatermark: true,
  showAllSubDubTracks: false,
  videoOutputInfo: [
    {
      type: "DigitalVideoOutputDescriptor",
      outputType: "unknown",
      supportedHdcpVersions: ["1.4", "2.2"],
      isHdcpEngaged: false,
    },
  ],
  preferAssistiveAudio: false,
  isNonMember: false,
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { movieId, netflixId, secureNetflixId } = await req.json();

    if (!movieId || !netflixId || !secureNetflixId) {
      return new Response(
        JSON.stringify({
          error: "Parâmetros obrigatórios: movieId, netflixId, secureNetflixId",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // ── Construir cookie de sessão ──────────────────────────────────────────
    const cookieHeader = `NetflixId=${netflixId}; SecureNetflixId=${secureNetflixId}`;

    // ── Buscar o manifest de playback ──────────────────────────────────────
    const manifestBody = {
      ...PLAYBACK_PARAMS,
      viewableId: parseInt(movieId),
    };

    const manifestResponse = await fetch(NETFLIX_MANIFEST_ENDPOINT, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Cookie: cookieHeader,
        "User-Agent":
          "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 "
          + "(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        "X-Netflix.clientType": "akira",
        "X-Netflix.uiVersion": "v25e4d3fa",
        Referer: "https://www.netflix.com/",
        Origin: "https://www.netflix.com",
      },
      body: JSON.stringify(manifestBody),
    });

    if (!manifestResponse.ok) {
      const errorText = await manifestResponse.text();
      return new Response(
        JSON.stringify({
          error: `Netflix manifest error: ${manifestResponse.status}`,
          detail: errorText.substring(0, 500),
        }),
        {
          status: manifestResponse.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const manifestData = await manifestResponse.json();

    // ── Extrair URL HLS e PSSH (para Widevine) ─────────────────────────────
    const videoTracks = manifestData?.result?.video_tracks ?? [];
    const audioTracks = manifestData?.result?.audio_tracks ?? [];

    // Pegar o melhor stream de vídeo disponível
    let hlsUrl: string | null = null;
    let pssh: string | null = null;

    for (const track of videoTracks) {
      const streams = track?.streams ?? [];
      for (const stream of streams) {
        if (stream?.content_profile?.includes("dash") && stream?.urls?.length > 0) {
          hlsUrl = stream.urls[0].url;
          break;
        }
      }
      if (hlsUrl) break;
    }

    // Extrair PSSH para licença Widevine
    const drmContextId = manifestData?.result?.drm_context_id;
    const widevinePssh = manifestData?.result?.widevine_pssh;
    if (widevinePssh) pssh = widevinePssh;

    if (!hlsUrl) {
      return new Response(
        JSON.stringify({
          error: "Nenhum stream encontrado no manifest Netflix",
          tracks: videoTracks.length,
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
        licenseUrl: NETFLIX_LICENSE_ENDPOINT,
        pssh,
        drmContextId,
        cookieHeader,
        platform: "netflix",
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
