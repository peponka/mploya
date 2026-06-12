-- ═══════════════════════════════════════════════════════════════════════════
-- Mploya — Resetear y Asignar Coordenadas (V3)
-- Ejecutar en: Supabase Dashboard → SQL Editor → Pegar y Run
-- Fecha: 6 abril 2026
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── PASO 1: RESETEAR COORDENADAS ───
-- Limpiamos las coordenadas erróneas (como los que cayeron en Buenos Aires por defecto).
UPDATE public.users SET latitude = NULL, longitude = NULL;

-- ─── PASO 2: ASIGNAR COORDENADAS POR CIUDAD O PAÍS ───
-- (Ignorando mayúsculas y acentos gracias a ILIKE)

-- 🇵🇪 Perú
UPDATE public.users SET latitude = -12.0464, longitude = -77.0428 WHERE (LOWER(city) LIKE '%lima%' OR LOWER(city) LIKE '%peru%' OR LOWER(city) LIKE '%perú%');

-- 🇪🇸 España
UPDATE public.users SET latitude = 40.4168, longitude = -3.7038 WHERE latitude IS NULL AND (LOWER(city) LIKE '%madrid%' OR LOWER(city) LIKE '%españa%' OR LOWER(city) LIKE '%spain%');
UPDATE public.users SET latitude = 41.3851, longitude = 2.1734 WHERE latitude IS NULL AND (LOWER(city) LIKE '%barcelona%');
UPDATE public.users SET latitude = 37.3891, longitude = -5.9845 WHERE latitude IS NULL AND (LOWER(city) LIKE '%sevilla%');
UPDATE public.users SET latitude = 39.4699, longitude = -0.3763 WHERE latitude IS NULL AND (LOWER(city) LIKE '%valencia%');
UPDATE public.users SET latitude = 36.7213, longitude = -4.4214 WHERE latitude IS NULL AND (LOWER(city) LIKE '%malaga%' OR LOWER(city) LIKE '%málaga%');

-- 🇦🇷 Argentina
UPDATE public.users SET latitude = -34.6037, longitude = -58.3816 WHERE latitude IS NULL AND (LOWER(city) LIKE '%buenos aires%' OR LOWER(city) LIKE '%bsas%' OR LOWER(city) LIKE '%caba%' OR LOWER(city) LIKE '%argentina%');
UPDATE public.users SET latitude = -32.9468, longitude = -60.6393 WHERE latitude IS NULL AND (LOWER(city) LIKE '%rosario%');
UPDATE public.users SET latitude = -31.4201, longitude = -64.1888 WHERE latitude IS NULL AND (LOWER(city) LIKE '%cordoba%' OR LOWER(city) LIKE '%córdoba%');
UPDATE public.users SET latitude = -32.8895, longitude = -68.8458 WHERE latitude IS NULL AND (LOWER(city) LIKE '%mendoza%');

-- 🇲🇽 México
UPDATE public.users SET latitude = 19.4326, longitude = -99.1332 WHERE latitude IS NULL AND (LOWER(city) LIKE '%cdmx%' OR LOWER(city) LIKE '%mexico%' OR LOWER(city) LIKE '%méxico%');
UPDATE public.users SET latitude = 20.6597, longitude = -103.3496 WHERE latitude IS NULL AND (LOWER(city) LIKE '%guadalajara%');
UPDATE public.users SET latitude = 25.6866, longitude = -100.3161 WHERE latitude IS NULL AND (LOWER(city) LIKE '%monterrey%');

-- 🇨🇴 Colombia
UPDATE public.users SET latitude = 4.7110, longitude = -74.0721 WHERE latitude IS NULL AND (LOWER(city) LIKE '%bogota%' OR LOWER(city) LIKE '%bogotá%' OR LOWER(city) LIKE '%colombia%');
UPDATE public.users SET latitude = 6.2442, longitude = -75.5812 WHERE latitude IS NULL AND (LOWER(city) LIKE '%medellin%' OR LOWER(city) LIKE '%medellín%');
UPDATE public.users SET latitude = 3.4516, longitude = -76.5320 WHERE latitude IS NULL AND (LOWER(city) LIKE '%cali%');

-- 🇨🇱 Chile
UPDATE public.users SET latitude = -33.4489, longitude = -70.6693 WHERE latitude IS NULL AND (LOWER(city) LIKE '%santiago%' OR LOWER(city) LIKE '%chile%');

-- 🇺🇾 Uruguay
UPDATE public.users SET latitude = -34.9011, longitude = -56.1645 WHERE latitude IS NULL AND (LOWER(city) LIKE '%montevideo%' OR LOWER(city) LIKE '%uruguay%');

-- 🇪🇨 Ecuador
UPDATE public.users SET latitude = -0.1807, longitude = -78.4678 WHERE latitude IS NULL AND (LOWER(city) LIKE '%quito%' OR LOWER(city) LIKE '%ecuador%');

-- 🇺🇸 Estados Unidos
UPDATE public.users SET latitude = 40.7128, longitude = -74.0060 WHERE latitude IS NULL AND (LOWER(city) LIKE '%new york%' OR LOWER(city) LIKE '%nueva york%' OR LOWER(city) LIKE '%usa%' OR LOWER(city) LIKE '%estados unidos%');
UPDATE public.users SET latitude = 25.7617, longitude = -80.1918 WHERE latitude IS NULL AND (LOWER(city) LIKE '%miami%');
UPDATE public.users SET latitude = 34.0522, longitude = -118.2437 WHERE latitude IS NULL AND (LOWER(city) LIKE '%los angeles%');

-- 🇪🇺 Resto de Europa y Asia (Solo match de países y principales ciudades)
UPDATE public.users SET latitude = 51.5074, longitude = -0.1278 WHERE latitude IS NULL AND (LOWER(city) LIKE '%london%' OR LOWER(city) LIKE '%uk%' OR LOWER(city) LIKE '%england%');
UPDATE public.users SET latitude = 48.8566, longitude = 2.3522 WHERE latitude IS NULL AND (LOWER(city) LIKE '%paris%' OR LOWER(city) LIKE '%france%' OR LOWER(city) LIKE '%francia%');
UPDATE public.users SET latitude = 41.9028, longitude = 12.4964 WHERE latitude IS NULL AND (LOWER(city) LIKE '%roma%' OR LOWER(city) LIKE '%rome%' OR LOWER(city) LIKE '%italia%' OR LOWER(city) LIKE '%italy%');


-- ─── PASO 3: SIN FALLBACK RANDOM ───
-- Si no hicimos match con la ciudad de la persona, NO le ponemos una coordenada random.
-- Así evitamos que la gente aparezca en Buenos Aires sin ser de ahí.

-- ─── PASO 4: RESULTADO ───
SELECT 
  name, 
  city, 
  account_type,
  CASE 
    WHEN latitude IS NOT NULL THEN '📍 Mapeado en Coords (' || latitude || ', ' || longitude || ')'
    ELSE '❌ No Encontrado - Ciudad: ' || COALESCE(city, 'N/A')
  END AS estado_mapa
FROM public.users
ORDER BY estado_mapa;
