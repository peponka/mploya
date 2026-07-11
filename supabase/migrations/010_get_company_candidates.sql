-- 010_get_company_candidates.sql
--
-- Nueva función para el "Gestor de Talentos" (pantalla Candidatos, vista
-- empresa): trae TODAS las postulaciones reales (job_applications) a las
-- vacantes de la empresa logueada, con el perfil del candidato y la vacante
-- ya unidos. No inventa match score acá (eso ya existe vía RPC
-- match_candidates_for_job y se pide aparte, por vacante, desde el cliente).
--
-- No toca ni reemplaza get_my_pipeline / connections.ats_status (esa es una
-- función distinta, ya rota de antes, que queda pendiente para otra sesión).

CREATE OR REPLACE FUNCTION public.get_company_candidates(p_status text DEFAULT NULL)
RETURNS TABLE (
  application_id uuid,
  candidate_id uuid,
  candidate_name text,
  candidate_headline text,
  candidate_avatar_url text,
  candidate_tags text[],
  job_id uuid,
  job_title text,
  status text,
  applied_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    ja.id AS application_id,
    u.id AS candidate_id,
    u.name::text AS candidate_name,
    u.headline::text AS candidate_headline,
    u.avatar_url::text AS candidate_avatar_url,
    u.tags AS candidate_tags,
    j.id AS job_id,
    j.title::text AS job_title,
    ja.status::text AS status,
    ja.created_at AS applied_at
  FROM public.job_applications ja
  JOIN public.jobs j ON j.id = ja.job_id
  JOIN public.users u ON u.id = ja.candidate_id
  WHERE j.company_id = auth.uid()
    AND (p_status IS NULL OR ja.status = p_status)
  ORDER BY ja.created_at DESC
  LIMIT 200;
$$;

GRANT EXECUTE ON FUNCTION public.get_company_candidates(text) TO authenticated;
