# AUDITORÍA COMPLETA — Mploya App
**Fecha:** 14 de abril de 2026  
**Revisado por:** Claude Sonnet 4.6  
**Branch:** master | Commit base: `2f9ac45`

---

## 🔴 CRÍTICO — Arreglar ANTES de publicar

### 1. APK firmado con debug keys
**Archivo:** `android/app/build.gradle.kts:38`
```kotlin
signingConfig = signingConfigs.getByName("debug")  // ← BOMBA
```
Google Play **rechazará** cualquier APK firmado con debug keys. El SHA-1 de la debug key no puede registrarse en Play Console. Esto bloquea completamente la publicación en Store.

**Fix:** Generar un keystore de producción y configurar `signingConfigs.release`.

---

### 2. applicationId sigue siendo nexwork
**Archivos:** `android/app/build.gradle.kts:11,24`
```kotlin
namespace = "com.nexwork.ai"
applicationId = "com.nexwork.ai"
```
El bundle ID de Android es `com.nexwork.ai`. Si publican en Play Store con este ID y después quieren cambiarlo, **perderán todos los usuarios instalados** porque Play Store trata el applicationId como identidad permanente.

**Fix:** Decidir ahora si quieren `com.mploya.ai`. Si el APK no está publicado aún, cambiarlo es gratis.

---

### 3. `.env` bundleado dentro del APK
**Archivo:** `pubspec.yaml:56`
```yaml
assets:
  - .env    # ← el .env va dentro del binario
```
Cualquiera que haga `unzip app.apk` puede leer el `.env`. En producción con `--dart-define`, el código ya no usa el `.env`, pero el archivo sigue dentro del binary. Las keys de Supabase anon son semi-públicas por diseño, pero es mala práctica y un riesgo si alguna vez se añaden keys privadas al `.env`.

**Fix:** Eliminar `.env` del listado de assets en `pubspec.yaml`. El archivo puede existir en el repo para desarrollo sin estar bundleado.

---

### 4. Deep links no funcionarán en producción sin los archivos web
El código está correctamente configurado (entitlements iOS, AndroidManifest Android), pero los deep links requieren archivos servidos desde el servidor:
- iOS necesita: `https://mploya.ai/.well-known/apple-app-site-association`
- Android necesita: `https://mploya.ai/.well-known/assetlinks.json`

Sin estos archivos con el bundle ID correcto, iOS abre el browser en lugar de la app, y Android App Links no se verifican. El deploy en Vercel debe incluirlos.

**Verificación rápida:**
```bash
curl https://mploya.ai/.well-known/apple-app-site-association
curl https://mploya.ai/.well-known/assetlinks.json
```

---

### 5. Deep links fallan silenciosamente para usuarios no logueados
**Archivo:** `lib/services/deep_link_service.dart:137`
```dart
final data = await Supabase.instance.client
    .from('users').select().eq('id', userId).maybeSingle();
```
Si la tabla `users` tiene RLS que requiere autenticación, este query devuelve `null` para usuarios no logueados. El resultado: el deep link llega, se parsea, pero no navega a ningún lado — sin error visible al usuario.

**Fix:** Verificar si `users` tiene read-public para perfiles, o redirigir al login primero con el deep link pendiente.

---

## ⚠️ RIESGOSO — Funciona pero puede romperse

### 6. `_selectedPackage!` con non-null assertion
**Archivo:** `lib/screens/premium_screen.dart:238`
```dart
onPressed: _isPurchasing ? null : () => _processPurchase(_selectedPackage!),
```
Analizado: el botón está dentro del `else` que solo aparece cuando `_packages.isNotEmpty`. Con RC desactivado, `_packages` siempre es vacío, por lo que el botón nunca se renderiza. **No crashea hoy.** Pero si alguien activa RC y llega un offering sin el `PackageType.annual/monthly` esperado, el `firstWhere` lanza `StateError` — hay un try/catch que lo atrapa y devuelve `_packages.first`. Está salvado por ahora.

---

### 7. `purchases_flutter` SDK nativo registra en startup aunque `_rcDisabled = true`
Flutter registra todos los plugins nativos al iniciar la app vía `GeneratedPluginRegistrant`. El RevenueCat SDK nativo se registra aunque nunca se llame a `Purchases.configure()`. Consecuencias:
- No crashea — RC SDK no inicializa hasta `configure()`
- Aumenta el tamaño del binario con la framework de RC (~2 MB)
- En edge cases de background app refresh en iOS, el SDK nativo puede intentar network calls

**Fix a largo plazo:** Cuando RC quede definitivamente desactivado, remover `purchases_flutter` del `pubspec.yaml` y eliminar todos los imports.

---

### 8. Archivos que importan `purchases_flutter` directamente
```
lib/screens/premium_screen.dart      ← usa Package, PackageType
lib/screens/premium_paywall_screen.dart ← usa Package
```
Si el SDK se remueve del pubspec en el futuro, estas pantallas no compilarán. Son imports directos de tipos del SDK, no de un wrapper propio.

---

### 9. Jitsi bundlea un runtime de React Native completo
**Archivo:** `lib/screens/messaging_screen.dart:7`
```dart
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
```
Jitsi está confirmado como no-dead-code (hay una llamada real ~línea 873). Pero el SDK bundlea un runtime de React Native completo, añadiendo aproximadamente **20-25 MB** al APK. Si los video calls son una feature secundaria, es un costo desproporcionado.

---

### 10. `media3-exoplayer-rtsp` excluido globalmente
**Archivo:** `android/app/build.gradle.kts:64`
```kotlin
configurations.all {
    exclude(group = "androidx.media3", module = "media3-exoplayer-rtsp")
}
```
Esto es una exclusión global, no solo para Jitsi. `video_player` usa `media3-exoplayer` (sin RTSP), así que no debería verse afectado para archivos MP4/HLS normales. Pero cualquier video RTSP (streams en vivo, cámaras IP) quebrarán silenciosamente en el futuro.

---

### 11. Retry counter compartido en deep links
**Archivo:** `lib/services/deep_link_service.dart:117`
```dart
int _retryCount = 0;
```
Si dos deep links se reciben casi simultáneamente (edge case real en cold-start con notificación push), el counter se corrompe. El segundo link puede abortar prematuramente si el primero ya consumió los retries.

---

## ✅ LO QUE QUEDÓ BIEN Y ES PRODUCTION-READY

| Componente | Veredicto |
|---|---|
| `main.dart` — orden de init | Excelente. Supabase + Prefs en paralelo bloqueante, Firebase/DeepLinks diferidos no-bloqueantes |
| RevenueCat bypass (`_rcDisabled = true`) | Limpio. Todas las early-returns funcionan correctamente, ningún path del SDK real se ejecuta |
| `auth_service.dart` — OAuth scheme | Consistente: `io.supabase.mploya://login-callback` coincide en Info.plist, AndroidManifest y `deep_link_service.dart` |
| AndroidManifest — deep links | `android:autoVerify="true"` configurado, ambos dominios (con y sin www) presentes |
| `Runner.entitlements` — iOS Universal Links | `applinks:mploya.ai` y `applinks:www.mploya.ai` presentes |
| `premium_paywall_screen.dart` | Maneja `_selectedPackage == null` con dialog "próximamente" — no crashea |
| `premium_screen.dart` — empty state | Muestra "Productos no disponibles" cuando packages vacíos — no crashea |
| `ErrorWidget.builder` | Configurado para evitar red screens en producción |
| Java 17 | Correctamente configurado en `compileOptions` y `kotlinOptions` |
| `deep_link_service.dart` — OAuth ignore | Ignora correctamente `io.supabase.mploya://` sin interferir con el callback de Supabase |
| Naming en `/lib` | Zero ocurrencias de "nexwork" en el código Dart — naming limpio |
| `deleteAccount()` | Flujo GDPR correcto con Edge Function y cleanup de tablas en orden de FK constraints |
| `deep_link_service.dart` — retry mechanism | 3 reintentos × 1 segundo con reset correcto del counter cuando navega exitosamente |

---

## 📊 MÉTRICAS

### Dispositivos excluidos por minSdk 26

| Versión Android | API | Excluido | % global estimado |
|---|---|---|---|
| Android 7.x Nougat | 24-25 | ✅ Sí | ~3% |
| Android 6.x Marshmallow | 23 | ✅ Sí | ~1.5% |
| Android 5.x Lollipop | 21-22 | ✅ Sí | ~0.5% |
| **Android 8.0+ Oreo** | **26+** | ❌ No | **~95%** |

**Veredicto:** Aceptable. Era el trade-off obligatorio por el requisito de Jitsi SDK.

---

### Tamaño estimado del bundle

| Componente | Tamaño estimado |
|---|---|
| Flutter base runtime | ~4 MB |
| Supabase + Firebase | ~4 MB |
| RevenueCat nativo (aunque desactivado) | ~2 MB |
| **Jitsi SDK (React Native bundleado)** | **~20-25 MB** |
| video_player + camera + image_picker | ~3 MB |
| Assets (imágenes, videos, branding) | Variable |
| **Total APK estimado** | **~35-40 MB** |
| **Total AAB (App Bundle)** | **~25-30 MB** |

> Jitsi representa ~60% del tamaño total. Removiéndolo, el APK bajaría a ~12-15 MB.

---

### Debug keys — limitaciones concretas

| Canal de distribución | Funciona con debug keys |
|---|---|
| Google Play Store | ❌ Rechazado |
| Sideloading directo (APK) | ⚠️ Funciona con warning de Android |
| Firebase App Distribution | ✅ Funciona |
| TestFlight (iOS) | No aplica (signing distinto) |

---

## 🧹 DEUDA TÉCNICA ACUMULADA HOY

1. **`purchases_flutter` como dependencia zombie** — SDK bundleado pero desactivado. Engrosa el binary y crea imports muertos en 2 pantallas de UI.

2. **`profile_screen.dart` con 2510 líneas** — monstruo técnico que viola el principio de responsabilidad única. Candidatos a extraer: `ProfileHeader`, `ProfileVideoPitch`, `ProfileExperience`, `ProfileActions`, `ProfileConnectionButton`.

3. **Dos pantallas de paywall** (`premium_screen.dart` + `premium_paywall_screen.dart`) con UIs distintas para el mismo concepto — necesita unificación en una sola pantalla parametrizable.

4. **`applicationId = "com.nexwork.ai"`** — naming inconsistente con la marca Mploya visible al usuario.

5. **`.env` en assets** bundleado en producción aunque `--dart-define` lo sobreescribe.

6. **`title: 'SocialMploya'`** en `CupertinoApp` (`main.dart:156`) — mezcla "Social" con "Mploya".

7. **`signingConfig` de producción** apuntando a debug keys con un `// TODO` sin resolución.

8. **`assetlinks.json` y `apple-app-site-association`** no versionados en el repo — dependen enteramente del deploy de Vercel, sin trazabilidad.

---

## 📋 PLAN DE ACCIÓN PRIORIZADO

### Hoy / mañana (bloqueantes para publicar)

- [ ] Generar keystore de producción y configurar `signingConfigs.release` en `build.gradle.kts`
- [ ] Decidir `applicationId`: `com.mploya.ai` vs mantener `com.nexwork.ai` — si no hay users en Store, cambiar ahora es gratis
- [ ] Verificar que Vercel sirve `/.well-known/apple-app-site-association` y `/.well-known/assetlinks.json` con los IDs correctos
- [ ] Eliminar `.env` de `flutter.assets` en `pubspec.yaml`

### Esta semana (estabilidad)

- [ ] Verificar RLS de tabla `users`: ¿permite `SELECT` a anon para deep links públicos?
- [ ] Remover `purchases_flutter` de `pubspec.yaml` e imports, o crear una abstracción (`PaymentService`) que no exponga `Package`/`PackageType` a las pantallas
- [ ] Smoke test en dispositivo real: deep link desde cold-start (app cerrada), warm-start (app en background), y usuario no logueado

### Próximas 2 semanas (deuda técnica)

- [ ] Split de `profile_screen.dart` en sub-widgets
- [ ] Unificar `premium_screen.dart` y `premium_paywall_screen.dart`
- [ ] Evaluar si Jitsi justifica +20 MB en el bundle vs alternativas más ligeras (agora.io, 100ms.live, WebRTC nativo)
- [ ] Corregir `title: 'SocialMploya'` → `'Mploya'` en `main.dart`
- [ ] Versionar `assetlinks.json` y `apple-app-site-association` en el repo bajo `/web/.well-known/`

---

*Generado el 14/04/2026 — Claude Sonnet 4.6*
