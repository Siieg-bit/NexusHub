// =============================================================================
// screening-relay-crunchyroll — Edge Function relay para Crunchyroll
//
// Recebe o access_token do usuário (OAuth2) e o episodeId,
// chama a CMS API do Crunchyroll e retorna HLS + licença Widevine.
//
// Baseado na engenharia reversa do Rave APK.
// Endpoints: https://www.crunchyroll.com/content/v2/cms/videos/{id}/streams
// =============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ── Constantes Crunchyroll ────────────────────────────────────────────────────
const CR_API_BASE = "https://www.crunchyroll.com";
const CR_CMS_BASE = "https://www.crunchyroll.com/content/v2/cms";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { episodeId, accessToken, locale = "pt-BR" } = await req.json();

    if (!episodeId || !accessToken) {
      return new Response(
        JSON.stringify({
          error: "Parâmetros obrigatórios: episodeId, accessToken",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // ── Buscar streams do episódio ─────────────────────────────────────────
    const streamsUrl = `${CR_CMS_BASE}/videos/${episodeId}/streams`;

    const streamsResponse = await fetch(
      `${streamsUrl}?locale=${locale}`,
      {
        method: "GET",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
          "Accept": "application/json",
          "User-Agent":
            "Crunchyroll/3.46.2 Android/13 okhttp/4.12.0",
          "Referer": "https://www.crunchyroll.com/",
          "Origin": "https://www.crunchyroll.com",
        },
      }
    );

    if (!streamsResponse.ok) {
      const errorText = await streamsResponse.text();
      return new Response(
        JSON.stringify({
          error: `Crunchyroll streams error: ${streamsResponse.status}`,
          detail: errorText.substring(0, 500),
        }),
        {
          status: streamsResponse.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const streamsData = await streamsResponse.json();

    // ── Extrair URL HLS e dados DRM ────────────────────────────────────────
    const data = streamsData?.data?.[0] ?? {};
    const streams = data?.streams ?? {};

    // Preferir DASH com Widevine
    let hlsUrl: string | null = null;
    let licenseUrl: string | null = null;
    let pssh: string | null = null;

    // DASH com Widevine (melhor qualidade)
    const dashWidevine = streams?.drm_dash_widevine ?? {};
    const dashWidevineEntries = Object.values(dashWidevine) as any[];
    if (dashWidevineEntries.length > 0) {
      hlsUrl = dashWidevineEntries[0]?.url ?? null;
      licenseUrl = dashWidevineEntries[0]?.licenseUrl ?? null;
    }

    // Fallback para HLS adaptativo (sem DRM — para conteúdo gratuito)
    if (!hlsUrl) {
      const hlsAdaptive = streams?.adaptive_hls ?? {};
      const hlsEntries = Object.values(hlsAdaptive) as any[];
      if (hlsEntries.length > 0) {
        // Preferir versão sem hardsub
        const noHardsub = hlsEntries.find((e: any) => !e?.hardsub_locale);
        hlsUrl = (noHardsub ?? hlsEntries[0])?.url ?? null;
      }
    }

    if (!hlsUrl) {
      return new Response(
        JSON.stringify({
          error: "Nenhum stream encontrado para o episódio Crunchyroll",
          availableStreams: Object.keys(streams),
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
        platform: "crunchyroll",
        isDrm: !!licenseUrl,
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
