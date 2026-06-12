-- ═══════════════════════════════════════════════════════════════════════════
-- Mploya — Fase 9: Persistencia de Bookmarks y Reacciones Emoji
-- Pegar en Supabase SQL Editor y ejecutar
-- Fecha: 9/Abril/2026
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. Tabla saved_profiles (Bookmarks / Guardados) ─────────────────────
-- Un usuario puede guardar perfiles de otros usuarios para verlos después.
-- Constraint UNIQUE evita duplicados.

CREATE TABLE IF NOT EXISTS public.saved_profiles (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  saved_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, saved_user_id)
);

-- RLS: Cada usuario solo ve/modifica sus propios bookmarks
ALTER TABLE public.saved_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own bookmarks"
  ON public.saved_profiles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own bookmarks"
  ON public.saved_profiles FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own bookmarks"
  ON public.saved_profiles FOR DELETE
  USING (auth.uid() = user_id);

-- Índice para queries rápidas
CREATE INDEX IF NOT EXISTS idx_saved_profiles_user_id ON public.saved_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_profiles_saved_user_id ON public.saved_profiles(saved_user_id);

-- Grant acceso a usuarios autenticados
GRANT SELECT, INSERT, DELETE ON public.saved_profiles TO authenticated;


-- ── 2. Tabla pitch_reactions (Reacciones Emoji en Video-Pitch) ──────────
-- Un usuario puede reaccionar con un emoji al video-pitch de otro.
-- Solo 1 reacción activa por par (user→target). ON CONFLICT = upsert.

CREATE TABLE IF NOT EXISTS public.pitch_reactions (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id         UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  target_user_id  UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  emoji           TEXT NOT NULL CHECK (emoji IN ('🔥', '💯', '👏', '🚀', '🤝')),
  created_at      TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, target_user_id)
);

-- RLS
ALTER TABLE public.pitch_reactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all reactions"
  ON public.pitch_reactions FOR SELECT
  USING (true);

CREATE POLICY "Users can insert own reactions"
  ON public.pitch_reactions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own reactions"
  ON public.pitch_reactions FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own reactions"
  ON public.pitch_reactions FOR DELETE
  USING (auth.uid() = user_id);

-- Índices
CREATE INDEX IF NOT EXISTS idx_pitch_reactions_user_id ON public.pitch_reactions(user_id);
CREATE INDEX IF NOT EXISTS idx_pitch_reactions_target ON public.pitch_reactions(target_user_id);

-- Grant acceso
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pitch_reactions TO authenticated;


-- ── 3. Vista de conteo de reacciones por usuario (para mostrar en el card) ──
-- Agrupa las reacciones recibidas por cada target_user_id y emoji.

CREATE OR REPLACE VIEW public.pitch_reaction_counts AS
SELECT
  target_user_id,
  emoji,
  COUNT(*)::int AS count
FROM public.pitch_reactions
GROUP BY target_user_id, emoji;

GRANT SELECT ON public.pitch_reaction_counts TO authenticated;


-- ═══════════════════════════════════════════════════════════════════════════
-- ✅ Listo. Ejecutá este script en el SQL Editor de Supabase.
-- Después volvé a Flutter y recargá la app.
-- ═══════════════════════════════════════════════════════════════════════════
