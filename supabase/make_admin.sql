-- ─────────────────────────────────────────────────────────────────────────────
-- Te marca como ADMINISTRADOR para acceder al Panel de Administración.
--
-- ⚠️ ORDEN: corré PRIMERO `admin_setup.sql` (crea la columna is_admin + las
--    políticas RLS que dejan al admin leer/editar todo). Después corré esto.
--
-- Tu cuenta principal es 'goole' (pepeq68@gmail.com). Si querés que otra cuenta
-- también sea admin, agregá más líneas con su email.
-- ─────────────────────────────────────────────────────────────────────────────

UPDATE public.users SET is_admin = true WHERE email = 'pepeq68@gmail.com';

-- Verificación: debería listar tu cuenta como admin.
-- SELECT name, email, is_admin FROM public.users WHERE is_admin = true;
