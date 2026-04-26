// Edge Function: generate-blurhash
// Recebe a URL pública de uma imagem no Supabase Storage,
// gera o BlurHash correspondente e retorna a string do hash.
//
// Estratégia: usa magick-wasm (WASM puro, suportado pelo Supabase Edge Runtime)
// para decodificar a imagem e extrair pixels RGBA, depois codifica com o
// pacote `blurhash` (npm). Não depende de Canvas, createImageBitmap ou APIs
// de browser — funciona 100% no runtime Deno do Supabase.
//
// Corpo da requisição (JSON):
//   { "image_url": "https://..." }
//
// Resposta de sucesso:
//   { "blurhash": "LGF5?xYk^6#M@-5c,1J5@[or[Q6." }
//
// Resposta de erro:
//   { "error": "mensagem" }

import {
  ImageMagick,
  initializeImageMagick,
  MagickFormat,
  MagickGeometry,
} from "npm:@imagemagick/magick-wasm@0.0.30";
import { encode } from "npm:blurhash@2.0.5";

// Inicializar o ImageMagick uma única vez (top-level await — executado no cold start)
const wasmBytes = await Deno.readFile(
  new URL(
    "magick.wasm",
    import.meta.resolve("npm:@imagemagick/magick-wasm@0.0.30"),
  ),
);
await initializeImageMagick(wasmBytes);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Dimensão máxima para redimensionar antes de gerar o hash.
// Valores menores = mais rápido e menos memória. 64px é suficiente para o BlurHash.
const MAX_DIM = 64;

// Componentes do BlurHash: 4 horizontal × 3 vertical.
// Bom equilíbrio entre qualidade visual e tamanho da string (~30 chars).
const COMP_X = 4;
const COMP_Y = 3;

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { image_url } = await req.json();

    if (!image_url || typeof image_url !== "string") {
      return new Response(
        JSON.stringify({ error: "image_url is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 1. Baixar a imagem
    const imageResponse = await fetch(image_url, {
      headers: { "User-Agent": "NexusHub-BlurHash/1.0" },
    });

    if (!imageResponse.ok) {
      return new Response(
        JSON.stringify({
          error: `Failed to fetch image: HTTP ${imageResponse.status}`,
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const imageBuffer = new Uint8Array(await imageResponse.arrayBuffer());

    // 2. Processar com magick-wasm: redimensionar e extrair pixels RGBA
    let blurhash: string | null = null;

    ImageMagick.read(imageBuffer, (img) => {
      // Redimensionar mantendo proporção para MAX_DIM × MAX_DIM
      const geometry = new MagickGeometry(MAX_DIM, MAX_DIM);
      geometry.ignoreAspectRatio = false;
      img.resize(geometry);

      const w = img.width;
      const h = img.height;

      // Extrair pixels RGBA via PixelCollection
      img.getPixels((pixels) => {
        const rgba = pixels.toByteArray(0, 0, w, h, "RGBA");
        if (!rgba) {
          throw new Error("Failed to extract pixel data from image");
        }

        // 3. Gerar BlurHash a partir dos pixels RGBA
        // encode() espera: pixels: Uint8ClampedArray, width, height, compX, compY
        blurhash = encode(
          new Uint8ClampedArray(rgba.buffer),
          w,
          h,
          COMP_X,
          COMP_Y,
        );
      });
    });

    if (!blurhash) {
      throw new Error("BlurHash generation returned empty result");
    }

    return new Response(
      JSON.stringify({ blurhash }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("[generate-blurhash] Error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", detail: String(error) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
