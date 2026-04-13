-- =============================================================================
-- Migration 095 — Sistema de Temas do NexusHub
--
-- Cria a tabela `app_themes` que armazena todos os tokens visuais de cada
-- tema. O Flutter carrega os temas ativos do banco e os converte para
-- NexusThemeData dinâmicos, sem precisar hardcodar no código.
--
-- Estrutura de tokens (JSONB):
--   colors     → todos os tokens de cor (hex string)
--   gradients  → gradientes (array de stops)
--   shadows    → sombras (array de objetos)
--   opacities  → opacidades e doubles
--
-- Integração Flutter:
--   - remoteThemesProvider: FutureProvider que busca temas ativos
--   - NexusThemeData.fromJson(): factory que converte o JSONB
--   - nexusThemeProvider: já existente, aceita NexusThemeData dinâmico
-- =============================================================================

-- ─── Tabela principal ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.app_themes (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Identidade
  slug          TEXT NOT NULL UNIQUE,          -- ex: "midnight", "ocean_blue"
  name          TEXT NOT NULL,                 -- ex: "Midnight", "Ocean Blue"
  description   TEXT DEFAULT '',
  base_mode     TEXT NOT NULL DEFAULT 'dark'   -- 'dark' | 'light'
                CHECK (base_mode IN ('dark', 'light')),

  -- Tokens visuais (JSONB)
  colors        JSONB NOT NULL DEFAULT '{}'::jsonb,
  gradients     JSONB NOT NULL DEFAULT '{}'::jsonb,
  shadows       JSONB NOT NULL DEFAULT '{}'::jsonb,
  opacities     JSONB NOT NULL DEFAULT '{}'::jsonb,

  -- Controle
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  is_builtin    BOOLEAN NOT NULL DEFAULT FALSE, -- TRUE = não pode ser deletado
  sort_order    INTEGER NOT NULL DEFAULT 0,

  -- Auditoria
  created_by    UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_app_themes_active    ON public.app_themes(is_active);
CREATE INDEX IF NOT EXISTS idx_app_themes_sort      ON public.app_themes(sort_order);

-- Trigger de updated_at
CREATE OR REPLACE FUNCTION public.set_app_themes_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_app_themes_updated_at ON public.app_themes;
CREATE TRIGGER trg_app_themes_updated_at
  BEFORE UPDATE ON public.app_themes
  FOR EACH ROW EXECUTE FUNCTION public.set_app_themes_updated_at();

-- ─── RLS ──────────────────────────────────────────────────────────────────────
ALTER TABLE public.app_themes ENABLE ROW LEVEL SECURITY;

-- Leitura pública de temas ativos (app Flutter)
CREATE POLICY "app_themes_read_active"
  ON public.app_themes FOR SELECT
  USING (is_active = TRUE);

-- Escrita apenas para team_admin
CREATE POLICY "app_themes_write_team"
  ON public.app_themes FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
        AND (is_team_admin = TRUE OR is_team_moderator = TRUE)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
        AND (is_team_admin = TRUE OR is_team_moderator = TRUE)
    )
  );

-- ─── Seed: temas built-in ─────────────────────────────────────────────────────

-- Tema Principal (claro)
INSERT INTO public.app_themes (slug, name, description, base_mode, is_builtin, sort_order, colors, gradients, shadows, opacities)
VALUES (
  'principal',
  'Principal',
  'Tema padrão do NexusHub — fundo branco com acentos roxos',
  'light',
  TRUE,
  0,
  '{
    "backgroundPrimary":        "#F8F8FA",
    "backgroundSecondary":      "#EFEFF5",
    "surfacePrimary":           "#FFFFFF",
    "surfaceSecondary":         "#F0F0F5",
    "cardBackground":           "#FFFFFF",
    "cardBackgroundElevated":   "#F5F5FA",
    "modalBackground":          "#FFFFFF",
    "overlayColor":             "#000000",
    "textPrimary":              "#1A1A2E",
    "textSecondary":            "#4A4A6A",
    "textHint":                 "#9090A8",
    "textDisabled":             "#C0C0D0",
    "iconPrimary":              "#1A1A2E",
    "iconSecondary":            "#6A6A8A",
    "iconDisabled":             "#C0C0D0",
    "accentPrimary":            "#7B2FBE",
    "accentSecondary":          "#9B4FDE",
    "buttonPrimaryBackground":  "#7B2FBE",
    "buttonPrimaryForeground":  "#FFFFFF",
    "buttonSecondaryBackground":"#EDE7F6",
    "buttonSecondaryForeground":"#7B2FBE",
    "buttonDestructiveBackground":"#D32F2F",
    "buttonDestructiveForeground":"#FFFFFF",
    "success":                  "#2E7D32",
    "successContainer":         "#E8F5E9",
    "error":                    "#C62828",
    "errorContainer":           "#FFEBEE",
    "warning":                  "#E65100",
    "warningContainer":         "#FFF3E0",
    "info":                     "#1565C0",
    "infoContainer":            "#E3F2FD",
    "borderPrimary":            "#D0D0E0",
    "borderSubtle":             "#E8E8F0",
    "borderFocus":              "#7B2FBE",
    "inputBackground":          "#F5F5FA",
    "inputBorder":              "#D0D0E0",
    "inputHint":                "#9090A8",
    "selectedState":            "#7B2FBE",
    "disabledState":            "#C0C0D0",
    "bottomNavBackground":      "#FFFFFF",
    "bottomNavSelectedItem":    "#7B2FBE",
    "bottomNavUnselectedItem":  "#9090A8",
    "appBarBackground":         "#FFFFFF",
    "appBarForeground":         "#1A1A2E",
    "drawerBackground":         "#F8F8FA",
    "drawerHeaderBackground":   "#EDE7F6",
    "drawerSidebarBackground":  "#4A1A7A",
    "chipBackground":           "#EDE7F6",
    "chipSelectedBackground":   "#7B2FBE",
    "chipText":                 "#4A1A7A",
    "chipSelectedText":         "#FFFFFF",
    "divider":                  "#E0E0EA",
    "shimmerBase":              "#E8E8F2",
    "shimmerHighlight":         "#F5F5FA",
    "levelBadgeBackground":     "#7B2FBE",
    "levelBadgeForeground":     "#FFFFFF",
    "coinColor":                "#B8860B",
    "onlineIndicator":          "#43A047",
    "previewAccent":            "#7B2FBE"
  }'::jsonb,
  '{
    "primaryGradient":   {"colors": ["#7B2FBE", "#9B4FDE"], "begin": "topLeft",   "end": "bottomRight"},
    "accentGradient":    {"colors": ["#9B4FDE", "#B56FFF"], "begin": "topLeft",   "end": "bottomRight"},
    "fabGradient":       {"colors": ["#7B2FBE", "#9B4FDE"], "begin": "topLeft",   "end": "bottomRight"},
    "streakGradient":    {"colors": ["#FF6D00", "#FFAB40"], "begin": "centerLeft","end": "centerRight"},
    "walletGradient":    {"colors": ["#7B2FBE", "#9B4FDE"], "begin": "topCenter", "end": "bottomCenter"},
    "aminoPlusGradient": {"colors": ["#7B2FBE", "#9B4FDE"], "begin": "centerLeft","end": "centerRight"}
  }'::jsonb,
  '{
    "cardShadow":   [{"color": "#1A1A2E14", "blurRadius": 4,  "offsetX": 0, "offsetY": 1}],
    "modalShadow":  [{"color": "#1A1A2E28", "blurRadius": 20, "offsetX": 0, "offsetY": 8}],
    "buttonShadow": [{"color": "#7B2FBE33", "blurRadius": 8,  "offsetX": 0, "offsetY": 3}]
  }'::jsonb,
  '{
    "overlayOpacity":   0.4,
    "disabledOpacity":  0.38
  }'::jsonb
)
ON CONFLICT (slug) DO NOTHING;

-- Tema Midnight (escuro)
INSERT INTO public.app_themes (slug, name, description, base_mode, is_builtin, sort_order, colors, gradients, shadows, opacities)
VALUES (
  'midnight',
  'Midnight',
  'Tema escuro profundo com acentos ciano',
  'dark',
  TRUE,
  1,
  '{
    "backgroundPrimary":        "#0A0A0F",
    "backgroundSecondary":      "#111118",
    "surfacePrimary":           "#16161E",
    "surfaceSecondary":         "#1C1C26",
    "cardBackground":           "#16161E",
    "cardBackgroundElevated":   "#1E1E28",
    "modalBackground":          "#16161E",
    "overlayColor":             "#000000",
    "textPrimary":              "#E8E8F0",
    "textSecondary":            "#9090A8",
    "textHint":                 "#5A5A72",
    "textDisabled":             "#3A3A50",
    "iconPrimary":              "#E8E8F0",
    "iconSecondary":            "#7070A0",
    "iconDisabled":             "#3A3A50",
    "accentPrimary":            "#00D4FF",
    "accentSecondary":          "#00B8E0",
    "buttonPrimaryBackground":  "#00D4FF",
    "buttonPrimaryForeground":  "#000000",
    "buttonSecondaryBackground":"#001A22",
    "buttonSecondaryForeground":"#00D4FF",
    "buttonDestructiveBackground":"#CF6679",
    "buttonDestructiveForeground":"#FFFFFF",
    "success":                  "#00E676",
    "successContainer":         "#003320",
    "error":                    "#CF6679",
    "errorContainer":           "#3B1018",
    "warning":                  "#FFB74D",
    "warningContainer":         "#3B2800",
    "info":                     "#40C4FF",
    "infoContainer":            "#001A2E",
    "borderPrimary":            "#2A2A3A",
    "borderSubtle":             "#1E1E2E",
    "borderFocus":              "#00D4FF",
    "inputBackground":          "#1C1C26",
    "inputBorder":              "#2A2A3A",
    "inputHint":                "#5A5A72",
    "selectedState":            "#00D4FF",
    "disabledState":            "#3A3A50",
    "bottomNavBackground":      "#111118",
    "bottomNavSelectedItem":    "#00D4FF",
    "bottomNavUnselectedItem":  "#5A5A72",
    "appBarBackground":         "#0A0A0F",
    "appBarForeground":         "#E8E8F0",
    "drawerBackground":         "#111118",
    "drawerHeaderBackground":   "#16161E",
    "drawerSidebarBackground":  "#001A22",
    "chipBackground":           "#1C1C26",
    "chipSelectedBackground":   "#00D4FF",
    "chipText":                 "#9090A8",
    "chipSelectedText":         "#000000",
    "divider":                  "#2A2A3A",
    "shimmerBase":              "#1C1C26",
    "shimmerHighlight":         "#2A2A3A",
    "levelBadgeBackground":     "#00D4FF",
    "levelBadgeForeground":     "#000000",
    "coinColor":                "#FFD700",
    "onlineIndicator":          "#00E676",
    "previewAccent":            "#00D4FF"
  }'::jsonb,
  '{
    "primaryGradient":   {"colors": ["#00D4FF", "#0090CC"], "begin": "topLeft",   "end": "bottomRight"},
    "accentGradient":    {"colors": ["#00D4FF", "#00B8E0"], "begin": "topLeft",   "end": "bottomRight"},
    "fabGradient":       {"colors": ["#00D4FF", "#0090CC"], "begin": "topLeft",   "end": "bottomRight"},
    "streakGradient":    {"colors": ["#FF6D00", "#FFAB40"], "begin": "centerLeft","end": "centerRight"},
    "walletGradient":    {"colors": ["#00D4FF", "#0090CC"], "begin": "topCenter", "end": "bottomCenter"},
    "aminoPlusGradient": {"colors": ["#00D4FF", "#0090CC"], "begin": "centerLeft","end": "centerRight"}
  }'::jsonb,
  '{
    "cardShadow":   [{"color": "#00000066", "blurRadius": 8,  "offsetX": 0, "offsetY": 2}],
    "modalShadow":  [{"color": "#00000099", "blurRadius": 24, "offsetX": 0, "offsetY": 8}],
    "buttonShadow": [{"color": "#00D4FF40", "blurRadius": 12, "offsetX": 0, "offsetY": 4}]
  }'::jsonb,
  '{
    "overlayOpacity":  0.6,
    "disabledOpacity": 0.38
  }'::jsonb
)
ON CONFLICT (slug) DO NOTHING;

-- Tema Green Leaf (claro)
INSERT INTO public.app_themes (slug, name, description, base_mode, is_builtin, sort_order, colors, gradients, shadows, opacities)
VALUES (
  'green_leaf',
  'Green Leaf',
  'Tema claro com tons verdes naturais',
  'light',
  TRUE,
  2,
  '{
    "backgroundPrimary":        "#F0F7F2",
    "backgroundSecondary":      "#E4F0E8",
    "surfacePrimary":           "#FFFFFF",
    "surfaceSecondary":         "#EAF4EC",
    "cardBackground":           "#FFFFFF",
    "cardBackgroundElevated":   "#F5FAF6",
    "modalBackground":          "#FFFFFF",
    "overlayColor":             "#1A3A1E",
    "textPrimary":              "#0F1F11",
    "textSecondary":            "#2E4A34",
    "textHint":                 "#4A6A52",
    "textDisabled":             "#B0CCB4",
    "iconPrimary":              "#0F1F11",
    "iconSecondary":            "#2E4A34",
    "iconDisabled":             "#B0CCB4",
    "accentPrimary":            "#1A7A3C",
    "accentSecondary":          "#2E9E50",
    "buttonPrimaryBackground":  "#1A7A3C",
    "buttonPrimaryForeground":  "#FFFFFF",
    "buttonSecondaryBackground":"#2E9E50",
    "buttonSecondaryForeground":"#FFFFFF",
    "buttonDestructiveBackground":"#B71C1C",
    "buttonDestructiveForeground":"#FFFFFF",
    "success":                  "#2E9E50",
    "successContainer":         "#D8F0DC",
    "error":                    "#B71C1C",
    "errorContainer":           "#FFEBEE",
    "warning":                  "#A85200",
    "warningContainer":         "#FFF3E0",
    "info":                     "#1565C0",
    "infoContainer":            "#E3F2FD",
    "borderPrimary":            "#9ECBA8",
    "borderSubtle":             "#C4DEC8",
    "borderFocus":              "#1A7A3C",
    "inputBackground":          "#E4F2E6",
    "inputBorder":              "#9ECBA8",
    "inputHint":                "#4A6A52",
    "selectedState":            "#1A7A3C",
    "disabledState":            "#B0CCB4",
    "bottomNavBackground":      "#FFFFFF",
    "bottomNavSelectedItem":    "#1A7A3C",
    "bottomNavUnselectedItem":  "#4A6650",
    "appBarBackground":         "#FAFDFА",
    "appBarForeground":         "#0F1F11",
    "drawerBackground":         "#F0F7F2",
    "drawerHeaderBackground":   "#D8EDD8",
    "drawerSidebarBackground":  "#2D4A30",
    "chipBackground":           "#D0E8D4",
    "chipSelectedBackground":   "#1A7A3C",
    "chipText":                 "#1A3A22",
    "chipSelectedText":         "#FFFFFF",
    "divider":                  "#C4DEC8",
    "shimmerBase":              "#DCE8DF",
    "shimmerHighlight":         "#EDF7EE",
    "levelBadgeBackground":     "#1A7A3C",
    "levelBadgeForeground":     "#FFFFFF",
    "coinColor":                "#B8860B",
    "onlineIndicator":          "#2E9E50",
    "previewAccent":            "#1A7A3C"
  }'::jsonb,
  '{
    "primaryGradient":   {"colors": ["#1A7A3C", "#2E9E50"], "begin": "topLeft",   "end": "bottomRight"},
    "accentGradient":    {"colors": ["#2E9E50", "#56C27A"], "begin": "topLeft",   "end": "bottomRight"},
    "fabGradient":       {"colors": ["#1A7A3C", "#2E9E50"], "begin": "topLeft",   "end": "bottomRight"},
    "streakGradient":    {"colors": ["#2E9E50", "#56C27A"], "begin": "centerLeft","end": "centerRight"},
    "walletGradient":    {"colors": ["#1A7A3C", "#2E9E50"], "begin": "topCenter", "end": "bottomCenter"},
    "aminoPlusGradient": {"colors": ["#1A7A3C", "#2E9E50"], "begin": "centerLeft","end": "centerRight"}
  }'::jsonb,
  '{
    "cardShadow":   [{"color": "#1A7A3C22", "blurRadius": 6,  "offsetX": 0, "offsetY": 1}],
    "modalShadow":  [{"color": "#1A7A3C2E", "blurRadius": 20, "offsetX": 0, "offsetY": 8}],
    "buttonShadow": [{"color": "#1A7A3C40", "blurRadius": 8,  "offsetX": 0, "offsetY": 3}]
  }'::jsonb,
  '{
    "overlayOpacity":  0.4,
    "disabledOpacity": 0.38
  }'::jsonb
)
ON CONFLICT (slug) DO NOTHING;
