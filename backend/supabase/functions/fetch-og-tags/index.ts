// Supabase Edge Function — fetch-og-tags
// Fetches Open Graph metadata from a given URL.
// Returns: { title, description, image, domain, favicon }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { url } = await req.json();

    if (!url || typeof url !== "string") {
      return new Response(
        JSON.stringify({ error: "Missing or invalid 'url' parameter" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Validate URL
    let parsedUrl: URL;
    try {
      parsedUrl = new URL(url);
    } catch {
      return new Response(
        JSON.stringify({ error: "Invalid URL format" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Fetch the page with timeout
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8000);

    const response = await fetch(url, {
      headers: {
        "User-Agent":
          "Mozilla/5.0 (compatible; NexusHub/1.0; +https://nexushub.app)",
        Accept: "text/html,application/xhtml+xml",
      },
      signal: controller.signal,
      redirect: "follow",
    });

    clearTimeout(timeout);

    if (!response.ok) {
      return new Response(
        JSON.stringify({ error: `HTTP ${response.status}` }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const html = await response.text();

    // Parse OG tags with regex (lightweight, no DOM parser needed)
    const getMetaContent = (property: string): string | null => {
      // Match both property="og:..." and name="og:..."
      const patterns = [
        new RegExp(
          `<meta[^>]+(?:property|name)=["']${property}["'][^>]+content=["']([^"']+)["']`,
          "i"
        ),
        new RegExp(
          `<meta[^>]+content=["']([^"']+)["'][^>]+(?:property|name)=["']${property}["']`,
          "i"
        ),
      ];

      for (const pattern of patterns) {
        const match = html.match(pattern);
        if (match?.[1]) return match[1].trim();
      }
      return null;
    };

    // Extract <title> tag as fallback
    const getTitleTag = (): string | null => {
      const match = html.match(/<title[^>]*>([^<]+)<\/title>/i);
      return match?.[1]?.trim() || null;
    };

    // Extract meta description as fallback
    const getMetaDescription = (): string | null => {
      const patterns = [
        /<meta[^>]+name=["']description["'][^>]+content=["']([^"']+)["']/i,
        /<meta[^>]+content=["']([^"']+)["'][^>]+name=["']description["']/i,
      ];
      for (const pattern of patterns) {
        const match = html.match(pattern);
        if (match?.[1]) return match[1].trim();
      }
      return null;
    };

    // Extract favicon
    const getFavicon = (): string | null => {
      const match = html.match(
        /<link[^>]+rel=["'](?:icon|shortcut icon)["'][^>]+href=["']([^"']+)["']/i
      );
      if (match?.[1]) {
        const href = match[1];
        if (href.startsWith("http")) return href;
        if (href.startsWith("//")) return `${parsedUrl.protocol}${href}`;
        if (href.startsWith("/"))
          return `${parsedUrl.origin}${href}`;
        return `${parsedUrl.origin}/${href}`;
      }
      return `${parsedUrl.origin}/favicon.ico`;
    };

    const ogData = {
      title: getMetaContent("og:title") || getTitleTag() || null,
      description:
        getMetaContent("og:description") || getMetaDescription() || null,
      image: getMetaContent("og:image") || null,
      site_name: getMetaContent("og:site_name") || null,
      domain: parsedUrl.hostname,
      favicon: getFavicon(),
      url: getMetaContent("og:url") || url,
    };

    return new Response(JSON.stringify(ogData), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Unknown error";
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
