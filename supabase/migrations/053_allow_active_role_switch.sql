-- Una misma cuenta puede alternar entre las experiencias de Mploya.
--
-- Antes `set_my_initial_role` bloqueaba cualquier cambio una vez que el
-- onboarding avanzaba. La app llegaba a mostrar el rol elegido localmente,
-- pero al refrescar desde la base volvía al rol anterior; por eso un candidato
-- terminaba viendo el feed de talento de Empresa. Esta función conserva la
-- misma validación de sesión y de roles, pero persiste explícitamente el rol
-- activo elegido por la persona.

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

  SELECT COALESCE(u.onboarding_step, 0)
  INTO v_existing_step
  FROM public.users u
  WHERE u.id = v_actor
  FOR UPDATE;
  v_user_exists := FOUND;

  SELECT * INTO v_role_row
  FROM jsonb_populate_record(
    NULL::public.users,
    jsonb_build_object('account_type', v_role)
  );

  IF NOT v_user_exists THEN
    INSERT INTO public.users (id, email, name, account_type, onboarding_step)
    VALUES (
      v_actor,
      v_email,
      v_name,
      v_role_row.account_type,
      CASE WHEN p_complete_selection THEN 1 ELSE 0 END
    )
    ON CONFLICT (id) DO NOTHING;
    v_inserted := FOUND;

    IF NOT v_inserted THEN
      SELECT COALESCE(u.onboarding_step, 0)
      INTO v_existing_step
      FROM public.users u
      WHERE u.id = v_actor
      FOR UPDATE;
      v_user_exists := FOUND;
    END IF;
  END IF;

  IF v_user_exists THEN
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

REVOKE ALL ON FUNCTION public.set_my_initial_role(TEXT, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_my_initial_role(TEXT, BOOLEAN) TO authenticated;

COMMENT ON FUNCTION public.set_my_initial_role(TEXT, BOOLEAN) IS
  'Guarda el rol activo elegido por el usuario autenticado. Permite alternar entre Candidato, Empresa, Headhunter y Confidencial.';
