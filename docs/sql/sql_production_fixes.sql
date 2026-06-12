-- ═══════════════════════════════════════════════════════════════════════════════
-- MPLOYA — PRODUCTION FIXES PARA SUPABASE
-- Fecha: 2026-04-15
-- Instrucciones: Correr CADA BLOQUE por separado en el SQL Editor de Supabase
-- ═══════════════════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOQUE 1: Verificar/Crear bucket "videos" como PÚBLICO
-- ─────────────────────────────────────────────────────────────────────────────
-- Si el bucket YA existe, esto lo actualiza a público.
-- Si NO existe, lo crea como público.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'videos',
  'videos',
  true,                          -- PÚBLICO: URLs accesibles sin token
  104857600,                     -- 100MB límite por archivo
  ARRAY['video/mp4', 'video/quicktime', 'video/webm']::text[]
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 104857600,
  allowed_mime_types = ARRAY['video/mp4', 'video/quicktime', 'video/webm']::text[];


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOQUE 2: Storage RLS Policies para bucket "videos"
-- ─────────────────────────────────────────────────────────────────────────────
-- Permite a usuarios autenticados subir, leer y borrar SUS propios archivos.
-- Lectura pública para todos (el bucket es público).

-- 2a. SELECT (lectura) → cualquiera puede ver videos públicos
DROP POLICY IF EXISTS "Videos públicos lectura" ON storage.objects;
CREATE POLICY "Videos públicos lectura"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'videos');

-- 2b. INSERT (subida) → solo usuarios autenticados
DROP POLICY IF EXISTS "Usuarios autenticados suben videos" ON storage.objects;
CREATE POLICY "Usuarios autenticados suben videos"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'videos');

-- 2c. UPDATE (reemplazar) → solo el dueño del archivo
DROP POLICY IF EXISTS "Usuarios actualizan sus videos" ON storage.objects;
CREATE POLICY "Usuarios actualizan sus videos"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id = 'videos' AND (auth.uid())::text = (storage.foldername(name))[1]);

-- 2d. DELETE (borrar) → solo el dueño del archivo
DROP POLICY IF EXISTS "Usuarios borran sus videos" ON storage.objects;
CREATE POLICY "Usuarios borran sus videos"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'videos' AND (auth.uid())::text = (storage.foldername(name))[1]);


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOQUE 3: Configurar edge_function_url para Push Notifications
-- ─────────────────────────────────────────────────────────────────────────────
-- Este setting es usado por sql_p0_6_push_triggers.sql para enviar
-- webhooks a la Edge Function de FCM.
-- REEMPLAZÁ 'qclipzefqndcefwwixdy' por tu project ref si es diferente.

ALTER DATABASE postgres 
SET app.settings.edge_function_url = 'https://qclipzefqndcefwwixdy.supabase.co/functions/v1/send-fcm';


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOQUE 4: Agregar columna fcm_token si no existe + cleanup trigger
-- ─────────────────────────────────────────────────────────────────────────────
-- Esto asegura que al hacer logout, el token FCM se puede limpiar.

-- 4a. Columna fcm_token (si no existe)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'fcm_token'
  ) THEN
    ALTER TABLE public.users ADD COLUMN fcm_token text;
  END IF;
END $$;

-- 4b. Índice para búsquedas rápidas de tokens
CREATE INDEX IF NOT EXISTS idx_users_fcm_token ON public.users(fcm_token) WHERE fcm_token IS NOT NULL;


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOQUE 5 (VERIFICACIÓN): Confirmar que todo quedó bien
-- ─────────────────────────────────────────────────────────────────────────────

-- Verificar bucket
SELECT id, name, public, file_size_limit, allowed_mime_types 
FROM storage.buckets 
WHERE id = 'videos';

-- Verificar policies
SELECT policyname, cmd 
FROM pg_policies 
WHERE tablename = 'objects' AND schemaname = 'storage' 
AND policyname LIKE '%video%' OR policyname LIKE '%Video%';

-- Verificar setting de edge function
SELECT current_setting('app.settings.edge_function_url', true);

-- Verificar columna fcm_token
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'users' AND column_name = 'fcm_token';
