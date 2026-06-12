# Informe de Auditoría — Apple App Store Compliance
**App:** Mploya | **Fecha:** 16 de abril de 2026 | **Stack:** Flutter + Supabase

---

## Resumen Ejecutivo

Se auditaron 4 directrices críticas de Apple. **3 de 4 ya estaban implementadas correctamente.** Se detectó y corrigió 1 incumplimiento en tiempo real durante esta sesión.

---

## Resultados por Guideline

### 1. Guideline 1.2 — User Generated Content
**Estado anterior:** ❌ Incumplimiento
**Estado actual:** ✅ Corregido

**Hallazgo:** El visor de videos (`tiktok_reel_card.dart`) permitía que los usuarios consumieran contenido generado por terceros sin ningún mecanismo para reportarlo o bloquear a su autor. Esto viola directamente la Guideline 1.2, que exige que toda app con UGC tenga funciones de reporte y bloqueo visibles y funcionales.

El servicio backend `ContentModerationService.reportContent()` ya existía y estaba operativo, pero no estaba expuesto en la UI del feed.

**Corrección aplicada:**
- Se agregó un botón `⋯` al fondo de la botonera derecha del card de video
- Al tocarlo, se despliega un `CupertinoActionSheet` con dos opciones destructivas:
  - **Reportar video** → sub-menú con 5 motivos (spam, acoso, discriminación, información falsa, privacidad) → llama a `ContentModerationService.instance.reportContent()` con `contentType: 'pitch'`
  - **Bloquear usuario** → diálogo de confirmación → persiste en tabla Supabase `user_blocks` con `{blocker_id, blocked_id}`
- Ambas acciones muestran feedback visual al usuario via `MployaErrorHandler`

**Archivo modificado:** `lib/widgets/tiktok_reel_card.dart`

---

### 2. Guideline 5.1.1(v) — Account Deletion
**Estado:** ✅ Completo — No requirió intervención

**Hallazgo:** La implementación supera los requisitos mínimos de Apple.

- El botón "Eliminar cuenta" está ubicado al fondo de `SettingsScreen`, claramente diferenciado con color rojo e icono de papelera
- Se implementó triple confirmación: (1) diálogo inicial con lista de qué se elimina, (2) campo de texto donde el usuario debe escribir `ELIMINAR` en mayúsculas, (3) pantalla de loading con feedback
- `AuthService.deleteAccount()` ejecuta un flujo completo: limpieza de 17 tablas en orden correcto (respetando FK constraints) → Edge Function `delete-user` con service_role para eliminar de `auth.users` → limpieza de recursos locales → cierre de sesión
- El método no tiene fallback soft-delete, cumpliendo con GDPR Art. 17 (derecho al olvido)

**Archivos auditados:** `lib/screens/settings_screen.dart`, `lib/services/auth_service.dart`

---

### 3. Guideline 4.8 — Sign in with Apple
**Estado:** ✅ Completo — No requirió intervención

**Hallazgo:** La implementación cumple con todos los requisitos de Apple HIG para Sign in with Apple.

- El botón "Continuar con Apple" es el **primer botón** de la pantalla de login (`SplashScreen`), con fondo negro `#1C1C1E` y texto blanco, siguiendo las Human Interface Guidelines de Apple para el botón oficial
- El mismo botón aparece también en el `_AuthBottomSheet` (flujo email), ubicado debajo de Google como segunda opción social
- `AuthService.signInWithApple()` usa `OAuthProvider.apple` via Supabase con deep link callback `io.supabase.mploya://login-callback`

**Archivos auditados:** `lib/screens/splash_screen.dart`, `lib/services/auth_service.dart`

---

### 4. Guideline 5.1.1 — Data Collection & Privacy Permissions
**Estado:** ✅ Completo — No requirió intervención

**Hallazgo:** El `Info.plist` contiene todas las Usage Description strings necesarias con descripciones claras del propósito.

| Clave | Descripción en el plist |
|-------|------------------------|
| `NSCameraUsageDescription` | Grabar Video-Pitch profesional |
| `NSMicrophoneUsageDescription` | Capturar audio del Video-Pitch |
| `NSPhotoLibraryUsageDescription` | Seleccionar video existente de la galería |
| `NSLocationWhenInUseUsageDescription` | Mostrar oportunidades laborales cercanas en el mapa Explore |
| `NSUserTrackingUsageDescription` | Mostrar ofertas laborales relevantes y mejorar experiencia |

Todas las descripciones especifican el motivo concreto del permiso, no frases genéricas, lo que reduce el riesgo de rechazo por parte del revisor.

**Archivo auditado:** `ios/Runner/Info.plist`

---

## Tabla Resumen

| # | Guideline | Descripción | Estado |
|---|-----------|-------------|--------|
| 1 | 1.2 | User Generated Content — Reportar y Bloquear | ✅ Corregido en esta sesión |
| 2 | 5.1.1(v) | Account Deletion — Eliminación permanente de cuenta | ✅ Preexistente y completo |
| 3 | 4.8 | Sign in with Apple — Oferta visual y funcional | ✅ Preexistente y completo |
| 4 | 5.1.1 | Data & Privacy — Usage Descriptions en Info.plist | ✅ Preexistente y completo |

---

## Recomendación para el Equipo de Backend

Antes de la primera build de producción, ejecutar la siguiente migración SQL en Supabase para que el bloqueo de usuarios funcione correctamente:

```sql
CREATE TABLE IF NOT EXISTS public.user_blocks (
  blocker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (blocker_id, blocked_id)
);

ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own blocks"
  ON public.user_blocks FOR ALL
  USING (auth.uid() = blocker_id)
  WITH CHECK (auth.uid() = blocker_id);
```

---

## Conclusión

La aplicación Mploya está en condiciones de pasar la revisión de Apple en los frentes auditados. El único cambio de código necesario fue el menú de moderación UGC (Guideline 1.2), que fue implementado y conectado al backend existente durante esta sesión.
