import 'enums.dart';

class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    required this.createdAt,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final UserStatus status;
  final DateTime createdAt;
  final String? avatarUrl;

  bool get isActive => status == UserStatus.active;
  bool get isSuperAdmin => role == UserRole.superAdmin;
  bool get isPending => status == UserStatus.pending;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String? ?? 'admin'),
      status: UserStatus.fromString(json['status'] as String? ?? 'pending'),
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Profile copyWith({
    String? name,
    String? avatarUrl,
    bool clearAvatar = false,
  }) {
    return Profile(
      id: id,
      name: name ?? this.name,
      email: email,
      role: role,
      status: status,
      createdAt: createdAt,
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.value,
        'status': status.value,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      };
}
