// =============================================================================
// screening-relay-disney — Edge Function relay para Disney+
//
// Recebe o token de acesso do usuário (obtido via OAuth no WebView)
// e o contentId, retorna o manifest HLS + URL de licença Widevine.
//
// Baseado na engenharia reversa do Rave APK.
// Client-ID Disney+: disney-svod-3d9324fc (extraído do Rave APK)
// Endpoint BAMTech: https://disney.playback.edge.bamgrid.com/media/{contentId}/scenarios/ctr-limited
// =============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ── Constantes Disney+ ────────────────────────────────────────────────────────
const DISNEY_CLIENT_ID = "disney-svod-3d9324fc"; // extraído do Rave APK
const DISNEY_API_BASE = "https://disney.api.edge.bamgrid.com";
const DISNEY_PLAYBACK_BASE = "https://disney.playback.edge.bamgrid.com";
const DISNEY_TOKEN_ENDPOINT = `${DISNEY_API_BASE}/token`;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { contentId, accessToken, refreshToken } = await req.json();

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

    // ── Buscar o manifest de playback via BAMTech ──────────────────────────
    // Cenário "ctr-limited" retorna DASH/HLS com DRM Widevine
    const playbackUrl = `${DISNEY_PLAYBACK_BASE}/media/${contentId}/scenarios/ctr-limited`;

    const playbackResponse = await fetch(playbackUrl, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
        "Accept": "application/vnd.media-service+json; version=5",
        "X-BAMSDK-Client-ID": DISNEY_CLIENT_ID,
        "X-BAMSDK-Platform": "android-tv",
        "X-BAMSDK-Version": "4.9",
        "User-Agent":
          "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 "
          + "(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        "Referer": "https://www.disneyplus.com/",
        "Origin": "https://www.disneyplus.com",
      },
    });

    if (!playbackResponse.ok) {
      // Tentar refresh do token se expirado
      if (playbackResponse.status === 401 && refreshToken) {
        const refreshed = await _refreshDisneyToken(refreshToken);
        if (refreshed) {
          // Retornar novo token para o cliente fazer nova requisição
          return new Response(
            JSON.stringify({
              error: "token_expired",
              newAccessToken: refreshed.accessToken,
              newRefreshToken: refreshed.refreshToken,
            }),
            {
              status: 401,
              headers: { ...corsHeaders, "Content-Type": "application/json" },
            }
          );
        }
      }

      const errorText = await playbackResponse.text();
      return new Response(
        JSON.stringify({
          error: `Disney+ playback error: ${playbackResponse.status}`,
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
    const stream = playbackData?.stream;
    const sources = stream?.sources ?? [];

    let hlsUrl: string | null = null;
    let licenseUrl: string | null = null;
    let pssh: string | null = null;

    // Preferir HLS sobre DASH
    for (const source of sources) {
      if (source?.type === "application/x-mpegURL" || source?.url?.includes(".m3u8")) {
        hlsUrl = source.url;
        break;
      }
    }

    // Fallback para DASH
    if (!hlsUrl) {
      for (const source of sources) {
        if (source?.type === "application/dash+xml" || source?.url?.includes(".mpd")) {
          hlsUrl = source.url;
          break;
        }
      }
    }

    // Extrair dados DRM
    const drm = stream?.drm ?? {};
    licenseUrl = drm?.widevine?.licenseAcquisitionUrl ?? null;
    pssh = drm?.widevine?.pssh ?? null;

    if (!hlsUrl) {
      return new Response(
        JSON.stringify({
          error: "Nenhum stream encontrado no manifest Disney+",
          sources: sources.length,
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
        platform: "disney",
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

// ── Helper: refresh do token Disney+ ─────────────────────────────────────────
async function _refreshDisneyToken(
  refreshToken: string
): Promise<{ accessToken: string; refreshToken: string } | null> {
  try {
    const response = await fetch(
      "https://disney.api.edge.bamgrid.com/token",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          Authorization: `Basic ${btoa(`${DISNEY_CLIENT_ID}:`)}`,
        },
        body: new URLSearchParams({
          grant_type: "refresh_token",
          refresh_token: refreshToken,
        }).toString(),
      }
    );

    if (!response.ok) return null;
    const data = await response.json();
    return {
      accessToken: data.access_token,
      refreshToken: data.refresh_token ?? refreshToken,
    };
  } catch {
    return null;
  }
}
