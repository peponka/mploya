-- ============================================================================
-- 019 — Matching híbrido: embedding + skills, con puntaje que discrimina
-- ============================================================================
-- PROBLEMA MEDIDO (28/7/2026). Para la vacante "buscamos ingeniero ia", los
-- mejores candidatos que devolvía `match_candidates_for_job` eran:
--     martin  · cto · [flutter, react, fullstack] · 69%
--     elio    · cto · [lider, finanzas, flutter]  · 65%
--     lose    · cfo · [flutter, react, finanzas]  · 65%
-- Ninguno es ingeniero de IA, y un CFO de finanzas figura con 65%.
--
-- Dos causas:
--  1) Puntaje = coseno puro. Los embeddings de textos cortos en el mismo idioma
--     caen casi todos en 0.60–0.75, así que el ranking casi no discrimina.
--  2) La app mostraba `similarity * 100`, o sea que un match malo se veía como
--     "65%" — infla las expectativas y hace desconfiar del producto.
--
-- SOLUCIÓN:
--  • Score híbrido: 70% señal semántica (embedding) + 30% coincidencia real de
--    skills/tags (Jaccard sobre los tags de la vacante y del candidato).
--  • Reescalado: el coseno útil vive en [0.55, 0.90] → se estira a [0, 1] para
--    que la diferencia entre un buen y un mal match se note.
--  • Umbral: no se devuelven candidatos por debajo de `p_min_score` (default
--    0.25) — es mejor mostrar 3 buenos que 20 de relleno.
--  • Se excluye a la propia empresa dueña de la vacante.
--
-- Se conserva la columna `similarity` (ahora = score final 0–1) para no romper
-- la app, que hace `similarity * 100`; se agregan `semantic_score` y
-- `skill_score` para poder explicar el match.
-- ============================================================================

-- Coincidencia de skills 0–1 (Jaccard: intersección / unión), case-insensitive.
CREATE OR REPLACE FUNCTION public.skill_overlap(a TEXT[], b TEXT[])
RETURNS DOUBLE PRECISION
LANGUAGE sql IMMUTABLE AS $$
  WITH
    x AS (SELECT DISTINCT lower(trim(t)) t FROM unnest(COALESCE(a, '{}')) t WHERE trim(t) <> ''),
    y AS (SELECT DISTINCT lower(trim(t)) t FROM unnest(COALESCE(b, '{}')) t WHERE trim(t) <> ''),
    i AS (SELECT count(*)::double precision c FROM (SELECT t FROM x INTERSECT SELECT t FROM y) s),
    u AS (SELECT count(*)::double precision c FROM (SELECT t FROM x UNION     SELECT t FROM y) s)
  SELECT CASE WHEN (SELECT c FROM u) = 0 THEN 0 ELSE (SELECT c FROM i) / (SELECT c FROM u) END;
$$;

-- Estira el coseno crudo al rango útil [0.55, 0.90] → [0, 1].
CREATE OR REPLACE FUNCTION public.rescale_similarity(sim DOUBLE PRECISION)
RETURNS DOUBLE PRECISION
LANGUAGE sql IMMUTABLE AS $$
  SELECT GREATEST(0, LEAST(1, (COALESCE(sim, 0) - 0.55) / (0.90 - 0.55)));
$$;

-- ── Candidatos para una vacante ─────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.match_candidates_for_job(UUID, INTEGER);
CREATE OR REPLACE FUNCTION public.match_candidates_for_job(
  p_job_id    UUID,
  p_limit     INTEGER DEFAULT 20,
  p_min_score DOUBLE PRECISION DEFAULT 0.25
)
RETURNS TABLE (
  id              UUID,
  name            VARCHAR,
  headline        VARCHAR,
  avatar_url      TEXT,
  account_type    VARCHAR,
  tags            TEXT[],
  similarity      DOUBLE PRECISION,  -- score final 0–1 (lo que muestra la app)
  semantic_score  DOUBLE PRECISION,
  skill_score     DOUBLE PRECISION
)
SECURITY DEFINER
SET search_path = public
LANGUAGE sql STABLE AS $$
  WITH j AS (
    SELECT id, company_id, embedding,
           COALESCE(tags, '{}')::TEXT[] || COALESCE(skills, '{}')::TEXT[] AS want
    FROM public.jobs WHERE id = p_job_id AND embedding IS NOT NULL
  ),
  scored AS (
    SELECT u.id, u.name, u.headline, u.avatar_url, u.account_type,
           COALESCE(u.tags, '{}')::TEXT[] AS tags,
           public.rescale_similarity(1 - (u.profile_embedding <=> j.embedding)) AS sem,
           public.skill_overlap(j.want, COALESCE(u.tags, '{}')::TEXT[]) AS skl
    FROM j
    JOIN public.users u ON TRUE
    WHERE u.profile_embedding IS NOT NULL
      AND u.account_type IN ('candidato', 'confidencial', 'stealth')
      AND u.id <> j.company_id
      AND u.deleted_at IS NULL
  )
  SELECT id, name, headline, avatar_url, account_type, tags,
         (0.7 * sem + 0.3 * skl) AS similarity,
         sem, skl
  FROM scored
  WHERE (0.7 * sem + 0.3 * skl) >= p_min_score
  ORDER BY similarity DESC
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.match_candidates_for_job(UUID, INTEGER, DOUBLE PRECISION)
  TO authenticated;

-- ── Personas parecidas / recomendadas para un usuario ───────────────────────
DROP FUNCTION IF EXISTS public.match_users_by_embedding(UUID, INTEGER);
CREATE OR REPLACE FUNCTION public.match_users_by_embedding(
  p_user_id   UUID,
  p_limit     INTEGER DEFAULT 10,
  p_min_score DOUBLE PRECISION DEFAULT 0.20
)
RETURNS TABLE (
  id             UUID,
  name           VARCHAR,
  headline       VARCHAR,
  avatar_url     TEXT,
  account_type   VARCHAR,
  tags           TEXT[],
  similarity     DOUBLE PRECISION,
  semantic_score DOUBLE PRECISION,
  skill_score    DOUBLE PRECISION
)
SECURITY DEFINER
SET search_path = public
LANGUAGE sql STABLE AS $$
  WITH me AS (
    SELECT id, profile_embedding, COALESCE(tags, '{}')::TEXT[] AS tags, account_type
    FROM public.users WHERE id = p_user_id AND profile_embedding IS NOT NULL
  ),
  scored AS (
    SELECT u.id, u.name, u.headline, u.avatar_url, u.account_type,
           COALESCE(u.tags, '{}')::TEXT[] AS tags,
           public.rescale_similarity(1 - (u.profile_embedding <=> me.profile_embedding)) AS sem,
           public.skill_overlap(me.tags, COALESCE(u.tags, '{}')::TEXT[]) AS skl
    FROM me
    JOIN public.users u ON u.id <> me.id
    WHERE u.profile_embedding IS NOT NULL
      AND u.deleted_at IS NULL
      -- Candidato ve empresas y viceversa; el objetivo es que se encuentren.
      AND (me.account_type IN ('empresa','headhunter')) <> (u.account_type IN ('empresa','headhunter'))
  )
  SELECT id, name, headline, avatar_url, account_type, tags,
         (0.7 * sem + 0.3 * skl) AS similarity,
         sem, skl
  FROM scored
  WHERE (0.7 * sem + 0.3 * skl) >= p_min_score
  ORDER BY similarity DESC
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.match_users_by_embedding(UUID, INTEGER, DOUBLE PRECISION)
  TO authenticated;

NOTIFY pgrst, 'reload schema';
