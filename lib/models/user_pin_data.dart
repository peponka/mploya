import 'package:latlong2/latlong.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modelo interno: datos devueltos por la RPC get_nearby_users / get_explore_pins
// ─────────────────────────────────────────────────────────────────────────────

class UserPinData {
  final String id;
  final String name;
  final String headline;
  final String? videoUrl;
  final LatLng point;
  final double distanceKm;
  final String accountType; // 'candidato', 'empresa', 'confidencial', 'stealth'

  const UserPinData({
    required this.id,
    required this.name,
    required this.headline,
    this.videoUrl,
    required this.point,
    required this.distanceKm,
    this.accountType = 'candidato',
  });

  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;
  bool get isCompany => accountType == 'empresa';

  String get distanceLabel {
    if (distanceKm < 1) return 'A ${(distanceKm * 1000).round()} m';
    return 'A ${distanceKm.toStringAsFixed(1)} km';
  }

  String get commuteLabel {
    final mins = (distanceKm * 2.4).round();
    if (mins < 3) return 'A la vuelta 🚶‍♂️';
    return '~$mins min 🚗';
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String get typeLabel => isCompany ? 'Empresa' : 'Candidato';
}
