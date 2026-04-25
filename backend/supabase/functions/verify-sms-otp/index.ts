// ============================================================================
// NEXUSHUB - Edge Function: Verify SMS OTP
// Endpoint: POST /functions/v1/verify-sms-otp
// Body: { phone: string, code: string, action: 'setup' | 'login' }
//   action='setup'  → verifica e ativa o SMS 2FA para o usuário
//   action='login'  → verifica o código durante o desafio de login
// Autenticado: sim (JWT do usuário)
// ============================================================================
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const json = (data: unknown, status = 200) =>
    new Response(JSON.stringify(data), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  try {
    // 1. Autenticar o usuário
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Token ausente" }, 401);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: authErr } = await supabase.auth.getUser();
    if (authErr || !user) return json({ error: "Não autenticado" }, 401);

    // 2. Validar parâmetros
    const { phone, code, action } = await req.json();
    if (!phone || !code || !action) {
      return json({ error: "Parâmetros obrigatórios: phone, code, action" }, 400);
    }
    if (!["setup", "login"].includes(action)) {
      return json({ error: "action deve ser 'setup' ou 'login'" }, 400);
    }
    if (!/^\d{6}$/.test(code)) {
      return json({ error: "Código deve ter 6 dígitos numéricos" }, 400);
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // 3. Buscar o código mais recente válido para este usuário/telefone
    const { data: otpRow, error: otpErr } = await supabaseAdmin
      .from("sms_2fa_codes")
      .select("*")
      .eq("user_id", user.id)
      .eq("phone", phone)
      .eq("used", false)
      .gt("expires_at", new Date().toISOString())
      .order("created_at", { ascending: false })
      .limit(1)
      .single();

    if (otpErr || !otpRow) {
      return json({ error: "Código expirado ou não encontrado. Solicite um novo." }, 400);
    }

    // 4. Verificar tentativas (máximo 5)
    if (otpRow.attempts >= 5) {
      await supabaseAdmin
        .from("sms_2fa_codes")
        .update({ used: true })
        .eq("id", otpRow.id);
      return json({ error: "Muitas tentativas incorretas. Solicite um novo código." }, 429);
    }

    // 5. Verificar o hash do código
    const encoder = new TextEncoder();
    const data    = encoder.encode(code + user.id);
    const hashBuf = await crypto.subtle.digest("SHA-256", data);
    const hash    = Array.from(new Uint8Array(hashBuf))
      .map(b => b.toString(16).padStart(2, "0"))
      .join("");

    if (hash !== otpRow.code_hash) {
      // Incrementar tentativas
      await supabaseAdmin
        .from("sms_2fa_codes")
        .update({ attempts: otpRow.attempts + 1 })
        .eq("id", otpRow.id);
      const remaining = 5 - (otpRow.attempts + 1);
      return json({
        error: `Código incorreto. ${remaining} tentativa(s) restante(s).`,
        attempts_remaining: remaining,
      }, 400);
    }

    // 6. Código correto — marcar como usado
    await supabaseAdmin
      .from("sms_2fa_codes")
      .update({ used: true })
      .eq("id", otpRow.id);

    // 7. Ação específica
    if (action === "setup") {
      // Ativar SMS 2FA para o usuário
      await supabaseAdmin
        .from("user_2fa_settings")
        .upsert({
          user_id:        user.id,
          phone_enabled:  true,
          phone_number:   phone,
          updated_at:     new Date().toISOString(),
        }, { onConflict: "user_id" });

      // Log de auditoria
      await supabaseAdmin.from("auth_security_log").insert({
        user_id:    user.id,
        event:      "sms_2fa_enabled",
        details:    { phone_masked: phone.slice(0, 3) + "****" + phone.slice(-4) },
        created_at: new Date().toISOString(),
      });

      return json({ success: true, message: "SMS 2FA ativado com sucesso." });

    } else {
      // action === 'login': verificação durante o login
      // Log de auditoria
      await supabaseAdmin.from("auth_security_log").insert({
        user_id:    user.id,
        event:      "sms_2fa_verified",
        details:    { phone_masked: phone.slice(0, 3) + "****" + phone.slice(-4) },
        created_at: new Date().toISOString(),
      });

      // Retornar token de sessão confirmado
      // O cliente Flutter já tem a sessão — apenas confirma que o 2FA passou
      return json({ success: true, message: "Verificação concluída." });
    }

  } catch (err) {
    console.error("verify-sms-otp error:", err);
    return json({ error: "Erro interno ao verificar código" }, 500);
  }
});
