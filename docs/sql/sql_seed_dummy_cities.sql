-- ═══════════════════════════════════════════════════════════════════════════
-- Mploya — Seed de Ciudades para Usuarios de Prueba
-- Ejecutar en: Supabase Dashboard → SQL Editor → Pegar y Run
-- ═══════════════════════════════════════════════════════════════════════════

-- 1️⃣ ASIGNAR CIUDADES ALEATORIAS A USUARIOS SIN CIUDAD
-- A todos los usuarios de prueba que no llenaron su perfil (city IS NULL), 
-- les asignamos una ciudad realista al azar para que el mapa se vea vivo.
UPDATE public.users
SET city = (ARRAY[
  'Asunción, Paraguay', 
  'Guayaquil, Ecuador', 
  'Bogotá, Colombia', 
  'Medellín, Colombia', 
  'Santiago, Chile', 
  'Madrid, España', 
  'Barcelona, España', 
  'Monterrey, México', 
  'CDMX, México', 
  'Guadalajara, México', 
  'Buenos Aires, Argentina', 
  'Córdoba, Argentina', 
  'Rosario, Argentina', 
  'Lima, Perú', 
  'Miami, USA',
  'San José, Costa Rica',
  'Montevideo, Uruguay'
])[floor(random() * 17 + 1)]
WHERE city IS NULL;

-- 2️⃣ ASIGNAR SUS RESPECTIVAS COORDENADAS
-- Usamos la misma lógica precisa para que ahora sí tengan latitud y longitud.

-- Paraguay
UPDATE public.users SET latitude = -25.2637, longitude = -57.5759 WHERE LOWER(city) LIKE '%asunción%';

-- Ecuador
UPDATE public.users SET latitude = -2.1894, longitude = -79.8891 WHERE LOWER(city) LIKE '%guayaquil%';

-- Colombia
UPDATE public.users SET latitude = 4.7110, longitude = -74.0721 WHERE LOWER(city) LIKE '%bogotá%';
UPDATE public.users SET latitude = 6.2442, longitude = -75.5812 WHERE LOWER(city) LIKE '%medellín%';

-- Chile
UPDATE public.users SET latitude = -33.4489, longitude = -70.6693 WHERE LOWER(city) LIKE '%santiago%';

-- España
UPDATE public.users SET latitude = 40.4168, longitude = -3.7038 WHERE LOWER(city) LIKE '%madrid%';
UPDATE public.users SET latitude = 41.3851, longitude = 2.1734 WHERE LOWER(city) LIKE '%barcelona%';

-- México
UPDATE public.users SET latitude = 25.6866, longitude = -100.3161 WHERE LOWER(city) LIKE '%monterrey%';
UPDATE public.users SET latitude = 19.4326, longitude = -99.1332 WHERE LOWER(city) LIKE '%cdmx%';
UPDATE public.users SET latitude = 20.6597, longitude = -103.3496 WHERE LOWER(city) LIKE '%guadalajara%';

-- Argentina
UPDATE public.users SET latitude = -34.6037, longitude = -58.3816 WHERE LOWER(city) LIKE '%buenos aires%';
UPDATE public.users SET latitude = -31.4201, longitude = -64.1888 WHERE LOWER(city) LIKE '%córdoba%';
UPDATE public.users SET latitude = -32.9468, longitude = -60.6393 WHERE LOWER(city) LIKE '%rosario%';

-- Perú
UPDATE public.users SET latitude = -12.0464, longitude = -77.0428 WHERE LOWER(city) LIKE '%lima%';

-- USA
UPDATE public.users SET latitude = 25.7617, longitude = -80.1918 WHERE LOWER(city) LIKE '%miami%';

-- Costa Rica
UPDATE public.users SET latitude = 9.9281, longitude = -84.0907 WHERE LOWER(city) LIKE '%san josé%';

-- Uruguay
UPDATE public.users SET latitude = -34.9011, longitude = -56.1645 WHERE LOWER(city) LIKE '%montevideo%';

-- 3️⃣ VERIFICAR RESULTADO
SELECT name, city, latitude, longitude FROM public.users ORDER BY city;
