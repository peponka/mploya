-- ============================================================================
-- 047 — Faltaba la policy de SELECT en `users` (feed vacío para Empresa)
-- ============================================================================
-- Pedro (29/8/2026): el feed general de candidatos ("Para ti", sin vacante
-- elegida) le aparecía vacío pese a haber candidatos reales con video
-- cargado. Diagnóstico con el propio Pedro vía SQL Editor:
--
--   1. `feed_ranked` y `accessible_user_profiles` (las vistas que arma el
--      feed) sólo filtran por video_url y por tipo de cuenta — nada ahí
--      excluye a estos candidatos.
--   2. `pg_policies` sobre `users` NO tenía ninguna policy de SELECT (sólo
--      UPDATE/INSERT/DELETE).
--   3. `pg_class.relrowsecurity` confirma que RLS está ENABLED en `users`.
--
-- Con RLS activo y sin ninguna policy de SELECT, Postgres deniega el SELECT
-- por completo para cualquier rol que no sea el dueño de la tabla — por eso
-- las consultas de Pedro en el SQL Editor (que corren como owner, así que no
-- ven RLS) mostraban los candidatos perfectamente, mientras que la app
-- (rol `authenticated`, sí sujeta a RLS) recibía siempre 0 filas de
-- `accessible_user_profiles`/`feed_ranked`. El resto de la app no se notaba
-- porque el perfil propio, dashboard, etc. se cargan por RPCs separadas
-- (my_profile_service.dart y similares), no por SELECT directo a `users`.
--
-- Esta policy replica EXACTAMENTE la misma regla de visibilidad que ya
-- vive en `accessible_user_profiles` (ver su definición con
-- `pg_get_viewdef('accessible_user_profiles', true)`), para no cambiar el
-- criterio de negocio, sólo para que RLS deje de bloquear TODO el SELECT.
-- ============================================================================

CREATE POLICY users_select_visible
ON public.users
FOR SELECT
TO authenticated
USING (
  deleted_at IS NULL
  AND (
    id = auth.uid()
    OR (
      lower(btrim(coalesce(account_type::text, ''))) <> 'stealth'
      AND lower(btrim(coalesce(account_type::text, ''))) NOT LIKE 'confidenc%'
      AND lower(btrim(coalesce(account_type::text, ''))) NOT LIKE 'confidential%'
    )
    OR EXISTS (
      SELECT 1
      FROM profile_unlocks pu
      JOIN candidate_unlock_ledger ledger
        ON ledger.id = pu.authorization_ledger_id
       AND ledger.actor_id = pu.company_id
       AND ledger.candidate_id = pu.candidate_id
       AND ledger.authorization_version = 1
      JOIN users actor ON actor.id = pu.company_id
      WHERE pu.company_id = auth.uid()
        AND pu.candidate_id = users.id
        AND pu.authorization_version = 1
        AND actor.deleted_at IS NULL
        AND lower(btrim(coalesce(actor.account_type::text, ''))) = ANY (ARRAY['empresa', 'headhunter'])
    )
  )
);
