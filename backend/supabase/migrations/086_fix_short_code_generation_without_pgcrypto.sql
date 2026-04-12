-- ============================================================================
-- 086_fix_short_code_generation_without_pgcrypto.sql
-- Corrige a geração de short codes para não depender de gen_random_bytes(),
-- evitando falhas em ambientes onde a função não está resolvível no runtime.
-- Isso afeta diretamente inserts em public.posts por causa do trigger
-- trg_post_short_code, e por consequência quebrava a RPC repost_post.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.generate_short_code(length INT DEFAULT 8)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  chars TEXT := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  result TEXT := '';
  hash_source TEXT;
  hash_value TEXT;
  i INT := 0;
  idx INT;
BEGIN
  IF length IS NULL OR length < 1 THEN
    RAISE EXCEPTION 'length deve ser maior que zero';
  END IF;

  WHILE char_length(result) < length LOOP
    hash_source := md5(
      random()::text ||
      clock_timestamp()::text ||
      txid_current()::text ||
      coalesce(auth.uid()::text, '') ||
      result
    );

    hash_value := hash_source;

    FOR i IN 0..(char_length(hash_value) - 2) BY 2 LOOP
      EXIT WHEN char_length(result) >= length;

      idx := (get_byte(decode(substr(hash_value, i + 1, 2), 'hex'), 0) % 62) + 1;
      result := result || substr(chars, idx, 1);
    END LOOP;
  END LOOP;

  RETURN left(result, length);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_or_create_short_code(
  p_type      TEXT,
  p_target_id UUID
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code TEXT;
  v_attempt INT := 0;
BEGIN
  SELECT code INTO v_code
  FROM public.short_urls
  WHERE type = p_type AND target_id = p_target_id
  LIMIT 1;

  IF v_code IS NOT NULL THEN
    RETURN v_code;
  END IF;

  LOOP
    v_code := public.generate_short_code(8);
    v_attempt := v_attempt + 1;

    BEGIN
      INSERT INTO public.short_urls (code, type, target_id)
      VALUES (v_code, p_type, p_target_id);
      RETURN v_code;
    EXCEPTION WHEN unique_violation THEN
      IF v_attempt >= 10 THEN
        v_code := public.generate_short_code(10);
        INSERT INTO public.short_urls (code, type, target_id)
        VALUES (v_code, p_type, p_target_id);
        RETURN v_code;
      END IF;
    END;
  END LOOP;
END;
$$;
