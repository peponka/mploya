-- ============================================================
-- TEST: Simular solicitud de conexión Candidato → Empresa
-- ============================================================
-- Empresa: af0839ad-8c6d-4a17-a23c-bdc5bd67dfed (gulo@gulo.com)

-- 1) Buscar candidatos existentes que NO sean la empresa
SELECT id, name, headline, account_type 
FROM public.users 
WHERE id != 'af0839ad-8c6d-4a17-a23c-bdc5bd67dfed'
LIMIT 5;
