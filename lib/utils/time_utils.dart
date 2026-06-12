/// Converts a raw timestamp value (String, DateTime, or null) into a
/// human-readable relative time string in Spanish.
///
/// Parameters:
///   [raw]      — ISO-8601 string, DateTime, or null.
///   [fallback] — Returned when [raw] is null or unparseable (default '').
///   [prefix]   — Prepended to the numeric result, e.g. 'Hace ' or 'hace '.
///
/// Examples:
///   timeAgo(row['created_at'])                  // '3h'
///   timeAgo(row['created_at'], fallback: 'Reciente')   // 'Reciente' when null
///   timeAgo(row['viewed_at'],  prefix: 'Hace ')  // 'Hace 2d'
String timeAgo(Object? raw, {String fallback = '', String prefix = ''}) {
  if (raw == null) return fallback;
  final dt = DateTime.tryParse(raw.toString());
  if (dt == null) return fallback;
  final diff = DateTime.now().difference(dt);
  if (diff.inDays > 0) return '$prefix${diff.inDays}d';
  if (diff.inHours > 0) return '$prefix${diff.inHours}h';
  if (diff.inMinutes > 0) return '$prefix${diff.inMinutes}m';
  return 'Ahora';
}
