-- ================================================================
-- MPLOYA — Conexiones Reales: Mutual Count + Recomendaciones IA
-- Ejecutar en Supabase SQL Editor
-- ================================================================

-- ── 1. Contar conexiones mutuas (server-side, 1 sola query) ─────
CREATE OR REPLACE FUNCTION public.get_mutual_connections_count(p_other_user_id UUID)
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER STABLE AS $$
DECLARE
  v_me UUID := auth.uid();
  v_count INT;
BEGIN
  IF v_me IS NULL THEN RETURN 0; END IF;

  -- Mis contactos aceptados
  WITH my_contacts AS (
    SELECT CASE WHEN requester_id = v_me THEN addressee_id ELSE requester_id END AS contact_id
    FROM public.connections
    WHERE status = 'accepted'
      AND (requester_id = v_me OR addressee_id = v_me)
  ),
  -- Contactos del otro usuario
  their_contacts AS (
    SELECT CASE WHEN requester_id = p_other_user_id THEN addressee_id ELSE requester_id END AS contact_id
    FROM public.connections
    WHERE status = 'accepted'
      AND (requester_id = p_other_user_id OR addressee_id = p_other_user_id)
  )
  SELECT COUNT(*) INTO v_count
  FROM my_contacts mc
  INNER JOIN their_contacts tc ON mc.contact_id = tc.contact_id;

  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_mutual_connections_count(UUID) TO authenticated;


-- ── 2. Usuarios recomendados con score real ─────────────────────
-- Rankea usuarios según:
--   • Tags/skills en común (peso 40)
--   • Misma ubicación (peso 20)
--   • Tiene video pitch (peso 15)  
--   • Rating alto (peso 15)
--   • Boosted activo (peso 10)
-- Excluye usuarios ya conectados y al usuario actual.
CREATE OR REPLACE FUNCTION public.get_recommended_users(
  p_limit INT DEFAULT 30
)
RETURNS TABLE (
  user_id UUID,
  name TEXT,
  headline TEXT,
  avatar_url TEXT,
  account_type TEXT,
  location TEXT,
  tags TEXT[],
  video_url TEXT,
  rating_stars FLOAT,
  is_premium BOOLEAN,
  is_verified BOOLEAN,
  connections INT,
  mutual_count BIGINT,
  affinity_score FLOAT
) LANGUAGE plpgsql SECURITY DEFINER STABLE AS $$
DECLARE
  v_me UUID := auth.uid();
  v_my_tags TEXT[];
  v_my_location TEXT;
  v_my_type TEXT;
BEGIN
  IF v_me IS NULL THEN RETURN; END IF;

  -- Obtener datos del usuario actual
  SELECT u.tags, u.location, u.account_type
  INTO v_my_tags, v_my_location, v_my_type
  FROM public.users u
  WHERE u.id = v_me;

  -- Crear CTE de mis contactos para mutual count
  RETURN QUERY
  WITH my_contacts AS (
    SELECT CASE WHEN requester_id = v_me THEN addressee_id ELSE requester_id END AS contact_id
    FROM public.connections
    WHERE status = 'accepted'
      AND (requester_id = v_me OR addressee_id = v_me)
  ),
  existing_connections AS (
    SELECT CASE WHEN requester_id = v_me THEN addressee_id ELSE requester_id END AS connected_id
    FROM public.connections
    WHERE (requester_id = v_me OR addressee_id = v_me)
      AND status IN ('pending', 'accepted')
  )
  SELECT
    u.id AS user_id,
    u.name::TEXT,
    u.headline::TEXT,
    u.avatar_url::TEXT,
    u.account_type::TEXT,
    u.location::TEXT,
    u.tags,
    u.video_url::TEXT,
    u.rating_stars::FLOAT,
    u.is_premium,
    u.is_verified,
    u.connections,
    -- Mutual connections count
    (SELECT COUNT(*) FROM my_contacts mc
     INNER JOIN (
       SELECT CASE WHEN c2.requester_id = u.id THEN c2.addressee_id ELSE c2.requester_id END AS cid
       FROM public.connections c2
       WHERE c2.status = 'accepted' AND (c2.requester_id = u.id OR c2.addressee_id = u.id)
     ) tc ON mc.contact_id = tc.cid
    )::BIGINT AS mutual_count,
    -- Affinity score calculation
    (
      -- Tags en común (peso 40): cada tag en común suma puntos
      COALESCE(
        (SELECT COUNT(*)::FLOAT FROM unnest(u.tags) t WHERE t = ANY(v_my_tags)) * 40.0
        / GREATEST(array_length(v_my_tags, 1), 1)::FLOAT,
        0
      )
      -- Misma ubicación (peso 20)
      + CASE WHEN u.location IS NOT NULL AND v_my_location IS NOT NULL
              AND LOWER(u.location) = LOWER(v_my_location) THEN 20.0 ELSE 0.0 END
      -- Tiene video pitch (peso 15)
      + CASE WHEN u.video_url IS NOT NULL AND u.video_url <> '' THEN 15.0 ELSE 0.0 END
      -- Rating alto (peso 15): escala lineal 0-5 → 0-15
      + (COALESCE(u.rating_stars, 0) / 5.0 * 15.0)
      -- Boost activo (peso 10)
      + CASE WHEN u.boost_ends_at IS NOT NULL AND u.boost_ends_at > NOW() THEN 10.0 ELSE 0.0 END
    )::FLOAT AS affinity_score
  FROM public.users u
  WHERE u.id <> v_me
    AND u.id NOT IN (SELECT connected_id FROM existing_connections)
  ORDER BY affinity_score DESC, u.rating_stars DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_recommended_users(INT) TO authenticated;
