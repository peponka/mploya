# CONTINUAR MPLOYA — CANDIDATO

Checkpoint del 13 de agosto de 2026.
Este documento es autosuficiente: una sesión nueva puede retomar desde acá sin
leer el historial del chat.

---

## 0. Estado del repositorio

| | |
|---|---|
| Proyecto | `C:\Users\pepeq\OneDrive\Desktop\Mploya27` |
| Rama | `backup/empresa-mobile-completa-20260812` |
| HEAD | `7ffea5cae1b6c97750d4401e7b6dbe4e91eeb013` (`7ffea5c`) |
| SDK | Flutter 3.44.1 / Dart 3.12.1 en `.flutter-sdk/` (no está en PATH global) |

Los comandos de Flutter se invocan con la ruta del SDK del proyecto:

```bash
./.flutter-sdk/bin/flutter test test/candidato_tanda1_goldens_test.dart
```

### Últimos 10 commits

```
7ffea5c feat: add canonical candidate navigation
b04215c fix: persist normal job applications and prevent duplicate notifications
7b2b07d fix: harden job application notification trigger
37612ea feat: add canonical ATS application stages and security
95bff43 chore: version existing pipeline backend migration
a2fff62 fix: harden system notifications and distinguish accepted connections
5787f3d chore: freeze approved empresa shortlist
f0c4cbb feat: complete empresa mobile redesign and real-data audit
70b78cd fix(feed): el header tapaba el badge de match — header pasa a Column, no overlay
0a9e064 fix(feed): categorías dinámicas + bug de falso positivo en el filtro
```

### `git status --short` en el momento del checkpoint

```
 M lib/main.dart
 M lib/screens/explore_screen.dart
 M lib/screens/jobs_screen.dart
 M lib/screens/messaging_screen.dart
 M lib/screens/network_screen.dart
 M lib/screens/notifications_screen.dart
 M lib/screens/profile_screen.dart
 M lib/services/saved_jobs_service.dart
?? design-reference/          (sólo Candidato_Tanda1_Final es del trabajo actual)
?? lib/preview/
?? test/candidato_render_test.dart
?? test/candidato_tanda1_goldens_test.dart
?? test/candidato_tanda1_test.dart
?? test/goldens/candidato_tanda1/
?? test/preview_aislamiento_test.dart
```

Además hay untracked **preexistentes y ajenos** a este trabajo, que NO forman
parte del checkpoint y deben ignorarse: `.claude/`, `.codex/`, `.flutter-sdk/`,
`test/failures/`, los PNG sueltos `.codex_*.png` / `.codex-*.png`, y el resto de
`design-reference/` (`FINAL_SCREENS`, `FINAL_SCREENS_CODEX`, `Main_Screens`,
`Assistants`, los `.zip`).

---

## 1. Empresa Mobile — CONGELADA

**29 pantallas de Empresa Mobile están congeladas y aprobadas. No se tocan.**

Quedaron fijadas en `f0c4cbb` (rediseño completo + auditoría de datos reales) y
`5787f3d` (freeze de la Shortlist aprobada). El directorio
`lib/screens/empresa/` tiene hoy 33 archivos `*_screen.dart`; la diferencia son
las pantallas de la *tanda 2* (Detalle Vacante, Publicar, Shortlist, Comparar,
Entrevistas), que están construidas pero **sin aprobar** — tampoco se tocan en
el trabajo de Candidato.

Hay 7 goldens de Empresa que fallan solos al cambiar el día porque usan
`DateTime.now()`. **Eso no es una regresión y no hay que regenerarlos.**

---

## 2. Backend / migraciones

Las migraciones viven en `supabase/migrations/`. Van del `001` al `030`.

| Migración | Estado | Detalle |
|---|---|---|
| `001` … `027` | Aplicadas (histórico) | Incluye `026_pipeline_real_data.sql`, versionada en `95bff43` |
| **`028_create_system_notification_hardening.sql`** | **CREADA, COMMITEADA (`a2fff62`), NO APLICADA** | Endurece `create_system_notification`: contrato basado en `auth`, whitelist de tipos (`jobAlert`, `connection`, `connection_accepted`, `comment`), chequeo de relación por tipo, `FOR UPDATE OF ja, j`, REVOKE a PUBLIC/anon/service_role |
| **`029_ats_canonical_applications.sql`** | **CREADA, COMMITEADA (`37612ea`), NO APLICADA** | Contrato canónico B′ sobre `job_applications`. **El orden es innegociable: RLS y privilegios PRIMERO, el CHECK ÚLTIMO.** Política de INSERT exige `candidate_id = auth.uid() AND status='pending' AND stage_changed_at IS NULL AND hired_at IS NULL`; `GRANT INSERT (job_id, candidate_id)` a nivel columna; CHECK final `status IN ('pending','viewed','interviewing','accepted','hired','rejected')` |
| **`030_harden_job_application_notification_trigger.sql`** | **APLICADA Y VERIFICADA EN PRODUCCIÓN** (`7b2b07d`) | Endurece `notify_job_application()`: saca el gate de `profiles`, agrega `sender_name`, `EXCEPTION WHEN OTHERS`, `SET search_path = public, pg_temp`, 4 REVOKEs |

### Reglas de aplicación (no negociables)

- **NUNCA** usar `supabase db push`: el historial remoto está vacío y reaplicaría
  todo desde `001`. La ruta segura de lectura y aplicación es
  `supabase db query --linked -f <archivo.sql>`.
- **NO reaplicar `030`.** Ya está en producción.
- **NO aplicar `028` ni `029` sin autorización explícita del usuario.**
- `029` tiene un bloqueo conocido pendiente de resolver antes de aplicarse: el
  caso de *self-hire* choca con las políticas RLS existentes.
- Que una migración exista en el repo **no prueba** que esté aplicada en la base.
  Verificar siempre contra la definición viva.

---

## 3. Navegación Candidato — commit `7ffea5c`

Navegación canónica de 5 destinos, implementada en
`lib/navigation/main_navigation.dart` y **ya commiteada**:

```
Inicio · Vacantes · Red · Mensajes · Perfil
```

Detalles de implementación que hay que conocer antes de tocar ese archivo:

- `_screens` usa `IndexedStack`, que construye **todos** los hijos. Los slots no
  alcanzables para candidato (4, 6, 7, 8) están neutralizados con
  `SizedBox.shrink()` a propósito — si se les devuelve una pantalla real, se
  monta y puede tocar Supabase sin que el usuario la vea.
- `_isIndexAllowedForAccount` define para candidato el set `{0, 1, 2, 5, 9}`.
- `_onTabTap` está blindado: `if (!_isIndexAllowedForAccount(...)) return;`

**Pendiente conocido:** `MpRole.candidato.navItems` en `lib/theme/mp_roles.dart`
todavía tiene la barra vieja de 4 ítems. Está desincronizado a propósito porque
el usuario pidió no tocar ese archivo todavía.

---

## 4. Fix de postulación normal — commit `b04215c`

Antes, postularse desde el flujo normal **no insertaba nada**: la única ruta
alcanzable no llegaba a hacer el INSERT (`SearchScreen` quedó huérfana y su
`JobCard` era inalcanzable). Por eso `job_applications` tenía una sola fila.

El fix vive en `lib/screens/jobs_screen.dart` y **debe conservarse**:

```dart
await _supabase.from('job_applications').insert({
  'job_id': jobId,
  'candidate_id': uid,
});
```

Se aplicó con un diff quirúrgico (141 líneas, 5 hunks) usando un wrapper
`_applyToJobFlow` para no reindentar el archivo.

> **Regla del proyecto:** no correr `dart format` sobre archivos completos. Un
> intento anterior generó un diff de 1204 líneas y 114 hunks, más 2 lints nuevos.

---

## 5. Tanda visual Candidato — 15 mockups

**15 mockups generados y mostrados al usuario: 5 pantallas × 3 resoluciones.**

Ubicación: **`design-reference/Candidato_Tanda1_Final/`**

```
design-reference/Candidato_Tanda1_Final/
├── contact_sheet_all.png       1856 x 1880   (las 15 juntas)
├── contact_sheet_mobile.png    2534 x 1223
├── contact_sheet_tablet.png    2534 x  882
├── contact_sheet_desktop.png   2346 x 2438
├── mobile/    01_inicio · 02_vacantes · 03_red · 04_mensajes · 05_perfil   390 x 844
├── tablet/    (los mismos 5)                                              820 x 1180
└── desktop/   (los mismos 5)                                             1440 x 900
```

### Estado de las 15 pantallas

| # | Pantalla | mobile 390×844 | tablet 820×1180 | desktop 1440×900 |
|---|---|---|---|---|
| 01 | Inicio | ✅ | ✅ | ✅ |
| 02 | Vacantes | ✅ | ✅ | ✅ |
| 03 | Red | ✅ | ✅ | ✅ |
| 04 | Mensajes | ✅ | ✅ | ✅ |
| 05 | Perfil | ✅ | ✅ | ✅ |

Las 15 renderizan sin excepción y **sin overflow** en su tamaño de diseño (el
test lo afirma explícitamente con `tester.takeException() is null`).

Las tres medidas son composiciones distintas de verdad, no un teléfono estirado:
mobile con barra inferior, tablet a dos columnas, desktop con sidebar
persistente y tercera columna de detalle.

### ⚠️ Los mockups NO están conectados a las pantallas productivas

Son composiciones presentacionales puras en `lib/preview/candidato/`. Usan
**datos ficticios** (Renata Ferreyra, Vantera, Almiar, 6 contactos), avatares
por iniciales sobre color (cero imágenes remotas) y **no tocan** Supabase Auth,
Database, RPC, Storage, Firebase, notificaciones, analytics, cámara, permisos,
geolocalización ni red externa. Por eso pueden renderizarse en un test.

**Ningún mockup demuestra que la pantalla productiva equivalente funcione.**

### Identidad visual canónica

Sistema **violeta** de `FINAL_SCREENS_CODEX`: `MpTokens.primary = #4129F0`,
naranja de acento `#FE5001`. La instrucción anterior de "premium azul"
(`#185FA5`) quedó **reemplazada** por decisión del usuario.

`NexTheme` está desviado respecto de estos tokens y **se dejó intacto a
propósito**.

---

## 6. Modo preview local aislado

Se levanta sólo si se cumplen las dos condiciones a la vez:

```bash
./.flutter-sdk/bin/flutter run --dart-define=MPLOYA_PREVIEW=true
```

```dart
// lib/preview/preview_flags.dart
const bool kMployaPreviewFlag = bool.fromEnvironment('MPLOYA_PREVIEW');
const bool kPreviewMode = kDebugMode && kMployaPreviewFlag;
```

Ambas constantes se resuelven en compilación: en un build de release
`kPreviewMode` es `false` y el tree shaking se lleva la rama entera y todo
`lib/preview/`.

El corte está en `lib/main.dart`, **antes** de inicializar Supabase, Firebase,
pinning, push, deep links y conectividad:

```dart
if (kPreviewMode) {
  runApp(const PreviewApp());
  return;
}
```

### Archivos de preview creados

```
lib/preview/preview_flags.dart          las dos constantes de compilación
lib/preview/preview_app.dart            shell con banner "PREVIEW LOCAL — DATOS FICTICIOS"
lib/preview/preview_fixtures.dart       fixtures generales
lib/preview/candidato/cand_kit.dart     kit visual (~700 líneas, APROBADO por el usuario)
lib/preview/candidato/cand_datos_preview.dart   fixtures de la tanda
lib/preview/candidato/cand_inicio_preview.dart
lib/preview/candidato/cand_vacantes_preview.dart
lib/preview/candidato/cand_red_preview.dart
lib/preview/candidato/cand_mensajes_preview.dart
lib/preview/candidato/cand_perfil_preview.dart
```

`cand_kit.dart` define `CandFormato` (mobile <700, tablet 700–1099, desktop
≥1100), `CandDestino`, `CandBarraInferior`, `CandSidebar`, `CandAvatar`,
`CandChip`, `CandMatch`, `CandTarjeta`, `CandTarjetaTip`, `CandEncabezado`,
`CandBuscador`, `CandBoton`, `CandVacio`. Cada composición tiene
`_Mobile` / `_Tablet` / `_Desktop`.

**Invariante protegido por test:** ninguna pantalla productiva puede importar
las fixtures del preview. Si hace falta un comportamiento distinto en preview,
se pasa un `bool esPreview` por parámetro, no se importa el módulo.

---

## 7. Correcciones funcionales SIN COMMITEAR

8 archivos productivos modificados, `+426 / −171`. Son de dos naturalezas:

**a) Desacople de Supabase para que las pantallas monten en un test.**
`Supabase.instance.client` en un inicializador de campo lanza excepción si
Supabase no fue inicializado. Se pasó a `late final _supabase` (evaluación
diferida) y se bifurcaron los getters `_solicitudesStream`, `_perfilBreve`,
`_conexionesStream`, `_usuariosStream`.

**b) Correcciones funcionales de la Tanda 1** (datos demo eliminados,
navegación muerta arreglada, accesos faltantes agregados).

| Archivo | Δ | Qué cambió |
|---|---|---|
| `lib/main.dart` | +14 / −0 | Corte de `kPreviewMode` antes de todo servicio |
| `lib/screens/explore_screen.dart` | +131 / −16 | Correcciones funcionales + desacople |
| `lib/screens/jobs_screen.dart` | +55 / −2 | `JobsPreviewData`, `late final _supabase`, `esPreview` en `_JobListCard` — **conserva el fix de `b04215c`** |
| `lib/screens/messaging_screen.dart` | +98 / −131 | Desacople + limpieza de demo |
| `lib/screens/network_screen.dart` | +87 / −19 | Desacople de streams + accesos rápidos que navegan de verdad |
| `lib/screens/notifications_screen.dart` | +9 / −2 | "Ver perfil" abre Perfil sin cambiar de pestaña |
| `lib/screens/profile_screen.dart` | +27 / −0 | Expone Mis Herramientas y Guardados, conserva Configuración |
| `lib/services/saved_jobs_service.dart` | +5 / −1 | `late final` del cliente |

---

## 8. Tests ejecutados y resultados

Todo lo de abajo se corrió en este checkpoint, no es un recuerdo.

| Comando | Resultado |
|---|---|
| `flutter analyze lib/preview` | **No issues found!** (17.1 s) |
| `flutter analyze lib` | **0 errores** (55 issues, todos `info`/`warning` preexistentes en pantallas ajenas) |
| `flutter test test/candidato_tanda1_goldens_test.dart` | **15/15 All tests passed!** |
| `flutter test test/candidato_tanda1_test.dart` | **14/14 All tests passed!** |
| `flutter test test/preview_aislamiento_test.dart` | **12/12 All tests passed!** |
| `flutter test test/candidato_render_test.dart` | **8 pasan · 3 FALLAN** |

### Los 3 tests que fallan — defecto real, no ruido

Los tres son de **Mensajes** y todos apuntan al mismo defecto:

```
Mensajes › monta sin overflow en mobile 390×844    → RenderFlex overflowed by 112 pixels on the right
Mensajes › monta sin overflow en desktop 1440×900  → RenderFlex overflowed by 103 pixels on the right
Mensajes › la bandeja vacía no inventa conversaciones
```

Es el `Row` de `_buildListPane` en `lib/screens/messaging_screen.dart`, que
necesita ~502 px de ancho. **No es un problema de Supabase ni del test: es un
overflow genuino de la pantalla productiva de Mensajes.** Hay que arreglarlo al
integrar el diseño de Mensajes.

### Archivos de test creados

```
test/candidato_tanda1_goldens_test.dart    15 goldens (5 pantallas × 3 medidas)
test/candidato_tanda1_test.dart            14 tests de correcciones funcionales
test/preview_aislamiento_test.dart         12 tests del invariante de aislamiento
test/candidato_render_test.dart            11 tests de montaje real (8 ✅ / 3 ❌)
test/goldens/candidato_tanda1/*.png        las 15 imágenes de referencia
```

Regenerar goldens:

```bash
./.flutter-sdk/bin/flutter test test/candidato_tanda1_goldens_test.dart --update-goldens
```

---

## 9. Qué está conectado a producción y qué no

### Conectado a producción (real)

- Migración **`030`**, aplicada y verificada en la base.
- El **fix de postulación** de `b04215c`: inserta de verdad en `job_applications`.
- La **navegación canónica** de `7ffea5c`: es la barra que ve el candidato real.
- Las 8 pantallas productivas modificadas siguen leyendo de Supabase. El
  desacople sólo difiere *cuándo* se resuelve el cliente, no lo reemplaza por
  un mock.

### Mockup / preview (NO productivo)

- Las 15 pantallas de `design-reference/Candidato_Tanda1_Final/`.
- Todo `lib/preview/` y sus fixtures.
- Los 15 goldens de `test/goldens/candidato_tanda1/`.

### No aplicado / desincronizado

- `028` y `029`: escritas y commiteadas, **fuera** de la base.
- `MpRole.candidato.navItems`: sigue con 4 ítems.
- Los 8 archivos productivos con correcciones: **sin commitear** hasta este
  checkpoint.

---

## 10. PRÓXIMO PASO EXACTO

**Integrar los cinco diseños aprobados en las pantallas productivas Inicio,
Vacantes, Red, Mensajes y Perfil, conservando los datos reales.**

Es decir: llevar el lenguaje visual de `lib/preview/candidato/` a las pantallas
que consumen Supabase, sin sustituir sus datos por fixtures. El kit
`cand_kit.dart` ya está aprobado y es el vocabulario a reutilizar.

Orden sugerido, de menor a mayor riesgo:

1. **Perfil** — la composición es la más estable y ya tiene los accesos correctos.
2. **Vacantes** — cuidando de no romper el INSERT de `b04215c`.
3. **Red**.
4. **Inicio**.
5. **Mensajes** — última, porque además hay que corregir el overflow de 112/103 px
   del `Row` de `_buildListPane`.

Al integrar cada una: sincronizar `MpRole.candidato.navItems` a los 5 destinos.

### Cola posterior (no ahora)

- Resolver el bloqueo de *self-hire* de `029` y recién ahí decidir si se aplica.
- Orden de despliegue acordado: `030` (hecho) → app → `028` → `029`.
- Firma release del APK, todavía pendiente.

---

## 11. RESTRICCIONES PERMANENTES

- ❌ **No tocar Empresa** (`lib/screens/empresa/`), **Headhunter** ni **onboarding**.
- ❌ **No aplicar migraciones sin autorización explícita.** En particular: no
  aplicar `028` ni `029`, no reaplicar `030`.
- ❌ **Nunca** `supabase db push`.
- ❌ **No deploy. No push.**
- ❌ No `dart format` sobre archivos completos; diffs quirúrgicos.
- ❌ No usar datos inventados para afirmar que algo funciona. Un mockup que
  renderiza no es una pantalla que funciona; una migración en el repo no es una
  migración aplicada. **Verificar siempre contra el sistema vivo.**
- ⚠️ Git sólo con autorización previa del usuario: ni commit ni push por
  iniciativa propia.
