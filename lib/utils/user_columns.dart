/// Columnas de la proyección segura `public.accessible_user_profiles`.
///
/// La lista es positiva: no contiene coordenadas, tokens, embeddings, flags de
/// administración, borrado, onboarding, preferencias privadas ni boosts. La
/// vista excluye perfiles confidenciales salvo autorización 034 válida.
const String kUserColumns =
    'id, name, headline, about, video_url, transcript_url, skills, experience, '
    'education, is_premium, is_verified, open_to_work, location, created_at, '
    'avatar_url, banner_url, company, profile_views, is_hiring, '
    'match_percentage, rating_stars, rating_count, like_count, '
    'connections, ai_transcript_json, account_type, tags, '
    'city, salary_expectation, soft_skills, employer_rating_stars, '
    'employer_rating_count, personality_scores';
