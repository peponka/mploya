# Mploya AI — Prompts de módulo (MVP)

> Derivados de `PRD_MASTER.md`. Cada bloque es UNA iteración: acotada, verificable
> y sobre el código existente. Ejecutar en orden: primero la fundación de
> embeddings (habilita el ranking), luego A, B y C.
>
> Pegá cada prompt tal cual al agente. Todos comparten el encabezado de abajo.

---

## Encabezado común (va en CADA prompt)

```
ROL: Ingeniero senior sobre la app Flutter+Supabase EXISTENTE de Mploya.
CONTEXTO EXISTENTE: feed Video-Pitch (TikTok), matching por tags (HashtagMatchService)
  + ClaudeAIService.matchScore, Supabase+RLS, Stripe/RevenueCat, mensajería,
  videollamada (Agora móvil / Jitsi web), i18n ES/EN/PT, tema claro/oscuro. NO reconstruir.
STACK FIJO: Flutter · Supabase (Postgres+RLS+Edge Functions+Storage) · Claude API
  (Opus 4.8 pesado / Haiku 4.5 liviano) · Gemini gemini-embedding-001 (1536 dims) para
  embeddings · pgvector · Twilio (fase 2).
RESTRICCIONES: no romper lo existente · i18n · claro/oscuro · costo IA acotado (loguear tokens).
```

---

## Prompt 0 — Fundación de matching (embeddings + pgvector) ✅ HECHO (8/7/2026)

> **Estado real:** ya implementado y verificado en producción, pero distinto a como
> se planteó abajo. Lo construido:
> - Proveedor: **Gemini `gemini-embedding-001` (1536 dims)**, NO HuggingFace (endpoint
>   retirado). Secret `GEMINI_API_KEY` en Supabase.
> - Columnas `vector(1536)`: `users.profile_embedding` + `jobs.embedding` (migraciones
>   003/005/006). NO se creó tabla nueva: se extendió la tabla `jobs` existente (PostGIS).
> - Edge Functions `generate-embedding` (perfiles) y `generate-job-embedding` (vacantes).
> - RPCs `match_candidates_for_job` y `match_jobs_for_candidate`.
> - Flutter: `AIMatchService.generateJobEmbedding()` / `getCandidatesForJob()`; el alta de
>   vacante dispara el embedding (pendiente de recompilar la app para que corra en prod).
>
> Pendiente: backfill de vacantes/perfiles existentes · recompilar app · rotar GEMINI_API_KEY.
> El prompt original (abajo) queda como referencia histórica.

```
TAREA: Montar la infraestructura de embeddings para matching semántico.

MODELO DE DATOS:
- Habilitar extensión `vector` (pgvector).
- Columna `embedding vector(1536)` en `users` (candidatos) y en `job_postings`.
- Índice HNSW (cosine) sobre ambas columnas.
- Tabla `embedding_jobs` (id, entity_type enum[user/job], entity_id, status enum
  [pending/done/error], updated_at) para regenerar vectores de forma idempotente.

ALCANCE:
1. Edge Function `embed-text`: recibe {text}, llama a Gemini gemini-embedding-001,
   trunca/normaliza a 1536 dims, devuelve {embedding}. Aísla el proveedor: si mañana
   se cambia a Voyage/OpenAI, solo se toca esta función.
2. Edge Function `regenerate-embeddings`: para un candidato o vacante, arma el texto
   canónico (perfil: headline+skills+experiencia+idiomas+ubicación; vacante:
   título+descripción+requisitos), llama a `embed-text` y persiste el vector.
3. Trigger/hook: al crear o editar un perfil o una vacante, encolar en
   `embedding_jobs` y regenerar (async, no bloquear la UI).
4. Función SQL `match_candidates(job_id, limit)` → candidatos ordenados por
   similitud coseno con la vacante, devolviendo el score 0–100.

CRITERIOS DE ACEPTACIÓN:
- Al guardar una vacante y un perfil, ambos quedan con `embedding` no nulo en < 5 s.
- `match_candidates(job_id)` devuelve una lista ordenada por score descendente.
- Cambiar de proveedor de embeddings implica editar solo `embed-text`.
- RLS: nadie lee el vector crudo de otro usuario vía API pública.

FUERA DE ALCANCE: UI de ranking (Prompt A), búsqueda en lenguaje natural (Fase 2).
ENTREGABLE: migraciones SQL + 2 Edge Functions + función SQL + pasos de prueba.
```

---

## Prompt A — Lado empresa (vacantes + dashboard) 🟡 PARCIAL (8/7/2026)

> **Estado real:** gran parte ya existía (`VacantesScreen`: lista vacantes de la
> empresa, cuenta postulaciones reales, sheet de postulantes; tabla `job_applications`
> ya en uso; `create_job_with_postgis`). Se implementaron las 2 piezas de IA que
> faltaban y que aprovechan la fundación de matching:
> - **Generar vacante con IA**: Edge Function `generate-job-posting` (Gemini 2.5-flash,
>   JSON estructurado) + botón "Generar con IA ✨" en el modal de creación
>   (`vacantes_screen.dart`) + `AIMatchService.generateJobPosting()`. Deployado y probado.
> - **Ranking de candidatos por IA**: toggle "Postulantes / Recomendados por IA" en el
>   sheet de candidatos, usando `match_candidates_for_job` vía `getCandidatesForJob`,
>   con chip de % de match. Código hecho (usa RPC ya deployado).
>
> Pendiente en este frente: dashboard de métricas/embudo (existe parcialmente en
> `analytics_dashboard_screen`), y recompilar la app para que todo corra en prod.
> El prompt original (abajo) queda como referencia.

```
TAREA: Módulo de publicación de vacantes con IA + dashboard de la empresa.

MODELO DE DATOS (IMPORTANTE — usar lo EXISTENTE, no crear job_postings):
- La tabla de vacantes es `public.jobs` (ya existe, con PostGIS: company_id, title,
  description, salary_range, location, modality, seniority, tags, required_tags,
  is_active, latitude/longitude, y `embedding vector(1536)` ya agregado en migración 005/006).
  El alta se hace con insert directo o el RPC `create_job_with_postgis`.
- Falta crear `applications` (id, job_id, candidate_id, status enum[applied/screening/
  interview/offer/hired/rejected], match_score int, created_at, updated_at) + RLS.
- El ranking de candidatos ya está: RPC `match_candidates_for_job(p_job_id)` /
  `AIMatchService.getCandidatesForJob(jobId)`.
- RLS: la empresa dueña lee/escribe sus vacantes y ve sus applications; el candidato
  solo lee vacantes activas y sus propias applications.

ALCANCE:
1. Formulario crear/editar vacante.
2. Botón "Generar con IA": Edge Function `generate-job-posting` que con Claude Haiku
   completa description + requirements + rango salarial a partir de título + notas.
   Todo el resultado queda EDITABLE por el usuario.
3. Al guardar: status `active`, disparar generación de embedding (Prompt 0).
4. Listado de vacantes de la empresa con estado y contador de candidatos.
5. Dashboard: vacantes activas/cerradas, candidatos por vacante, embudo de
   selección (por status de application), ranking de postulantes (via
   `match_candidates`), actividad reciente. Números reales, sin mocks.

CRITERIOS DE ACEPTACIÓN:
- Creo una vacante escribiendo solo el título; "Generar con IA" completa el resto
  y puedo editarlo antes de guardar.
- Al guardar queda `active` con embedding no nulo.
- El ranking muestra candidatos ordenados por match_score real.
- Otra empresa NO ve mis borradores (verificado por RLS).
- El embudo refleja los status reales de las applications.

FUERA DE ALCANCE: entrevistas (Prompt B), automatizaciones/WhatsApp (Fase 2).
ENTREGABLE: migraciones + Edge Function `generate-job-posting` + pantallas Flutter
(form, listado, dashboard) + pasos de prueba.
```

---

## Prompt B — Entrevistas IA 🟡 BACKEND HECHO (8/7/2026)

> **Estado real:** fundación backend implementada y verificada end-to-end. Falta la UI Flutter.
> - Migración `007_interviews.sql`: tablas `interviews`, `interview_questions`,
>   `interview_answers`, `interview_reports` + helper `is_interview_party` + RLS
>   (solo candidato y empresa dueña de la vacante).
> - Edge Function `generate-interview-questions` (Gemini 2.5-flash): preguntas por
>   vacante, con categoría; persiste si se pasa `interview_id`; soporta follow-up
>   adaptativo vía `previous_qa`. Probada.
> - Edge Function `generate-interview-report` (Gemini 2.5-flash): resumen +
>   competencias + keywords + score + rationale (IA explicable); upsert en
>   `interview_reports` + marca la entrevista `completed`. Probada (score 92 en el test).
> - Reusa la transcripción existente (transcribe-video / deepgram-proxy) para el
>   campo `transcript` de las respuestas.
>
> PENDIENTE (UI Flutter): lanzar entrevista desde una application · flujo de
> grabación de respuestas (reusar Video-Pitch) · vista del informe para RRHH.
> Prompt original abajo como referencia.

```
TAREA: Entrevistas automáticas por video con evaluación por IA.

MODELO DE DATOS:
- `interviews` (id, application_id, status enum[pending/in_progress/completed],
  created_at, completed_at).
- `interview_questions` (id, interview_id, order, text, generated_by enum[ai/human]).
- `interview_answers` (id, question_id, video_url, transcript, created_at).
- `interview_reports` (id, interview_id, summary, competencies jsonb, keywords jsonb,
  score int, created_at).
- RLS: la empresa dueña de la vacante y el candidato de esa application acceden;
  nadie más.

ALCANCE:
1. Edge Function `generate-interview-questions`: con Claude (Opus para calidad)
   genera preguntas a partir de la vacante. Adaptación: tras cada respuesta
   transcrita, puede generar la siguiente pregunta según lo respondido.
2. Flujo de grabación del candidato reusando la infra de Video-Pitch (grabar,
   subir a Storage) + transcripción y subtítulos (infra existente).
3. Edge Function `generate-interview-report`: con Claude Opus produce resumen,
   competencias detectadas, palabras clave y score, guardado en `interview_reports`.
4. Vista para RRHH: ver el informe + reproducir respuestas.

CRITERIOS DE ACEPTACIÓN:
- La empresa lanza una entrevista desde una application y se generan preguntas
  relevantes a la vacante.
- El candidato graba respuestas; quedan transcriptas.
- Al completar, se genera un informe con score y competencias, visible solo para
  las partes autorizadas.
- El informe es explicable (dice POR QUÉ del score) — requisito de IA responsable.

FUERA DE ALCANCE: scheduling con calendario (Fase 2), firma (Fase 4).
ENTREGABLE: migraciones + 2 Edge Functions + pantallas (entrevista candidato +
informe RRHH) + pasos de prueba.
```

---

## Prompt C — Pulir lo existente

```
TAREA: Estabilizar y saldar deuda técnica de los módulos actuales antes de crecer.

ALCANCE:
1. Verificar el fix de audio ya aplicado (RouteObserver + RouteAware en las cards
   del feed): el video se silencia al abrir cualquier pantalla encima y se reanuda
   solo el que sonaba al volver, solo si el feed es la pestaña activa.
2. Resolver los warnings de `flutter analyze` (imports sin usar, elementos/variables
   muertos) en home_feed_screen.dart, tiktok_reel_card.dart, main.dart, etc.
3. Revisar el ciclo de vida de VideoPreloadManager (fugas de controllers, mute en
   transiciones) y de la videollamada.
4. Regresión: feed, matching, perfil, mensajería y videollamada siguen funcionando
   en web y Android.

CRITERIOS DE ACEPTACIÓN:
- `flutter analyze` sin warnings en los archivos tocados.
- No hay audio de video fuera del feed en ningún flujo (perfil, mensajes, alertas,
  empleos, modales, historias).
- Sin regresiones visibles en los flujos principales (web + Android).

FUERA DE ALCANCE: features nuevas.
ENTREGABLE: diff + salida de `flutter analyze` + checklist de regresión probada.
```

---

## Orden sugerido

1. **Prompt 0** (fundación embeddings) — habilita el ranking.
2. **Prompt A** (empresa) — usa el ranking.
3. **Prompt B** (entrevistas) — usa las applications de A.
4. **Prompt C** (pulido) — en paralelo, cuando haga falta estabilizar.

**Decisión aún abierta:** confirmar cuenta/facturación de Gemini (Google Cloud) y
límite de gasto para embeddings antes de correr el Prompt 0.
