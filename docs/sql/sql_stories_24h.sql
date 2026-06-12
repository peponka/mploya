-- ═══════════════════════════════════════════════════════════════════════════
-- Mploya — Historias 24h (Stories)
-- Pegar en Supabase SQL Editor y ejecutar
--
-- Cada usuario puede publicar stories (texto, imagen o mini-video)
-- que expiran automáticamente a las 24 horas.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. Tabla stories ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.stories (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  content     TEXT,                              -- Texto de la story (opcional)
  media_url   TEXT,                              -- URL de imagen o video (opcional)
  media_type  TEXT DEFAULT 'text'                -- 'text', 'image', 'video'
    CHECK (media_type IN ('text', 'image', 'video')),
  created_at  TIMESTAMPTZ DEFAULT now(),
  expires_at  TIMESTAMPTZ DEFAULT (now() + interval '24 hours')
);

ALTER TABLE public.stories ENABLE ROW LEVEL SECURITY;

-- Todos pueden ver stories no expiradas
CREATE POLICY "Anyone can view non-expired stories"
  ON public.stories FOR SELECT
  USING (expires_at > now());

-- Solo el owner puede crear sus stories
CREATE POLICY "Users can create own stories"
  ON public.stories FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Solo el owner puede borrar sus propias stories
CREATE POLICY "Users can delete own stories"
  ON public.stories FOR DELETE
  USING (auth.uid() = user_id);

-- Índices para queries rápidas
CREATE INDEX IF NOT EXISTS idx_stories_user_id ON public.stories(user_id);
CREATE INDEX IF NOT EXISTS idx_stories_expires_at ON public.stories(expires_at);
CREATE INDEX IF NOT EXISTS idx_stories_created_at ON public.stories(created_at DESC);

GRANT SELECT, INSERT, DELETE ON public.stories TO authenticated;

-- ── 2. Vista de usuarios con stories activas ────────────────────────────
-- Retorna solo los usuarios que tienen al menos 1 story activa (no expirada)
CREATE OR REPLACE VIEW public.active_story_users AS
SELECT DISTINCT
  s.user_id,
  u.name,
  u.headline,
  u.avatar_url,
  u.account_type,
  u.video_url,
  MAX(s.created_at) AS latest_story_at
FROM public.stories s
JOIN public.users u ON u.id = s.user_id
WHERE s.expires_at > now()
GROUP BY s.user_id, u.name, u.headline, u.avatar_url, u.account_type, u.video_url
ORDER BY latest_story_at DESC;

GRANT SELECT ON public.active_story_users TO authenticated;

-- ── 3. Limpieza automática (opcional, ejecutar como pg_cron si disponible) ─
-- DELETE FROM public.stories WHERE expires_at < now();
-- (Se puede programar como CRON job cada 6h en Supabase Extensions > pg_cron)
