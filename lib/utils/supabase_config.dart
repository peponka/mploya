// ─────────────────────────────────────────────────────────────────────────────
// Mploya — Supabase Configuration
//
// SECURITY NOTES:
// • The ANON KEY below is a PUBLIC key (equivalent to a frontend API key).
//   It is safe to include in client-side code. All data security is enforced
//   via Row Level Security (RLS) policies on the database.
// • The SERVICE ROLE key (admin key) is NEVER included in client code.
// • For production APK builds, inject via --dart-define:
//   flutter build apk --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
// ─────────────────────────────────────────────────────────────────────────────

abstract final class SupabaseConfig {
  /// Supabase project URL — injected at build time or fallback.
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://qclipzefqndcefwwixdy.supabase.co',
  );

  /// Supabase anon (public) key — safe to embed in client code.
  /// All data access is controlled by RLS policies.
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFjbGlwemVmcW5kY2Vmd3dpeGR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2MzQ1MjYsImV4cCI6MjA5MDIxMDUyNn0.'
        'Pl6xdBAHP0yuSq91Dpv1SamSFkn4lTVsLOcu2EKdwkM',
  );

  /// Whether credentials were injected at build time (vs using defaults).
  static bool get isInjected => url != 'https://qclipzefqndcefwwixdy.supabase.co';
}
