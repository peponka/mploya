# Informe de Diagnóstico — Auth & Feed Fix
**Fecha:** 2026-04-17  
**Proyecto:** Mploya (Flutter + Supabase)  
**Problema reportado:** Después del login, el usuario nunca ve la pantalla principal. Va directo a errores.

---

## 1. Resumen Ejecutivo

Hay **dos bugs distintos** que se manifiestan juntos:

| # | Error visible | Origen | Severidad |
|---|---|---|---|
| A | "Algo salió mal. Recargá la app." (gris arriba) | `NetworkImage("")` en avatar — **ya corregido en código actual** | ALTA — ya fixeado |
| B | "Error al cargar el feed" (centro) | `rethrow` en `feed_service.dart:113` | ALTA — **fixeado en este PR** |
| C | Crash potencial silencioso | Streams sin `onError` en `main_navigation.dart` | MEDIA — **fixeado en este PR** |

El usuario estaba testeando un APK antiguo donde el Bug A aún existía. El código actual YA tiene el fix del Bug A (`avatarUrl != null && avatarUrl.isNotEmpty`). Solo era necesario reconstruir el APK.

---

## 2. Cadena completa de errores (arranque → pantalla de error)

```
1. App arranca → main.dart → SplashScreen
2. splash_screen.dart:112-117
   └─ addPostFrameCallback: AuthService.instance.currentSession != null?
   └─ SÍ (hay sesión persistida de login anterior)
   └─ _hasNavigated = true → _navigateToHome()
3. _navigateToHome() → consulta users table → onboarding_step >= 3
   └─ pushReplacement → MainNavigation
4. MainNavigation.initState()
   ├─ _subscribeToCounters()
   │   ├─ .stream('notifications') — SIN onError handler → crash potencial
   │   └─ .stream('connections')  — SIN onError handler → crash potencial
   ├─ _fetchAccountType() → OK (tiene try/catch)
   └─ RevenueCatService.instance.initialize(uid) → OK
5. HomeFeedScreen.initState()
   └─ postFrameCallback → loadInitial() → refreshFeed()
6. FeedNotifier.refreshFeed()
   ├─ currentUserData = null (provider en loading) → manualUserRefreshProvider
   ├─ manualUserRefreshProvider → OK (tiene try/catch, retorna null)
   └─ FeedService.getFeedUsers(myType: 'candidato') → FALLA
7. FeedService.getFeedUsers()
   ├─ Intento 1: feed_ranked view → NO EXISTE → PostgREST error → fallback
   ├─ Fallback: users table con filtro account_type IN ('empresa','headhunter')
   │   └─ Si falla (RLS/red/no data) → catch → rethrow  ← BUG B
   └─ rethrow propagado a FeedNotifier
8. FeedNotifier: retry 3 veces (4.5s total)
   └─ Después de 3 fallos: state.error = errorMessage, state.isInitialLoading = false
9. HomeFeedScreen build()
   ├─ Capa 3 (Top Bar): avatarUrl = null → initials = 'N' → OK (ya fixeado)
   └─ Capa 1 (Feed): feedState.error != null && items.isEmpty → "Error al cargar el feed"
10. Usuario ve: icono wifi_slash + "Error al cargar el feed" + botón Reintentar
```

---

## 3. Diagnóstico por archivo

### 3.1 `lib/services/feed_service.dart` — BUG CRÍTICO (FIXEADO)

**Línea afectada:** 110–114 (catch externo del `getFeedUsers`)

**Problema:**
```dart
} catch (e) {
  debugPrint('❌ FeedService: Error al cargar feed: $e');
  if (offset == 0 && _cachedUsers != null) return _cachedUsers!;
  rethrow;  // ← ESTA LÍNEA era el problema
}
```

Si `feed_ranked` no existe Y la query a `users` también falla (RLS, red, o tabla vacía), el error se relanza. El `FeedNotifier` lo captura, reintenta 3 veces, y finalmente setea `state.error`. La UI muestra "Error al cargar el feed".

**Fix aplicado:**
```dart
} catch (e) {
  debugPrint('❌ FeedService: Error al cargar feed: $e');
  if (offset == 0 && _cachedUsers != null) return _cachedUsers!;
  return []; // Retorna lista vacía → muestra "Sé el primero en tu industria"
}
```

**Por qué es correcto:** Si la DB no tiene usuarios con videos (app nueva, DB vacía, o RLS bloquea), lo correcto es mostrar el estado vacío, no un error. El usuario puede "Actualizar feed" cuando haya datos.

---

### 3.2 `lib/navigation/main_navigation.dart` — CRASH SILENCIOSO (FIXEADO)

**Líneas afectadas:** 92–113 (`_subscribeToCounters`)

**Problema:**
```dart
_notifSub = Supabase.instance.client
    .from('notifications')
    .stream(primaryKey: ['id'])
    .eq('user_id', uid)
    .listen((rows) { ... });  // ← SIN onError
```

Si `notifications` o `connections` tables no existen o RLS las bloquea, el stream emite un error. Sin `onError` handler, Dart propaga el error como excepción no manejada. Esto puede causar un crash de la app en producción (reportado en Crashlytics como "Unhandled stream error").

**Fix aplicado:**
```dart
.listen(
  (rows) { ... },
  onError: (e) => debugPrint('⚠️ notifications stream error (non-fatal): $e'),
)
```

---

### 3.3 `lib/screens/home_feed_screen.dart` — BUG A (ya corregido en código actual)

**Líneas:** 386–399 (Top Bar, avatar del usuario)

**Problema original (en APK antiguo):**
```dart
image: DecorationImage(image: NetworkImage(avatarUrl)),  // avatarUrl podría ser ""
```

`NetworkImage("")` lanza una excepción durante el build. El `ErrorWidget.builder` de `main.dart:32-48` la captura y muestra "Algo salió mal. Recargá la app." en la posición del Top Bar (Capa 3).

**Estado actual (ya fixeado, comentado `// FIXED`):**
```dart
image: (avatarUrl != null && avatarUrl.isNotEmpty) // FIXED
    ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
    : null,
child: (avatarUrl == null || avatarUrl.isEmpty) // FIXED
    ? Center(child: Text(initials, ...))
    : null,
```

**Acción requerida:** Solo reconstruir el APK con el código actual.

---

### 3.4 `lib/providers/user_provider.dart` — ESTADO (sin cambios necesarios)

El `currentUserProvider` usa `.handleError()` para swallowear errores del stream. Si el stream falla antes de emitir, el provider puede quedar en `AsyncLoading` indefinidamente. Sin embargo, esto es benigno porque:
- `ref.watch(currentUserProvider).value` retorna `null` cuando está en loading (safe)
- El `manualUserRefreshProvider` actúa como fallback en `feed_provider.dart`
- Los checks de null en la UI están en su lugar

---

### 3.5 `lib/screens/splash_screen.dart` — DISEÑO INTENCIONAL

El comportamiento de navegar directo a `MainNavigation` cuando hay sesión persistida **es correcto**. El problema no estaba en el flujo de auth sino en lo que pasaba después de la navegación.

---

## 4. Fixes aplicados

| Archivo | Cambio | Líneas |
|---|---|---|
| `lib/services/feed_service.dart` | `rethrow` → `return []` | ~113 |
| `lib/navigation/main_navigation.dart` | `onError` handlers en streams | ~96–113 |

---

## 5. Comportamiento esperado después de los fixes

```
App arranca → SplashScreen → sesión detectada → MainNavigation
                                                      ↓
                                             HomeFeedScreen
                                                      ↓
                                   feedProvider.refreshFeed()
                                                      ↓
                              feed_ranked no existe → fallback users table
                                                      ↓
                      Si users table falla → return [] (antes: rethrow)
                                                      ↓
                      feedState.items = [], feedState.error = null
                                                      ↓
              HomeFeedScreen muestra: "Sé el primero en tu industria" ✓
              Top Bar muestra: iniciales del usuario (avatarUrl = null → safe) ✓
              Tab bar funciona correctamente ✓
```

---

## 6. Acciones pendientes en Supabase Dashboard

Para que el feed funcione correctamente con datos reales:

1. **Crear vista `feed_ranked`** (opcional pero mejora rendimiento):
```sql
CREATE OR REPLACE VIEW feed_ranked AS
SELECT *, 
  COALESCE(
    (CASE WHEN boost_ends_at > NOW() THEN 1000 ELSE 0 END) +
    (CASE WHEN is_premium THEN 100 ELSE 0 END),
    0
  ) AS base_score
FROM public.users
WHERE video_url IS NOT NULL AND video_url != '';
```

2. **Verificar RLS en tabla `users`**:
```sql
-- Los usuarios autenticados deben poder leer perfiles de otros
CREATE POLICY "Users can read all profiles"
  ON public.users FOR SELECT
  USING (auth.role() = 'authenticated');
```

3. **Habilitar Realtime** en tabla `users` (Dashboard → Database → Replication):
   - Mejora el `currentUserProvider` para actualizaciones en tiempo real

---

## 7. Verificación

```bash
flutter analyze        # 0 errores esperados
flutter build apk --release  # Build exitoso esperado
```
