// ============================================================================
// NEXUSHUB — BOT DE MODERAÇÃO DE CONTEÚDO
// Edge Function: content-moderation-bot
//
// Responsabilidades:
// 1. Receber webhook de novas flags (via pg_net ou chamada direta)
// 2. Analisar o snapshot do conteúdo com OpenAI Moderation API
// 3. Classificar: clean | suspicious | auto_removed | escalated
// 4. Registrar resultado via RPC record_bot_action
// 5. Auto-remover conteúdo com score >= 0.85 (configurável)
// 6. Notificar staff quando escalado
//
// Pode ser chamado de duas formas:
// • POST /content-moderation-bot  { flag_id, snapshot_id }  (webhook)
// • POST /content-moderation-bot  { mode: "batch", limit: 20 } (processamento em lote)
// ============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-bot-secret",
};

// Limiares de decisão automática
const THRESHOLDS = {
  AUTO_REMOVE:  0.85,  // score >= 0.85 → auto_removed
  SUSPICIOUS:   0.50,  // score >= 0.50 → suspicious (escalado para humano)
  CLEAN:        0.20,  // score < 0.20  → clean
};

// Categorias da OpenAI Moderation API mapeadas para as nossas
const CATEGORY_MAP: Record<string, string> = {
  "hate":                     "hate_speech",
  "hate/threatening":         "hate_speech",
  "harassment":               "harassment",
  "harassment/threatening":   "harassment",
  "self-harm":                "self_harm",
  "self-harm/intent":         "self_harm",
  "self-harm/instructions":   "self_harm",
  "sexual":                   "nsfw",
  "sexual/minors":            "csam",
  "violence":                 "violence",
  "violence/graphic":         "violence",
};

interface BotRequest {
  flag_id?:    string;
  snapshot_id?: string;
  mode?:       "single" | "batch";
  limit?:      number;
}

interface OpenAIModerationResult {
  flagged: boolean;
  categories: Record<string, boolean>;
  category_scores: Record<string, number>;
}

// ============================================================================
// FUNÇÃO PRINCIPAL DE ANÁLISE
// ============================================================================
async function analyzeContent(
  text: string,
  imageUrls: string[] = []
): Promise<{
  flagged: boolean;
  score: number;
  categories: string[];
  rawResponse: unknown;
}> {
  const openaiKey = Deno.env.get("OPENAI_API_KEY");

  if (!openaiKey) {
    // Fallback: análise por palavras-chave simples quando não há API key
    return fallbackAnalysis(text);
  }

  try {
    // OpenAI Moderation API (gratuita, sem custo por token)
    const response = await fetch("https://api.openai.com/v1/moderations", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${openaiKey}`,
      },
      body: JSON.stringify({
        input: text.substring(0, 2000), // Limitar a 2000 chars
        model: "omni-moderation-latest",
      }),
    });

    if (!response.ok) {
      throw new Error(`OpenAI API error: ${response.status}`);
    }

    const data = await response.json();
    const result: OpenAIModerationResult = data.results?.[0];

    if (!result) throw new Error("Resposta inválida da OpenAI");

    // Calcular score máximo entre todas as categorias
    const scores = Object.values(result.category_scores);
    const maxScore = Math.max(...scores, 0);

    // Mapear categorias detectadas
    const detectedCategories = Object.entries(result.categories)
      .filter(([, flagged]) => flagged)
      .map(([cat]) => CATEGORY_MAP[cat] ?? cat);

    return {
      flagged:    result.flagged,
      score:      maxScore,
      categories: detectedCategories,
      rawResponse: data,
    };
  } catch (err) {
    console.error("[bot] Erro na OpenAI API:", err);
    // Fallback em caso de erro
    return fallbackAnalysis(text);
  }
}

// Análise por palavras-chave como fallback
function fallbackAnalysis(text: string): {
  flagged: boolean;
  score: number;
  categories: string[];
  rawResponse: unknown;
} {
  const lower = text.toLowerCase();

  const patterns: Array<{ words: string[]; category: string; weight: number }> = [
    { words: ["spam", "clique aqui", "ganhe dinheiro", "promoção exclusiva"], category: "spam", weight: 0.6 },
    { words: ["ódio", "hate", "racismo", "preconceito"], category: "hate_speech", weight: 0.7 },
    { words: ["assédio", "ameaça", "vou te matar", "te pego"], category: "harassment", weight: 0.75 },
    { words: ["nsfw", "pornô", "nude", "conteúdo adulto"], category: "nsfw", weight: 0.8 },
  ];

  let maxScore = 0;
  const categories: string[] = [];

  for (const pattern of patterns) {
    const matches = pattern.words.filter(w => lower.includes(w)).length;
    if (matches > 0) {
      const score = Math.min(pattern.weight * (matches / pattern.words.length * 2), 1.0);
      if (score > maxScore) maxScore = score;
      if (score > 0.3) categories.push(pattern.category);
    }
  }

  return {
    flagged:    maxScore > 0.5,
    score:      maxScore,
    categories,
    rawResponse: { method: "fallback_keyword_analysis" },
  };
}

// ============================================================================
// PROCESSAR UMA FLAG
// ============================================================================
async function processFlag(
  supabaseAdmin: ReturnType<typeof createClient>,
  flagId: string,
  snapshotId?: string
): Promise<{ success: boolean; verdict: string; score: number }> {
  // 1. Buscar snapshot
  let snapshot: Record<string, unknown> | null = null;

  if (snapshotId) {
    const { data } = await supabaseAdmin
      .from("content_snapshots")
      .select("*")
      .eq("id", snapshotId)
      .single();
    snapshot = data;
  } else {
    const { data } = await supabaseAdmin
      .from("content_snapshots")
      .select("*")
      .eq("flag_id", flagId)
      .order("captured_at", { ascending: false })
      .limit(1)
      .single();
    snapshot = data;
  }

  if (!snapshot) {
    console.warn(`[bot] Snapshot não encontrado para flag ${flagId}`);
    return { success: false, verdict: "clean", score: 0 };
  }

  // 2. Extrair texto do snapshot
  const snapData = snapshot.snapshot_data as Record<string, unknown>;
  const contentType = snapshot.content_type as string;

  let textContent = "";
  const imageUrls: string[] = [];

  if (contentType === "post") {
    textContent = [
      snapData.title as string ?? "",
      snapData.body as string ?? "",
    ].filter(Boolean).join("\n\n");
    const imgs = snapData.image_urls as string[] ?? [];
    imageUrls.push(...imgs);
  } else if (contentType === "comment") {
    textContent = snapData.body as string ?? "";
    const imgs = snapData.image_urls as string[] ?? [];
    imageUrls.push(...imgs);
  } else if (contentType === "chat_message") {
    textContent = snapData.content as string ?? "";
    if (snapData.media_url) imageUrls.push(snapData.media_url as string);
  } else if (contentType === "profile") {
    textContent = [
      snapData.nickname as string ?? "",
      snapData.bio as string ?? "",
    ].filter(Boolean).join("\n");
  }

  // Conteúdo vazio ou erro → marcar como clean
  if (!textContent.trim() && imageUrls.length === 0) {
    await supabaseAdmin.rpc("record_bot_action", {
      p_flag_id:     flagId,
      p_snapshot_id: snapshot.id,
      p_action_type: `scan_${contentType}`,
      p_verdict:     "clean",
      p_confidence:  0.0,
      p_categories:  [],
      p_reasoning:   "Conteúdo vazio — nenhuma análise necessária",
      p_auto_action: false,
    });
    return { success: true, verdict: "clean", score: 0 };
  }

  // 3. Analisar conteúdo
  const analysis = await analyzeContent(textContent, imageUrls);

  // 4. Determinar veredicto
  let verdict: string;
  let autoAction = false;
  let reasoning: string;

  if (analysis.score >= THRESHOLDS.AUTO_REMOVE) {
    verdict = "auto_removed";
    autoAction = true;
    reasoning = `Conteúdo removido automaticamente. Score: ${(analysis.score * 100).toFixed(1)}%. ` +
      `Categorias: ${analysis.categories.join(", ") || "não classificado"}.`;
  } else if (analysis.score >= THRESHOLDS.SUSPICIOUS) {
    verdict = "suspicious";
    autoAction = false;
    reasoning = `Conteúdo suspeito — requer revisão humana. Score: ${(analysis.score * 100).toFixed(1)}%. ` +
      `Categorias: ${analysis.categories.join(", ") || "não classificado"}.`;
  } else if (analysis.score >= THRESHOLDS.CLEAN) {
    verdict = "escalated";
    autoAction = false;
    reasoning = `Conteúdo com score baixo mas acima do limiar de limpeza. Score: ${(analysis.score * 100).toFixed(1)}%. ` +
      `Monitorar.`;
  } else {
    verdict = "clean";
    autoAction = false;
    reasoning = `Conteúdo analisado e considerado dentro das diretrizes. Score: ${(analysis.score * 100).toFixed(1)}%.`;
  }

  // 5. Registrar resultado via RPC
  await supabaseAdmin.rpc("record_bot_action", {
    p_flag_id:     flagId,
    p_snapshot_id: snapshot.id,
    p_action_type: `scan_${contentType}`,
    p_verdict:     verdict,
    p_confidence:  analysis.score,
    p_categories:  analysis.categories,
    p_reasoning:   reasoning,
    p_raw_response: analysis.rawResponse,
    p_auto_action: autoAction,
  });

  // 6. Notificar staff se escalado ou auto-removido
  if (verdict === "escalated" || verdict === "suspicious") {
    const { data: flagData } = await supabaseAdmin
      .from("flags")
      .select("community_id, reporter_id")
      .eq("id", flagId)
      .single();

    if (flagData?.community_id) {
      // Buscar staff da comunidade
      const { data: staff } = await supabaseAdmin
        .from("community_members")
        .select("user_id")
        .eq("community_id", flagData.community_id)
        .in("role", ["agent", "leader", "curator", "moderator"]);

      if (staff && staff.length > 0) {
        const notifications = staff.map((s: { user_id: string }) => ({
          user_id:   s.user_id,
          type:      "moderation_alert",
          title:     verdict === "suspicious"
            ? "⚠️ Conteúdo suspeito detectado"
            : "🔍 Conteúdo para revisão",
          body:      `O bot detectou conteúdo que requer sua atenção. Score: ${(analysis.score * 100).toFixed(0)}%`,
          data:      JSON.stringify({ flag_id: flagId, verdict, score: analysis.score }),
          community_id: flagData.community_id,
        }));

        await supabaseAdmin.from("notifications").insert(notifications);
      }
    }
  }

  return { success: true, verdict, score: analysis.score };
}

// ============================================================================
// PROCESSAMENTO EM LOTE (flags não analisadas)
// ============================================================================
async function processBatch(
  supabaseAdmin: ReturnType<typeof createClient>,
  limit: number = 20
): Promise<{ processed: number; results: unknown[] }> {
  // Buscar flags com snapshot mas sem análise do bot
  const { data: flags } = await supabaseAdmin
    .from("flags")
    .select("id")
    .eq("snapshot_captured", true)
    .eq("bot_analyzed", false)
    .eq("status", "pending")
    .order("created_at", { ascending: true })
    .limit(limit);

  if (!flags || flags.length === 0) {
    return { processed: 0, results: [] };
  }

  const results = [];
  for (const flag of flags) {
    try {
      const result = await processFlag(supabaseAdmin, flag.id);
      results.push({ flag_id: flag.id, ...result });
      // Pequeno delay para não sobrecarregar a API
      await new Promise(r => setTimeout(r, 200));
    } catch (err) {
      results.push({ flag_id: flag.id, success: false, error: String(err) });
    }
  }

  return { processed: flags.length, results };
}

// ============================================================================
// HANDLER PRINCIPAL
// ============================================================================
serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Verificar secret do bot (segurança)
  const botSecret = req.headers.get("x-bot-secret");
  const expectedSecret = Deno.env.get("BOT_SECRET");

  // Permitir também chamadas autenticadas com service_role
  const authHeader = req.headers.get("Authorization");
  const isServiceRole = authHeader?.includes(Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "NEVER");

  if (expectedSecret && botSecret !== expectedSecret && !isServiceRole) {
    return new Response(
      JSON.stringify({ error: "Não autorizado" }),
      { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const body: BotRequest = await req.json().catch(() => ({}));

    // Modo batch
    if (body.mode === "batch" || (!body.flag_id && !body.snapshot_id)) {
      const result = await processBatch(supabaseAdmin, body.limit ?? 20);
      return new Response(
        JSON.stringify({ success: true, ...result }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Modo single (webhook)
    if (!body.flag_id) {
      return new Response(
        JSON.stringify({ error: "flag_id é obrigatório" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const result = await processFlag(supabaseAdmin, body.flag_id, body.snapshot_id);

    return new Response(
      JSON.stringify({ success: true, flag_id: body.flag_id, ...result }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (err) {
    console.error("[bot] Erro:", err);
    return new Response(
      JSON.stringify({ error: "Erro interno", details: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
