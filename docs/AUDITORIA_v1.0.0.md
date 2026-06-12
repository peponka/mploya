# AUDITORÍA COMPLETA — MPLOYA v1.0.0
**Fecha**: 2026-04-12  
**Auditores**: Senior Software Engineer (ex-FAANG) + CMO (ex-LinkedIn/Tinder)  
**Stack**: Flutter 3.x · Supabase · RevenueCat · Firebase FCM · Riverpod

---

## RESUMEN EJECUTIVO DE RIESGOS

| Riesgo | Probabilidad | Impacto |
|---|---|---|
| Rechazo App Store por ATT faltante | Alta | Crítico |
| Rechazo App Store por delete account incompleto (GDPR) | Alta | Crítico |
| Crash por disposeAll + preloaded controller | Media | Alto |
| Fuga de datos si RLS mal configurada | Baja | Catastrófico |
| Churn por onboarding con video obligatorio | Muy Alta | Alto |
| Cero crecimiento orgánico sin sharing externo | Certeza | Alto |

---

## ÍNDICE

1. [🔴 Críticos](#críticos)
2. [🟡 Importantes](#importantes)
3. [🟢 Sugerencias](#sugerencias)
4. [📊 Gap vs Competidores](#gap-vs-competidores)
5. [🏆 Top 3 CTO](#top-3-cto)
6. [📈 Top 3 CMO](#top-3-cmo)

---

## CRÍTICOS

### 🔴 CRÍTICO #1 — `.env` embebido en el binario de la app

**Categoría**: Seguridad  
**Archivo(s)**: `pubspec.yaml:52`, `.env`

**Problema**  
El archivo `.env` está listado como Flutter asset (`- .env`). Esto lo embebe en el binario compilado. Cualquiera puede hacer `unzip app.ipa` o `apktool d app.apk` y leer `SUPABASE_ANON_KEY`, `RC_APPLE_API_KEY`, `RC_GOOGLE_API_KEY` en texto plano.

**Impacto**  
Alguien puede usar tu RevenueCat API key para hacer compras fraudulentas. La Supabase anon key es pública por diseño (RLS la protege), pero exponerla junto a las demás keys crea una superficie de ataque mayor. App Store puede rechazar si la clave de RevenueCat permite bypassear pagos.

**Solución propuesta**
```yaml
# pubspec.yaml — SACAR el .env de assets
assets:
  - assets/images/
  - assets/videos/
  # NO incluir .env
```
Para RevenueCat, usar `--dart-define` en build time:
```bash
flutter build ios \
  --dart-define=RC_APPLE_API_KEY=xxx \
  --dart-define=SUPABASE_URL=xxx \
  --dart-define=SUPABASE_ANON_KEY=xxx
```
Y en código:
```dart
const String rcKey = String.fromEnvironment('RC_APPLE_API_KEY');
```

**Esfuerzo**: < 1 hora

---

### 🔴 CRÍTICO #2 — Delete Account hace soft-delete cuando la Edge Function falla (GDPR)

**Categoría**: Seguridad / Legal  
**Archivo(s)**: `lib/services/auth_service.dart:254-267`

**Problema**  
`deleteAccount()` hace soft-delete cuando la Edge Function `delete-user` no está disponible. El usuario queda en `auth.users` con una sesión válida. Si el token JWT no ha expirado, puede seguir haciendo requests autenticados.

**Impacto**  
- Violación directa de GDPR "right to be forgotten"
- Apple requiere que delete account sea real y completo (Guideline 5.1.1)
- Posible rechazo en App Store Review
- Un usuario "eliminado" puede seguir autenticándose

**Solución propuesta**  
Deployar la Edge Function `delete-user` antes del launch. El soft-delete solo es aceptable en desarrollo. En producción, si la Edge Function falla, retornar error en lugar de hacer soft-delete silencioso:
```dart
if (response.status != 200) {
  return 'No se pudo eliminar la cuenta. Contactá a soporte@mploya.com';
  // NO soft-delete
}
```

**Esfuerzo**: 1-4 horas (deploy Edge Function)

---

### 🔴 CRÍTICO #3 — Crash: `disposeAll()` en el feed libera controllers activos

**Categoría**: Memory Leak / Crash  
**Archivo(s)**: `lib/screens/home_feed_screen.dart:73`, `lib/services/video_preload_manager.dart:88`

**Problema**  
`HomeFeedScreen.dispose()` llama `VideoPreloadManager.instance.disposeAll()`, que llama `.dispose()` en todos los controllers del cache LRU. Pero `TikTokReelCard` puede tener `_usesPreloaded = true`, apuntando al mismo controller que el manager acaba de liberar. El card activo queda con un `VideoPlayerController` disposed pero `_isInitialized = true`, causando `PlatformException` en cualquier llamada posterior.

**Impacto**  
Crash al volver al feed desde otra tab si hay videos reproduciéndose. Más probable en dispositivos lentos donde la animación de tab tarda más.

**Solución propuesta**
```dart
// En HomeFeedScreen.dispose():
// NO llamar disposeAll() — el manager es singleton
// Llamar pauseAll() en su lugar:
@override
void dispose() {
  _pageController.dispose();
  _likesSub?.cancel();
  VideoPreloadManager.instance.pauseAll(); // ← cambiar aquí
  super.dispose();
}
// Solo llamar disposeAll() en logout / deleteAccount
```

**Esfuerzo**: < 1 hora

---

### 🔴 CRÍTICO #4 — ATT (App Tracking Transparency) faltante → rechazo garantizado en App Store

**Categoría**: App Store Review  
**Archivo(s)**: `ios/Runner/Info.plist`, `lib/main.dart`

**Problema**  
La app usa Firebase (que usa IDFAs) y no implementa el `ATTrackingManager.requestTrackingAuthorization`. Desde iOS 14.5, esto es **obligatorio** antes de cualquier tracking. Adicionalmente, revisar que los `NSUsageDescription` strings en Info.plist sean descriptivos y estén en español.

**Impacto**  
Rechazo garantizado en App Store Review primera instancia.

**Solución propuesta**
```xml
<!-- ios/Runner/Info.plist — verificar que existen y están en español -->
<key>NSCameraUsageDescription</key>
<string>Mploya necesita tu cámara para grabar tu Video-Pitch de 60 segundos.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Mploya necesita el micrófono para grabar el audio de tu Video-Pitch.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Mploya usa tu ubicación para mostrarte oportunidades laborales cerca tuyo.</string>
<key>NSUserNotificationsUsageDescription</key>
<string>Mploya te notifica cuando alguien muestra interés en tu perfil.</string>
<key>NSUserTrackingUsageDescription</key>
<string>Para mostrarte ofertas relevantes y medir la efectividad de la app.</string>
```
```dart
// pubspec.yaml — agregar dependencia
app_tracking_transparency: ^2.0.4

// main.dart — antes de Firebase.initialize()
if (Platform.isIOS) {
  await AppTrackingTransparency.requestTrackingAuthorization();
}
await Firebase.initializeApp(...);
```

**Esfuerzo**: 1-4 horas

---

### 🔴 CRÍTICO #5 — Race condition: `_buildScreens()` destruye el estado de los screens activos

**Categoría**: Race Condition / Crash  
**Archivo(s)**: `lib/navigation/main_navigation.dart:61-74`

**Problema**  
`_fetchAccountType()` hace async fetch y luego llama `_buildScreens()` dentro de `setState`. Esto crea **nuevas instancias** de todos los screens (`HomeFeedScreen()`, `ExploreScreen()`, etc.), destruyendo el estado existente — incluyendo streams activos, posición del PageView y VideoPlayerControllers en reproducción.

**Impacto**  
Crash o comportamiento errático cuando el fetch de `account_type` resuelve después de que el usuario ya está usando la app. Más probable en conexiones lentas (LatAm).

**Solución propuesta**
```dart
// Solo actualizar el tipo; NO reconstruir todos los screens
Future<void> _fetchAccountType() async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;
  try {
    final res = await Supabase.instance.client
        .from('users').select('account_type').eq('id', uid).single();
    final newType = res['account_type']?.toString() ?? 'candidato';
    if (mounted && newType != _accountType) {
      setState(() => _accountType = newType);
      // NO llamar _buildScreens() aquí
    }
  } catch (e) {
    debugPrint('⚠️ fetchAccountType failed: $e');
    Future.delayed(const Duration(seconds: 3), _fetchAccountType); // retry
  }
}

// En build(), usar getter dinámico para el tab 2:
Widget _getTab2() => _accountType == 'empresa'
    ? const AtsDashboardScreen()
    : const NetworkScreen();
```

**Esfuerzo**: < 1 hora

---

### 🔴 CRÍTICO #6 — Streams de MessagingScreen sin filtro defensivo (potencial data breach)

**Categoría**: Seguridad / Privacidad  
**Archivo(s)**: `lib/screens/messaging_screen.dart:31-47`

**Problema**  
Los 3 streams de Messaging se crean sin filtros explícitos de `user_id` y descargan 100 usuarios, 200 conexiones y 500 mensajes confiando 100% en RLS. Un solo error de configuración en las policies de Supabase expone todos esos datos al cliente.

**Impacto**  
Data breach masivo si RLS falla (misconfiguration, bug en policy, nueva tabla sin RLS habilitado). Además, 500 mensajes descargados al abrir Inbox aunque el usuario tenga 3 conversaciones — desperdicio de ancho de banda.

**Solución propuesta**  
Agregar filtros defensivos como segunda capa:
```dart
final String? _currentUserId =
    Supabase.instance.client.auth.currentUser?.id;

// Defense in depth: filtrar por user_id aunque RLS ya lo haga
final _messagesStreamGlobal = Supabase.instance.client
    .from('messages')
    .stream(primaryKey: ['id'])
    .eq('receiver_id', _currentUserId!)
    .order('created_at', ascending: false)
    .limit(100); // 100 en vez de 500
```
Antes del launch: **ejecutar un script de auditoría de RLS** con un usuario de prueba que intente leer datos de otro usuario en cada tabla crítica.

**Esfuerzo**: < 1 hora

---

## IMPORTANTES

### 🟡 IMPORTANTE #1 — Validación de email demasiado permisiva

**Categoría**: Seguridad / UX  
**Archivo(s)**: `lib/services/auth_service.dart:46`

**Problema**  
`if (!email.contains('@'))` pasa strings como `a@`, `@b`, `test@`.

**Solución**
```dart
if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
  return 'Por favor, ingresá un email válido.';
}
```
**Esfuerzo**: < 1 hora

---

### 🟡 IMPORTANTE #2 — Preloader de video sin detección de red móvil vs WiFi

**Categoría**: Rendimiento / UX  
**Archivo(s)**: `lib/services/video_preload_manager.dart:99-115`

**Problema**  
Pre-carga hasta 3 videos simultáneamente sin verificar tipo de red. En datos móviles, un video de 60 segundos puede pesar 30-80MB. El usuario puede consumir 200MB+ simplemente scrolleando el feed durante 5 minutos.

**Solución propuesta**
```yaml
# pubspec.yaml
connectivity_plus: ^6.0.3
```
```dart
// video_preload_manager.dart
static const _maxCacheWifi = 4;
static const _maxCacheCellular = 2; // solo precargar el siguiente

Future<int> _getMaxCache() async {
  final connectivity = await Connectivity().checkConnectivity();
  return connectivity.contains(ConnectivityResult.wifi)
      ? _maxCacheWifi
      : _maxCacheCellular;
}
```
**Esfuerzo**: 1-4 horas

---

### 🟡 IMPORTANTE #3 — purchasePackage no diferencia cancelación del usuario de error real

**Categoría**: Error Handling / UX  
**Archivo(s)**: `lib/services/revenuecat_service.dart:111-129`

**Problema**  
Si el usuario toca "Comprar" y cancela el diálogo de Apple Pay, la app muestra un error genérico.

**Solución**
```dart
} on PurchasesError catch (e) {
  if (e.code == PurchasesErrorCode.purchaseCancelledError) {
    return false; // silencioso — el usuario canceló voluntariamente
  }
  debugPrint('Error en la compra: ${e.message}');
  return false;
}
```
**Esfuerzo**: < 1 hora

---

### 🟡 IMPORTANTE #4 — `is_premium` se actualiza desde el cliente (potencial bypass)

**Categoría**: Seguridad / Monetización  
**Archivo(s)**: `lib/services/revenuecat_service.dart:160-172`

**Problema**  
`_syncPremiumToSupabase()` hace `UPDATE` directo desde el cliente para setear `is_premium = true`. Si RLS permite que un usuario actualice su propio campo `is_premium`, alguien con el JWT puede darse premium gratis.

**Solución**  
El campo `is_premium` debe actualizarse **solo desde un webhook de RevenueCat** → Edge Function (con service_role), nunca desde el cliente. Agregar en RLS:
```sql
-- En Supabase SQL Editor
CREATE POLICY "users cannot update is_premium themselves"
ON public.users FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (
  -- permitir actualizar todo EXCEPTO is_premium desde el cliente
  (SELECT is_premium FROM public.users WHERE id = auth.uid()) = is_premium
);
```
**Esfuerzo**: 1 día (webhook RevenueCat + Edge Function)

---

### 🟡 IMPORTANTE #5 — Offline resilience inexistente

**Categoría**: UX / Confiabilidad  
**Archivo(s)**: Toda la app

**Problema**  
No hay manejo de estado offline. Cuando Supabase no está disponible, los `StreamBuilder` y `FutureBuilder` muestran spinners indefinidos o pantallas vacías sin retry automático ni mensajes empáticos.

**Impacto**  
En LatAm, la conectividad es intermitente (3G lento). Un usuario con mala señal ve spinners infinitos y abandona la app. Este puede ser el mayor contribuyente al churn inicial.

**Solución mínima viable**
```dart
// FeedService — agregar timeout explícito
final rows = await query
    .order('base_score', ascending: false)
    .range(offset, offset + 19)
    .timeout(const Duration(seconds: 10));

// HomeFeedScreen — si hay error pero hay cache, mostrar cache con banner
if (feedState.error != null && feedState.items.isNotEmpty) {
  // mostrar items cacheados + banner "Mostrando datos guardados"
}
```
**Esfuerzo**: 1 día

---

### 🟡 IMPORTANTE #6 — `_fetchAccountType` con `catch(_) {}` vacío

**Categoría**: Error Handling  
**Archivo(s)**: `lib/navigation/main_navigation.dart:73`

**Problema**  
Si falla el fetch de `account_type`, una empresa ve la tab de "Matches" en lugar de "ATS Dashboard" sin ninguna indicación de error.

**Solución**
```dart
} catch (e) {
  debugPrint('⚠️ fetchAccountType failed: $e');
  Future.delayed(const Duration(seconds: 3), _fetchAccountType);
}
```
**Esfuerzo**: < 1 hora

---

### 🟡 IMPORTANTE #7 — Privacy Policy / Terms URLs deben existir antes del submit

**Categoría**: App Store Review / Legal  
**Archivo(s)**: `lib/screens/settings_screen.dart`

**Problema**  
Apple requiere URLs válidos y funcionales en la metadata del App Store. La política de privacidad debe mencionar explícitamente: datos de video, tracking de ubicación GPS, FCM (Firebase), RevenueCat, y el proceso de eliminación de cuenta.

**Checklist antes del submit**:
- [ ] `https://mploya.ai/privacy` accesible públicamente
- [ ] `https://mploya.ai/terms` accesible públicamente
- [ ] La política menciona: video data, GPS, Firebase, RevenueCat, delete account
- [ ] Los links en la app apuntan a URLs que resuelven

**Esfuerzo**: 1-4 horas

---

### 🟡 IMPORTANTE #8 — Zero tests en el proyecto

**Categoría**: Testing / Confiabilidad  
**Archivo(s)**: Todo el proyecto

**Problema**  
No hay ningún archivo `*_test.dart`. Cualquier refactor puede romper silenciosamente funcionalidades críticas sin red de seguridad.

**Tests mínimos antes del launch**:
```dart
// test/auth_service_test.dart
test('signIn con email inválido retorna error', () async {
  final result = await AuthService.instance.signInWithEmail('no-es-email', '123');
  expect(result, isNotNull);
});

test('signUp con password débil retorna error', () async {
  final result = await AuthService.instance.signUpWithEmail('a@b.com', 'abc');
  expect(result, isNotNull);
});

// test/feed_service_test.dart
test('cache hit no hace network call', () async {
  // primer fetch
  await FeedService.instance.getFeedUsers();
  // segundo fetch en los primeros 60s debe usar cache
  final start = DateTime.now();
  await FeedService.instance.getFeedUsers();
  expect(DateTime.now().difference(start).inMilliseconds, lessThan(10));
});
```
**Esfuerzo**: 1 día

---

### 🟡 IMPORTANTE #9 — Archivos monstruo de 60-85KB (mantenibilidad)

**Categoría**: Arquitectura / Deuda Técnica  
**Archivo(s)**: `tiktok_reel_card.dart` (85KB), `profile_screen.dart` (84KB), `messaging_screen.dart` (60KB)

**Problema**  
`tiktok_reel_card.dart` maneja: video player, reacciones, bookmark, matching bidireccional, micro-pitch, reply video, connection status, mutuals y el rendering visual. Imposible de mantener por más de una persona a la vez (git merge conflicts constantes).

**No bloquea el launch.** Refactorizar post-v1.0 en:
- `VideoPlayerWidget`
- `ReactionPanel`
- `CardSocialOverlay` (acciones sociales)
- `CardAuthorInfo` (datos del autor)

**Esfuerzo**: 1 semana (post-launch)

---

## SUGERENCIAS

### 🟢 #1 — `darkModeNotifier` global mutable inconsistente con Riverpod

**Archivo**: `lib/main.dart:17`  
**Solución**: Migrar a `StateProvider<bool>` de Riverpod.  
**Esfuerzo**: < 1 hora

---

### 🟢 #2 — `sortByAffinity` en main thread (potencial jank en dispositivos gama baja)

**Archivo**: `lib/services/feed_service.dart:112`  
**Solución**:
```dart
result = await compute(_sortByAffinityIsolate, SortParams(result, myTags));
```
**Esfuerzo**: < 1 hora

---

### 🟢 #3 — Video-Pitch obligatorio en onboarding mata el conversion rate

**Archivo**: `lib/screens/onboarding_pitch_screen.dart`  
**Problema**: El candidato debe grabar 60 segundos de video ANTES de ver cualquier contenido. Drop-off estimado: 40-60%.  
**Solución**: Hacer el video-pitch opcional con badge "Perfil Incompleto" + push 24h después.  
**Esfuerzo**: 1-4 horas

---

### 🟢 #4 — Sin sharing externo ni deep links (viralidad = cero)

**Problema**: No hay forma de compartir un perfil fuera de la app. Sin deep links, sin invite-a-friend.  
**Solución**: 3 features de alto ROI:
1. `mploya://profile/[userId]` con Universal Links
2. Botón "Compartir perfil" → `mploya.ai/p/[userId]`
3. Invite link con incentivo: "Invitá a un colega, ambos reciben 7 días Premium"

**Esfuerzo**: 1-4 horas por feature

---

### 🟢 #5 — Sin free trial para B2B (barrera de entrada muy alta)

**Problema**: $99/mes sin prueba gratis es una barrera altísima para early adopters cuando la red no tiene masa crítica.  
**Solución**: 
- B2B: "14 días gratis, sin tarjeta de crédito" (configurable en RevenueCat)
- Candidato: descuento 40% primera semana ("Precio de Fundador")

**Esfuerzo**: < 1 hora (config RevenueCat + UI)

---

### 🟢 #6 — Sin loops de retención

**Problema**: Si un usuario no tiene matches ni mensajes, no tiene razón para volver.  
**Solución**:
1. Push semanal: "X empresas vieron tu perfil esta semana" (usando `profile_views`)
2. Push cuando nueva empresa matchea con el candidato: "Hay 5 nuevas empresas de [ciudad] en Mploya"
3. Streak de "Perfil activo" (badge si entrás 3 días seguidos)

**Esfuerzo**: 1 día

---

### 🟢 #7 — Empty states sin call-to-action

**Problema**: "Aún no hay Video-Pitches." — frío, sin dirección.  
**Solución**:
```
"Sé el primero en tu industria.
Los candidatos con Video-Pitch reciben 3x más contactos.
[Grabar mi Pitch ahora →]"
```
**Esfuerzo**: < 1 hora

---

### 🟢 #8 — Copywriting con voseo puede generar fricción en México/Colombia

**Problema**: "Ingresá", "Probá" funciona en AR/UY pero genera distancia en MX/CO/PE.  
**Solución**: Estandarizar en tuteo neutro (`app_es.arb`) o agregar `app_es_AR.arb` vs `app_es_MX.arb`.  
**Esfuerzo**: 4 horas

---

## GAP VS COMPETIDORES

| Feature | LinkedIn | Wellfound | **Mploya** |
|---|:---:|:---:|:---:|
| Share perfil externo | ✅ | ✅ | ❌ |
| Free trial B2B | ✅ | ✅ | ❌ |
| Explorar sin registrarse | ✅ | ✅ | ❌ |
| Skill endorsements | ✅ | ✅ | ❌ |
| Company reviews | ✅ | parcial | ❌ |
| Salary insights | ✅ | ✅ | ❌ |
| **Video Pitch** | ❌ | ❌ | ✅ ← diferenciador |
| **GPS Matching** | ❌ | ❌ | ✅ ← diferenciador |
| **Matching bidireccional** | ❌ | ❌ | ✅ ← diferenciador |

**Conclusión**: No copiar LinkedIn feature por feature. El diferenciador es claro: **video + GPS + matching bidireccional**. Doblar la apuesta en lo que LinkedIn no puede hacer.

---

## TOP 3 CTO

### 1. Deployar `delete-user` Edge Function ANTES del submit
Es el único bloqueador que simultáneamente es un riesgo de rechazo en App Store Y un riesgo legal (GDPR). Una hora de trabajo elimina ambos. Sin esto, no subir al store.

### 2. Auditar RLS en Supabase con un script de prueba
Hacer un script que, con un usuario de prueba B, intente leer datos del usuario A en cada tabla crítica (`messages`, `nexus_signals`, `users`, `connections`, `jobs`). Si cualquier query retorna filas de otro usuario, hay un agujero de seguridad que ningún test de Flutter va a detectar. Este es el único tipo de bug invisible en el código cliente.

### 3. Corregir el crash de `disposeAll()` y el race condition de `_buildScreens()`
Son los dos más probables de manifestarse durante una demo o durante la App Store Review. Un reviewer de Apple que vea la app crashear al cambiar de tab o al volver al feed la rechaza sin más. Ambos son fixes de menos de 1 hora.

---

## TOP 3 CMO

### 1. Hacer el Video-Pitch opcional en onboarding
Es el mayor asesino de conversión del funnel. El paso "grabá 60 segundos de video" antes de ver cualquier contenido puede estar matando el 50%+ del funnel. Cambiar a "completá tu perfil cuando quieras" + recordatorio push 24h después probablemente aumenta el signup completion en 30-50%. Sin masa crítica de usuarios, la red no existe y ningún otro esfuerzo de marketing importa.

### 2. Lanzar con "Precio de Fundador" agresivo
Las primeras 100 empresas: primer mes gratis + $49/mes de por vida (50% off). Los primeros 500 candidatos: Premium gratis 30 días. Necesitás resolver el cold-start problem de una red B2B. El pricing normal ($14.99 / $99) es correcto para escala, no para tracción inicial. Sin dos lados de la red activos en las primeras semanas, el producto muere.

### 3. Implementar sharing externo + deep links en la primera semana post-launch
Cada candidato que manda su "Mploya Profile" en lugar de su CV a una empresa es el mejor caso de uso de viralidad orgánica que tienen. Un link `mploya.ai/p/[userId]` con preview del video-pitch es un ad gratis cada vez que alguien aplica a un trabajo. Sin esto, el crecimiento es 100% paid acquisition — insostenible en stage 0.

---

## CHECKLIST PRE-LAUNCH

### Bloqueadores absolutos (no subir sin esto)
- [ ] Edge Function `delete-user` deployada y funcionando
- [ ] ATT prompt implementado antes de Firebase init
- [ ] `NSUsageDescription` strings en español y descriptivos en Info.plist
- [ ] `.env` sacado de flutter assets
- [ ] Privacy Policy y Terms URLs funcionando y completos
- [ ] Auditoría manual de RLS (script de prueba con 2 usuarios)
- [ ] Fix: `pauseAll()` en lugar de `disposeAll()` en HomeFeedScreen
- [ ] Fix: `_buildScreens()` no se llama en setState posterior a initState

### Recomendado antes del launch
- [ ] Timeout de 10s en queries de Supabase
- [ ] `purchasePackage` maneja `purchaseCancelledError` silenciosamente
- [ ] `fetchAccountType` tiene retry con backoff
- [ ] Filtros defensivos en streams de MessagingScreen
- [ ] Mínimo 3 unit tests para auth flow

### Post-launch (primera semana)
- [ ] Deep links + sharing externo
- [ ] Free trial B2B configurado en RevenueCat
- [ ] Loops de retención (push de re-engagement)
- [ ] Video-Pitch opcional en onboarding
- [ ] Invite-a-friend con incentivo

---

*Generado el 2026-04-12 | Mploya v1.0.0 | Auditoría pre-launch*
