-- ============================================================================
-- Migration 016: Database Webhooks & Triggers para Edge Functions
--
-- Cria triggers que chamam o webhook-handler Edge Function quando:
-- - Notificação é criada (push notification)
-- - Membro entra/sai de comunidade (member_count)
-- - Post é criado (notificar seguidores)
-- - Comentário é criado (notificar autor do post + incrementar count)
-- - Flag é criada (notificar moderadores)
-- - Follow é criado (notificar seguido)
-- ============================================================================

-- Função genérica para chamar Edge Function via pg_net
-- (Requer extensão pg_net habilitada no Supabase)
CREATE OR REPLACE FUNCTION public.notify_webhook()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  payload jsonb;
  webhook_url text;
BEGIN
  webhook_url := current_setting('app.settings.supabase_url', true) 
    || '/functions/v1/webhook-handler';

  payload := jsonb_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'schema', TG_TABLE_SCHEMA,
    'record', CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE row_to_json(NEW)::jsonb END,
    'old_record', CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN row_to_json(OLD)::jsonb ELSE NULL END
  );

  -- Usar pg_net para chamada assíncrona (não bloqueia a transação)
  PERFORM net.http_post(
    url := webhook_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
    ),
    body := payload
  );

  RETURN COALESCE(NEW, OLD);
EXCEPTION
  WHEN OTHERS THEN
    -- Se pg_net não estiver disponível, logar e continuar
    RAISE WARNING 'Webhook notification failed: %', SQLERRM;
    RETURN COALESCE(NEW, OLD);
END;
$$;

-- Trigger: Novo membro → atualizar member_count + welcome
DROP TRIGGER IF EXISTS on_new_member ON public.community_members;
CREATE TRIGGER on_new_member
  AFTER INSERT ON public.community_members
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_webhook();

-- Trigger: Membro saiu → decrementar member_count
DROP TRIGGER IF EXISTS on_member_left ON public.community_members;
CREATE TRIGGER on_member_left
  AFTER DELETE ON public.community_members
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_webhook();

-- Trigger: Novo comentário → notificar autor do post
DROP TRIGGER IF EXISTS on_new_comment ON public.comments;
CREATE TRIGGER on_new_comment
  AFTER INSERT ON public.comments
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_webhook();

-- Trigger: Nova flag → notificar moderadores
DROP TRIGGER IF EXISTS on_new_flag ON public.flags;
CREATE TRIGGER on_new_flag
  AFTER INSERT ON public.flags
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_webhook();

-- Trigger: Novo follow → notificar seguido
DROP TRIGGER IF EXISTS on_new_follow ON public.follows;
CREATE TRIGGER on_new_follow
  AFTER INSERT ON public.follows
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_webhook();

-- Função auxiliar para incrementar comment_count (usada pelo webhook)
CREATE OR REPLACE FUNCTION public.increment_comment_count(p_post_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE posts
  SET comment_count = comment_count + 1
  WHERE id = p_post_id;
END;
$$;

-- ============================================================================
-- Configuração: Setar as variáveis de ambiente para os webhooks
-- (Estas devem ser configuradas no Supabase Dashboard > Settings > Database)
-- ALTER DATABASE postgres SET app.settings.supabase_url = 'https://SEU_PROJETO.supabase.co';
-- ALTER DATABASE postgres SET app.settings.service_role_key = '<service_role_key>';
-- ============================================================================
