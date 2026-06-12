-- ================================================================
-- P0-4 & P0-6: ATS PIPLELINE BATCH Y SEGURIDAD RLS
-- Copia este texto y córrelo en el SQL Editor de tu Supabase.
-- ================================================================

-- 1. Función Maestra para limpiar el Loop N+2 del Kanban ATS
CREATE OR REPLACE FUNCTION public.get_my_pipeline()
RETURNS TABLE(
  connection_id    UUID,
  ats_status       TEXT,
  user_id          UUID,
  user_name        TEXT,
  user_headline    TEXT,
  user_avatar_url  TEXT,
  user_account_type TEXT,
  user_video_url   TEXT,
  is_confidential  BOOLEAN
) LANGUAGE sql SECURITY DEFINER AS $$
  SELECT
    c.id, 
    c.ats_status, 
    u.id,
    CASE WHEN u.account_type LIKE 'confidenc%' THEN 'Candidato Confidencial' ELSE u.name END,
    u.headline,
    CASE WHEN u.account_type LIKE 'confidenc%' THEN NULL ELSE u.avatar_url END,
    u.account_type, 
    u.video_url, 
    (u.account_type LIKE 'confidenc%') AS is_confidential
  FROM public.connections c
  JOIN public.users u ON u.id = CASE
    WHEN c.requester_id = auth.uid() THEN c.addressee_id
    ELSE c.requester_id
  END
  WHERE (c.requester_id = auth.uid() OR c.addressee_id = auth.uid())
    AND c.status != 'blocked'
  ORDER BY c.updated_at DESC;
$$;

-- 2. Parches de Seguridad (RLS) Detectados por Claude
DROP POLICY IF EXISTS "Only participants can update ats_status" ON public.connections;
CREATE POLICY "Only participants can update ats_status"
  ON public.connections FOR UPDATE TO authenticated
  USING (requester_id = auth.uid() OR addressee_id = auth.uid())
  WITH CHECK (requester_id = auth.uid() OR addressee_id = auth.uid());

DROP POLICY IF EXISTS "Signal sender must be authenticated user" ON public.nexus_signals;
CREATE POLICY "Signal sender must be authenticated user"
  ON public.nexus_signals FOR INSERT TO authenticated
  WITH CHECK (sender_id = auth.uid());
