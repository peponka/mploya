-- ═══════════════════════════════════════════════════════════════════════════
-- SQL para Push Notifications — PASO 1: Crear tablas faltantes + Webhooks
-- Ejecutar en Supabase SQL Editor
-- SEGURO DE RE-EJECUTAR: usa IF NOT EXISTS en todo
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 0. Crear tabla connections si no existe ──────────────────────────────
CREATE TABLE IF NOT EXISTS public.connections (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id  UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  addressee_id  UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status        TEXT        NOT NULL DEFAULT 'pending'
                            CHECK (status IN ('pending','accepted','rejected','blocked')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT connections_no_self   CHECK (requester_id <> addressee_id),
  CONSTRAINT connections_pair_uniq UNIQUE (requester_id, addressee_id)
);

CREATE INDEX IF NOT EXISTS idx_connections_requester ON public.connections (requester_id, status);
CREATE INDEX IF NOT EXISTS idx_connections_addressee ON public.connections (addressee_id, status);

-- RLS para connections
ALTER TABLE public.connections ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='connections' AND policyname='connections_select') THEN
    CREATE POLICY "connections_select" ON public.connections FOR SELECT
      USING (auth.uid() IN (requester_id, addressee_id));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='connections' AND policyname='connections_insert') THEN
    CREATE POLICY "connections_insert" ON public.connections FOR INSERT
      WITH CHECK (auth.uid() = requester_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='connections' AND policyname='connections_update') THEN
    CREATE POLICY "connections_update" ON public.connections FOR UPDATE
      USING (auth.uid() IN (requester_id, addressee_id));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='connections' AND policyname='connections_delete') THEN
    CREATE POLICY "connections_delete" ON public.connections FOR DELETE
      USING (auth.uid() IN (requester_id, addressee_id));
  END IF;
END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.connections TO authenticated;

-- Realtime para connections
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'connections'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.connections;
  END IF;
END $$;

-- ── 0b. Crear tabla pitch_reactions si no existe ─────────────────────────
CREATE TABLE IF NOT EXISTS public.pitch_reactions (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target_user_id  UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reaction_type   TEXT        NOT NULL DEFAULT 'fire',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT pitch_reactions_uniq UNIQUE (user_id, target_user_id, reaction_type)
);

ALTER TABLE public.pitch_reactions ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='pitch_reactions' AND policyname='pitch_reactions_select_all') THEN
    CREATE POLICY "pitch_reactions_select_all" ON public.pitch_reactions FOR SELECT
      TO authenticated USING (TRUE);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='pitch_reactions' AND policyname='pitch_reactions_insert_own') THEN
    CREATE POLICY "pitch_reactions_insert_own" ON public.pitch_reactions FOR INSERT
      WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='pitch_reactions' AND policyname='pitch_reactions_delete_own') THEN
    CREATE POLICY "pitch_reactions_delete_own" ON public.pitch_reactions FOR DELETE
      USING (auth.uid() = user_id);
  END IF;
END $$;

GRANT SELECT, INSERT, DELETE ON public.pitch_reactions TO authenticated;

-- ── 0c. Columna fcm_token en users ───────────────────────────────────────
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS fcm_token TEXT;
CREATE INDEX IF NOT EXISTS idx_users_fcm_token ON public.users(fcm_token) WHERE fcm_token IS NOT NULL;

-- ── 0d. RPCs de conexiones (si no existen) ───────────────────────────────
CREATE OR REPLACE FUNCTION public.send_connection_request(p_addressee_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_me  UUID := auth.uid();
  v_row public.connections%ROWTYPE;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('error', 'not_authenticated'); END IF;
  IF v_me = p_addressee_id THEN RETURN jsonb_build_object('error', 'self_connect'); END IF;

  SELECT * INTO v_row FROM public.connections
  WHERE (requester_id = v_me AND addressee_id = p_addressee_id)
     OR (requester_id = p_addressee_id AND addressee_id = v_me);

  IF FOUND THEN
    RETURN jsonb_build_object('status', v_row.status, 'connection_id', v_row.id, 'message', 'already_exists');
  END IF;

  INSERT INTO public.connections (requester_id, addressee_id) VALUES (v_me, p_addressee_id) RETURNING id INTO v_row.id;
  RETURN jsonb_build_object('status', 'pending', 'connection_id', v_row.id, 'message', 'pending_sent');
END;
$$;

CREATE OR REPLACE FUNCTION public.respond_connection(p_requester_id UUID, p_action TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_me UUID := auth.uid();
  v_new_status TEXT;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('error', 'not_authenticated'); END IF;
  IF p_action NOT IN ('accept', 'reject') THEN RETURN jsonb_build_object('error', 'invalid_action'); END IF;
  v_new_status := CASE p_action WHEN 'accept' THEN 'accepted' ELSE 'rejected' END;

  UPDATE public.connections SET status = v_new_status
  WHERE requester_id = p_requester_id AND addressee_id = v_me AND status = 'pending';

  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'request_not_found'); END IF;
  RETURN jsonb_build_object('status', v_new_status, 'message', 'ok');
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_connection_request(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_connection(UUID, TEXT) TO authenticated;

-- ══════════════════════════════════════════════════════════════════════════
-- PASO 2: PUSH NOTIFICATION WEBHOOKS
-- ══════════════════════════════════════════════════════════════════════════

-- ── 1. Habilitar extensión pg_net ────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS pg_net;

-- ── 2. Función genérica para enviar webhook a la Edge Function ───────────
CREATE OR REPLACE FUNCTION public.notify_push_webhook()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_payload jsonb;
  v_edge_url text;
  v_anon_key text;
BEGIN
  v_edge_url := 'https://qclipzefqndcefwwixdy.supabase.co/functions/v1/send-fcm';
  v_anon_key := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFjbGlwemVmcW5kY2Vmd3dpeGR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2MzQ1MjYsImV4cCI6MjA5MDIxMDUyNn0.Pl6xdBAHP0yuSq91Dpv1SamSFkn4lTVsLOcu2EKdwkM';

  v_payload := jsonb_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'record', to_jsonb(NEW),
    'old_record', CASE WHEN TG_OP = 'UPDATE' THEN to_jsonb(OLD) ELSE NULL END
  );

  PERFORM net.http_post(
    url := v_edge_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_anon_key
    ),
    body := v_payload
  );

  RETURN NEW;
END;
$$;

-- ── 3. Triggers ──────────────────────────────────────────────────────────

-- Connections: INSERT (solicitud nueva) y UPDATE (aceptada)
DROP TRIGGER IF EXISTS trg_push_connection_insert ON public.connections;
CREATE TRIGGER trg_push_connection_insert
  AFTER INSERT ON public.connections
  FOR EACH ROW EXECUTE FUNCTION public.notify_push_webhook();

DROP TRIGGER IF EXISTS trg_push_connection_update ON public.connections;
CREATE TRIGGER trg_push_connection_update
  AFTER UPDATE ON public.connections
  FOR EACH ROW
  WHEN (NEW.status IS DISTINCT FROM OLD.status)
  EXECUTE FUNCTION public.notify_push_webhook();

-- Messages: INSERT (mensaje nuevo)
DROP TRIGGER IF EXISTS trg_push_message_insert ON public.messages;
CREATE TRIGGER trg_push_message_insert
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.notify_push_webhook();

-- Pitch Reactions: INSERT (reacción nueva)
DROP TRIGGER IF EXISTS trg_push_reaction_insert ON public.pitch_reactions;
CREATE TRIGGER trg_push_reaction_insert
  AFTER INSERT ON public.pitch_reactions
  FOR EACH ROW EXECUTE FUNCTION public.notify_push_webhook();

-- ── 4. Verificación ──────────────────────────────────────────────────────
SELECT 
  tgname AS trigger_name,
  tgrelid::regclass AS table_name
FROM pg_trigger 
WHERE tgname LIKE 'trg_push_%'
ORDER BY tgrelid::regclass::text;
