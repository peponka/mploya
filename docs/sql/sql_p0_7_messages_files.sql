-- ============================================================================
-- Mploya — Fase B: Soporte de archivos/media en mensajes
-- Ejecutar en Supabase SQL Editor
-- ============================================================================

-- 1. Agregar columnas de media a la tabla messages (si no existen)
ALTER TABLE public.messages 
  ADD COLUMN IF NOT EXISTS file_url TEXT,
  ADD COLUMN IF NOT EXISTS file_name TEXT,
  ADD COLUMN IF NOT EXISTS file_type TEXT,        -- 'image', 'file', 'voice', 'video'
  ADD COLUMN IF NOT EXISTS file_size_bytes BIGINT;

-- 2. Crear bucket para archivos de chat (si no existe)
-- NOTA: Esto se hace desde el dashboard de Supabase → Storage → Create Bucket
-- Nombre: "chat-files"
-- Public: false (privado, solo accesible via signed URLs)

-- 3. Índice para búsqueda rápida de mensajes por conversación
CREATE INDEX IF NOT EXISTS idx_messages_conversation 
  ON public.messages (sender_id, receiver_id, created_at DESC);

-- 4. Índice para mensajes no leídos
CREATE INDEX IF NOT EXISTS idx_messages_unread
  ON public.messages (receiver_id, is_read) 
  WHERE is_read = false;

-- 5. RLS: Asegurar que solo los participantes del chat lean/escriban
-- (Si ya existe, estas son idempotentes)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'messages_select_own' AND tablename = 'messages') THEN
    CREATE POLICY messages_select_own ON public.messages FOR SELECT USING (
      auth.uid() = sender_id OR auth.uid() = receiver_id
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'messages_insert_own' AND tablename = 'messages') THEN
    CREATE POLICY messages_insert_own ON public.messages FOR INSERT WITH CHECK (
      auth.uid() = sender_id
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'messages_update_own' AND tablename = 'messages') THEN
    CREATE POLICY messages_update_own ON public.messages FOR UPDATE USING (
      auth.uid() = receiver_id
    );
  END IF;
END $$;

-- 6. Habilitar RLS si no está habilitado
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
