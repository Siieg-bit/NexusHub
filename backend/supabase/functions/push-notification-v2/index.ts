import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok");
  }

  try {
    // Validar autenticação do backend
    const authHeader = req.headers.get("x-backend-auth-key");
    const backendAuthKey = Deno.env.get("BACKEND_AUTH_KEY");
    
    if (backendAuthKey && authHeader !== backendAuthKey) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401 }
      );
    }

    const payload = await req.json();
    console.log("[push-notification-v2] Recebido:", JSON.stringify(payload));

    return new Response(
      JSON.stringify({ success: true, message: "Notification queued" }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("[push-notification-v2] Erro:", error.message);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500 }
    );
  }
});
