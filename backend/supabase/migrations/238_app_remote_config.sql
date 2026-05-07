-- =============================================================================
-- Migration 238 — App Remote Config
--
-- Cria a tabela `app_remote_config` para armazenar configurações globais
-- do app NexusHub que antes estavam hardcoded no APK Flutter.
--
-- Categorias de configuração:
--   - limits.*      → limites de texto, mídia e paginação
--   - rate_limits.* → rate limits client-side por ação
--   - links.*       → URLs e webhooks de suporte/integração
--   - ads.*         → configurações de anúncios (AdMob)
--   - iap.*         → pacotes de moedas (IAP fallback)
--   - features.*    → feature flags globais
--
-- RLS:
--   - Qualquer usuário autenticado pode ler
--   - Apenas platform_admin pode escrever
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.app_remote_config (
  key        TEXT PRIMARY KEY,
  value      JSONB NOT NULL,
  category   TEXT NOT NULL DEFAULT 'general',
  description TEXT DEFAULT '',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índice por categoria para facilitar buscas no admin
CREATE INDEX IF NOT EXISTS idx_app_remote_config_category
  ON public.app_remote_config(category);

-- RLS
ALTER TABLE public.app_remote_config ENABLE ROW LEVEL SECURITY;

-- Qualquer usuário autenticado pode ler
CREATE POLICY "app_remote_config_read" ON public.app_remote_config
  FOR SELECT TO authenticated
  USING (TRUE);

-- Apenas platform_admin pode escrever
CREATE POLICY "app_remote_config_admin_write" ON public.app_remote_config
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_team_admin = TRUE
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_team_admin = TRUE
    )
  );

-- Trigger de updated_at
CREATE OR REPLACE FUNCTION public.set_app_remote_config_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS app_remote_config_updated_at ON public.app_remote_config;
CREATE TRIGGER app_remote_config_updated_at
  BEFORE UPDATE ON public.app_remote_config
  FOR EACH ROW EXECUTE FUNCTION public.set_app_remote_config_updated_at();

-- RPC para buscar todas as configs de uma vez (otimiza o fetch no app start)
CREATE OR REPLACE FUNCTION public.get_app_remote_config()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result JSONB := '{}'::jsonb;
  rec RECORD;
BEGIN
  FOR rec IN SELECT key, value FROM public.app_remote_config LOOP
    result := result || jsonb_build_object(rec.key, rec.value);
  END LOOP;
  RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_app_remote_config() TO authenticated;

-- =============================================================================
-- Seed: inserir os valores que estavam hardcoded no Flutter
-- =============================================================================

INSERT INTO public.app_remote_config (key, value, category, description)
VALUES

-- ── LIMITES DE TEXTO ──────────────────────────────────────────────────────────
('limits.max_post_title_length',    '300',   'limits', 'Tamanho máximo do título de um post'),
('limits.max_post_content_length',  '10000', 'limits', 'Tamanho máximo do conteúdo de um post'),
('limits.max_comment_length',       '2000',  'limits', 'Tamanho máximo de um comentário'),
('limits.max_message_length',       '5000',  'limits', 'Tamanho máximo de uma mensagem de chat'),
('limits.max_bio_length',           '500',   'limits', 'Tamanho máximo da bio do perfil'),
('limits.max_community_name_length','100',   'limits', 'Tamanho máximo do nome de uma comunidade'),
('limits.max_media_per_post',       '10',    'limits', 'Número máximo de mídias por post'),
('limits.max_avatar_size_bytes',    '5242880','limits','Tamanho máximo do avatar em bytes (5MB)'),
('limits.max_nickname_length',      '30',    'limits', 'Tamanho máximo do nickname'),
('limits.min_nickname_length',      '3',     'limits', 'Tamanho mínimo do nickname'),
('limits.max_tags_per_post',        '10',    'limits', 'Número máximo de tags por post'),
('limits.max_community_desc_length','1000',  'limits', 'Tamanho máximo da descrição de comunidade'),
('limits.max_chat_members',         '1000',  'limits', 'Número máximo de membros em um chat'),

-- ── PAGINAÇÃO ─────────────────────────────────────────────────────────────────
('pagination.feed_page_size',        '20',  'pagination', 'Itens por página no feed'),
('pagination.chat_page_size',        '50',  'pagination', 'Mensagens por página no chat'),
('pagination.search_page_size',      '20',  'pagination', 'Itens por página na busca'),
('pagination.leaderboard_page_size', '50',  'pagination', 'Itens por página no leaderboard'),
('pagination.comments_page_size',    '30',  'pagination', 'Comentários por página'),

-- ── RATE LIMITS (client-side) ─────────────────────────────────────────────────
('rate_limits.post_create',     '{"max": 5,   "window": 3600}', 'rate_limits', '5 posts por hora'),
('rate_limits.comment_create',  '{"max": 30,  "window": 3600}', 'rate_limits', '30 comentários por hora'),
('rate_limits.message_send',    '{"max": 60,  "window": 60}',   'rate_limits', '60 mensagens por minuto'),
('rate_limits.like_toggle',     '{"max": 120, "window": 60}',   'rate_limits', '120 likes por minuto'),
('rate_limits.report_create',   '{"max": 10,  "window": 3600}', 'rate_limits', '10 reports por hora'),
('rate_limits.transfer_coins',  '{"max": 20,  "window": 3600}', 'rate_limits', '20 transferências por hora'),
('rate_limits.wiki_create',     '{"max": 10,  "window": 3600}', 'rate_limits', '10 wikis por hora'),
('rate_limits.profile_update',  '{"max": 10,  "window": 300}',  'rate_limits', '10 atualizações de perfil por 5 minutos'),
('rate_limits.search',          '{"max": 30,  "window": 60}',   'rate_limits', '30 buscas por minuto'),
('rate_limits.auth_attempt',    '{"max": 5,   "window": 300}',  'rate_limits', '5 tentativas de login por 5 minutos'),

-- ── LINKS E WEBHOOKS ──────────────────────────────────────────────────────────
('links.discord_bug_report_webhook',
  '"https://discord.com/api/webhooks/1499274845739814934/L1eV_WkUi7FZZ3ibZ74LRAKmg0GkTKyQlgmm8gATNXezLq4-jc5aOto_bRQBOr9zinqw"',
  'links', 'Webhook do Discord para bug reports'),
('links.support_email',   '"suporte@nexushub.app"', 'links', 'Email de suporte'),
('links.discord_server',  '"discord.gg/nexushub"',  'links', 'Servidor Discord da comunidade'),
('links.faq_url',         '"nexushub.app/faq"',     'links', 'URL do FAQ'),
('links.deep_link_scheme','"nexushub"',              'links', 'Scheme de deep link'),
('links.deep_link_host',  '"app.nexushub.io"',      'links', 'Host de deep link'),

-- ── ANÚNCIOS (AdMob) ──────────────────────────────────────────────────────────
('ads.max_daily_rewarded_ads',  '3',     'ads', 'Limite diário de anúncios recompensados por usuário'),
('ads.rewarded_coins_per_ad',   '5',     'ads', 'Moedas ganhas por anúncio assistido'),

-- ── IAP — PACOTES DE MOEDAS (fallback antes do RevenueCat responder) ──────────
('iap.coin_packages', '[
  {"id": "coins_100",  "coins": 100,  "price_label": "R$ 4,90"},
  {"id": "coins_500",  "coins": 500,  "price_label": "R$ 19,90"},
  {"id": "coins_1200", "coins": 1200, "price_label": "R$ 39,90"},
  {"id": "coins_3000", "coins": 3000, "price_label": "R$ 89,90"},
  {"id": "coins_7000", "coins": 7000, "price_label": "R$ 179,90"}
]', 'iap', 'Pacotes de moedas exibidos antes do RevenueCat responder'),

-- ── FEATURE FLAGS ─────────────────────────────────────────────────────────────
('features.voice_chat_enabled',      'true',  'features', 'Habilitar voice chat (requer Agora App ID)'),
('features.screening_enabled',       'true',  'features', 'Habilitar sala de projeção'),
('features.rpg_mode_enabled',        'true',  'features', 'Habilitar modo RPG nos chats'),
('features.ads_enabled',             'true',  'features', 'Habilitar anúncios recompensados'),
('features.iap_enabled',             'true',  'features', 'Habilitar compras in-app'),
('features.ai_roleplay_enabled',     'true',  'features', 'Habilitar IA de roleplay'),
('features.maintenance_mode',        'false', 'features', 'Modo de manutenção (bloqueia login)'),
('features.min_app_version',         '"1.0.0"','features','Versão mínima do app (force update)')

ON CONFLICT (key) DO UPDATE SET
  value       = EXCLUDED.value,
  category    = EXCLUDED.category,
  description = EXCLUDED.description;
