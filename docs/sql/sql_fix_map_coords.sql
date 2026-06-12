-- ═══════════════════════════════════════════════════════════════════════════
-- Mploya — Asignar coordenadas a TODOS los usuarios según su campo 'city'
-- Ejecutar en: Supabase Dashboard → SQL Editor → Pegar y Run
-- Fecha: 6 abril 2026 (v2 — ampliado con 90+ ciudades)
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── PASO 0: Ver qué hay antes de tocar ───
-- SELECT id, name, city, latitude, longitude, account_type FROM public.users ORDER BY name;

-- ─── PASO 1: ASIGNAR COORDENADAS POR CIUDAD ───
-- Solo actualiza usuarios cuyo lat/lng es NULL, sin pisar datos existentes.
-- Usa ILIKE (case-insensitive) y pattern matching amplio.

-- 🇪🇸 España
UPDATE public.users SET latitude = 40.4168, longitude = -3.7038 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%madrid%');
UPDATE public.users SET latitude = 41.3851, longitude = 2.1734 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%barcelona%');
UPDATE public.users SET latitude = 37.3891, longitude = -5.9845 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%sevilla%' OR LOWER(city) LIKE '%seville%');
UPDATE public.users SET latitude = 39.4699, longitude = -0.3763 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%valencia%');
UPDATE public.users SET latitude = 43.2627, longitude = -2.9253 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%bilbao%');
UPDATE public.users SET latitude = 36.7213, longitude = -4.4214 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%malaga%' OR LOWER(city) LIKE '%málaga%');
UPDATE public.users SET latitude = 41.6488, longitude = -0.8891 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%zaragoza%');

-- 🇪🇺 Europa
UPDATE public.users SET latitude = 51.5074, longitude = -0.1278 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%london%' OR LOWER(city) LIKE '%londres%');
UPDATE public.users SET latitude = 48.8566, longitude = 2.3522 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%paris%' OR LOWER(city) LIKE '%parís%');
UPDATE public.users SET latitude = 52.5200, longitude = 13.4050 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%berlin%' OR LOWER(city) LIKE '%berlín%');
UPDATE public.users SET latitude = 52.3676, longitude = 4.9041 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%amsterdam%');
UPDATE public.users SET latitude = 41.9028, longitude = 12.4964 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%roma%' OR LOWER(city) LIKE '%rome%');
UPDATE public.users SET latitude = 45.4642, longitude = 9.1900 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%milan%' OR LOWER(city) LIKE '%milán%');
UPDATE public.users SET latitude = 38.7223, longitude = -9.1393 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%lisb%');
UPDATE public.users SET latitude = 48.1351, longitude = 11.5820 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%munich%' OR LOWER(city) LIKE '%múnich%');
UPDATE public.users SET latitude = 47.3769, longitude = 8.5417 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%zurich%' OR LOWER(city) LIKE '%zúrich%');
UPDATE public.users SET latitude = 59.3293, longitude = 18.0686 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%stockholm%' OR LOWER(city) LIKE '%estocolmo%');
UPDATE public.users SET latitude = 53.3498, longitude = -6.2603 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%dublin%' OR LOWER(city) LIKE '%dublín%');
UPDATE public.users SET latitude = 48.2082, longitude = 16.3738 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%viena%' OR LOWER(city) LIKE '%vienna%');
UPDATE public.users SET latitude = 50.0755, longitude = 14.4378 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%praga%' OR LOWER(city) LIKE '%prague%');
UPDATE public.users SET latitude = 50.8503, longitude = 4.3517 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%brusel%' OR LOWER(city) LIKE '%brussels%');

-- 🇺🇸 Norteamérica
UPDATE public.users SET latitude = 40.7128, longitude = -74.0060 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%new york%' OR LOWER(city) LIKE '%nueva york%');
UPDATE public.users SET latitude = 34.0522, longitude = -118.2437 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%los angeles%');
UPDATE public.users SET latitude = 41.8781, longitude = -87.6298 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%chicago%');
UPDATE public.users SET latitude = 25.7617, longitude = -80.1918 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%miami%');
UPDATE public.users SET latitude = 37.7749, longitude = -122.4194 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%san francisco%');
UPDATE public.users SET latitude = 29.7604, longitude = -95.3698 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%houston%');
UPDATE public.users SET latitude = 47.6062, longitude = -122.3321 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%seattle%');
UPDATE public.users SET latitude = 42.3601, longitude = -71.0589 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%boston%');
UPDATE public.users SET latitude = 30.2672, longitude = -97.7431 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%austin%');
UPDATE public.users SET latitude = 43.6532, longitude = -79.3832 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%toronto%');
UPDATE public.users SET latitude = 49.2827, longitude = -123.1207 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%vancouver%');
UPDATE public.users SET latitude = 45.5017, longitude = -73.5673 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%montreal%');

-- 🇲🇽 México
UPDATE public.users SET latitude = 19.4326, longitude = -99.1332 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%cdmx%' OR LOWER(city) LIKE '%mexico%' OR LOWER(city) LIKE '%méxico%' OR LOWER(city) LIKE '%ciudad de m%');
UPDATE public.users SET latitude = 20.6597, longitude = -103.3496 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%guadalajara%');
UPDATE public.users SET latitude = 25.6866, longitude = -100.3161 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%monterrey%');
UPDATE public.users SET latitude = 19.0414, longitude = -98.2063 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%puebla%');
UPDATE public.users SET latitude = 21.1619, longitude = -86.8515 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%cancun%' OR LOWER(city) LIKE '%cancún%');

-- 🇦🇷 Argentina
UPDATE public.users SET latitude = -34.6037, longitude = -58.3816 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%buenos aires%' OR LOWER(city) LIKE '%bsas%' OR LOWER(city) LIKE '%caba%');
UPDATE public.users SET latitude = -32.9468, longitude = -60.6393 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%rosario%');
UPDATE public.users SET latitude = -31.4201, longitude = -64.1888 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%cordoba%' OR LOWER(city) LIKE '%córdoba%');
UPDATE public.users SET latitude = -32.8895, longitude = -68.8458 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%mendoza%');

-- 🇨🇴 Colombia
UPDATE public.users SET latitude = 4.7110, longitude = -74.0721 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%bogota%' OR LOWER(city) LIKE '%bogotá%');
UPDATE public.users SET latitude = 6.2442, longitude = -75.5812 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%medellin%' OR LOWER(city) LIKE '%medellín%');
UPDATE public.users SET latitude = 3.4516, longitude = -76.5320 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%cali%');
UPDATE public.users SET latitude = 10.9685, longitude = -74.7813 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%barranquilla%');

-- 🇵🇪 🇨🇱 🇧🇷 🇺🇾 🇪🇨 🇵🇦 🇻🇪 Resto Sudamérica
UPDATE public.users SET latitude = -12.0464, longitude = -77.0428 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%lima%');
UPDATE public.users SET latitude = -33.4489, longitude = -70.6693 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%santiago%');
UPDATE public.users SET latitude = -23.5505, longitude = -46.6333 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%sao paulo%' OR LOWER(city) LIKE '%são paulo%');
UPDATE public.users SET latitude = -22.9068, longitude = -43.1729 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%rio%');
UPDATE public.users SET latitude = -15.7975, longitude = -47.8919 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%brasilia%');
UPDATE public.users SET latitude = -34.9011, longitude = -56.1645 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%montevideo%');
UPDATE public.users SET latitude = -0.1807, longitude = -78.4678 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%quito%');
UPDATE public.users SET latitude = 8.9824, longitude = -79.5199 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%panama%' OR LOWER(city) LIKE '%panamá%');
UPDATE public.users SET latitude = 10.4806, longitude = -66.9036 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%caracas%');
UPDATE public.users SET latitude = -16.5000, longitude = -68.1500 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%la paz%');
UPDATE public.users SET latitude = -25.2637, longitude = -57.5759 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%asuncion%' OR LOWER(city) LIKE '%asunción%');

-- 🇯🇵 🇦🇪 🇸🇬 Asia & Oceanía
UPDATE public.users SET latitude = 35.6762, longitude = 139.6503 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%tokyo%' OR LOWER(city) LIKE '%tokio%');
UPDATE public.users SET latitude = 25.2048, longitude = 55.2708 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%dubai%');
UPDATE public.users SET latitude = 1.3521, longitude = 103.8198 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%singap%');
UPDATE public.users SET latitude = 37.5665, longitude = 126.9780 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%seoul%' OR LOWER(city) LIKE '%seúl%');
UPDATE public.users SET latitude = 31.2304, longitude = 121.4737 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%shanghai%');
UPDATE public.users SET latitude = 22.3193, longitude = 114.1694 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%hong kong%');
UPDATE public.users SET latitude = -33.8688, longitude = 151.2093 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%sydney%' OR LOWER(city) LIKE '%sídney%');

-- 🇲🇦 🇿🇦 África
UPDATE public.users SET latitude = -33.9249, longitude = 18.4241 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%cape town%');
UPDATE public.users SET latitude = -1.2921, longitude = 36.8219 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%nairobi%');
UPDATE public.users SET latitude = 30.0444, longitude = 31.2357 WHERE (latitude IS NULL OR longitude IS NULL) AND (LOWER(city) LIKE '%cairo%' OR LOWER(city) LIKE '%el cairo%');

-- ─── PASO 2: USUARIOS SIN CITY — poner CDMX como fallback de testing ───
-- (Solo si no tienen ni city ni coordenadas)
UPDATE public.users SET latitude = 19.4326, longitude = -99.1332 
WHERE latitude IS NULL AND longitude IS NULL AND (city IS NULL OR city = '');

-- ─── PASO 3: DIAGNÓSTICO — Ver resultado final ───
SELECT 
  name, 
  city, 
  account_type,
  latitude, 
  longitude,
  CASE 
    WHEN latitude IS NOT NULL THEN '✅ Con coords'
    ELSE '❌ Sin coords'
  END AS estado
FROM public.users
ORDER BY account_type, name;
