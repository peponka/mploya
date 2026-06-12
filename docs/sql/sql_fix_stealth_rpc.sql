-- ================================================================
-- FIX: get_stealth_catalog() — Type mismatch entre TEXT y VARCHAR
-- 
-- Error original: "Returned type text does not match expected type 
--   character varying in column 2"
-- 
-- Causa: Las columnas headline/about en la tabla users son TEXT,
--        pero el RETURNS TABLE las declaraba como VARCHAR.
--
-- EJECUTAR EN: Supabase SQL Editor → New Query → Run
-- ================================================================

CREATE OR REPLACE FUNCTION public.get_stealth_catalog()
RETURNS TABLE (
  candidate_id UUID,
  headline TEXT,          -- Cambiado de VARCHAR a TEXT
  about TEXT,             -- Cambiado de VARCHAR a TEXT
  tags TEXT[],
  budget TEXT,            -- Cambiado de VARCHAR a TEXT
  is_unlocked BOOLEAN,
  real_name TEXT          -- Cambiado de VARCHAR a TEXT
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_me UUID := auth.uid();
BEGIN
  RETURN QUERY
  SELECT 
    u.id, 
    u.headline, 
    u.about, 
    u.tags,
    '1M+'::TEXT AS budget,
    (pu.id IS NOT NULL) AS is_unlocked,
    CASE WHEN pu.id IS NOT NULL THEN u.name ELSE 'Confidencial'::TEXT END AS real_name
  FROM public.users u
  LEFT JOIN public.profile_unlocks pu ON pu.candidate_id = u.id AND pu.company_id = v_me
  WHERE u.account_type = 'confidencial';
END;
$$;
