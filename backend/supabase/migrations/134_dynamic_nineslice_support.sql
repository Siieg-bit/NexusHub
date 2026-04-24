-- ============================================================================
-- Migração 134: Dynamic NineSlice Support
--
-- Documenta e valida o suporte ao novo modo "dynamic_nineslice" no asset_config
-- dos chat_bubbles. Esta migração NÃO altera o schema (asset_config já é JSONB
-- e aceita qualquer estrutura), apenas:
--
-- 1. Adiciona comentário no schema documentando os novos campos
-- 2. Cria uma função de validação do asset_config para o novo modo
-- 3. Adiciona um índice GIN para consultas eficientes por mode
--
-- Compatibilidade total:
-- - Balões antigos (sem campo "mode") continuam funcionando normalmente
-- - Balões com "mode": "dynamic_nineslice" usam o novo layout pré-calculado
-- - Nenhum dado existente é alterado
--
-- Estrutura do asset_config para o modo dynamic_nineslice:
-- {
--   "mode": "dynamic_nineslice",
--   "bubble_style": "nine_slice",
--   "bubble_url": "https://...",
--   "image_width": 128,
--   "image_height": 128,
--   "slice_top": 20,
--   "slice_bottom": 20,
--   "slice_left": 20,
--   "slice_right": 20,
--   "slice": { "left": 20, "right": 20, "top": 20, "bottom": 20 },
--   "content": {
--     "padding": { "x": 16, "y": 12 },
--     "maxWidth": 260,
--     "minWidth": 60
--   },
--   "behavior": {
--     "horizontalPriority": true,
--     "maxHeightRatio": 0.6,
--     "transitionZone": 0.15
--   }
-- }
-- ============================================================================

-- Comentário no schema documentando os campos do dynamic_nineslice
COMMENT ON COLUMN public.store_items.asset_config IS
'Configurações específicas do item da loja.

Para chat_bubbles, suporta dois modos:

1. Modo clássico (nine_slice):
   bubble_style: "nine_slice"
   slice_top/bottom/left/right: pontos de corte (px)
   content_padding_h/v: padding interno (px)
   pad_top/bottom/left/right: padding individual por lado (px)
   text_color: cor do texto (hex)
   is_animated: true para GIF/WebP animado

2. Modo dinâmico (dynamic_nineslice):
   mode: "dynamic_nineslice"
   slice: { left, right, top, bottom } — pontos de corte (px)
   content: { padding: { x, y }, maxWidth, minWidth }
   behavior: { horizontalPriority, maxHeightRatio, transitionZone }

   No modo dinâmico, o layout é pré-calculado com TextPainter antes
   de renderizar, garantindo que o balão se ajuste ao conteúdo sem
   distorção. Crescimento prioritariamente horizontal; vertical apenas
   quando necessário (quebra de linha).

Compatibilidade: itens sem campo "mode" usam o comportamento clássico.';

-- Índice GIN para consultas eficientes por mode no asset_config
-- Útil para queries como: WHERE asset_config->>'mode' = 'dynamic_nineslice'
CREATE INDEX IF NOT EXISTS idx_store_items_asset_config_gin
  ON public.store_items USING GIN (asset_config);

-- Função de validação do asset_config para o modo dynamic_nineslice
-- Pode ser usada em triggers ou em validações do editor web
CREATE OR REPLACE FUNCTION public.validate_dynamic_nineslice_config(
  p_asset_config JSONB
) RETURNS JSONB AS $$
DECLARE
  v_mode TEXT;
  v_errors JSONB := '[]'::jsonb;
  v_content JSONB;
  v_behavior JSONB;
  v_slice JSONB;
BEGIN
  v_mode := p_asset_config->>'mode';

  -- Se não é dynamic_nineslice, retorna válido (compatibilidade)
  IF v_mode IS DISTINCT FROM 'dynamic_nineslice' THEN
    RETURN jsonb_build_object('valid', true, 'mode', 'classic', 'errors', '[]'::jsonb);
  END IF;

  -- Valida campos obrigatórios do modo dinâmico
  v_content  := p_asset_config->'content';
  v_behavior := p_asset_config->'behavior';
  v_slice    := p_asset_config->'slice';

  -- Verifica se tem URL da imagem
  IF p_asset_config->>'bubble_url' IS NULL
     AND p_asset_config->>'image_url' IS NULL
     AND p_asset_config->>'bubble_image_url' IS NULL THEN
    v_errors := v_errors || '"bubble_url é obrigatório"'::jsonb;
  END IF;

  -- Verifica content.maxWidth
  IF v_content IS NOT NULL THEN
    IF (v_content->>'maxWidth')::numeric < 60 THEN
      v_errors := v_errors || '"content.maxWidth deve ser >= 60"'::jsonb;
    END IF;
    IF (v_content->>'minWidth')::numeric > (v_content->>'maxWidth')::numeric THEN
      v_errors := v_errors || '"content.minWidth deve ser <= maxWidth"'::jsonb;
    END IF;
  END IF;

  -- Verifica behavior.transitionZone
  IF v_behavior IS NOT NULL THEN
    IF (v_behavior->>'transitionZone')::numeric < 0
       OR (v_behavior->>'transitionZone')::numeric > 0.5 THEN
      v_errors := v_errors || '"behavior.transitionZone deve estar entre 0 e 0.5"'::jsonb;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'valid', jsonb_array_length(v_errors) = 0,
    'mode', 'dynamic_nineslice',
    'errors', v_errors
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Exemplo de uso da função de validação:
-- SELECT validate_dynamic_nineslice_config(asset_config) FROM store_items WHERE type = 'chat_bubble';

COMMENT ON FUNCTION public.validate_dynamic_nineslice_config IS
'Valida o asset_config de um store_item para o modo dynamic_nineslice.
Retorna { valid: bool, mode: string, errors: string[] }.
Compatível com o modo clássico (retorna valid=true para itens sem mode).';
