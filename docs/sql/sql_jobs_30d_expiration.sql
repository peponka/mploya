-- ================================================================
-- MPLOYA BACKEND: AUTO-CADUCIDAD DE VACANTES A LOS 30 DÍAS
-- Copia este texto y córrelo en el SQL Editor de tu Supabase.
-- ================================================================

-- 1. Asegurarnos de tener la extensión "pg_cron" (por defecto la trae Supabase)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 2. Eliminar la tarea anterior si existe (por seguridad al recargar)
DO $$
BEGIN
  PERFORM cron.unschedule('mploya_auto_archive_jobs');
EXCEPTION WHEN OTHERS THEN
  -- Puede fallar si la tarea no existía, está bien.
END $$;

-- 3. Crear el Robot/Trabajador (Cron Job) programado
-- El patrón '0 0 * * *' significa: Todos los días a la medianoche (Hora Servidor).
SELECT cron.schedule(
  'mploya_auto_archive_jobs',
  '0 0 * * *', 
  $$
    UPDATE public.jobs 
    SET is_active = false 
    WHERE created_at < NOW() - INTERVAL '30 days' 
      AND is_active = true;
  $$
);

/*
CÓMO FUNCIONA ESTA TÁCTICA:
1. No se borra ningún dato de tu panel ni tus analíticas.
2. Cada noche la Base de Datos revisa qué vacantes pasaron la barrera de 30 días.
3. Lo oculta instantáneamente del Home Feed porque 'is_active' se vuelve falso.
4. Así el Feed sigue 100% fresco manteniendo solo empleos reales que reclutan ahora.
*/
