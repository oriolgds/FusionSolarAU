import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final DateTime lastLogin;
  final Map<String, dynamic> preferences;

  const User({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.lastLogin,
    required this.preferences,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? '',
      photoUrl: json['photoUrl'],
      lastLogin: DateTime.fromMillisecondsSinceEpoch(
        json['lastLogin'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      preferences: Map<String, dynamic>.from(json['preferences'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'lastLogin': lastLogin.millisecondsSinceEpoch,
      'preferences': preferences,
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    DateTime? lastLogin,
    Map<String, dynamic>? preferences,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      lastLogin: lastLogin ?? this.lastLogin,
      preferences: preferences ?? this.preferences,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        displayName,
        photoUrl,
        lastLogin,
        preferences,
      ];
}
