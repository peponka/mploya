---
description: Retomar reconstrucción del flujo de Login, Registro y Onboarding (Puntos 1 a 7).
---

1. Lee primero el archivo `plan_reconstruccion_auth.md` ubicado en la raíz del proyecto para entender todo el contexto de la Fase 20 y los 7 puntos exactos que el usuario solicitó reparar tras un desastre en el Onboarding de ayer.
2. Revisa el archivo `lib/screens/splash_screen.dart`, verificando qué tan roto quedó el ruteo (`_navigateToHome`) con la lógica del `onboarding_step`.
3. Analiza el archivo `lib/services/auth_service.dart`, específicamente el método `upsertUserProfile` para eliminar todo "fallback" o "generación de nombre loco temporal" que falsee los datos.
4. Explora `lib/screens/role_selection_screen.dart` y ordena visual y lógicamente: 1. Candidato, 2. Confidencial, 3. Empresa.
5. Inicia el trabajo progresivamente: primero el SplashScreen (Auth), luego la Pantalla de 3 Roles y finalmente comprueba los `ProfileForms`. Muestra tu progreso ordenado al usuario punto por punto.
