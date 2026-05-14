class User {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String status;
  final String? profileImage;
  final String? bio;
  final String? username;
  final String? phone;
  final String? location;
  final String? branchId;
  final List<UserBadge> badges;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.status,
    this.profileImage,
    this.bio,
    this.username,
    this.phone,
    this.location,
    this.branchId,
    this.badges = const [],
  });

  String get fullName => '$firstName $lastName';
  String get initials => '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'member',
      status: json['status'] ?? 'pending',
      profileImage: json['profileImage'],
      bio: json['bio'],
      username: json['username'],
      phone: json['phone'],
      location: json['location'],
      branchId: json['branchId'],
      badges: (json['badges'] as List?)
              ?.map((b) => UserBadge.fromJson(b))
              .toList() ??
          [],
    );
  }
}

class UserBadge {
  final String label;
  final String? icon;

  UserBadge({required this.label, this.icon});

  factory UserBadge.fromJson(Map<String, dynamic> json) {
    return UserBadge(
      label: json['label'] ?? '',
      icon: json['icon'],
    );
  }
}
