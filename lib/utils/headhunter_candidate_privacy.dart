import '../models/models.dart';

const headhunterProtectedCandidateName = 'Talento confidencial';
const headhunterProtectedMessageText =
    'Contenido oculto para proteger la identidad.';

bool isConfidentialAccountType(String? accountType) {
  final type = accountType?.toLowerCase() ?? '';
  return type == 'stealth' ||
      type.startsWith('confidencial') ||
      type.startsWith('confidential');
}

bool isConfidentialCandidate(NexUser candidate) {
  return isConfidentialAccountType(candidate.accountType);
}

bool shouldProtectCandidateForHeadhunter(
  NexUser candidate,
  String? viewerAccountType,
) {
  return viewerAccountType?.toLowerCase() == 'headhunter' &&
      isConfidentialCandidate(candidate);
}

NexUser protectCandidateForHeadhunter(
  NexUser candidate,
  String? viewerAccountType,
) {
  if (!shouldProtectCandidateForHeadhunter(candidate, viewerAccountType)) {
    return candidate;
  }

  final protected = Map<String, dynamic>.from(candidate.toJson())
    ..['name'] = headhunterProtectedCandidateName
    ..['headline'] = ''
    ..['company'] = null
    ..['location'] = null
    ..['avatar_url'] = null
    ..['banner_url'] = null
    ..['video_url'] = null
    ..['about'] = null
    ..['experience'] = const <Map<String, dynamic>>[]
    ..['education'] = const <Map<String, dynamic>>[]
    ..['latitude'] = null
    ..['longitude'] = null
    ..['salary_expectation'] = null
    ..['profile_views'] = 0
    ..['match_percentage'] = 0;

  return NexUser.fromJson(protected);
}

Map<String, dynamic> protectCandidateRowForHeadhunter(
  Map<String, dynamic> row,
  String? viewerAccountType,
) {
  final candidate = NexUser.fromJson(Map<String, dynamic>.from(row));
  if (!shouldProtectCandidateForHeadhunter(candidate, viewerAccountType)) {
    return row;
  }

  return <String, dynamic>{
    ...row,
    ...protectCandidateForHeadhunter(candidate, viewerAccountType).toJson(),
  };
}
