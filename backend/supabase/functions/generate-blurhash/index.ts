// Edge Function: generate-blurhash
// Recebe a URL pública de uma imagem no Supabase Storage,
// gera o BlurHash correspondente e retorna a string do hash.
//
// Corpo da requisição (JSON):
//   { "image_url": "https://..." }
//
// Resposta:
//   { "blurhash": "LGF5?xYk^6#M@-5c,1J5@[or[Q6." }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { encode } from "https://esm.sh/blurhash@2.0.5";
import { decode } from "https://esm.sh/@jsquash/jpeg@1.3.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { image_url } = await req.json();

    if (!image_url || typeof image_url !== "string") {
      return new Response(
        JSON.stringify({ error: "image_url is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Baixar a imagem
    const imageResponse = await fetch(image_url);
    if (!imageResponse.ok) {
      return new Response(
        JSON.stringify({ error: "Failed to fetch image" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const imageBuffer = await imageResponse.arrayBuffer();
    const contentType = imageResponse.headers.get("content-type") ?? "image/jpeg";

    // Decodificar imagem para pixels RGBA
    let imageData: ImageData;
    if (contentType.includes("webp") || contentType.includes("jpeg") || contentType.includes("jpg")) {
      // Usar createImageBitmap do Deno (disponível no Supabase Edge Runtime)
      const blob = new Blob([imageBuffer], { type: contentType });
      const bitmap = await createImageBitmap(blob);

      // Redimensionar para no máximo 64x64 para performance
      const targetW = Math.min(bitmap.width, 64);
      const targetH = Math.min(bitmap.height, 64);

      const canvas = new OffscreenCanvas(targetW, targetH);
      const ctx = canvas.getContext("2d")!;
      ctx.drawImage(bitmap, 0, 0, targetW, targetH);
      imageData = ctx.getImageData(0, 0, targetW, targetH);
    } else {
      return new Response(
        JSON.stringify({ error: "Unsupported image format: " + contentType }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Gerar BlurHash (componentes 4x3 — bom equilíbrio entre qualidade e tamanho da string)
    const blurhash = encode(
      imageData.data,
      imageData.width,
      imageData.height,
      4,
      3
    );

    return new Response(
      JSON.stringify({ blurhash }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("[generate-blurhash] Error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", detail: String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
