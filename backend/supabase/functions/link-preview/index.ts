// ============================================================================
// Edge Function: link-preview
//
// Fallback web para URLs curtas do NexusHub.
// Quando o app não está instalado, o usuário abre nexushub.app/p/xK9mZ no
// browser. Esta função:
//   1. Resolve o short code no banco
//   2. Busca metadados do conteúdo (título, descrição, imagem)
//   3. Retorna HTML com meta tags Open Graph para preview em redes sociais
//   4. Redireciona para o deep link do app (nexushub://) ou App Store/Play Store
//
// Rota: GET /link-preview?path=/p/xK9mZ
// Ou:   GET /link-preview/p/xK9mZ  (via rewrite no config.toml)
// ============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const APP_SCHEME = "nexushub";
const APP_NAME = "NexusHub";
const BASE_URL = "https://nexushub.app";
const PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=app.nexushub";
const APP_STORE_URL = "https://apps.apple.com/app/nexushub/id000000000";
const DEFAULT_OG_IMAGE = "https://nexushub.app/og-image.png";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface ResolvedContent {
  type: string;
  targetId: string;
  title: string;
  description: string;
  imageUrl: string;
  deepLink: string;
}

// ─────────────────────────────────────────────────────────────
// Resolve short code → conteúdo
// ─────────────────────────────────────────────────────────────
async function resolveShortCode(
  supabase: ReturnType<typeof createClient>,
  prefix: string,
  code: string
): Promise<ResolvedContent | null> {
  // Para perfis (/u/) e comunidades (/c/), o code é o slug/amino_id
  if (prefix === "u") {
    const { data } = await supabase
      .from("profiles")
      .select("id, nickname, amino_id, bio, icon_url")
      .or(`amino_id.eq.${code},id.eq.${code}`)
      .maybeSingle();
    if (!data) return null;
    return {
      type: "user",
      targetId: data.id,
      title: `${data.nickname || data.amino_id || 'Usuário'} — NexusHub`,
      description: data.bio ?? `Perfil de ${data.nickname || data.amino_id || 'usuário'} no NexusHub`,
      imageUrl: data.icon_url ?? DEFAULT_OG_IMAGE,
      deepLink: `${APP_SCHEME}://u/${code}`,
    };
  }

  if (prefix === "c") {
    const { data } = await supabase
      .from("communities")
      .select("id, name, description, banner_url, icon_url")
      .or(`endpoint.eq.${code},id.eq.${code}`)
      .maybeSingle();
    if (!data) return null;
    return {
      type: "community",
      targetId: data.id,
      title: `${data.name} — NexusHub`,
      description: data.description ?? `Comunidade ${data.name} no NexusHub`,
      imageUrl: data.banner_url ?? data.icon_url ?? DEFAULT_OG_IMAGE,
      deepLink: `${APP_SCHEME}://c/${code}`,
    };
  }

  // Para os demais, resolver via short_urls
  const { data: shortUrl } = await supabase
    .from("short_urls")
    .select("type, target_id")
    .eq("code", code)
    .maybeSingle();

  if (!shortUrl) return null;

  const { type, target_id: targetId } = shortUrl;

  if (type === "post" || type === "blog") {
    const { data } = await supabase
      .from("posts")
      .select("id, title, content, cover_image_url, profiles(nickname, icon_url)")
      .eq("id", targetId)
      .maybeSingle();
    if (!data) return null;
    const author = (data.profiles as { nickname?: string; icon_url?: string } | null);
    const desc = data.content
      ? (data.content as string).replace(/<[^>]+>/g, "").slice(0, 160)
      : `Post de ${author?.nickname ?? "usuário"} no NexusHub`;
    return {
      type,
      targetId,
      title: `${data.title ?? "Post"} — NexusHub`,
      description: desc,
      imageUrl: data.cover_image_url ?? author?.icon_url ?? DEFAULT_OG_IMAGE,
      deepLink: `${APP_SCHEME}://p/${code}`,
    };
  }

  if (type === "wiki") {
    const { data } = await supabase
      .from("wiki_entries")
      .select("id, title, content, cover_image_url")
      .eq("id", targetId)
      .maybeSingle();
    if (!data) return null;
    const desc = data.content
      ? (data.content as string).replace(/<[^>]+>/g, "").slice(0, 160)
      : `Entrada de wiki no NexusHub`;
    return {
      type,
      targetId,
      title: `${data.title ?? "Wiki"} — NexusHub`,
      description: desc,
      imageUrl: data.cover_image_url ?? DEFAULT_OG_IMAGE,
      deepLink: `${APP_SCHEME}://w/${code}`,
    };
  }

  if (type === "chat") {
    const { data } = await supabase
      .from("chat_threads")
      .select("id, title, icon_url, description")
      .eq("id", targetId)
      .maybeSingle();
    if (!data) return null;
    return {
      type,
      targetId,
      title: `${data.title ?? "Chat"} — NexusHub`,
      description: data.description ?? `Chat público no NexusHub`,
      imageUrl: data.icon_url ?? DEFAULT_OG_IMAGE,
      deepLink: `${APP_SCHEME}://chat/${code}`,
    };
  }

  if (type === "sticker_pack") {
    const { data } = await supabase
      .from("sticker_packs")
      .select("id, name, description, cover_url")
      .eq("id", targetId)
      .maybeSingle();
    if (!data) return null;
    return {
      type,
      targetId,
      title: `${data.name ?? "Sticker Pack"} — NexusHub`,
      description: data.description ?? `Pack de stickers no NexusHub`,
      imageUrl: data.cover_url ?? DEFAULT_OG_IMAGE,
      deepLink: `${APP_SCHEME}://s/${code}`,
    };
  }

  if (type === "invite") {
    return {
      type,
      targetId,
      title: `Convite para comunidade — NexusHub`,
      description: `Você foi convidado para entrar em uma comunidade no NexusHub!`,
      imageUrl: DEFAULT_OG_IMAGE,
      deepLink: `${APP_SCHEME}://invite/${code}`,
    };
  }

  return null;
}

// ─────────────────────────────────────────────────────────────
// Gera HTML com Open Graph + redirect automático
// ─────────────────────────────────────────────────────────────
function buildHtml(content: ResolvedContent): string {
  const { title, description, imageUrl, deepLink } = content;
  const escapedTitle = title.replace(/"/g, "&quot;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  const escapedDesc = description.replace(/"/g, "&quot;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

  return `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${escapedTitle}</title>

  <!-- Open Graph -->
  <meta property="og:title" content="${escapedTitle}" />
  <meta property="og:description" content="${escapedDesc}" />
  <meta property="og:image" content="${imageUrl}" />
  <meta property="og:image:width" content="1200" />
  <meta property="og:image:height" content="630" />
  <meta property="og:type" content="website" />
  <meta property="og:site_name" content="${APP_NAME}" />

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="${escapedTitle}" />
  <meta name="twitter:description" content="${escapedDesc}" />
  <meta name="twitter:image" content="${imageUrl}" />

  <!-- App Links (Android) -->
  <meta property="al:android:package" content="app.nexushub" />
  <meta property="al:android:url" content="${deepLink}" />
  <meta property="al:android:app_name" content="${APP_NAME}" />

  <!-- App Links (iOS) -->
  <meta property="al:ios:url" content="${deepLink}" />
  <meta property="al:ios:app_store_id" content="000000000" />
  <meta property="al:ios:app_name" content="${APP_NAME}" />

  <!-- Smart App Banner (iOS Safari) -->
  <meta name="apple-itunes-app" content="app-id=000000000, app-argument=${deepLink}" />

  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      background: #0d0d0d;
      color: #fff;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      text-align: center;
      padding: 24px;
    }
    .card { max-width: 420px; width: 100%; }
    .logo {
      width: 72px; height: 72px;
      background: linear-gradient(135deg, #22c55e, #16a34a);
      border-radius: 20px;
      margin: 0 auto 20px;
      display: flex; align-items: center; justify-content: center;
      font-size: 36px; font-weight: 900; color: #fff;
    }
    .og-image {
      width: 100%; border-radius: 16px; margin-bottom: 20px;
      max-height: 200px; object-fit: cover;
    }
    h1 { font-size: 20px; font-weight: 700; margin-bottom: 10px; }
    p  { font-size: 14px; color: #aaa; line-height: 1.6; margin-bottom: 24px; }
    .btn {
      display: block; width: 100%;
      background: linear-gradient(135deg, #22c55e, #16a34a);
      color: #fff; font-size: 16px; font-weight: 600;
      padding: 14px 32px; border-radius: 14px;
      text-decoration: none; margin-bottom: 12px;
    }
    .btn-secondary {
      display: block; width: 100%;
      background: #1a1a1a; color: #aaa;
      font-size: 14px; font-weight: 500;
      padding: 12px 24px; border-radius: 14px;
      text-decoration: none; border: 1px solid #333;
    }
    .store-links { display: flex; gap: 10px; margin-top: 12px; }
    .store-links a { flex: 1; }
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">N</div>
    ${imageUrl !== DEFAULT_OG_IMAGE ? `<img class="og-image" src="${imageUrl}" alt="Preview" onerror="this.style.display='none'" />` : ""}
    <h1>${escapedTitle}</h1>
    <p>${escapedDesc}</p>
    <a id="open-btn" class="btn" href="${deepLink}">Abrir no ${APP_NAME}</a>
    <div class="store-links">
      <a class="btn-secondary" href="${PLAY_STORE_URL}">📱 Google Play</a>
      <a class="btn-secondary" href="${APP_STORE_URL}">🍎 App Store</a>
    </div>
  </div>
  <script>
    // Tenta abrir o app automaticamente
    window.location.href = "${deepLink}";
  </script>
</body>
</html>`;
}

// ─────────────────────────────────────────────────────────────
// Página de erro 404
// ─────────────────────────────────────────────────────────────
function buildNotFoundHtml(): string {
  return `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Conteúdo não encontrado — NexusHub</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      background: #0d0d0d; color: #fff;
      display: flex; align-items: center; justify-content: center;
      min-height: 100vh; text-align: center; padding: 24px;
    }
    .card { max-width: 400px; width: 100%; }
    h1 { font-size: 20px; font-weight: 700; margin-bottom: 10px; }
    p  { font-size: 14px; color: #aaa; line-height: 1.6; margin-bottom: 24px; }
    a  { color: #22c55e; text-decoration: none; }
  </style>
</head>
<body>
  <div class="card">
    <h1>🔗 Link não encontrado</h1>
    <p>O conteúdo que você está procurando pode ter sido removido ou o link está expirado.</p>
    <p><a href="${BASE_URL}">Ir para o NexusHub</a></p>
  </div>
</body>
</html>`;
}

// ─────────────────────────────────────────────────────────────
// Handler principal
// ─────────────────────────────────────────────────────────────
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);

  // Aceita tanto ?path=/p/xK9mZ quanto /link-preview/p/xK9mZ
  let pathParam = url.searchParams.get("path") ?? "";
  if (!pathParam) {
    // Remove o prefixo /link-preview do pathname
    pathParam = url.pathname.replace(/^\/link-preview/, "") || "/";
  }

  // Parsear o path: /prefix/code
  const segments = pathParam.replace(/^\//, "").split("/");
  const prefix = segments[0] ?? "";
  const code = segments[1] ?? "";

  if (!prefix || !code) {
    return new Response(buildNotFoundHtml(), {
      status: 404,
      headers: { ...corsHeaders, "Content-Type": "text/html; charset=utf-8" },
    });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  try {
    const content = await resolveShortCode(supabase, prefix, code);

    if (!content) {
      return new Response(buildNotFoundHtml(), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "text/html; charset=utf-8" },
      });
    }

    // Incrementar hits (fire-and-forget)
    if (!["u", "c"].includes(prefix)) {
      supabase
        .from("short_urls")
        .update({ hits: supabase.rpc("hits + 1") as unknown as number })
        .eq("code", code)
        .then(() => {})
        .catch(() => {});
    }

    return new Response(buildHtml(content), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "text/html; charset=utf-8",
        "Cache-Control": "public, max-age=300", // 5 min cache
      },
    });
  } catch (err) {
    console.error("[link-preview] Erro:", err);
    return new Response(buildNotFoundHtml(), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "text/html; charset=utf-8" },
    });
  }
});
