-- ============================================================================
-- 024 — Vista `active_story_users` (faltaba: StoryRow consultaba una vista inexistente)
-- ============================================================================
-- Hallazgo de la auditoría (29/7/2026): las tablas `stories` y `story_likes`
-- existen y desde el feed se pueden crear y ver historias, pero el widget
-- `StoryRow` (la fila de círculos) consultaba `public.active_story_users`, que
-- NUNCA existió → la consulta fallaba y la fila nunca mostraba nada. Encima el
-- widget tampoco estaba montado en ninguna pantalla.
--
-- Esta vista devuelve un usuario por fila con la fecha de su historia más
-- reciente vigente, que es justo lo que el widget ordena y filtra.
-- ============================================================================

CREATE OR REPLACE VIEW public.active_story_users
WITH (security_invoker = true) AS
SELECT
  s.user_id,
  max(s.created_at) AS latest_story_at,
  count(*)          AS story_count
FROM public.stories s
WHERE COALESCE(s.is_active, true)
  AND (s.expires_at IS NULL OR s.expires_at > now())
GROUP BY s.user_id;

GRANT SELECT ON public.active_story_users TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
