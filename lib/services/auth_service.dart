import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Auth state stream
  Stream<UserModel> get authStateChanges =>
      _auth.authStateChanges().map((User? user) {
        if (user != null) {
          return UserModel.fromFirebaseUser(user);
        }
        return UserModel.empty();
      });

  // Current user
  UserModel get currentUser {
    final user = _auth.currentUser;
    if (user != null) {
      return UserModel.fromFirebaseUser(user);
    }
    return UserModel.empty();
  }

  // Sign in with email and password
  Future<UserModel> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user == null) {
        throw Exception('Sign in failed: no user returned');
      }

      if (kDebugMode) {
        print('Sign in successful: ${user.uid}');
      }

      return UserModel.fromFirebaseUser(user);
    } catch (e) {
      if (kDebugMode) {
        print('Sign in error: $e');
      }
      rethrow;
    }
  }

  // Sign up with email and password
  Future<UserModel> signUpWithEmailAndPassword(
      String email, String password, String name) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user == null) {
        throw Exception('Sign up failed: no user returned');
      }

      // Update the user's display name
      await user.updateDisplayName(name);

      if (kDebugMode) {
        print('Sign up successful: ${user.uid}');
      }

      return UserModel.fromFirebaseUser(user);
    } catch (e) {
      if (kDebugMode) {
        print('Sign up error: $e');
      }
      rethrow;
    }
  }

  // Sign in with Google
  Future<UserModel> signInWithGoogle() async {
    try {
      // Try using the Firebase auth provider method
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      final UserCredential userCredential =
          await _auth.signInWithProvider(googleProvider);

      final User? user = userCredential.user;
      if (user == null) {
        throw Exception('Google sign in failed: no user returned');
      }

      if (kDebugMode) {
        print('Google sign in successful: ${user.uid}');
      }

      return UserModel.fromFirebaseUser(user);
    } catch (e) {
      if (kDebugMode) {
        print('Google sign in error: $e');
      }
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
    } catch (e) {
      if (kDebugMode) {
        print('Sign out error: $e');
      }
      rethrow;
    }
  }

  // Password reset
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      if (kDebugMode) {
        print('Password reset error: $e');
      }
      rethrow;
    }
  }
}
