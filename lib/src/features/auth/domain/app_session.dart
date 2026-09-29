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
    this.mustChangePassword = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
    name: json['name']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    role: UserRole.parse(json['role']?.toString() ?? ''),
    adminPermissions: json['admin_permissions'] is List
        ? (json['admin_permissions'] as List).map((item) => '$item').toSet()
        : null,
    mustChangePassword: json['must_change_password'] == true || json['must_change_password'] == 1,
  );

  final int id;
  final String name;
  final String email;
  final UserRole role;
  final Set<String>? adminPermissions;
  final bool mustChangePassword;

  bool hasAdminPermission(String permission) =>
      role == UserRole.admin &&
      (adminPermissions == null || adminPermissions!.contains(permission));

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role.name,
    'admin_permissions': adminPermissions?.toList(),
    'must_change_password': mustChangePassword,
  };
}

class AppSession {
  const AppSession({
    required this.token,
    required this.user,
    this.adminToken,
    this.adminUser,
  });

  factory AppSession.fromJson(Map<String, dynamic> json) => AppSession(
    token: json['token']?.toString() ?? '',
    user: AppUser.fromJson((json['user'] as Map).cast<String, dynamic>()),
    adminToken: json['admin_token']?.toString(),
    adminUser: json['admin_user'] is Map
        ? AppUser.fromJson((json['admin_user'] as Map).cast<String, dynamic>())
        : null,
  );

  final String token;
  final AppUser user;
  final String? adminToken;
  final AppUser? adminUser;

  bool get canReturnToAdmin =>
      user.role == UserRole.driver &&
      adminToken != null &&
      adminToken!.isNotEmpty &&
      adminUser?.role == UserRole.admin;

  Map<String, dynamic> toJson() => {
    'token': token,
    'user': user.toJson(),
    if (adminToken != null) 'admin_token': adminToken,
    if (adminUser != null) 'admin_user': adminUser!.toJson(),
  };
}
