-- ============================================================================
-- 025 — Tapar la fuga de PII que quedaba por la vista `feed_ranked`
-- ============================================================================
-- Las migraciones 017/021/022 cerraron el acceso a email, fcm_token y
-- profile_embedding sobre la TABLA `users`… pero no sobre las VISTAS construidas
-- encima. `feed_ranked` seleccionaba email y fcm_token y, al no tener
-- security_invoker, corre con permisos de su dueño (postgres): saltea por
-- completo los privilegios de columna.
--
-- Verificado con la anon key (pública) el 29/7/2026:
--   curl '.../rest/v1/feed_ranked?select=name,email,fcm_token'
--   → [{"name":"mploya","email":"bulos@gmail.com","fcm_token":"eArNOV…"}]
--
-- Es decir: la fuga seguía abierta por otra puerta. Se recrea la vista sin esas
-- dos columnas (la app no las usa: kUserColumns tampoco las pide) y con
-- security_invoker para que en adelante respete el RLS y los privilegios de
-- quien consulta, en vez de los del dueño.
-- ============================================================================

DROP VIEW IF EXISTS public.feed_ranked;

CREATE VIEW public.feed_ranked
WITH (security_invoker = true) AS
SELECT
  id, name, headline, about, video_url, transcript_url, skills, experience,
  education, is_premium, is_verified, open_to_work, location, created_at,
  avatar_url, banner_url, company, profile_views, is_hiring, latitude, longitude,
  match_percentage, rating_stars, rating_count, like_count, connections,
  ai_transcript_json, account_type, tags, location_geom, onboarding_step, city,
  boost_ends_at, boost_type, boost_target_city, salary_expectation,
  (CASE WHEN boost_ends_at > now() THEN 1000 ELSE 0 END)
  + (CASE WHEN is_premium THEN 100 ELSE 0 END) AS base_score
FROM public.users u
WHERE video_url IS NOT NULL AND video_url <> ''::text;

GRANT SELECT ON public.feed_ranked TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
