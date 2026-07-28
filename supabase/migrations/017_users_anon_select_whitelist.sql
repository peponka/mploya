-- ============================================================================
-- 017 — Cerrar la fuga de PII de verdad (la 016 no alcanzó)
-- ============================================================================
-- La migración 016 hacía `REVOKE SELECT (col...) ON users FROM anon`, pero en
-- Postgres un GRANT de tabla completa NO se puede recortar por columna: si el
-- rol tiene SELECT sobre la tabla, lo tiene sobre todas sus columnas. Se
-- verificó que tras aplicar la 016 el email y el fcm_token seguían siendo
-- legibles con la anon key.
--
-- Forma correcta: revocar el SELECT de tabla y volver a otorgarlo SOLO sobre la
-- lista blanca de columnas públicas.
--
-- `authenticated` NO se toca (la app hace `select()` de todas las columnas en
-- ~122 lugares y se rompería).
-- ============================================================================

REVOKE SELECT ON public.users FROM anon;

GRANT SELECT (
  id,
  name,
  headline,
  about,
  video_url,
  transcript_url,
  skills,
  soft_skills,
  experience,
  education,
  tags,
  company,
  location,               -- texto ("Buenos Aires"), no coordenadas
  city,
  avatar_url,
  banner_url,
  account_type,
  is_premium,
  is_verified,
  is_hiring,
  open_to_work,
  blind_hiring_mode,
  profile_views,
  match_percentage,
  rating_stars,
  rating_count,
  employer_rating_stars,
  employer_rating_count,
  like_count,
  connections,
  created_at
) ON public.users TO anon;

-- Quedan FUERA del alcance de `anon` (lo que se estaba filtrando):
--   email, fcm_token, latitude, longitude, location_geom, salary_expectation,
--   personality_scores, ai_transcript_json, is_admin, b2b_tokens, deleted_at,
--   profile_embedding, push_enabled, email_notifications_enabled,
--   job_alerts_enabled, onboarding_step, boost_* .

-- PostgREST cachea el esquema: forzar recarga para que tome los privilegios.
NOTIFY pgrst, 'reload schema';
