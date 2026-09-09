# Auditoría de seguridad y calidad — Mploya27 (local, carpeta completa)

**Fecha:** 27/8/2026
**Alcance:** Working tree local completo en `Mploya27` (rama actual: `backup/empresa-mobile-completa-20260812`, HEAD `e449c599`), comparado contra `main`/`origin/main` (72 commits, última auditoría del 27/8 sobre el repo de GitHub).
**Método:** revisión directa de archivos vía conexión al dispositivo — sin subir zip ni copiar la carpeta.

## Resumen ejecutivo

El trabajo de hardening de seguridad hecho en agosto (migraciones 026–045, rediseño de `feed_ranked`) sigue existiendo **solo en la rama local `backup/empresa-mobile-completa-20260812`**, nunca mergeado a `main` ni pusheado. `main`/`origin/main` — lo único que hay en GitHub — sigue en el estado vulnerable que ya se había detectado el 27/8: keystore de release commiteado y la vista `feed_ranked` vieja, que exponía `latitude`, `longitude`, `salary_expectation` y `ai_transcript_json` a `anon`.

La buena noticia: en la rama local esos dos problemas críticos **ya están resueltos**, y de forma bastante más robusta que un parche simple. La mala noticia: mientras no se mergee a `main`, esas correcciones no protegen nada en producción si `main` es lo que se despliega.

## Hallazgos críticos

### 1. `main` (rama pública en GitHub) sigue exponiendo PII vía `feed_ranked` a `anon`
`main` solo tiene migraciones hasta la `025_feed_ranked_sin_pii.sql`. Esa versión de la vista:

```sql
CREATE VIEW public.feed_ranked WITH (security_invoker = true) AS
SELECT ..., latitude, longitude, ..., ai_transcript_json, ..., salary_expectation, ...
FROM public.users u ...
GRANT SELECT ON public.feed_ranked TO anon, authenticated;
```

Ubicación real (coordenadas), expectativa salarial y el JSON de transcripción de la entrevista con IA quedan accesibles con la anon key pública para cualquiera que llame al endpoint REST, sin login.

**Corregido en la rama local**, migración `035_close_direct_user_profile_access.sql`: elimina ese `feed_ranked` y lo reemplaza por tres vistas con `security_barrier` + `REVOKE ALL` explícito:
- `safe_user_profiles` (para `anon`): sin lat/long, sin `salary_expectation`, sin `ai_transcript_json`.
- `accessible_user_profiles` (solo `authenticated`, con lógica de perfiles "stealth"/"confidenciales" y desbloqueo vía `candidate_unlock_ledger`).
- `feed_ranked` nuevo: ahora se construye sobre `accessible_user_profiles` y su `GRANT SELECT` es solo para `authenticated` — ya no para `anon`.

`lib/services/feed_service.dart` ya está preparado para este esquema (intenta `feed_ranked`, si falla cae a `accessible_user_profiles` con `kUserColumns`).

**Acción recomendada:** mergear `backup/empresa-mobile-completa-20260812` a `main` (al menos las migraciones 026–045) y aplicar la migración 035 en producción cuanto antes. Mientras `main` sea lo desplegado, este leak sigue activo en producción.

### 2. Keystore de release commiteado — sigue presente, en ambas ramas
`mploya-release.jks` (2728 bytes) sigue trackeado en git, tanto en `main` como en la rama local, a pesar de que `.gitignore` lo excluye explícitamente (`*.jks`, `*.keystore`, `key.properties`) — se commiteó antes de que existiera esa regla y nunca se purgó del historial.

Hallazgo adicional que cambia el análisis de riesgo: en `android/app/build.gradle.kts`, el build de `release` **no usa ese keystore**:

```kotlin
release {
    // TODO: Add your own signing config for the release build.
    // Signing with the debug keys for now, so `flutter run --release` works.
    signingConfig = signingConfigs.getByName("debug")
    ...
}
```

O sea: el keystore expuesto no es (todavía) la clave real de firma — pero eso abre un problema distinto y más urgente para publicar: **los builds de "release" se están firmando con la clave de debug** (contraseña pública y conocida, `android`/`androiddebugkey`). Eso no es publicable en Play Store tal cual, y si se sube así una primera versión, migrar después a una firma real rompe la compatibilidad de actualización para usuarios existentes.

**Acción recomendada:**
- Purgar `mploya-release.jks` (y el `google-services (2).json` duplicado, ver hallazgo #3) del historial de git con `git filter-repo` o BFG, y rotar/regenerar el keystore si se llegó a usar en algún build real.
- Configurar un signing config de release real (vía `key.properties` no trackeado + variables de entorno/CI) antes de cualquier publicación en Play Store.

### 3. `google-services (2).json` duplicado, commiteado
`android/app/google-services (2).json` (695 bytes) está trackeado junto al `google-services.json` original — el nombre con espacio y paréntesis evadió el `.gitignore`. Contiene la misma API key de Firebase que ya viaja en cualquier APK compilado, así que el riesgo real es bajo, pero es basura de repo y vale la pena borrarlo.

## Hallazgos medios

### 4. Errores tragados en 29 lugares (`catch (_) {}`)
Conteo actual sobre los 311 archivos `.dart` de `lib/`: **29** bloques `catch (_) {}` vacíos (subió de los 22 detectados el 27/8 sobre el repo stale — hay más código nuevo con el mismo patrón). Concentrados sobre todo en la primera mitad de `lib/` (screens de candidato/empresa tempranas). `MployaErrorHandler` (`lib/services/error_handler.dart`) centraliza el manejo de errores hacia el usuario (toast) pero **no reporta a Crashlytics** — `wrapAsync()` hace catch, muestra un toast amigable y descarta la excepción.

Crashlytics como paquete está en `pubspec.yaml` (`firebase_crashlytics: ^4.3.5`) y se usa en `lib/main.dart` (8 referencias), pero en ningún otro archivo — es decir, errores de inicialización quedan cubiertos, pero los cientos de `try/catch` repartidos por `lib/services/` y `lib/screens/` no llegan a Crashlytics salvo que pasen por ahí explícitamente.

**Acción recomendada:** conectar `MployaErrorHandler.handleSupabase`/`wrapAsync` a `FirebaseCrashlytics.instance.recordError` antes de mostrar el toast, así los `catch` silenciosos al menos quedan registrados.

### 5. Archivos gigantes — varios por encima de lo que un solo desarrollador puede mantener con seguridad
El peor: `lib/screens/profile_screen.dart` con **6294 líneas** (no estaba entre los archivos grandes reportados el 27/8; puede haber crecido o no haberse revisado antes). Le siguen `lib/screens/jobs_screen.dart` (2536), `lib/screens/notifications_screen.dart` (2528), `lib/screens/messaging_screen.dart` (2359 — el mismo que ya se había marcado como problema), `lib/screens/job_detail_screen.dart` (1399), y otros 30+ archivos por encima de 500 líneas.

Esto no es una vulnerabilidad, pero es el principal factor de riesgo de que sigan apareciendo bugs como los `catch` vacíos o el `context.mp` que se encontró en la migración del design system: archivos de este tamaño son difíciles de revisar completos y fáciles de romper con cambios locales.

### 6. Solo 1 archivo de test en `main`, pero 77 en la rama local
En la rama local hay **77 archivos de test** en `test/` (goldens de Candidato/Empresa/Headhunter, capturas de UI, tests de widgets del design system) contra los 311 de `lib/` — mucho mejor que el 1-contra-186 que tenía `main`. De nuevo: esta cobertura vive solo en la rama que no está mergeada.

## Hallazgos bajos / notas

- **API keys de Firebase en `lib/firebase_options.dart`** (`AIzaSy...`): esperable y no es un secreto real — Firebase las diseña para ir en el cliente, protegidas por las reglas de seguridad del proyecto y restricciones de la API key en la consola de Google Cloud, no por ocultarlas. Vale la pena confirmar en la consola de Firebase que esas keys tienen restricción por `applicationId`/SHA-1.
- **`anonKey` de Supabase hardcodeada como fallback** en `lib/utils/supabase_config.dart`: está documentado explícitamente en el propio archivo como intencional y seguro (es la key pública, protegida por RLS) — correcto, no es un hallazgo.
- **0 usos de `print()`** en los 311 archivos de `lib/` — usan `debugPrint` u otro mecanismo, buena práctica (no se filtran logs en builds de release vía `print`).
- No se encontraron claves privadas (`BEGIN PRIVATE KEY`), tokens tipo `sk_live_`, ni JWT de `service_role` hardcodeados en `lib/`.
- `.env` no está trackeado en git (la regla de `.gitignore` funciona correctamente para ese archivo).

## Estado de las migraciones de Supabase

`main`: hasta `025_feed_ranked_sin_pii.sql` (25 migraciones).
Rama local: hasta `045_fix_hpc_stage_dates_trigger_security.sql` (45 migraciones) — incluye, además del fix de `feed_ranked`, trabajo de ATS (`029`/`038`), ledger de desbloqueo de candidatos confidenciales (`032`–`034`), headhunter (`039`–`044`), y hardening de triggers (`045`).

## Prioridad sugerida

1. Mergear la rama de seguridad a `main` y aplicar las migraciones pendientes en producción — el leak de PII vía `feed_ranked` sigue vivo mientras esto no pase.
2. Resolver el signing config de release (hoy firma con debug key) antes de cualquier submit a Play Store, y purgar el `.jks` del historial de git.
3. Conectar el manejo de errores centralizado a Crashlytics.
4. Planear una división de los archivos más grandes (`profile_screen.dart` primero) como deuda técnica, no urgente pero creciente.
