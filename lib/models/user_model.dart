import 'package:firebase_auth/firebase_auth.dart' as firebase;

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final bool isPremium;
  final DateTime createdAt;
  final DateTime? lastLogin;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.isPremium = false, // Default to free tier
    required this.createdAt,
    this.lastLogin,
  });

  // Factory constructor to create a UserModel from Firebase User
  factory UserModel.fromFirebaseUser(firebase.User user) {
    return UserModel(
      uid: user.uid,
      name: user.displayName ?? 'User',
      email: user.email ?? '',
      photoUrl: user.photoURL,
      createdAt: DateTime.now(), // You might want to store this in Firestore
      lastLogin: DateTime.now(),
    );
  }

  // Empty user for unauthenticated state
  factory UserModel.empty() {
    return UserModel(
      uid: '',
      name: '',
      email: '',
      createdAt: DateTime.now(),
    );
  }

  // Create a copy of this user with modified properties
  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? photoUrl,
    bool? isPremium,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  // Check if user is authenticated
  bool get isAuthenticated => uid.isNotEmpty;

  // Method to convert user to map for database storage
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'isPremium': isPremium,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
    };
  }

  // Factory constructor to create a UserModel from map
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'],
      isPremium: map['isPremium'] ?? false,
      createdAt: DateTime.parse(map['createdAt']),
      lastLogin:
          map['lastLogin'] != null ? DateTime.parse(map['lastLogin']) : null,
    );
  }
}
