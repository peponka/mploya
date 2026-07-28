/// Columnas de `public.users` que necesita la app para armar un [NexUser].
///
/// Se usa en lugar de `.select()` (que trae TODAS las columnas) para no exponer
/// datos que el cliente nunca lee: `fcm_token`, `email`, `is_admin`,
/// `b2b_tokens`, `profile_embedding`, `deleted_at`… Con las consultas acotadas
/// se pueden revocar esas columnas al rol `authenticated` sin romper nada.
///
/// Si agregás un campo a `NexUser.fromJson`, agregalo también acá.
const String kUserColumns =
    'id, name, headline, about, avatar_url, banner_url, video_url, '
    'skills, tags, experience, education, company, location, '
    'account_type, is_premium, is_verified, is_hiring, open_to_work, '
    'profile_views, connections, match_percentage, rating_stars, rating_count, '
    'latitude, longitude, salary_expectation, ai_transcript_json, '
    'boost_type, boost_ends_at, boost_target_city';
