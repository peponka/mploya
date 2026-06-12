PLAN DE ACCIÓN — 15 DE ABRIL 2026
Mploya App | Post-auditoría del 14/04
============================================================

BLOQUE 1 — SIGNING E IDENTIDAD (~1.5h) [BLOQUEANTE]
------------------------------------------------------------

[ ] Generar keystore de producción
    keytool -genkey -v -keystore mploya-release.jks -keyalg RSA -keysize 2048 -validity 10000
    Guardar contraseña en lugar seguro. Sin esto, Play Store rechaza el APK.

[ ] Configurar signingConfigs.release en build.gradle.kts
    Reemplazar signingConfig = signingConfigs.getByName("debug") con la config release.
    Usar variables de entorno para las keys, no hardcodeadas.

[ ] Decidir applicationId definitivo
    ¿com.mploya.ai o com.nexwork.ai?
    Si no hay users en Store, cambiarlo ahora es gratis. Después es irreversible.
    Actualizar namespace y applicationId en build.gradle.kts.
    IMPORTANTE: decidir esto ANTES de generar el keystore, porque el SHA-256
    que se registra en assetlinks.json y Firebase debe corresponder al ID final.


BLOQUE 2 — DEEP LINKS EN PRODUCCIÓN (~1h) [BLOQUEANTE]
------------------------------------------------------------

[ ] Verificar archivos .well-known en Vercel
    curl https://mploya.ai/.well-known/apple-app-site-association
    curl https://mploya.ai/.well-known/assetlinks.json
    Si no existen o tienen el bundle ID viejo, los deep links no funcionan.

[ ] Actualizar .well-known si se cambió applicationId
    assetlinks.json debe tener el SHA-256 del keystore de producción (no debug)
    y el applicationId correcto.
    Versionar estos archivos en /web/.well-known/ del repo.

[ ] Verificar RLS de tabla users para deep links anon
    Si la tabla users no permite SELECT anon, los deep links a perfiles públicos
    fallan silenciosamente. Decidir: ¿redirigir al login o hacer perfiles públicos?


BLOQUE 3 — LIMPIEZA DE SEGURIDAD (~45min) [IMPORTANTE]
------------------------------------------------------------

[ ] Eliminar .env de flutter assets en pubspec.yaml
    Quitar la línea "- .env" de la sección assets.
    El .env se queda en el repo para dev local, pero no se bundlea en el APK.
    Cualquiera puede extraerlo con unzip.

[ ] Corregir title: 'SocialMploya' → 'Mploya'
    En main.dart línea ~156.
    Detalle menor pero visible en el app switcher de iOS/Android.


BLOQUE 4 — SMOKE TESTS (~2h) [VALIDACIÓN]
------------------------------------------------------------

[ ] Build release APK con nuevo keystore
    flutter build apk --release
    Verificar que no crashea en startup.
    Probar en dispositivo real, no solo emulador.

[ ] Test deep link: cold start (app cerrada)
    Abrir https://mploya.ai/p/{tuUserId} desde el browser con la app cerrada.
    Verificar que abre la app y navega al perfil correcto.

[ ] Test deep link: usuario no logueado
    Desloguearte y abrir un deep link.
    ¿Muestra error? ¿Redirige al login? ¿Se queda en blanco?
    Documentar el comportamiento actual.

[ ] Abrir pantalla premium con RC desactivado
    Navegar a premium_screen y premium_paywall_screen.
    Verificar que muestran empty state sin crash.
    Probar el botón "restaurar compras".


============================================================
NO HACER MAÑANA (deuda técnica para la semana que viene)
============================================================

- Refactorear profile_screen.dart (2500 líneas) — funciona, no tocar lo que no arde
- Remover purchases_flutter — el bypass aguanta, hacerlo ahora puede romper la compilación
- Evaluar alternativas a Jitsi — es deuda técnica real pero no urgente
- Optimizar el tamaño del bundle — primero publicar, después optimizar


============================================================
CONTEXTO RÁPIDO (resumen de la auditoría del 14/04)
============================================================

CRÍTICOS ENCONTRADOS:
- APK firmado con debug keys → Play Store lo rechaza
- applicationId sigue siendo com.nexwork.ai
- .env bundleado dentro del APK (visible si alguien hace unzip)
- Deep links requieren archivos .well-known servidos desde mploya.ai
- Deep links fallan silenciosamente para usuarios no logueados (RLS)

LO QUE QUEDÓ BIEN:
- Orden de init en main.dart (Supabase + Prefs en paralelo, Firebase diferido)
- Bypass de RevenueCat (_rcDisabled = true) limpio, no crashea
- OAuth scheme consistente entre Info.plist, AndroidManifest y deep_link_service
- premium_paywall_screen maneja _selectedPackage == null correctamente
- Java 17 configurado correctamente
- Zero ocurrencias de "nexwork" en código Dart
- deleteAccount() con flujo GDPR correcto

MÉTRICAS:
- minSdk 26 excluye ~5% de dispositivos Android (aceptable por requisito de Jitsi)
- Tamaño estimado del APK: ~35-40 MB (Jitsi = ~60% del peso)
- Tamaño estimado del AAB: ~25-30 MB

Tiempo estimado total mañana: ~6 horas
