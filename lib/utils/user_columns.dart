/// Columnas de `public.users` que puede pedir la app.
///
/// Es **todas menos tres**: `email`, `fcm_token` y `profile_embedding`. Se usa en
/// lugar de `.select()` (que expande a `*`) porque el rol `authenticated` ya no
/// tiene SELECT sobre esas tres, y en Postgres un `SELECT *` falla ENTERO si
/// falta el permiso de una sola columna.
///
/// Se listan por exclusión —y no solo los campos que arma `NexUser`— para que no
/// pueda faltar ninguno: omitir uno no da error, devuelve null en silencio, que
/// es peor. (Un primer intento listó 30 campos y rompió Perfil, Feed y Mensajes.)
///
/// • `email` → sale solo por las RPC `admin_list_users` / `admin_list_boosted`,
///   que validan `is_admin()`. El email propio ya viene en la sesión:
///   `Supabase.instance.client.auth.currentUser?.email`.
/// • `fcm_token`, `profile_embedding` → el cliente nunca los lee.
///
/// Si se agrega una columna a `users` y la app la necesita, sumarla acá.
const String kUserColumns =
    'id, name, headline, about, video_url, transcript_url, skills, experience, '
    'education, is_premium, is_verified, open_to_work, location, created_at, '
    'avatar_url, banner_url, company, profile_views, is_hiring, latitude, '
    'longitude, match_percentage, rating_stars, rating_count, like_count, '
    'connections, ai_transcript_json, account_type, tags, location_geom, '
    'onboarding_step, city, boost_ends_at, boost_type, boost_target_city, '
    'salary_expectation, b2b_tokens, deleted_at, soft_skills, '
    'employer_rating_stars, employer_rating_count, blind_hiring_mode, '
    'personality_scores, push_enabled, email_notifications_enabled, '
    'job_alerts_enabled, boost_started_at, is_admin';
