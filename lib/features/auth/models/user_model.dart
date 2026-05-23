/// Represents a user profile in the mploya platform.
///
/// Maps to the `profiles` table in Supabase.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    this.phone,
    this.bio,
    this.headline,
    this.location,
    this.latitude,
    this.longitude,
    this.resumeUrl,
    this.skills,
    this.experience,
    this.education,
    this.isVerified = false,
    this.userType = UserType.jobSeeker,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final String? phone;
  final String? bio;
  final String? headline;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? resumeUrl;
  final List<String>? skills;
  final List<Map<String, dynamic>>? experience;
  final List<Map<String, dynamic>>? education;
  final bool isVerified;
  final UserType userType;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      bio: json['bio'] as String?,
      headline: json['headline'] as String?,
      location: json['location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      resumeUrl: json['resume_url'] as String?,
      skills: (json['skills'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      experience: (json['experience'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      education: (json['education'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      isVerified: json['is_verified'] as bool? ?? false,
      userType: _userTypeFromJson(json['user_type'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'phone': phone,
        'bio': bio,
        'headline': headline,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'resume_url': resumeUrl,
        'skills': skills,
        'experience': experience,
        'education': education,
        'is_verified': isVerified,
        'user_type': userType.value,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  /// Returns display name or email as fallback
  String get displayName => fullName ?? email.split('@').first;

  /// Returns initials for avatar placeholder
  String get initials {
    if (fullName != null && fullName!.isNotEmpty) {
      final parts = fullName!.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }
      return parts.first[0].toUpperCase();
    }
    return email[0].toUpperCase();
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? avatarUrl,
    String? phone,
    String? bio,
    String? headline,
    String? location,
    double? latitude,
    double? longitude,
    String? resumeUrl,
    List<String>? skills,
    List<Map<String, dynamic>>? experience,
    List<Map<String, dynamic>>? education,
    bool? isVerified,
    UserType? userType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      headline: headline ?? this.headline,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      resumeUrl: resumeUrl ?? this.resumeUrl,
      skills: skills ?? this.skills,
      experience: experience ?? this.experience,
      education: education ?? this.education,
      isVerified: isVerified ?? this.isVerified,
      userType: userType ?? this.userType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// User type enum for the platform.
enum UserType {
  jobSeeker('job_seeker'),
  employer('employer'),
  recruiter('recruiter'),
  admin('admin');

  const UserType(this.value);
  final String value;
}

UserType _userTypeFromJson(String? value) {
  switch (value) {
    case 'employer':
      return UserType.employer;
    case 'recruiter':
      return UserType.recruiter;
    case 'admin':
      return UserType.admin;
    default:
      return UserType.jobSeeker;
  }
}
