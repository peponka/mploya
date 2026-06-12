# 📋 TODO — 15 de Abril 2026
## Basado en la auditoría de Claude del 14/04

---

## 🔴 FASE 1: Fixes rápidos (10 min)

- [ ] **Quitar `.env` de assets** → `pubspec.yaml` línea 56, borrar `- .env`
- [ ] **Corregir title** → `main.dart:156`, cambiar `'SocialMploya'` → `'Mploya'`
- [ ] **Decidir applicationId** → `build.gradle.kts:10,25` — si nunca se publicó en Play Store, cambiar `com.nexwork.ai` → `com.mploya.ai` (namespace + applicationId)

---

## 🔴 FASE 2: Bloqueantes para publicar (1-2 hrs)

- [ ] **Generar keystore de producción Android**
  ```bash
  keytool -genkey -v -keystore mploya-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias mploya
  ```
- [ ] **Configurar `signingConfigs.release`** en `build.gradle.kts`
- [ ] **Crear `key.properties`** (no commitear al repo)
- [ ] **Verificar archivos `.well-known` en Vercel:**
  - `https://mploya.ai/.well-known/apple-app-site-association`
  - `https://mploya.ai/.well-known/assetlinks.json`
  - Deben tener el bundle ID correcto (el que decidas en Fase 1)

---

## ⚠️ FASE 3: Estabilidad (esta semana)

- [ ] **Verificar RLS tabla `users`** — ¿permite SELECT anon para deep links de perfiles públicos?
- [ ] **Smoke test deep links** en dispositivo real:
  - Cold start (app cerrada)
  - Warm start (app en background)
  - Usuario no logueado
- [ ] **Evaluar remover `purchases_flutter`** del pubspec si RC queda desactivado definitivamente
  - Si se remueve: limpiar imports en `premium_screen.dart` y `premium_paywall_screen.dart`

---

## 🧹 FASE 4: Deuda técnica (próximas 2 semanas)

- [ ] Split `profile_screen.dart` (2510 líneas) en sub-widgets
- [ ] Unificar `premium_screen.dart` + `premium_paywall_screen.dart` en una sola
- [ ] Evaluar Jitsi SDK (+20MB) vs alternativas más ligeras
- [ ] Versionar `assetlinks.json` y `apple-app-site-association` en `/web/.well-known/`

---

## 📎 Referencias

- Auditoría completa: `AUDITORIA_14ABR2026.md`
- Prompt usado: `../PROMPT_AUDITORIA_CLAUDE.md`

---

> Para retomar mañana en Antigravity: "Arrancá con la Fase 1 del TODO_15ABR2026.md"
