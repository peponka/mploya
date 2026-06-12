-- ═══════════════════════════════════════════════════════════════════════════════
-- PROTECCIÓN: Bloquear que el cliente pueda auto-setearse is_premium
--
-- Problema: El SDK de Flutter puede hacer UPDATE ... SET is_premium = true
-- directamente en la tabla users. Un atacante con un JWT válido podría
-- darse premium gratis.
--
-- Solución: is_premium SOLO se actualiza desde Edge Functions (webhook de
-- RevenueCat) que usan service_role, o desde el dashboard de Supabase.
-- ═══════════════════════════════════════════════════════════════════════════════

-- Paso 1: Crear función que valida el update
CREATE OR REPLACE FUNCTION prevent_client_premium_update()
RETURNS TRIGGER AS $$
BEGIN
  -- Si el campo is_premium está cambiando y NO es una operación con service_role
  IF OLD.is_premium IS DISTINCT FROM NEW.is_premium THEN
    -- Verificar si el request viene de un JWT de usuario normal (no service_role)
    -- Los requests con service_role tienen 'service_role' en el claim 'role'
    IF current_setting('request.jwt.claims', true)::json->>'role' = 'authenticated' THEN
      -- Bloquear: el campo is_premium no puede cambiar desde el cliente
      NEW.is_premium := OLD.is_premium;
      RAISE NOTICE 'Blocked client-side is_premium update for user %', OLD.id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Paso 2: Trigger que se ejecuta ANTES del update
DROP TRIGGER IF EXISTS prevent_premium_self_update ON public.users;
CREATE TRIGGER prevent_premium_self_update
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION prevent_client_premium_update();

-- ═══════════════════════════════════════════════════════════════════════════════
-- VERIFICACIÓN: Testear que funciona
-- ═══════════════════════════════════════════════════════════════════════════════
-- 
-- Desde el cliente (debería ser bloqueado silenciosamente):
--   await supabase.from('users').update({'is_premium': true}).eq('id', uid);
--   → El trigger revierte el cambio de is_premium, pero permite otros campos
--
-- Desde Edge Function con service_role (debería funcionar):
--   await adminClient.from('users').update({'is_premium': true}).eq('id', uid);
--   → Pasa porque el role es 'service_role', no 'authenticated'
-- ═══════════════════════════════════════════════════════════════════════════════
