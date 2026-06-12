-- ═══════════════════════════════════════════════════════════════════════════════
-- CRON JOB: Loop de retención semanal
--
-- Ejecuta la Edge Function weekly-engagement cada lunes a las 10:00 AM (UTC-3)
-- que corresponde a las 13:00 UTC.
--
-- Prerequisitos:
--   1. La extensión pg_cron debe estar habilitada en Supabase
--      (Dashboard → Database → Extensions → pg_cron → Enable)
--   2. La extensión pg_net debe estar habilitada
--      (Dashboard → Database → Extensions → pg_net → Enable)
--   3. La Edge Function weekly-engagement debe estar deployada
-- ═══════════════════════════════════════════════════════════════════════════════

-- Habilitar extensiones si no están activas
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Programar: cada lunes a las 13:00 UTC (10:00 AM Argentina)
SELECT cron.schedule(
  'weekly-engagement-loop',
  '0 13 * * 1',  -- minuto hora día mes día_semana (1=lunes)
  $$
  SELECT net.http_post(
    'https://qclipzefqndcefwwixdy.supabase.co/functions/v1/weekly-engagement',
    '{}',
    'application/json',
    ARRAY[
      net.http_header('Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.placeholder')
    ]
  );
  $$
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- NOTA: Reemplazá 'eyJhb...' con tu SUPABASE_SERVICE_ROLE_KEY real.
-- La encontrás en: Dashboard → Settings → API → service_role (secret)
--
-- Para verificar que el cron está activo:
--   SELECT * FROM cron.job;
--
-- Para eliminar el cron:
--   SELECT cron.unschedule('weekly-engagement-loop');
-- ═══════════════════════════════════════════════════════════════════════════════
