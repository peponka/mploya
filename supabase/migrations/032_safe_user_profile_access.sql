-- ============================================================================
-- 032 - Capa aditiva segura para lectura de perfiles
-- ============================================================================
-- Esta migracion NO reemplaza ni revoca el acceso actual a public.users.
-- Agrega contratos seguros para migrar consumidores antes del enforcement:
--
--   Descubrimiento publico:
--     Feed, Busqueda, Red, perfiles publicos, guardados, deep links, stories,
--     hashtags, posts y tarjetas sociales -> public.safe_user_profiles.
--
--   Perfil propio:
--     auth, splash, Perfil, onboarding, formularios, ajustes y herramientas
--     -> public.get_my_profile(). Los campos privados que esta primera RPC no
--     devuelve necesitaran RPC especificas antes de cerrar public.users.
--     Campos privados incluidos por consumidor en la primera tanda:
--       * UserProvider/NexUser: location, latitude, longitude y
--         ai_transcript_json.
--       * CandidateProfileForm: salary_expectation para editar el dato propio.
--       * Splash/RoleSelection: onboarding_step y account_type.
--       * CompanyProfileForm: account_type para preservar headhunter.
--     No se incluyen is_admin, FCM, embeddings, tokens, boosts, borrado ni
--     otros campos economicos o internos.
--
--   Acceso por relacion:
--     Mensajes, notificaciones, postulaciones, entrevistas, Talent Feed,
--     Shortlist y Pipeline -> RPC especificas por relacion. No deben migrarse
--     a una proyeccion publica que ignore permisos de negocio.
--
-- El enforcement sobre SELECT directo solo puede ocurrir despues de migrar y
-- probar esos grupos. Esta migracion es deliberadamente aditiva.
-- ============================================================================

BEGIN;

CREATE OR REPLACE VIEW public.safe_user_profiles
WITH (security_barrier = true, security_invoker = false)
AS
SELECT
  u.id,
  u.name::TEXT AS name,
  u.headline::TEXT AS headline,
  u.about::TEXT AS about,
  u.video_url,
  u.skills,
  u.experience,
  u.education,
  u.is_premium,
  u.is_verified,
  u.open_to_work,
  u.created_at,
  u.avatar_url,
  u.banner_url,
  u.company,
  u.profile_views,
  u.is_hiring,
  u.rating_stars,
  u.rating_count,
  u.like_count,
  u.connections,
  u.account_type::TEXT AS account_type,
  u.tags,
  u.city,
  u.soft_skills,
  u.employer_rating_stars,
  u.employer_rating_count,
  u.blind_hiring_mode
FROM public.users u
WHERE u.deleted_at IS NULL
  AND lower(btrim(COALESCE(u.account_type::TEXT, ''))) <> 'stealth'
  AND lower(btrim(COALESCE(u.account_type::TEXT, ''))) NOT LIKE 'confidenc%'
  AND lower(btrim(COALESCE(u.account_type::TEXT, ''))) NOT LIKE 'confidential%';

REVOKE ALL ON public.safe_user_profiles
  FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON public.safe_user_profiles TO authenticated;

COMMENT ON VIEW public.safe_user_profiles IS
  'Proyeccion publica minima. Excluye perfiles confidenciales server-side y no contiene PII privada, coordenadas, salario, IA, tokens, boosts ni privilegios.';


CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS TABLE (
  id UUID,
  name TEXT,
  headline TEXT,
  about TEXT,
  video_url TEXT,
  skills JSONB,
  experience JSONB,
  education JSONB,
  is_premium BOOLEAN,
  is_verified BOOLEAN,
  open_to_work BOOLEAN,
  location TEXT,
  created_at TIMESTAMPTZ,
  avatar_url TEXT,
  banner_url TEXT,
  company TEXT,
  profile_views INTEGER,
  is_hiring BOOLEAN,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  rating_stars DOUBLE PRECISION,
  rating_count INTEGER,
  like_count INTEGER,
  connections INTEGER,
  ai_transcript_json JSONB,
  account_type TEXT,
  tags TEXT[],
  onboarding_step INTEGER,
  city TEXT,
  salary_expectation TEXT,
  soft_skills JSONB,
  employer_rating_stars NUMERIC,
  employer_rating_count INTEGER,
  blind_hiring_mode BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'get_my_profile: sesion no disponible'
      USING ERRCODE = '28000';
  END IF;

  RETURN QUERY
  SELECT
    u.id,
    u.name::TEXT,
    u.headline::TEXT,
    u.about::TEXT,
    u.video_url,
    u.skills,
    u.experience,
    u.education,
    u.is_premium,
    u.is_verified,
    u.open_to_work,
    u.location::TEXT,
    u.created_at,
    u.avatar_url,
    u.banner_url,
    u.company,
    u.profile_views,
    u.is_hiring,
    u.latitude,
    u.longitude,
    u.rating_stars,
    u.rating_count,
    u.like_count,
    u.connections,
    u.ai_transcript_json,
    u.account_type::TEXT,
    u.tags,
    u.onboarding_step,
    u.city,
    u.salary_expectation,
    u.soft_skills,
    u.employer_rating_stars,
    u.employer_rating_count,
    u.blind_hiring_mode
  FROM public.users u
  WHERE u.id = v_actor
    AND u.deleted_at IS NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_profile()
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_my_profile() TO authenticated;

COMMENT ON FUNCTION public.get_my_profile() IS
  'Perfil privado del actor autenticado. Nunca acepta un user_id y solo devuelve auth.uid(); omite privilegios, tokens y campos internos.';


-- Seleccion inicial de familia de cuenta. `confidencial` es una variante de
-- Candidato, no una cuarta familia con permisos propios.
CREATE OR REPLACE FUNCTION public.set_my_initial_role(
  p_role TEXT,
  p_complete_selection BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (selected_role TEXT, selected_onboarding_step INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_role TEXT := lower(btrim(COALESCE(p_role, '')));
  v_email TEXT;
  v_name TEXT;
  v_existing_role TEXT;
  v_existing_step INTEGER;
  v_user_exists BOOLEAN;
  v_inserted BOOLEAN := FALSE;
  v_role_row public.users%ROWTYPE;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'set_my_initial_role: sesion no disponible'
      USING ERRCODE = '28000';
  END IF;
  IF p_complete_selection IS NULL THEN
    RAISE EXCEPTION 'set_my_initial_role: progreso invalido'
      USING ERRCODE = '22023';
  END IF;
  IF v_role NOT IN ('candidato', 'confidencial', 'empresa', 'headhunter') THEN
    RAISE EXCEPTION 'set_my_initial_role: rol no permitido'
      USING ERRCODE = '22023';
  END IF;

  SELECT
    au.email::TEXT,
    COALESCE(
      NULLIF(btrim(au.raw_user_meta_data ->> 'name'), ''),
      NULLIF(btrim(au.raw_user_meta_data ->> 'full_name'), ''),
      NULLIF(split_part(COALESCE(au.email, ''), '@', 1), ''),
      'Usuario'
    )
  INTO v_email, v_name
  FROM auth.users au
  WHERE au.id = v_actor;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'set_my_initial_role: sesion no disponible'
      USING ERRCODE = '28000';
  END IF;

  SELECT u.account_type::TEXT, COALESCE(u.onboarding_step, 0)
  INTO v_existing_role, v_existing_step
  FROM public.users u
  WHERE u.id = v_actor
  FOR UPDATE;
  v_user_exists := FOUND;

  -- Convierte de TEXT al tipo vivo de account_type (TEXT, VARCHAR o enum).
  SELECT * INTO v_role_row
  FROM jsonb_populate_record(
    NULL::public.users,
    jsonb_build_object('account_type', v_role)
  );

  IF NOT v_user_exists THEN
    INSERT INTO public.users (
      id, email, name, account_type, onboarding_step
    ) VALUES (
      v_actor,
      v_email,
      v_name,
      v_role_row.account_type,
      CASE WHEN p_complete_selection THEN 1 ELSE 0 END
    )
    ON CONFLICT (id) DO NOTHING;
    v_inserted := FOUND;

    -- El trigger de auth puede ganar la carrera entre el SELECT y el INSERT.
    IF NOT v_inserted THEN
      SELECT u.account_type::TEXT, COALESCE(u.onboarding_step, 0)
      INTO v_existing_role, v_existing_step
      FROM public.users u
      WHERE u.id = v_actor
      FOR UPDATE;
      v_user_exists := FOUND;
    END IF;
  END IF;

  IF v_user_exists THEN
    -- Paso 0 es la preseleccion del registro por email y puede corregirse.
    -- Una seleccion ya consolidada solo admite repeticion idempotente.
    IF NULLIF(btrim(COALESCE(v_existing_role, '')), '') IS NOT NULL
      AND v_existing_step >= 1
      AND lower(btrim(v_existing_role)) <> v_role
    THEN
      RAISE EXCEPTION 'set_my_initial_role: rol ya seleccionado'
        USING ERRCODE = '42501';
    END IF;

    UPDATE public.users u
    SET
      account_type = v_role_row.account_type,
      onboarding_step = CASE
        WHEN p_complete_selection THEN GREATEST(v_existing_step, 1)
        ELSE v_existing_step
      END,
      email = v_email,
      name = COALESCE(NULLIF(btrim(u.name::TEXT), ''), v_name)
    WHERE u.id = v_actor;
  END IF;

  RETURN QUERY
  SELECT u.account_type::TEXT, COALESCE(u.onboarding_step, 0)
  FROM public.users u
  WHERE u.id = v_actor;
END;
$$;


CREATE OR REPLACE FUNCTION public.update_my_candidate_profile(
  p_name TEXT,
  p_headline TEXT,
  p_city TEXT,
  p_about TEXT,
  p_tags TEXT[],
  p_skills JSONB,
  p_experience JSONB,
  p_education JSONB,
  p_salary_expectation TEXT,
  p_latitude DOUBLE PRECISION,
  p_longitude DOUBLE PRECISION,
  p_complete_onboarding BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_role TEXT;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'update_my_candidate_profile: sesion no disponible'
      USING ERRCODE = '28000';
  END IF;
  IF p_complete_onboarding IS NULL THEN
    RAISE EXCEPTION 'update_my_candidate_profile: progreso invalido'
      USING ERRCODE = '22023';
  END IF;

  SELECT lower(btrim(COALESCE(u.account_type::TEXT, '')))
  INTO v_role
  FROM public.users u
  WHERE u.id = v_actor
  FOR UPDATE;

  IF NOT FOUND OR NOT (
    v_role = 'candidato'
    OR v_role = 'stealth'
    OR v_role LIKE 'confidenc%'
    OR v_role LIKE 'confidential%'
  ) THEN
    RAISE EXCEPTION 'update_my_candidate_profile: rol no permitido'
      USING ERRCODE = '42501';
  END IF;
  IF btrim(COALESCE(p_name, '')) = ''
    OR btrim(COALESCE(p_headline, '')) = ''
    OR btrim(COALESCE(p_city, '')) = ''
  THEN
    RAISE EXCEPTION 'update_my_candidate_profile: campos requeridos incompletos'
      USING ERRCODE = '22023';
  END IF;
  IF jsonb_typeof(COALESCE(p_skills, '[]'::JSONB)) <> 'array'
    OR jsonb_typeof(COALESCE(p_experience, '[]'::JSONB)) <> 'array'
    OR jsonb_typeof(COALESCE(p_education, '[]'::JSONB)) <> 'array'
  THEN
    RAISE EXCEPTION 'update_my_candidate_profile: listas invalidas'
      USING ERRCODE = '22023';
  END IF;
  IF (p_latitude IS NULL) <> (p_longitude IS NULL)
    OR (p_latitude IS NOT NULL AND (p_latitude < -90 OR p_latitude > 90))
    OR (p_longitude IS NOT NULL AND (p_longitude < -180 OR p_longitude > 180))
  THEN
    RAISE EXCEPTION 'update_my_candidate_profile: coordenadas invalidas'
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.users u
  SET
    name = btrim(p_name),
    headline = btrim(p_headline),
    city = btrim(p_city),
    about = p_about,
    tags = p_tags,
    skills = p_skills,
    experience = p_experience,
    education = p_education,
    salary_expectation = p_salary_expectation,
    latitude = CASE WHEN p_latitude IS NULL THEN u.latitude ELSE p_latitude END,
    longitude = CASE WHEN p_longitude IS NULL THEN u.longitude ELSE p_longitude END,
    onboarding_step = CASE
      WHEN p_complete_onboarding THEN GREATEST(COALESCE(u.onboarding_step, 0), 2)
      ELSE u.onboarding_step
    END
  WHERE u.id = v_actor;
END;
$$;


CREATE OR REPLACE FUNCTION public.update_my_company_profile(
  p_company TEXT,
  p_headline TEXT,
  p_about TEXT,
  p_tags TEXT[]
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_role TEXT;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'update_my_company_profile: sesion no disponible'
      USING ERRCODE = '28000';
  END IF;

  SELECT lower(btrim(COALESCE(u.account_type::TEXT, '')))
  INTO v_role
  FROM public.users u
  WHERE u.id = v_actor
  FOR UPDATE;

  IF NOT FOUND OR v_role <> 'empresa' THEN
    RAISE EXCEPTION 'update_my_company_profile: rol no permitido'
      USING ERRCODE = '42501';
  END IF;
  IF btrim(COALESCE(p_company, '')) = '' THEN
    RAISE EXCEPTION 'update_my_company_profile: empresa requerida'
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.users u
  SET
    company = btrim(p_company),
    name = btrim(p_company),
    headline = p_headline,
    about = p_about,
    tags = p_tags,
    is_hiring = TRUE,
    onboarding_step = GREATEST(COALESCE(u.onboarding_step, 0), 2)
  WHERE u.id = v_actor;
END;
$$;


CREATE OR REPLACE FUNCTION public.update_my_headhunter_profile(
  p_name TEXT,
  p_headline TEXT,
  p_city TEXT,
  p_tags TEXT[]
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_role TEXT;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'update_my_headhunter_profile: sesion no disponible'
      USING ERRCODE = '28000';
  END IF;

  SELECT lower(btrim(COALESCE(u.account_type::TEXT, '')))
  INTO v_role
  FROM public.users u
  WHERE u.id = v_actor
  FOR UPDATE;

  IF NOT FOUND OR v_role <> 'headhunter' THEN
    RAISE EXCEPTION 'update_my_headhunter_profile: rol no permitido'
      USING ERRCODE = '42501';
  END IF;
  IF btrim(COALESCE(p_name, '')) = ''
    OR btrim(COALESCE(p_headline, '')) = ''
  THEN
    RAISE EXCEPTION 'update_my_headhunter_profile: campos requeridos incompletos'
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.users u
  SET
    name = btrim(p_name),
    headline = btrim(p_headline),
    city = CASE WHEN btrim(COALESCE(p_city, '')) = '' THEN u.city ELSE btrim(p_city) END,
    tags = p_tags,
    is_hiring = TRUE,
    onboarding_step = GREATEST(COALESCE(u.onboarding_step, 0), 2)
  WHERE u.id = v_actor;
END;
$$;


-- Transicion de privacidad separada: nunca puede cruzar hacia Empresa o
-- Headhunter y normaliza variantes historicas al vocabulario productivo.
CREATE OR REPLACE FUNCTION public.set_my_candidate_privacy(
  p_confidential BOOLEAN
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_role TEXT;
  v_target TEXT := CASE WHEN p_confidential THEN 'confidencial' ELSE 'candidato' END;
  v_role_row public.users%ROWTYPE;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'set_my_candidate_privacy: sesion no disponible'
      USING ERRCODE = '28000';
  END IF;
  IF p_confidential IS NULL THEN
    RAISE EXCEPTION 'set_my_candidate_privacy: valor invalido'
      USING ERRCODE = '22023';
  END IF;

  SELECT lower(btrim(COALESCE(u.account_type::TEXT, '')))
  INTO v_role
  FROM public.users u
  WHERE u.id = v_actor
  FOR UPDATE;

  IF NOT FOUND OR NOT (
    v_role = 'candidato'
    OR v_role = 'stealth'
    OR v_role LIKE 'confidenc%'
    OR v_role LIKE 'confidential%'
  ) THEN
    RAISE EXCEPTION 'set_my_candidate_privacy: rol no permitido'
      USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_role_row
  FROM jsonb_populate_record(
    NULL::public.users,
    jsonb_build_object('account_type', v_target)
  );

  UPDATE public.users u
  SET account_type = v_role_row.account_type
  WHERE u.id = v_actor;

  RETURN v_target;
END;
$$;


CREATE OR REPLACE FUNCTION public.set_my_profile_avatar(p_avatar_url TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_role TEXT;
  v_expected_path TEXT;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'set_my_profile_avatar: sesion no disponible'
      USING ERRCODE = '28000';
  END IF;

  SELECT lower(btrim(COALESCE(u.account_type::TEXT, '')))
  INTO v_role
  FROM public.users u
  WHERE u.id = v_actor
  FOR UPDATE;

  IF NOT FOUND OR NOT (
    v_role = 'candidato'
    OR v_role = 'stealth'
    OR v_role LIKE 'confidenc%'
    OR v_role LIKE 'confidential%'
  ) THEN
    RAISE EXCEPTION 'set_my_profile_avatar: rol no permitido'
      USING ERRCODE = '42501';
  END IF;

  v_expected_path := '/storage/v1/object/public/videos/avatars/'
    || v_actor::TEXT || '.jpg';
  IF p_avatar_url IS NOT NULL
    AND position(v_expected_path IN p_avatar_url) = 0
  THEN
    RAISE EXCEPTION 'set_my_profile_avatar: origen de storage no permitido'
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.users u
  SET avatar_url = p_avatar_url
  WHERE u.id = v_actor;
END;
$$;


REVOKE ALL ON FUNCTION public.set_my_initial_role(TEXT, BOOLEAN)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.update_my_candidate_profile(
  TEXT, TEXT, TEXT, TEXT, TEXT[], JSONB, JSONB, JSONB, TEXT,
  DOUBLE PRECISION, DOUBLE PRECISION, BOOLEAN
) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.update_my_company_profile(TEXT, TEXT, TEXT, TEXT[])
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.update_my_headhunter_profile(TEXT, TEXT, TEXT, TEXT[])
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.set_my_candidate_privacy(BOOLEAN)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.set_my_profile_avatar(TEXT)
  FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.set_my_initial_role(TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_my_candidate_profile(
  TEXT, TEXT, TEXT, TEXT, TEXT[], JSONB, JSONB, JSONB, TEXT,
  DOUBLE PRECISION, DOUBLE PRECISION, BOOLEAN
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_my_company_profile(TEXT, TEXT, TEXT, TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_my_headhunter_profile(TEXT, TEXT, TEXT, TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_my_candidate_privacy(BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_my_profile_avatar(TEXT) TO authenticated;

COMMENT ON FUNCTION public.set_my_initial_role(TEXT, BOOLEAN) IS
  'Crea o completa el perfil de auth.uid() con una familia inicial; no permite cambiar una seleccion consolidada.';
COMMENT ON FUNCTION public.update_my_candidate_profile(
  TEXT, TEXT, TEXT, TEXT, TEXT[], JSONB, JSONB, JSONB, TEXT,
  DOUBLE PRECISION, DOUBLE PRECISION, BOOLEAN
) IS 'Actualiza exclusivamente campos editables del perfil propio de Candidato.';
COMMENT ON FUNCTION public.update_my_company_profile(TEXT, TEXT, TEXT, TEXT[]) IS
  'Actualiza exclusivamente campos editables del perfil propio de Empresa.';
COMMENT ON FUNCTION public.update_my_headhunter_profile(TEXT, TEXT, TEXT, TEXT[]) IS
  'Actualiza exclusivamente campos editables del perfil propio de Headhunter.';
COMMENT ON FUNCTION public.set_my_candidate_privacy(BOOLEAN) IS
  'Alterna de forma explicita candidato/confidencial sin permitir cambios de familia.';
COMMENT ON FUNCTION public.set_my_profile_avatar(TEXT) IS
  'Asocia al Candidato autenticado su avatar de la ruta propia del bucket videos.';

COMMIT;

NOTIFY pgrst, 'reload schema';
