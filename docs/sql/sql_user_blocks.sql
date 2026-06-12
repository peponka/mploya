-- =========================================================================
-- MIGRACIÓN DE BLOQUEOS (User Blocks) - APPLE APP STORE COMPLIANCE (1.2)
-- =========================================================================
-- Esta tabla permite a los usuarios bloquearse entre sí, lo cual es un
-- requisito estricto y obligatorio de Apple para cualquier red social.

CREATE TABLE IF NOT EXISTS public.user_blocks (
  blocker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (blocker_id, blocked_id)
);

-- Habilitar Reglas de Seguridad (RLS)
ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;

-- Permitir a un usuario gestionar a las personas que él mismo bloqueó
CREATE POLICY "Users manage own blocks"
  ON public.user_blocks FOR ALL
  USING (auth.uid() = blocker_id)
  WITH CHECK (auth.uid() = blocker_id);

-- Opcional (Recomendado): Evitar que perfiles bloqueados se crucen en el future feed
-- Esto lo usará el algoritmo de feed para ocultar a los bloqueados
-- =========================================================================
