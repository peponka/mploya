# Mploya AI — PRD Maestro

> Documento de visión y decisiones de producto. NO es un prompt para ejecutar de
> una sola vez: es la fuente de verdad de la que se derivan los prompts de módulo
> (ver `MVP_PROMPTS.md`). Cada módulo se construye como una iteración chica y
> verificable, **sobre el código existente**, sin reconstruir.

---

## 1. Visión

Posicionar a Mploya como la plataforma de reclutamiento con IA más completa de
Latinoamérica: un **asistente de contratación** que automatiza el proceso de
selección de punta a punta — no un simple portal de empleo. La IA optimiza
tiempos, reduce costos y facilita identificar al mejor talento.

## 2. Estado actual (NO reconstruir — extender)

Mploya ya existe y está en desarrollo activo:

- App **Flutter** (web `mploya.ai/app/` + Android/iOS).
- **Supabase**: Postgres + RLS + Edge Functions + Storage + Realtime.
- **Feed Video-Pitch** estilo TikTok (web + móvil), con pausa/mute por
  visibilidad y por ruta.
- **Matching actual**: `HashtagMatchService` (score por tags) + `ClaudeAIService.matchScore`.
- **Subtítulos automáticos** en los reels.
- **Pagos**: Stripe / RevenueCat.
- **Mensajería** + **videollamada** (Agora móvil / Jitsi web).
- **i18n** ES/EN/PT · tema claro/oscuro.
- **Auth** Supabase + Google Sign-In.

Cualquier trabajo nuevo **extiende** esto. Regla de oro en todos los prompts:
*"Mploya ya existe. No reconstruyas. No rompas feed, matching, auth, Stripe ni
mensajería existentes."*

## 3. Usuarios

**Empresas:** publicar vacantes · buscar candidatos · crear entrevistas ·
analizar perfiles · contratar · firmar contratos · onboarding.

**Candidatos:** crear perfil · subir CV · grabar Video CV · postularse ·
entrevistas automáticas · consultar estado de postulaciones.

---

## 4. Decisiones técnicas (fijas)

| Área | Decisión | Nota |
|------|----------|------|
| Front | Flutter (web + móvil) | El existente. No migrar de framework. |
| Back | Supabase (Postgres + RLS + Edge Functions + Storage + Realtime) | — |
| IA razonamiento/generación | **Claude API** — Opus 4.8 (pesado: informes, entrevistas) / Haiku 4.5 (liviano: resúmenes, correcciones) | Ya existe `ClaudeAIService`. |
| **Embeddings** | **Gemini `gemini-embedding-001`**, salida **truncada a 1536 dims** | pgvector no indexa >2000 dims. Sinergia con Google Cloud (ya usado para Sign-In). Aislado en Edge Function `embed-text` → swappable. |
| Vectores | `pgvector` en el mismo Supabase | Índice HNSW. |
| WhatsApp / SMS | **Twilio** (opt-in obligatorio) | Fase 2. |
| Email | SendGrid / el actual | — |
| Firma electrónica | DocuSign / Dropbox Sign (a definir) | Fase 4. |
| Pagos | Stripe / RevenueCat | Ya integrado. |
| API | REST vía Supabase + Edge Functions | No GraphQL. Decisión cerrada. |

**Claude NO genera embeddings** — por eso el proveedor de vectores es aparte
(Gemini). No mezclar ambos roles.

---

## 5. MVP (primeras 2–3 semanas)

Objetivo verificable: *una empresa publica una vacante generada con IA, el sistema
le ordena candidatos por compatibilidad real (vector), lanza una entrevista IA y
recibe un informe — de punta a punta, sin intervención manual.*

### Frente A — Lado empresa
- Publicar / editar / cerrar vacante.
- Generar descripción + requisitos + rango salarial con Claude (Haiku).
- Dashboard: vacantes activas/cerradas, candidatos por vacante, embudo, ranking
  de postulantes, actividad reciente.
- Ranking de candidatos apoyado en el matching por vector.

### Frente B — Entrevistas IA
- Generación de preguntas por vacante (Claude), adaptativas según respuestas.
- Grabación de video (reusar Video-Pitch), transcripción + subtítulos (infra existente).
- Informe para RRHH: resumen, competencias, palabras clave, score.

### Frente C — Pulir lo existente
- Estabilizar feed / matching / perfil / videollamada (incl. fix de audio ya aplicado).
- Deuda técnica: warnings del `flutter analyze`, imports/código muerto.

### Transversal — Fundación de matching (embeddings + pgvector)
- Habilita el ranking del Frente A. Se monta en el MVP: extensión pgvector,
  tablas de embeddings de candidatos y vacantes, pipeline que genera el vector al
  crear/editar perfil o vacante, y `match_score` por similitud coseno.
- La **búsqueda en lenguaje natural** ("dev Flutter, 3 años, Asunción, inglés") se
  agrega encima en Fase 2.

**MoSCoW:** MVP = Must.

---

## 6. Roadmap post-MVP

| Fase | Módulos | Prioridad |
|------|---------|-----------|
| **F2** | Búsqueda NL sobre embeddings · Automatizaciones WhatsApp/email (invitaciones, recordatorios, rechazos) + consentimiento · Calendario Google/Outlook | Should |
| **F3** | IA para candidatos (mejorar CV, simular entrevistas, recomendar empleos/cursos) · Analytics avanzado (fuentes, conversión, reclutadores) | Could |
| **F4** | Firma electrónica · Onboarding · Auditoría/roles finos · Landing premium nueva | Won't (todavía) |

---

## 7. Requisitos no funcionales

- **Escalabilidad:** objetivo realista de arranque a definir en números (ej.
  X empresas / Y candidatos en 6 meses); la arquitectura Supabase + Edge Functions
  cubre el crecimiento inicial sin sobre-ingeniería.
- **Seguridad:** RLS en toda tabla nueva · roles (candidato / empresa / headhunter /
  admin) · cifrado en tránsito y reposo (Supabase) · auditoría de acciones sensibles.
- **Protección de datos:** consentimiento explícito para datos personales y para
  WhatsApp (opt-in). Contemplar normativa local (Paraguay/LATAM) y estilo GDPR.
- **IA responsable (crítico en selección de personal):** la IA **asiste, no decide**.
  Todo score/recomendación es explicable y revisable por un humano. Log de tokens y
  costo por llamada. Evaluar sesgo del matching antes de exponerlo como decisión.
- **Calidad:** i18n ES/EN/PT · claro/oscuro · responsive · manejo de errores y
  estados offline · tests en la lógica de matching y en las Edge Functions.

## 8. Diseño

Premium, inspirado en Linear / Notion / Stripe / Vercel: minimalista, espacios en
blanco amplios, tipografía moderna, iconografía consistente, animaciones suaves,
responsive, claro/oscuro. Reusar el sistema de diseño `mploya_ui` existente.

## 9. Métrica de éxito final

Plataforma SaaS de nivel internacional, competitiva con las mejores soluciones de
reclutamiento con IA: automatización de extremo a extremo, UX excepcional, foco en
ahorrar tiempo a las empresas y mejorar la experiencia del candidato.
