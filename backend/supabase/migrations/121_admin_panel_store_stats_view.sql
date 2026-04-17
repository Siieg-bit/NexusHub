-- ============================================================
-- Migração 121: View store_stats para o painel administrativo
-- Cria/atualiza a view materializada com estatísticas da loja
-- ============================================================

-- Drop e recria a view store_stats para o painel admin
DROP VIEW IF EXISTS store_stats;

CREATE OR REPLACE VIEW store_stats AS
SELECT
  (SELECT COUNT(*) FROM store_items WHERE is_active = true)::int AS active_items,
  (SELECT COUNT(*) FROM store_items)::int AS total_items,
  (SELECT COUNT(*) FROM sticker_packs WHERE is_user_created = false AND is_active = true)::int AS official_packs,
  (SELECT COUNT(*) FROM user_purchases)::int AS total_purchases,
  (SELECT COALESCE(SUM(ABS(amount)), 0) FROM coin_transactions WHERE amount < 0)::bigint AS total_coins_spent,
  (SELECT COUNT(*) FROM app_themes WHERE is_active = true)::int AS active_themes,
  (SELECT COUNT(*) FROM profiles)::int AS total_users;

-- Garantir que a view é acessível para usuários autenticados
GRANT SELECT ON store_stats TO authenticated;
GRANT SELECT ON store_stats TO anon;

-- ============================================================
-- Políticas RLS para o painel admin (store_items)
-- Admins e moderadores podem gerenciar itens da loja
-- ============================================================

-- Verificar se a política de admin já existe antes de criar
DO $$
BEGIN
  -- Política para admins/moderadores gerenciarem store_items
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'store_items'
    AND policyname = 'team_admin_manage_store_items'
  ) THEN
    CREATE POLICY "team_admin_manage_store_items"
    ON store_items
    FOR ALL
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND (profiles.is_team_admin = true OR profiles.is_team_moderator = true)
      )
    )
    WITH CHECK (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND (profiles.is_team_admin = true OR profiles.is_team_moderator = true)
      )
    );
  END IF;

  -- Política para admins/moderadores gerenciarem sticker_packs
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'sticker_packs'
    AND policyname = 'team_admin_manage_sticker_packs'
  ) THEN
    CREATE POLICY "team_admin_manage_sticker_packs"
    ON sticker_packs
    FOR ALL
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND (profiles.is_team_admin = true OR profiles.is_team_moderator = true)
      )
    )
    WITH CHECK (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND (profiles.is_team_admin = true OR profiles.is_team_moderator = true)
      )
    );
  END IF;

  -- Política para admins/moderadores gerenciarem stickers
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'stickers'
    AND policyname = 'team_admin_manage_stickers'
  ) THEN
    CREATE POLICY "team_admin_manage_stickers"
    ON stickers
    FOR ALL
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND (profiles.is_team_admin = true OR profiles.is_team_moderator = true)
      )
    )
    WITH CHECK (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND (profiles.is_team_admin = true OR profiles.is_team_moderator = true)
      )
    );
  END IF;

  -- Política para admins/moderadores gerenciarem app_themes
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'app_themes'
    AND policyname = 'team_admin_manage_app_themes'
  ) THEN
    CREATE POLICY "team_admin_manage_app_themes"
    ON app_themes
    FOR ALL
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND (profiles.is_team_admin = true OR profiles.is_team_moderator = true)
      )
    )
    WITH CHECK (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND (profiles.is_team_admin = true OR profiles.is_team_moderator = true)
      )
    );
  END IF;
END $$;
