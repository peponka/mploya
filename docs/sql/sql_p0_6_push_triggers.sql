-- ==============================================================================
-- MPLOYA: CONFIGURACIÓN DE NOTIFICACIONES PUSH (MATCHES)
-- ==============================================================================

-- 1. Crear la función disparadora que llamará al webhook de Supabase (send-fcm)
CREATE OR REPLACE FUNCTION notify_match_push()
RETURNS trigger AS $$
BEGIN
  -- Solo disparamos cuando el status cambia EXACTAMENTE a 'accepted'
  IF NEW.status = 'accepted' AND OLD.status IS DISTINCT FROM 'accepted' THEN
    
    -- Hacer un llamando asíncrono (pg_net) usando el formato de webhooks
    -- Usamos la URL de tu Edge Function de Supabase.
    -- OJO: Asegúrate de habilitar `pg_net` o usar net.http_post
    PERFORM net.http_post(
        url := current_setting('app.settings.edge_function_url', true) || '/send-fcm',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
        ),
        body := jsonb_build_object(
            'type', 'UPDATE',
            'table', 'connections',
            'record', row_to_json(NEW),
            'old_record', row_to_json(OLD)
        )
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Asegurarse de que el trigger no exista antes de crearlo
DROP TRIGGER IF EXISTS on_match_accepted_push ON connections;

-- 3. Crear el Trigger sobre la tabla connections
CREATE TRIGGER on_match_accepted_push
AFTER UPDATE ON connections
FOR EACH ROW
EXECUTE FUNCTION notify_match_push();

-- ==============================================================================
-- NOTA: Si prefieres la vía sin código SQL, puedes hacer exactamente lo mismo
-- yendo a: Supabase Dashboard > Database > Webhooks > Crear Webhook:
--   - Tabla: connections
--   - Eventos: Update
--   - Tipo de Destino: Supabase Edge Functions -> send-fcm
-- ==============================================================================
