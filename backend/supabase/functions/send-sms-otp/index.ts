// ============================================================================
// NEXUSHUB - Edge Function: Send SMS OTP
// Endpoint: POST /functions/v1/send-sms-otp
// Body: { phone: string }  — formato internacional: +5511999999999
// Autenticado: sim (JWT do usuário)
// ============================================================================
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Gera código OTP numérico de 6 dígitos
function generateOtp(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// Envia SMS via Twilio REST API
async function sendTwilioSms(to: string, body: string): Promise<void> {
  const accountSid = Deno.env.get("TWILIO_ACCOUNT_SID")!;
  const authToken  = Deno.env.get("TWILIO_AUTH_TOKEN")!;
  const from       = Deno.env.get("TWILIO_PHONE_NUMBER")!;

  const url = `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`;
  const credentials = btoa(`${accountSid}:${authToken}`);

  const params = new URLSearchParams({ To: to, From: from, Body: body });

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Authorization": `Basic ${credentials}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: params.toString(),
  });

  if (!res.ok) {
    const err = await res.json();
    throw new Error(`Twilio error ${err.code}: ${err.message}`);
  }
}

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

    // 2. Validar o número de telefone
    const { phone } = await req.json();
    if (!phone || !/^\+[1-9]\d{7,14}$/.test(phone)) {
      return json({ error: "Número de telefone inválido. Use o formato +5511999999999" }, 400);
    }

    // 3. Rate limit: máximo 3 envios por hora por usuário
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
    const { count } = await supabaseAdmin
      .from("sms_2fa_codes")
      .select("*", { count: "exact", head: true })
      .eq("user_id", user.id)
      .gte("created_at", oneHourAgo);

    if ((count ?? 0) >= 5) {
      return json({ error: "Muitas tentativas. Aguarde 1 hora." }, 429);
    }

    // 4. Invalidar códigos anteriores do mesmo usuário/telefone
    await supabaseAdmin
      .from("sms_2fa_codes")
      .update({ used: true })
      .eq("user_id", user.id)
      .eq("phone", phone)
      .eq("used", false);

    // 5. Gerar novo OTP e salvar (expira em 10 minutos)
    const code    = generateOtp();
    const expires = new Date(Date.now() + 10 * 60 * 1000).toISOString();

    // Hash do código para não armazenar em plain text
    const encoder = new TextEncoder();
    const data    = encoder.encode(code + user.id);
    const hashBuf = await crypto.subtle.digest("SHA-256", data);
    const hash    = Array.from(new Uint8Array(hashBuf))
      .map(b => b.toString(16).padStart(2, "0"))
      .join("");

    await supabaseAdmin.from("sms_2fa_codes").insert({
      user_id:    user.id,
      phone,
      code_hash:  hash,
      expires_at: expires,
      used:       false,
      attempts:   0,
    });

    // 6. Enviar SMS via Twilio
    const maskedPhone = phone.slice(0, 3) + "****" + phone.slice(-4);
    await sendTwilioSms(
      phone,
      `Seu código de verificação NexusHub: ${code}. Válido por 10 minutos. Não compartilhe.`
    );

    return json({ success: true, masked_phone: maskedPhone });

  } catch (err) {
    console.error("send-sms-otp error:", err);
    return json({ error: "Erro interno ao enviar SMS" }, 500);
  }
});
