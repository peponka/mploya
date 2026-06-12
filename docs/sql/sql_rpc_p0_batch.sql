-- ================================================================
-- P0-1 FIX: RPC BATCH QUERY PARA EL FEED (Solución N+1)
-- Copia este texto y córrelo en el SQL Editor de tu Supabase.
-- ================================================================

CREATE OR REPLACE FUNCTION public.get_card_metadata_batch(p_target_user_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_me UUID := auth.uid();
  v_result JSONB;
  
  v_nexus_sent BOOLEAN;
  v_connection_status TEXT;
  v_is_bookmarked BOOLEAN;
  v_active_reaction TEXT;
  v_reaction_counts JSONB;
  v_reply_video_url TEXT;
BEGIN
  -- Si no hay usuario logueado, retorna todo nulo por seguridad
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  -- 1. ¿Le enviaste señal Nexus (interest, dm, micro_pitch)?
  SELECT EXISTS(
    SELECT 1 FROM public.nexus_signals 
    WHERE sender_id = v_me AND receiver_id = p_target_user_id
  ) INTO v_nexus_sent;

  -- 2. Estado de conexión mutua
  SELECT status INTO v_connection_status 
  FROM public.connections 
  WHERE (requester_id = v_me AND addressee_id = p_target_user_id) 
     OR (requester_id = p_target_user_id AND addressee_id = v_me) 
  LIMIT 1;

  -- 3. ¿Está guardado / Bookmarked?
  SELECT EXISTS(
    SELECT 1 FROM public.saved_profiles 
    WHERE user_id = v_me AND saved_user_id = p_target_user_id
  ) INTO v_is_bookmarked;

  -- 4. Mi reacción activa
  SELECT emoji INTO v_active_reaction 
  FROM public.pitch_reactions 
  WHERE user_id = v_me AND target_user_id = p_target_user_id;

  -- 5. Contador Total de reacciones (Agrupado en un JSON)
  SELECT COALESCE(jsonb_object_agg(emoji, count), '{}'::jsonb) INTO v_reaction_counts
  FROM public.pitch_reaction_counts 
  WHERE target_user_id = p_target_user_id;

  -- 6. Video Reply (Si él te mandó uno a ti, o tú a él)
  SELECT video_url INTO v_reply_video_url 
  FROM public.nexus_signals 
  WHERE signal_type = 'micro_pitch' 
    AND (
      (sender_id = p_target_user_id AND receiver_id = v_me) OR 
      (sender_id = v_me AND receiver_id = p_target_user_id)
    )
  LIMIT 1;

  -- 7. Empaquetar todo en un solo diccionario JSONB mágico
  v_result := jsonb_build_object(
    'nexus_sent', COALESCE(v_nexus_sent, false),
    'connection_status', COALESCE(v_connection_status, 'none'),
    'is_bookmarked', COALESCE(v_is_bookmarked, false),
    'active_reaction', v_active_reaction,
    'reaction_counts', v_reaction_counts,
    'reply_video_url', v_reply_video_url
  );

  RETURN v_result;

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('error', SQLERRM);
END;
$$;
