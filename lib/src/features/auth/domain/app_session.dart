enum UserRole {
  admin,
  driver,
  client;

  static UserRole parse(String value) {
    return UserRole.values.firstWhere(
      (role) => role.name == value.toLowerCase(),
      orElse: () => throw FormatException('Nieobsługiwana rola: $value'),
    );
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.adminPermissions,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
    name: json['name']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    role: UserRole.parse(json['role']?.toString() ?? ''),
    adminPermissions: json['admin_permissions'] is List
        ? (json['admin_permissions'] as List).map((item) => '$item').toSet()
        : null,
  );

  final int id;
  final String name;
  final String email;
  final UserRole role;
  final Set<String>? adminPermissions;

  bool hasAdminPermission(String permission) =>
      role == UserRole.admin &&
      (adminPermissions == null || adminPermissions!.contains(permission));

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role.name,
    'admin_permissions': adminPermissions?.toList(),
  };
}

class AppSession {
  const AppSession({required this.token, required this.user});

  factory AppSession.fromJson(Map<String, dynamic> json) => AppSession(
    token: json['token']?.toString() ?? '',
    user: AppUser.fromJson((json['user'] as Map).cast<String, dynamic>()),
  );

  final String token;
  final AppUser user;

  Map<String, dynamic> toJson() => {'token': token, 'user': user.toJson()};
}
