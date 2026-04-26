// ============================================================================
// NEXUSHUB — AI ROLEPLAY EDGE FUNCTION
// Edge Function: ai-roleplay
//
// Recebe uma mensagem do usuário + contexto do personagem e retorna
// a resposta do personagem via OpenAI GPT-4.1-mini.
//
// Body: {
//   thread_id: string,
//   user_message: string,
//   character_id: string,
//   history?: Array<{ role: 'user'|'assistant', content: string }>
// }
//
// Response: {
//   reply: string,
//   character_name: string,
//   character_avatar: string | null
// }
// ============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const MAX_HISTORY = 10; // Máximo de mensagens anteriores enviadas ao LLM
const MAX_REPLY_TOKENS = 200; // Respostas curtas para chat

interface RolePlayRequest {
  thread_id: string;
  user_message: string;
  character_id: string;
  history?: Array<{ role: "user" | "assistant"; content: string }>;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // Autenticação via JWT do usuário
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    // Verificar usuário autenticado
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const body: RolePlayRequest = await req.json();
    const { thread_id, user_message, character_id, history = [] } = body;

    if (!thread_id || !user_message?.trim() || !character_id) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Buscar personagem no banco (usando service role para bypass RLS)
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { data: character, error: charError } = await supabaseAdmin
      .from("ai_characters")
      .select("id, name, avatar_url, system_prompt, is_active")
      .eq("id", character_id)
      .eq("is_active", true)
      .single();

    if (charError || !character) {
      return new Response(
        JSON.stringify({ error: "Character not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Montar histórico truncado
    const recentHistory = history.slice(-MAX_HISTORY);

    // Chamar OpenAI
    const openaiKey = Deno.env.get("OPENAI_API_KEY");
    if (!openaiKey) {
      return new Response(
        JSON.stringify({ error: "OpenAI key not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const messages = [
      { role: "system", content: character.system_prompt },
      ...recentHistory,
      { role: "user", content: user_message },
    ];

    const openaiRes = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${openaiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4.1-mini",
        messages,
        max_tokens: MAX_REPLY_TOKENS,
        temperature: 0.8,
      }),
    });

    if (!openaiRes.ok) {
      const errText = await openaiRes.text();
      console.error("[ai-roleplay] OpenAI error:", errText);
      return new Response(
        JSON.stringify({ error: "AI service unavailable" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const openaiData = await openaiRes.json();
    const reply = openaiData.choices?.[0]?.message?.content?.trim() ?? "";

    if (!reply) {
      return new Response(
        JSON.stringify({ error: "Empty AI response" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Incrementar contador de mensagens na sessão
    await supabaseAdmin
      .from("chat_roleplay_sessions")
      .update({ message_count: supabaseAdmin.rpc("increment", { x: 1 }) })
      .eq("thread_id", thread_id)
      .eq("is_active", true);

    return new Response(
      JSON.stringify({
        reply,
        character_name: character.name,
        character_avatar: character.avatar_url,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    console.error("[ai-roleplay] Unexpected error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
