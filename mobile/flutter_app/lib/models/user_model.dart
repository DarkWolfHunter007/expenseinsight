class UserModel {
  final String id;
  final String email;
  final bool isGuest;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.isGuest,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      isGuest: json['is_guest'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'is_guest': isGuest,
    'created_at': createdAt.toIso8601String(),
  };
}
