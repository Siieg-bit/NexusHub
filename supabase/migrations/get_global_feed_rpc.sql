-- RPC: get_global_feed
-- Retorna posts do feed global do usuário com joins embutidos,
-- suportando paginação via p_limit e p_offset.
-- Substitui a query client-side que não tinha paginação.
CREATE OR REPLACE FUNCTION get_global_feed(
  p_user_id uuid,
  p_limit   int DEFAULT 30,
  p_offset  int DEFAULT 0
)
RETURNS SETOF json
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT row_to_json(t)
  FROM (
    SELECT
      p.*,
      row_to_json(pr.*)  AS author,
      json_build_object(
        'id',          c.id,
        'name',        c.name,
        'icon_url',    c.icon_url,
        'theme_color', c.theme_color
      ) AS community
    FROM posts p
    LEFT JOIN profiles    pr ON pr.id = p.author_id
    LEFT JOIN communities c  ON c.id  = p.community_id
    WHERE p.status = 'ok'
      AND p.community_id IN (
        SELECT community_id
        FROM   community_members
        WHERE  user_id = p_user_id
          AND  status  = 'active'
      )
    ORDER BY p.created_at DESC
    LIMIT  p_limit
    OFFSET p_offset
  ) t;
$$;

-- Garante que usuários autenticados possam chamar a função
GRANT EXECUTE ON FUNCTION get_global_feed(uuid, int, int) TO authenticated;
