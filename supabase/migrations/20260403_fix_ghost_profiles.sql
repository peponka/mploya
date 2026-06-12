-- ============================================================
-- MPLOYA — Fix perfiles fantasmas + get_nearby_users RPC
-- Fecha: 2026-04-03
-- Ejecutar en: Supabase Dashboard → SQL Editor → Run
--
-- Orden:
--   1) Repara/crea trigger handle_new_user en auth.users
--   2) Despliega RPC get_nearby_users (Haversine, sin PostGIS)
--   3) Inyecta seeds: CDMX (candidato) + Londres (confidencial)
--   4) Validación: llama get_nearby_users con radio 40000 km
-- ============================================================


-- ============================================================
-- PASO 1: TRIGGER handle_new_user
-- Crea el perfil en public.users cada vez que se registra
-- un nuevo usuario en auth.users.
-- SECURITY DEFINER + ON CONFLICT DO NOTHING = idempotente y
-- no rompe aunque la tabla ya tenga el registro.
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, email, name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(
      NEW.raw_user_meta_data->>'name',
      split_part(NEW.email, '@', 1)
    )
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Recrea el trigger (DROP + CREATE es idempotente con IF EXISTS)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE PROCEDURE public.handle_new_user();

-- Política RLS mínima para que cada usuario pueda leer/editar su propio perfil
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename  = 'users'
      AND policyname = 'users_own_upsert'
  ) THEN
    EXECUTE 'CREATE POLICY "users_own_upsert"
      ON public.users
      FOR ALL
      USING     (auth.uid() = id)
      WITH CHECK (auth.uid() = id)';
  END IF;
END$$;


-- ============================================================
-- PASO 2: RPC get_nearby_users
-- Usa fórmula de Haversine pura (sin extensión PostGIS).
-- LEY DE CRUCE: candidatos ven empresas y viceversa.
--   - caller_type = 'empresa'   → devuelve candidatos + confidenciales
--   - caller_type != 'empresa'  → devuelve solo empresas
-- Parámetro radius_km: en km (ej. 40000 = radio global).
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_nearby_users(
  user_lat    double precision,
  user_lng    double precision,
  radius_km   double precision DEFAULT 50,
  max_results integer          DEFAULT 60,
  caller_type text             DEFAULT 'candidato'
)
RETURNS TABLE (
  id           uuid,
  name         text,
  headline     text,
  video_url    text,
  account_type text,
  latitude     double precision,
  longitude    double precision,
  distance_km  double precision
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT *
  FROM (
    SELECT
      u.id::uuid,
      u.name::text,
      u.headline::text,
      u.video_url::text,
      u.account_type::text,
      u.latitude::double precision,
      u.longitude::double precision,
      ( 6371.0 * acos( LEAST(1.0,
          cos(radians(user_lat)) * cos(radians(u.latitude))
          * cos(radians(u.longitude) - radians(user_lng))
          + sin(radians(user_lat)) * sin(radians(u.latitude))
      ))) AS distance_km
    FROM public.users u
    WHERE u.latitude  IS NOT NULL
      AND u.longitude IS NOT NULL
      AND (
        -- Ley de cruce: empresa ve candidatos/confidenciales; candidato ve empresas
        (caller_type = 'empresa'   AND u.account_type IN ('candidato', 'confidencial'))
        OR
        (caller_type != 'empresa'  AND u.account_type = 'empresa')
      )
  ) sub
  WHERE sub.distance_km <= radius_km
  ORDER BY sub.distance_km ASC
  LIMIT max_results;
$$;

-- Permiso de ejecución para usuarios autenticados y anon (para tests)
GRANT EXECUTE ON FUNCTION public.get_nearby_users(
  double precision, double precision, double precision, integer, text
) TO authenticated, anon;


-- ============================================================
-- PASO 3: SEEDS — Perfiles fantasma para poblar el radar
--
-- Como public.users.id referencia auth.users(id),
-- primero insertamos entradas mínimas en auth.users
-- (esto solo funciona desde el SQL Editor con rol postgres/service_role)
-- luego hacemos UPSERT en public.users.
-- ============================================================

-- ── 3a. Entradas en auth.users (mínimas, confirmadas) ──────
INSERT INTO auth.users (
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  raw_app_meta_data,
  raw_user_meta_data,
  is_super_admin
)
VALUES
  (
    '00000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'seed_cdmx_candidato@mploya.fake',
    '',                          -- sin contraseña real; cuenta seed de prueba
    NOW(),
    NOW(),
    NOW(),
    '{"provider":"email","providers":["email"]}',
    '{"name":"Alejandro Vega"}',
    false
  ),
  (
    '00000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'seed_london_confidencial@mploya.fake',
    '',
    NOW(),
    NOW(),
    NOW(),
    '{"provider":"email","providers":["email"]}',
    '{"name":"Sophie Whitmore"}',
    false
  )
ON CONFLICT (id) DO NOTHING;

-- ── 3b. Perfiles en public.users ────────────────────────────
INSERT INTO public.users (
  id,
  email,
  name,
  headline,
  account_type,
  latitude,
  longitude,
  match_percentage,
  rating_stars,
  rating_count,
  like_count,
  connections,
  profile_views,
  is_hiring
)
VALUES
  -- CDMX · candidato  (Lat 19.43, Lng -99.13)
  (
    '00000000-0000-0000-0000-000000000001',
    'seed_cdmx_candidato@mploya.fake',
    'Alejandro Vega',
    'Desarrollador Flutter · 5 años de experiencia',
    'candidato',
    19.4326,
    -99.1332,
    82.0,
    4.5,
    12,
    34,
    8,
    210,
    false
  ),
  -- Londres · confidencial  (Lat 51.50, Lng -0.12)
  (
    '00000000-0000-0000-0000-000000000002',
    'seed_london_confidencial@mploya.fake',
    'Sophie Whitmore',
    'Senior Product Designer · Startup fintech',
    'confidencial',
    51.5074,
    -0.1278,
    91.0,
    4.8,
    27,
    61,
    15,
    430,
    false
  )
ON CONFLICT (id) DO UPDATE
  SET
    latitude         = EXCLUDED.latitude,
    longitude        = EXCLUDED.longitude,
    account_type     = EXCLUDED.account_type,
    headline         = EXCLUDED.headline,
    match_percentage = EXCLUDED.match_percentage;


-- ============================================================
-- PASO 4: VALIDACIÓN
-- Llama la RPC con radio 40 000 km (global) y caller_type empresa.
-- Debe retornar los 2 seeds recién insertados.
-- ============================================================

SELECT
  id,
  name,
  account_type,
  ROUND(distance_km::numeric, 2) AS distance_km,
  latitude,
  longitude
FROM public.get_nearby_users(
  user_lat    => 19.4326,   -- posición del caller (CDMX para probar)
  user_lng    => -99.1332,
  radius_km   => 40000,
  max_results => 60,
  caller_type => 'empresa'  -- empresa ve candidato + confidencial
);

-- Resultado esperado:
--   Alejandro Vega   | candidato    |   ~0 km   (mismo punto)
--   Sophie Whitmore  | confidencial | ~9 113 km (CDMX → Londres)
