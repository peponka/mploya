-- ================================================================
-- P0-5 FIX: ÍNDICES CRÍTICOS DE SUPABASE (Performance)
-- Copia este texto y córrelo en el SQL Editor de tu Supabase.
-- ================================================================

-- 1. Feed principal (Acelera la búsqueda de usuarios con videos)
CREATE INDEX IF NOT EXISTS idx_users_feed ON public.users (account_type, created_at DESC)
  WHERE video_url IS NOT NULL AND video_url != '';

-- 2. Señales Nexus (Es la tabla que revisan en el Batch constantemente)
CREATE INDEX IF NOT EXISTS idx_nexus_sender ON public.nexus_signals (sender_id, receiver_id, signal_type);
CREATE INDEX IF NOT EXISTS idx_nexus_receiver ON public.nexus_signals (receiver_id, status, created_at DESC);

-- 3. Conexiones Mentores/Empresas
CREATE INDEX IF NOT EXISTS idx_connections_pair ON public.connections (requester_id, addressee_id, status);
CREATE INDEX IF NOT EXISTS idx_connections_addressee ON public.connections (addressee_id, status);

-- 4. Stream de Likes en Tiempo Real
CREATE INDEX IF NOT EXISTS idx_pitch_likes_liker ON public.pitch_likes (liker_id, pitch_owner_id);

-- 5. Menú de Notificaciones
CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications (user_id, is_read, created_at DESC);

-- 6. Perfiles Guardados en la DB
CREATE INDEX IF NOT EXISTS idx_saved_profiles_user ON public.saved_profiles (user_id, saved_user_id);

-- 7. Puntos Boost! (Acelera el cálculo del algoritmo de afinidad)
CREATE INDEX IF NOT EXISTS idx_users_boost_active ON public.users (boost_ends_at);
