-- ============================================================================
-- 031 — Tapar la fuga de privacidad de `get_explore_pins` (Mapa de Empresa)
-- ============================================================================
-- BORRADOR SIN APLICAR — auditado por segunda vez el 15/8/2026, a pedido de
-- Pepe, ANTES de aplicarlo. Sigue sin correr contra la base: ni `db push`, ni
-- `db query`, ni el SQL Editor. Vive sólo en este archivo hasta que él lo
-- autorice.
--
-- ============================================================================
-- HALLAZGO
-- ============================================================================
-- `get_explore_pins` (023_explore_pins_reales.sql) selecciona `u.name`,
-- `u.avatar_url`, `u.latitude` y `u.longitude` de CUALQUIER usuario con
-- ubicación, sin excluir a quienes tienen `account_type` confidencial/stealth.
-- A diferencia de Pipeline, Shortlist, Mensajes, Match IA y el Perfil de
-- Candidato — que sí ocultan identidad —, acá la fila sale cruda: nombre real,
-- foto real y COORDENADAS GPS EXACTAS.
--
-- Mitigado del lado del cliente en la misma tanda (empresa_mapa_screen.dart,
-- función `candidatosDesdeFilas`): esos pines se descartan antes de dibujarse.
-- Pero la función SQL sigue devolviendo el dato crudo a quien la llame
-- directo. Este archivo es el fix de raíz.
--
-- ============================================================================
-- AUDITORÍA FINAL (segunda pasada, antes de aplicar)
-- ============================================================================
--
-- 1. FIRMA — IDÉNTICA a 023: mismos 3 parámetros (p_lat, p_lng, p_radius_km
--    DOUBLE PRECISION, el tercero DEFAULT 50), mismas 9 columnas de retorno
--    en el mismo orden y con los mismos tipos. No cambia.
--
-- 2. FILTROS EXISTENTES PARA CANDIDATOS NORMALES — preservados sin tocar:
--      u.id IS DISTINCT FROM auth.uid()
--      u.latitude IS NOT NULL
--      u.longitude IS NOT NULL
--      u.deleted_at IS NULL
--      u.name IS NOT NULL
--    Un candidato normal (account_type = 'candidato' o NULL) atraviesa estas
--    cinco condiciones exactamente igual que hoy.
--
-- 3. QUÉ SE EXCLUYE — SÓLO dos condiciones nuevas, agregadas con AND (nunca
--    reemplazan nada):
--      lower(COALESCE(u.account_type, '')) NOT LIKE 'confidenc%'
--      lower(COALESCE(u.account_type, '')) <> 'stealth'
--    Empresa/headhunter NO se tocan acá: nunca estuvieron excluidos por SQL,
--    sólo por el cliente Flutter (`tipo == 'empresa' || tipo == 'headhunter'`
--    en `candidatosDesdeFilas`). Esta migración no cambia ese reparto de
--    responsabilidad — sigue siendo el cliente quien los filtra. Ver el punto
--    10 (validación) para la consecuencia exacta de esto.
--
-- 4. LLAMADAS ANÓNIMAS PRODUCTIVAS — build buscado en todo el repo
--    (`grep -rn get_explore_pins`): dos consumidores, los dos Flutter, los dos
--    detrás de pantallas que requieren sesión iniciada (la app entera pasa por
--    `splash_screen.dart` antes de llegar a cualquier pantalla con mapa):
--      · lib/screens/explore_screen.dart:168      (Candidato · Explorar)
--      · lib/screens/empresa/empresa_mapa_screen.dart:97  (Empresa · Mapa)
--    Cero Edge Functions, cero SQL/triggers, cero JS/TS/HTML sueltos la
--    invocan. NINGÚN camino de la app llama a esta RPC sin sesión. El riesgo
--    de `anon` es exclusivamente API directa (curl/Postman con la anon key
--    pública), no un flujo interno de la app.
--
-- 5. `authenticated` CONSERVA EXECUTE — sí, se regrant explícitamente después
--    del DROP+CREATE (ver punto 7: el DROP borra los grants previos).
--
-- 6. PUBLIC / anon / service_role — CORRECCIÓN respecto del primer borrador.
--    Postgres otorga EXECUTE a PUBLIC automáticamente en todo CREATE FUNCTION
--    nuevo, salvo que se revoque a mano. `023` nunca lo revocó, así que HOY
--    —antes de este fix— PUBLIC probablemente ya tiene EXECUTE sobre esta
--    función, lo cual habilita a `anon` incluso si sólo se le revocara a él
--    directamente: `anon` hereda por ser miembro implícito de PUBLIC. Mi
--    primer borrador sólo revocaba de `anon` y por lo tanto NO cerraba nada.
--    Corregido: ahora revoca explícitamente de PUBLIC, anon Y service_role —
--    mismo patrón que ya usa este repo en la migración 030 (revocar de los
--    cuatro roles y otorgar sólo lo necesario). service_role nunca la llama
--    (punto 4) y no la necesita: Supabase ya la usa con su propia vía de
--    administración, no a través de esta RPC.
--
-- 7. `SECURITY DEFINER` / `search_path` / ownership / escalamiento —
--      · `SECURITY DEFINER` ya estaba en 023: la función corre con los
--        privilegios de su dueño (no del llamador), que es lo que le permite
--        leer filas de `users` de otros usuarios pese a RLS. Es preexistente,
--        no lo introduce este fix, y sigue siendo necesario para que la
--        función funcione en absoluto.
--      · `SET search_path = public` ya estaba en 023 y se preserva
--        literal: evita el secuestro de search_path (alguien creando objetos
--        homónimos en un esquema que controle). No se agrega `pg_temp` al
--        final como sí hace 030 en una función más nueva — para no tocar más
--        de lo que este fix pide, se deja igual que 023.
--      · Ownership: no se toca (`ALTER FUNCTION … OWNER TO` no aparece). El
--        `DROP + CREATE OR REPLACE` en la misma transacción/migración deja la
--        función con el mismo owner que tenga quien ejecute este script
--        (normalmente el rol de la migración, igual que en 023).
--      · Escalamiento: el `DROP FUNCTION` seguido de `CREATE` no es un
--        rediseño de superficie — es el mismo patrón exacto que ya usó 023.
--        El único cambio de superficie de ESTA migración es que reduce
--        exposición (menos filas, menos roles), nunca la amplía.
--
-- 8. COMPARACIÓN LÍNEA POR LÍNEA contra 023 — todo idéntico excepto lo
--    señalado:
--      · Parámetros: IDÉNTICOS.
--      · RETURNS TABLE: IDÉNTICO (9 columnas, mismo orden, mismos tipos).
--      · SECURITY DEFINER: IDÉNTICO.
--      · SET search_path = public: IDÉNTICO.
--      · LANGUAGE sql STABLE: IDÉNTICO.
--      · Las 9 expresiones del SELECT interno (pin_id … distance_km),
--        incluida la fórmula haversine completa: IDÉNTICAS carácter por
--        carácter.
--      · WHERE interno: las 5 condiciones de 023 se preservan en el mismo
--        orden: SE AGREGAN 2 condiciones nuevas al final (punto 3). No se
--        quitó ninguna.
--      · WHERE externo (distance_km <= p_radius_km): IDÉNTICO.
--      · ORDER BY distance_km ASC: IDÉNTICO.
--      · LIMIT 200: IDÉNTICO.
--      · GRANT: CAMBIA — de `TO authenticated, anon` (una sola línea) a
--        revocar de PUBLIC/anon/service_role y otorgar sólo a authenticated
--        (punto 6).
--
-- ============================================================================
-- RIESGOS RESIDUALES (no resueltos por esta migración, quedan para después)
-- ============================================================================
--   · Empresa/headhunter siguen sin excluirse por SQL — sólo por el cliente
--     Flutter. Una llamada directa a la RPC (con sesión `authenticated`)
--     seguiría devolviendo esos pines. Fuera del alcance que pediste para esta
--     migración («sólo excluya» los tres ítems del punto 3).
--   · No se revisó si OTRAS funciones/vistas del proyecto tienen el mismo
--     patrón (PUBLIC-por-defecto sin revocar). Esta migración es puntual a
--     `get_explore_pins`.
--   · `authenticated` sigue pudiendo ver la ubicación exacta de CUALQUIER
--     candidato no confidencial dentro del radio — eso es el propósito
--     declarado de la función (mapa de talento), no un defecto nuevo.
-- ============================================================================


-- ── Migración ─────────────────────────────────────────────────────────────

DROP FUNCTION IF EXISTS public.get_explore_pins(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION);

CREATE OR REPLACE FUNCTION public.get_explore_pins(
  p_lat       DOUBLE PRECISION,
  p_lng       DOUBLE PRECISION,
  p_radius_km DOUBLE PRECISION DEFAULT 50
)
RETURNS TABLE (
  pin_id       UUID,
  pin_name     TEXT,
  pin_headline TEXT,
  pin_type     TEXT,
  avatar_url   TEXT,
  has_video    BOOLEAN,
  latitude     DOUBLE PRECISION,
  longitude    DOUBLE PRECISION,
  distance_km  DOUBLE PRECISION
)
SECURITY DEFINER
SET search_path = public
LANGUAGE sql STABLE AS $$
  SELECT * FROM (
    SELECT
      u.id                                   AS pin_id,
      u.name::TEXT                           AS pin_name,
      COALESCE(u.headline, '')::TEXT         AS pin_headline,
      COALESCE(u.account_type, 'candidato')::TEXT AS pin_type,
      u.avatar_url::TEXT                     AS avatar_url,
      (u.video_url IS NOT NULL AND u.video_url <> '') AS has_video,
      u.latitude,
      u.longitude,
      (6371 * acos(LEAST(1.0,
        cos(radians(p_lat)) * cos(radians(u.latitude))
        * cos(radians(u.longitude) - radians(p_lng))
        + sin(radians(p_lat)) * sin(radians(u.latitude))
      ))) AS distance_km
    FROM public.users u
    WHERE u.id IS DISTINCT FROM auth.uid()
      AND u.latitude IS NOT NULL
      AND u.longitude IS NOT NULL
      AND u.deleted_at IS NULL
      AND u.name IS NOT NULL
      -- Fix 031: nunca exponer la ubicación de un perfil confidencial/stealth.
      AND lower(COALESCE(u.account_type, '')) NOT LIKE 'confidenc%'
      AND lower(COALESCE(u.account_type, '')) <> 'stealth'
  ) sub
  WHERE distance_km <= p_radius_km
  ORDER BY distance_km ASC
  LIMIT 200;
$$;

COMMENT ON FUNCTION public.get_explore_pins(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) IS
  'Pines de talento para el mapa (Candidato y Empresa). Excluye confidenciales/stealth desde la migración 031 — antes exponía su nombre, foto y coordenadas exactas sin ningún filtro. Sólo authenticated.';

-- ── Permisos ────────────────────────────────────────────────────────────────
-- El DROP+CREATE anterior deja la función con los privilegios por defecto de
-- Postgres, que incluyen EXECUTE para PUBLIC salvo que se revoque a mano —
-- 023 nunca lo hizo. Se revoca de los tres roles relevantes y se otorga sólo
-- a `authenticated`, mismo patrón que la migración 030 de este repo.
REVOKE EXECUTE ON FUNCTION public.get_explore_pins(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_explore_pins(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) FROM anon;
REVOKE EXECUTE ON FUNCTION public.get_explore_pins(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) FROM service_role;
GRANT EXECUTE ON FUNCTION public.get_explore_pins(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;

NOTIFY pgrst, 'reload schema';


-- ============================================================================
-- ROLLBACK — SQL EXACTO, NO EJECUTADO, para volver a la versión de 023
-- ============================================================================
-- Restaura la función y los permisos EXACTAMENTE como estaban antes de esta
-- migración (incluido volver a otorgar a `anon` — sólo usar si hace falta
-- revertir de verdad, no como limpieza de rutina).
--
-- DROP FUNCTION IF EXISTS public.get_explore_pins(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION);
--
-- CREATE OR REPLACE FUNCTION public.get_explore_pins(
--   p_lat       DOUBLE PRECISION,
--   p_lng       DOUBLE PRECISION,
--   p_radius_km DOUBLE PRECISION DEFAULT 50
-- )
-- RETURNS TABLE (
--   pin_id       UUID,
--   pin_name     TEXT,
--   pin_headline TEXT,
--   pin_type     TEXT,
--   avatar_url   TEXT,
--   has_video    BOOLEAN,
--   latitude     DOUBLE PRECISION,
--   longitude    DOUBLE PRECISION,
--   distance_km  DOUBLE PRECISION
-- )
-- SECURITY DEFINER
-- SET search_path = public
-- LANGUAGE sql STABLE AS $$
--   SELECT * FROM (
--     SELECT
--       u.id                                   AS pin_id,
--       u.name::TEXT                           AS pin_name,
--       COALESCE(u.headline, '')::TEXT         AS pin_headline,
--       COALESCE(u.account_type, 'candidato')::TEXT AS pin_type,
--       u.avatar_url::TEXT                     AS avatar_url,
--       (u.video_url IS NOT NULL AND u.video_url <> '') AS has_video,
--       u.latitude,
--       u.longitude,
--       (6371 * acos(LEAST(1.0,
--         cos(radians(p_lat)) * cos(radians(u.latitude))
--         * cos(radians(u.longitude) - radians(p_lng))
--         + sin(radians(p_lat)) * sin(radians(u.latitude))
--       ))) AS distance_km
--     FROM public.users u
--     WHERE u.id IS DISTINCT FROM auth.uid()
--       AND u.latitude IS NOT NULL
--       AND u.longitude IS NOT NULL
--       AND u.deleted_at IS NULL
--       AND u.name IS NOT NULL
--   ) sub
--   WHERE distance_km <= p_radius_km
--   ORDER BY distance_km ASC
--   LIMIT 200;
-- $$;
--
-- GRANT EXECUTE ON FUNCTION public.get_explore_pins(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION)
--   TO authenticated, anon;
--
-- NOTIFY pgrst, 'reload schema';
-- ============================================================================


-- ============================================================================
-- VALIDACIÓN POST-APLICACIÓN — NO EJECUTADA, propuesta para correr a mano
-- ============================================================================
-- Ejecutar en Supabase Dashboard → SQL Editor, DESPUÉS de aplicar. Ninguna
-- escribe datos.
--
-- Antes de correr V1–V4, elegir un centro y radio que cubran usuarios reales
-- con `latitude`/`longitude` cargados (ajustar según los datos reales):
--   SELECT id, name, account_type, latitude, longitude
--   FROM public.users
--   WHERE latitude IS NOT NULL AND longitude IS NOT NULL AND deleted_at IS NULL
--   ORDER BY account_type;
--
-- V1 · Un candidato normal SÍ aparece
--   SELECT pin_id, pin_name, pin_type
--   FROM public.get_explore_pins(<lat>, <lng>, 150)
--   WHERE pin_type = 'candidato' OR pin_type IS NULL;
--   → esperado: al menos las filas de candidatos reales con ubicación.
--
-- V2 · Confidencial NO aparece
--   SELECT count(*) FROM public.get_explore_pins(<lat>, <lng>, 500)
--   WHERE pin_id IN (
--     SELECT id FROM public.users WHERE account_type ILIKE 'confidenc%'
--   );
--   → esperado: 0.
--
-- V3 · Stealth NO aparece
--   SELECT count(*) FROM public.get_explore_pins(<lat>, <lng>, 500)
--   WHERE pin_id IN (
--     SELECT id FROM public.users WHERE account_type = 'stealth'
--   );
--   → esperado: 0.
--
-- V4 · Empresa/headhunter — ADVERTENCIA: esta migración NO los excluye por
--   SQL (punto 3 y "riesgos residuales" arriba). La siguiente consulta
--   confirmará que SIGUEN apareciendo — eso es el comportamiento actual
--   esperado, no una falla de esta migración. Sólo el cliente Flutter los
--   filtra hoy.
--   SELECT count(*) FROM public.get_explore_pins(<lat>, <lng>, 500)
--   WHERE pin_type IN ('empresa', 'headhunter');
--   → esperado con datos reales de ambos tipos: > 0 (no filtrados por SQL).
--
-- V5 · anon NO puede ejecutar
--   SET LOCAL ROLE anon;
--   SELECT * FROM public.get_explore_pins(<lat>, <lng>, 10);
--   RESET ROLE;
--   → esperado: ERROR 42501 permission denied for function get_explore_pins.
--
-- V6 · authenticated SÍ puede ejecutar
--   SET LOCAL ROLE authenticated;
--   SELECT set_config('request.jwt.claims',
--          json_build_object('sub','<UUID_DE_UN_USUARIO_REAL>')::text, true);
--   SELECT count(*) FROM public.get_explore_pins(<lat>, <lng>, 150);
--   RESET ROLE;
--   → esperado: corre sin error (0 o más filas, según haya candidatos en el
--     radio).
-- ============================================================================
