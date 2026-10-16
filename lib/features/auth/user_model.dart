enum UserRole { hotel, vendor, driver, admin }

class ReordaUser {
  final String uid;
  final String email;
  final String name;
  final UserRole role;
  final String? entityId;

  ReordaUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.entityId,
  });

  factory ReordaUser.fromMap(Map<String, dynamic> map, String uid) {
    return ReordaUser(
      uid: uid,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => UserRole.hotel,
      ),
      entityId: map['entity_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role.name,
      'entity_id': entityId,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}